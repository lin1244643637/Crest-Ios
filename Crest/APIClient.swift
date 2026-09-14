import Foundation

struct LoginResponse: Decodable {
    let token: String
    let username: String
    let tenantID: String
    let userID: String
    let role: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case token
        case username
        case tenantID = "tenant_id"
        case userID = "user_id"
        case role
        case refreshToken = "refresh_token"
    }
}

enum PhoneVerificationPurpose: String, Encodable {
    case login
    case register
    case resetPassword = "reset_password"
}

// Registration status is not exposed by the server yet, so this request is kept
// separate from the verification endpoints that are already available.
struct PhoneRegistrationStatusRequest: Encodable {
    let phone: String
    let countryCode: String
    let clientType: String

    enum CodingKeys: String, CodingKey {
        case phone
        case countryCode = "country_code"
        case clientType = "client_type"
    }
}

struct VerificationCreateRequest: Encodable {
    let channel = "sms"
    let purpose: PhoneVerificationPurpose
    let target: String
    let inviteToken: String

    enum CodingKeys: String, CodingKey {
        case channel
        case purpose
        case target
        case inviteToken = "invite_token"
    }
}

struct VerificationCreateResponse: Decodable {
    let challengeID: String
    let message: String
    let expiresIn: Int
    let resendAfter: Int

    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case message
        case expiresIn = "expires_in"
        case resendAfter = "resend_after"
    }
}

struct VerificationConfirmRequest: Encodable {
    let code: String
}

struct VerificationConfirmResponse: Decodable {
    let verificationToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case verificationToken = "verification_token"
        case expiresIn = "expires_in"
    }
}

struct CodeLoginRequest: Encodable {
    let verificationToken: String
    let clientType: String
    let deviceName: String

    enum CodingKeys: String, CodingKey {
        case verificationToken = "verification_token"
        case clientType = "client_type"
        case deviceName = "device_name"
    }
}

struct ResetPasswordRequest: Encodable {
    let verificationToken: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case verificationToken = "verification_token"
        case newPassword = "new_password"
    }
}

struct ResetPasswordResponse: Decodable {
    let message: String
}

struct ChatSessionSummary: Decodable, Identifiable {
    let sessionID: String
    let title: String
    let createdAt: String
    let updatedAt: String

    var id: String { sessionID }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChatHistoryMessage: Decodable {
    let id: String
    let role: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt = "created_at"
    }
}

struct ChatSessionDetail: Decodable {
    let sessionID: String
    let title: String
    let messages: [ChatHistoryMessage]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case title
        case messages
    }
}

enum ChatStreamEvent {
    case text(String)
    case metadata(sessionID: String?)
    case stage(String)
    case done
}

private struct ChatRequest: Encodable {
    let message: String
    let sessionID: String

    enum CodingKeys: String, CodingKey {
        case message
        case sessionID = "session_id"
    }
}

struct MobileSessionRequest: Encodable {
    let clientType = "mobile"
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case clientType = "client_type"
        case refreshToken = "refresh_token"
    }
}

private struct LogoutResponse: Decodable {
    let ok: Bool
}

enum APIError: LocalizedError {
    case invalidResponse
    case invalidSession
    case unauthorized(String)
    case server(String)

    var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }

    var invalidatesSession: Bool {
        switch self {
        case .invalidSession, .unauthorized:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应异常"
        case .invalidSession:
            return "登录状态无效，请重新登录"
        case .unauthorized(let message):
            return message
        case .server(let message):
            return message
        }
    }
}

struct APIClient {
    private let baseURL = URL(string: "https://blackwave.org.cn/yuanji")!

    func isPhoneRegistered(_ request: PhoneRegistrationStatusRequest) async -> Bool {
        // TODO(auth-api): Replace this fallback when the registration-status endpoint is ready.
        // Request parameters: phone, country_code, client_type.
        // Expected response fields: is_registered, has_password.
        _ = request
        return true
    }

    func login(phone: String, password: String) async throws -> LoginResponse {
        let body = [
            "identifier_type": "phone",
            "identifier": phone,
            "password": password,
            "client_type": "mobile",
            "device_name": "crest-ios",
        ]
        return try await post(
            "/api/v1/auth/login",
            body: body,
            fallbackError: "登录失败"
        )
    }

    func sendPhoneCode(
        phone: String,
        purpose: PhoneVerificationPurpose,
        inviteToken: String = ""
    ) async throws -> VerificationCreateResponse {
        try await post(
            "/api/v1/auth/verifications",
            body: VerificationCreateRequest(
                purpose: purpose,
                target: phone,
                inviteToken: inviteToken
            ),
            fallbackError: "验证码发送失败"
        )
    }

    func confirmPhoneCode(
        challengeID: String,
        code: String
    ) async throws -> VerificationConfirmResponse {
        try await post(
            "/api/v1/auth/verifications/\(challengeID)/confirm",
            body: VerificationConfirmRequest(code: code),
            fallbackError: "验证码校验失败"
        )
    }

    func loginWithCode(verificationToken: String) async throws -> LoginResponse {
        try await post(
            "/api/v1/auth/login/code",
            body: CodeLoginRequest(
                verificationToken: verificationToken,
                clientType: "mobile",
                deviceName: "crest-ios"
            ),
            fallbackError: "验证码登录失败"
        )
    }

    func refreshSession(refreshToken: String) async throws -> LoginResponse {
        try await post(
            "/api/v1/auth/refresh",
            body: MobileSessionRequest(refreshToken: refreshToken),
            fallbackError: "登录状态刷新失败"
        )
    }

    func logout(refreshToken: String) async throws {
        let response: LogoutResponse = try await post(
            "/api/v1/auth/logout",
            body: MobileSessionRequest(refreshToken: refreshToken),
            fallbackError: "退出登录失败"
        )
        guard response.ok else { throw APIError.invalidResponse }
    }

    func resetPassword(
        verificationToken: String,
        newPassword: String
    ) async throws -> ResetPasswordResponse {
        try await post(
            "/api/v1/auth/reset-password",
            body: ResetPasswordRequest(
                verificationToken: verificationToken,
                newPassword: newPassword
            ),
            fallbackError: "密码重置失败"
        )
    }

    func listChatSessions(accessToken: String) async throws -> [ChatSessionSummary] {
        try await get(
            baseURL.appending(path: "api/v1/sessions"),
            accessToken: accessToken,
            fallbackError: "对话历史加载失败"
        )
    }

    func chatSessionDetail(
        sessionID: String,
        accessToken: String
    ) async throws -> ChatSessionDetail {
        try await get(
            baseURL
                .appending(path: "api/v1/sessions")
                .appending(path: sessionID),
            accessToken: accessToken,
            fallbackError: "对话加载失败"
        )
    }

    func streamChat(
        message: String,
        sessionID: String,
        accessToken: String,
        onEvent: (ChatStreamEvent) async -> Void
    ) async throws {
        var request = URLRequest(url: baseURL.appending(path: "api/v1/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(message: message, sessionID: sessionID)
        )

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
            }
            let message = readErrorMessage(from: data) ?? "消息发送失败（\(http.statusCode)）"
            if http.statusCode == 401 {
                throw APIError.unauthorized(message)
            }
            throw APIError.server(message)
        }

        var didComplete = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }

            let raw = line
                .dropFirst(5)
                .trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { continue }
            if raw == "[DONE]" {
                didComplete = true
                await onEvent(.done)
                break
            }
            if let event = try parseChatEvent(raw) {
                await onEvent(event)
            }
        }

        guard didComplete else {
            throw APIError.server("回复中断，请重新发送")
        }
    }

    private func get<ResponseBody: Decodable>(
        _ url: URL,
        accessToken: String,
        fallbackError: String
    ) async throws -> ResponseBody {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = readErrorMessage(from: data) ?? "\(fallbackError)（\(http.statusCode)）"
            if http.statusCode == 401 {
                throw APIError.unauthorized(message)
            }
            throw APIError.server(message)
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    private func parseChatEvent(_ raw: String) throws -> ChatStreamEvent? {
        guard let data = raw.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data)
        else {
            return .text(raw)
        }

        if let text = payload as? String {
            return .text(text)
        }
        guard let object = payload as? [String: Any] else { return nil }

        switch object["type"] as? String {
        case "text":
            guard let text = object["content"] as? String, !text.isEmpty else { return nil }
            return .text(text)
        case "meta":
            return .metadata(sessionID: object["session_id"] as? String)
        case "stage":
            return .stage(object["label"] as? String ?? "正在处理")
        case "error":
            throw APIError.server(object["message"] as? String ?? "消息处理失败")
        default:
            return nil
        }
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        _ path: String,
        body: RequestBody,
        fallbackError: String
    ) async throws -> ResponseBody {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = readErrorMessage(from: data) ?? "\(fallbackError)（\(http.statusCode)）"
            if http.statusCode == 401 {
                throw APIError.unauthorized(message)
            }
            throw APIError.server(message)
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    private func readErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = object["detail"] as? String
        else {
            return nil
        }
        return detail
    }
}
