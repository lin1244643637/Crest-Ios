import SwiftUI

struct ChatHeader: View {
    let title: String
    let onOpenSidebar: () -> Void
    let onNewConversation: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text("经营助手")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 2) {
                Button(action: onOpenSidebar) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开侧边栏")

                Spacer()

                Button(action: onNewConversation) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新对话")

                Button(action: onOpenSettings) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("账户")
            }
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 10)
        .frame(height: 56)
    }
}

struct ChatEmptyState: View {
    let suggestions: [ChatSuggestion]
    let onSelectSuggestion: (ChatSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 44)

            CrestMark()
                .padding(.bottom, 22)

            Text("今天想一起处理什么？")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("从一个经营问题开始")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 22)

                            Text(suggestion.title)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.09), lineWidth: 1)
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
}

struct ChatMessageList: View {
    let messages: [ChatMessage]
    let streamingMessageID: String?
    let streamStatus: String

    var body: some View {
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
}

struct ChatComposer: View {
    @Binding var draft: String
    @FocusState.Binding var isFocused: Bool
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.primary.opacity(0.08))

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "给 Crest 发消息",
                    text: $draft,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .font(.body)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(onSend)
                .padding(.leading, 14)
                .padding(.vertical, 11)

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            canSend
                                ? Color(uiColor: .systemBackground)
                                : Color.secondary.opacity(0.55)
                        )
                        .frame(width: 38, height: 38)
                        .background(
                            canSend ? Color.primary : Color.primary.opacity(0.07),
                            in: Circle()
                        )
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
                    .stroke(Color.primary.opacity(isFocused ? 0.22 : 0.11), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemBackground).opacity(0.82))
    }
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
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 12) {
                CrestMark(size: 30)
                if message.content.isEmpty, let loadingLabel {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.secondary)
                        Text(loadingLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 5)
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct CrestMark: View {
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.08))
            Circle()
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
            Text("C")
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.primary.opacity(0.1), radius: size * 0.42)
        .accessibilityHidden(true)
    }
}

struct ChatBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(
                    colorScheme == .dark
                        ? Color(white: 0.025)
                        : Color(white: 0.965)
                )
            )

            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -size.width * 0.3, y: size.height * 0.02))
            ribbon.addCurve(
                to: CGPoint(x: size.width * 1.28, y: size.height * 0.46),
                control1: CGPoint(x: size.width * 0.18, y: size.height * 0.38),
                control2: CGPoint(x: size.width * 0.78, y: -size.height * 0.12)
            )

            context.drawLayer { glow in
                glow.opacity = colorScheme == .dark ? 0.15 : 0.07
                glow.addFilter(.blur(radius: min(size.width, size.height) * 0.12))
                glow.stroke(
                    ribbon,
                    with: .linearGradient(
                        Gradient(
                            colors: colorScheme == .dark
                                ? [.clear, .white, .clear]
                                : [.clear, .black, .clear]
                        ),
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
                    Gradient(
                        colors: colorScheme == .dark
                            ? [.clear, .black.opacity(0.22), .black.opacity(0.82)]
                            : [.clear, .white.opacity(0.18), .white.opacity(0.68)]
                    ),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
