import SwiftUI

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
    @State private var presentedAlert: ChatAlert?
    @State private var chatTask: Task<Void, Never>?

    private let suggestions = [
        ChatSuggestion(icon: "chart.line.uptrend.xyaxis", title: "分析本月经营情况"),
        ChatSuggestion(icon: "exclamationmark.magnifyingglass", title: "找出最近的异常费用"),
        ChatSuggestion(icon: "doc.text", title: "生成一份经营摘要")
    ]

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = min(geometry.size.width * 0.88, 370)

            ZStack(alignment: .leading) {
                chatContent

                Color.black.opacity(isSidebarOpen ? 0.48 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .allowsHitTesting(isSidebarOpen)
                    .onTapGesture(perform: closeSidebar)
                    .zIndex(1)

                sidebar
                    .frame(width: sidebarWidth)
                    .offset(x: isSidebarOpen ? 0 : -sidebarWidth)
                    .allowsHitTesting(isSidebarOpen)
                    .accessibilityHidden(!isSidebarOpen)
                    .zIndex(2)
            }
            .animation(.easeInOut(duration: 0.28), value: isSidebarOpen)
        }
        .preferredColorScheme(.dark)
        .tint(.white)
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
    }

    private var chatContent: some View {
        ZStack {
            ChatBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Divider()
                    .overlay(.white.opacity(0.08))

                conversation
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(activeTitle)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text("经营助手")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
            }

            HStack(spacing: 2) {
                Button(action: openSidebar) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开侧边栏")

                Spacer()

                Button(action: startNewConversation) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新对话")

                Menu {
                    if !session.username.isEmpty {
                        Text(session.username)
                    }

                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("账户")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 56)
    }

    private var sidebar: some View {
        ChatSidebar(
            username: session.username,
            sessions: history,
            activeSessionID: activeSessionID,
            searchText: $historySearch,
            isLoading: isLoadingHistory,
            onClose: closeSidebar,
            onNewConversation: startNewConversation,
            onSelectSession: openConversation,
            onRefresh: {
                Task { await loadHistory() }
            },
            onSignOut: session.signOut
        )
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoadingConversation {
                    ProgressView()
                        .tint(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 500)
                } else if messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
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

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 44)

            CrestMark()
                .padding(.bottom, 22)

            Text("今天想一起处理什么？")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("从一个经营问题开始")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.52))
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(suggestions) { suggestion in
                    Button {
                        draft = suggestion.title
                        isComposerFocused = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(width: 22)

                            Text(suggestion.title)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.36))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.09), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 34)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: 560, minHeight: 500)
    }

    private var messageList: some View {
        LazyVStack(spacing: 22) {
            ForEach(messages) { message in
                MessageRow(
                    message: message,
                    loadingLabel: message.id == streamingMessageID ? streamStatus : nil
                )
                    .id(message.id)
            }
        }
        .frame(maxWidth: 680)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(.white.opacity(0.08))

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "给 Crest 发消息",
                    text: $draft,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .font(.body)
                .focused($isComposerFocused)
                .submitLabel(.send)
                .onSubmit(sendMessage)
                .padding(.leading, 14)
                .padding(.vertical, 11)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? .black : .white.opacity(0.3))
                        .frame(width: 38, height: 38)
                        .background(canSend ? .white : .white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("发送")
                .padding(.trailing, 5)
                .padding(.bottom, 5)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(isComposerFocused ? 0.22 : 0.11), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.black.opacity(0.72))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isWaitingForService
    }

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

private struct ChatMessage: Identifiable {
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

private struct ChatAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ChatSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
}

private struct MessageRow: View {
    let message: ChatMessage
    let loadingLabel: String?

    var body: some View {
        switch message.role {
        case .user:
            HStack(alignment: .top) {
                Spacer(minLength: 54)
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 12) {
                CrestMark(size: 30)
                if message.content.isEmpty, let loadingLabel {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white.opacity(0.72))
                        Text(loadingLabel)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 5)
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct ChatSidebar: View {
    let username: String
    let sessions: [ChatSessionSummary]
    let activeSessionID: String?
    @Binding var searchText: String
    let isLoading: Bool
    let onClose: () -> Void
    let onNewConversation: () -> Void
    let onSelectSession: (ChatSessionSummary) -> Void
    let onRefresh: () -> Void
    let onSignOut: () -> Void

    private var filteredSessions: [ChatSessionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Crest")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭侧边栏")
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            Button(action: onNewConversation) {
                Label("发起新对话", systemImage: "square.and.pencil")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.55))
                TextField("搜索对话内容", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .frame(width: 22)
                Text("库")
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 18)
            .frame(height: 48)

            Divider()
                .overlay(.white.opacity(0.08))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

            HStack {
                Text("最近")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.48))
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .accessibilityLabel("刷新历史记录")
            }
            .padding(.horizontal, 18)

            Group {
                if isLoading && sessions.isEmpty {
                    ProgressView()
                        .tint(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredSessions.isEmpty {
                    Text(searchText.isEmpty ? "暂无对话记录" : "没有匹配的对话")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.42))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredSessions) { item in
                                Button {
                                    onSelectSession(item)
                                } label: {
                                    Text(item.title)
                                        .font(.body)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .frame(height: 48)
                                        .background(
                                            item.sessionID == activeSessionID
                                                ? .white.opacity(0.09)
                                                : .clear,
                                            in: RoundedRectangle(cornerRadius: 7)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }

            Divider()
                .overlay(.white.opacity(0.08))

            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.72))

                Text(username.isEmpty ? "账户" : username)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button(role: .destructive, action: onSignOut) {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("账户设置")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .padding(.top, 10)
        .background {
            Color(white: 0.055)
                .ignoresSafeArea()
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -50 {
                        onClose()
                    }
                }
        )
    }
}

private struct CrestMark: View {
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
            Text("C")
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.12), radius: size * 0.42)
        .accessibilityHidden(true)
    }
}

private struct ChatBackdrop: View {
    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(white: 0.025))
            )

            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -size.width * 0.3, y: size.height * 0.02))
            ribbon.addCurve(
                to: CGPoint(x: size.width * 1.28, y: size.height * 0.46),
                control1: CGPoint(x: size.width * 0.18, y: size.height * 0.38),
                control2: CGPoint(x: size.width * 0.78, y: -size.height * 0.12)
            )

            context.drawLayer { glow in
                glow.opacity = 0.15
                glow.addFilter(.blur(radius: min(size.width, size.height) * 0.12))
                glow.stroke(
                    ribbon,
                    with: .linearGradient(
                        Gradient(colors: [.clear, .white, .clear]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height * 0.5)
                    ),
                    style: StrokeStyle(
                        lineWidth: min(size.width, size.height) * 0.28,
                        lineCap: .round
                    )
                )
            }

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [.clear, .black.opacity(0.22), .black.opacity(0.82)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ChatView()
        .environmentObject(SessionStore())
}
