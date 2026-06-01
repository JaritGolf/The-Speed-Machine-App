import SwiftUI

// MARK: - Live View Theme

enum LiveViewTheme: String, CaseIterable {
    case dark, light, system

    var displayName: String {
        switch self {
        case .dark:   return "Dark"
        case .light:  return "Light"
        case .system: return "System"
        }
    }

    func resolvedDark(scheme: ColorScheme) -> Bool {
        switch self {
        case .dark:   return true
        case .light:  return false
        case .system: return scheme == .dark
        }
    }
}

// MARK: - Sport Design Tokens

struct SportTokens {
    let bg:      Color
    let surface: Color
    let fg:      Color
    let sub:     Color
    let subtle:  Color
    let zone:    Color
    let miss:    Color

    static func make(dark: Bool) -> SportTokens {
        if dark {
            return SportTokens(
                bg:      Color(hex: "08090C"),
                surface: Color(hex: "13151A"),
                fg:      .white,
                sub:     Color.white.opacity(0.50),
                subtle:  Color.white.opacity(0.10),
                zone:    Color(hex: "22C55E"),
                miss:    Color(hex: "EF4444")
            )
        } else {
            return SportTokens(
                bg:      Color(hex: "FFFFFF"),
                surface: .white,
                fg:      Color(hex: "000000"),
                sub:     Color.black.opacity(0.50),
                subtle:  Color.black.opacity(0.08),
                zone:    Color(hex: "22C55E"),
                miss:    Color(hex: "DC2626")
            )
        }
    }
}

// MARK: - Inter Font

extension Font {
    static func inter(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        let name: String
        switch weight {
        case .black:    name = "Inter-Black"
        case .heavy:    name = "Inter-ExtraBold"
        case .bold:     name = "Inter-Bold"
        case .semibold: name = "Inter-SemiBold"
        case .medium:   name = "Inter-Medium"
        default:        name = "Inter-Regular"
        }
        return .custom(name, size: size)
    }
}
