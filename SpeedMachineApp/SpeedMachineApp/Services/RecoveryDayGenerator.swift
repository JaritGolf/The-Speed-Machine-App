//
//  RecoveryDayGenerator.swift
//  SpeedMachine
//
//  Phase 4 — Auto-prescribed recovery day on hard-gate failure.
//
//  When the user fails a hard gate test, the next day inserted is a generated
//  RecoveryDay built from the user's weakest speed in the failed zone:
//    • 4 blocks, ~12 minutes
//    • Block 1 — warm-up: full zone pool, skipGating
//    • Block 2 — blocked practice: 60% reps on weakest speed (hard-gated)
//    • Block 3 — adjacent integration: 40% reps on adjacent speeds (soft-gated)
//    • Block 4 — cool-down: weakest speed, reduced count, skipGating
//
//  The generated day does NOT count against the 30-day program day count
//  (isRecoveryDay = true in the returned TrainingTrack).
//
//  Per SKILL_GATING_PLAN.md §4: progressive, individually adjusted, low-stakes.
//

import Foundation

struct RecoveryDayGenerator {

    // MARK: - Public Entry Point

    /// Generate a recovery day for the zone implied by the failed gate test.
    ///
    /// - Parameters:
    ///   - failedGateId: The `gateId` string from the failed `TrainingBlock` (e.g. "gate-zone3").
    ///   - failedTrackNumber: The official day number that failed (used for the recovery label only).
    ///   - mastery: `MasteryService` instance to look up per-speed tiers.
    /// - Returns: A synthesised `TrainingTrack` ready to be presented to the user.
    static func generateRecoveryDay(
        failedGateId: String,
        failedTrackNumber: Int,
        mastery: MasteryService = .shared
    ) -> TrainingTrack {

        // Determine speed pool for the failed zone
        let zonePool = speedPool(forGateId: failedGateId)

        // Pick weakest speed — lowest tier wins; ties broken by speed (pick slower)
        let weakest = weakestSpeed(in: zonePool, mastery: mastery)

        // Adjacent speeds = all pool speeds except the weakest
        let adjacent = zonePool.filter { $0 != weakest }

        // Build 4 blocks
        let blocks = buildBlocks(weakestSpeed: weakest, adjacentSpeeds: adjacent, gateId: failedGateId)

        let recoveryLabel = "\(failedTrackNumber)R"
        let zoneName = zoneName(forGateId: failedGateId)

        return TrainingTrack(
            number: failedTrackNumber,    // same track number — marked by title, not offset
            phase: phaseNumber(forGateId: failedGateId),
            title: "Recovery Day \(recoveryLabel): \(zoneName) Focus",
            duration: "~12 min",
            targetPutts: blocks.compactMap(\.putts).reduce(0, +),
            availableSpeeds: zonePool,
            speedRange: speedRangeString(for: zonePool),
            objective: "Rebuild consistency at \(weakest) MPH before retrying the gate test.",
            science: ScienceInfo(
                principle: "Mastery Learning",
                explanation: "Extra blocked practice at the weakest speed closes the gap before the gate retest.",
                citation: "Bloom, 1968 / Guadagnoli & Lee, 2004"
            ),
            blocks: blocks,
            successMetrics: [
                SuccessMetric(metric: "Zone accuracy at \(weakest) MPH", target: "≥ 65%", note: nil)
            ],
            coachingNotes: "Focus on feel at \(weakest) MPH. Slow, deliberate setup for each putt.",
            warnings: []
        )
    }

    // MARK: - Block Builder

    private static func buildBlocks(
        weakestSpeed: Int,
        adjacentSpeeds: [Int],
        gateId: String
    ) -> [TrainingBlock] {

        let allSpeeds = [weakestSpeed] + adjacentSpeeds
        let totalWarmupPutts = max(8, (allSpeeds.count * 2))   // 2 per speed, min 8
        let weakestPutts     = 16   // 60% of ~26; keep it a round number at this scale
        let adjacentPutts    = adjacentSpeeds.isEmpty ? 0 : 12 // 40%
        let cooldownPutts    = 8

        // Block R-A: Warm-Up (full pool, skip gating)
        let warmupBlock = makeBlock(
            id: "\(gateId)-RA",
            name: "Recovery Warm-Up",
            duration: "3 min",
            putts: totalWarmupPutts,
            type: .warmup,
            targetSpeed: nil,
            sequence: allSpeeds.shuffled(),
            adaptivePool: allSpeeds,
            skipGating: true,
            blockPassThreshold: nil,
            description: "Easy warm-up across all zone speeds. No pressure — just find the feel."
        )

        // Block R-B: Blocked practice at weakest speed (hard-gated at 65%)
        let blockedBlock = makeBlock(
            id: "\(gateId)-RB",
            name: "\(weakestSpeed) MPH Blocked Practice",
            duration: "5 min",
            putts: weakestPutts,
            type: .blocked,
            targetSpeed: weakestSpeed,
            sequence: nil,
            adaptivePool: nil,
            skipGating: false,
            blockPassThreshold: 0.65,
            description: "Focused reps at your weakest gate-test speed. Build the feel before the retest."
        )

        // Block R-C: Adjacent integration (soft-gated at 60%) — only if adjacent speeds exist
        var blocks = [warmupBlock, blockedBlock]
        if !adjacentSpeeds.isEmpty {
            let adjacentBlock = makeBlock(
                id: "\(gateId)-RC",
                name: "Zone Integration",
                duration: "4 min",
                putts: adjacentPutts,
                type: .sequence,
                targetSpeed: nil,
                sequence: buildInterleavedSequence(weakest: weakestSpeed, adjacent: adjacentSpeeds, total: adjacentPutts),
                adaptivePool: nil,
                skipGating: false,
                blockPassThreshold: 0.60,
                description: "Mix \(weakestSpeed) MPH with adjacent speeds. Transfer the feel into a moving target."
            )
            blocks.append(adjacentBlock)
        }

        // Block R-D: Cool-Down at weakest speed (skip gating)
        let cooldownBlock = makeBlock(
            id: "\(gateId)-RD",
            name: "Cool-Down",
            duration: "2 min",
            putts: cooldownPutts,
            type: .recovery,
            targetSpeed: weakestSpeed,
            sequence: nil,
            adaptivePool: nil,
            skipGating: true,
            blockPassThreshold: nil,
            description: "Finish easy. Let the session consolidate."
        )
        blocks.append(cooldownBlock)

        return blocks
    }

    // MARK: - Helpers

    /// Build an interleaved sequence mixing weakest speed (more frequent) with adjacent speeds.
    private static func buildInterleavedSequence(weakest: Int, adjacent: [Int], total: Int) -> [Int] {
        // ~50% weakest, rest spread across adjacent, total length = total
        var seq: [Int] = []
        let weakestCount = max(total / 2, 1)
        let adjCount     = total - weakestCount
        seq.append(contentsOf: Array(repeating: weakest, count: weakestCount))
        if !adjacent.isEmpty {
            for i in 0..<adjCount {
                seq.append(adjacent[i % adjacent.count])
            }
        }
        // Constrained shuffle: no more than 2 consecutive same speed
        return constrainedShuffle(seq)
    }

    private static func constrainedShuffle(_ input: [Int]) -> [Int] {
        var remaining = input
        var result: [Int] = []
        while !remaining.isEmpty {
            // Prefer speeds that don't create a run of 3+
            let lastTwo = result.suffix(2)
            let blocked: Int? = (lastTwo.count == 2 && lastTwo[0] == lastTwo[1]) ? lastTwo[0] : nil
            let candidates = remaining.enumerated().filter { $0.element != blocked }
            if let pick = (candidates.randomElement() ?? remaining.enumerated().first) {
                result.append(pick.element)
                remaining.remove(at: pick.offset)
            }
        }
        return result
    }

    private static func makeBlock(
        id: String,
        name: String,
        duration: String,
        putts: Int,
        type: BlockType,
        targetSpeed: Int?,
        sequence: [Int]?,
        adaptivePool: [Int]?,
        skipGating: Bool?,
        blockPassThreshold: Float?,
        description: String
    ) -> TrainingBlock {
        TrainingBlock(
            blockId: id,
            name: name,
            duration: duration,
            putts: putts,
            targetSpeed: targetSpeed,
            type: type,
            description: description,
            sequence: sequence,
            protocol_: nil,
            acceptRange: nil,
            focus: nil,
            rounds: nil,
            isOfficial: nil,
            gateId: nil,
            passRequirements: nil,
            onPass: nil,
            onFail: nil,
            challengeType: nil,
            consecutiveRequired: nil,
            requirements: nil,
            lives: nil,
            startSpeed: nil,
            endSpeed: nil,
            speedRange: nil,
            isPhaseAssessment: nil,
            isFinalAssessment: nil,
            allowSpeedChange: nil,
            emergencyProtocol: nil,
            entryRequirement: nil,
            maxAttempts: nil,
            safetyChecklist: nil,
            adaptiveMode: adaptivePool != nil ? "recovery" : nil,
            adaptivePool: adaptivePool,
            blockPassThreshold: blockPassThreshold,
            skipGating: skipGating
        )
    }

    // MARK: - Zone / Speed Mapping

    /// Speed pools per gate zone (matches the official gate test protocols in JSON).
    private static func speedPool(forGateId id: String) -> [Int] {
        switch id {
        case "gate-zone1": return [3, 4, 5]
        case "gate-zone2": return [5, 6, 7]
        case "gate-zone3": return [8, 9, 10]
        case "gate-zone4": return [10, 12, 14]
        case "gate-zone5": return [15, 16, 17, 18]
        default:           return [3, 4, 5]
        }
    }

    private static func zoneName(forGateId id: String) -> String {
        switch id {
        case "gate-zone1": return "Zone 1 (3–5 MPH)"
        case "gate-zone2": return "Zone 2 (5–7 MPH)"
        case "gate-zone3": return "Zone 3 (8–10 MPH)"
        case "gate-zone4": return "Zone 4 (10–14 MPH)"
        case "gate-zone5": return "Zone 5 (15–18 MPH)"
        default:           return "Zone"
        }
    }

    private static func phaseNumber(forGateId id: String) -> Int {
        switch id {
        case "gate-zone1", "gate-zone2": return 1
        case "gate-zone3", "gate-zone4": return 2
        case "gate-zone5":               return 3
        default:                         return 1
        }
    }

    private static func speedRangeString(for pool: [Int]) -> String {
        guard let lo = pool.min(), let hi = pool.max() else { return "" }
        return lo == hi ? "\(lo) MPH" : "\(lo)–\(hi) MPH"
    }

    /// Weakest speed = lowest mastery tier; ties resolved by picking the slowest speed
    /// (safer to drill the entry speed first).
    private static func weakestSpeed(in pool: [Int], mastery: MasteryService) -> Int {
        return pool.min(by: { a, b in
            let ta = mastery.tier(forSpeed: a)
            let tb = mastery.tier(forSpeed: b)
            if ta != tb { return ta < tb }
            return a < b   // tie-break: prefer slower speed
        }) ?? pool.first ?? 3
    }
}
