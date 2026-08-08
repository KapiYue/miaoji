import Foundation
import Security

enum EmailOTPCode {
    static func normalized(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(10))
    }

    static func isValid(_ value: String) -> Bool {
        (6...10).contains(normalized(value).count)
    }
}

struct SupabaseConfiguration: Equatable {
    let url: URL
    let publishableKey: String

    init?(bundle: Bundle = .main) {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let rawKey = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        else { return nil }

        let urlString = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !urlString.isEmpty,
            !key.isEmpty,
            !urlString.contains("$("),
            !key.contains("$("),
            !urlString.localizedCaseInsensitiveContains("YOUR_PROJECT"),
            !key.localizedCaseInsensitiveContains("YOUR_"),
            let url = URL(string: urlString),
            url.scheme == "https",
            url.host != nil
        else { return nil }

        self.url = url
        self.publishableKey = key
    }
}

enum SupabaseSyncError: LocalizedError {
    case notConfigured
    case notSignedIn
    case invalidResponse
    case networkUnavailable
    case requestTimedOut
    case cannotReachServer
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "尚未配置云同步服务。"
        case .notSignedIn:
            "请先登录云同步账号。"
        case .invalidResponse:
            "云端返回了无法识别的数据。"
        case .networkUnavailable:
            "当前网络不可用。请检查 Wi-Fi 或蜂窝网络后重试。"
        case .requestTimedOut:
            "连接云同步服务超时。请切换网络或稍后重试。"
        case .cannotReachServer:
            "暂时无法连接云同步服务。请检查网络、VPN 或代理设置后重试。"
        case .server(let message):
            message
        }
    }
}

@MainActor
protocol SupabaseSyncServicing: AnyObject {
    func restoreSession() async throws -> String?
    func requestEmailOTP(email: String) async throws
    func verifyEmailOTP(email: String, token: String) async throws -> String
    func signInWithPassword(email: String, password: String) async throws -> String
    func recordPrivacyConsent() async throws
    func fetchSnapshot() async throws -> StoredData?
    func uploadSnapshot(_ data: StoredData) async throws
    func accessToken() async throws -> String
    func deleteAccount() async throws
    func signOut() async
}

final class SupabaseSyncService: SupabaseSyncServicing {
    static let installationMarkerKey = "MiaoJiAccout.installationInitialized.v1"

    private struct User: Codable {
        let id: UUID
        let email: String?
    }

    private struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double
        let expiresAt: Double?
        let user: User

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case expiresAt = "expires_at"
            case user
        }
    }

    private struct Session: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Double
        let user: User
    }

    private struct SnapshotRow: Decodable {
        let data: StoredData
    }

    private struct SnapshotUpload: Encodable {
        let userID: UUID
        let data: StoredData

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case data
        }
    }

    private struct PrivacyConsentUpload: Encodable {
        let userID: UUID
        let policyVersion = "2026-07-17"
        let termsVersion = "2026-07-17"
        let crossBorderConsent = true
        let crossBorderRecipient = "Supabase Pte. Ltd (Singapore)"
        let consentedAt: String

        init(userID: UUID) {
            self.userID = userID
            consentedAt = ISO8601DateFormatter().string(from: .now)
        }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case policyVersion = "policy_version"
            case termsVersion = "terms_version"
            case crossBorderConsent = "cross_border_consent"
            case crossBorderRecipient = "cross_border_recipient"
            case consentedAt = "consented_at"
        }
    }

    // GoTrue and PostgREST disagree on the shape of an error body: GoTrue sends
    // a numeric `code` with the machine-readable reason in `error_code`, while
    // PostgREST sends a string `code` (the SQLSTATE). Decoding must tolerate
    // both — a single mismatched field previously discarded the whole body and
    // reduced every server error to "HTTP 400".
    struct ServerError: Decodable {
        let code: String?
        let errorCode: String?
        let message: String?
        let msg: String?
        let errorDescription: String?
        let error: String?

        /// The machine-readable reason, preferring GoTrue's dedicated field.
        var reasonCode: String? { errorCode ?? code }

        /// The most descriptive human-readable text the server provided.
        var localizedText: String? { message ?? msg ?? errorDescription ?? error }

        enum CodingKeys: String, CodingKey {
            case code, message, msg, error
            case errorCode = "error_code"
            case errorDescription = "error_description"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let string = try? container.decodeIfPresent(String.self, forKey: .code) {
                code = string
            } else if let number = try? container.decodeIfPresent(Int.self, forKey: .code) {
                code = String(number)
            } else {
                code = nil
            }
            errorCode = try? container.decodeIfPresent(String.self, forKey: .errorCode)
            message = try? container.decodeIfPresent(String.self, forKey: .message)
            msg = try? container.decodeIfPresent(String.self, forKey: .msg)
            errorDescription = try? container.decodeIfPresent(String.self, forKey: .errorDescription)
            error = try? container.decodeIfPresent(String.self, forKey: .error)
        }
    }

    private let configuration: SupabaseConfiguration
    private let session: URLSession
    private let keychain = SupabaseSessionKeychain()
    private var currentSession: Session?

    init(configuration: SupabaseConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        self.session = session ?? Self.makeSession()
    }

    static func prepareSessionForAppLaunch(
        defaults: UserDefaults = .standard,
        clearPersistedSession: () -> Void = { SupabaseSessionKeychain().delete() }
    ) {
        guard !defaults.bool(forKey: installationMarkerKey) else { return }

        // UserDefaults is removed when the app is uninstalled, while Keychain
        // items may survive. A missing marker therefore identifies a fresh
        // installation and prevents an old account from being restored.
        clearPersistedSession()
        defaults.set(true, forKey: installationMarkerKey)
    }

    static func configured(bundle: Bundle = .main) -> SupabaseSyncService? {
        guard let configuration = SupabaseConfiguration(bundle: bundle) else { return nil }
        return SupabaseSyncService(configuration: configuration)
    }

    var accountEmail: String? { currentSession?.user.email }

    func restoreSession() async throws -> String? {
        guard let saved: Session = keychain.load() else { return nil }
        currentSession = saved
        do {
            let session = try await validSession(forceRefresh: true)
            return session.user.email
        } catch {
            signOutLocally()
            throw error
        }
    }

    func requestEmailOTP(email: String) async throws {
        struct Payload: Encodable {
            let email: String
            let createUser = true

            enum CodingKeys: String, CodingKey {
                case email
                case createUser = "create_user"
            }
        }

        var request = try request(path: "auth/v1/otp", method: "POST")
        request.httpBody = try JSONEncoder().encode(Payload(email: email))
        _ = try await perform(request)
    }

    func verifyEmailOTP(email: String, token: String) async throws -> String {
        struct Payload: Encodable {
            let email: String
            let token: String
            let type = "email"
        }

        var request = try request(path: "auth/v1/verify", method: "POST")
        request.httpBody = try JSONEncoder().encode(Payload(email: email, token: token))
        let data = try await perform(request)
        let session = try decodeSession(from: data)
        save(session)
        return session.user.email ?? email
    }

    func signInWithPassword(email: String, password: String) async throws -> String {
        struct Payload: Encodable {
            let email: String
            let password: String
        }

        var components = URLComponents(url: try endpoint(path: "auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let url = components?.url else { throw SupabaseSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(Payload(email: email, password: password))
        let data = try await perform(request)
        let session = try decodeSession(from: data)
        save(session)
        return session.user.email ?? email
    }

    func recordPrivacyConsent() async throws {
        let session = try await validSession()
        var components = URLComponents(url: try endpoint(path: "rest/v1/privacy_consents"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id")]
        guard let url = components?.url else { throw SupabaseSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        authorize(&request, accessToken: session.accessToken)
        request.httpBody = try JSONEncoder().encode(PrivacyConsentUpload(userID: session.user.id))
        _ = try await perform(request)
    }

    func fetchSnapshot() async throws -> StoredData? {
        let session = try await validSession()
        var components = URLComponents(url: try endpoint(path: "rest/v1/account_snapshots"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "data"),
            URLQueryItem(name: "user_id", value: "eq.\(session.user.id.uuidString)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else { throw SupabaseSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        authorize(&request, accessToken: session.accessToken)
        let data = try await perform(request)
        return try JSONDecoder().decode([SnapshotRow].self, from: data).first?.data
    }

    func uploadSnapshot(_ data: StoredData) async throws {
        let session = try await validSession()
        var components = URLComponents(url: try endpoint(path: "rest/v1/account_snapshots"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id")]
        guard let url = components?.url else { throw SupabaseSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        authorize(&request, accessToken: session.accessToken)
        request.httpBody = try JSONEncoder().encode(SnapshotUpload(userID: session.user.id, data: data))
        _ = try await perform(request)
    }

    func accessToken() async throws -> String {
        try await validSession().accessToken
    }

    func deleteAccount() async throws {
        let session = try await validSession()
        var request = try request(path: "rest/v1/rpc/delete_current_account", method: "POST")
        authorize(&request, accessToken: session.accessToken)
        request.httpBody = Data("{}".utf8)
        _ = try await perform(request)
        signOutLocally()
    }

    func signOut() async {
        if let session = currentSession {
            if var request = try? request(path: "auth/v1/logout", method: "POST") {
                authorize(&request, accessToken: session.accessToken)
                _ = try? await perform(request)
            }
        }
        signOutLocally()
    }

    private func validSession(forceRefresh: Bool = false) async throws -> Session {
        guard let session = currentSession else { throw SupabaseSyncError.notSignedIn }
        if !forceRefresh, session.expiresAt > Date.now.timeIntervalSince1970 + 60 {
            return session
        }

        struct Payload: Encodable { let refreshToken: String; enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" } }
        var components = URLComponents(url: try endpoint(path: "auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components?.url else { throw SupabaseSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(Payload(refreshToken: session.refreshToken))
        let data = try await perform(request)
        let refreshed = try decodeSession(from: data)
        save(refreshed)
        return refreshed
    }

    private func decodeSession(from data: Data) throws -> Session {
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        return Session(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt ?? Date.now.timeIntervalSince1970 + response.expiresIn,
            user: response.user
        )
    }

    private func save(_ session: Session) {
        currentSession = session
        keychain.save(session)
    }

    private func signOutLocally() {
        currentSession = nil
        keychain.delete()
    }

    private func endpoint(path: String) throws -> URL {
        let base = configuration.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/\(path)") else { throw SupabaseSyncError.invalidResponse }
        return url
    }

    private func request(path: String, method: String) throws -> URLRequest {
        var request = URLRequest(url: try endpoint(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func authorize(_ request: inout URLRequest, accessToken: String) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw SupabaseSyncError.networkUnavailable
            case .timedOut:
                throw SupabaseSyncError.requestTimedOut
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                 .secureConnectionFailed, .serverCertificateUntrusted:
                throw SupabaseSyncError.cannotReachServer
            default:
                throw error
            }
        }
        guard let http = response as? HTTPURLResponse else { throw SupabaseSyncError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let serverError = try? JSONDecoder().decode(ServerError.self, from: data)
            throw SupabaseSyncError.server(Self.localizedServerMessage(
                code: serverError?.reasonCode,
                fallback: serverError?.localizedText,
                statusCode: http.statusCode
            ))
        }
        return data
    }

    static func localizedServerMessage(code: String?, fallback: String?, statusCode: Int) -> String {
        switch code {
        case "invalid_credentials", "invalid_grant":
            return "邮箱或密码不正确，请检查后重试。"
        case "email_not_confirmed":
            return "该邮箱尚未完成验证，请先用邮箱验证码登录一次。"
        case "user_banned":
            return "该账号已被停用，请联系支持人员。"
        case "weak_password":
            return "密码强度不足，请改用至少 8 位且包含字母和数字的密码。"
        case "email_address_not_authorized":
            return "当前邮箱暂不能接收验证码。请联系支持人员开通邮件服务，或改用邮箱密码登录。"
        case "over_email_send_rate_limit", "over_request_rate_limit":
            return "验证码发送过于频繁，请稍后再试。"
        case "email_provider_disabled":
            return "邮箱登录服务暂未开启，请联系支持人员。"
        case "signup_disabled":
            return "暂不允许创建新账号，请改用已有账号登录。"
        default:
            return fallback ?? "云同步请求失败（HTTP \(statusCode)）。"
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        return URLSession(configuration: configuration)
    }
}

private final class SupabaseSessionKeychain {
    private let service = "personal.MiaoJiAccout.supabase"
    private let account = "auth-session"

    func save<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func load<T: Decodable>() -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
