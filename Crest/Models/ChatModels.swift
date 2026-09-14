import Foundation

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id: String
    let role: Role
    var content: String

    init(id: String = UUID().uuidString, role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    init?(historyMessage: ChatHistoryMessage) {
        guard historyMessage.role == "user" || historyMessage.role == "assistant" else {
            return nil
        }
        id = historyMessage.id
        role = historyMessage.role == "user" ? .user : .assistant
        content = historyMessage.content
    }
}

struct ChatAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ChatSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
}
