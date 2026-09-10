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
                    VStack(spacing: 12) {
                        Text("Your AGI Agent")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                            .shadow(color: .white.opacity(0.28), radius: 24)

                        Text("沉浸式智能助理，即刻进入对话。")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.42), radius: 14)
                    }
                    .padding(.horizontal, 12)

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 12) {
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

                    HStack(spacing: 14) {
                        Rectangle()
                            .fill(.white.opacity(0.34))
                            .frame(height: 1)

                        Text("1.0x")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))

                        Rectangle()
                            .fill(.white.opacity(0.24))
                            .frame(width: 1, height: 18)

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 22)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
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

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                var context = context
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let rect = CGRect(origin: .zero, size: size)

                context.fill(Path(rect), with: .color(.black))
                drawExpandedBlooms(in: &context, size: size, time: time)
                drawFullScreenLightSheets(in: &context, size: size, time: time)
                drawLightEdges(in: &context, size: size, time: time)
                drawFineGrain(in: &context, size: size)
                drawVignette(in: &context, size: size)
            }
        }
    }

    private func drawExpandedBlooms(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let longSide = max(size.width, size.height)
        let blooms: [(x: CGFloat, y: CGFloat, radius: CGFloat, opacity: Double, seed: Double)] = [
            (0.18, 0.24, 1.18, 0.86, 0.35),
            (0.54, 0.42, 1.02, 0.52, 1.45),
            (0.28, 0.72, 0.9, 0.42, 2.35),
            (0.88, 0.2, 0.94, 0.34, 3.2)
        ]

        for bloom in blooms {
            let center = CGPoint(
                x: size.width * (bloom.x + wave(time, bloom.seed, speed: 0.06) * 0.18),
                y: size.height * (bloom.y + wave(time, bloom.seed + 1.6, speed: 0.052) * 0.16)
            )
            let radius = longSide * bloom.radius

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: longSide * 0.075))
                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: .white.opacity(bloom.opacity), location: 0),
                            .init(color: .white.opacity(bloom.opacity * 0.56), location: 0.28),
                            .init(color: .white.opacity(bloom.opacity * 0.16), location: 0.66),
                            .init(color: .clear, location: 1)
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
    }

    private func drawFullScreenLightSheets(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let longSide = max(size.width, size.height)
        let widths: [CGFloat] = [0.5, 0.4, 0.46, 0.34]
        let opacities: [Double] = [0.74, 0.54, 0.46, 0.36]

        for index in 0..<4 {
            let path = sheetPath(index: index, time: time, size: size)

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: longSide * (0.05 + CGFloat(index) * 0.008)))
                layer.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0.04),
                            .init(color: .white.opacity(opacities[index] * 0.42), location: 0.28),
                            .init(color: .white.opacity(opacities[index]), location: 0.52),
                            .init(color: .white.opacity(opacities[index] * 0.34), location: 0.76),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: CGPoint(x: size.width * -0.1, y: size.height * 0.08),
                        endPoint: CGPoint(x: size.width * 1.05, y: size.height * 0.92)
                    ),
                    style: StrokeStyle(lineWidth: longSide * widths[index], lineCap: .round, lineJoin: .round)
                )
            }

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: longSide * 0.012))
                layer.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0.14),
                            .init(color: .white.opacity(opacities[index] * 0.18), location: 0.44),
                            .init(color: .white.opacity(opacities[index] * 0.5), location: 0.52),
                            .init(color: .white.opacity(opacities[index] * 0.12), location: 0.62),
                            .init(color: .clear, location: 0.88)
                        ]),
                        startPoint: CGPoint(x: size.width * -0.12, y: size.height * 0.02),
                        endPoint: CGPoint(x: size.width * 1.14, y: size.height * 0.96)
                    ),
                    style: StrokeStyle(lineWidth: longSide * 0.032, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func drawLightEdges(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let longSide = max(size.width, size.height)

        for index in 0..<7 {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: CGFloat(index % 2) * 0.8))
                layer.stroke(
                    edgePath(index: index, time: time, size: size),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.32), location: 0.36),
                            .init(color: .white.opacity(0.78), location: 0.5),
                            .init(color: .white.opacity(0.22), location: 0.68),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: size.height * 0.1),
                        endPoint: CGPoint(x: size.width, y: size.height * 0.9)
                    ),
                    style: StrokeStyle(lineWidth: max(1.4, longSide * (0.0016 + CGFloat(index % 3) * 0.0007)), lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func drawFineGrain(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<70 {
            let x = size.width * randomUnit(5000 + index * 17)
            let y = size.height * randomUnit(7000 + index * 19)
            let radius = CGFloat(0.6 + randomUnit(9000 + index * 23) * 0.9)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                with: .color(.white.opacity(0.055))
            )
        }
    }

    private func drawVignette(in context: inout GraphicsContext, size: CGSize) {
        let rect = Path(CGRect(origin: .zero, size: size))

        context.fill(
            rect,
            with: .linearGradient(
                Gradient(colors: [.black.opacity(0.12), .clear, .black.opacity(0.76)]),
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )

        context.fill(
            rect,
            with: .linearGradient(
                Gradient(colors: [.black.opacity(0.38), .clear, .black.opacity(0.66)]),
                startPoint: CGPoint(x: 0, y: size.height / 2),
                endPoint: CGPoint(x: size.width, y: size.height / 2)
            )
        )
    }

    private func sheetPath(index: Int, time: Double, size: CGSize) -> Path {
        let seed = Double(index) * 1.6 + 0.8
        let offset = CGFloat(index) * 0.2
        let startY = size.height * (-0.22 + offset + wave(time, seed, speed: 0.045) * 0.24)
        let endY = size.height * (0.34 + offset + wave(time, seed + 2, speed: 0.038) * 0.28)

        var path = Path()
        path.move(to: CGPoint(x: size.width * -0.42, y: startY))
        path.addCurve(
            to: CGPoint(x: size.width * 1.48, y: endY),
            control1: CGPoint(x: size.width * 0.16, y: size.height * (0.94 - offset + wave(time, seed + 3, speed: 0.04) * 0.28)),
            control2: CGPoint(x: size.width * 0.68, y: size.height * (-0.34 + offset + wave(time, seed + 5, speed: 0.036) * 0.34))
        )

        return path
    }

    private func edgePath(index: Int, time: Double, size: CGSize) -> Path {
        let seed = Double(index) * 0.9 + 1.2
        let x = size.width * (0.16 + CGFloat(index) * 0.13 + wave(time, seed, speed: 0.04) * 0.08)
        let lean = size.width * (0.16 + wave(time, seed + 4, speed: 0.035) * 0.1)

        var path = Path()
        path.move(to: CGPoint(x: x, y: size.height * -0.16))
        path.addCurve(
            to: CGPoint(x: x + lean, y: size.height * 1.16),
            control1: CGPoint(x: x - size.width * 0.28, y: size.height * 0.2),
            control2: CGPoint(x: x + size.width * 0.42, y: size.height * 0.68)
        )

        return path
    }

    private func randomUnit(_ seed: Int) -> CGFloat {
        let value = sin(Double(seed) * 12.9898) * 43758.5453123
        return CGFloat(value - floor(value))
    }

    private func wave(_ time: Double, _ seed: Double, speed: Double) -> CGFloat {
        CGFloat((sin(time * speed + seed) + cos(time * speed * 0.62 + seed * 1.7)) * 0.5)
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionStore())
}
