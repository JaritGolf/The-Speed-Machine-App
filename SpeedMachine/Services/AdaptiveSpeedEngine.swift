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
        for block: TrainingBlock, track: TrainingTrack
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
        } else if !track.availableSpeeds.isEmpty {
            // Block draws from day's available speeds
            speedPool = track.availableSpeeds
            targetLength = block.putts ?? 16  // Default to 16 if no putt count
        } else {
            // No speed info available — can't adapt
            return nil
        }

        guard !speedPool.isEmpty, targetLength > 0 else { return nil }

        // Generate weighted sequence
        switch level {
        case .smartInterleaved:
            return generateSmartInterleavedResult(for: block, track: track)?.sequence
        case .full:
            return generateWeightedSequence(
                pool: masteryFilteredPool(speedPool),
                length: targetLength,
                weightFunction: weight(for:)
            )
        case .warmup:
            return generateWarmupSequence(
                pool: masteryFilteredPool(speedPool),
                length: targetLength
            )
        case .none:
            return nil
        }
    }

    private func masteryFilteredPool(_ pool: [Int]) -> [Int] {
        let mastery = MasteryService.shared
        let unlocked = pool.filter { mastery.isSpeedUnlockedForAdaptive($0, in: pool) }
        return unlocked.isEmpty ? pool : unlocked
    }

    // MARK: - Smart Interleaved (Data-Driven Block Redesign)

    struct AdaptiveInterleavedResult {
        let sequence: [Int]
        let context: String
    }

    func generateSmartInterleavedResult(
        for block: TrainingBlock, track: TrainingTrack
    ) -> AdaptiveInterleavedResult? {
        guard let mode = block.adaptiveMode,
              let rawPool = block.adaptivePool, !rawPool.isEmpty else { return nil }
        let pool = masteryFilteredPool(rawPool)
        let length = block.putts ?? 15

        switch mode {
        case "recovery":
            return generateRecoveryInterleaved(pool: pool, length: length)
        case "challenge":
            return generateChallengeInterleaved(block: block, pool: pool, length: length)
        case "predictive":
            return generatePredictiveInterleaved(pool: pool, length: length)
        default:
            return nil
        }
    }

    private func generateRecoveryInterleaved(pool: [Int], length: Int) -> AdaptiveInterleavedResult {
        let profiles = pool.compactMap { speed -> (speed: Int, accuracy: Double)? in
            guard let p = statsService.speedProfiles[speed], p.totalPutts >= 3 else { return nil }
            return (speed, p.accuracy)
        }.sorted { $0.accuracy > $1.accuracy }

        guard !profiles.isEmpty else {
            let seq = generateEqualDistribution(pool: pool, length: length)
            return AdaptiveInterleavedResult(sequence: seq, context: "Building confidence")
        }

        let primary = profiles[0].speed
        let primaryZone = SpeedZone.getZone(for: primary)

        guard profiles.count > 1 else {
            let seq = Array(repeating: primary, count: length)
            return AdaptiveInterleavedResult(
                sequence: seq,
                context: "Strength: \(primary) MPH (\(primaryZone.name))"
            )
        }

        let secondary = profiles[1].speed
        let primaryCount = Int(round(Double(length) * 0.65))
        let secondaryCount = length - primaryCount
        let flat = Array(repeating: primary, count: primaryCount)
                 + Array(repeating: secondary, count: secondaryCount)
        return AdaptiveInterleavedResult(
            sequence: constrainedShuffle(flat),
            context: "Strength focus: \(primaryZone.name)"
        )
    }

    private func generateChallengeInterleaved(
        block: TrainingBlock,
        pool: [Int],
        length: Int
    ) -> AdaptiveInterleavedResult {
        let profiles = pool.compactMap { speed -> (speed: Int, accuracy: Double)? in
            guard let p = statsService.speedProfiles[speed], p.totalPutts >= 3 else { return nil }
            return (speed, p.accuracy)
        }

        guard !profiles.isEmpty else {
            let seq = generateEqualDistribution(pool: pool, length: length)
            return AdaptiveInterleavedResult(sequence: seq, context: "Your optimal challenge")
        }

        let target = profiles.min(by: {
            abs($0.accuracy - 70.0) < abs($1.accuracy - 70.0)
        })!
        let targetZone = SpeedZone.getZone(for: target.speed)
        let context = target.accuracy < 60.0 ? "Targeting your weak zone" : "Your optimal challenge"

        let isConsecutive = block.challengeType == "consecutive"
        if isConsecutive {
            let seq = Array(repeating: target.speed, count: length)
            return AdaptiveInterleavedResult(sequence: seq, context: context)
        }

        let anchor = profiles
            .filter { $0.accuracy > 80.0 && $0.speed != target.speed }
            .max(by: { $0.accuracy < $1.accuracy })

        if let anchor = anchor {
            let targetCount = Int(round(Double(length) * 0.60))
            let anchorCount = length - targetCount
            let flat = Array(repeating: target.speed, count: targetCount)
                     + Array(repeating: anchor.speed, count: anchorCount)
            return AdaptiveInterleavedResult(
                sequence: constrainedShuffle(flat),
                context: "\(context) · \(targetZone.name)"
            )
        } else {
            let seq = Array(repeating: target.speed, count: length)
            return AdaptiveInterleavedResult(
                sequence: seq,
                context: "\(context) · \(targetZone.name)"
            )
        }
    }

    private func generatePredictiveInterleaved(pool: [Int], length: Int) -> AdaptiveInterleavedResult {
        let seq = generateWeightedSequence(pool: pool, length: length, weightFunction: weight(for:))
        return AdaptiveInterleavedResult(sequence: seq, context: "Targeting your weak spots")
    }

    private func generateEqualDistribution(pool: [Int], length: Int) -> [Int] {
        let seq = (0..<length).map { pool[$0 % pool.count] }
        return constrainedShuffle(seq)
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

    /// Generate a warmup sequence with full adaptive bias toward weak speeds.
    /// Speed *selection* is weighted (weaker speeds appear more often), then the
    /// resulting putts are presented in ascending order so the user always warms up
    /// slow → fast even when the pool is adaptive.
    private func generateWarmupSequence(pool: [Int], length: Int) -> [Int] {
        let sortedPool = pool.sorted()

        // Full adaptive weighting — warmup blocks now apply the same weak-speed
        // emphasis as random/exploration blocks (previously compressed by warmupBiasFactor).
        let weights = sortedPool.map { weight(for: $0) }
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
