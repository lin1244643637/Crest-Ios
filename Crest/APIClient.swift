import Foundation

struct LoginResponse: Decodable {
    let token: String
    let username: String
    let tenantID: String
    let userID: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case token
        case username
        case tenantID = "tenant_id"
        case userID = "user_id"
        case role
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

enum APIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应异常"
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
            throw APIError.server(readErrorMessage(from: data) ?? "\(fallbackError)（\(http.statusCode)）")
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
