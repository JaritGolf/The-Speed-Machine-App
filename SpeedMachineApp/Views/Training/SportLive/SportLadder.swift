//
//  SportLadder.swift
//  SpeedMachine
//
//  Vertical tolerance ladder shown inside the hero card.
//  Mirrors the Ladder component from variant-b3-ladder.jsx / variant-b1-tach.jsx.
//
//  Shows a ±2.5 MPH range around the current target speed.
//  The tolerance band is highlighted in green.
//  The last-putt position is marked with an arrow (or gold star if bullseye).
//

import SwiftUI

struct SportLadder: View {
    let targetSpeed: Int
    let tolerance: Float
    let lastPutt: PuttResult?
    let tokens: SportTokens

    var pxHeight: CGFloat = 300

    private let range: Float = 2.5

    private var minSpeed: Float { Float(targetSpeed) - range }
    private var maxSpeed: Float { Float(targetSpeed) + range }

    private func yFor(_ mph: Float) -> CGFloat {
        CGFloat((maxSpeed - mph) / (maxSpeed - minSpeed)) * pxHeight
    }

    private var ticks: [Int] {
        let lo = Int(ceil(Double(minSpeed)))
        let hi = Int(floor(Double(maxSpeed)))
        return Array(lo...max(lo, hi))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Track
            Rectangle()
                .fill(tokens.subtle)
                .frame(width: 2)
                .frame(height: pxHeight)
                .position(x: 23, y: pxHeight / 2)

            // Tolerance band
            let tolMin = Float(targetSpeed) - tolerance
            let tolMax = Float(targetSpeed) + tolerance
            let bandTop = yFor(tolMax)
            let bandH = yFor(tolMin) - yFor(tolMax)
            Rectangle()
                .fill(tokens.zone.opacity(0.2))
                .overlay(Rectangle().stroke(tokens.zone, lineWidth: 1.5))
                .cornerRadius(4)
                .frame(width: 14, height: max(4, bandH))
                .position(x: 16 + 7, y: bandTop + bandH / 2)

            // Ticks
            ForEach(ticks, id: \.self) { mph in
                let y = yFor(Float(mph))
                let isTarget = mph == targetSpeed
                HStack(spacing: 4) {
                    Text("\(mph)")
                        .font(.inter(fs(30), weight: isTarget ? .bold : .semibold))
                        .foregroundColor(isTarget ? tokens.fg : tokens.sub)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minWidth: 48, alignment: .trailing)
                    Rectangle()
                        .fill(isTarget ? tokens.fg : tokens.dim)
                        .frame(width: isTarget ? 14 : 8, height: isTarget ? 2 : 1)
                }
                .position(x: (48 + 4 + (isTarget ? 14 : 8)) / 2, y: y)
            }

            // Last putt indicator
            if let putt = lastPutt {
                let clampedMph = max(minSpeed, min(maxSpeed, putt.actualSpeed))
                let y = yFor(clampedMph)
                let isExact = abs(putt.actualSpeed - Float(targetSpeed)) < 0.05

                if isExact {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "FFC107"))
                        .shadow(color: Color(hex: "FFC107").opacity(0.6), radius: 4)
                        .position(x: 48, y: y)
                }
            }
        }
        .frame(width: 90, height: pxHeight)
    }
}
