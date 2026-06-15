import SwiftUI
import UIKit

@main
struct PotluckApp: App {
    @StateObject private var auth = AuthManager()

    init() {
        // Force strong, high-contrast navigation titles on the cream background.
        // (On iOS 26 the default label color renders washed-out over a light tint.)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.background)
        appearance.shadowColor = .clear
        let dark = UIColor(Theme.ink)
        appearance.titleTextAttributes = [.foregroundColor: dark]
        appearance.largeTitleTextAttributes = [.foregroundColor: dark]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .tint(Theme.terracotta)
                .task { await auth.restoreSession() }
        }
    }
}
