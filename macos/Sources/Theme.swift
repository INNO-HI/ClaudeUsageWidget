import SwiftUI
import AppKit

// MARK: - Typography (에이투지체 / A2Z)

enum AppFont {
    static func thin(_ size: CGFloat) -> Font      { Font.custom("A2Z 1 Thin", size: size) }
    static func light(_ size: CGFloat) -> Font     { Font.custom("A2Z 3 Light", size: size) }
    static func regular(_ size: CGFloat) -> Font   { Font.custom("A2Z 4 Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font    { Font.custom("A2Z 5 Medium", size: size) }
    static func semibold(_ size: CGFloat) -> Font  { Font.custom("A2Z 6 SemiBold", size: size) }
    static func bold(_ size: CGFloat) -> Font      { Font.custom("A2Z 7 Bold", size: size) }
    static func extraBold(_ size: CGFloat) -> Font { Font.custom("A2Z 8 ExtraBold", size: size) }
    static func black(_ size: CGFloat) -> Font     { Font.custom("A2Z 9 Black", size: size) }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Color Theme (Light + Dark adaptive)

struct Theme {
    // Base — adapt to system appearance
    static let background = Color.dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    // Card surface — sits on popoverBg (#FAFAFA / #1C1C1E)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)

    // Text
    static let textPrimary = Color.dynamic(light: 0x1F2937, dark: 0xF2F2F7)
    static let textSecondary = Color.dynamic(light: 0x6B7280, dark: 0xAEAEB2)

    // Status colors
    static let danger = Color(hex: 0xF87171)       // Soft red
    static let warning = Color(hex: 0xF59E0B)      // Warm orange
    static let success = Color(hex: 0x10B981)      // Green
    static let claudeOrange = Color(hex: 0xD97757) // Claude brand

    // Accent = Claude orange for brand consistency
    static let accent = Color(hex: 0xD97757)
    static let accentDim = Color(hex: 0xD97757).opacity(0.6)

    // UI elements
    static let progressBg = Color.dynamic(light: 0xE5E7EB, dark: 0x3A3A3C)
    static let border = Color.dynamic(light: 0xE5E7EB, dark: 0x3A3A3C)
    static let cardBorder = Color.dynamic(light: 0xFFFFFF, dark: 0x48484A).opacity(0.6)

    // Card glow shadow
    static let glassBg = Color.dynamic(light: 0xFFFFFF, dark: 0x2C2C2E).opacity(0.7)
    static let glassBorder = Color.dynamic(light: 0xFFFFFF, dark: 0x48484A).opacity(0.5)
    static let glassShadow = Color.black.opacity(0.04)

    // Solid popover background — off-white in light mode, dark surface in dark mode
    static let popoverBg = Color.dynamic(light: 0xFAFAFA, dark: 0x1C1C1E)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Dynamic color that follows the system appearance (light/dark mode).
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green:   CGFloat((hex >> 8)  & 0xFF) / 255.0,
                blue:    CGFloat( hex        & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
    }
}
