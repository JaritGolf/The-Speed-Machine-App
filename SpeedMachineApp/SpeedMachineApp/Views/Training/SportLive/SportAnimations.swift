//
//  SportAnimations.swift
//  SpeedMachine
//
//  Shared animation helpers for Sport live view.
//  - SportEdgeFlash: full-screen inset border glow triggered on each new putt.
//  - SportPulsingDot: REC-style pulsing dot.
//  - sportPopIn: spring animation for newly arrived putt numbers.
//

import SwiftUI

// MARK: - Edge Flash

/// Full-bleed colored inset glow that fires for ~700ms on each putt.
/// Place as an overlay on the root container view.
struct SportEdgeFlash: View {
    let lastPuttID: Int          // puttRecords.count — changes on each putt
    let inZone: Bool?            // nil before first putt

    @State private var on = false
    @State private var prevID = -1
    @State private var flashColor: Color = .green

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Group {
                    if on {
                        Rectangle()
                            .strokeBorder(flashColor, lineWidth: 6)
                            .transition(.opacity)
                    }
                }
            )
            .shadow(color: on ? flashColor.opacity(0.55) : .clear, radius: on ? 40 : 0)
            .animation(on ? .easeOut(duration: 0.06) : .easeOut(duration: 0.6), value: on)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: lastPuttID) { _, newID in
                guard newID != prevID, newID > 0 else { prevID = newID; return }
                prevID = newID
                flashColor = (inZone == true) ? Color(hex: "22C55E") : Color(hex: "EF4444")
                on = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { on = false }
            }
    }
}

// MARK: - Pulsing REC Dot

struct SportPulsingDot: View {
    let color: Color
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .shadow(color: color.opacity(0.5), radius: pulsing ? 6 : 2)
            .scaleEffect(pulsing ? 1.15 : 0.9)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

// MARK: - Pop-in modifier

struct SportPopIn: ViewModifier {
    let trigger: Int   // changes to trigger the animation

    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: trigger) { _, _ in
                scale = 0.85; opacity = 0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.04; opacity = 1
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.15)) {
                    scale = 1
                }
            }
    }
}

extension View {
    func sportPopIn(trigger: Int) -> some View {
        modifier(SportPopIn(trigger: trigger))
    }
}

// MARK: - Tint Fade Overlay

/// Green or red tint that fades out over 2 s after each putt.
struct SportTintFade: View {
    let inZone: Bool
    let triggerCount: Int    // puttRecords.count

    @State private var opacity: Double = 0
    @State private var prevCount = 0

    private var color: Color { inZone ? Color(hex: "22C55E").opacity(0.28) : Color(hex: "EF4444").opacity(0.28) }

    var body: some View {
        Rectangle()
            .fill(color)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: triggerCount) { _, newCount in
                guard newCount != prevCount, newCount > 0 else { prevCount = newCount; return }
                prevCount = newCount
                opacity = 1
                withAnimation(.easeOut(duration: 2.0)) { opacity = 0 }
            }
    }
}
