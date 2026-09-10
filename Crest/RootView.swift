import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.isSignedIn {
                ChatView()
            } else {
                LoginView()
            }
        }
    }
}
