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
                    .foregroundStyle(AppColors.secondaryText)
            }

            HStack(spacing: 2) {
                Button(action: onOpenSidebar) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("打开侧边栏")

                Spacer()

                Button(action: onNewConversation) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("新对话")

                Button(action: onOpenSettings) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("账户")
            }
        }
        .foregroundStyle(AppColors.primaryText)
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
                .foregroundStyle(AppColors.secondaryText)
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppColors.secondaryText)
                                .frame(width: 22)

                            Text(suggestion.title)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.tertiaryText)
                        }
                        .foregroundStyle(AppColors.primaryText)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.border, lineWidth: 1)
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
                .overlay(AppColors.border)

            HStack(alignment: .center, spacing: 10) {
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
                .padding(.vertical, 12)

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(!canSend)
                .accessibilityLabel("发送")
                .padding(.trailing, 2)
            }
            .background(AppColors.inputBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isFocused ? AppColors.secondaryText : AppColors.border, lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(AppColors.background)
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
                    .foregroundStyle(AppColors.primaryText)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 12) {
                CrestMark(size: 30)
                if message.content.isEmpty, let loadingLabel {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppColors.secondaryText)
                        Text(loadingLabel)
                            .font(.footnote)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 5)
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(AppColors.primaryText)
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
                .fill(AppColors.surface)
            Circle()
                .stroke(AppColors.border, lineWidth: 1)
            Text("C")
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.primaryText)
        }
        .frame(width: size, height: size)
        .shadow(color: AppColors.primaryText.opacity(0.1), radius: size * 0.42)
        .accessibilityHidden(true)
    }
}

struct ChatBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(AppColors.background)
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
                        colors: [.clear, AppColors.background.opacity(0.34), AppColors.background]
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
