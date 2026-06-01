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
