import SwiftUI

/// 聊天主页，负责消息流、历史会话、侧边栏和设置弹窗的状态编排。
struct ChatView: View {
    @EnvironmentObject private var session: SessionStore
    @FocusState private var isComposerFocused: Bool

    private let api = APIClient()

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isWaitingForService = false
    @State private var streamStatus = "正在连接"
    @State private var streamingMessageID: String?
    @State private var activeSessionID: String?
    @State private var activeTitle = "新对话"
    @State private var history: [ChatSessionSummary] = []
    @State private var historySearch = ""
    @State private var isLoadingHistory = false
    @State private var isLoadingConversation = false
    @State private var isSidebarOpen = false
    @State private var isSettingsPresented = false
    @State private var isSettingPassword = false
    @State private var presentedAlert: ChatAlert?
    @State private var chatTask: Task<Void, Never>?

    private var suggestions: [ChatSuggestion] {
        if session.tenantID == nil {
            return [
                ChatSuggestion(icon: "menucard", title: "帮我设计一份菜单结构"),
                ChatSuggestion(icon: "chart.pie", title: "如何控制餐厅食材成本"),
                ChatSuggestion(icon: "megaphone", title: "制定新店开业推广计划")
            ]
        }
        return [
            ChatSuggestion(icon: "chart.line.uptrend.xyaxis", title: "分析本月经营情况"),
            ChatSuggestion(icon: "exclamationmark.magnifyingglass", title: "找出最近的异常费用"),
            ChatSuggestion(icon: "doc.text", title: "生成一份经营摘要")
        ]
    }

    var body: some View {
        ZStack(alignment: .leading) {
            chatContent
            appSidebar
        }
        .alert(item: $presentedAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("好"))
            )
        }
        .task {
            await loadHistory()
        }
        .onDisappear {
            chatTask?.cancel()
        }
        .sheet(isPresented: $isSettingsPresented) {
            AppSettingsSheet(
                username: session.username,
                onSignOut: session.signOut
            )
            .presentationDetents([.fraction(0.78), .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(45)
        }
        .sheet(isPresented: $isSettingPassword) {
            InitialPasswordView()
                .environmentObject(session)
                .presentationDetents([.medium])
        }
    }

    private var chatContent: some View {
        ZStack {
            ChatBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ChatHeader(
                    title: activeTitle,
                    subtitle: session.tenantID == nil ? "餐饮经营助手" : "经营助手",
                    onOpenSidebar: openSidebar,
                    onNewConversation: startNewConversation,
                    onOpenSettings: openSettings
                )

                Divider()
                    .overlay(AppColors.border)

                if session.tenantID == nil && !session.hasPassword {
                    Button {
                        isSettingPassword = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.badge.plus")
                            Text("完善密码")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.primaryText)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(AppColors.surface)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(AppColors.border)
                }

                conversation
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(
                draft: $draft,
                isFocused: $isComposerFocused,
                canSend: canSend,
                onSend: sendMessage
            )
        }
    }

    private var appSidebar: some View {
        AppSidebar(
            isPresented: $isSidebarOpen,
            username: session.username,
            sessions: history,
            activeSessionID: activeSessionID,
            searchText: $historySearch,
            isLoading: isLoadingHistory,
            onNewConversation: startNewConversation,
            onSelectSession: openConversation,
            onRefresh: {
                Task { await loadHistory() }
            },
            onOpenSettings: openSettings
        )
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoadingConversation {
                    ProgressView()
                        .tint(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 500)
                } else if messages.isEmpty {
                    ChatEmptyState(
                        suggestions: suggestions,
                        subtitle: "从一个餐饮经营问题开始"
                    ) { suggestion in
                        draft = suggestion.title
                        isComposerFocused = true
                    }
                } else {
                    ChatMessageList(
                        messages: messages,
                        streamingMessageID: streamingMessageID,
                        streamStatus: streamStatus
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 8)
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                isComposerFocused = false
            }
            .onChange(of: messages.last?.content) { _, _ in
                scrollToBottom(with: proxy)
            }
            .onChange(of: isWaitingForService) { _, _ in
                scrollToBottom(with: proxy)
            }
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isWaitingForService
    }

    /// 先插入空的助手消息占位，再把流式片段持续追加到同一条消息。
    private func sendMessage() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isWaitingForService else { return }

        let requestSessionID = activeSessionID ?? UUID().uuidString
        let assistantID = UUID().uuidString
        activeSessionID = requestSessionID

        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(ChatMessage(role: .user, content: content))
            messages.append(ChatMessage(id: assistantID, role: .assistant, content: ""))
            draft = ""
            isWaitingForService = true
            streamingMessageID = assistantID
            streamStatus = "正在连接"
        }
        isComposerFocused = false

        chatTask?.cancel()
        chatTask = Task {
            do {
                try await session.withAuthenticatedSession { token in
                    try await api.streamChat(
                        message: content,
                        sessionID: requestSessionID,
                        accessToken: token
                    ) { event in
                        await MainActor.run {
                            apply(event, to: assistantID)
                        }
                    }
                }
                finishStreamingMessage(assistantID)
                await loadHistory()
            } catch is CancellationError {
                finishStreamingMessage(assistantID)
            } catch {
                finishStreamingMessage(assistantID)
                presentedAlert = ChatAlert(
                    title: "发送失败",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func startNewConversation() {
        chatTask?.cancel()
        isComposerFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.removeAll()
            draft = ""
            isWaitingForService = false
            streamingMessageID = nil
            activeSessionID = nil
            activeTitle = "新对话"
        }
        closeSidebar()
    }

    private func openSidebar() {
        isComposerFocused = false
        withAnimation(.easeInOut(duration: 0.28)) {
            isSidebarOpen = true
        }
        Task { await loadHistory() }
    }

    private func closeSidebar() {
        withAnimation(.easeInOut(duration: 0.28)) {
            isSidebarOpen = false
        }
    }

    private func openSettings() {
        isComposerFocused = false
        closeSidebar()
        isSettingsPresented = true
    }

    /// 加载侧边栏历史，并同步当前会话可能被服务端更新的标题。
    private func loadHistory() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            history = try await session.withAuthenticatedSession { token in
                try await api.listChatSessions(accessToken: token)
            }
            if let activeSessionID,
               let activeSession = history.first(where: { $0.sessionID == activeSessionID }) {
                activeTitle = activeSession.title
            }
        } catch {
            presentedAlert = ChatAlert(
                title: "历史记录加载失败",
                message: error.localizedDescription
            )
        }
    }

    /// 等待侧边栏收起动画结束后加载所选历史会话。
    private func openConversation(_ item: ChatSessionSummary) {
        chatTask?.cancel()
        closeSidebar()
        isComposerFocused = false

        chatTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(280))
                isLoadingConversation = true
                let detail = try await session.withAuthenticatedSession { token in
                    try await api.chatSessionDetail(
                        sessionID: item.sessionID,
                        accessToken: token
                    )
                }
                try Task.checkCancellation()
                activeSessionID = detail.sessionID
                activeTitle = detail.title
                messages = detail.messages.compactMap(ChatMessage.init(historyMessage:))
                isLoadingConversation = false
            } catch is CancellationError {
                isLoadingConversation = false
            } catch {
                isLoadingConversation = false
                presentedAlert = ChatAlert(
                    title: "对话加载失败",
                    message: error.localizedDescription
                )
            }
        }
    }

    /// 将网络层流式事件合并进当前页面状态。
    private func apply(_ event: ChatStreamEvent, to messageID: String) {
        switch event {
        case .text(let text):
            guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
            messages[index].content += text
        case .metadata(let serverSessionID):
            if let serverSessionID, !serverSessionID.isEmpty {
                activeSessionID = serverSessionID
            }
        case .stage(let label):
            streamStatus = label
        case .done:
            break
        }
    }

    private func finishStreamingMessage(_ messageID: String) {
        if let index = messages.firstIndex(where: { $0.id == messageID }),
           messages[index].content.isEmpty {
            messages.remove(at: index)
        }
        isWaitingForService = false
        if streamingMessageID == messageID {
            streamingMessageID = nil
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        guard let lastID = messages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(SessionStore())
}
