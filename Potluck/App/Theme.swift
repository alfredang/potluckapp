import SwiftUI

/// Potluck brand palette — derived from the rainbow + spoon logo.
enum Theme {
    static let terracotta = Color(red: 0.788, green: 0.318, blue: 0.184) // #C9512F
    static let teal       = Color(red: 0.122, green: 0.431, blue: 0.416) // #1F6E6A
    static let golden     = Color(red: 0.898, green: 0.635, blue: 0.231) // #E5A23B
    static let cream      = Color(red: 1.000, green: 0.969, blue: 0.925) // #FFF7EC
    static let sand       = Color(red: 1.000, green: 0.890, blue: 0.745) // #FFE3BE
    static let ink        = Color(red: 0.165, green: 0.149, blue: 0.137) // #2A2622
    static let mutedInk   = Color(red: 0.420, green: 0.392, blue: 0.365)

    static let background  = Color(red: 0.992, green: 0.957, blue: 0.910)
    static let cardShadow  = Color.black.opacity(0.06)
}

extension View {
    /// Standard rounded card surface used across the app.
    func potluckCard(padding: CGFloat = 0) -> some View {
        self
            .padding(padding)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 4)
    }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
