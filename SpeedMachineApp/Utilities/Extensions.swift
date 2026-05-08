//
//  Extensions.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

// Color extension for hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// View extension for card styling
extension View {
    func cardStyle() -> some View {
        self
            .background(Color.white)
            .cornerRadius(DesignConstants.cornerRadiusCard)
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusCard)
                    .stroke(AppColors.primaryBlack, lineWidth: DesignConstants.borderWidthBold)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    func primaryButtonStyle() -> some View {
        self
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.accentGreen)
            .cornerRadius(DesignConstants.cornerRadiusButton)
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusButton)
                    .stroke(AppColors.primaryBlack, lineWidth: DesignConstants.borderWidthNormal)
            )
    }

    func secondaryButtonStyle() -> some View {
        self
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundColor(AppColors.primaryBlack)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(DesignConstants.cornerRadiusButton)
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusButton)
                    .stroke(AppColors.primaryBlack, lineWidth: DesignConstants.borderWidthNormal)
            )
    }
}

// Float extension for speed formatting
extension Float {
    func toSpeedString() -> String {
        return String(format: "%.1f", self)
    }
}

// Date extension for formatting
extension Date {
    func toDisplayString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
