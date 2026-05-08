import SwiftUI

// MARK: - Strip Configurations

enum SportPassStripConfig {
    case standard(puttsLeft: Int, puttsNeeded: Int)
    case gateTest(puttsLeft: Int, puttsNeeded: Int)
    case makeInRow(puttsTaken: Int, toGo: Int)
    case ladder(currentRung: Int, totalRungs: Int)
    case exploration(puttsTaken: Int)
}

// MARK: - Pass Strip

struct SportPassStrip: View {
    let config: SportPassStripConfig
    let tokens: SportTokens

    var body: some View {
        Group {
            switch config {
            case .standard(let left, let needed):
                twoCol(
                    leftLabel: "PUTTS LEFT",  leftValue: "\(left)",
                    rightLabel: "PUTTS NEEDED", rightValue: "\(max(0, needed))"
                )
            case .gateTest(let left, let needed):
                twoCol(
                    leftLabel: "PUTTS LEFT",  leftValue: "\(left)",
                    rightLabel: "IN ZONE NEEDED", rightValue: "\(max(0, needed))"
                )
            case .makeInRow(let taken, let toGo):
                twoCol(
                    leftLabel: "PUTTS TAKEN", leftValue: "\(taken)",
                    rightLabel: "TO GO",      rightValue: "\(max(0, toGo))"
                )
            case .ladder(let rung, let total):
                singleCol(label: "RUNG", value: "\(rung) / \(total)")
            case .exploration(let taken):
                singleCol(label: "PUTTS TAKEN", value: "\(taken)")
            }
        }
        .background(tokens.surface)
    }

    // MARK: Two-column layout

    @ViewBuilder
    private func twoCol(leftLabel: String, leftValue: String,
                        rightLabel: String, rightValue: String) -> some View {
        HStack(spacing: 0) {
            statCol(label: leftLabel, value: leftValue)
            Rectangle()
                .fill(tokens.subtle)
                .frame(width: 1)
            statCol(label: rightLabel, value: rightValue)
        }
    }

    // MARK: Single-column layout

    @ViewBuilder
    private func singleCol(label: String, value: String) -> some View {
        statCol(label: label, value: value)
            .frame(maxWidth: .infinity)
    }

    // MARK: Stat column

    @ViewBuilder
    private func statCol(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.oswald(fs(10), weight: .semibold))
                .foregroundColor(tokens.sub)
                .tracking(1.5)
            Text(value)
                .font(.oswald(fs(36)))
                .foregroundColor(tokens.fg)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 10 : 7)
    }
}
