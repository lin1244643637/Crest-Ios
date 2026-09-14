import SwiftUI

struct AppSidebar: View {
    @Binding var isPresented: Bool
    let username: String
    let sessions: [ChatSessionSummary]
    let activeSessionID: String?
    @Binding var searchText: String
    let isLoading: Bool
    let onNewConversation: () -> Void
    let onSelectSession: (ChatSessionSummary) -> Void
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void

    private var filteredSessions: [ChatSessionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.black.opacity(isPresented ? 0.48 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)

                sidebarContent
                    .frame(width: geometry.size.width)
                    .offset(x: isPresented ? 0 : -geometry.size.width)
            }
        }
        .allowsHitTesting(isPresented)
        .accessibilityHidden(!isPresented)
        .animation(.easeInOut(duration: 0.28), value: isPresented)
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Crest")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))

                Spacer()

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.07), in: Circle())
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
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
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
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .frame(height: 48)

            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

            HStack {
                Text("最近")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
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
                        .tint(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredSessions.isEmpty {
                    Text(searchText.isEmpty ? "暂无对话记录" : "没有匹配的对话")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                                                ? Color.primary.opacity(0.08)
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
                .overlay(Color.primary.opacity(0.08))

            Button {
                close()
                onOpenSettings()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)

                    Text(username.isEmpty ? "账户" : username)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("账户设置")
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .foregroundStyle(Color.primary)
        .padding(.top, 10)
        .background {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -50 {
                        close()
                    }
                }
        )
    }

    private func close() {
        isPresented = false
    }
}
