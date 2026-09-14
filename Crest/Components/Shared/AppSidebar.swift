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

                sidebarContent(bottomInset: geometry.safeAreaInsets.bottom)
                    .frame(width: geometry.size.width)
                    .ignoresSafeArea(edges: .bottom)
                    .offset(x: isPresented ? 0 : -geometry.size.width)
            }
        }
        .allowsHitTesting(isPresented)
        .accessibilityHidden(!isPresented)
        .animation(.easeInOut(duration: 0.28), value: isPresented)
    }

    private func sidebarContent(bottomInset: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Button(action: onNewConversation) {
                    Label("发起新对话", systemImage: "square.and.pencil")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppColors.secondaryText)
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
                .foregroundStyle(AppColors.secondaryText)
                .padding(.horizontal, 18)
                .frame(height: 48)

                Divider()
                    .overlay(AppColors.border)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                HStack {
                    Text("最近")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.secondaryText)
                    Spacer()
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 36, height: 36)
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("刷新历史记录")
                }
                .padding(.horizontal, 18)

                Group {
                    if isLoading && sessions.isEmpty {
                        ProgressView()
                            .tint(AppColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 64)
                    } else if filteredSessions.isEmpty {
                        Text(searchText.isEmpty ? "暂无对话记录" : "没有匹配的对话")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 64)
                    } else {
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
                                                ? AppColors.surface
                                                : .clear,
                                            in: RoundedRectangle(cornerRadius: 7)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
            }
            .padding(.top, 76)
            .padding(.bottom, 104 + bottomInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .clipped()
        .foregroundStyle(AppColors.primaryText)
        .background {
            AppColors.sidebarBackground
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            headerBar
        }
        .overlay(alignment: .bottom) {
            accountBar(bottomInset: bottomInset)
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

    private var headerBar: some View {
        HStack {
            Text("Crest")
                .font(.system(size: 26, weight: .semibold, design: .rounded))

            Spacer()

            Button(action: close) {
                Image(systemName: "xmark")
                    .foregroundStyle(AppColors.primaryText)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 25, height: 25)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(AppColors.primaryText)
            .accessibilityLabel("关闭侧边栏")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)

                AppColors.sidebarBackground
                    .opacity(0.96)
            }
                .ignoresSafeArea(edges: .top)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.78),
                            .init(color: .black.opacity(0.76), location: 0.9),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
    }

    private func accountBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Button {
                close()
                onOpenSettings()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(AppColors.secondaryText)

                    Text(username.isEmpty ? "账户" : username)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("账户设置")
        }
        .padding(.bottom, bottomInset)
        .background {
            BackdropBlur()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.18), location: 0.2),
                            .init(color: .black.opacity(0.48), location: 0.45),
                            .init(color: .black.opacity(0.78), location: 0.7),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .allowsHitTesting(false)
        }
    }

    private func close() {
        isPresented = false
    }
}
