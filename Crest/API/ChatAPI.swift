import Foundation

/// 侧边栏展示的对话历史摘要。
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

/// 服务端返回的单条历史消息。
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

/// 打开历史会话时返回的完整对话内容。
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

/// 将服务端流式事件转换成页面可直接消费的类型。
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

/// 聊天、历史记录和流式响应接口。
extension APIClient {
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

        // SSE 必须收到明确的结束标记，否则按回复中断处理。
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

    /// 兼容纯文本片段和带 type 字段的 JSON 事件。
    private func parseChatEvent(_ raw: String) throws -> ChatStreamEvent? {
        guard let data = raw.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
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
}
