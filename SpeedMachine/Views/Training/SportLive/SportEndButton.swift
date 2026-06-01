import SwiftUI

struct SportEndButton: View {
    let tokens: SportTokens
    @Binding var showAlert: Bool

    var body: some View {
        Button {
            showAlert = true
        } label: {
            Text("END SESSION")
                .font(.inter(fs(15), weight: .semibold))
                .foregroundColor(tokens.miss)
                .tracking(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isIPad ? 18 : 13)
                .background(tokens.miss.opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tokens.miss.opacity(0.45), lineWidth: 1.5)
                )
        }
    }
}
