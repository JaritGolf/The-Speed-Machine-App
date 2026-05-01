//
//  AdaptiveLayout.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Single-codebase adaptive layout for iPhone and iPad.
//  Device is detected at runtime — no separate targets needed.
//

import SwiftUI

// MARK: - Device Detection

/// Returns true when running on any iPad model.
var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

/// Scale factor applied to live-session font sizes on iPad.
/// Session UIs are viewed at 5–6 ft; iPad screens are physically ~1.4× larger.
var iPadFontScale: CGFloat {
    isIPad ? 1.4 : 1.0
}

/// Max content width used to centre nav/stats cards on iPad.
let iPadContentMaxWidth: CGFloat = 740

// MARK: - Session Font Scale Helper

/// Scales a point size for the current device.
/// Use on every font size inside live-session views (ActiveSession, PressureSession, etc.)
/// so text stays readable at the intended 5–6 ft viewing distance on both devices.
///
///     Text("TARGET").font(.system(size: fs(28), weight: .bold))
///
func fs(_ size: CGFloat) -> CGFloat {
    size * iPadFontScale
}

// MARK: - Landscape Orientation Environment Key

/// Custom environment key that carries the true landscape state.
/// Standard `verticalSizeClass == .compact` only works on iPhone — on iPad both
/// portrait and landscape report `.regular` for both size classes.
/// `TrainingSessionView` injects the correct value via `GeometryReader`.
private struct IsLandscapeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// `true` when the current screen is wider than it is tall.
    /// Reliable on both iPhone (via verticalSizeClass) and iPad (via GeometryReader).
    var isLandscapeOrientation: Bool {
        get { self[IsLandscapeEnvironmentKey.self] }
        set { self[IsLandscapeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Helpers

extension View {
    /// On iPad, constrains the view to `maxWidth` and centres it horizontally.
    /// On iPhone the view is returned unchanged, so no call sites need if/else guards.
    ///
    ///     ScrollView { content.adaptiveContentFrame() }
    ///
    func adaptiveContentFrame(maxWidth: CGFloat = iPadContentMaxWidth) -> some View {
        self
            .frame(maxWidth: isIPad ? maxWidth : .infinity)
            .frame(maxWidth: .infinity) // always fill width so background extends edge-to-edge
    }
}

// MARK: - Adaptive Grid Columns

/// Returns a `[GridItem]` array sized for the current device and orientation.
///
/// - Parameters:
///   - iPhone: Column count for iPhone portrait (default 3).
///   - iPhoneLandscape: Column count for iPhone landscape (default 6).
///   - iPad: Column count for iPad any orientation (default 5).
///   - isLandscape: Whether the device is currently in landscape.
func adaptiveGridColumns(
    iPhone: Int = 3,
    iPhoneLandscape: Int = 6,
    iPad: Int = 5,
    isLandscape: Bool = false
) -> [GridItem] {
    let count: Int
    if isIPad {
        count = iPad
    } else {
        count = isLandscape ? iPhoneLandscape : iPhone
    }
    return Array(repeating: GridItem(.flexible()), count: count)
}
