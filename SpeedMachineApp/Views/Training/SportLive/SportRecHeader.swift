import SwiftUI

// MARK: - Header Icon Type

enum SportHeaderIcon {
    case rec, flag, bolt
}

// MARK: - Sport Session Header

struct SportRecHeader: View {
    let day: TrainingDay
    let block: TrainingBlock
    let tokens: SportTokens
    let icon: SportHeaderIcon
    let isConnected: Bool
    var adaptiveContext: String? = nil

    private var blockNumber: Int {
        (day.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: fs(16), height: fs(16))

            VStack(alignment: .leading, spacing: 1) {
                Text("TRACK \(day.day)  /  BLOCK \(blockNumber)")
                    .font(.oswald(fs(11), weight: .semibold))
                    .foregroundColor(tokens.sub)
                    .tracking(1.5)
                if let ctx = adaptiveContext {
                    Text(ctx.uppercased())
                        .font(.system(size: fs(9), weight: .semibold))
                        .foregroundColor(tokens.zone)
                }
            }

            Spacer()

            Text(block.name.uppercased())
                .font(.oswald(fs(11), weight: .semibold))
                .foregroundColor(tokens.sub)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Circle()
                .fill(isConnected ? tokens.zone : tokens.miss)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(tokens.surface)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .rec:
            SportPulsingDot(color: Color(hex: "EF4444"))
        case .flag:
            Image(systemName: "flag.checkered")
                .font(.system(size: fs(13), weight: .bold))
                .foregroundColor(tokens.zone)
        case .bolt:
            Image(systemName: "bolt.fill")
                .font(.system(size: fs(13), weight: .bold))
                .foregroundColor(Color(hex: "EF4444"))
        }
    }
}
