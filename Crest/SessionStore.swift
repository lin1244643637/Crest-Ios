import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var isRestoringSession: Bool
    @Published private(set) var username = ""

    private let api = APIClient()
    private let keychain = KeychainStore(service: "com.blackwave.crest")
    private var accessToken: String?
    private var refreshTask: Task<LoginResponse, Error>?
    private var didAttemptRestore = false
    private var sessionEpoch = 0

    init() {
        isRestoringSession = keychain.readRefreshToken() != nil
    }

    func signIn(phone: String, password: String) async throws {
        do {
            let response = try await api.login(phone: phone, password: password)
            try startSession(with: response)
        } catch {
            clearLocalSession()
            throw error
        }
    }

    func signInWithCode(verificationToken: String) async throws {
        do {
            let response = try await api.loginWithCode(verificationToken: verificationToken)
            try startSession(with: response)
        } catch {
            clearLocalSession()
            throw error
        }
    }

    func restoreSession() async {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true
        defer { isRestoringSession = false }

        guard keychain.readRefreshToken() != nil else {
            clearLocalSession()
            return
        }
        if !(await refreshStoredSession()) {
            accessToken = nil
            username = ""
            isSignedIn = false
        }
    }

    func signOut() {
        let refreshToken = keychain.readRefreshToken()
        clearLocalSession()

        guard let refreshToken else { return }
        Task {
            try? await api.logout(refreshToken: refreshToken)
        }
    }

    func withAuthenticatedSession<Result>(
        _ operation: (String) async throws -> Result
    ) async throws -> Result {
        if shouldRefreshAccessToken(accessToken) {
            _ = await refreshStoredSession()
        }
        guard let token = accessToken, isSignedIn else {
            throw APIError.invalidSession
        }

        do {
            return try await operation(token)
        } catch let error as APIError where error.isUnauthorized {
            let refreshed: Bool
            if accessToken != token {
                refreshed = true
            } else {
                refreshed = await refreshStoredSession()
            }
            guard refreshed, let retryToken = accessToken else {
                clearLocalSession()
                throw APIError.invalidSession
            }

            do {
                return try await operation(retryToken)
            } catch let retryError as APIError where retryError.isUnauthorized {
                clearLocalSession()
                throw APIError.invalidSession
            }
        }
    }

    private func startSession(with response: LoginResponse) throws {
        sessionEpoch += 1
        refreshTask?.cancel()
        refreshTask = nil
        try apply(response)
    }

    private func apply(_ response: LoginResponse) throws {
        guard let refreshToken = response.refreshToken, !refreshToken.isEmpty else {
            throw APIError.invalidSession
        }
        try keychain.saveRefreshToken(refreshToken)
        accessToken = response.token
        username = response.username
        isSignedIn = true
    }

    private func refreshStoredSession() async -> Bool {
        let epoch = sessionEpoch
        do {
            let response = try await refreshResponse()
            guard epoch == sessionEpoch else { return false }
            try apply(response)
            return true
        } catch {
            guard epoch == sessionEpoch else { return false }
            if let apiError = error as? APIError, apiError.invalidatesSession {
                clearLocalSession()
            }
            return false
        }
    }

    private func refreshResponse() async throws -> LoginResponse {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let refreshToken = keychain.readRefreshToken() else {
            throw APIError.invalidSession
        }

        let task = Task {
            try await api.refreshSession(refreshToken: refreshToken)
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func clearLocalSession() {
        sessionEpoch += 1
        refreshTask?.cancel()
        refreshTask = nil
        accessToken = nil
        keychain.deleteSessionTokens()
        username = ""
        isSignedIn = false
    }

    private func shouldRefreshAccessToken(_ token: String?) -> Bool {
        guard let token else { return false }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return false }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expiration = object["exp"] as? NSNumber
        else {
            return false
        }
        return expiration.doubleValue - Date().timeIntervalSince1970 <= 6 * 60 * 60
    }
}
