import SwiftUI

// MARK: - Standard Hero Card

struct SportHeroCard: View {
    @ObservedObject var session: SessionProgress
    let tokens: SportTokens

    private var lastPutt: PuttResult? { session.puttRecords.last }

    private var hitRate: Int {
        session.currentPutt > 0 ? Int(session.zoneAccuracy * 100) : 0
    }

    private var speedText: String {
        guard let p = lastPutt else { return "—" }
        return p.actualSpeed.toSpeedString()
    }

    private var speedFontSize: CGFloat {
        guard let p = lastPutt else { return fs(160) }
        return p.actualSpeed >= 10 ? fs(130) : fs(160)
    }

    private var speedColor: Color {
        guard let p = lastPutt else { return tokens.sub }
        return p.isInZone ? tokens.zone : tokens.miss
    }

    private var tintColor: Color {
        guard let p = lastPutt else { return .clear }
        return p.isInZone ? tokens.zone : tokens.miss
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(tokens.surface)

            // Colored border that pulses with zone/miss
            RoundedRectangle(cornerRadius: 24)
                .stroke(lastPutt != nil ? speedColor.opacity(0.55) : tokens.subtle, lineWidth: 2)

            // Tint overlay that fades out after each putt
            SportTintFade(color: tintColor, trigger: session.puttRecords.count)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 0) {
                // Top area: HIT RATE corner stat
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("HIT RATE")
                            .font(.oswald(fs(10), weight: .semibold))
                            .foregroundColor(tokens.sub)
                            .tracking(1)
                        Text("\(hitRate)%")
                            .font(.oswald(fs(22)))
                            .foregroundColor(hitRate >= 60 ? tokens.zone : tokens.sub)
                            .monospacedDigit()
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 14)
                }
                .frame(height: isIPad ? 64 : 50)

                // Middle: ladder + giant speed
                HStack(spacing: 0) {
                    SportLadder(
                        targetSpeed: session.currentTargetSpeed,
                        lastPutt: lastPutt,
                        tokens: tokens,
                        tolerance: 0.5
                    )
                    .frame(width: isIPad ? 56 : 44)
                    .padding(.leading, 12)

                    VStack(spacing: 2) {
                        Spacer()
                        Text(speedText)
                            .font(.oswald(speedFontSize))
                            .foregroundColor(speedColor)
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                            .monospacedDigit()
                            .sportPopIn(trigger: session.puttRecords.count)
                        Text("MPH")
                            .font(.oswald(fs(22), weight: .semibold))
                            .foregroundColor(tokens.sub)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }

                // Bottom: live readout strip
                SportLiveReadout(
                    targetSpeed: session.currentTargetSpeed,
                    lastPutt: lastPutt,
                    tokens: tokens
                )
                .frame(height: isIPad ? 44 : 36)
            }
        }
    }
}

// MARK: - Exploration Hero (no target, no ladder)

struct SportExplorationHero: View {
    @ObservedObject var session: SessionProgress
    let tokens: SportTokens

    private var lastPutt: PuttResult? { session.puttRecords.last }

    private var speedText: String {
        guard let p = lastPutt else { return "—" }
        return p.actualSpeed.toSpeedString()
    }

    private var speedFontSize: CGFloat {
        guard let p = lastPutt else { return fs(160) }
        return p.actualSpeed >= 10 ? fs(130) : fs(160)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(tokens.surface)
            RoundedRectangle(cornerRadius: 24)
                .stroke(tokens.subtle, lineWidth: 1)

            VStack(spacing: 0) {
                Text("YOUR SPEED")
                    .font(.oswald(fs(14), weight: .semibold))
                    .foregroundColor(tokens.sub)
                    .tracking(2)
                    .padding(.top, 16)

                Spacer()

                Text(speedText)
                    .font(.oswald(speedFontSize))
                    .foregroundColor(tokens.zone)
                    .minimumScaleFactor(0.2)
                    .lineLimit(1)
                    .monospacedDigit()
                    .sportPopIn(trigger: session.puttRecords.count)

                Text("MPH")
                    .font(.oswald(fs(22), weight: .semibold))
                    .foregroundColor(tokens.sub)

                Spacer()
            }
        }
    }
}

// MARK: - Live Readout Strip (bottom of hero card)

struct SportLiveReadout: View {
    let targetSpeed: Int
    let lastPutt: PuttResult?
    let tokens: SportTokens

    private var deltaText: String {
        guard let p = lastPutt else { return "" }
        let d = p.actualSpeed - Float(targetSpeed)
        if abs(d) < 0.05 { return "PERFECT" }
        return d > 0 ? "+\(String(format: "%.1f", d))" : "\(String(format: "%.1f", d))"
    }

    private var deltaColor: Color {
        guard let p = lastPutt else { return tokens.sub }
        return p.isInZone ? tokens.zone : tokens.miss
    }

    var body: some View {
        HStack {
            Text("TARGET")
                .font(.oswald(fs(10), weight: .semibold))
                .foregroundColor(tokens.sub)
                .tracking(1.5)
            Text("\(targetSpeed) MPH")
                .font(.oswald(fs(13)))
                .foregroundColor(tokens.fg)
            Spacer()
            if lastPutt != nil {
                Text(deltaText)
                    .font(.oswald(fs(11), weight: .semibold))
                    .foregroundColor(deltaColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(deltaColor.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 14)
        .background(tokens.subtle)
    }
}
