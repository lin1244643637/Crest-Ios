import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.isRestoringSession {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    ProgressView()
                        .tint(.secondary)
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
