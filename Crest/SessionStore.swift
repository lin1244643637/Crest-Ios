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

    func signIn(phone: String, password: String) async throws {
        let response = try await api.login(phone: phone, password: password)
        apply(response)
    }

    func signInWithCode(verificationToken: String) async throws {
        let response = try await api.loginWithCode(verificationToken: verificationToken)
        apply(response)
    }

    private func apply(_ response: LoginResponse) {
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
