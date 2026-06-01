//
//  SportRecHeader.swift
//  SpeedMachine
//
//  Sport-style top header bar.
//  Mirrors SportRecHeader from sport-shared.jsx.
//  Pulsing REC dot · "TRACK X / BLOCK Y" · drill name (right)
//

import SwiftUI

struct SportRecHeader: View {
    let track: TrainingTrack
    let block: TrainingBlock
    let tokens: SportTokens
    var icon: SportHeaderIcon = .rec
    var isConnected: Bool = true
    var adaptiveContext: String? = nil

    var blockNumber: Int {
        (track.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    private var headerColor: Color {
        switch icon {
        case .bolt: return Color(hex: "DC2626")
        case .flag: return Color(hex: "1D4ED8")
        case .rec:  return tokens.fg
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                iconView
                    .frame(width: 16, height: 16)

                Text("TRACK \(track.number) / BLOCK \(blockNumber)")
                    .font(.inter(fs(18)))
                    .foregroundColor(headerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                Text(block.name.uppercased())
                    .font(.inter(fs(16), weight: .semibold))
                    .foregroundColor(headerColor.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, adaptiveContext != nil ? 4 : 10)

            if let ctx = adaptiveContext {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: fs(12), weight: .semibold))
                        .foregroundColor(tokens.zone)
                    Text(ctx)
                        .font(.system(size: fs(13), weight: .semibold, design: .rounded))
                        .foregroundColor(tokens.zone)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
        }
        .background(tokens.bg.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(tokens.subtle).frame(height: 1), alignment: .bottom)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .rec:
            SportPulsingDot(color: tokens.zone)
        case .flag:
            Image(systemName: "flag.checkered")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "1D4ED8"))
        case .bolt:
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "DC2626"))
        }
    }
}

enum SportHeaderIcon {
    case rec
    case flag
    case bolt
}
