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

    var body: some View {
        Button {
            showAlert = true
        } label: {
            Text("END SESSION")
                .font(.inter(fs(16), weight: .bold))
                .foregroundColor(tokens.miss)
                .tracking(4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tokens.miss.opacity(0.40), lineWidth: 1.5)
                )
        }
    }
}
