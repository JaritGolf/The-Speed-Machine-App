//
//  Coachmark.swift
//  SpeedMachine
//
//  Reusable first-time coachmark engine — spotlight + arrow callout (or a centered
//  card when a step has no anchor). Adopted by the selection, mode, and stats screens
//  via the `.coachmarkTour(...)` modifier. Themeable so AppColors screens and
//  SportTokens (live-view) screens both match. The Home tour keeps its own bespoke
//  OnboardingTour; this powers everything else.
//

import SwiftUI

// MARK: - Model

struct CoachmarkStep {
    let title: String
    let body: String
    /// Anchor id to spotlight, or nil for a centered card with no spotlight.
    let anchor: Int?

    init(_ title: String, _ body: String, anchor: Int? = nil) {
        self.title = title
        self.body = body
        self.anchor = anchor
    }
}

struct CoachmarkStyle {
    var card: Color
    var title: Color
    var body: Color
    var subtle: Color   // step counter / Skip
    var accent: Color   // button bg + spotlight ring
    var onAccent: Color // button text

    static func appColors() -> CoachmarkStyle {
        CoachmarkStyle(card: .white, title: .black, body: AppColors.textMuted,
                       subtle: AppColors.textSubdued, accent: AppColors.accentGreen, onAccent: .white)
    }

    static func sport(_ t: SportTokens) -> CoachmarkStyle {
        CoachmarkStyle(card: t.surface, title: t.fg, body: t.sub,
                       subtle: t.sub, accent: t.zone, onAccent: .white)
    }
}

// MARK: - Anchor plumbing

struct CoachmarkAnchorKey: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>],
                       nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Marks this view as the spotlight target for coachmark step `id`.
    func coachmarkAnchor(_ id: Int) -> some View {
        anchorPreference(key: CoachmarkAnchorKey.self, value: .bounds) { [id: $0] }
    }

    /// Hosts a coachmark tour over this view. `index` drives the current step (nil = inactive).
    func coachmarkTour(_ steps: [CoachmarkStep],
                       index: Binding<Int?>,
                       style: CoachmarkStyle,
                       onStepChange: ((Int) -> Void)? = nil,
                       onFinish: @escaping () -> Void) -> some View {
        overlayPreferenceValue(CoachmarkAnchorKey.self) { anchors in
            if index.wrappedValue != nil {
                CoachmarkOverlay(steps: steps, anchors: anchors, index: index,
                                 style: style, onStepChange: onStepChange, onFinish: onFinish)
            }
        }
    }
}

// MARK: - Overlay

struct CoachmarkOverlay: View {
    let steps: [CoachmarkStep]
    let anchors: [Int: Anchor<CGRect>]
    @Binding var index: Int?
    let style: CoachmarkStyle
    var onStepChange: ((Int) -> Void)? = nil
    let onFinish: () -> Void

    private let cardWidth: CGFloat = 300
    private let spotlightPadding: CGFloat = 10
    private let spotlightCorner: CGFloat = 14
    private let arrowSize: CGFloat = 14
    private let gap: CGFloat = 14
    private let sideMargin: CGFloat = 16
    private let bubbleHalfHeight: CGFloat = 96

    var body: some View {
        GeometryReader { proxy in
            if let i = index, i >= 0, i < steps.count {
                let step = steps[i]
                if let aid = step.anchor, let anchor = anchors[aid] {
                    spotlightContent(step: step, target: proxy[anchor], screen: proxy.size)
                } else {
                    centeredContent(step: step)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: index)
    }

    // MARK: spotlight layout

    @ViewBuilder
    private func spotlightContent(step: CoachmarkStep, target: CGRect, screen: CGSize) -> some View {
        let spot = target.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
        let placeBelow = target.midY < screen.height / 2

        ZStack(alignment: .topLeading) {
            spotlightMask(spot: spot)
                .contentShape(Rectangle())
                .onTapGesture { advance() }

            RoundedRectangle(cornerRadius: spotlightCorner)
                .stroke(style.accent, lineWidth: 2)
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
    private func calloutBubble(step: CoachmarkStep, spot: CGRect, placeBelow: Bool, screen: CGSize) -> some View {
        let halfWidth = cardWidth / 2
        let clampedX = min(max(spot.midX, sideMargin + halfWidth), screen.width - sideMargin - halfWidth)
        let arrowX = min(max(spot.midX - (clampedX - halfWidth), arrowSize), cardWidth - arrowSize)

        VStack(spacing: 0) {
            if placeBelow {
                CoachmarkTriangle().rotation(.degrees(180))
                    .fill(style.card)
                    .frame(width: arrowSize * 1.6, height: arrowSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, arrowX - arrowSize * 0.8)
            }

            card(step: step)

            if !placeBelow {
                CoachmarkTriangle()
                    .fill(style.card)
                    .frame(width: arrowSize * 1.6, height: arrowSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, arrowX - arrowSize * 0.8)
            }
        }
        .frame(width: cardWidth)
        .position(
            x: clampedX,
            y: placeBelow ? spot.maxY + gap + bubbleHalfHeight
                          : spot.minY - gap - bubbleHalfHeight
        )
    }

    // MARK: centered layout (no anchor)

    private func centeredContent(step: CoachmarkStep) -> some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { advance() }
            card(step: step)
                .frame(width: cardWidth)
        }
    }

    // MARK: card

    private func card(step: CoachmarkStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(step.title)
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.0)
                    .foregroundColor(style.title)
                Spacer()
                Text("\((index ?? 0) + 1) / \(steps.count)")
                    .font(.custom("Inter-Bold", size: 11))
                    .kerning(1.0)
                    .foregroundColor(style.subtle)
            }

            Text(step.body)
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(style.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if (index ?? 0) == 0 {
                    Button(action: onFinish) {
                        Text("Skip")
                            .font(.custom("Inter-Medium", size: 14))
                            .foregroundColor(style.subtle)
                    }
                }
                Spacer()
                Button(action: advance) {
                    Text(isLast ? "Done" : "Next")
                        .font(.custom("Inter-Bold", size: 14))
                        .foregroundColor(style.onAccent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(style.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(style.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 6)
    }

    private var isLast: Bool { (index ?? 0) >= steps.count - 1 }

    private func advance() {
        let current = index ?? 0
        if current >= steps.count - 1 {
            onFinish()
        } else {
            let next = current + 1
            index = next
            onStepChange?(next)
        }
    }
}

// MARK: - Arrow

private struct CoachmarkTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
