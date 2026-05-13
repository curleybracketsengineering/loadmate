import SwiftUI
import UIKit

enum AppColors {
    // Base surfaces
    static let backgroundPrimary = Color.dynamic(light: 0xFFFFFF, dark: 0x000000)
    static let backgroundSecondary = Color.dynamic(light: 0xF2F2F7, dark: 0x1C1C1E)
    static let backgroundTertiary = Color.dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)
    static let separator = Color.dynamic(light: 0xC6C6C8, dark: 0x3A3A3C)

    /// Fill behind inline text fields (grouped / elevated surface).
    static let inputFieldBackground = Color.dynamic(light: 0xF2F2F7, dark: 0x2C2C2E)

    /// Bordered field surface (white / elevated card in light mode).
    static let inputSurface = Color.dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)
    static let inputBorder = Color.dynamic(light: 0xD1D1D6, dark: 0x48484A)

    // Text
    static let textPrimary = Color.dynamic(light: 0x000000, dark: 0xFFFFFF)
    static let textSecondary = Color.dynamicRGBA(
        light: (60.0 / 255.0, 60.0 / 255.0, 67.0 / 255.0, 0.60),
        dark: (235.0 / 255.0, 235.0 / 255.0, 245.0 / 255.0, 0.60)
    )
    static let textTertiary = Color.dynamicRGBA(
        light: (60.0 / 255.0, 60.0 / 255.0, 67.0 / 255.0, 0.30),
        dark: (235.0 / 255.0, 235.0 / 255.0, 245.0 / 255.0, 0.30)
    )

    /// Captions and hints on grouped surfaces and list headers (higher contrast than `textSecondary` / SwiftUI `.secondary`).
    static let textSupporting = Color.dynamic(light: 0x3C3C43, dark: 0xAEAEB2)

    // Accents
    static let blue = Color(hex: 0x007AFF)
    static let green = Color(hex: 0x34C759)
    static let red = Color(hex: 0xFF3B30)
    static let orange = Color(hex: 0xFF9500)
    static let yellow = Color(hex: 0xFFCC00)
    static let indigo = Color(hex: 0x5856D6)
    static let teal = Color(hex: 0x5AC8FA)
    static let pink = Color(hex: 0xFF2D55)

    // Inline notice (e.g. configure settings)
    static let warningBannerBackground = Color.dynamic(light: 0xFFF3CD, dark: 0x3D3500)
    static let warningBannerText = Color.dynamic(light: 0x664D03, dark: 0xFFECB0)

    // Existing app tokens (kept for compatibility with current views)
    static let secondaryText = textSecondary
    static let accentInfo = blue
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

    static func dynamic(light: Int, dark: Int) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(Color.hex(dark))
                : UIColor(Color.hex(light))
        })
    }

    static func dynamicRGBA(
        light: (Double, Double, Double, Double),
        dark: (Double, Double, Double, Double)
    ) -> Color {
        Color(UIColor { traitCollection in
            let values = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: values.0,
                green: values.1,
                blue: values.2,
                alpha: values.3
            )
        })
    }
}
