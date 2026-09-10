import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var message = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("今天想看什么？")
                            .font(.title2.weight(.semibold))
                        Text("原生 iOS 骨架已接入登录态。下一步可以把现有对话 SSE 和经营摘要接进来。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                }

                HStack(spacing: 10) {
                    TextField("输入消息", text: $message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        message = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("对话")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("退出") {
                        session.signOut()
                    }
                }
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(SessionStore())
}
