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

    func login(username: String, password: String) async throws -> LoginResponse {
        let url = baseURL.appending(path: "/api/v1/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "username": username,
            "password": password,
            "client_type": "mobile",
            "device_name": "crest-ios",
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(readErrorMessage(from: data) ?? "登录失败（\(http.statusCode)）")
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
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
