import SwiftUI

// MARK: - Vertical Tolerance Ladder
// Shows ±2.5 MPH range around target; last-putt indicator slides up/down.

struct SportLadder: View {
    @Environment(\.colorScheme) var colorScheme

    let targetSpeed: Int
    let lastPutt: PuttResult?
    let tokens: SportTokens
    let tolerance: Float = 0.5

    @State private var triangleVisibleUntil: Date?

    private let rangeHalf: Float = 2.5

    private var minSpeed: Float { Float(targetSpeed) - rangeHalf }
    private var maxSpeed: Float { Float(targetSpeed) + rangeHalf }

    private var lineColor: Color {
        colorScheme == .dark ? .white : .black
    }

    // Fraction along the ladder (0 = bottom/min, 1 = top/max)
    private func fraction(for speed: Float) -> CGFloat {
        CGFloat((speed - minSpeed) / (rangeHalf * 2))
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let cx = geo.size.width / 2
            let shouldShowTriangle = triangleVisibleUntil.map { Date() < $0 } ?? false

            ZStack(alignment: .topLeading) {
                // Track spine (thicker, color-aware)
                Capsule()
                    .fill(lineColor)
                    .frame(width: 5, height: h)
                    .position(x: cx, y: h / 2)

                // Tolerance band (dynamic based on tolerance parameter)
                let bandFrac = CGFloat(tolerance / (rangeHalf * 2))
                let bandH = max(6, h * bandFrac * 2)
                let bandY = h * (1 - fraction(for: Float(targetSpeed))) - bandH / 2

                RoundedRectangle(cornerRadius: 3)
                    .fill(tokens.zone.opacity(0.20))
                    .frame(width: 14, height: bandH)
                    .position(x: cx, y: bandY + bandH / 2)

                RoundedRectangle(cornerRadius: 3)
                    .stroke(tokens.zone.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 14, height: bandH)
                    .position(x: cx, y: bandY + bandH / 2)

                // Target center tick
                Capsule()
                    .fill(tokens.zone)
                    .frame(width: 18, height: 2)
                    .position(x: cx, y: h * (1 - fraction(for: Float(targetSpeed))))

                // Last-putt indicator (triangle pointing up, shows for 3 seconds after putt)
                if let putt = lastPutt {
                    let frac = min(max(fraction(for: putt.actualSpeed), 0), 1)
                    let dotY = h * (1 - frac)
                    let isExact = abs(putt.difference) < 0.15

                    Group {
                        if shouldShowTriangle {
                            if isExact {
                                Image(systemName: "star.fill")
                                    .font(.system(size: fs(11)))
                                    .foregroundColor(.yellow)
                            } else {
                                Image(systemName: "arrowtriangle.up.fill")
                                    .font(.system(size: fs(10)))
                                    .foregroundColor(putt.isInZone ? tokens.zone : tokens.miss)
                            }
                        }
                    }
                    .position(x: cx, y: dotY - 14)
                    .sportPopIn(trigger: putt.puttNumber)
                }

                // Speed labels on the left edge (larger, bolder)
                VStack {
                    Text(String(format: "%.0f", maxSpeed))
                        .font(.inter(fs(12), weight: .semibold))
                        .foregroundColor(tokens.sub)
                    Spacer()
                    Text("\(targetSpeed)")
                        .font(.inter(fs(14), weight: .bold))
                        .foregroundColor(tokens.zone)
                    Spacer()
                    Text(String(format: "%.0f", minSpeed))
                        .font(.inter(fs(12), weight: .semibold))
                        .foregroundColor(tokens.sub)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .padding(.leading, 4)
            }
            .onChange(of: lastPutt?.puttNumber) { _ in
                triangleVisibleUntil = Date().addingTimeInterval(3)
            }
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                if let deadline = triangleVisibleUntil, Date() > deadline {
                    triangleVisibleUntil = nil
                }
            }
        }
    }
}
