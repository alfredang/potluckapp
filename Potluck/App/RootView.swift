import SwiftUI

struct RootView: View {
    @State private var selection = ScreenshotConfig.initialTab

    var body: some View {
        TabView(selection: $selection) {
            ExploreView()
                .tabItem { Label("Explore", systemImage: "sparkles") }.tag(0)
            DishesView()
                .tabItem { Label("Dishes", systemImage: "fork.knife") }.tag(1)
            BookingsView()
                .tabItem { Label("Bookings", systemImage: "calendar") }.tag(2)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(3)
        }
        .tint(Theme.terracotta)
    }
}

/// Reads environment variables used only to drive deterministic screenshots.
enum ScreenshotConfig {
    private static func env(_ key: String) -> String? { ProcessInfo.processInfo.environment[key] }
    static var initialTab: Int { Int(env("POTLUCK_TAB") ?? "") ?? 0 }
    static var openFirstChef: Bool { env("POTLUCK_OPEN_CHEF") == "1" }
}

/// Cuisine categories shown as quick filters (slugs match the API `category` param).
enum Cuisine: String, CaseIterable, Identifiable {
    case chinese, western, thai, japanese, korean, malay, indian, halal, vegetarian
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .chinese: return "🥟"
        case .western: return "🍝"
        case .thai: return "🍜"
        case .japanese: return "🍱"
        case .korean: return "🍲"
        case .malay: return "🍛"
        case .indian: return "🍛"
        case .halal: return "🥘"
        case .vegetarian: return "🥗"
        }
    }
}
