//
//  SpeedMathTests.swift
//  SpeedMachineAppTests
//
//  Boundary regression tests for make/miss classification.
//  Guards against the Float precision bug where a 10.6 MPH putt at a
//  10 MPH ±0.6 target was classified a miss (10.6 − 10.0 = 0.6000004 in
//  Float, which is greater than Float(0.6) = 0.6000000).
//

import Testing
@testable import SpeedMachineApp

struct SpeedMathTests {

    // MARK: - Exact boundary putts are makes (every zone, both edges)

    @Test(arguments: [
        // (actual, target, tolerance)
        (Float(2.5),  3,  Float(0.5)),
        (Float(3.5),  3,  Float(0.5)),
        (Float(6.5),  6,  Float(0.5)),
        (Float(7.5),  7,  Float(0.5)),
        (Float(9.4),  10, Float(0.6)),  // the reported bug
        (Float(10.6), 10, Float(0.6)),  // the reported bug
        (Float(10.4), 11, Float(0.6)),
        (Float(11.6), 11, Float(0.6)),
        (Float(11.4), 12, Float(0.6)),
        (Float(12.6), 12, Float(0.6)),
        (Float(12.3), 13, Float(0.7)),
        (Float(13.7), 13, Float(0.7)),
        (Float(14.3), 15, Float(0.7)),
        (Float(15.7), 15, Float(0.7)),
    ])
    func boundaryPuttIsMake(_ putt: (Float, Int, Float)) {
        #expect(SpeedMath.isInZone(actual: putt.0, target: putt.1, tolerance: putt.2))
    }

    // MARK: - Just outside the zone is a miss

    @Test(arguments: [
        (Float(10.7), 10, Float(0.6)),
        (Float(9.3),  10, Float(0.6)),
        (Float(11.7), 11, Float(0.6)),
        (Float(13.8), 13, Float(0.7)),
        (Float(6.6),  6,  Float(0.5)),
    ])
    func outsidePuttIsMiss(_ putt: (Float, Int, Float)) {
        #expect(!SpeedMath.isInZone(actual: putt.0, target: putt.1, tolerance: putt.2))
    }

    // MARK: - Raw BLE noise near the boundary rounds to the displayed value

    @Test func bleNoiseAtBoundaryIsMake() {
        // The device float can arrive as 10.6000004 or 10.5999996 — both
        // display as "10.6" and both must classify as the display does.
        #expect(SpeedMath.isInZone(actual: 10.6000004, target: 10, tolerance: 0.6))
        #expect(SpeedMath.isInZone(actual: 10.5999996, target: 10, tolerance: 0.6))
        #expect(SpeedMath.isInZone(actual: 10.649, target: 10, tolerance: 0.6))  // displays 10.6
        #expect(!SpeedMath.isInZone(actual: 10.651, target: 10, tolerance: 0.6)) // displays 10.7
    }

    // MARK: - Accept-range blocks share the same boundary behavior

    @Test func acceptRangeBoundaries() {
        #expect(SpeedMath.isInZone(actual: 9.4, min: 9.4, max: 10.6))
        #expect(SpeedMath.isInZone(actual: 10.6, min: 9.4, max: 10.6))
        #expect(!SpeedMath.isInZone(actual: 10.7, min: 9.4, max: 10.6))
        #expect(!SpeedMath.isInZone(actual: 9.3, min: 9.4, max: 10.6))
    }

    // MARK: - Combine scoring tiers at target 10 (±0.6)

    @Test func combineTiersAtTarget10() {
        let game = CombineGame()
        // dev 0.0 and 0.1 → perfect (≤ 0.15), 0.2/0.3 → excellent (≤ 0.30),
        // 0.4 → good (≤ 0.45), 0.5/0.6 → in zone (≤ 0.60), 0.7–0.9 → close,
        // 1.0 → miss.
        #expect(game.calculateScore(target: 10, actual: 10.0).tier == .perfect)
        #expect(game.calculateScore(target: 10, actual: 10.1).tier == .perfect)
        #expect(game.calculateScore(target: 10, actual: 10.2).tier == .excellent)
        #expect(game.calculateScore(target: 10, actual: 9.7).tier == .excellent)
        #expect(game.calculateScore(target: 10, actual: 10.4).tier == .good)
        #expect(game.calculateScore(target: 10, actual: 10.5).tier == .inZone)
        #expect(game.calculateScore(target: 10, actual: 10.6).tier == .inZone)  // was "close" pre-fix
        #expect(game.calculateScore(target: 10, actual: 10.7).tier == .close)
        #expect(game.calculateScore(target: 10, actual: 10.9).tier == .close)
        #expect(game.calculateScore(target: 10, actual: 11.0).tier == .miss)
    }
}
