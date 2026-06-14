import SwiftUI

@main
struct PotluckApp: App {
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .tint(Theme.terracotta)
                .task { await auth.restoreSession() }
        }
    }
}
