//
//  OnboardingTour.swift
//  SpeedMachine
//
//  First-launch coachmark tour. Spotlights each Home feature with an
//  arrow callout and a Next button. Gated by @AppStorage("hasSeenTour"),
//  replayable from Settings.
//

import SwiftUI

// MARK: - Steps

enum TourStep: Int, CaseIterable {
    case pair, dashboard, recall, practice, combine, stats, settings, start

    /// All copy lives in TourCopy.Home (single source of truth).
    private var line: TourCopy.Line {
        switch self {
        case .pair:      return TourCopy.Home.pair
        case .dashboard: return TourCopy.Home.dashboard
        case .recall:    return TourCopy.Home.recall
        case .practice:  return TourCopy.Home.practice
        case .combine:   return TourCopy.Home.combine
        case .stats:     return TourCopy.Home.stats
        case .settings:  return TourCopy.Home.settings
        case .start:     return TourCopy.Home.start
        }
    }

    var title: String { line.title }
    var bodyText: String { line.body }

    var next: TourStep? { TourStep(rawValue: rawValue + 1) }
    var isLast: Bool { next == nil }
    var stepNumber: Int { rawValue + 1 }
    static var total: Int { allCases.count }
}

// MARK: - Anchor plumbing

struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [TourStep: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourStep: Anchor<CGRect>],
                       nextValue: () -> [TourStep: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Marks this view as the spotlight target for a tour step.
    func tourAnchor(_ step: TourStep) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [step: $0] }
    }
}

// MARK: - Overlay

struct OnboardingTourOverlay: View {
    let anchors: [TourStep: Anchor<CGRect>]
    @Binding var step: TourStep?
    let onFinish: () -> Void

    // Layout constants
    private let cardWidth: CGFloat = 300
    private let spotlightPadding: CGFloat = 10
    private let spotlightCorner: CGFloat = 14
    private let arrowSize: CGFloat = 14
    private let gap: CGFloat = 14          // space between target and bubble
    private let sideMargin: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            if let step, let anchor = anchors[step] {
                let target = proxy[anchor]
                content(step: step, target: target, screen: proxy.size)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    @ViewBuilder
    private func content(step: TourStep, target: CGRect, screen: CGSize) -> some View {
        let spot = target.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
        // Place bubble below the target when the target sits in the top half.
        let placeBelow = target.midY < screen.height / 2

        ZStack(alignment: .topLeading) {
            // Dimmed backdrop with a spotlight cutout. Tapping advances.
            spotlightMask(spot: spot)
                .contentShape(Rectangle())
                .onTapGesture { advance(from: step) }

            // Bright ring around the cutout.
            RoundedRectangle(cornerRadius: spotlightCorner)
                .stroke(AppColors.accentGreen, lineWidth: 2)
                .frame(width: spot.width, height: spot.height)
                .position(x: spot.midX, y: spot.midY)
                .allowsHitTesting(false)

            calloutBubble(step: step, spot: spot, placeBelow: placeBelow, screen: screen)
        }
    }

    private func spotlightMask(spot: CGRect) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.72))
            .ignoresSafeArea()
            .overlay(
                RoundedRectangle(cornerRadius: spotlightCorner)
                    .frame(width: spot.width, height: spot.height)
                    .position(x: spot.midX, y: spot.midY)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }

    @ViewBuilder
    private func calloutBubble(step: TourStep, spot: CGRect, placeBelow: Bool, screen: CGSize) -> some View {
        // Horizontal centre, clamped so the card stays on-screen.
        let halfWidth = cardWidth / 2
        let clampedX = min(max(spot.midX, sideMargin + halfWidth), screen.width - sideMargin - halfWidth)
        // Arrow x relative to the card's leading edge, pointing at the target.
        let arrowX = min(max(spot.midX - (clampedX - halfWidth), arrowSize), cardWidth - arrowSize)

        VStack(spacing: 0) {
            if placeBelow {
                Triangle().rotation(.degrees(180))
                    .fill(Color.white)
                    .frame(width: arrowSize * 1.6, height: arrowSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, arrowX - arrowSize * 0.8)
            }

            card(step: step)

            if !placeBelow {
                Triangle()
                    .fill(Color.white)
                    .frame(width: arrowSize * 1.6, height: arrowSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, arrowX - arrowSize * 0.8)
            }
        }
        .frame(width: cardWidth)
        .position(
            x: clampedX,
            y: placeBelow
                ? spot.maxY + gap + bubbleHalfHeight
                : spot.minY - gap - bubbleHalfHeight
        )
    }

    // Rough half-height for vertical positioning (card + arrow).
    private var bubbleHalfHeight: CGFloat { 92 }

    private func card(step: TourStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(step.title)
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.0)
                    .foregroundColor(.black)
                Spacer()
                Text("\(step.stepNumber) / \(TourStep.total)")
                    .font(.custom("Inter-Bold", size: 11))
                    .kerning(1.0)
                    .foregroundColor(AppColors.textSubdued)
            }

            Text(step.bodyText)
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(AppColors.textMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if step == .pair {
                    Button(action: onFinish) {
                        Text("Skip tour")
                            .font(.custom("Inter-Medium", size: 14))
                            .foregroundColor(AppColors.textSubdued)
                    }
                }
                Spacer()
                Button { advance(from: step) } label: {
                    Text(step.isLast ? "Done" : "Next")
                        .font(.custom("Inter-Bold", size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(AppColors.accentGreen)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 6)
    }

    private func advance(from step: TourStep) {
        if let next = step.next {
            self.step = next
        } else {
            onFinish()
        }
    }
}

// MARK: - Arrow

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
