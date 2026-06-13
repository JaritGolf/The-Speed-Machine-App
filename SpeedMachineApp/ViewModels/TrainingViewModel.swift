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
    @Published var selectedDay: TrainingDay?
    @Published var selectedBlock: TrainingBlock?
    @Published var currentSession: SessionProgress?
    @Published var isSessionActive = false
    @Published var blockCompletionPending = false
    @Published var blockJustCompleted = false
    /// True when the just-completed block FAILED. Drives the red variant of the
    /// "BLOCK FAILED" drop-down banner. Pairs with `blockJustCompleted` (which is
    /// the umbrella "banner is showing" flag) so the view branches color/text/icon.
    /// Reset alongside `blockJustCompleted` everywhere.
    @Published var lastBlockFailed: Bool = false
    @Published var nextBlockForTransition: TrainingBlock? = nil
    @Published var shouldNavigateHome = false
    @Published var gateTestResult: GateTestResult?
    @Published var showGateTestFailedAlert = false
    /// Set when a standard block fails its in-zone threshold — drives BlockFailedView.
    @Published var blockFailedResult: BlockFailResult? = nil
    /// Next track queued for auto-advance after a track completes. nil = no next (track 30).
    @Published var nextTrackForAutoAdvance: TrainingDay? = nil
    /// Guards the pending 5s auto-advance Task so Exit cancels it.
    private var autoAdvanceToken: UUID?
    @Published var dayCompleteStats: DayCompleteStats? = nil
    /// Context label shown in the session header when a block uses adaptive interleaved selection.
    /// e.g. "Your optimal challenge · Zone 2" — nil for non-adaptive blocks.
    @Published var adaptiveBlockContext: String? = nil
    /// Incremented whenever completion data is repaired — triggers DaySelectionView re-render.
    @Published var repairVersion: Int = 0

    private let dataService = DataService.shared
    private let statsService = StatsService.shared
    private let adaptiveEngine = AdaptiveSpeedEngine.shared
    private let programLoader = TrainingProgramLoader.shared
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    /// Tracks when the first block of a day session began — not reset between blocks.
    private var daySessionStartTime: Date?

    var currentDay: Int {
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

    func isDayUnlocked(_ dayNumber: Int) -> Bool {
        // Day 1 is always unlocked
        if dayNumber == 1 { return true }

        // Current day is unlocked
        if dayNumber == currentDay { return true }

        // Any completed day is unlocked
        if dataService.isDayCompleted(dayNumber) { return true }

        // Check if previous day is completed
        let previousDayCompleted = dataService.isDayCompleted(dayNumber - 1)

        // Recovery path: all blocks of the previous day may be complete in Core Data
        // even though DayCompletionData was never written (session ended before completeBlock fired).
        // If so, treat the previous day as complete.
        let effectivePreviousDayCompleted: Bool
        if !previousDayCompleted, let prevDay = programLoader.getDay(dayNumber - 1) {
            let prevBlockIds = prevDay.blocks.map { $0.blockId }
            let completedCount = dataService.getCompletedBlockCount(
                dayNumber: dayNumber - 1,
                blockIds: prevBlockIds
            )
            effectivePreviousDayCompleted = completedCount >= prevDay.blocks.count
        } else {
            effectivePreviousDayCompleted = previousDayCompleted
        }

        // Also check if there's a gate test required before this day
        // Gate test days: 5, 9, 12, 19, 25, 30
        // Gate test on day X must be passed to proceed past that day
        if let gateTest = programLoader.getGateTest(forDay: dayNumber - 1) {
            // Previous day was a gate test - must have passed it
            if !passedGateTests.contains(gateTest.gateId) {
                return false
            }
        }

        return effectivePreviousDayCompleted
    }

    func isDayCompleted(_ dayNumber: Int) -> Bool {
        return dataService.isDayCompleted(dayNumber)
    }

    func isGateTestDay(_ dayNumber: Int) -> Bool {
        return programLoader.isGateTestDay(dayNumber)
    }

    func getGateTestForDay(_ dayNumber: Int) -> GateTest? {
        return programLoader.getGateTest(forDay: dayNumber)
    }

    func getDayStatus(_ dayNumber: Int) -> DayStatus {
        if isDayCompleted(dayNumber) {
            return .completed
        } else if dayNumber == currentDay {
            return .current
        } else if isDayUnlocked(dayNumber) {
            return .available
        } else {
            return .locked
        }
    }

    func startBlock(_ block: TrainingBlock, for day: TrainingDay) {
        selectedDay = day
        selectedBlock = block

        let session = SessionProgress(block: block, dayNumber: day.day)

        // Smart interleaved blocks: data-driven speed selection + context label for header
        if block.adaptiveMode != nil,
           let result = adaptiveEngine.generateSmartInterleavedResult(for: block, day: day) {
            session.adaptiveSequence = result.sequence
            adaptiveBlockContext = result.context
        } else {
            // Standard adaptive weighting for random/exploration/warmup/etc. blocks
            adaptiveBlockContext = nil
            if let adaptiveSeq = adaptiveEngine.generateAdaptiveSequence(for: block, day: day) {
                session.adaptiveSequence = adaptiveSeq
            }
        }

        currentSession = session
        isSessionActive = true
        gateTestResult = nil
        blockFailedResult = nil
        blockJustCompleted = false
        lastBlockFailed = false
        nextTrackForAutoAdvance = nil
        autoAdvanceToken = nil
        sessionStartTime = Date()
        // Only record the day-level start time on the first block — preserve it through auto-advances.
        if daySessionStartTime == nil {
            daySessionStartTime = Date()
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func recordPutt(_ speed: Float) {
        guard let session = currentSession, let block = selectedBlock, let day = selectedDay else { return }

        // Get the target speed (may differ based on block type)
        let targetSpeed: Int
        if session.blockSessionType == .eliminationLadder {
            targetSpeed = session.getCurrentLadderSpeed()
        } else if session.blockSessionType == .warmup {
            targetSpeed = session.currentTargetSpeed  // Will be random
        } else {
            targetSpeed = session.currentTargetSpeed
        }

        // Calculate tolerance and check if in zone. SpeedMath compares in
        // integer tenths so the result matches the %.1f display exactly and
        // boundary putts (e.g. 10.6 at 10 ±0.6) can never fail on Float error.
        let roundedSpeed = (speed * 10).rounded() / 10
        let tolerance: Float
        let isInZone: Bool
        if let acceptRange = block.acceptRange {
            tolerance = (acceptRange.max - acceptRange.min) / 2
            isInZone = SpeedMath.isInZone(actual: speed, min: acceptRange.min, max: acceptRange.max)
        } else {
            let t = programLoader.getToleranceForSpeed(targetSpeed)
            tolerance = t
            isInZone = SpeedMath.isInZone(actual: speed, target: targetSpeed, tolerance: t)
        }

        // Standard putt recording FIRST
        session.recordPutt(actualSpeed: roundedSpeed)

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
        if let sessionData = getOrCreateSessionData(for: block, day: day.day) {
            dataService.recordPutt(
                session: sessionData,
                targetSpeed: Float(targetSpeed),
                actualSpeed: roundedSpeed,
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
            actualSpeed: roundedSpeed,
            tolerance: tolerance
        )

        // Check if block is complete — 3-second delay so the final putt result
        // is visible on screen before the block advances or transitions.
        // The banner overlay shows on BOTH outcomes: green ✓ "BLOCK COMPLETE" on
        // pass, red ✗ "BLOCK FAILED" on fail. `blockJustCompleted` gates the
        // overlay's visibility; `lastBlockFailed` selects the red variant.
        if session.isComplete || session.isLadderComplete {
            let passed = blockIsPassed(session, block, day)
            // Set the color flag BEFORE the visibility flag so the banner can never
            // render one frame in the wrong color while both `@Published` writes
            // settle through SwiftUI's diff cycle.
            lastBlockFailed = !passed
            blockJustCompleted = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { completeBlock() }
            }
        }
    }

    /// Decides whether a completed block passed. Special self-completing session types
    /// (warmup / elimination ladder / recovery) are never in-zone-count gated; standard
    /// blocks are gated by `requiredInZonePutts`. Make-in-row passes only once the
    /// consecutive streak is achieved (completion already implies this, but gate it
    /// explicitly so the pass logic can't be bypassed by any putt-count path).
    func blockIsPassed(_ session: SessionProgress, _ block: TrainingBlock, _ day: TrainingDay) -> Bool {
        switch session.blockSessionType {
        case .warmup, .eliminationLadder, .recovery: return true
        case .makeInRow: return session.pressureChallengeComplete
        case .standard: break
        }
        let required = block.requiredInZonePutts(day: day.day, totalPutts: session.totalPutts)
        if required == 0 { return true }
        return session.inZonePutts >= required
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
            // Threshold scales with ladder length so both 5-rung and 12-rung ladders behave proportionally.
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
        // The consecutive counter and pressureChallengeComplete are fully maintained by
        // SessionProgress.recordPutt (increment on in-zone, reset to 0 on miss). Do NOT
        // mutate the counter again here — doing so double-counts every in-zone putt and
        // makes the block "pass" after ~half the required streak. This handler is haptics only.
        if isInZone {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var activeSessionData: SessionData?

    private func getOrCreateSessionData(for block: TrainingBlock, day: Int) -> SessionData? {
        if let existing = activeSessionData {
            return existing
        }

        let targetPutts = currentSession?.totalPutts ?? block.putts ?? 0
        let sessionData = dataService.createSession(
            dayNumber: day,
            blockId: block.blockId,
            targetPutts: targetPutts
        )
        activeSessionData = sessionData
        return sessionData
    }

    func completeBlock() {
        guard let day = selectedDay, let block = selectedBlock, let session = currentSession else { return }

        // Banner has served its purpose — hide it now.
        blockJustCompleted = false
        lastBlockFailed = false

        // Check if this is a gate test block with pass criteria
        if block.type == .gateTest && block.passRequirements != nil {
            evaluateGateTest()
            return
        }

        // Standard-block pass/fail gate. A failed block must NOT advance or complete the
        // day — show BlockFailedView and keep the block uncompleted so the next block /
        // day stay locked (same mechanism gate-test failures use: isComplete: false).
        if !blockIsPassed(session, block, day) {
            if let sessionData = activeSessionData {
                dataService.updateSession(
                    sessionData,
                    completedPutts: session.currentPutt,
                    onTargetPutts: session.inZonePutts,
                    isComplete: false
                )
            }
            blockCompletionPending = false
            blockFailedResult = BlockFailResult(
                inZone: session.inZonePutts,
                required: block.requiredInZonePutts(day: day.day, totalPutts: session.totalPutts),
                totalPutts: session.currentPutt
            )
            return
        }

        let blockIds = day.blocks.map { $0.blockId }
        blockCompletionPending = true

        // Find the next block in this day
        if let currentBlockIndex = day.blocks.firstIndex(where: { $0.blockId == block.blockId }) {
            if currentBlockIndex < day.blocks.count - 1 {
                // There's a next block in this day, auto-advance to it
                let nextBlock = day.blocks[currentBlockIndex + 1]
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
                        self.startBlock(nextBlock, for: day)
                    }
                }
                return
            }
        }

        // Last block of the day — save progress then show DayCompleteView
        if !dataService.isDayCompleted(day.day) {
            dataService.markDayComplete(
                dayNumber: day.day,
                accuracy: session.zoneAccuracy,
                totalPutts: session.currentPutt,
                onTargetPutts: session.inZonePutts
            )

            // Advance to next day
            if day.day < 30 {
                dataService.updateProgress(currentDay: day.day + 1, phase: day.phase)
            }
        }

        // Compute day stats and hand off to DayCompleteView (user taps Done to go home).
        dayCompleteStats = computeDayCompleteStats(day: day)

        // Queue the 5s auto-advance into the next track's first block (no-op on track 30).
        scheduleTrackAutoAdvance(after: day)
    }

    /// Queues a 5-second auto-advance into the first block of the next track. Shows the
    /// countdown wheel on the completion screen; if no next track exists (track 30) it is a
    /// no-op and the screen keeps its plain "Back to Tracks" exit.
    private func scheduleTrackAutoAdvance(after completedDay: TrainingDay) {
        guard let nextDay = programLoader.getDay(completedDay.day + 1),
              let firstBlock = nextDay.blocks.first else {
            nextTrackForAutoAdvance = nil   // track 30 → stop, no wheel
            return
        }
        nextTrackForAutoAdvance = nextDay
        let token = UUID()
        autoAdvanceToken = token
        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                guard self.autoAdvanceToken == token else { return }  // exited → cancelled
                self.startNextTrack(nextDay, firstBlock: firstBlock)
            }
        }
    }

    /// Resets session state and starts the next track's first block (mirrors the
    /// between-block reset but for a fresh track, finalizing the prior track's time).
    private func startNextTrack(_ nextDay: TrainingDay, firstBlock: TrainingBlock) {
        // Finalize the just-finished track's practice time, then time the new track fresh.
        if let start = daySessionStartTime {
            statsService.addPracticeTime(seconds: Date().timeIntervalSince(start))
        }
        daySessionStartTime = nil
        autoAdvanceToken = nil
        nextTrackForAutoAdvance = nil
        dayCompleteStats = nil
        blockCompletionPending = false
        nextBlockForTransition = nil
        gateTestResult = nil
        currentSession = nil
        selectedBlock = nil
        activeSessionData = nil
        startBlock(firstBlock, for: nextDay)   // startBlock re-inits daySessionStartTime
    }

    /// Builds the summary stat block shown on DayCompleteView.
    private func computeDayCompleteStats(day: TrainingDay) -> DayCompleteStats {
        // 1. Fetch all sessions for this day
        let sessions = dataService.getSessionsForDay(day.day)
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
            let matchedBlock = day.blocks.first(where: { $0.blockId == blockId }),
            let idx = day.blocks.firstIndex(where: { $0.blockId == blockId })
            else { return nil }
            return "Block \(idx + 1): \(matchedBlock.name)"
        }()

        return DayCompleteStats(
            dayNumber: day.day,
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

        let zoneAccuracyMet = session.inZonePutts >= requirements.zoneAccuracy.minimum

        let passed = zoneAccuracyMet

        gateTestResult = GateTestResult(
            gateId: gateId,
            passed: passed,
            zoneAccuracyRequired: requirements.zoneAccuracy.minimum,
            zoneAccuracyAchieved: session.inZonePutts,
            totalPutts: session.currentPutt
        )

        if passed {
            dataService.recordGateTestPassed(gateId: gateId)

            // Complete the block and potentially the day
            if let day = selectedDay {
                let blockIds = day.blocks.map { $0.blockId }
                let completedBlockCount = dataService.getCompletedBlockCount(
                    dayNumber: day.day,
                    blockIds: blockIds
                )

                if completedBlockCount >= day.blocks.count - 1 { // -1 because current block isn't recorded yet
                    dataService.markDayComplete(
                        dayNumber: day.day,
                        accuracy: session.zoneAccuracy,
                        totalPutts: session.currentPutt,
                        onTargetPutts: session.inZonePutts
                    )

                    if day.day < 30 {
                        dataService.updateProgress(currentDay: day.day + 1, phase: day.phase)
                    }

                    // Passing the gate completed the track — queue the same 5s auto-advance
                    // into the next track that normal track completion uses.
                    scheduleTrackAutoAdvance(after: day)
                }
            }
        } else {
            // Reset the session's isComplete flag in Core Data so the gate test
            // block does NOT appear as completed in BlockSelectionView. Without
            // this, blocks that follow the gate test would become unlocked even
            // though the test was failed. Resetting here keeps them locked and
            // forces the user to retry the gate test before proceeding.
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

    /// Restarts the just-failed block in place (Try Again on BlockFailedView).
    func retryBlock() {
        guard let day = selectedDay, let block = selectedBlock else { return }
        blockFailedResult = nil
        blockJustCompleted = false
        lastBlockFailed = false
        activeSessionData = nil   // force a fresh SessionData record on the next putt
        currentSession = nil
        startBlock(block, for: day)
    }

    /// Resets the current block in place from the live RESET button — clears all
    /// putts, progress, streak, lives, and ladder rung, then restarts the same block.
    /// Mirrors retryBlock(); startBlock() builds a fresh SessionProgress so every
    /// per-block counter resets. The partial SessionData record is orphaned and a new
    /// one is created on the next putt (same as Try Again).
    func resetBlock() {
        guard let day = selectedDay, let block = selectedBlock else { return }
        blockFailedResult = nil
        blockJustCompleted = false
        lastBlockFailed = false
        blockCompletionPending = false
        activeSessionData = nil
        currentSession = nil
        startBlock(block, for: day)
    }

    func endSession() {
        // Safety net: if all blocks of the current day are complete but the day
        // wasn't marked complete yet (e.g. session was dismissed during the 3-second
        // completeBlock delay), mark it now before clearing state.
        if let day = selectedDay, !dataService.isDayCompleted(day.day) {
            let blockIds = day.blocks.map { $0.blockId }
            let completedCount = dataService.getCompletedBlockCount(
                dayNumber: day.day,
                blockIds: blockIds
            )
            if completedCount >= day.blocks.count {
                dataService.markDayComplete(
                    dayNumber: day.day,
                    accuracy: currentSession?.zoneAccuracy ?? 0,
                    totalPutts: currentSession?.currentPutt ?? 0,
                    onTargetPutts: currentSession?.inZonePutts ?? 0
                )
                if day.day < 30 {
                    dataService.updateProgress(currentDay: day.day + 1, phase: day.phase)
                }
            }
        }

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
        lastBlockFailed = false
        dayCompleteStats = nil
        adaptiveBlockContext = nil
        nextBlockForTransition = nil
        activeSessionData = nil
        currentSession = nil
        selectedBlock = nil
        selectedDay = nil
        gateTestResult = nil
        blockFailedResult = nil
        nextTrackForAutoAdvance = nil
        autoAdvanceToken = nil
        sessionStartTime = nil
        daySessionStartTime = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// Scans completed-block data and writes any missing DayCompletionData records.
    /// Call from DaySelectionView.onAppear to recover from sessions that ended before
    /// completeBlock() had a chance to write the completion marker.
    func repairMissingCompletions() {
        guard let days = programLoader.program?.days else { return }
        var anyRepaired = false
        var maxRepairedDay = 0

        for day in days.sorted(by: { $0.day < $1.day }) {
            // Already properly recorded — keep track of the highest complete day.
            if dataService.isDayCompleted(day.day) {
                maxRepairedDay = day.day
                continue
            }
            // Check whether all blocks are done in SessionData.
            let blockIds = day.blocks.map { $0.blockId }
            guard !blockIds.isEmpty else { continue }
            let count = dataService.getCompletedBlockCount(dayNumber: day.day, blockIds: blockIds)
            guard count >= day.blocks.count else { break } // Not done — stop scanning.

            // Write the missing DayCompletionData record.
            dataService.markDayComplete(
                dayNumber: day.day,
                accuracy: 0,
                totalPutts: 0,
                onTargetPutts: 0
            )
            maxRepairedDay = day.day
            anyRepaired = true
        }

        if anyRepaired {
            // Advance currentDay to the first track after the last repaired one.
            let nextDay = maxRepairedDay + 1
            if nextDay <= 30 && currentDay <= maxRepairedDay,
               let completedDay = programLoader.getDay(maxRepairedDay) {
                dataService.updateProgress(currentDay: nextDay, phase: completedDay.phase)
            }
            repairVersion += 1 // Trigger re-render of DaySelectionView.
        }
    }

    func getAllDays() -> [TrainingDay] {
        return programLoader.program?.days ?? []
    }

    func getDay(_ number: Int) -> TrainingDay? {
        return programLoader.getDay(number)
    }

    func getPhase(_ number: Int) -> Phase? {
        return programLoader.getPhase(number)
    }

    func getSpeedZone(_ number: Int) -> SpeedZoneInfo? {
        return programLoader.getSpeedZone(number)
    }
}

enum DayStatus {
    case locked
    case available
    case current
    case completed
}

struct GateTestResult {
    let gateId: String
    let passed: Bool
    let zoneAccuracyRequired: Int
    let zoneAccuracyAchieved: Int
    let totalPutts: Int

    var zoneAccuracyPercentage: Float {
        guard totalPutts > 0 else { return 0 }
        return Float(zoneAccuracyAchieved) / Float(totalPutts) * 100
    }
}

// MARK: - Day Complete Stats

struct DayCompleteStats {
    let dayNumber: Int
    let totalPutts: Int
    let overallAccuracy: Float      // 0.0–1.0
    let practiceSeconds: Double
    let strongestSpeed: Int?        // MPH value with best accuracy today
    let strongestAccuracy: Float    // 0.0–1.0
    let weakestSpeed: Int?          // MPH value with worst accuracy today
    let weakestAccuracy: Float      // 0.0–1.0
    let bestBlock: String?          // e.g. "Block 2: Speed Builder" (nil for single-block days)

    var practiceMinutes: Int { Int(practiceSeconds / 60) }
    var practiceSecondsRemainder: Int { Int(practiceSeconds.truncatingRemainder(dividingBy: 60)) }
    var accuracyPercent: Int { Int(overallAccuracy * 100) }
}
