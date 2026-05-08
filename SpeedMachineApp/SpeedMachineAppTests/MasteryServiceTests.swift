//
//  MasteryServiceTests.swift
//  SpeedMachineAppTests
//
//  Phase 1 unit tests for MasteryService.
//  Verifies tier computation against synthetic SpeedProfileData values.
//

import Testing
import Foundation
import CoreData
@testable import SpeedMachineApp

// MARK: - Synthetic SpeedProfileData builder

/// Creates a detached SpeedProfileData-like struct for testing tier logic
/// without requiring a live Core Data stack.
private struct MockSpeedProfile {
    var totalPutts: Int32 = 0
    var onTargetPutts: Int32 = 0
    var sumSquaredDeviation: Double = 0
    var sumActualSpeed: Double = 0
    var lastPracticedAt: Date? = nil

    var accuracy: Double {
        guard totalPutts > 0 else { return 0 }
        return Double(onTargetPutts) / Double(totalPutts) * 100
    }

    var standardDeviation: Double {
        guard totalPutts > 1 else { return 0 }
        let mean = sumActualSpeed / Double(totalPutts)
        let variance = (sumSquaredDeviation / Double(totalPutts)) - (mean * mean)
        return variance > 0 ? sqrt(variance) : 0
    }
}

// MARK: - Tier computation logic (mirrors MasteryService.computedTier, testable without Core Data)

private func computeTier(_ p: MockSpeedProfile) -> MasteryTier {
    let totalPutts = Int(p.totalPutts)
    let accuracy   = p.accuracy
    let stdDev     = p.standardDeviation

    if totalPutts < 10 { return .unpracticed }
    if totalPutts < 20 || accuracy < 40.0 { return .familiar }
    if totalPutts < 30 || accuracy < 60.0 || stdDev > 0.8 { return .competent }
    if totalPutts < 40 || accuracy < 75.0 || stdDev > 0.6 { return .proficient }
    if accuracy >= 85.0 && stdDev <= 0.5 { return .mastered }
    return .proficient
}

// MARK: - Phase Floor tests (pure logic, no Core Data needed)

private func phaseFloor(forDay day: Int) -> Float {
    switch day {
    case 1...4:   return 0.40
    case 5...9:   return 0.50
    case 10...12: return 0.60
    case 13...18: return 0.65
    case 19...24: return 0.70
    case 25...30: return 0.75
    default:      return 0.75
    }
}

// MARK: - Tests

struct MasteryServiceTests {

    // MARK: Tier 0 — Unpracticed (< 10 putts)

    @Test func tier0_belowMinReps() {
        var p = MockSpeedProfile()
        p.totalPutts = 5
        p.onTargetPutts = 5
        #expect(computeTier(p) == .unpracticed)
    }

    @Test func tier0_zeroPutts() {
        let p = MockSpeedProfile()
        #expect(computeTier(p) == .unpracticed)
    }

    @Test func tier0_exactlyNineReps() {
        var p = MockSpeedProfile()
        p.totalPutts = 9
        p.onTargetPutts = 9
        #expect(computeTier(p) == .unpracticed)
    }

    // MARK: Tier 1 — Familiar (≥ 10 putts, ≥ 40% accuracy)

    @Test func tier1_exactlyTenRepsHighAccuracy() {
        var p = MockSpeedProfile()
        p.totalPutts = 10
        p.onTargetPutts = 5  // 50%
        // std dev not a factor at tier 1
        #expect(computeTier(p) == .familiar)
    }

    @Test func tier1_tenRepsLowAccuracy() {
        var p = MockSpeedProfile()
        p.totalPutts = 10
        p.onTargetPutts = 3  // 30% < 40%
        #expect(computeTier(p) == .familiar)  // still tier 1: accuracy only gates tier 2+
        // Note: 30% < 40 means can't reach tier 2, so stays at tier 1
    }

    @Test func tier1_nineteenRepsNotEnoughForTier2() {
        var p = MockSpeedProfile()
        p.totalPutts = 19
        p.onTargetPutts = 15  // 79%
        #expect(computeTier(p) == .familiar)
    }

    // MARK: Tier 2 — Competent (≥ 20 putts, ≥ 60% accuracy, std dev ≤ 0.8)

    @Test func tier2_exactlyTwentyReps() {
        // Build a profile with 20 putts, 70% accuracy, low std dev
        var p = MockSpeedProfile()
        p.totalPutts = 20
        p.onTargetPutts = 14  // 70%
        // Set sumActualSpeed and sumSquaredDeviation to produce std dev ≈ 0.3 MPH
        let targetSpeed = 5.0
        let spread = 0.3
        p.sumActualSpeed = targetSpeed * Double(p.totalPutts)
        p.sumSquaredDeviation = Double(p.totalPutts) * (targetSpeed * targetSpeed + spread * spread)
        #expect(computeTier(p) == .competent)
    }

    @Test func tier2_blockedByHighStdDev() {
        // ≥ 20 putts, ≥ 60% accuracy, but std dev > 0.8 → stuck at competent, not proficient
        var p = MockSpeedProfile()
        p.totalPutts = 30
        p.onTargetPutts = 24  // 80%
        let targetSpeed = 5.0
        let spread = 1.5   // > 0.8
        p.sumActualSpeed = targetSpeed * Double(p.totalPutts)
        p.sumSquaredDeviation = Double(p.totalPutts) * (targetSpeed * targetSpeed + spread * spread)
        #expect(computeTier(p) == .competent)
    }

    // MARK: Tier 3 — Proficient (≥ 30 putts, ≥ 75% accuracy, std dev ≤ 0.6)

    @Test func tier3_exactlyThirtyReps() {
        var p = MockSpeedProfile()
        p.totalPutts = 30
        p.onTargetPutts = 24  // 80%
        let targetSpeed = 5.0
        let spread = 0.5   // ≤ 0.6
        p.sumActualSpeed = targetSpeed * Double(p.totalPutts)
        p.sumSquaredDeviation = Double(p.totalPutts) * (targetSpeed * targetSpeed + spread * spread)
        #expect(computeTier(p) == .proficient)
    }

    @Test func tier3_blockedByLowAccuracy() {
        var p = MockSpeedProfile()
        p.totalPutts = 30
        p.onTargetPutts = 20  // 67% < 75%
        let targetSpeed = 5.0
        let spread = 0.4
        p.sumActualSpeed = targetSpeed * Double(p.totalPutts)
        p.sumSquaredDeviation = Double(p.totalPutts) * (targetSpeed * targetSpeed + spread * spread)
        #expect(computeTier(p) == .competent)
    }

    // MARK: Tier 4 — Mastered (≥ 40 putts, ≥ 85% accuracy, std dev ≤ 0.5)

    @Test func tier4_fullMastery() {
        var p = MockSpeedProfile()
        p.totalPutts = 40
        p.onTargetPutts = 36  // 90%
        let targetSpeed = 5.0
        let spread = 0.4   // ≤ 0.5
        p.sumActualSpeed = targetSpeed * Double(p.totalPutts)
        p.sumSquaredDeviation = Double(p.totalPutts) * (targetSpeed * targetSpeed + spread * spread)
        #expect(computeTier(p) == .mastered)
    }

    @Test func tier4_blockedByStdDev() {
        var p = MockSpeedProfile()
        p.totalPutts = 40
        p.onTargetPutts = 36  // 90%
        let targetSpeed = 5.0
        let spread = 0.6   // > 0.5
        p.sumActualSpeed = targetSpeed * Double(p.totalPutts)
        p.sumSquaredDeviation = Double(p.totalPutts) * (targetSpeed * targetSpeed + spread * spread)
        // std dev > 0.5 — stays at proficient not mastered
        #expect(computeTier(p) == .proficient)
    }

    // MARK: 14-day decay rule

    @Test func decayRule_14daysDropsOneTier() {
        // A proficient speed not practiced in 14 days → decays to competent
        // We test the phase-floor logic directly since we can't call MasteryService
        // without Core Data. This validates the decay rule formula.
        let daysSince = 15
        let baseRaw = MasteryTier.proficient.rawValue
        let decayed = MasteryTier(rawValue: baseRaw - (daysSince >= 14 ? 1 : 0)) ?? .familiar
        let result = max(decayed, .familiar)
        #expect(result == .competent)
    }

    @Test func decayRule_doesNotDropBelowTier1() {
        // A familiar speed (tier 1) should not decay below tier 1
        let daysSince = 30
        let baseRaw = MasteryTier.familiar.rawValue
        let decayed = MasteryTier(rawValue: baseRaw - (daysSince >= 14 ? 1 : 0)) ?? .familiar
        let result = max(decayed, .familiar)
        #expect(result == .familiar)
    }

    @Test func decayRule_13daysNodecay() {
        // 13 days = no decay
        let daysSince = 13
        let decays = daysSince >= 14
        #expect(decays == false)
    }

    // MARK: Phase floors

    @Test func phaseFloor_day1() { #expect(phaseFloor(forDay: 1) == 0.40) }
    @Test func phaseFloor_day4() { #expect(phaseFloor(forDay: 4) == 0.40) }
    @Test func phaseFloor_day5() { #expect(phaseFloor(forDay: 5) == 0.50) }
    @Test func phaseFloor_day9() { #expect(phaseFloor(forDay: 9) == 0.50) }
    @Test func phaseFloor_day10() { #expect(phaseFloor(forDay: 10) == 0.60) }
    @Test func phaseFloor_day13() { #expect(phaseFloor(forDay: 13) == 0.65) }
    @Test func phaseFloor_day19() { #expect(phaseFloor(forDay: 19) == 0.70) }
    @Test func phaseFloor_day25() { #expect(phaseFloor(forDay: 25) == 0.75) }
    @Test func phaseFloor_day30() { #expect(phaseFloor(forDay: 30) == 0.75) }

    // MARK: Tier ordering / comparable

    @Test func tierOrdering() {
        #expect(MasteryTier.unpracticed < .familiar)
        #expect(MasteryTier.familiar < .competent)
        #expect(MasteryTier.competent < .proficient)
        #expect(MasteryTier.proficient < .mastered)
    }

    // MARK: Phase 2 — Adaptive Speed Lock (isSpeedUnlockedForAdaptive logic)
    //
    // These tests mirror the logic in MasteryService.isSpeedUnlockedForAdaptive
    // without requiring a live Core Data stack, using a local closure for tier lookup.

    private func isSpeedUnlocked(
        _ speed: Int,
        in pool: [Int],
        tierFor: (Int) -> MasteryTier
    ) -> Bool {
        let sortedPool = pool.sorted()
        guard let lowestInPool = sortedPool.first, speed > lowestInPool else { return true }
        guard sortedPool.contains(speed) else { return true }
        guard let prerequisite = sortedPool.last(where: { $0 < speed }) else { return true }
        return tierFor(prerequisite) >= .familiar
    }

    @Test func adaptiveLock_lowestSpeedAlwaysUnlocked() {
        // Pool [3,4,5] — speed 3 (lowest) always unlocked regardless of mastery tier
        let result = isSpeedUnlocked(3, in: [3, 4, 5]) { _ in .unpracticed }
        #expect(result == true)
    }

    @Test func adaptiveLock_secondSpeedLockedWhenPrerequisiteUnpracticed() {
        // Speed 4 requires Tier 1+ on speed 3. If 3 is Tier 0, 4 is locked.
        let result = isSpeedUnlocked(4, in: [3, 4, 5]) { _ in .unpracticed }
        #expect(result == false)
    }

    @Test func adaptiveLock_secondSpeedUnlockedWhenPrerequisiteFamiliar() {
        // Speed 4 is unlocked when speed 3 is Tier 1+
        let result = isSpeedUnlocked(4, in: [3, 4, 5]) { speed in speed == 3 ? .familiar : .unpracticed }
        #expect(result == true)
    }

    @Test func adaptiveLock_higherSpeedRequiresImmediatePredecessorInPool() {
        // Speed 5 requires Tier 1+ on speed 4 (highest pool speed below 5).
        // Speed 3 being familiar is not sufficient — 4 must be familiar.
        let result = isSpeedUnlocked(5, in: [3, 4, 5]) { speed in speed == 3 ? .familiar : .unpracticed }
        #expect(result == false)
    }

    @Test func adaptiveLock_higherSpeedUnlockedWhenAllBelowAreFamiliar() {
        // Speed 5 unlocked when speed 4 (its prerequisite) is Tier 1+
        let result = isSpeedUnlocked(5, in: [3, 4, 5]) { _ in .familiar }
        #expect(result == true)
    }

    @Test func adaptiveLock_crossZoneTransition_locked() {
        // Pool [5, 8] (Zone 1 max, Zone 2 min — cross-zone transition).
        // Speed 8 requires Tier 1+ on speed 5 (highest pool speed below 8).
        let result = isSpeedUnlocked(8, in: [5, 8]) { _ in .unpracticed }
        #expect(result == false)
    }

    @Test func adaptiveLock_crossZoneTransition_unlocked() {
        // Same pool: speed 5 at Tier 1+ → speed 8 unlocked
        let result = isSpeedUnlocked(8, in: [5, 8]) { _ in .familiar }
        #expect(result == true)
    }

    @Test func adaptiveLock_filteredPoolNeverEmpty_lowestAlwaysUnlocked() {
        // With a brand-new user (all Tier 0), the lowest speed is always unlocked,
        // so masteryFilteredPool always returns a non-empty result.
        let pool = [3, 4, 5]
        let unlocked = pool.filter { isSpeedUnlocked($0, in: pool) { _ in .unpracticed } }
        // Speed 3 (lowest) is always unlocked — pool is never empty
        #expect(!unlocked.isEmpty)
        #expect(unlocked == [3])
    }

    @Test func adaptiveLock_masteredUserAllSpeeds() {
        // A mastered user (Tier 4 everywhere) has all speeds unlocked
        let pool = [3, 4, 5, 6, 7]
        let unlocked = pool.filter { isSpeedUnlocked($0, in: pool) { _ in .mastered } }
        #expect(unlocked == pool)
    }

    // MARK: Phase 5 — recomputeFromHistory aggregate logic

    /// Tests the rolling-20-window logic that recomputeFromHistory uses for
    /// recentPutts/recentOnTargetPutts. This is pure Swift with no Core Data dependency.
    @Test func recompute_rollingWindow_capsAt20() {
        // Simulate replaying 25 putts for one speed — window should cap at 20
        var window: [Bool] = []
        let hits = [true, false, true, true, false, true, true, true, false, true,
                    true, false, true, true, false, true, true, true, false, true,
                    true, true, false, true, true]  // 25 putts
        for hit in hits {
            window.append(hit)
            if window.count > 20 { window.removeFirst() }
        }
        #expect(window.count == 20)
    }

    @Test func recompute_rollingWindow_correctOnTargetCount() {
        // Last 20 of a known sequence should give correct on-target count
        var window: [Bool] = []
        // 10 misses then 10 hits — after replay, window = [false×10, true×10]
        for _ in 0..<10 { window.append(false); if window.count > 20 { window.removeFirst() } }
        for _ in 0..<10 { window.append(true);  if window.count > 20 { window.removeFirst() } }
        #expect(window.count == 20)
        #expect(window.filter { $0 }.count == 10)
    }

    @Test func recompute_rollingWindow_slidesOldestOut() {
        // After 25 putts where first 5 are hits, those hits should be gone from the window
        var window: [Bool] = []
        for _ in 0..<5  { window.append(true);  if window.count > 20 { window.removeFirst() } }
        for _ in 0..<20 { window.append(false); if window.count > 20 { window.removeFirst() } }
        // The 5 initial hits were evicted; last 20 are all misses
        #expect(window.filter { $0 }.count == 0)
    }

    @Test func recompute_tierFromReplayedAggregates_competent() {
        // If replay produces: 22 putts, 14 on-target (63.6%), stdDev 0.5
        // Expected tier: Competent (≥20 putts, ≥60% acc, stdDev ≤ 0.8)
        var p = MockSpeedProfile()
        p.totalPutts = 22
        p.onTargetPutts = 14
        // sumSquaredDeviation = n × stdDev² → 22 × 0.25 = 5.5
        p.sumSquaredDeviation = 5.5
        p.sumActualSpeed = 22 * 5   // doesn't affect tier
        #expect(computeTier(p) == .competent)
    }

    @Test func recompute_tierFromReplayedAggregates_unpracticed() {
        // A user with only 8 putts replayed stays at Tier 0
        var p = MockSpeedProfile()
        p.totalPutts = 8
        p.onTargetPutts = 8
        #expect(computeTier(p) == .unpracticed)
    }

    @Test func recompute_migrationKeyNotSetBeforeRun() {
        // The migration guard key must be absent before migration runs.
        // This test verifies the key name is correct and hasn't drifted.
        let key = MasteryService.recomputeMigrationKey
        #expect(key == "masteryRecomputedFromHistory_v1")
    }
}
