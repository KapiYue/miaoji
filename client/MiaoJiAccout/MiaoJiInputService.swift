import AVFoundation
import Combine
import Foundation
import Speech

struct VoiceEntryDraft: Equatable {
    let amount: Double?
    let title: String
    let categoryID: UUID?
}

enum VoiceEntryParser {
    static func parse(_ transcript: String, categories: [ExpenseCategory]) -> VoiceEntryDraft {
        let normalized = transcript
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: ",", with: " ")

        let amountExpression = try? NSRegularExpression(
            pattern: #"([0-9]+(?:\.[0-9]{1,2})?)\s*(?:元|块钱|块|人民币)?"#
        )
        let fullRange = NSRange(normalized.startIndex..., in: normalized)
        let match = amountExpression?.firstMatch(in: normalized, range: fullRange)
        let amount: Double? = match.flatMap { result in
            guard let range = Range(result.range(at: 1), in: normalized) else { return nil }
            return Double(normalized[range])
        }

        let category = categories.first {
            normalized.localizedCaseInsensitiveContains($0.name)
        }

        var title = normalized
        if let match, let range = Range(match.range(at: 0), in: title) {
            title.removeSubrange(range)
        }
        if let category {
            title = title.replacingOccurrences(of: category.name, with: "")
        }
        ["花了", "消费", "支出", "记一笔", "记账", "一笔"].forEach {
            title = title.replacingOccurrences(of: $0, with: "")
        }
        title = title
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return VoiceEntryDraft(
            amount: amount,
            title: title.isEmpty ? "语音记账" : title,
            categoryID: category?.id
        )
    }
}

@MainActor
final class MiaoJiInputService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var isUploading = false
    @Published private(set) var transcript = ""
    @Published private(set) var statusMessage = "点击“开始录音”后说出金额、用途和分类。"
    @Published private(set) var recordedFileURL: URL?
    @Published private(set) var uploadedAudioURL: URL?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var permissionRequestID = 0
    private var audioRecorder: AVAudioRecorder?
    private var speechRecognitionAuthorized = false

    private let apiBaseURL: URL?

    var apiEndpointDescription: String {
        apiBaseURL?.absoluteString ?? "未配置"
    }

    init(apiBaseURL: URL? = nil) {
        self.apiBaseURL = apiBaseURL ?? Self.configuredAPIBaseURL
    }

    func startRecording() async {
        guard !isRecording, !isRequestingPermission, !isUploading else { return }

        permissionRequestID += 1
        let currentRequestID = permissionRequestID
        isRequestingPermission = true
        statusMessage = "正在请求录音权限…"
        transcript = ""
        recordedFileURL = nil
        uploadedAudioURL = nil

        speechRecognitionAuthorized = await requestSpeechPermission()
        guard currentRequestID == permissionRequestID else { return }

        let microphoneAuthorized = await requestMicrophonePermission()
        guard currentRequestID == permissionRequestID else { return }
        guard microphoneAuthorized else {
            isRequestingPermission = false
            statusMessage = "未获得麦克风权限，请在系统设置中允许后重试。"
            return
        }

        do {
            try beginRecording()
            isRequestingPermission = false
            isRecording = true
            statusMessage = "正在聆听…说完后点击“停止录音”。"
        } catch {
            stopAudioCapture(cancelTranscription: true)
            discardCurrentRecording()
            isRequestingPermission = false
            statusMessage = "无法开始录音：\(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        guard isRecording || isRequestingPermission else { return }

        permissionRequestID += 1
        let completionRequestID = permissionRequestID
        isRequestingPermission = false
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let recordedFileURL else {
            statusMessage = "未生成录音文件，请重新录音。"
            return
        }

        _ = await uploadRecording(at: recordedFileURL)
        guard completionRequestID == permissionRequestID else { return }
        beginTranscription(of: recordedFileURL)
    }

    func retryUpload() async {
        guard !isRecording, !isUploading, let recordedFileURL else { return }
        _ = await uploadRecording(at: recordedFileURL)
    }

    func cancelRecording() {
        let shouldDiscardRecording = isRecording || isRequestingPermission
        permissionRequestID += 1
        isRequestingPermission = false
        stopAudioCapture(cancelTranscription: true)
        if shouldDiscardRecording {
            discardCurrentRecording()
        }
    }

    private func beginRecording() throws {
        stopAudioCapture(cancelTranscription: true)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let fileURL = try makeRecordingURL()
        let recorder = try AVAudioRecorder(
            url: fileURL,
            settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )
        guard recorder.prepareToRecord(), recorder.record() else {
            throw MiaoJiInputError.audioInputUnavailable
        }
        recordedFileURL = fileURL
        audioRecorder = recorder
    }

    private func beginTranscription(of fileURL: URL) {
        guard speechRecognitionAuthorized, speechRecognizer?.isAvailable == true else {
            statusMessage = uploadedAudioURL == nil
                ? "录音已保存但上传失败；语音识别当前不可用。"
                : "录音已上传；语音识别当前不可用。"
            return
        }

        recognitionTask?.cancel()
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.taskHint = .dictation
        request.shouldReportPartialResults = true
        statusMessage = uploadedAudioURL == nil
            ? "录音上传失败，正在识别录音内容…"
            : "录音已上传，正在识别录音内容…"

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.recognitionTask = nil
                        self.statusMessage = self.uploadedAudioURL == nil
                            ? "识别完成；录音尚未上传，可点击重新上传。"
                            : "录音已上传，可填写识别结果。"
                    }
                } else if let error {
                    self.recognitionTask = nil
                    self.statusMessage = self.uploadedAudioURL == nil
                        ? "录音已保存但上传失败，且识别失败：\(error.localizedDescription)"
                        : "录音已上传，但识别失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func stopAudioCapture(cancelTranscription: Bool) {
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
        audioRecorder = nil
        if cancelTranscription {
            recognitionTask?.cancel()
        }
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @discardableResult
    private func uploadRecording(at fileURL: URL) async -> Bool {
        guard !isUploading else { return false }
        guard let apiBaseURL else {
            statusMessage = "录音已保存，但未配置 MIAOJI_API_BASE_URL，无法上传。"
            return false
        }

        isUploading = true
        statusMessage = "录音已保存，正在上传…"
        defer { isUploading = false }

        do {
            let fileData = try await Task.detached(priority: .utility) {
                try Data(contentsOf: fileURL, options: .mappedIfSafe)
            }.value
            guard !fileData.isEmpty else { throw MiaoJiInputError.emptyRecording }

            let boundary = "Boundary-\(UUID().uuidString)"
            var request = URLRequest(url: apiBaseURL.appendingPathComponent("upload-audio"))
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.multipartBody(
                fileData: fileData,
                filename: fileURL.lastPathComponent,
                boundary: boundary
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MiaoJiInputError.invalidServerResponse
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data).error)
                    ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw MiaoJiInputError.uploadRejected(message)
            }

            let result = try JSONDecoder().decode(AudioUploadResponse.self, from: data)
            uploadedAudioURL = result.url
            statusMessage = transcript.isEmpty
                ? "录音已上传，但没有识别到文字，请靠近麦克风后重试。"
                : "录音已上传，可填写识别结果。"
            return true
        } catch {
            statusMessage = "上传到 \(apiEndpointDescription) 失败：\(error.localizedDescription)"
            return false
        }
    }

    private func makeRecordingURL() throws -> URL {
        let recordingsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
        return recordingsDirectory
            .appending(path: "recording-\(UUID().uuidString.lowercased())")
            .appendingPathExtension("m4a")
    }

    private func discardCurrentRecording() {
        audioRecorder = nil
        if let recordedFileURL {
            try? FileManager.default.removeItem(at: recordedFileURL)
        }
        recordedFileURL = nil
        uploadedAudioURL = nil
    }

    private static func multipartBody(fileData: Data, filename: String, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private static var configuredAPIBaseURL: URL? {
        let configuredValue = ProcessInfo.processInfo.environment["MIAOJI_API_BASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "MIAOJI_API_BASE_URL") as? String
        if let configuredValue,
           let url = URL(string: configuredValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}

private struct AudioUploadResponse: Decodable {
    let url: URL
}

private struct APIErrorResponse: Decodable {
    let error: String
}

private enum MiaoJiInputError: LocalizedError {
    case audioInputUnavailable
    case emptyRecording
    case invalidServerResponse
    case uploadRejected(String)

    var errorDescription: String? {
        switch self {
        case .audioInputUnavailable:
            "未检测到可用的音频输入设备"
        case .emptyRecording:
            "录音文件为空"
        case .invalidServerResponse:
            "服务器响应无效"
        case .uploadRejected(let message):
            message
        }
    }
}
