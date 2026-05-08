//
//  TrainingViewModel.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import Combine
import UIKit

class TrainingViewModel: ObservableObject {
    @Published var selectedTrack: TrainingTrack?
    @Published var selectedBlock: TrainingBlock?
    @Published var currentSession: SessionProgress?
    @Published var isSessionActive = false
    @Published var blockCompletionPending = false
    @Published var blockJustCompleted = false
    @Published var nextBlockForTransition: TrainingBlock? = nil
    @Published var shouldNavigateHome = false
    @Published var gateTestResult: GateTestResult?
    @Published var showGateTestFailedAlert = false
    @Published var trackCompleteStats: TrackCompleteStats? = nil
    /// Context label shown in the session header when a block uses adaptive interleaved selection.
    /// e.g. "Your optimal challenge · Zone 2" — nil for non-adaptive blocks.
    @Published var adaptiveBlockContext: String? = nil
    /// Phase 3: Non-nil when the completed block failed its pass threshold.
    /// Routes TrainingSessionView to SkillCheckResultView until the user chooses
    /// Repeat or Continue anyway (override).
    @Published var pendingSkillCheck: BlockEvaluation? = nil

    private let dataService = DataService.shared
    private let statsService = StatsService.shared
    private let adaptiveEngine = AdaptiveSpeedEngine.shared
    private let programLoader = TrainingProgramLoader.shared
    private let masteryService = MasteryService.shared
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    /// Tracks when the first block of a day session began — not reset between blocks.
    private var daySessionStartTime: Date?

    init() {
        // When the remote program loads after launch, refresh any in-flight block/track
        // so live session displays (pass threshold, etc.) reflect the new values.
        programLoader.$program
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProgram in
                guard let self, let newProgram else { return }
                if let currentTrack = self.selectedTrack,
                   let newTrack = newProgram.tracks.first(where: { $0.number == currentTrack.number }) {
                    self.selectedTrack = newTrack
                    if let currentBlock = self.selectedBlock,
                       let newBlock = newTrack.blocks.first(where: { $0.id == currentBlock.id }) {
                        self.selectedBlock = newBlock
                    }
                }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var currentTrack: Int {
        return Int(dataService.userProgress.currentDay)
    }

    var currentPhase: Int {
        return Int(dataService.userProgress.currentPhase)
    }

    var unlockedZones: [Int] {
        return (dataService.userProgress.unlockedZones ?? []).map { Int($0) }
    }

    var passedGateTests: Set<String> {
        return dataService.getPassedGateTests()
    }

    func isTrackUnlocked(_ trackNumber: Int) -> Bool {
        // Day 1 is always unlocked
        if trackNumber == 1 { return true }

        // Current day is unlocked
        if trackNumber == currentTrack { return true }

        // Any completed day is unlocked
        if dataService.isTrackCompleted(trackNumber) { return true }

        // Check if previous day is completed
        let previousTrackCompleted = dataService.isTrackCompleted(trackNumber - 1)

        // Also check if there's a gate test required before this day
        // Gate test tracks: 5, 9, 12, 19, 25, 30
        // Gate test on day X must be passed to proceed past that day
        if let gateTest = programLoader.getGateTest(forTrack: trackNumber - 1) {
            // Previous day was a gate test - must have passed it
            if !passedGateTests.contains(gateTest.gateId) {
                return false
            }
        }

        return previousTrackCompleted
    }

    func isTrackCompleted(_ trackNumber: Int) -> Bool {
        return dataService.isTrackCompleted(trackNumber)
    }

    func isGateTestTrack(_ trackNumber: Int) -> Bool {
        return programLoader.isGateTestTrack(trackNumber)
    }

    func getGateTestForTrack(_ trackNumber: Int) -> GateTest? {
        return programLoader.getGateTest(forTrack: trackNumber)
    }

    func getTrackStatus(_ trackNumber: Int) -> TrackStatus {
        if isTrackCompleted(trackNumber) {
            return .completed
        } else if trackNumber == currentTrack {
            return .current
        } else if isTrackUnlocked(trackNumber) {
            return .available
        } else {
            return .locked
        }
    }

    func startBlock(_ block: TrainingBlock, for track: TrainingTrack, puttsOverride: Int? = nil) {
        selectedTrack = track
        selectedBlock = block

        let session = SessionProgress(block: block, trackNumber: track.number, puttsOverride: puttsOverride)

        // Smart interleaved blocks: data-driven speed selection + context label for header
        if block.adaptiveMode != nil,
           let result = adaptiveEngine.generateSmartInterleavedResult(for: block, track: track) {
            session.adaptiveSequence = result.sequence
            adaptiveBlockContext = result.context
        } else {
            // Standard adaptive weighting for random/exploration/warmup/etc. blocks
            adaptiveBlockContext = nil
            if let adaptiveSeq = adaptiveEngine.generateAdaptiveSequence(for: block, track: track) {
                session.adaptiveSequence = adaptiveSeq
            }
        }

        currentSession = session
        isSessionActive = true
        gateTestResult = nil
        sessionStartTime = Date()
        // Only record the day-level start time on the first block — preserve it through auto-advances.
        if daySessionStartTime == nil {
            daySessionStartTime = Date()
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func recordPutt(_ speed: Float) {
        guard let session = currentSession, let block = selectedBlock, let track = selectedTrack else { return }

        // Get the target speed (may differ based on block type)
        let targetSpeed: Int
        if session.blockSessionType == .eliminationLadder {
            targetSpeed = session.getCurrentLadderSpeed()
        } else if session.blockSessionType == .warmup {
            targetSpeed = session.currentTargetSpeed  // Will be random
        } else {
            targetSpeed = session.currentTargetSpeed
        }

        // Calculate tolerance and check if in zone.
        // Round to 1 decimal place before comparing so the zone check matches
        // what is displayed on screen (%.1f), preventing floating-point edge
        // cases where the display shows e.g. "6.5" but the raw BLE float is
        // 6.5000001 and would otherwise narrowly fail the boundary check.
        let roundedSpeed = (speed * 10).rounded() / 10
        let tolerance: Float
        let isInZone: Bool
        if let acceptRange = block.acceptRange {
            tolerance = (acceptRange.max - acceptRange.min) / 2
            isInZone = roundedSpeed >= acceptRange.min && roundedSpeed <= acceptRange.max
        } else {
            let t = programLoader.getToleranceForSpeed(targetSpeed)
            tolerance = t
            isInZone = abs(roundedSpeed - Float(targetSpeed)) <= t
        }

        // Standard putt recording FIRST
        session.recordPutt(actualSpeed: speed)

        // Apply block-specific logic AFTER putt is recorded
        switch session.blockSessionType {
        case .eliminationLadder:
            handleLadderPutt(session: session, isInZone: isInZone)
        case .makeInRow:
            handleMakeInRowPutt(session: session, isInZone: isInZone)
        case .warmup, .standard, .recovery:
            // No special handling needed
            break
        }

        // Save to Core Data
        if let sessionData = getOrCreateSessionData(for: block, track: track.number) {
            dataService.recordPutt(
                session: sessionData,
                targetSpeed: Float(targetSpeed),
                actualSpeed: speed,
                tolerance: tolerance,
                isOnTarget: isInZone
            )

            dataService.updateSession(
                sessionData,
                completedPutts: session.currentPutt,
                onTargetPutts: session.inZonePutts,
                isComplete: session.isComplete || session.isLadderComplete
            )
        }

        // Update lifetime stats (independent of training program)
        statsService.recordPutt(
            targetSpeed: targetSpeed,
            actualSpeed: speed,
            tolerance: tolerance
        )

        // Check if block is complete — 2-second delay so the final putt result
        // is visible on screen before the block advances or transitions.
        // blockJustCompleted drives the "✓ BLOCK COMPLETE" banner overlay.
        if session.isComplete || session.isLadderComplete {
            blockJustCompleted = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { completeBlock() }
            }
        }
    }

    // MARK: - Block-Specific Putt Handlers

    private func handleLadderPutt(session: SessionProgress, isInZone: Bool) {
        if isInZone {
            let topRungIndex = session.ladderSpeeds.count - 1  // index 4 = speed 7

            if session.currentRung >= topRungIndex {
                // ✅ Top rung hit in zone — ladder is now truly complete.
                // BUG FIX: previously advanceRung() silently returned false here,
                // but isLadderComplete was already true (set when currentRung reached 4
                // after the *previous* rung), so the top rung was never actually required.
                session.markLadderComplete()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                // Advance to the next rung
                let advanced = session.advanceRung()
                if advanced {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        } else {
            // Miss logic: lower 60% of rungs reset to start, upper 40% drop one.
            let resetThreshold = session.ladderSpeeds.count * 3 / 5 - 1
            if session.currentRung <= resetThreshold {
                session.resetRung()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } else {
                let dropped = session.dropRung()
                if dropped {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    private func handleMakeInRowPutt(session: SessionProgress, isInZone: Bool) {
        if isInZone {
            session.recordConsecutiveSuccess()
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        } else {
            session.resetConsecutiveCount()
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }

    private var activeSessionData: SessionData?

    private func getOrCreateSessionData(for block: TrainingBlock, track: Int) -> SessionData? {
        if let existing = activeSessionData {
            return existing
        }

        let targetPutts = currentSession?.totalPutts ?? block.putts ?? 0
        let sessionData = dataService.createSession(
            trackNumber: track,
            blockId: block.blockId,
            targetPutts: targetPutts
        )
        activeSessionData = sessionData
        return sessionData
    }

    func completeBlock() {
        guard let track = selectedTrack, let block = selectedBlock, let session = currentSession else { return }

        // Banner has served its purpose — hide it now.
        blockJustCompleted = false

        // Telemetry + Phase 3 soft-gate evaluation for every non-gate-test block.
        if block.type != .gateTest {
            let evaluation = MasteryService.shared.evaluateBlock(session, block: block, track: track.number)
            dataService.createBlockAttempt(
                trackNumber: track.number,
                blockId: block.blockId,
                zoneAccuracy: session.zoneAccuracy,
                passedThreshold: evaluation.passed,
                passedWithOverride: false
            )
            print("📊 BlockAttempt: Day \(track.number) \(block.blockId) | acc=\(Int(session.zoneAccuracy * 100))% | threshold=\(Int(evaluation.threshold * 100))% | passed=\(evaluation.passed) | force=\(evaluation.gateForce) | src=\(evaluation.thresholdSource)")

            // Phase 3+4: enforce gates — route to SkillCheckResultView on fail.
            // Soft gates: "Continue anyway" always enabled.
            // Hard gates: "Continue anyway" only enabled after 3 failed attempts.
            if !evaluation.passed && evaluation.gateForce != .none {
                pendingSkillCheck = evaluation
                return  // do NOT advance; wait for user action in SkillCheckResultView
            }
        }

        // Check if this is a gate test block with pass criteria
        if block.type == .gateTest && block.passRequirements != nil {
            evaluateGateTest()
            return
        }

        // Block passed (or no gate applies) — advance normally.
        advanceToNextBlockOrComplete(track: track, block: block, session: session)
    }

    // MARK: - Skill Check Actions (Phase 3)

    /// User chose "Repeat this block" in SkillCheckResultView.
    /// Phase 4: on a hard gate's 3rd+ failed attempt, auto-shortens to half the rep count.
    func repeatBlock() {
        guard let track = selectedTrack, let block = selectedBlock else { return }
        // Hard-gate third-retry shortening: if this is the 3rd failed attempt for a hard gate,
        // the repeated block gets half the normal putts to keep the practice manageable.
        let check = pendingSkillCheck
        let halvePutts = check?.gateForce == .hard && (check?.failedAttemptCount ?? 0) >= 2
        pendingSkillCheck = nil
        currentSession = nil
        activeSessionData = nil
        blockJustCompleted = false
        if halvePutts, let originalPutts = block.putts {
            startBlock(block, for: track, puttsOverride: max(4, originalPutts / 2))
        } else {
            startBlock(block, for: track)
        }
    }

    /// User chose "Continue anyway" (override) in SkillCheckResultView.
    /// Records the override in telemetry, then advances to the next block / day end.
    func overrideAndContinue() {
        guard let track = selectedTrack, let block = selectedBlock, let session = currentSession else { return }
        // Record the override — passedWithOverride:true signals this in telemetry.
        if let check = pendingSkillCheck {
            dataService.createBlockAttempt(
                trackNumber: track.number,
                blockId: block.blockId,
                zoneAccuracy: session.zoneAccuracy,
                passedThreshold: false,
                passedWithOverride: true
            )
            print("⚠️ SkillCheck override: Day \(track.number) \(block.blockId) | acc=\(Int(check.zoneAccuracy * 100))% | required=\(Int(check.threshold * 100))%")
        }
        pendingSkillCheck = nil
        advanceToNextBlockOrComplete(track: track, block: block, session: session)
    }

    // MARK: - Block Advancement (shared by completeBlock + overrideAndContinue)

    private func advanceToNextBlockOrComplete(track: TrainingTrack, block: TrainingBlock, session: SessionProgress) {
        // Check if all blocks in the day are complete
        let blockIds = track.blocks.map { $0.blockId }
        let completedBlockCount = dataService.getCompletedBlockCount(
            trackNumber: track.number,
            blockIds: blockIds
        )

        blockCompletionPending = true

        // Find the next block in this day
        if let currentBlockIndex = track.blocks.firstIndex(where: { $0.blockId == block.blockId }) {
            if currentBlockIndex < track.blocks.count - 1 {
                // There's a next block in this day, auto-advance to it
                let nextBlock = track.blocks[currentBlockIndex + 1]
                nextBlockForTransition = nextBlock  // drives the transition screen

                // Reset session and start the next block after transition screen
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    await MainActor.run {
                        self.blockCompletionPending = false
                        self.nextBlockForTransition = nil
                        self.currentSession = nil
                        self.selectedBlock = nil
                        self.activeSessionData = nil
                        self.startBlock(nextBlock, for: track)
                    }
                }
                return
            }
        }

        // Last block of the day — save progress then show DayCompleteView
        if completedBlockCount >= track.blocks.count && !dataService.isTrackCompleted(track.number) {
            dataService.markTrackComplete(
                trackNumber: track.number,
                accuracy: session.zoneAccuracy,
                totalPutts: session.currentPutt,
                onTargetPutts: session.inZonePutts
            )

            // Advance to next day
            if track.number < 30 {
                dataService.updateProgress(currentTrack: track.number + 1, phase: track.phase)
            }
        }

        // Compute day stats and hand off to DayCompleteView (user taps Done to go home).
        trackCompleteStats = computeTrackCompleteStats(track: track)
    }

    /// Builds the summary stat block shown on DayCompleteView.
    private func computeTrackCompleteStats(track: TrainingTrack) -> TrackCompleteStats {
        // 1. Fetch all sessions for this day
        let sessions = dataService.getSessionsForTrack(track.number)
        let sessionIds = sessions.compactMap { $0.id }

        // 2. Total putts and zone accuracy from session records
        let totalPutts = sessions.reduce(0) { $0 + Int($1.completedPutts) }
        let totalInZone = sessions.reduce(0) { $0 + Int($1.onTargetPutts) }
        let overallAccuracy: Float = totalPutts > 0 ? Float(totalInZone) / Float(totalPutts) : 0

        // 3. Practice time: prior sessions today (DailySnapshot) + current session elapsed
        let priorSeconds = dataService.getTodayPracticeSeconds()
        let currentElapsed = daySessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let practiceSeconds = priorSeconds + currentElapsed

        // 4. Strongest / weakest individual speed from putt records
        var (strongestZone, weakestZone, strongestAcc, weakestAcc) = computeSpeedStrengths(sessionIds: sessionIds)

        // 5. Best block (highest accuracy among completed blocks with ≥3 putts)
        let bestBlock: String? = {
            guard sessions.count > 1 else { return nil }
            let withPutts = sessions.filter { $0.completedPutts >= 3 }
            guard let best = withPutts.max(by: {
                let accA = $0.completedPutts > 0 ? Float($0.onTargetPutts) / Float($0.completedPutts) : 0
                let accB = $1.completedPutts > 0 ? Float($1.onTargetPutts) / Float($1.completedPutts) : 0
                return accA < accB
            }),
            let blockId = best.blockId,
            let matchedBlock = track.blocks.first(where: { $0.blockId == blockId }),
            let idx = track.blocks.firstIndex(where: { $0.blockId == blockId })
            else { return nil }
            return "Block \(idx + 1): \(matchedBlock.name)"
        }()

        return TrackCompleteStats(
            trackNumber: track.number,
            totalPutts: totalPutts,
            overallAccuracy: overallAccuracy,
            practiceSeconds: practiceSeconds,
            strongestSpeed: strongestZone,
            strongestAccuracy: strongestAcc,
            weakestSpeed: weakestZone,
            weakestAccuracy: weakestAcc,
            bestBlock: bestBlock
        )
    }

    /// Computes per-speed accuracy from putt records for a set of session IDs.
    /// Returns the individual MPH value with the best and worst accuracy today.
    private func computeSpeedStrengths(sessionIds: [UUID]) -> (strongest: Int?, weakest: Int?, strongestAcc: Float, weakestAcc: Float) {
        let putts = dataService.getPuttsForSessionIds(sessionIds)
        guard !putts.isEmpty else { return (nil, nil, 0, 0) }

        // Accumulate (total, inZone) per individual speed (MPH)
        var speedTotals: [Int: Int] = [:]
        var speedInZone: [Int: Int] = [:]

        for putt in putts {
            let speed = Int(putt.targetSpeed.rounded())
            speedTotals[speed, default: 0] += 1
            if putt.isOnTarget { speedInZone[speed, default: 0] += 1 }
        }

        // Build accuracy map for speeds with at least 3 putts
        var speedAccuracy: [Int: Float] = [:]
        for (speed, total) in speedTotals where total >= 3 {
            let inZone = speedInZone[speed, default: 0]
            speedAccuracy[speed] = Float(inZone) / Float(total)
        }

        guard !speedAccuracy.isEmpty else { return (nil, nil, 0, 0) }

        let bestEntry  = speedAccuracy.max(by: { $0.value < $1.value })!
        let worstEntry = speedAccuracy.min(by: { $0.value < $1.value })!

        // Only show weakest if it's a different speed from strongest
        let weakestSpeed = (worstEntry.key != bestEntry.key) ? worstEntry.key : nil
        let weakestAcc   = (worstEntry.key != bestEntry.key) ? worstEntry.value : 0

        return (bestEntry.key, weakestSpeed, bestEntry.value, weakestAcc)
    }

    func evaluateGateTest() {
        guard let block = selectedBlock,
              let session = currentSession,
              let gateId = block.gateId,
              let requirements = block.passRequirements else { return }

        // Phase 4: four-criterion evaluation via MasteryService
        let result = masteryService.evaluateGateTest(
            session: session,
            block: block,
            gateId: gateId,
            requirements: requirements
        )

        gateTestResult = result

        if result.passed {
            dataService.recordGateTestPassed(gateId: gateId)

            // Complete the block and potentially the day
            if let track = selectedTrack {
                let blockIds = track.blocks.map { $0.blockId }
                let completedBlockCount = dataService.getCompletedBlockCount(
                    trackNumber: track.number,
                    blockIds: blockIds
                )

                if completedBlockCount >= track.blocks.count - 1 {
                    dataService.markTrackComplete(
                        trackNumber: track.number,
                        accuracy: session.zoneAccuracy,
                        totalPutts: session.currentPutt,
                        onTargetPutts: session.inZonePutts
                    )

                    if track.number < 30 {
                        dataService.updateProgress(currentTrack: track.number + 1, phase: track.phase)
                    }
                }
            }
        } else {
            // Reset the session's isComplete flag so the gate test block does NOT
            // appear as completed in BlockSelectionView (forces the user to retry).
            if let sessionData = activeSessionData {
                dataService.updateSession(
                    sessionData,
                    completedPutts: session.currentPutt,
                    onTargetPutts: session.inZonePutts,
                    isComplete: false
                )
            }
            showGateTestFailedAlert = true
        }
    }

    func endSession() {
        // Track practice time using day-level start so the full multi-block
        // session duration is recorded, not just the last block.
        if let startTime = daySessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            statsService.addPracticeTime(seconds: elapsed)
        } else if let startTime = sessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            statsService.addPracticeTime(seconds: elapsed)
        }

        isSessionActive = false
        blockCompletionPending = false
        blockJustCompleted = false
        trackCompleteStats = nil
        adaptiveBlockContext = nil
        pendingSkillCheck = nil
        nextBlockForTransition = nil
        activeSessionData = nil
        currentSession = nil
        selectedBlock = nil
        selectedTrack = nil
        gateTestResult = nil
        sessionStartTime = nil
        daySessionStartTime = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func getAllTracks() -> [TrainingTrack] {
        return programLoader.program?.tracks ?? []
    }

    func getTrack(_ number: Int) -> TrainingTrack? {
        return programLoader.getTrack(number)
    }

    func getPhase(_ number: Int) -> Phase? {
        return programLoader.getPhase(number)
    }

    func getSpeedZone(_ number: Int) -> SpeedZoneInfo? {
        return programLoader.getSpeedZone(number)
    }
}

enum TrackStatus {
    case locked
    case available
    case current
    case completed
}

/// Reasons a gate test can fail — one or more may apply simultaneously.
enum GateFailureReason: String, CaseIterable {
    case zoneAccuracy     // Didn't hit the minimum overall in-zone count
    case perSpeedFloor    // One or more speeds fell below the per-speed minimum
    case deviationCap     // Average absolute deviation exceeded the cap
    case catastrophicMiss // A single putt missed by more than the max-miss cap

    var displayName: String {
        switch self {
        case .zoneAccuracy:     return "Not enough putts in zone"
        case .perSpeedFloor:    return "Inconsistent at a specific speed"
        case .deviationCap:     return "Average deviation too high"
        case .catastrophicMiss: return "Single putt way off target"
        }
    }

    var remediationMessage: String {
        switch self {
        case .zoneAccuracy:
            return "Focus on zone accuracy — aim to keep every putt within ±0.5 MPH of target."
        case .perSpeedFloor:
            return "One speed in this gate needs more practice. Use blocked practice to isolate it."
        case .deviationCap:
            return "Work on consistency — a steady stroke produces tighter deviations."
        case .catastrophicMiss:
            return "Avoid the big misses — a slow, deliberate setup helps eliminate outliers."
        }
    }
}

struct GateTestResult {
    let gateId: String
    let passed: Bool
    let zoneAccuracyRequired: Int
    let zoneAccuracyAchieved: Int
    let totalPutts: Int
    // Phase 4 extended data
    let perSpeedAccuracy: [Int: Float]?      // speed → fraction in zone (0.0–1.0)
    let avgAbsDeviation: Float?              // average |actual − target| across all putts
    let maxDeviation: Float?                 // worst single |actual − target|
    let failureReasons: [GateFailureReason]  // which of the four criteria failed

    init(gateId: String, passed: Bool,
         zoneAccuracyRequired: Int, zoneAccuracyAchieved: Int, totalPutts: Int,
         perSpeedAccuracy: [Int: Float]? = nil,
         avgAbsDeviation: Float? = nil,
         maxDeviation: Float? = nil,
         failureReasons: [GateFailureReason] = []) {
        self.gateId = gateId
        self.passed = passed
        self.zoneAccuracyRequired = zoneAccuracyRequired
        self.zoneAccuracyAchieved = zoneAccuracyAchieved
        self.totalPutts = totalPutts
        self.perSpeedAccuracy = perSpeedAccuracy
        self.avgAbsDeviation = avgAbsDeviation
        self.maxDeviation = maxDeviation
        self.failureReasons = failureReasons
    }

    var zoneAccuracyPercentage: Float {
        guard totalPutts > 0 else { return 0 }
        return Float(zoneAccuracyAchieved) / Float(totalPutts) * 100
    }
}

// MARK: - Track Complete Stats

struct TrackCompleteStats {
    let trackNumber: Int
    let totalPutts: Int
    let overallAccuracy: Float      // 0.0–1.0
    let practiceSeconds: Double
    let strongestSpeed: Int?        // MPH value with best accuracy today
    let strongestAccuracy: Float    // 0.0–1.0
    let weakestSpeed: Int?          // MPH value with worst accuracy today
    let weakestAccuracy: Float      // 0.0–1.0
    let bestBlock: String?          // e.g. "Block 2: Speed Builder" (nil for single-block tracks)

    var practiceMinutes: Int { Int(practiceSeconds / 60) }
    var practiceSecondsRemainder: Int { Int(practiceSeconds.truncatingRemainder(dividingBy: 60)) }
    var accuracyPercent: Int { Int(overallAccuracy * 100) }
}
