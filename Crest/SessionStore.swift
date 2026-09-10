import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var username = ""

    private let api = APIClient()
    private let keychain = KeychainStore(service: "com.blackwave.crest")

    init() {
        if keychain.readToken() != nil {
            isSignedIn = true
        }
    }

    func signIn(username: String, password: String) async throws {
        let response = try await api.login(username: username, password: password)
        keychain.saveToken(response.token)
        self.username = response.username
        isSignedIn = true
    }

    func signOut() {
        keychain.deleteToken()
        username = ""
        isSignedIn = false
    }
}
