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
    @State private var seed = Int.random(in: 0..<1_000_000)

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 60,
            paused: reduceMotion || scenePhase != .active
        )) { timeline in
            let time = reduceMotion ? 0 : max(0, timeline.date.timeIntervalSince(startedAt))

            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                let bounds = Path(CGRect(origin: .zero, size: size))
                context.fill(bounds, with: .color(.black))

                for index in 0..<4 {
                    drawRibbon(index, time: time, context: context, size: size)
                }

                context.fill(
                    bounds,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .black.opacity(0.24), location: 0),
                            .init(color: .clear, location: 0.2),
                            .init(color: .clear, location: 0.48),
                            .init(color: .black.opacity(0.66), location: 1)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawRibbon(_ index: Int, time: Double, context: GraphicsContext, size: CGSize) {
        let channel = index * 11
        let lane = 0.14 + CGFloat(index) * 0.25
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let shortSide = min(size.width, size.height)
        let widths: [CGFloat] = [0.50, 0.34, 0.24, 0.15]
        let width = shortSide * widths[index] * (1 + drift(time, channel: channel + 8) * 0.18)

        var path = Path()
        path.move(to: CGPoint(
            x: size.width * (lane + drift(time, channel: channel) * 0.44),
            y: size.height * -0.35
        ))
        path.addCurve(
            to: CGPoint(
                x: size.width * (1 - lane + drift(time, channel: channel + 1) * 0.55),
                y: size.height * 1.35
            ),
            control1: CGPoint(
                x: size.width * (lane + direction * 0.65 + drift(time, channel: channel + 2) * 0.75),
                y: size.height * (0.18 + drift(time, channel: channel + 3) * 0.16)
            ),
            control2: CGPoint(
                x: size.width * (1 - lane - direction * 0.65 + drift(time, channel: channel + 4) * 0.75),
                y: size.height * (0.72 + drift(time, channel: channel + 5) * 0.20)
            )
        )

        let lightPosition = drift(time, channel: channel + 6)
        let intensity = 0.80 + Double(drift(time, channel: channel + 7)) * 0.16
        let start = CGPoint(x: size.width * (-0.2 + lightPosition * 0.35), y: size.height * -0.1)
        let end = CGPoint(x: size.width * (1.1 + lightPosition * 0.25), y: size.height * 1.05)
        let surface = Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.12), location: 0.18),
            .init(color: .white.opacity(intensity * 0.64), location: 0.35),
            .init(color: .white.opacity(intensity), location: 0.48),
            .init(color: Color(white: 0.12).opacity(0.88), location: 0.65),
            .init(color: .white.opacity(0.22), location: 0.83),
            .init(color: .clear, location: 1)
        ])

        context.drawLayer { glow in
            glow.blendMode = .screen
            glow.opacity = 0.42
            glow.addFilter(.blur(radius: shortSide * 0.075))
            glow.stroke(
                path,
                with: .linearGradient(surface, startPoint: start, endPoint: end),
                style: StrokeStyle(lineWidth: width * 1.25, lineCap: .round)
            )
        }

        context.drawLayer { ribbon in
            ribbon.addFilter(.blur(radius: shortSide * (index == 0 ? 0.022 : 0.012)))
            ribbon.stroke(
                path,
                with: .linearGradient(surface, startPoint: start, endPoint: end),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        }

        context.drawLayer { reflection in
            reflection.blendMode = .screen
            reflection.addFilter(.blur(radius: shortSide * 0.024))
            reflection.stroke(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.1),
                        .init(color: .white.opacity(intensity * 0.50), location: 0.43),
                        .init(color: .white.opacity(intensity * 0.72), location: 0.52),
                        .init(color: .clear, location: 0.74)
                    ]),
                    startPoint: start,
                    endPoint: end
                ),
                style: StrokeStyle(lineWidth: width * 0.26, lineCap: .round)
            )
        }
    }

    // Independent schedules and quintic interpolation keep random targets smooth.
    private func drift(_ time: Double, channel: Int) -> CGFloat {
        let position = time / (9 + Double(channel % 7) * 1.3) + Double(channel) * 0.37
        let step = Int(floor(position))
        let fraction = position - floor(position)
        let eased = fraction * fraction * fraction * (fraction * (fraction * 6 - 15) + 10)
        let from = randomUnit(step: step, channel: channel)
        let to = randomUnit(step: step + 1, channel: channel)
        return CGFloat((from + (to - from) * eased) * 2 - 1)
    }

    private func randomUnit(step: Int, channel: Int) -> Double {
        let value = sin(Double(seed + step * 1013 + channel * 7919) * 12.9898) * 43758.5453
        return value - floor(value)
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionStore())
}
