import SwiftUI

@main
struct CrestApp: App {
    @StateObject private var session = SessionStore()
    @AppStorage(AppTheme.storageKey) private var selectedTheme = AppTheme.dark.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(
                    session.isSignedIn
                        ? AppTheme(rawValue: selectedTheme)?.colorScheme
                        : .dark
                )
        }
    }
}
