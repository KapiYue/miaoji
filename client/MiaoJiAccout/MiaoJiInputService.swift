import AVFoundation
import Combine
import Foundation

struct AIParsedExpense: Decodable, Equatable, Identifiable {
    let id = UUID()
    let amount: Double
    let title: String
    let categoryID: UUID
    let categoryName: String

    private enum CodingKeys: String, CodingKey {
        case amount, title
        case categoryID = "category_id"
        case categoryName = "category_name"
    }
}

@MainActor
final class MiaoJiInputService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var isUploading = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var statusMessage = "点击“开始录音”后说出一笔或多笔消费。"
    @Published private(set) var recordedFileURL: URL?
    @Published private(set) var uploadedAudioPath: String?
    @Published private(set) var parsedExpenses: [AIParsedExpense] = []

    private var operationID = 0
    private var audioRecorder: AVAudioRecorder?
    private let apiBaseURL: URL?
    private let urlSession: URLSession

    var isBusy: Bool { isRequestingPermission || isUploading || isAnalyzing }
    var canRetry: Bool { recordedFileURL != nil && !isRecording && !isBusy }

    init(apiBaseURL: URL? = nil) {
        let resolvedAPIBaseURL = apiBaseURL ?? Self.configuredAPIBaseURL
        self.apiBaseURL = resolvedAPIBaseURL
        if let resolvedAPIBaseURL {
            let configuration = resolvedAPIBaseURL.isLocalDevelopmentServer
                ? URLSessionConfiguration.ephemeral
                : URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForResource = 150
            if resolvedAPIBaseURL.isLocalDevelopmentServer {
                // A system or development proxy should not intercept private LAN traffic.
                configuration.connectionProxyDictionary = [:]
            }
            self.urlSession = URLSession(configuration: configuration)
        } else {
            self.urlSession = .shared
        }
        Self.removeStaleRecordings()
    }

    func startRecording() async {
        guard !isRecording, !isBusy else { return }

        operationID += 1
        let currentOperationID = operationID
        isRequestingPermission = true
        statusMessage = "正在请求录音权限…"
        parsedExpenses = []
        removeLocalRecording()
        uploadedAudioPath = nil

        let microphoneAuthorized = await requestMicrophonePermission()
        guard currentOperationID == operationID else { return }
        guard microphoneAuthorized else {
            isRequestingPermission = false
            statusMessage = "未获得麦克风权限，请在系统设置中允许后重试。"
            return
        }

        do {
            try beginRecording()
            isRequestingPermission = false
            isRecording = true
            statusMessage = "正在聆听…可以连续说出多笔消费。"
        } catch {
            stopAudioCapture()
            discardCurrentRecording()
            isRequestingPermission = false
            statusMessage = "无法开始录音：\(error.localizedDescription)"
        }
    }

    func stopRecording(categories: [ExpenseCategory], authorizationToken: String) async {
        guard isRecording || isRequestingPermission else { return }

        operationID += 1
        let currentOperationID = operationID
        isRequestingPermission = false
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let recordedFileURL else {
            statusMessage = "未生成录音文件，请重新录音。"
            return
        }
        await uploadAndAnalyze(
            recordedFileURL,
            categories: categories,
            authorizationToken: authorizationToken,
            operationID: currentOperationID
        )
    }

    func retry(categories: [ExpenseCategory], authorizationToken: String) async {
        guard canRetry else { return }
        operationID += 1
        let currentOperationID = operationID
        parsedExpenses = []
        if let uploadedAudioPath {
            await analyze(
                audioPath: uploadedAudioPath,
                categories: categories,
                authorizationToken: authorizationToken,
                operationID: currentOperationID
            )
        } else if let recordedFileURL {
            await uploadAndAnalyze(
                recordedFileURL,
                categories: categories,
                authorizationToken: authorizationToken,
                operationID: currentOperationID
            )
        }
    }

    func showAccountRequired() {
        statusMessage = "语音解析需要先在“设置”中登录云同步账号；手动记账无需登录。"
    }

    func showAuthorizationFailure(_ error: Error) {
        statusMessage = "无法验证语音服务账号：\(error.localizedDescription)"
    }

    func cancelRecording() {
        operationID += 1
        isRequestingPermission = false
        isUploading = false
        isAnalyzing = false
        stopAudioCapture()
        discardCurrentRecording()
    }

    private func beginRecording() throws {
        stopAudioCapture()
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

    private func stopAudioCapture() {
        if audioRecorder?.isRecording == true { audioRecorder?.stop() }
        audioRecorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func uploadAndAnalyze(
        _ fileURL: URL,
        categories: [ExpenseCategory],
        authorizationToken: String,
        operationID: Int
    ) async {
        guard let apiBaseURL else {
            statusMessage = "未配置服务端地址，无法上传录音。"
            return
        }
        guard !categories.isEmpty else {
            statusMessage = "暂无可用分类，请先在设置中添加分类。"
            return
        }

        isUploading = true
        statusMessage = "录音完成，正在安全上传…"
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
            request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = Self.multipartBody(fileData: fileData, filename: fileURL.lastPathComponent, boundary: boundary)

            let (data, response) = try await urlSession.data(for: request)
            guard operationID == self.operationID else { return }
            guard let httpResponse = response as? HTTPURLResponse else { throw MiaoJiInputError.invalidServerResponse }
            guard 200..<300 ~= httpResponse.statusCode else {
                throw MiaoJiInputError.requestRejected(Self.serverMessage(data, statusCode: httpResponse.statusCode))
            }

            let result = try JSONDecoder().decode(AudioUploadResponse.self, from: data)
            uploadedAudioPath = result.path
            isUploading = false
            await analyze(
                audioPath: result.path,
                categories: categories,
                authorizationToken: authorizationToken,
                operationID: operationID
            )
        } catch {
            guard operationID == self.operationID else { return }
            isUploading = false
            statusMessage = Self.failureMessage(for: error, action: "上传", apiBaseURL: apiBaseURL)
        }
    }

    private func analyze(
        audioPath: String,
        categories: [ExpenseCategory],
        authorizationToken: String,
        operationID: Int
    ) async {
        guard let apiBaseURL else { return }
        isAnalyzing = true
        statusMessage = "AI 正在理解语音并拆分记账明细…"
        do {
            let body = ParseAudioRequest(
                audioPath: audioPath,
                categories: categories.map { .init(id: $0.id.uuidString, name: $0.name) }
            )
            var request = URLRequest(url: apiBaseURL.appendingPathComponent("parse-audio-expenses"))
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await urlSession.data(for: request)
            guard operationID == self.operationID else { return }
            guard let httpResponse = response as? HTTPURLResponse else { throw MiaoJiInputError.invalidServerResponse }
            guard 200..<300 ~= httpResponse.statusCode else {
                throw MiaoJiInputError.requestRejected(Self.serverMessage(data, statusCode: httpResponse.statusCode))
            }
            let result = try JSONDecoder().decode([AIParsedExpense].self, from: data)
            parsedExpenses = result
            uploadedAudioPath = nil
            isAnalyzing = false
            removeLocalRecording()
            statusMessage = result.isEmpty
                ? "没有识别到明确的记账明细，请重试并说清金额和用途。"
                : "AI 已识别 \(result.count) 笔明细，请核对后统一保存。"
        } catch {
            guard operationID == self.operationID else { return }
            isAnalyzing = false
            // The server deletes its temporary object after every parse attempt,
            // so a retry must upload the retained local recording again.
            uploadedAudioPath = nil
            statusMessage = Self.failureMessage(for: error, action: "AI 解析", apiBaseURL: apiBaseURL)
        }
    }

    private func makeRecordingURL() throws -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "recording-\(UUID().uuidString.lowercased())").appendingPathExtension("m4a")
    }

    private func discardCurrentRecording() {
        removeLocalRecording()
        uploadedAudioPath = nil
        parsedExpenses = []
    }

    private func removeLocalRecording() {
        if let recordedFileURL { try? FileManager.default.removeItem(at: recordedFileURL) }
        recordedFileURL = nil
    }

    private static func removeStaleRecordings() {
        let manager = FileManager.default
        guard let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "Recordings", directoryHint: .isDirectory),
              let files = try? manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return }
        let cutoff = Date.now.addingTimeInterval(-24 * 60 * 60)
        for file in files {
            let modifiedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if modifiedAt.map({ $0 < cutoff }) ?? true { try? manager.removeItem(at: file) }
        }
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

    private static func serverMessage(_ data: Data, statusCode: Int) -> String {
        (try? JSONDecoder().decode(APIErrorResponse.self, from: data).error)
            ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
    }

    static func failureMessage(for error: Error, action: String, apiBaseURL: URL?) -> String {
        if let urlError = error as? URLError {
            if apiBaseURL?.isLocalDevelopmentServer == true,
               [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut]
                .contains(urlError.code) {
                return "无法访问局域网记账服务。请确认手机与电脑连接同一 Wi-Fi，并在 iPhone“设置 > 隐私与安全性 > 本地网络”中允许“妙记”；仍失败时请检查 macOS 防火墙。"
            }
            if [.cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost,
                .notConnectedToInternet, .timedOut, .secureConnectionFailed]
                .contains(urlError.code) {
                return "暂时无法连接语音记账服务。请检查网络、VPN 或代理设置后重试。"
            }
        }
        return "\(action)失败：\(error.localizedDescription)"
    }

    private static var configuredAPIBaseURL: URL? {
        if let value = ProcessInfo.processInfo.environment["MIAOJI_API_BASE_URL"],
           let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
#if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000")
#else
        if let value = Bundle.main.object(forInfoDictionaryKey: "MIAOJI_API_BASE_URL") as? String,
           let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.host != nil {
#if DEBUG
            guard url.scheme?.lowercased() == "https" || url.isLocalDevelopmentServer else { return nil }
#else
            guard url.scheme?.lowercased() == "https" else { return nil }
#endif
            return url
        }
        return nil
#endif
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}

private extension URL {
    var isLocalDevelopmentServer: Bool {
        guard scheme?.lowercased() == "http", let host = host?.lowercased() else { return false }
        return host == "localhost"
            || host == "127.0.0.1"
            || host.hasPrefix("192.168.")
            || host.hasPrefix("10.")
            || host.range(of: #"^172\.(1[6-9]|2[0-9]|3[01])\."#, options: .regularExpression) != nil
    }
}

private struct AudioUploadResponse: Decodable { let path: String }
private struct APIErrorResponse: Decodable { let error: String }

private struct ParseAudioRequest: Encodable {
    let audioPath: String
    let categories: [Category]

    struct Category: Encodable { let id: String; let name: String }
    enum CodingKeys: String, CodingKey { case audioPath = "audio_path", categories }
}

private enum MiaoJiInputError: LocalizedError {
    case audioInputUnavailable, emptyRecording, invalidServerResponse
    case requestRejected(String)

    var errorDescription: String? {
        switch self {
        case .audioInputUnavailable: "未检测到可用的音频输入设备"
        case .emptyRecording: "录音文件为空"
        case .invalidServerResponse: "服务器响应无效"
        case .requestRejected(let message): message
        }
    }
}
