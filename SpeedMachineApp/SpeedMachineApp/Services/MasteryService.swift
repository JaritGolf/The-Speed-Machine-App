//
//  MasteryService.swift
//  SpeedMachine
//
//  Phase 1 — Telemetry skeleton. Computes mastery tiers and block thresholds,
//  logs them, and exposes them to the UI. Does NOT enforce gating yet.
//  Enforcement begins in Phase 3 (soft gates) and Phase 4 (hard gates).
//
//  All tier thresholds and phase floors come from SKILL_GATING_PLAN.md (locked).
//

import Foundation
import CoreData

// MARK: - Mastery Tier

/// Five-tier scale derived from per-speed SpeedProfileData.
/// The foundation for all gating layers and the adaptive engine (Phase 2+).
enum MasteryTier: Int, Comparable {
    case unpracticed = 0  // < 10 lifetime reps
    case familiar    = 1  // ≥ 10 reps, ≥ 40% lifetime accuracy
    case competent   = 2  // ≥ 20 reps, ≥ 60% accuracy, std dev ≤ 0.8
    case proficient  = 3  // ≥ 30 reps, ≥ 75% accuracy, std dev ≤ 0.6
    case mastered    = 4  // ≥ 40 reps, ≥ 85% accuracy, std dev ≤ 0.5

    static func < (lhs: MasteryTier, rhs: MasteryTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .unpracticed: return "Unpracticed"
        case .familiar:    return "Familiar"
        case .competent:   return "Competent"
        case .proficient:  return "Proficient"
        case .mastered:    return "Mastered"
        }
    }

    var shortName: String {
        switch self {
        case .unpracticed: return "T0"
        case .familiar:    return "T1"
        case .competent:   return "T2"
        case .proficient:  return "T3"
        case .mastered:    return "T4"
        }
    }
}

// MARK: - Gate Force

/// Whether a block or gate test is soft-gated or hard-gated.
/// Determined by speed (≥ 11 MPH = hard), not by track.
enum GateForce: String {
    case soft   // Override always allowed; repeat / continue anyway
    case hard   // Override only enabled after 3 failed attempts
    case none   // No gating (skipGating, pressure built-in, combine, etc.)
}

// MARK: - Block Evaluation

/// Result from evaluating a block against its threshold.
struct BlockEvaluation {
    let passed: Bool
    let zoneAccuracy: Float         // 0.0–1.0 actual
    let threshold: Float            // 0.0–1.0 required
    let gateForce: GateForce
    let thresholdSource: String     // "block" (per-block override) or "phase" (floor)
    /// Number of prior non-override failures for this block+track (Phase 4 hard-gate retry tracking).
    /// Hard gate "Continue anyway" is enabled only after failedAttemptCount ≥ 3.
    let failedAttemptCount: Int
}

// MARK: - MasteryService

/// Reads SpeedProfileData to compute mastery tiers, phase floors, and block thresholds.
/// Phase 1: compute + log + expose. Phase 3+: enforce.
class MasteryService {
    static let shared = MasteryService()

    private let statsService = StatsService.shared
    private let dataService  = DataService.shared

    private init() {}

    // MARK: - Tier Computation

    /// Compute the mastery tier for a given speed (3–20 MPH).
    /// Respects tierOverride (-1 = auto).
    /// Applies 14-day decay: speed not practiced in ≥ 14 calendar days drops one tier (min Tier 1).
    func tier(forSpeed speed: Int) -> MasteryTier {
        guard let profile = statsService.speedProfiles[speed] else { return .unpracticed }

        // Manual override wins
        if profile.tierOverride >= 0 {
            return MasteryTier(rawValue: Int(profile.tierOverride)) ?? .unpracticed
        }

        let computed = computedTier(for: profile)

        // 14-day decay rule — if ≥ 14 calendar days since last practice, drop one tier (min Tier 1)
        if computed > .familiar, let lastPracticed = profile.lastPracticedAt {
            let daysSince = Calendar.current.dateComponents([.day], from: lastPracticed, to: Date()).day ?? 0
            if daysSince >= 14 {
                let decayed = MasteryTier(rawValue: computed.rawValue - 1) ?? .familiar
                return max(decayed, .familiar)
            }
        }

        return computed
    }

    /// Raw tier computation ignoring override and decay.
    func computedTier(for profile: SpeedProfileData) -> MasteryTier {
        let totalPutts = Int(profile.totalPutts)
        let accuracy   = profile.accuracy          // 0–100 scale
        let stdDev     = profile.standardDeviation // MPH

        if totalPutts < 10 { return .unpracticed }
        if totalPutts < 20 || accuracy < 40.0 { return .familiar }
        if totalPutts < 30 || accuracy < 60.0 || stdDev > 0.8 { return .competent }
        if totalPutts < 40 || accuracy < 75.0 || stdDev > 0.6 { return .proficient }
        if accuracy >= 85.0 && stdDev <= 0.5 { return .mastered }
        return .proficient  // ≥ 40 reps but doesn't yet hit mastered thresholds
    }

    // MARK: - Recent Accuracy

    /// Recent accuracy from the rolling 20-putt window (0.0–1.0).
    /// Falls back to lifetime accuracy when recent window is too small (< 5 putts).
    func recentAccuracy(forSpeed speed: Int) -> Double {
        guard let profile = statsService.speedProfiles[speed] else { return 0 }
        let recent = Int(profile.recentPutts)
        let recentOnTarget = Int(profile.recentOnTargetPutts)
        if recent >= 5 {
            return Double(recentOnTarget) / Double(recent)
        }
        // Fall back to lifetime
        guard profile.totalPutts > 0 else { return 0 }
        return Double(profile.onTargetPutts) / Double(profile.totalPutts)
    }

    // MARK: - Phase Floors

    /// Phase floor (0.0–1.0) for the given day number.
    /// Locked table from SKILL_GATING_PLAN.md.
    func phaseFloor(forTrack track: Int) -> Float {
        switch track {
        case 1...4:  return 0.40
        case 5...9:  return 0.50
        case 10...12: return 0.60
        case 13...18: return 0.65
        case 19...24: return 0.70
        case 25...30: return 0.75
        default:     return 0.75
        }
    }

    // MARK: - Gate Force

    /// Whether a block is soft or hard gated.
    /// Hard if any target speed ≥ 11 MPH; soft for ≤ 10 MPH; none for skipGating/pressure/combine.
    func gateForce(for block: TrainingBlock) -> GateForce {
        // Never gate these block types (built-in completion logic or free-practice intent)
        if block.skipGating == true { return .none }
        if block.type == .combine    { return .none }
        if block.type == .recovery   { return .none }
        // Warmup blocks are free-practice warm-ups — always advance regardless of accuracy
        if block.type == .warmup     { return .none }
        // Exploration blocks are ungated unless explicitly given skipGating:false
        if block.type == .exploration && block.skipGating != false { return .none }

        // Pressure blocks use built-in pass/fail — no external gate
        if block.type == .pressure { return .none }

        // Gate tests go through Layer D — handled separately
        if block.type == .gateTest { return .none }

        // Determine hardest speed in the block
        let hardestSpeed = maxSpeed(for: block)
        if hardestSpeed == 0 { return .none }       // Can't determine speed pool
        return hardestSpeed >= 11 ? .hard : .soft
    }

    /// Returns the highest target speed in the block's pool.
    private func maxSpeed(for block: TrainingBlock) -> Int {
        var speeds: [Int] = []
        if let t = block.targetSpeed { speeds.append(t) }
        if let seq = block.sequence  { speeds.append(contentsOf: seq) }
        if let proto = block.protocol_ { speeds.append(contentsOf: proto.map { $0.speed }) }
        if let pool = block.adaptivePool { speeds.append(contentsOf: pool) }
        return speeds.max() ?? 0
    }

    // MARK: - Block Threshold

    /// The pass threshold (0.0–1.0) for a block in a given track.
    /// Uses per-block override if present; falls back to phase floor.
    /// Returns nil when no threshold applies (skipGating, pressure, combine, etc.).
    func blockThreshold(for block: TrainingBlock, track: Int) -> Float? {
        // No gating for these
        let force = gateForce(for: block)
        if force == .none { return nil }

        // Per-block explicit override wins over phase floor
        if let explicit = block.blockPassThreshold {
            return explicit
        }

        // Phase floor
        return phaseFloor(forTrack: track)
    }

    // MARK: - Block Evaluation (enforced from Phase 3 onwards)

    /// Evaluates a block against its pass threshold.
    /// Phase 3+: returned result is acted on in TrainingViewModel.completeBlock().
    /// Phase 4+: failedAttemptCount determines hard-gate retry eligibility.
    func evaluateBlock(_ session: SessionProgress, block: TrainingBlock, track: Int) -> BlockEvaluation {
        let force = gateForce(for: block)
        let failedCount = DataService.shared.getFailedAttemptCount(trackNumber: track, blockId: block.blockId)

        guard force != .none else {
            return BlockEvaluation(passed: true, zoneAccuracy: session.zoneAccuracy,
                                   threshold: 0, gateForce: .none, thresholdSource: "none",
                                   failedAttemptCount: 0)
        }

        let threshold: Float
        let source: String
        if let explicit = block.blockPassThreshold {
            threshold = explicit
            source = "block"
        } else {
            threshold = phaseFloor(forTrack: track)
            source = "phase"
        }

        let passed = session.zoneAccuracy >= threshold
        return BlockEvaluation(passed: passed, zoneAccuracy: session.zoneAccuracy,
                               threshold: threshold, gateForce: force, thresholdSource: source,
                               failedAttemptCount: failedCount)
    }

    // MARK: - Gate Test Four-Criterion Evaluation (Phase 4)

    /// Evaluates a completed gate test session against the four locked criteria.
    /// Returns a fully populated GateTestResult including per-criterion failure reasons.
    func evaluateGateTest(
        session: SessionProgress,
        block: TrainingBlock,
        gateId: String,
        requirements: PassRequirements
    ) -> GateTestResult {
        let putts = session.puttRecords
        let totalPutts = putts.count

        // ── Criterion 1: min overall in-zone ────────────────────────────
        let overallInZone = putts.filter { $0.isInZone }.count
        let minOverall = requirements.minOverallInZone ?? Int(Float(totalPutts) * 0.67)
        let passesOverall = overallInZone >= minOverall

        // ── Criterion 2: min per-speed in-zone ───────────────────────────
        // Build per-speed in-zone counts from puttRecords
        var speedInZone: [Int: Int]   = [:]
        var speedTotal:  [Int: Int]   = [:]
        for putt in putts {
            let s = Int(putt.targetSpeed.rounded())
            speedTotal[s, default: 0] += 1
            if putt.isInZone { speedInZone[s, default: 0] += 1 }
        }
        let perSpeedAccuracy: [Int: Float] = speedTotal.mapValues { total in
            let inZone = speedInZone.values.first ?? 0  // placeholder — fixed below
            return total > 0 ? Float(inZone) / Float(total) : 0
        }
        // Rebuild correctly keyed accuracy map
        var speedAccuracyMap: [Int: Float] = [:]
        for (speed, total) in speedTotal where total > 0 {
            let inZ = speedInZone[speed, default: 0]
            speedAccuracyMap[speed] = Float(inZ) / Float(total)
        }
        let minPerSpeed = requirements.minPerSpeedInZone ?? 1
        // For each speed in the protocol, check if in-zone count ≥ minPerSpeed
        let protocolSpeeds = (block.protocol_ ?? []).map { $0.speed }
        let speedsFailing = protocolSpeeds.filter { s in
            (speedInZone[s, default: 0]) < minPerSpeed
        }
        let passesPerSpeed = speedsFailing.isEmpty

        // ── Criterion 3: average absolute deviation cap ─────────────────
        let avgDevCap = requirements.avgDeviationCapMph ?? Float.greatestFiniteMagnitude
        let avgDev: Float = totalPutts > 0
            ? putts.reduce(0) { $0 + $1.difference } / Float(totalPutts)
            : 0
        let passesAvgDev = avgDev <= avgDevCap

        // ── Criterion 4: max single miss cap ─────────────────────────────
        let maxMissCap = requirements.maxSingleMissMph ?? Float.greatestFiniteMagnitude
        let maxDev: Float = putts.map { $0.difference }.max() ?? 0
        let passesMaxMiss = maxDev <= maxMissCap

        // ── Failure reasons ───────────────────────────────────────────────
        var reasons: [GateFailureReason] = []
        if !passesOverall   { reasons.append(.zoneAccuracy) }
        if !passesPerSpeed  { reasons.append(.perSpeedFloor) }
        if !passesAvgDev    { reasons.append(.deviationCap) }
        if !passesMaxMiss   { reasons.append(.catastrophicMiss) }

        let passed = reasons.isEmpty

        return GateTestResult(
            gateId: gateId,
            passed: passed,
            zoneAccuracyRequired: minOverall,
            zoneAccuracyAchieved: overallInZone,
            totalPutts: totalPutts,
            perSpeedAccuracy: speedAccuracyMap,
            avgAbsDeviation: avgDev,
            maxDeviation: maxDev,
            failureReasons: reasons
        )
    }

    // MARK: - Gate Test Force (for Layer D)

    /// The force level for an official gate test track.
    func gateForce(forTrack track: Int) -> GateForce {
        switch track {
        case 5, 9:         return .soft
        case 12, 19, 25, 30: return .hard
        default:           return .none
        }
    }

    // MARK: - Tier Summary (for Stats UI)

    /// All 18 speeds (3–20) with their current mastery tier.
    var allTiers: [(speed: Int, tier: MasteryTier)] {
        return (3...20).map { speed in
            (speed: speed, tier: tier(forSpeed: speed))
        }
    }

    /// Speeds at Tier 0 (unpracticed) or Tier 1 (familiar) — the "needs work" list.
    var weakSpeeds: [(speed: Int, tier: MasteryTier)] {
        return allTiers.filter { $0.tier <= .familiar }
    }

    // MARK: - Phase 5: Retroactive Mastery Recomputation

    /// UserDefaults key guarding the one-time Phase 5 migration.
    static let recomputeMigrationKey = "masteryRecomputedFromHistory_v1"

    /// Whether the Phase 5 migration has already run on this device.
    var hasRecomputedFromHistory: Bool {
        UserDefaults.standard.bool(forKey: MasteryService.recomputeMigrationKey)
    }

    /// Resets all `SpeedProfileData` aggregates and replays every `PuttRecordData` row
    /// from scratch (sorted by timestamp) to produce accurate mastery tiers for in-flight
    /// users who advanced before the gating system shipped.
    ///
    /// - Resets: totalPutts, onTargetPutts, deviation stats, streaks, recentPutts/recentOnTargetPutts
    /// - Preserves: tierOverride, lastPracticedAt (updated to the most recent putt timestamp)
    /// - Rolling window: last 20 putts per speed are stored in recentPutts/recentOnTargetPutts
    /// - Guards itself with `recomputeMigrationKey` so it only runs once.
    ///
    /// Call from the app startup path (e.g. HomeView.onAppear) after a nil check on
    /// `hasRecomputedFromHistory`. After calling, show `SkillReassessmentView` once.
    func recomputeFromHistory() {
        guard !hasRecomputedFromHistory else { return }

        let context = DataService.shared.container.viewContext

        // ── 1. Fetch all profile objects (speeds 3–20) ───────────────────
        let profileRequest: NSFetchRequest<SpeedProfileData> = SpeedProfileData.fetchRequest()
        guard let profiles = try? context.fetch(profileRequest) else {
            UserDefaults.standard.set(true, forKey: MasteryService.recomputeMigrationKey)
            return
        }

        // Reset all aggregates (preserve tierOverride)
        for profile in profiles {
            profile.totalPutts            = 0
            profile.onTargetPutts         = 0
            profile.totalDeviation        = 0
            profile.totalSignedDeviation  = 0
            profile.sumSquaredDeviation   = 0
            profile.sumActualSpeed        = 0
            profile.bestStreak            = 0
            profile.currentStreak         = 0
            profile.recentPutts           = 0
            profile.recentOnTargetPutts   = 0
            profile.lastPracticedAt       = nil
            // tierOverride intentionally preserved
        }

        // Build a speed → profile lookup for O(1) access in the replay loop
        var profileMap: [Int: SpeedProfileData] = [:]
        for p in profiles {
            profileMap[Int(p.targetSpeed)] = p
        }

        // ── 2. Fetch all PuttRecordData sorted oldest-first ─────────────
        let puttRequest: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
        puttRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PuttRecordData.timestamp, ascending: true)]

        guard let allPutts = try? context.fetch(puttRequest), !allPutts.isEmpty else {
            UserDefaults.standard.set(true, forKey: MasteryService.recomputeMigrationKey)
            return
        }

        // ── 3. Replay each putt into the profile ─────────────────────────
        // Rolling window: keep per-speed ordered lists of recent results (cap 20)
        var recentWindow: [Int: [Bool]] = [:]   // speed → [isOnTarget], newest-last

        for putt in allPutts {
            let speed = Int(roundf(putt.targetSpeed))
            guard speed >= 3, speed <= 20, let profile = profileMap[speed] else { continue }

            let deviation        = abs(Double(putt.actualSpeed) - Double(putt.targetSpeed))
            let signedDeviation  = Double(putt.actualSpeed) - Double(putt.targetSpeed)

            profile.totalPutts           += 1
            profile.totalDeviation       += deviation
            profile.totalSignedDeviation += signedDeviation
            profile.sumSquaredDeviation  += deviation * deviation
            profile.sumActualSpeed       += Double(putt.actualSpeed)
            profile.lastPracticedAt       = putt.timestamp

            if putt.isOnTarget {
                profile.onTargetPutts   += 1
                profile.currentStreak   += 1
                if profile.currentStreak > profile.bestStreak {
                    profile.bestStreak = profile.currentStreak
                }
            } else {
                profile.currentStreak = 0
            }

            // Rolling-20 window update
            var window = recentWindow[speed] ?? []
            window.append(putt.isOnTarget)
            if window.count > 20 { window.removeFirst() }
            recentWindow[speed] = window

            profile.recentPutts         = Int16(window.count)
            profile.recentOnTargetPutts = Int16(window.filter { $0 }.count)
        }

        // ── 4. Persist and mark migration done ───────────────────────────
        try? context.save()
        UserDefaults.standard.set(true, forKey: MasteryService.recomputeMigrationKey)

        // Reload StatsService so the UI reflects updated profiles
        StatsService.shared.loadSpeedProfiles()
        print("✅ MasteryService.recomputeFromHistory() complete — \(allPutts.count) putts replayed across \(profiles.count) speed profiles")
    }

    // MARK: - Adaptive Speed Lock (Phase 2 — Layer C)

    /// Returns true if `speed` can appear in an adaptive sequence pool.
    ///
    /// Unlock rule: the user must be Tier 1+ (Familiar) on the speed immediately
    /// below `speed` within the given pool. For cross-zone transitions where the
    /// next-lower speed in the full range isn't in the pool, the prerequisite is
    /// the highest pool speed below `speed`. The lowest speed in any pool is
    /// always unlocked — there is no prerequisite for the entry point.
    ///
    /// This is Layer C from the skill-gating plan. Block-type exclusions (gate tests,
    /// assessments, recovery, etc.) are handled upstream by `adaptationLevel` returning
    /// `.none` — this method is only called for adaptable blocks.
    func isSpeedUnlockedForAdaptive(_ speed: Int, in pool: [Int]) -> Bool {
        let sortedPool = pool.sorted()
        // Lowest speed in pool is always unlocked — no prerequisite for the entry point
        guard let lowestInPool = sortedPool.first, speed > lowestInPool else { return true }
        // Speed not in pool — treat as unlocked (defensive)
        guard sortedPool.contains(speed) else { return true }
        // Prerequisite is the highest pool speed that sits below this one
        guard let prerequisite = sortedPool.last(where: { $0 < speed }) else { return true }
        return tier(forSpeed: prerequisite) >= .familiar
    }
}
