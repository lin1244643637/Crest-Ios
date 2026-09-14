import SwiftUI

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
                if session.tenantID == nil {
                    PersonalAccountHomeView()
                } else {
                    ChatView()
                }
            } else {
                LoginView()
            }
        }
        .task {
            await session.restoreSession()
        }
    }
}

private struct PersonalAccountHomeView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var isSettingPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppColors.secondaryText)
                    Text("个人空间")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.primaryText)
                    Text(session.username)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .safeAreaInset(edge: .top) {
                if !session.hasPassword {
                    Button {
                        isSettingPassword = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.badge.plus")
                            Text("完善密码")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppColors.primaryText)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(AppColors.surface)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Crest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: session.signOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("退出登录")
                }
            }
        }
        .sheet(isPresented: $isSettingPassword) {
            InitialPasswordView()
                .environmentObject(session)
                .presentationDetents([.medium])
        }
    }
}

private struct InitialPasswordView: View {
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
