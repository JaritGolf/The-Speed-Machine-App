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

    // Header tint: standard = black, gate = blue, pressure = red (mockup .live-header)
    private var titleColor: Color {
        switch icon {
        case .rec:  return tokens.fg
        case .flag: return AppColors.bleBlue
        case .bolt: return AppColors.error
        }
    }

    private var titleText: String {
        "T\(day.day) · BLOCK \(blockNumber) · \(block.name.uppercased())"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            iconView
                .frame(width: fs(18), height: fs(18))
                .padding(.top, fs(3))

            Text(titleText)
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(titleColor)
                .tracking(fs(20) * 0.14)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(tokens.surface)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .rec:
            SportPulsingDot(color: isConnected ? tokens.zone : tokens.miss)
        case .flag:
            Image(systemName: "flag.checkered")
                .font(.system(size: fs(16), weight: .bold))
                .foregroundColor(AppColors.bleBlue)
        case .bolt:
            Image(systemName: "bolt.fill")
                .font(.system(size: fs(16), weight: .bold))
                .foregroundColor(AppColors.error)
        }
    }
}
