import SwiftUI
import UIKit

enum AppColors {
    // Base surfaces — Lyneqo light-first
    static let backgroundPrimary = Color("LyneqoCard")
    static let backgroundSecondary = Color("LyneqoBackground")
    static let backgroundTertiary = Color("LyneqoCard")
    static let separator = Color("LyneqoBorder")

    /// Fill behind inline text fields (grouped / elevated surface).
    static let inputFieldBackground = Color("LyneqoBackground")

    /// Bordered field surface (white / elevated card in light mode).
    static let inputSurface = Color("LyneqoCard")
    static let inputBorder = Color("LyneqoBorder")

    // Text
    static let textPrimary = Color("LyneqoPrimaryText")
    static let textSecondary = Color("LyneqoSecondaryText")
    static let textTertiary = Color("LyneqoDisabled")

    /// Captions and hints on grouped surfaces and list headers.
    static let textSupporting = Color("LyneqoSecondaryText")

    // Accents — brand + status
    static let blue = Color("LyneqoPrimaryTeal")
    static let green = Color("StatusSuccess")
    static let red = Color("StatusDanger")
    static let orange = Color("StatusWarning")
    static let yellow = Color("StatusWarning")
    static let indigo = Color("LearnAccent")
    static let teal = Color("LyneqoAqua")
    static let pink = Color("StatusDanger")
    static let purple = Color("LearnAccent")
    /// Bike rack on motorhome cutaway (deeper than system purple).
    static let zonePurpleDeep = Color(hex: 0x7B3FB8)

    // Zone chip pastels (accent at 12% on white — matches iPad cutaway artwork)
    static let zonePastelBlue = Color(hex: 0xE0EFFF)
    static let zonePastelOrange = Color(hex: 0xFFEDE0)
    static let zonePastelPink = Color(hex: 0xFFE5EA)
    static let zonePastelPurple = Color(hex: 0xF7E9FF)
    static let zonePastelPurpleDeep = Color(hex: 0xE8D4F5)
    static let zonePastelGreen = Color(hex: 0xEDFAEB)

    // Inline notice (e.g. configure settings) — soft amber from StatusWarning
    static let warningBannerBackground = Color("StatusWarning").opacity(0.18)
    static let warningBannerText = Color("LyneqoDeepNavy")

    // Existing app tokens (kept for compatibility with current views)
    static let secondaryText = textSecondary
    static let accentInfo = Color("StatusInfo")
    static let actionPositive = green
    static let actionCaution = orange
    static let statusWarning = red
    static let statusSafe = green
}

private extension Color {
    static func hex(_ hex: Int) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    init(hex: Int) {
        self = Color.hex(hex)
    }
}
