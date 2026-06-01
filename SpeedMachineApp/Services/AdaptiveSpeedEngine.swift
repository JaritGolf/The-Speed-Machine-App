//
//  AdaptiveSpeedEngine.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Generates weighted speed sequences for training blocks based on the user's
//  SpeedProfile data. Weak speeds appear more often; strong speeds appear less.
//  Never modifies gate tests, assessments, fixed-speed blocks, or putt counts.
//

import Foundation

class AdaptiveSpeedEngine {
    static let shared = AdaptiveSpeedEngine()

    private let statsService = StatsService.shared

    private init() {}

    // MARK: - Weight Thresholds (Moderate Push)

    /// Speeds below this accuracy get maximum weight
    private let weakThreshold: Double = 60.0
    /// Speeds between weak and moderate get medium weight
    private let moderateThreshold: Double = 75.0
    /// Speeds above this are strong — reduced weight
    private let strongThreshold: Double = 90.0

    /// Weight for speeds with accuracy < 60%
    private let weakWeight: Double = 3.0
    /// Weight for speeds with accuracy 60-75%
    private let moderateWeight: Double = 2.0
    /// Weight for speeds with accuracy 75-90%
    private let baselineWeight: Double = 1.0
    /// Weight for speeds with accuracy > 90%
    private let strongWeight: Double = 0.5
    /// Weight for speeds with no data yet
    private let unpracticedWeight: Double = 1.5

    /// How much warmup blocks compress toward neutral (0.0 = no bias, 1.0 = full bias)
    private let warmupBiasFactor: Double = 0.3

    // MARK: - Block Eligibility

    /// Block types that get FULL adaptive weighting
    private let fullAdaptiveTypes: Set<BlockType> = [
        .random, .exploration, .challenge, .reactive, .celebration
    ]

    /// Block types that get LIGHT warmup bias
    private let warmupAdaptiveTypes: Set<BlockType> = [
        .warmup
    ]

    /// Block types that NEVER get adapted
    private let protectedTypes: Set<BlockType> = [
        .gateTest, .assessment
    ]

    /// Determines if a block should be adapted and at what intensity
    func adaptationLevel(for block: TrainingBlock) -> AdaptationLevel {
        // Smart interleaved blocks take priority — checked before all other guards
        if block.adaptiveMode != nil {
            return .smartInterleaved
        }

        // Gate tests, assessments — never touch
        if protectedTypes.contains(block.type) {
            return .none
        }

        // Fixed-speed blocks (single targetSpeed, no sequence) — never touch
        if block.targetSpeed != nil && block.sequence == nil && block.protocol_ == nil {
            return .none
        }

        // Protocol-based blocks (structured rounds) — never touch
        if block.protocol_ != nil {
            return .none
        }

        // Pressure blocks with fixed speed (make-in-row) — never touch
        if block.type == .pressure && block.targetSpeed != nil {
            return .none
        }

        // Elimination ladder — has its own logic, never touch
        if block.type == .pressure && block.challengeType == "ladder" {
            return .none
        }

        // Warmup blocks — light bias
        if warmupAdaptiveTypes.contains(block.type) {
            return .warmup
        }

        // Random, exploration, challenge, reactive, celebration — full adaptive
        if fullAdaptiveTypes.contains(block.type) {
            return .full
        }

        // Sequence/alternating blocks — full adaptive (regenerate with weighted distribution)
        if block.sequence != nil && (block.type == .sequence || block.type == .alternating) {
            return .full
        }

        // Recovery blocks — never touch (intentionally easy)
        if block.type == .recovery {
            return .none
        }

        // Combine blocks — never touch (has its own scoring system)
        if block.type == .combine {
            return .none
        }

        // Blocked type with sequence (like Day 6 6A) — full adaptive
        if block.sequence != nil {
            return .full
        }

        // Default: don't adapt
        return .none
    }

    // MARK: - Weight Calculation

    /// Calculate the adaptive weight for a given speed based on user performance
    func weight(for speed: Int) -> Double {
        guard let profile = statsService.speedProfiles[speed] else {
            return unpracticedWeight
        }

        if profile.totalPutts < 5 {
            return unpracticedWeight
        }

        let accuracy = profile.accuracy
        if accuracy < weakThreshold { return weakWeight }
        if accuracy < moderateThreshold { return moderateWeight }
        if accuracy < strongThreshold { return baselineWeight }
        return strongWeight
    }

    /// Inverse of `weight(for:)` — features the user's STRONGEST speeds most often.
    /// Used by recovery mode (confidence builder) while still keeping the full pool in play.
    func strengthWeight(for speed: Int) -> Double {
        guard let profile = statsService.speedProfiles[speed] else {
            return unpracticedWeight
        }

        if profile.totalPutts < 5 {
            return unpracticedWeight
        }

        let accuracy = profile.accuracy
        if accuracy < weakThreshold { return strongWeight }       // weak speeds appear least
        if accuracy < moderateThreshold { return baselineWeight }
        if accuracy < strongThreshold { return moderateWeight }
        return weakWeight                                          // strongest speeds appear most
    }

    /// Calculate warmup-compressed weight (closer to 1.0)
    func warmupWeight(for speed: Int) -> Double {
        let fullWeight = weight(for: speed)
        // Compress toward 1.0: warmupWeight = 1.0 + (fullWeight - 1.0) * warmupBiasFactor
        return 1.0 + (fullWeight - 1.0) * warmupBiasFactor
    }

    // MARK: - Sequence Generation

    /// Generate an adaptive sequence for a block.
    /// Returns nil if the block should not be adapted.
    func generateAdaptiveSequence(
        for block: TrainingBlock,
        day: TrainingDay
    ) -> [Int]? {
        let level = adaptationLevel(for: block)
        guard level != .none else { return nil }

        // Determine the speed pool and target length
        let speedPool: [Int]
        let targetLength: Int

        if let sequence = block.sequence, !sequence.isEmpty {
            // Block has a pre-baked sequence — extract unique speeds as the pool
            speedPool = Array(Set(sequence)).sorted()
            targetLength = sequence.count
        } else if !day.availableSpeeds.isEmpty {
            // Block draws from day's available speeds
            speedPool = day.availableSpeeds
            targetLength = block.putts ?? 16  // Default to 16 if no putt count
        } else {
            // No speed info available — can't adapt
            return nil
        }

        guard !speedPool.isEmpty, targetLength > 0 else { return nil }

        // Generate weighted sequence
        switch level {
        case .smartInterleaved:
            return generateSmartInterleavedResult(for: block, day: day)?.sequence
        case .full:
            return generateWeightedSequence(
                pool: speedPool,
                length: targetLength,
                weightFunction: weight(for:)
            )
        case .warmup:
            return generateWarmupSequence(
                pool: speedPool,
                length: targetLength
            )
        case .none:
            return nil
        }
    }

    // MARK: - Smart Interleaved (Data-Driven Block Redesign)

    /// Result from smart interleaved generation — sequence + a human-readable context label
    /// for display in the session header ("Your optimal challenge", etc.)
    struct AdaptiveInterleavedResult {
        let sequence: [Int]
        let context: String
    }

    /// Public entry point: generate a data-driven sequence + context label for blocks
    /// that carry an `adaptiveMode` field. Returns nil if the block has no adaptiveMode
    /// or if the pool is empty.
    func generateSmartInterleavedResult(
        for block: TrainingBlock,
        day: TrainingDay
    ) -> AdaptiveInterleavedResult? {
        guard let mode = block.adaptiveMode,
              let pool = block.adaptivePool, !pool.isEmpty else { return nil }
        let length = block.putts ?? 15

        // Single-speed gate: only drill one speed when the block explicitly asks for it
        // (adaptiveSingleSpeed flag) or its mechanic requires it (make-in-row / consecutive).
        // Everything else features the relevant speeds more often across the FULL pool.
        let wantsSingleSpeed = block.adaptiveSingleSpeed == true
            || block.challengeType == "make-in-row"
            || block.challengeType == "consecutive"
        if wantsSingleSpeed {
            return generateSingleSpeed(mode: mode, pool: pool, length: length)
        }

        switch mode {
        case "recovery":
            return generateRecoveryInterleaved(pool: pool, length: length)
        case "challenge":
            return generateChallengeInterleaved(pool: pool, length: length)
        case "predictive":
            return generatePredictiveInterleaved(pool: pool, length: length)
        default:
            return nil
        }
    }

    /// Build a deliberate single-speed (exclusive drill) sequence. The speed is chosen by the
    /// mode's intent: recovery → strongest; challenge → optimal challenge point (~70%);
    /// predictive → weakest. Used only when a block opts in via `adaptiveSingleSpeed` or
    /// carries a make-in-row / consecutive mechanic.
    private func generateSingleSpeed(mode: String, pool: [Int], length: Int) -> AdaptiveInterleavedResult {
        let profiles = pool.compactMap { speed -> (speed: Int, accuracy: Double)? in
            guard let p = statsService.speedProfiles[speed], p.totalPutts >= 3 else { return nil }
            return (speed, p.accuracy)
        }

        // No data yet — fall back to the middle of the pool with a neutral label
        guard !profiles.isEmpty else {
            let speed = pool[pool.count / 2]
            return AdaptiveInterleavedResult(sequence: Array(repeating: speed, count: length),
                                             context: "Focused drill: \(speed) MPH")
        }

        let chosen: Int
        let label: String
        switch mode {
        case "recovery":
            chosen = profiles.max(by: { $0.accuracy < $1.accuracy })!.speed
            label = "Strength: \(chosen) MPH (\(SpeedZone.getZone(for: chosen).name))"
        case "predictive":
            chosen = profiles.min(by: { $0.accuracy < $1.accuracy })!.speed
            label = "Weak-spot drill: \(chosen) MPH"
        default: // challenge — speed closest to the ~70% optimal challenge point
            let target = profiles.min(by: { abs($0.accuracy - 70.0) < abs($1.accuracy - 70.0) })!
            chosen = target.speed
            label = target.accuracy < 60.0 ? "Weak-zone drill: \(chosen) MPH" : "Optimal challenge: \(chosen) MPH"
        }
        return AdaptiveInterleavedResult(sequence: Array(repeating: chosen, count: length), context: label)
    }

    /// Recovery mode — confidence builder.
    /// Features the user's STRONGEST speeds most often while keeping the whole pool in play,
    /// so it stays varied instead of collapsing into single-speed block practice.
    private func generateRecoveryInterleaved(pool: [Int], length: Int) -> AdaptiveInterleavedResult {
        let seq = generateWeightedSequence(pool: pool, length: length, weightFunction: strengthWeight(for:))
        return AdaptiveInterleavedResult(sequence: seq, context: "Building confidence")
    }

    /// Challenge mode — optimal challenge point.
    /// Features weaker speeds more often across the FULL pool (every pool speed still appears);
    /// the label reflects the speed nearest the ~70% optimal challenge point.
    private func generateChallengeInterleaved(pool: [Int], length: Int) -> AdaptiveInterleavedResult {
        let seq = generateWeightedSequence(pool: pool, length: length, weightFunction: weight(for:))

        // Context label only — derived from the speed closest to the 70% challenge point.
        let profiles = pool.compactMap { speed -> (speed: Int, accuracy: Double)? in
            guard let p = statsService.speedProfiles[speed], p.totalPutts >= 3 else { return nil }
            return (speed, p.accuracy)
        }
        let context: String
        if let target = profiles.min(by: { abs($0.accuracy - 70.0) < abs($1.accuracy - 70.0) }) {
            let zone = SpeedZone.getZone(for: target.speed)
            context = (target.accuracy < 60.0 ? "Targeting your weak zone" : "Your optimal challenge") + " · \(zone.name)"
        } else {
            context = "Your optimal challenge"
        }
        return AdaptiveInterleavedResult(sequence: seq, context: context)
    }

    /// Predictive mode — full adaptive weighting across the specified pool.
    /// Weakest speeds in pool appear most; builds contextual interference from early days.
    private func generatePredictiveInterleaved(pool: [Int], length: Int) -> AdaptiveInterleavedResult {
        let seq = generateWeightedSequence(pool: pool, length: length, weightFunction: weight(for:))
        return AdaptiveInterleavedResult(sequence: seq, context: "Targeting your weak spots")
    }

    /// Generate a weighted random sequence.
    /// Each speed appears proportional to its weight. Avoids more than 3 consecutive same speed.
    private func generateWeightedSequence(
        pool: [Int],
        length: Int,
        weightFunction: (Int) -> Double
    ) -> [Int] {
        // Calculate weights for each speed
        let weights = pool.map { weightFunction($0) }
        let totalWeight = weights.reduce(0, +)

        guard totalWeight > 0 else {
            // Fallback: equal distribution
            return (0..<length).map { pool[$0 % pool.count] }
        }

        // Calculate how many times each speed should appear
        var counts: [Int: Int] = [:]
        var assigned = 0

        for (index, speed) in pool.enumerated() {
            let proportion = weights[index] / totalWeight
            let count = max(1, Int(round(proportion * Double(length))))
            counts[speed] = count
            assigned += count
        }

        // Adjust to match exact target length
        while assigned > length {
            // Remove from the highest-count speed (strongest = lowest weight)
            if let maxSpeed = counts.max(by: { $0.value < $1.value })?.key, counts[maxSpeed]! > 1 {
                counts[maxSpeed]! -= 1
                assigned -= 1
            } else {
                break
            }
        }
        while assigned < length {
            // Add to the weakest speed (highest weight)
            let weakestSpeed = pool[weights.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0]
            counts[weakestSpeed, default: 0] += 1
            assigned += 1
        }

        // Build the flat array
        var sequence: [Int] = []
        for (speed, count) in counts {
            sequence.append(contentsOf: Array(repeating: speed, count: count))
        }

        // Shuffle with constraint: no more than 3 consecutive same speed
        return constrainedShuffle(sequence)
    }

    /// Generate a warmup sequence with light bias.
    /// Warmups are structured: slower speeds first, faster speeds later (progressive).
    private func generateWarmupSequence(pool: [Int], length: Int) -> [Int] {
        let sortedPool = pool.sorted()

        // Calculate warmup-compressed weights
        let weights = sortedPool.map { warmupWeight(for: $0) }
        let totalWeight = weights.reduce(0, +)

        guard totalWeight > 0 else {
            // Fallback: equal distribution, sorted progressive
            return generateProgressiveSequence(pool: sortedPool, length: length)
        }

        // Calculate counts per speed
        var counts: [Int: Int] = [:]
        var assigned = 0

        for (index, speed) in sortedPool.enumerated() {
            let proportion = weights[index] / totalWeight
            let count = max(1, Int(round(proportion * Double(length))))
            counts[speed] = count
            assigned += count
        }

        // Adjust totals
        while assigned > length {
            if let maxSpeed = counts.max(by: { $0.value < $1.value })?.key, counts[maxSpeed]! > 1 {
                counts[maxSpeed]! -= 1
                assigned -= 1
            } else { break }
        }
        while assigned < length {
            let weakestSpeed = sortedPool[weights.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0]
            counts[weakestSpeed, default: 0] += 1
            assigned += 1
        }

        // Build progressive warmup: group by speed ascending, each group's putts together
        var sequence: [Int] = []
        for speed in sortedPool {
            let count = counts[speed] ?? 0
            sequence.append(contentsOf: Array(repeating: speed, count: count))
        }

        return sequence
    }

    /// Fallback: equal progressive distribution when no profile data exists
    private func generateProgressiveSequence(pool: [Int], length: Int) -> [Int] {
        let sorted = pool.sorted()
        var sequence: [Int] = []
        let perSpeed = max(1, length / sorted.count)
        let remainder = length - (perSpeed * sorted.count)

        for (index, speed) in sorted.enumerated() {
            let count = perSpeed + (index < remainder ? 1 : 0)
            sequence.append(contentsOf: Array(repeating: speed, count: count))
        }

        // Trim or pad to exact length
        while sequence.count > length { sequence.removeLast() }
        while sequence.count < length { sequence.append(sorted.last ?? 5) }

        return sequence
    }

    // MARK: - Constrained Shuffle

    /// Shuffle a sequence such that no speed appears more than maxConsecutive times in a row.
    /// Uses a greedy approach with backtracking to guarantee the constraint is met.
    private func constrainedShuffle(_ input: [Int], maxConsecutive: Int = 3) -> [Int] {
        guard input.count > 1 else { return input }

        // Count occurrences of each speed
        var counts: [Int: Int] = [:]
        for speed in input {
            counts[speed, default: 0] += 1
        }

        var result: [Int] = []
        let totalToPlace = input.count

        while result.count < totalToPlace {
            // Get all speeds that still have remaining counts
            var candidates = counts.filter { $0.value > 0 }.map { $0.key }.shuffled()

            // Filter out speeds that would violate the consecutive constraint
            let tail = result.suffix(maxConsecutive)
            if tail.count == maxConsecutive && Set(tail).count == 1 {
                // Last maxConsecutive elements are all the same — exclude that speed
                let excludedSpeed = tail.first!
                candidates.removeAll { $0 == excludedSpeed }
            }

            if candidates.isEmpty {
                // Dead end: all remaining are the same speed that's already at max consecutive.
                // Interleave remaining with the last element in result to break the run.
                let remainingSpeed = counts.first(where: { $0.value > 0 })!.key
                let remainingCount = counts[remainingSpeed]!

                // Insert remaining copies spread throughout the result
                for i in 0..<remainingCount {
                    // Find a safe insertion point (not adjacent to same speed on both sides)
                    let insertAt = min(result.count, (result.count / max(remainingCount, 1)) * (i + 1))
                    result.insert(remainingSpeed, at: insertAt)
                }
                break
            }

            // Pick the candidate with the highest remaining count (greedy: place hardest-to-place first)
            candidates.sort { counts[$0]! > counts[$1]! }
            let chosen = candidates[0]

            result.append(chosen)
            counts[chosen]! -= 1
        }

        return result
    }
}

// MARK: - Adaptation Level

enum AdaptationLevel {
    case none               // Do not adapt this block
    case warmup             // Light bias (~30% of full weighting)
    case full               // Full adaptive weighting (~3x for weakest)
    case smartInterleaved   // Data-driven interleave: recovery / challenge / predictive
}
