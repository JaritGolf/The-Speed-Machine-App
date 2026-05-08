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
                bg:      Color(hex: "F5F7FA"),
                surface: .white,
                fg:      Color(hex: "08090C"),
                sub:     Color(hex: "08090C").opacity(0.50),
                subtle:  Color(hex: "08090C").opacity(0.10),
                zone:    Color(hex: "16A34A"),
                miss:    Color(hex: "DC2626")
            )
        }
    }
}

// MARK: - Oswald Font

extension Font {
    static func oswald(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .semibold: name = "Oswald-SemiBold"
        case .regular:  name = "Oswald-Regular"
        default:        name = "Oswald-Bold"
        }
        return .custom(name, size: size)
    }
}
