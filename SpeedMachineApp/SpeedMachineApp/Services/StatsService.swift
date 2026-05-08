//
//  StatsService.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import CoreData
import Combine

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

    private init() {
        loadSpeedProfiles()
        recalculateOverallStats()
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
                    newProfile.recentPutts = 0
                    newProfile.recentOnTargetPutts = 0
                    newProfile.tierOverride = -1
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
        let isOnTarget = abs(actualSpeed - Float(targetSpeed)) <= tolerance
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

        // Rolling last-20 window for MasteryService recent-accuracy tracking.
        // Simple approach: cap recentPutts at 20 and track recentOnTargetPutts
        // proportionally. Once the window is full, slide it by adjusting the
        // on-target count based on the incoming hit/miss.
        let cap: Int16 = 20
        if profile.recentPutts < cap {
            profile.recentPutts += 1
            if isOnTarget { profile.recentOnTargetPutts += 1 }
        } else {
            // Window is full — approximate the evicted putt as the current running
            // accuracy (keeps the window stable without storing individual records).
            let evictedWasOnTarget = Double(profile.recentOnTargetPutts) / Double(profile.recentPutts) >= 0.5
            if evictedWasOnTarget && !isOnTarget {
                profile.recentOnTargetPutts = max(0, profile.recentOnTargetPutts - 1)
            } else if !evictedWasOnTarget && isOnTarget {
                profile.recentOnTargetPutts = min(cap, profile.recentOnTargetPutts + 1)
            }
            // recentPutts stays at cap
        }

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

        // Practice streak (consecutive days with at least 1 putt)
        currentPracticeStreak = calculatePracticeStreak()
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
        } catch {
            print("Failed to reset stats: \(error)")
        }
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
