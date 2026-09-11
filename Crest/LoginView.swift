import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var canSubmit: Bool {
        !isLoading && !username.isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            AnimatedLoginBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Crest")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer()

                    Button("Login") {
                        Task { await submit() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 76, minHeight: 44)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    }
                    .disabled(!canSubmit)
                }
                .padding(.top, 12)

                Spacer(minLength: 0)

                VStack(spacing: 30) {

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 12) {
                            Text("Crest")
                                .font(.system(size: 42, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.76)
                                .shadow(color: .white.opacity(0.28), radius: 24)

                            Text("沉浸式智能助理，即刻进入对话。")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.78))
                                .multilineTextAlignment(.leading)
                                .shadow(color: .black.opacity(0.42), radius: 14)
                            field(systemImage: "person") {
                                TextField("用户名", text: $username, prompt: Text("请输入手机号").foregroundStyle(.white.opacity(0.48)))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textContentType(.username)
                                    .submitLabel(.next)
                                    .foregroundStyle(.white)
                            }

                            field(systemImage: "lock") {
                                SecureField("密码", text: $password, prompt: Text("请输入密码").foregroundStyle(.white.opacity(0.48)))
                                    .textContentType(.password)
                                    .submitLabel(.go)
                                    .foregroundStyle(.white)
                                    .onSubmit {
                                        Task { await submit() }
                                    }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.36))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(isLoading ? "登录中" : "Get Started")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white.opacity(canSubmit ? 0.18 : 0.1), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(canSubmit ? 0.34 : 0.14), lineWidth: 1)
                            }
                            .shadow(color: Color(red: 0.14, green: 0.35, blue: 1).opacity(canSubmit ? 0.32 : 0), radius: 28, x: 0, y: 16)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmit)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 34, x: 0, y: 22)

                }
                .padding(.bottom, 22)
            }
            .padding(.horizontal, 24)
        }
        .tint(.white)
    }

    private func field<Content: View>(systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .frame(width: 22)

            content()
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await session.signIn(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AnimatedLoginBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 60,
            paused: reduceMotion || scenePhase != .active
        )) { timeline in
            let time = reduceMotion ? 4 : timeline.date.timeIntervalSince(startedAt)

            Rectangle()
                .fill(.black)
                .visualEffect { content, geometry in
                    content.colorEffect(
                        ShaderLibrary.monochromeFlow(
                            .float2(geometry.size),
                            .float(time)
                        )
                    )
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionStore())
}
