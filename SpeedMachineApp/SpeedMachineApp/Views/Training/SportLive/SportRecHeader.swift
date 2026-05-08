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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                iconView
                    .frame(width: 16, height: 16)

                Text("TRACK \(track.number) / BLOCK \(blockNumber)")
                    .font(.oswald(fs(18)))
                    .foregroundColor(tokens.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                Text(block.name.uppercased())
                    .font(.oswald(fs(16), weight: .semibold))
                    .foregroundColor(tokens.sub)
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
            SportPulsingDot(color: tokens.miss)
        case .flag:
            Image(systemName: "flag.checkered")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "3B82F6"))
        case .bolt:
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tokens.miss)
        }
    }
}

enum SportHeaderIcon {
    case rec
    case flag
    case bolt
}
