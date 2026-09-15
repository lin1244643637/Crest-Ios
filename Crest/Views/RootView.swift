import SwiftUI

/// 根据会话恢复结果切换启动加载、登录页和聊天主页。
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.isRestoringSession {
                ZStack {
                    AppColors.background.ignoresSafeArea()
                    ProgressView()
                        .tint(AppColors.secondaryText)
                }
            } else if session.isSignedIn {
                ChatView()
            } else {
                LoginView()
            }
        }
        .task {
            await session.restoreSession()
        }
    }
}

/// 为验证码注册且尚未设置密码的用户补充首次密码。
struct InitialPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        (7...16).contains(password.count)
            && password == confirmation
            && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("设置密码") {
                    SecureField("7 至 16 位密码", text: $password)
                        .textContentType(.newPassword)
                    SecureField("再次输入密码", text: $confirmation)
                        .textContentType(.newPassword)
                }
            }
            .navigationTitle("完善密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit)
                }
            }
            .alert(
                "密码设置失败",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "请稍后重试")
            }
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await session.setInitialPassword(password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
