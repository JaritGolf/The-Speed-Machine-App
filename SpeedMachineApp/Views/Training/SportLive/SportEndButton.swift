//
//  SportEndButton.swift
//  SpeedMachine
//
//  Full-width red-outline "END SESSION" button.
//  Mirrors SportEndButton from sport-shared.jsx.
//

import SwiftUI

struct SportEndButton: View {
    let tokens: SportTokens
    @Binding var showAlert: Bool
    var title: String = "END SESSION"
    var accent: Color? = nil

    private var tint: Color { accent ?? tokens.miss }

    var body: some View {
        Button {
            showAlert = true
        } label: {
            Text(title)
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tint)
                .tracking(fs(20) * 0.22)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tint.opacity(0.40), lineWidth: 1.5)
                )
        }
    }
}

/// Full-width outlined "RESET BLOCK" button — secondary sibling of SportEndButton.
/// Paired with it in a half/half footer row on every live interface.
struct SportResetButton: View {
    let tokens: SportTokens
    @Binding var showAlert: Bool
    var title: String = "RESET BLOCK"

    var body: some View {
        Button {
            showAlert = true
        } label: {
            Text(title)
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(20) * 0.22)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tokens.sub.opacity(0.40), lineWidth: 1.5)
                )
        }
    }
}
