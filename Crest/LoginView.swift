import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    private enum AuthStep: Hashable {
        case phone
        case password
        case verification
        case resetPassword
    }

    private enum FocusField: Hashable {
        case phone
        case password
        case verificationCode
        case newPassword
        case confirmPassword
    }

    private struct AuthNotice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private let api = APIClient()
    private let countryCode = "+86"

    @State private var step: AuthStep = .phone
    @State private var verificationPurpose: PhoneVerificationPurpose = .login
    @State private var phone = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var resetToken = ""
    @State private var isPasswordVisible = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var isLoading = false
    @State private var isSendingCode = false
    @State private var isVerifying = false
    @AppStorage("auth.sms.phone") private var storedVerificationPhone = ""
    @AppStorage("auth.sms.purpose") private var storedVerificationPurpose = ""
    @AppStorage("auth.sms.challengeID") private var storedVerificationChallengeID = ""
    @AppStorage("auth.sms.resendAvailableAt") private var storedResendAvailableAt = 0.0
    @State private var notice: AuthNotice?
    @State private var shouldReturnAfterNotice = false
    @FocusState private var focusedField: FocusField?

    private var canContinueWithPhone: Bool {
        !isLoading && phone.count == 11
    }

    private var canSubmitPassword: Bool {
        !isLoading && !password.isEmpty
    }

    private var canSubmitReset: Bool {
        !isLoading && !resetToken.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty
    }

    private var resendAvailableAt: Date {
        Date(timeIntervalSince1970: storedResendAvailableAt)
    }

    var body: some View {
        ZStack {
            AnimatedLoginBackground()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }

            VStack(spacing: 0) {
                Group {
                    if step == .phone {
                        Color.clear
                            .frame(height: 44)
                    } else {
                        authTopBar
                    }
                }
                .padding(.top, 12)

                Spacer(minLength: 0)

                panelContent
                    .id(step)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 20)
                    .animation(.easeInOut(duration: 0.28), value: step)
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 18)
        }
        .tint(.white)
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("好")) {
                    if shouldReturnAfterNotice {
                        shouldReturnAfterNotice = false
                        goBack()
                    }
                }
            )
        }
        .onChange(of: phone) { _, value in
            let digits = normalizedPhone(value)
            if digits != value {
                phone = digits
            }
        }
        .onChange(of: verificationCode) { _, value in
            let digits = String(value.filter { $0.isNumber }.prefix(6))
            if digits != value {
                verificationCode = digits
                return
            }
            if digits.count == 6 && !isSendingCode && !isVerifying {
                Task { await verifyCode() }
            }
        }
    }

    private var authTopBar: some View {
        HStack(spacing: 12) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Spacer()

            Text(stepLabel)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .monospacedDigit()
        }
        .frame(height: 44)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var panelContent: some View {
        switch step {
        case .phone:
            phonePanel
        case .password:
            passwordPanel
        case .verification:
            verificationPanel
        case .resetPassword:
            resetPasswordPanel
        }
    }

    private var phonePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Crest")
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.26), radius: 24)

            Text("纷繁之上，洞察经营")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 8)
                .padding(.bottom, 26)

            inputField {
                HStack(spacing: 10) {
                    Text(countryCode)
                        .foregroundStyle(.white.opacity(0.72))

                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 1, height: 20)

                    TextField(
                        "手机号",
                        text: $phone,
                        prompt: Text("请输入手机号").foregroundStyle(.white.opacity(0.48))
                    )
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .submitLabel(.continue)
                    .foregroundStyle(.white)
                    .focused($focusedField, equals: .phone)
                    .onSubmit {
                        Task { await continueWithPhone() }
                    }
                }
            }

            primaryButton(
                title: isLoading ? "识别中" : "Get start",
                isLoading: isLoading,
                isEnabled: canContinueWithPhone
            ) {
                Task { await continueWithPhone() }
            }
            .padding(.top, 14)
        }
    }

    private var passwordPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "欢迎回来", copy: formattedPhone)

            passwordInput(
                label: "密码",
                prompt: "请输入密码",
                text: $password,
                isVisible: $isPasswordVisible,
                focus: .password,
                isNewPassword: false
            ) {
                Task { await submitPassword() }
            }

            HStack {
                Button("验证码登录") {
                    Task { await beginVerification(.login) }
                }
                .disabled(isSendingCode)

                Spacer()

                Button("忘记密码") {
                    Task { await beginVerification(.resetPassword) }
                }
                .disabled(isSendingCode)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.68))
            .frame(minHeight: 44)
            .padding(.horizontal, 3)

            primaryButton(
                title: isLoading ? "登录中" : "登录",
                isLoading: isLoading,
                isEnabled: canSubmitPassword
            ) {
                Task { await submitPassword() }
            }
        }
    }

    private var verificationPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: verificationTitle, copy: verificationCopy)

            verificationCodeInput

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(ceil(resendAvailableAt.timeIntervalSince(context.date))))

                Button {
                    Task {
                        if await sendVerificationCode() {
                            await verifyCode()
                        }
                    }
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.72))
                        } else {
                            Text(remaining > 0 ? "\(remaining)s 后可重新发送" : "重新发送验证码")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
                .font(.footnote.weight(remaining > 0 ? .regular : .semibold))
                .foregroundStyle(.white.opacity(remaining > 0 ? 0.58 : 1))
                .disabled(remaining > 0 || isSendingCode || isVerifying)
            }
        }
    }

    private var resetPasswordPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "设置新密码", copy: "使用新的密码保护你的账号")

            passwordInput(
                label: "新密码",
                prompt: "请输入新密码",
                text: $newPassword,
                isVisible: $isNewPasswordVisible,
                focus: .newPassword,
                isNewPassword: true
            ) {
                focusedField = .confirmPassword
            }

            passwordInput(
                label: "再次输入新密码",
                prompt: "请再次输入新密码",
                text: $confirmPassword,
                isVisible: $isConfirmPasswordVisible,
                focus: .confirmPassword,
                isNewPassword: true
            ) {
                Task { await submitResetPassword() }
            }
            .padding(.top, 12)

            primaryButton(
                title: isLoading ? "提交中" : "确认",
                isLoading: isLoading,
                isEnabled: canSubmitReset
            ) {
                Task { await submitResetPassword() }
            }
            .padding(.top, 16)
        }
    }

    private var verificationCodeInput: some View {
        ZStack {
            TextField("验证码", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .verificationCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .opacity(0.02)
                .frame(height: 54)
                .disabled(isVerifying)
                .accessibilityLabel("六位验证码")

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let characters = Array(verificationCode)
                    let isActive = min(characters.count, 5) == index

                    Text(index < characters.count ? String(characters[index]) : "")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(isActive ? 0.72 : 0.18), lineWidth: 1)
                        }
                        .shadow(color: .white.opacity(isActive ? 0.09 : 0), radius: 8)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isVerifying {
                focusedField = .verificationCode
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func sectionHeader(title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(.white)

            Text(copy)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
                .lineSpacing(3)
        }
        .padding(.bottom, 11)
    }

    private func inputField<Content: View>(
        label: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: label == nil ? 0 : 8) {
            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
            }
            content()
        }
        .frame(minHeight: 54)
        .padding(.leading, 15)
        .padding(.trailing, 8)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private func passwordInput(
        label: String,
        prompt: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        focus: FocusField,
        isNewPassword: Bool,
        onSubmit: @escaping () -> Void
    ) -> some View {
        inputField {
            HStack(spacing: 6) {
                Group {
                    if isVisible.wrappedValue {
                        TextField(
                            label,
                            text: text,
                            prompt: Text(prompt).foregroundStyle(.white.opacity(0.48))
                        )
                    } else {
                        SecureField(
                            label,
                            text: text,
                            prompt: Text(prompt).foregroundStyle(.white.opacity(0.48))
                        )
                    }
                }
                .textContentType(isNewPassword ? .newPassword : .password)
                .submitLabel(isNewPassword && focus == .newPassword ? .next : .go)
                .foregroundStyle(.white)
                .focused($focusedField, equals: focus)
                .onSubmit(onSubmit)

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.67))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible.wrappedValue ? "隐藏密码" : "显示密码")
            }
        }
    }

    private func primaryButton(
        title: String,
        isLoading: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .tint(.black.opacity(0.78))
                }

                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.black.opacity(isEnabled ? 0.9 : 0.48))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white.opacity(isEnabled ? 0.92 : 0.42), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(isEnabled ? 0.92 : 0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isEnabled ? 0.2 : 0), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var stepLabel: String {
        switch step {
        case .phone:
            return ""
        case .password:
            return "已识别账号"
        case .verification:
            switch verificationPurpose {
            case .login:
                return "验证码登录"
            case .register:
                return "创建个人账号"
            case .resetPassword:
                return "找回密码"
            }
        case .resetPassword:
            return "重置密码"
        }
    }

    private var verificationTitle: String {
        switch verificationPurpose {
        case .login:
            return "输入验证码"
        case .register:
            return "验证手机号"
        case .resetPassword:
            return "确认是你"
        }
    }

    private var verificationCopy: String {
        switch verificationPurpose {
        case .login:
            return "验证码已发送至 \(maskedPhone)"
        case .register:
            return "完成验证后将直接进入 Crest"
        case .resetPassword:
            return "请输入发送至 \(maskedPhone) 的验证码"
        }
    }

    private var formattedPhone: String {
        guard phone.count == 11 else { return phone }
        let start = phone.index(phone.startIndex, offsetBy: 3)
        let end = phone.index(start, offsetBy: 4)
        return "\(phone[..<start]) \(phone[start..<end]) \(phone[end...])"
    }

    private var maskedPhone: String {
        guard phone.count >= 7 else { return "\(countryCode) \(phone)" }
        return "\(countryCode) \(phone.prefix(3)) **** \(phone.suffix(4))"
    }

    private func normalizedPhone(_ value: String) -> String {
        var digits = String(value.filter { $0.isNumber })
        if digits.count > 11 && digits.hasPrefix("86") {
            digits.removeFirst(2)
        }
        return String(digits.prefix(11))
    }

    private func continueWithPhone() async {
        guard canContinueWithPhone else { return }
        isLoading = true
        defer { isLoading = false }

        let request = PhoneRegistrationStatusRequest(
            phone: phone,
            countryCode: countryCode,
            clientType: "mobile"
        )
        let isRegistered = await api.isPhoneRegistered(request)

        if isRegistered {
            withAnimation(.easeInOut(duration: 0.28)) {
                step = .password
            }
        } else {
            await beginVerification(.register)
        }
    }

    private func submitPassword() async {
        guard canSubmitPassword else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await session.signIn(phone: phone, password: password)
        } catch {
            notice = AuthNotice(title: "登录失败", message: error.localizedDescription)
        }
    }

    private func beginVerification(_ purpose: PhoneVerificationPurpose) async {
        let remaining = verificationCooldownRemaining()
        if remaining > 0 {
            guard
                storedVerificationPhone == phone,
                storedVerificationPurpose == purpose.rawValue,
                !storedVerificationChallengeID.isEmpty
            else {
                showVerificationCooldownNotice(remaining: remaining)
                return
            }

            verificationPurpose = purpose
            verificationCode = ""
            withAnimation(.easeInOut(duration: 0.28)) {
                step = .verification
            }
            return
        }

        verificationPurpose = purpose
        verificationCode = ""
        withAnimation(.easeInOut(duration: 0.28)) {
            step = .verification
        }
        if await sendVerificationCode() {
            await verifyCode()
        }
    }

    @discardableResult
    private func sendVerificationCode() async -> Bool {
        guard !isSendingCode && !isVerifying else { return false }

        let remaining = verificationCooldownRemaining()
        guard remaining == 0 else {
            showVerificationCooldownNotice(remaining: remaining)
            return false
        }

        guard verificationPurpose != .register else {
            notice = AuthNotice(
                title: "注册暂未接入",
                message: "当前先开放手机号登录和找回密码。"
            )
            return false
        }

        verificationCode = ""
        storedVerificationPhone = phone
        storedVerificationPurpose = verificationPurpose.rawValue
        storedVerificationChallengeID = ""
        let sendStartedAt = Date()
        storedResendAvailableAt = sendStartedAt.addingTimeInterval(60).timeIntervalSince1970

        isSendingCode = true
        defer { isSendingCode = false }

        do {
            let response = try await api.sendPhoneCode(
                phone: phone,
                purpose: verificationPurpose
            )
            storedVerificationChallengeID = response.challengeID
            storedResendAvailableAt = sendStartedAt
                .addingTimeInterval(TimeInterval(response.resendAfter))
                .timeIntervalSince1970
            return true
        } catch {
            storedVerificationChallengeID = ""
            storedResendAvailableAt = 0
            shouldReturnAfterNotice = true
            notice = AuthNotice(title: "验证码发送失败", message: error.localizedDescription)
            return false
        }
    }

    private func verificationCooldownRemaining(at date: Date = Date()) -> Int {
        max(0, Int(ceil(resendAvailableAt.timeIntervalSince(date))))
    }

    private func showVerificationCooldownNotice(remaining: Int) {
        notice = AuthNotice(
            title: "操作频繁",
            message: "请稍等 \(remaining) 秒后再试。"
        )
    }

    private func verifyCode() async {
        guard verificationCode.count == 6, !isSendingCode, !isVerifying else { return }
        guard verificationPurpose != .register else {
            verificationCode = ""
            notice = AuthNotice(title: "功能暂未接入", message: "当前先开放手机号登录和找回密码。")
            focus(after: .verification)
            return
        }
        guard !storedVerificationChallengeID.isEmpty else {
            verificationCode = ""
            notice = AuthNotice(title: "验证码已失效", message: "请重新获取验证码。")
            focus(after: .verification)
            return
        }

        isVerifying = true
        defer { isVerifying = false }

        do {
            let response = try await api.confirmPhoneCode(
                challengeID: storedVerificationChallengeID,
                code: verificationCode
            )
            storedVerificationChallengeID = ""

            switch verificationPurpose {
            case .login:
                try await session.signInWithCode(verificationToken: response.verificationToken)
            case .resetPassword:
                resetToken = response.verificationToken
                newPassword = ""
                confirmPassword = ""
                withAnimation(.easeInOut(duration: 0.28)) {
                    step = .resetPassword
                }
            case .register:
                break
            }
        } catch {
            verificationCode = ""
            notice = AuthNotice(title: "验证码错误", message: error.localizedDescription)
            focus(after: .verification)
        }
    }

    private func submitResetPassword() async {
        guard canSubmitReset else { return }
        guard (7...16).contains(newPassword.count) else {
            notice = AuthNotice(title: "密码格式不正确", message: "新密码需要 7 至 16 位。")
            return
        }
        guard newPassword == confirmPassword else {
            notice = AuthNotice(title: "两次密码不一致", message: "请重新确认新密码。")
            confirmPassword = ""
            focusedField = .confirmPassword
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await api.resetPassword(
                verificationToken: resetToken,
                newPassword: newPassword
            )
            password = ""
            newPassword = ""
            confirmPassword = ""
            resetToken = ""
            verificationCode = ""
            withAnimation(.easeInOut(duration: 0.28)) {
                step = .password
            }
            notice = AuthNotice(title: "密码重置成功", message: response.message)
        } catch {
            notice = AuthNotice(title: "密码重置失败", message: error.localizedDescription)
        }
    }

    private func goBack() {
        focusedField = nil
        withAnimation(.easeInOut(duration: 0.28)) {
            switch step {
            case .phone:
                break
            case .password:
                password = ""
                step = .phone
            case .verification:
                verificationCode = ""
                step = verificationPurpose == .register ? .phone : .password
            case .resetPassword:
                resetToken = ""
                newPassword = ""
                confirmPassword = ""
                step = .password
            }
        }
    }

    private func focus(after target: AuthStep) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            switch target {
            case .phone:
                focusedField = .phone
            case .password:
                focusedField = .password
            case .verification:
                focusedField = .verificationCode
            case .resetPassword:
                focusedField = .newPassword
            }
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
        let channel = index * 100
        let lane: CGFloat = [-0.08, 0.62, 1.02, 0.28][index]
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let shortSide = min(size.width, size.height)
        let widths: [CGFloat] = [0.56, 0.38, 0.29, 0.19]
        let width = shortSide * widths[index] * (1 + drift(time, channel: channel + 8) * 0.18)

        let p0 = CGPoint(
            x: size.width * (lane + drift(time, channel: channel) * 0.44),
            y: size.height * -0.35
        )
        let p1 = CGPoint(
            x: size.width * (lane + direction * 0.65 + drift(time, channel: channel + 2) * 0.75),
            y: size.height * (0.18 + drift(time, channel: channel + 3) * 0.16)
        )
        let p2 = CGPoint(
            x: size.width * (1 - lane - direction * 0.65 + drift(time, channel: channel + 4) * 0.75),
            y: size.height * (0.72 + drift(time, channel: channel + 5) * 0.20)
        )
        let p3 = CGPoint(
            x: size.width * (1 - lane + drift(time, channel: channel + 1) * 0.55),
            y: size.height * 1.35
        )

        var samples: [(center: CGPoint, normal: CGPoint, width: CGFloat, bias: CGFloat, scatter: CGFloat)] = []
        for step in 0...80 {
            let t = CGFloat(step) / 80
            let u = 1 - t
            let along = Double(t) + time * 0.012
            let bend = variation(along * 4.3, time: time, channel: channel + 12)
            let detail = variation(along * 10.7, time: time, channel: channel + 25)
            let breadth = variation(along * 5.1, time: time, channel: channel + 40)
            let bias = variation(along * 7.4, time: time, channel: channel + 55)
            let scatter = variation(along * 3.8, time: time, channel: channel + 70)
            let dx = 3 * u * u * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * t * t * (p3.x - p2.x)
            let dy = 3 * u * u * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * t * t * (p3.y - p2.y)
            let length = max(hypot(dx, dy), 1)
            let normal = CGPoint(x: dy / length, y: -dx / length)
            let displacement = shortSide * (bend * 0.23 + detail * 0.045)
            let center = CGPoint(
                x: u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x + normal.x * displacement,
                y: u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y + normal.y * displacement
            )
            let localWidth = width * (0.16 + pow((breadth + 1) * 0.5, 1.6) * 1.4)
            samples.append((center, normal, localWidth, bias, scatter))
        }

        // Independent edges and a displaced outer contour let light feather into shadow.
        func contour(scale: CGFloat, dispersion: CGFloat, offset: CGFloat = 0) -> Path {
            var path = Path()
            for side in [CGFloat(1), -1] {
                for step in samples.indices {
                    let sample = samples[side > 0 ? step : samples.count - 1 - step]
                    let spread = shortSide * dispersion
                    let radius = sample.width * scale * (0.5 + side * sample.bias * 0.24)
                        + spread * (0.65 + sample.scatter * side * 0.35)
                    let distance = side * radius + sample.width * offset + spread * sample.scatter
                    let point = CGPoint(
                        x: sample.center.x + sample.normal.x * distance,
                        y: sample.center.y + sample.normal.y * distance
                    )
                    if side > 0 && step == 0 { path.move(to: point) }
                    else { path.addLine(to: point) }
                }
            }
            path.closeSubpath()
            return path
        }

        let lightPosition = drift(time, channel: channel + 6)
        let intensity = 0.72 + Double(drift(time, channel: channel + 7)) * 0.16
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
            glow.opacity = 0.62
            glow.addFilter(.blur(radius: shortSide * 0.14))
            glow.fill(
                contour(scale: 1.5, dispersion: 0.20),
                with: .linearGradient(surface, startPoint: start, endPoint: end)
            )
        }

        context.drawLayer { ribbon in
            ribbon.addFilter(.blur(radius: shortSide * (index == 0 ? 0.045 : 0.028)))
            ribbon.fill(
                contour(scale: 1, dispersion: 0),
                with: .linearGradient(surface, startPoint: start, endPoint: end)
            )
        }

        context.drawLayer { reflection in
            reflection.blendMode = .screen
            reflection.addFilter(.blur(radius: shortSide * 0.035))
            reflection.fill(
                contour(scale: 0.24, dispersion: 0.025, offset: -0.20),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.1),
                        .init(color: .white.opacity(intensity * 0.50), location: 0.43),
                        .init(color: .white.opacity(intensity * 0.72), location: 0.52),
                        .init(color: .clear, location: 0.74)
                    ]),
                    startPoint: start,
                    endPoint: end
                )
            )
        }
    }

    private func variation(_ position: Double, time: Double, channel: Int) -> CGFloat {
        let step = Int(floor(position))
        let fraction = position - floor(position)
        let eased = CGFloat(fraction * fraction * (3 - 2 * fraction))
        let from = drift(time, channel: channel + step)
        let to = drift(time, channel: channel + step + 1)
        return from + (to - from) * eased
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
