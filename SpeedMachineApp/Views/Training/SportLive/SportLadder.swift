import SwiftUI

// MARK: - Vertical Tolerance Ladder
// Shows ±2.5 MPH range around target; last-putt indicator slides up/down.

struct SportLadder: View {
    let targetSpeed: Int
    let lastPutt: PuttResult?
    let tokens: SportTokens

    private let rangeHalf: Float = 2.5

    private var minSpeed: Float { Float(targetSpeed) - rangeHalf }
    private var maxSpeed: Float { Float(targetSpeed) + rangeHalf }

    // Fraction along the ladder (0 = bottom/min, 1 = top/max)
    private func fraction(for speed: Float) -> CGFloat {
        CGFloat((speed - minSpeed) / (rangeHalf * 2))
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let cx = geo.size.width / 2

            ZStack(alignment: .topLeading) {
                // Track spine
                Capsule()
                    .fill(tokens.subtle)
                    .frame(width: 3, height: h)
                    .position(x: cx, y: h / 2)

                // Tolerance band (±0.5 MPH of target = 0.5/2.5 = 20% of range each side)
                let bandFrac = CGFloat(0.5 / (rangeHalf * 2))
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

                // Last-putt indicator
                if let putt = lastPutt {
                    let frac = min(max(fraction(for: putt.actualSpeed), 0), 1)
                    let dotY = h * (1 - frac)
                    let isExact = abs(putt.difference) < 0.15

                    Group {
                        if isExact {
                            Image(systemName: "star.fill")
                                .font(.system(size: fs(11)))
                                .foregroundColor(.yellow)
                        } else {
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.system(size: fs(9)))
                                .foregroundColor(putt.isInZone ? tokens.zone : tokens.miss)
                        }
                    }
                    .position(x: cx + 12, y: dotY)
                    .sportPopIn(trigger: putt.puttNumber)
                }

                // Speed labels on the right edge
                VStack {
                    Text(String(format: "%.0f", maxSpeed))
                        .font(.oswald(fs(8), weight: .regular))
                        .foregroundColor(tokens.sub)
                    Spacer()
                    Text("\(targetSpeed)")
                        .font(.oswald(fs(9), weight: .semibold))
                        .foregroundColor(tokens.zone)
                    Spacer()
                    Text(String(format: "%.0f", minSpeed))
                        .font(.oswald(fs(8), weight: .regular))
                        .foregroundColor(tokens.sub)
                }
                .frame(width: geo.size.width, alignment: .trailing)
            }
        }
    }
}
