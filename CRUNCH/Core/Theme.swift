import SwiftUI

enum Theme {
    // MARK: - Colours
    static let brand         = Color(hex: "#C4622D")
    static let brandDark     = Color(hex: "#A3501F")
    static let surface       = Color(hex: "#0A0A0A")
    static let card          = Color(hex: "#1A1A1A")
    static let subtle        = Color(hex: "#2A2A2A")
    static let textPrimary   = Color(hex: "#FFFFFF")
    static let textSecondary = Color(hex: "#9CA3AF")
    static let textInverse   = Color(hex: "#1E2A23")
    static let success       = Color(hex: "#22C55E")
    static let warning       = Color(hex: "#F59E0B")
    static let neutral       = Color(hex: "#6B7280")
    static let error         = Color(hex: "#EF4444")

    // MARK: - Typography
    static let heroNumber  = Font.system(size: 32, weight: .bold)
    static let heading     = Font.system(size: 22, weight: .bold)
    static let subheading  = Font.system(size: 17, weight: .semibold)
    static let body        = Font.system(size: 15, weight: .regular)
    static let caption     = Font.system(size: 13, weight: .regular)
    static let tabLabel    = Font.system(size: 10, weight: .medium)

    // MARK: - Spacing
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32

    // MARK: - Corner Radius
    static let cardRadius:   CGFloat = 16
    static let buttonRadius: CGFloat = 14
    static let inputRadius:  CGFloat = 14
    static let pillRadius:   CGFloat = 20
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
