//
//  SportTokens.swift
//  SpeedMachine
//
//  Design tokens for the Sport / Tach live session theme.
//  Mirrors sportTokens() from the v2 design handoff (sport-shared.jsx).
//

import SwiftUI

// MARK: - Theme Preference

enum LiveViewTheme: String, CaseIterable, Identifiable {
    case dark   = "dark"
    case light  = "light"
    case system = "system"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:   return "Dark"
        case .light:  return "Light"
        case .system: return "System"
        }
    }

    /// Resolves to a concrete dark/light bool given the current iOS color scheme.
    func resolvedDark(scheme: ColorScheme) -> Bool {
        switch self {
        case .dark:   return true
        case .light:  return false
        case .system: return scheme == .dark
        }
    }
}

// MARK: - Token Set

struct SportTokens {
    let bg: Color
    let surface: Color
    let fg: Color
    let sub: Color
    let dim: Color
    let subtle: Color
    let hairline: Color
    let zone: Color
    let miss: Color
    let isDark: Bool

    static func make(dark: Bool) -> SportTokens {
        SportTokens(
            bg:       dark ? Color(hex: "08090C") : Color(hex: "FFFFFF"),
            surface:  dark ? Color(hex: "13151A") : Color(hex: "FFFFFF"),
            fg:       dark ? Color.white           : Color(hex: "08090C"),
            sub:      dark ? Color.white.opacity(0.50) : Color.black.opacity(0.50),
            dim:      dark ? Color.white.opacity(0.30) : Color.black.opacity(0.30),
            subtle:   dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
            hairline: dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06),
            zone:     Color(hex: "22C55E"),
            miss:     Color(hex: "EF4444"),
            isDark:   dark
        )
    }
}

// MARK: - Inter font helper

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
