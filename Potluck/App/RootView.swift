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

/// Cuisine categories shown as quick filters. Slugs match the API menu `category` param
/// (the eight categories the backend actually serves). Ordered Singapore-local first.
enum Cuisine: String, CaseIterable, Identifiable {
    case malay, chinese, indian, halal, vegetarian, japanese, korean, western
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .malay: return "🍛"      // nasi lemak, rendang
        case .chinese: return "🥟"
        case .indian: return "🫓"     // roti prata
        case .halal: return "🥘"
        case .vegetarian: return "🥗"
        case .japanese: return "🍱"
        case .korean: return "🍜"
        case .western: return "🍝"
        }
    }
}
