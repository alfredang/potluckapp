import Foundation
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published var isWorking = false

    private let accessKey = "accessToken"
    private let refreshKey = "refreshToken"

    var isLoggedIn: Bool { currentUser != nil }

    /// Restore a previously saved session on launch.
    func restoreSession() async {
        guard let token = Keychain.get(accessKey) else { return }
        APIClient.shared.accessToken = token
        do {
            currentUser = try await PotluckService.me()
        } catch {
            // Token expired or invalid — clear it silently.
            signOut()
        }
    }

    func login(email: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }
        let result = try await PotluckService.login(email: email, password: password)
        persist(result)
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        isWorking = true
        defer { isWorking = false }
        let result = try await PotluckService.register(
            email: email, password: password, firstName: firstName, lastName: lastName
        )
        persist(result)
    }

    /// Permanently deletes the account on the server, then clears the local session.
    func deleteAccount() async throws {
        isWorking = true
        defer { isWorking = false }
        try await PotluckService.deleteAccount()
        signOut()
    }

    func signOut() {
        Keychain.delete(accessKey)
        Keychain.delete(refreshKey)
        APIClient.shared.accessToken = nil
        currentUser = nil
    }

    private func persist(_ result: AuthResult) {
        Keychain.set(result.accessToken, for: accessKey)
        Keychain.set(result.refreshToken, for: refreshKey)
        APIClient.shared.accessToken = result.accessToken
        currentUser = result.user
    }
}
