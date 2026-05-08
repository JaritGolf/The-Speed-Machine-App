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
    static let primaryBlack = Color(hex: "0a0a0a")
    static let background = Color(hex: "ffffff")
    static let backgroundAlt = Color(hex: "f5f5f5")

    // Accent colors
    static let accentGreen = Color(hex: "15803d")
    static let accentLight = Color(hex: "dcfce7")
    static let accentBright = Color(hex: "22c55e")

    // Text colors
    static let textMuted = Color(hex: "525252")
    static let border = Color(hex: "e5e5e5")

    // Status colors
    static let error = Color(hex: "EF4444")
    static let bleBlue = Color(hex: "3B82F6")
    static let accentAmber = Color(hex: "D97706")
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
        SpeedZone(number: 1, name: "Zone 1", speedRange: 3...9, tolerance: 0.5, multiplier: 1.0),
        SpeedZone(number: 2, name: "Zone 2", speedRange: 10...12, tolerance: 0.6, multiplier: 1.1),
        SpeedZone(number: 3, name: "Zone 3", speedRange: 13...16, tolerance: 0.7, multiplier: 1.25),
        SpeedZone(number: 4, name: "Zone 4", speedRange: 17...18, tolerance: 0.8, multiplier: 1.5),
        SpeedZone(number: 5, name: "Zone 5", speedRange: 19...20, tolerance: 0.9, multiplier: 2.0)
    ]

    static func getZone(for speed: Int) -> SpeedZone {
        return zones.first { $0.speedRange.contains(speed) } ?? zones[0]
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
