import SwiftUI

// MARK: - Edge Flash (full-screen border pulse on each putt)

struct SportEdgeFlash: View {
    let lastPuttID: Int
    let inZone: Bool?

    @State private var show = false

    private var flashColor: Color {
        guard let inZone else { return .clear }
        return inZone ? Color(hex: "22C55E") : Color(hex: "EF4444")
    }

    var body: some View {
        Rectangle()
            .stroke(flashColor, lineWidth: 10)
            .opacity(show ? 1 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: lastPuttID) { _, _ in
                guard inZone != nil else { return }
                show = true
                withAnimation(.easeOut(duration: 0.6).delay(0.7)) {
                    show = false
                }
            }
    }
}

// MARK: - Pulsing Dot (REC indicator)

struct SportPulsingDot: View {
    let color: Color

    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .scaleEffect(pulse ? 1.35 : 1.0)
            .shadow(color: color.opacity(0.8), radius: pulse ? 6 : 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Pop-In Animation (scale bounce on new putt)

struct SportPopIn: ViewModifier {
    let trigger: Int
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                scale = 1.15
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                    scale = 1.0
                }
            }
    }
}

extension View {
    func sportPopIn(trigger: Int) -> some View {
        modifier(SportPopIn(trigger: trigger))
    }
}

// MARK: - Tint Fade (color wash that fades over 2s after each putt)

struct SportTintFade: View {
    let color: Color
    let trigger: Int

    @State private var opacity: Double = 0

    var body: some View {
        color
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, _ in
                guard color != .clear else { return }
                opacity = 0.28
                withAnimation(.easeOut(duration: 2.0)) {
                    opacity = 0
                }
            }
    }
}
