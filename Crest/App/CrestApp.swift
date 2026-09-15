import SwiftUI

@main
/// 应用入口，持有全局唯一的登录会话。
struct CrestApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            AppRoot(session: session)
        }
    }
}

/// 在进入业务页面前统一注入会话和主题环境。
private struct AppRoot: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage(AppTheme.storageKey) private var selectedTheme = AppTheme.dark.rawValue

    @ObservedObject var session: SessionStore

    var body: some View {
        RootView()
            .environmentObject(session)
            .environment(\.systemColorScheme, systemColorScheme)
            .preferredColorScheme(
                session.isSignedIn
                    ? AppTheme(rawValue: selectedTheme)?.colorScheme
                    : .dark
            )
    }
}
