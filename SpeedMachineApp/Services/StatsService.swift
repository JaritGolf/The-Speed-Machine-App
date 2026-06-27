 //
//  StatsService.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import CoreData
import Combine
import UIKit

/// Manages all stat tracking independent of training protocol.
/// Maintains SpeedProfile (per-speed running stats) and DailySnapshot (per-day aggregates).
class StatsService: ObservableObject {
    static let shared = StatsService()

    private let dataService = DataService.shared
    private var context: NSManagedObjectContext {
        dataService.container.viewContext
    }

    // Cached speed profiles (18 rows, always in memory)
    @Published var speedProfiles: [Int: SpeedProfileData] = [:]

    // Overall computed stats
    @Published var overallAccuracy: Double = 0
    @Published var overallConsistency: Double = 0
    @Published var totalLifetimePutts: Int = 0
    @Published var currentPracticeStreak: Int = 0
    @Published var weakestSpeeds: [SpeedProfileData] = []
    @Published var strongestSpeeds: [SpeedProfileData] = []
    /// Speeds (3–15 goal range) most in need of a tune-up, ranked by decay-risk × weakness.
    /// Powers the Maintenance / Daily Tune-Up recall round.
    @Published var maintenanceFocusSpeeds: [Int] = []

    private init() {
        loadSpeedProfiles()
        recalculateOverallStats()

        // Snapshot stats to KV whenever the app moves to background or is about to terminate,
        // so data is always current even if the user never finishes a formal session.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.snapshotStatsToKV()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.snapshotStatsToKV()
        }
    }

    // MARK: - Speed Profile Management

    /// Load all 18 speed profiles into memory. Creates missing ones.
    func loadSpeedProfiles() {
        let request: NSFetchRequest<SpeedProfileData> = SpeedProfileData.fetchRequest()

        do {
            let results = try context.fetch(request)
            var profileMap: [Int: SpeedProfileData] = [:]
            for profile in results {
                profileMap[Int(profile.targetSpeed)] = profile
            }

            // Ensure all 18 speeds (3-20) have a profile
            for speed in 3...20 {
                if profileMap[speed] == nil {
                    let newProfile = SpeedProfileData(context: context)
                    newProfile.targetSpeed = Int16(speed)
                    newProfile.totalPutts = 0
                    newProfile.onTargetPutts = 0
                    newProfile.totalDeviation = 0
                    newProfile.totalSignedDeviation = 0
                    newProfile.sumSquaredDeviation = 0
                    newProfile.sumActualSpeed = 0
                    newProfile.bestStreak = 0
                    newProfile.currentStreak = 0
                    profileMap[speed] = newProfile
                }
            }

            try context.save()
            speedProfiles = profileMap
        } catch {
            print("Failed to load speed profiles: \(error)")
        }
    }

    // MARK: - Record a Putt (called from TrainingViewModel and CombineViewModel)

    /// Update SpeedProfile and DailySnapshot for a single putt.
    /// This is the main entry point — call after every putt from any mode.
    func recordPutt(targetSpeed: Int, actualSpeed: Float, tolerance: Float) {
        let isOnTarget = SpeedMath.isInZone(actual: actualSpeed, target: targetSpeed, tolerance: tolerance)
        let deviation = abs(actualSpeed - Float(targetSpeed))
        let signedDeviation = Double(actualSpeed) - Double(targetSpeed)

        // 1. Update SpeedProfile
        updateSpeedProfile(
            targetSpeed: targetSpeed,
            actualSpeed: actualSpeed,
            deviation: Double(deviation),
            signedDeviation: signedDeviation,
            isOnTarget: isOnTarget
        )

        // 2. Update DailySnapshot
        updateDailySnapshot(
            deviation: Double(deviation),
            actualSpeed: actualSpeed,
            isOnTarget: isOnTarget
        )

        // 3. Recalculate overall stats
        recalculateOverallStats()
    }

    private func updateSpeedProfile(targetSpeed: Int, actualSpeed: Float, deviation: Double, signedDeviation: Double, isOnTarget: Bool) {
        guard let profile = speedProfiles[targetSpeed] else { return }

        profile.totalPutts += 1
        if isOnTarget {
            profile.onTargetPutts += 1
            profile.currentStreak += 1
            if profile.currentStreak > profile.bestStreak {
                profile.bestStreak = profile.currentStreak
            }
        } else {
            profile.currentStreak = 0
        }

        profile.totalDeviation += deviation
        profile.totalSignedDeviation += signedDeviation
        profile.sumSquaredDeviation += Double(actualSpeed) * Double(actualSpeed)
        profile.sumActualSpeed += Double(actualSpeed)
        profile.lastPracticedAt = Date()

        saveContext()
    }

    private func updateDailySnapshot(deviation: Double, actualSpeed: Float, isOnTarget: Bool) {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = getOrCreateDailySnapshot(for: today)

        snapshot.totalPutts += 1
        if isOnTarget {
            snapshot.onTargetPutts += 1
        }
        snapshot.totalDeviation += deviation
        snapshot.sumSquaredDeviation += Double(actualSpeed) * Double(actualSpeed)

        saveContext()
    }

    // MARK: - Daily Snapshot

    private func getOrCreateDailySnapshot(for date: Date) -> DailySnapshotData {
        let request: NSFetchRequest<DailySnapshotData> = DailySnapshotData.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.fetchLimit = 1

        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            }
        } catch {
            print("Failed to fetch daily snapshot: \(error)")
        }

        // Create new
        let snapshot = DailySnapshotData(context: context)
        snapshot.date = startOfDay
        snapshot.totalPutts = 0
        snapshot.onTargetPutts = 0
        snapshot.totalDeviation = 0
        snapshot.sumSquaredDeviation = 0
        snapshot.practiceSeconds = 0
        return snapshot
    }

    /// Update practice time for today's snapshot (call at session end)
    func addPracticeTime(seconds: Double) {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = getOrCreateDailySnapshot(for: today)
        snapshot.practiceSeconds += seconds
        saveContext()
        snapshotStatsToKV()
    }

    // MARK: - Trend Queries

    /// Get daily snapshots for a date range (for trend charts)
    func getDailySnapshots(days: Int) -> [DailySnapshotData] {
        let request: NSFetchRequest<DailySnapshotData> = DailySnapshotData.fetchRequest()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailySnapshotData.date, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch daily snapshots: \(error)")
            return []
        }
    }

    /// Get all daily snapshots (for all-time view)
    func getAllDailySnapshots() -> [DailySnapshotData] {
        let request: NSFetchRequest<DailySnapshotData> = DailySnapshotData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailySnapshotData.date, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    // MARK: - Overall Stats

    func recalculateOverallStats() {
        let profiles = Array(speedProfiles.values).filter { $0.totalPutts > 0 }

        // Overall accuracy
        let totalPutts = profiles.reduce(0) { $0 + Int($1.totalPutts) }
        let totalOnTarget = profiles.reduce(0) { $0 + Int($1.onTargetPutts) }
        totalLifetimePutts = totalPutts
        overallAccuracy = totalPutts > 0 ? Double(totalOnTarget) / Double(totalPutts) * 100 : 0

        // Overall consistency (average std dev across practiced speeds)
        let practicedProfiles = profiles.filter { $0.totalPutts >= 5 }
        if !practicedProfiles.isEmpty {
            let avgStdDev = practicedProfiles.reduce(0.0) { $0 + $1.standardDeviation } / Double(practicedProfiles.count)
            overallConsistency = avgStdDev
        }

        // Weakest speeds (sorted by accuracy ascending, min 5 putts to qualify)
        let qualified = profiles.filter { $0.totalPutts >= 5 }
        weakestSpeeds = Array(qualified.sorted { $0.accuracy < $1.accuracy }.prefix(3))
        strongestSpeeds = Array(qualified.sorted { $0.accuracy > $1.accuracy }.prefix(3))

        // Maintenance focus: practiced speeds in the 3–15 goal range, ranked by how much a
        // tune-up would help (low accuracy and/or long since last practiced). Top 5.
        let goalRange = 3...15
        maintenanceFocusSpeeds = qualified
            .filter { goalRange.contains(Int($0.targetSpeed)) }
            .sorted { maintenancePriority(for: $0) > maintenancePriority(for: $1) }
            .prefix(5)
            .map { Int($0.targetSpeed) }

        // Practice streak (consecutive days with at least 1 putt)
        currentPracticeStreak = calculatePracticeStreak()
    }

    /// Whole calendar days since a speed was last practiced (nil if never).
    func daysSincePracticed(_ speed: Int) -> Int? {
        guard let last = speedProfiles[speed]?.lastPracticedAt else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date())).day
    }

    /// Tune-up priority: weakness (100 − accuracy) plus a decay penalty per stale day.
    private func maintenancePriority(for profile: SpeedProfileData) -> Double {
        let weakness = max(0, 100.0 - profile.accuracy)
        let staleDays = Double(daysSincePracticed(Int(profile.targetSpeed)) ?? 0)
        let decayPerDay = 6.0
        return weakness + staleDays * decayPerDay
    }

    private func calculatePracticeStreak() -> Int {
        let request: NSFetchRequest<DailySnapshotData> = DailySnapshotData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailySnapshotData.date, ascending: false)]
        request.predicate = NSPredicate(format: "totalPutts > 0")

        do {
            let snapshots = try context.fetch(request)
            guard !snapshots.isEmpty else { return 0 }

            var streak = 0
            let calendar = Calendar.current
            var expectedDate = calendar.startOfDay(for: Date())

            // Check if today has practice — if not, start from yesterday
            if let firstDate = snapshots.first?.date,
               !calendar.isDate(firstDate, inSameDayAs: expectedDate) {
                // No practice today — check if yesterday had practice
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            }

            for snapshot in snapshots {
                guard let snapshotDate = snapshot.date else { continue }
                let snapshotDay = calendar.startOfDay(for: snapshotDate)

                if calendar.isDate(snapshotDay, inSameDayAs: expectedDate) {
                    streak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
                } else if snapshotDay < expectedDate {
                    // Gap in practice — streak broken
                    break
                }
            }

            return streak
        } catch {
            return 0
        }
    }

    // MARK: - Session Detail Queries

    /// All putt records on/after `since` (nil = all time), oldest first.
    /// Spine for the time-series Trends charts. Covers training + practice modes
    /// (Combine shots carry no per-shot timestamp and are intentionally excluded).
    func getPuttRecords(since: Date?) -> [PuttRecordData] {
        let request: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
        if let since = since {
            request.predicate = NSPredicate(format: "timestamp >= %@", since as NSDate)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PuttRecordData.timestamp, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch putt records for trends: \(error)")
            return []
        }
    }

    /// Get all putt records for a specific session (for session deep-dive)
    func getPuttRecords(for sessionId: UUID) -> [PuttRecordData] {
        let request: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PuttRecordData.timestamp, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    /// Get all sessions (for session history)
    func getAllSessions(limit: Int? = nil) -> [SessionData] {
        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionData.startedAt, ascending: false)]
        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    // MARK: - Combine Stats

    func getAllCombineGames() -> [CombineGameData] {
        let request: NSFetchRequest<CombineGameData> = CombineGameData.fetchRequest()
        request.predicate = NSPredicate(format: "isComplete == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CombineGameData.playedAt, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    func getCombineShots(for gameId: UUID) -> [CombineShotData] {
        let request: NSFetchRequest<CombineShotData> = CombineShotData.fetchRequest()
        request.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CombineShotData.shotNumber, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    var combineAverageScore: Double {
        let games = getAllCombineGames()
        guard !games.isEmpty else { return 0 }
        let total = games.reduce(0) { $0 + Int($1.totalScore) }
        return Double(total) / Double(games.count)
    }

    // MARK: - Reset Stats

    /// Wipe all speed profiles and daily snapshots. Training progress untouched.
    func resetAllStats() {
        // Clear speed profiles
        let profileRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SpeedProfileData")
        let deleteProfiles = NSBatchDeleteRequest(fetchRequest: profileRequest)

        // Clear daily snapshots
        let snapshotRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "DailySnapshotData")
        let deleteSnapshots = NSBatchDeleteRequest(fetchRequest: snapshotRequest)

        do {
            try context.execute(deleteProfiles)
            try context.execute(deleteSnapshots)
            try context.save()

            // Reload empty profiles
            speedProfiles = [:]
            loadSpeedProfiles()
            recalculateOverallStats()
            snapshotStatsToKV()
        } catch {
            print("Failed to reset stats: \(error)")
        }
    }

    // MARK: - iCloud KV Stats Backup

    private let kvSpeedProfileKey   = "speedProfileSnapshot"
    private let kvDailySnapshotsKey = "dailySnapshotsSnapshot"
    private let kvSnapshotDailyWindow = 90

    func snapshotStatsToKV() {
        let practicedProfiles = speedProfiles.values.filter { $0.totalPutts > 0 }
        let profileDicts: [[String: Any]] = practicedProfiles.map { p in
            var d: [String: Any] = [
                "targetSpeed":          Int(p.targetSpeed),
                "totalPutts":           Int(p.totalPutts),
                "onTargetPutts":        Int(p.onTargetPutts),
                "totalDeviation":       p.totalDeviation,
                "totalSignedDeviation": p.totalSignedDeviation,
                "sumSquaredDeviation":  p.sumSquaredDeviation,
                "sumActualSpeed":       p.sumActualSpeed,
                "bestStreak":           Int(p.bestStreak),
                "currentStreak":        Int(p.currentStreak),
                "recentPutts":          Int(p.recentPutts),
                "recentOnTargetPutts":  Int(p.recentOnTargetPutts),
                "tierOverride":         Int(p.tierOverride),
            ]
            if let lp = p.lastPracticedAt {
                d["lastPracticedAt"] = lp.timeIntervalSince1970
            }
            return d
        }
        if let data = try? JSONSerialization.data(withJSONObject: profileDicts),
           let json = String(data: data, encoding: .utf8) {
            NSUbiquitousKeyValueStore.default.set(json, forKey: kvSpeedProfileKey)
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -kvSnapshotDailyWindow, to: Date())!
        let request: NSFetchRequest<DailySnapshotData> = DailySnapshotData.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND totalPutts > 0", cutoff as NSDate)
        if let snapshots = try? context.fetch(request) {
            let snapshotDicts: [[String: Any]] = snapshots.compactMap { s in
                guard let d = s.date else { return nil }
                return [
                    "date":                d.timeIntervalSince1970,
                    "totalPutts":          Int(s.totalPutts),
                    "onTargetPutts":       Int(s.onTargetPutts),
                    "totalDeviation":      s.totalDeviation,
                    "sumSquaredDeviation": s.sumSquaredDeviation,
                    "practiceSeconds":     s.practiceSeconds,
                ]
            }
            if let data = try? JSONSerialization.data(withJSONObject: snapshotDicts),
               let json = String(data: data, encoding: .utf8) {
                NSUbiquitousKeyValueStore.default.set(json, forKey: kvDailySnapshotsKey)
            }
        }

        NSUbiquitousKeyValueStore.default.synchronize()
        print("Stats snapshot written to iCloud KV (\(practicedProfiles.count) speeds).")
    }

    // MARK: - Migration: Backfill from existing PuttRecordData

    /// One-time migration to populate SpeedProfiles from historical putt data.
    /// Called on first launch after stats update.
    func migrateExistingData() {
        let migrationKey = "statsDataMigrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let request: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PuttRecordData.timestamp, ascending: true)]

        do {
            let allPutts = try context.fetch(request)
            guard !allPutts.isEmpty else {
                UserDefaults.standard.set(true, forKey: migrationKey)
                return
            }

            for putt in allPutts {
                let targetSpeed = Int(roundf(putt.targetSpeed))
                guard targetSpeed >= 3 && targetSpeed <= 20 else { continue }
                guard let profile = speedProfiles[targetSpeed] else { continue }

                let deviation = abs(Double(putt.actualSpeed) - Double(putt.targetSpeed))
                let signedDeviation = Double(putt.actualSpeed) - Double(putt.targetSpeed)

                profile.totalPutts += 1
                if putt.isOnTarget {
                    profile.onTargetPutts += 1
                    profile.currentStreak += 1
                    if profile.currentStreak > profile.bestStreak {
                        profile.bestStreak = profile.currentStreak
                    }
                } else {
                    profile.currentStreak = 0
                }

                profile.totalDeviation += deviation
                profile.totalSignedDeviation += signedDeviation
                profile.sumSquaredDeviation += Double(putt.actualSpeed) * Double(putt.actualSpeed)
                profile.sumActualSpeed += Double(putt.actualSpeed)
                profile.lastPracticedAt = putt.timestamp
            }

            // Also build daily snapshots from historical data
            let grouped = Dictionary(grouping: allPutts) { putt -> Date in
                Calendar.current.startOfDay(for: putt.timestamp ?? Date())
            }

            for (date, putts) in grouped {
                let snapshot = getOrCreateDailySnapshot(for: date)
                // Reset in case partially created
                snapshot.totalPutts = 0
                snapshot.onTargetPutts = 0
                snapshot.totalDeviation = 0
                snapshot.sumSquaredDeviation = 0

                for putt in putts {
                    snapshot.totalPutts += 1
                    if putt.isOnTarget {
                        snapshot.onTargetPutts += 1
                    }
                    snapshot.totalDeviation += abs(Double(putt.actualSpeed) - Double(putt.targetSpeed))
                    snapshot.sumSquaredDeviation += Double(putt.actualSpeed) * Double(putt.actualSpeed)
                }
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: migrationKey)

            // Refresh
            loadSpeedProfiles()
            recalculateOverallStats()

            print("Stats migration complete: \(allPutts.count) putts processed")
        } catch {
            print("Stats migration failed: \(error)")
        }
    }

    // MARK: - Migration: Repair Float boundary misclassification

    /// One-time repair for records saved before SpeedMath existed: Float
    /// comparison error classified exact-boundary putts (e.g. 10.6 at 10 ±0.6)
    /// as misses. Re-classifies every stored putt and combine shot, then
    /// applies the difference to SpeedProfile, DailySnapshot, session, and
    /// combine score aggregates. Streak fields are left untouched — they can't
    /// be replayed exactly (combine shots carry no per-shot timestamp) and the
    /// stored values only ever under-count.
    func fixBoundaryClassification() {
        let migrationKey = "boundaryClassificationFixed_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        do {
            var flipped = 0

            // 1. Training putt records — stored isOnTarget is the old verdict.
            let puttRequest: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
            let allPutts = try context.fetch(puttRequest)
            var affectedSessionIds: Set<UUID> = []
            for putt in allPutts {
                let target = Int(roundf(putt.targetSpeed))
                let corrected = SpeedMath.isInZone(actual: putt.actualSpeed, target: target, tolerance: putt.tolerance)
                guard corrected != putt.isOnTarget else { continue }
                putt.isOnTarget = corrected
                flipped += 1
                if let sessionId = putt.sessionId { affectedSessionIds.insert(sessionId) }
                applyOnTargetDelta(corrected ? 1 : -1, target: target, date: putt.timestamp)
            }

            // Re-count onTargetPutts for sessions that had a putt flip.
            for sessionId in affectedSessionIds {
                let sessionRequest: NSFetchRequest<SessionData> = SessionData.fetchRequest()
                sessionRequest.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
                guard let session = try context.fetch(sessionRequest).first else { continue }
                let sessionPuttsRequest: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
                sessionPuttsRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
                let sessionPutts = try context.fetch(sessionPuttsRequest)
                session.onTargetPutts = Int16(sessionPutts.filter { $0.isOnTarget }.count)
            }

            // 2. Combine shots — reconstruct the old verdict the way the old
            // code computed it (raw Float comparison), then rescore with the
            // fixed math. Points can only increase, so the high score check
            // afterwards is safe.
            let gameRequest: NSFetchRequest<CombineGameData> = CombineGameData.fetchRequest()
            let games = try context.fetch(gameRequest)
            var gameDates: [UUID: Date] = [:]
            for game in games {
                if let id = game.id, let playedAt = game.playedAt { gameDates[id] = playedAt }
            }

            let shotRequest: NSFetchRequest<CombineShotData> = CombineShotData.fetchRequest()
            let shots = try context.fetch(shotRequest)
            let scorer = CombineGame(speeds: [])  // scorer only — calculateScore is independent of the target pool
            var rescoredGameIds: Set<UUID> = []
            for shot in shots {
                let target = Int(shot.targetSpeed)
                let tolerance = SpeedZone.getZone(for: target).tolerance
                let oldInZone = abs(shot.actualSpeed - Float(target)) <= tolerance
                let newInZone = SpeedMath.isInZone(actual: shot.actualSpeed, target: target, tolerance: tolerance)
                if newInZone != oldInZone {
                    flipped += 1
                    applyOnTargetDelta(newInZone ? 1 : -1, target: target, date: shot.gameId.flatMap { gameDates[$0] })
                }
                let (points, tier) = scorer.calculateScore(target: target, actual: shot.actualSpeed)
                if shot.points != Int16(points) || shot.accuracy != tier.rawValue {
                    shot.points = Int16(points)
                    shot.accuracy = tier.rawValue
                    if let gameId = shot.gameId { rescoredGameIds.insert(gameId) }
                }
            }

            // Re-total rescored games and refresh the high score.
            for game in games {
                guard let id = game.id, rescoredGameIds.contains(id) else { continue }
                let gameShots = shots.filter { $0.gameId == id }
                game.totalScore = gameShots.reduce(0) { $0 + $1.points }
            }
            if let best = games.map({ Int($0.totalScore) }).max() {
                dataService.updateCombineHighScore(best)
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
            loadSpeedProfiles()
            recalculateOverallStats()
            print("Boundary classification repair complete: \(flipped) records reclassified")
        } catch {
            print("Boundary classification repair failed: \(error)")
        }
    }

    private func applyOnTargetDelta(_ delta: Int, target: Int, date: Date?) {
        if let profile = speedProfiles[target] {
            profile.onTargetPutts = max(0, profile.onTargetPutts + Int32(delta))
        }
        if let date = date {
            let snapshot = getOrCreateDailySnapshot(for: Calendar.current.startOfDay(for: date))
            snapshot.onTargetPutts = max(0, snapshot.onTargetPutts + Int32(delta))
        }
    }

    // MARK: - Reconcile: rebuild all aggregates from de-duplicated raw events

    /// One-time repair for iCloud/CloudKit row duplication. `NSPersistentCloudKitContainer`
    /// enforces no uniqueness, so the two independent counters drifted apart: the per-speed
    /// SpeedProfile counter (which `totalLifetimePutts` and the Home/Stats KPIs read) collapses
    /// duplicate rows on load and under-counts, while the per-day DailySnapshot counter (which the
    /// Trends consistency card reads) over-counts. This de-duplicates the raw events by their stable
    /// `id`, then rebuilds BOTH aggregates from the clean set so every screen reads one number.
    /// Training putts (`PuttRecordData`) and Combine shots (`CombineShotData`) are both replayed.
    func reconcileStatsFromRawData() {
        let migrationKey = "statsReconciledFromRaw_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let cal = Calendar.current

        struct ReplayEvent {
            let date: Date
            let target: Int
            let actual: Float
            let isOnTarget: Bool
        }

        do {
            // 1a. De-duplicate training putts by stable id (delete the extras).
            let puttRequest: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
            let allPutts = try context.fetch(puttRequest)
            var seenPutt = Set<String>()
            var putts: [PuttRecordData] = []
            for p in allPutts {
                let key = p.id?.uuidString
                    ?? "nil:\(p.timestamp?.timeIntervalSince1970 ?? 0):\(p.targetSpeed):\(p.actualSpeed):\(p.sessionId?.uuidString ?? "-")"
                if seenPutt.insert(key).inserted { putts.append(p) } else { context.delete(p) }
            }

            // 1b. De-duplicate Combine shots by stable id.
            let shotRequest: NSFetchRequest<CombineShotData> = CombineShotData.fetchRequest()
            let allShots = try context.fetch(shotRequest)
            var seenShot = Set<String>()
            var shots: [CombineShotData] = []
            for s in allShots {
                let key = s.id?.uuidString ?? "nil:\(s.gameId?.uuidString ?? "-"):\(s.shotNumber)"
                if seenShot.insert(key).inserted { shots.append(s) } else { context.delete(s) }
            }

            // Combine shots carry no per-shot timestamp — anchor them to their game's playedAt.
            let gameRequest: NSFetchRequest<CombineGameData> = CombineGameData.fetchRequest()
            let games = try context.fetch(gameRequest)
            var gameDate: [UUID: Date] = [:]
            for g in games {
                guard let id = g.id, let d = g.playedAt else { continue }
                gameDate[id] = gameDate[id].map { Swift.min($0, d) } ?? d
            }

            // 2. Preserve per-day practiceSeconds (not derivable from putts) before wiping snapshots.
            let snapRequest: NSFetchRequest<DailySnapshotData> = DailySnapshotData.fetchRequest()
            let oldSnapshots = try context.fetch(snapRequest)
            var practiceByDay: [Date: Double] = [:]
            for s in oldSnapshots {
                guard let d = s.date else { continue }
                let day = cal.startOfDay(for: d)
                practiceByDay[day] = Swift.max(practiceByDay[day] ?? 0, s.practiceSeconds)
            }

            // 3a. Delete all snapshots — they'll be rebuilt from scratch.
            for s in oldSnapshots { context.delete(s) }

            // 3b. Collapse duplicate SpeedProfile rows to one per speed, then zero the survivor.
            let profileRequest: NSFetchRequest<SpeedProfileData> = SpeedProfileData.fetchRequest()
            let allProfiles = try context.fetch(profileRequest)
            var profileMap: [Int: SpeedProfileData] = [:]
            for p in allProfiles {
                let speed = Int(p.targetSpeed)
                if profileMap[speed] == nil { profileMap[speed] = p } else { context.delete(p) }
            }
            for speed in 3...20 {
                let profile = profileMap[speed] ?? {
                    let np = SpeedProfileData(context: context)
                    np.targetSpeed = Int16(speed)
                    return np
                }()
                profile.totalPutts = 0
                profile.onTargetPutts = 0
                profile.totalDeviation = 0
                profile.totalSignedDeviation = 0
                profile.sumSquaredDeviation = 0
                profile.sumActualSpeed = 0
                profile.bestStreak = 0
                profile.currentStreak = 0
                profile.recentPutts = 0
                profile.recentOnTargetPutts = 0
                profile.lastPracticedAt = nil
                profileMap[speed] = profile
            }

            // 4. Build one chronological event stream (only 3–20 MPH, so profile and snapshot
            //    count the identical set and their totals are guaranteed equal).
            var events: [ReplayEvent] = []
            for p in putts {
                guard let ts = p.timestamp else { continue }
                let target = Int(p.targetSpeed.rounded())
                guard (3...20).contains(target) else { continue }
                let isOn = SpeedMath.isInZone(actual: p.actualSpeed, target: target, tolerance: p.tolerance)
                events.append(ReplayEvent(date: ts, target: target, actual: p.actualSpeed, isOnTarget: isOn))
            }
            for s in shots {
                guard let gid = s.gameId, let base = gameDate[gid] else { continue }
                let target = Int(s.targetSpeed)
                guard (3...20).contains(target) else { continue }
                let tol = SpeedZone.getZone(for: target).tolerance
                let isOn = SpeedMath.isInZone(actual: s.actualSpeed, target: target, tolerance: tol)
                // Offset by shotNumber so shots within a game keep their order.
                let date = base.addingTimeInterval(Double(s.shotNumber))
                events.append(ReplayEvent(date: date, target: target, actual: s.actualSpeed, isOnTarget: isOn))
            }
            events.sort { $0.date < $1.date }

            // 5. Replay — mirrors updateSpeedProfile + updateDailySnapshot exactly.
            var snapByDay: [Date: DailySnapshotData] = [:]
            func snapshot(for day: Date) -> DailySnapshotData {
                if let existing = snapByDay[day] { return existing }
                let ns = DailySnapshotData(context: context)
                ns.date = day
                ns.totalPutts = 0
                ns.onTargetPutts = 0
                ns.totalDeviation = 0
                ns.sumSquaredDeviation = 0
                ns.practiceSeconds = 0
                snapByDay[day] = ns
                return ns
            }

            for e in events {
                let dev = abs(Double(e.actual) - Double(e.target))
                let signed = Double(e.actual) - Double(e.target)

                if let profile = profileMap[e.target] {
                    profile.totalPutts += 1
                    if e.isOnTarget {
                        profile.onTargetPutts += 1
                        profile.currentStreak += 1
                        if profile.currentStreak > profile.bestStreak { profile.bestStreak = profile.currentStreak }
                    } else {
                        profile.currentStreak = 0
                    }
                    profile.totalDeviation += dev
                    profile.totalSignedDeviation += signed
                    profile.sumSquaredDeviation += Double(e.actual) * Double(e.actual)
                    profile.sumActualSpeed += Double(e.actual)
                    profile.lastPracticedAt = e.date
                }

                let snap = snapshot(for: cal.startOfDay(for: e.date))
                snap.totalPutts += 1
                if e.isOnTarget { snap.onTargetPutts += 1 }
                snap.totalDeviation += dev
                snap.sumSquaredDeviation += Double(e.actual) * Double(e.actual)
            }

            // 6. Restore preserved practice time.
            for (day, secs) in practiceByDay {
                snapshot(for: day).practiceSeconds = secs
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: migrationKey)

            loadSpeedProfiles()
            recalculateOverallStats()
            snapshotStatsToKV()

            let rebuiltTotal = profileMap.values.reduce(0) { $0 + Int($1.totalPutts) }
            print("Stats reconcile complete: \(events.count) events → \(rebuiltTotal) putts across \(snapByDay.count) days "
                  + "(removed \(allPutts.count - putts.count) dup putts, \(allShots.count - shots.count) dup shots).")
        } catch {
            print("Stats reconcile failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("StatsService failed to save: \(error)")
            }
        }
    }

    /// Sorted speed profiles for display (3 MPH to 20 MPH)
    var sortedProfiles: [SpeedProfileData] {
        return (3...20).compactMap { speedProfiles[$0] }
    }

    /// Speed profiles that have been practiced
    var practicedProfiles: [SpeedProfileData] {
        return sortedProfiles.filter { $0.totalPutts > 0 }
    }
}
