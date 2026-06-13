//
//  Constants.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import SwiftUI

struct BLEConstants {
    // Service and Characteristic UUIDs
    static let serviceUUID = "4A524954-5350-4545-4400-000000000001"
    static let speedCharacteristicUUID = "4A524954-5350-4545-4400-000000000002"
    static let batteryCharacteristicUUID = "4A524954-5350-4545-4400-000000000003"

    // Device name
    static let deviceName = "Speed Machine"
}

struct AppColors {
    // Primary colors
    static let primaryBlack = Color(hex: "000000")
    static let background = Color(hex: "ffffff")
    static let backgroundAlt = Color(hex: "f5f5f5")

    // Accent colors
    static let accentGreen = Color(hex: "22C55E")
    static let accentLight = Color(hex: "dcfce7")
    static let accentBright = Color(hex: "22C55E")

    // Text colors
    static let textMuted = Color(hex: "525252")
    static let textSubdued = Color(hex: "a1a1a1")
    static let border = Color(hex: "f0f0f0")
    static let surfaceAlt = Color(hex: "f5f5f5")

    // Status colors
    static let error = Color(hex: "DC2626")
    static let bleBlue = Color(hex: "1D4ED8")
    static let accentAmber = Color(hex: "F59E0B")
}

struct DesignConstants {
    static let cornerRadiusButton: CGFloat = 12
    static let cornerRadiusCard: CGFloat = 20
    static let borderWidthBold: CGFloat = 4
    static let borderWidthNormal: CGFloat = 2
}

struct TrainingConstants {
    static let totalTracks = 30
    static let combineShots = 18
}

// Zone definitions
struct SpeedZone {
    let number: Int
    let name: String
    let speedRange: ClosedRange<Int>
    let tolerance: Float
    let multiplier: Float

    static let zones = [
        SpeedZone(number: 1, name: "Touch",    speedRange: 3...6,   tolerance: 0.5, multiplier: 1.0),
        SpeedZone(number: 2, name: "Moderate", speedRange: 7...9,   tolerance: 0.5, multiplier: 1.15),
        SpeedZone(number: 3, name: "Firm",     speedRange: 10...12, tolerance: 0.6, multiplier: 1.35),
        SpeedZone(number: 4, name: "Power",    speedRange: 13...15, tolerance: 0.7, multiplier: 1.6)
    ]

    static func getZone(for speed: Int) -> SpeedZone {
        return zones.first { $0.speedRange.contains(speed) } ?? zones[0]
    }
}

// Make/miss classification math.
// All speed comparisons happen in integer tenths of a MPH (the device/display
// resolution). In 32-bit Float, 10.6 − 10.0 = 0.6000004 while the tolerance
// 0.6 stores as 0.6000000, so `abs(speed − target) <= tolerance` fails at the
// exact boundary — a 10.6 MPH putt at a 10 MPH ±0.6 target read as a miss.
// Integer tenths make the boundary exact.
enum SpeedMath {
    /// Speed in integer tenths of a MPH.
    static func tenths(_ value: Float) -> Int {
        return Int((value * 10).rounded())
    }

    /// Make/miss vs target ± tolerance.
    static func isInZone(actual: Float, target: Int, tolerance: Float) -> Bool {
        return abs(tenths(actual) - target * 10) <= tenths(tolerance)
    }

    /// Make/miss vs an explicit accept range (block.acceptRange).
    static func isInZone(actual: Float, min: Float, max: Float) -> Bool {
        let a = tenths(actual)
        return a >= tenths(min) && a <= tenths(max)
    }
}

// Accuracy tiers
enum AccuracyTier: String {
    case perfect = "Perfect"
    case excellent = "Excellent"
    case good = "Good"
    case inZone = "In Zone"
    case close = "Close"
    case miss = "Miss"

    var basePoints: Int {
        switch self {
        case .perfect: return 10
        case .excellent: return 8
        case .good: return 6
        case .inZone: return 4
        case .close: return 2
        case .miss: return 0
        }
    }

    var color: Color {
        switch self {
        case .perfect: return AppColors.accentBright
        case .excellent: return AppColors.accentGreen
        case .good: return .green
        case .inZone: return .blue
        case .close: return .orange
        case .miss: return AppColors.error
        }
    }
}
