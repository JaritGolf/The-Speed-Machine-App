//
//  DataService.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import CoreData
import Combine

class DataService: ObservableObject {
    static let shared = DataService()

    let container: NSPersistentContainer

    @Published var userProgress: UserProgressData
    @Published var combineHighScore: Int = 0

    private init() {
        container = NSPersistentContainer(name: "SpeedMachine")
        // Enable lightweight migration so schema additions (new attributes with defaults)
        // are automatically handled for existing installs.
        // IMPORTANT: modify the existing description rather than replacing it — creating a
        // new NSPersistentStoreDescription() without a URL causes Core Data to lose the
        // SQLite file location and fall back to an in-memory store (all data lost on relaunch).
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        // Load or create user progress
        userProgress = Self.loadUserProgress(context: container.viewContext)
        combineHighScore = Int(userProgress.combineHighScore)
    }

    // MARK: - User Progress

    private static func loadUserProgress(context: NSManagedObjectContext) -> UserProgressData {
        let request: NSFetchRequest<UserProgressData> = UserProgressData.fetchRequest()

        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            } else {
                // Create new
                let newProgress = UserProgressData(context: context)
                newProgress.currentDay = 1
                newProgress.currentPhase = 1
                newProgress.unlockedZones = [1]
                newProgress.combineHighScore = 0
                newProgress.totalPutts = 0
                newProgress.createdAt = Date()
                newProgress.updatedAt = Date()

                try context.save()
                return newProgress
            }
        } catch {
            print("Failed to load user progress: \(error)")
            let newProgress = UserProgressData(context: context)
            newProgress.currentDay = 1
            newProgress.currentPhase = 1
            return newProgress
        }
    }

    func updateProgress(currentTrack: Int, phase: Int) {
        userProgress.currentDay = Int16(currentTrack)
        userProgress.currentPhase = Int16(phase)
        userProgress.updatedAt = Date()
        saveContext()
    }

    func unlockZone(_ zone: Int) {
        var zones = userProgress.unlockedZones ?? []
        if !zones.contains(Int16(zone)) {
            zones.append(Int16(zone))
            userProgress.unlockedZones = zones
            saveContext()
        }
    }

    func updateCombineHighScore(_ score: Int) {
        if score > combineHighScore {
            combineHighScore = score
            userProgress.combineHighScore = Int16(score)
            userProgress.updatedAt = Date()
            saveContext()
        }
    }

    // MARK: - Gate Test Tracking

    private let passedGateTestsKey = "passedGateTests"

    func getPassedGateTests() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: passedGateTestsKey) ?? []
        return Set(array)
    }

    func recordGateTestPassed(gateId: String) {
        var passed = getPassedGateTests()
        passed.insert(gateId)
        UserDefaults.standard.set(Array(passed), forKey: passedGateTestsKey)
    }

    func hasPassedGateTest(gateId: String) -> Bool {
        return getPassedGateTests().contains(gateId)
    }

    // MARK: - Day Completion

    func markTrackComplete(trackNumber: Int, accuracy: Float, totalPutts: Int, onTargetPutts: Int) {
        let completion = DayCompletionData(context: container.viewContext)
        completion.dayNumber = Int16(trackNumber)
        completion.completedAt = Date()
        completion.overallAccuracy = accuracy
        completion.totalPutts = Int16(totalPutts)
        completion.onTargetPutts = Int16(onTargetPutts)

        saveContext()
    }

    func isTrackCompleted(_ trackNumber: Int) -> Bool {
        let request: NSFetchRequest<DayCompletionData> = DayCompletionData.fetchRequest()
        request.predicate = NSPredicate(format: "dayNumber == %d", trackNumber)

        do {
            let results = try container.viewContext.fetch(request)
            return !results.isEmpty
        } catch {
            return false
        }
    }

    func getTrackCompletion(_ trackNumber: Int) -> DayCompletionData? {
        let request: NSFetchRequest<DayCompletionData> = DayCompletionData.fetchRequest()
        request.predicate = NSPredicate(format: "dayNumber == %d", trackNumber)

        do {
            let results = try container.viewContext.fetch(request)
            return results.first
        } catch {
            return nil
        }
    }

    // MARK: - Session Management

    func createSession(trackNumber: Int, blockId: String, targetPutts: Int) -> SessionData {
        let session = SessionData(context: container.viewContext)
        session.id = UUID()
        session.dayNumber = Int16(trackNumber)
        session.blockId = blockId
        session.startedAt = Date()
        session.targetPutts = Int16(targetPutts)
        session.completedPutts = 0
        session.onTargetPutts = 0
        session.isComplete = false

        saveContext()
        return session
    }

    func updateSession(_ session: SessionData, completedPutts: Int, onTargetPutts: Int, isComplete: Bool) {
        session.completedPutts = Int16(completedPutts)
        session.onTargetPutts = Int16(onTargetPutts)
        session.isComplete = isComplete

        if isComplete {
            session.completedAt = Date()
        }

        saveContext()
    }

    func recordPutt(session: SessionData, targetSpeed: Float, actualSpeed: Float, tolerance: Float, isOnTarget: Bool) {
        let putt = PuttRecordData(context: container.viewContext)
        putt.id = UUID()
        putt.sessionId = session.id
        putt.timestamp = Date()
        putt.targetSpeed = targetSpeed
        putt.actualSpeed = actualSpeed
        putt.tolerance = tolerance
        putt.isOnTarget = isOnTarget
        putt.difference = abs(actualSpeed - targetSpeed)

        userProgress.totalPutts += 1
        saveContext()
    }

    // MARK: - Combine Game

    func createCombineGame() -> CombineGameData {
        let game = CombineGameData(context: container.viewContext)
        game.id = UUID()
        game.playedAt = Date()
        game.totalScore = 0
        game.isComplete = false

        saveContext()
        return game
    }

    func recordCombineShot(game: CombineGameData, shotNumber: Int, targetSpeed: Int, actualSpeed: Float, points: Int, accuracy: String) {
        let shot = CombineShotData(context: container.viewContext)
        shot.id = UUID()
        shot.gameId = game.id
        shot.shotNumber = Int16(shotNumber)
        shot.targetSpeed = Int16(targetSpeed)
        shot.actualSpeed = actualSpeed
        shot.points = Int16(points)
        shot.accuracy = accuracy

        saveContext()
    }

    func completeCombineGame(_ game: CombineGameData, finalScore: Int) {
        game.isComplete = true
        game.totalScore = Int16(finalScore)

        updateCombineHighScore(finalScore)
        saveContext()
    }

    // MARK: - Stats

    func getRecentSessions(limit: Int = 10) -> [SessionData] {
        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionData.startedAt, ascending: false)]
        request.fetchLimit = limit

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }

    func getAllCompletedTracks() -> [DayCompletionData] {
        let request: NSFetchRequest<DayCompletionData> = DayCompletionData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DayCompletionData.completedAt, ascending: true)]

        do {
            return try container.viewContext.fetch(request)
        } catch {
            return []
        }
    }

    func getCompletedBlockCount(trackNumber: Int, blockIds: [String]) -> Int {
        guard !blockIds.isEmpty else { return 0 }

        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.predicate = NSPredicate(
            format: "dayNumber == %d AND isComplete == YES AND blockId IN %@",
            trackNumber,
            blockIds
        )

        do {
            return try container.viewContext.count(for: request)
        } catch {
            return 0
        }
    }

    func getSessionsForTrack(_ trackNumber: Int) -> [SessionData] {
        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.predicate = NSPredicate(format: "dayNumber == %d AND isComplete == YES", trackNumber)

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch sessions for track \(trackNumber): \(error)")
            return []
        }
    }

    func getPuttsForSessionIds(_ sessionIds: [UUID]) -> [PuttRecordData] {
        guard !sessionIds.isEmpty else { return [] }
        let request: NSFetchRequest<PuttRecordData> = PuttRecordData.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId IN %@", sessionIds)

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch putts for session IDs: \(error)")
            return []
        }
    }

    /// Returns the practiceSeconds recorded in DailySnapshotData for today's calendar date.
    /// Does NOT include the currently-running session (that's tracked separately in TrainingViewModel).
    func getTodayPracticeSeconds() -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let request: NSFetchRequest<DailySnapshotData> = DailySnapshotData.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", today as NSDate)
        request.fetchLimit = 1

        do {
            let results = try container.viewContext.fetch(request)
            return results.first?.practiceSeconds ?? 0
        } catch {
            return 0
        }
    }

    func isBlockCompleted(trackNumber: Int, blockId: String) -> Bool {
        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.predicate = NSPredicate(
            format: "dayNumber == %d AND isComplete == YES AND blockId == %@",
            trackNumber,
            blockId
        )
        request.fetchLimit = 1

        do {
            let results = try container.viewContext.fetch(request)
            return !results.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Block Attempt Telemetry (Phase 1)

    /// Returns the number of non-override failed attempts for a block+day (Phase 4).
    /// Used by MasteryService.evaluateBlock() to determine hard-gate retry eligibility.
    func getFailedAttemptCount(trackNumber: Int, blockId: String) -> Int {
        let request: NSFetchRequest<BlockAttemptData> = BlockAttemptData.fetchRequest()
        request.predicate = NSPredicate(
            format: "dayNumber == %d AND blockId == %@ AND passedThreshold == NO AND passedWithOverride == NO",
            trackNumber, blockId
        )
        return (try? container.viewContext.count(for: request)) ?? 0
    }

    /// Record a block attempt for threshold-validation telemetry.
    /// passedWithOverride is always false in Phase 1 (no enforcement yet).
    func createBlockAttempt(trackNumber: Int, blockId: String, zoneAccuracy: Float, passedThreshold: Bool, passedWithOverride: Bool = false) {
        // Count prior attempts for this block+day to get attempt number
        let request: NSFetchRequest<BlockAttemptData> = BlockAttemptData.fetchRequest()
        request.predicate = NSPredicate(format: "dayNumber == %d AND blockId == %@", trackNumber, blockId)
        let priorCount = (try? container.viewContext.count(for: request)) ?? 0

        let attempt = BlockAttemptData(context: container.viewContext)
        attempt.id = UUID()
        attempt.dayNumber = Int16(trackNumber)
        attempt.blockId = blockId
        attempt.attemptNumber = Int16(priorCount + 1)
        attempt.zoneAccuracy = zoneAccuracy
        attempt.passedThreshold = passedThreshold
        attempt.passedWithOverride = passedWithOverride
        attempt.attemptedAt = Date()

        saveContext()
    }

    // MARK: - Core Data

    private func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}

// MARK: - Core Data Managed Object Subclasses

@objc(UserProgressData)
public class UserProgressData: NSManagedObject {
    @NSManaged public var currentDay: Int16
    @NSManaged public var currentPhase: Int16
    @NSManaged public var unlockedZones: [Int16]?
    @NSManaged public var combineHighScore: Int16
    @NSManaged public var totalPutts: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension UserProgressData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProgressData> {
        return NSFetchRequest<UserProgressData>(entityName: "UserProgressData")
    }
}

@objc(DayCompletionData)
public class DayCompletionData: NSManagedObject {
    @NSManaged public var dayNumber: Int16
    @NSManaged public var completedAt: Date?
    @NSManaged public var overallAccuracy: Float
    @NSManaged public var totalPutts: Int16
    @NSManaged public var onTargetPutts: Int16
}

extension DayCompletionData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DayCompletionData> {
        return NSFetchRequest<DayCompletionData>(entityName: "DayCompletionData")
    }
}

@objc(SessionData)
public class SessionData: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var dayNumber: Int16
    @NSManaged public var blockId: String?
    @NSManaged public var startedAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var targetPutts: Int16
    @NSManaged public var completedPutts: Int16
    @NSManaged public var onTargetPutts: Int16
    @NSManaged public var isComplete: Bool
}

extension SessionData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SessionData> {
        return NSFetchRequest<SessionData>(entityName: "SessionData")
    }
}

@objc(PuttRecordData)
public class PuttRecordData: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var sessionId: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var targetSpeed: Float
    @NSManaged public var actualSpeed: Float
    @NSManaged public var tolerance: Float
    @NSManaged public var isOnTarget: Bool
    @NSManaged public var difference: Float
}

extension PuttRecordData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PuttRecordData> {
        return NSFetchRequest<PuttRecordData>(entityName: "PuttRecordData")
    }
}

@objc(CombineGameData)
public class CombineGameData: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var playedAt: Date?
    @NSManaged public var totalScore: Int16
    @NSManaged public var isComplete: Bool
}

extension CombineGameData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CombineGameData> {
        return NSFetchRequest<CombineGameData>(entityName: "CombineGameData")
    }
}

@objc(CombineShotData)
public class CombineShotData: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var gameId: UUID?
    @NSManaged public var shotNumber: Int16
    @NSManaged public var targetSpeed: Int16
    @NSManaged public var actualSpeed: Float
    @NSManaged public var points: Int16
    @NSManaged public var accuracy: String?
}

extension CombineShotData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CombineShotData> {
        return NSFetchRequest<CombineShotData>(entityName: "CombineShotData")
    }
}

// MARK: - Speed Profile (per-speed running stats)

@objc(SpeedProfileData)
public class SpeedProfileData: NSManagedObject {
    @NSManaged public var targetSpeed: Int16
    @NSManaged public var totalPutts: Int32
    @NSManaged public var onTargetPutts: Int32
    @NSManaged public var totalDeviation: Double
    @NSManaged public var totalSignedDeviation: Double
    @NSManaged public var sumSquaredDeviation: Double
    @NSManaged public var sumActualSpeed: Double
    @NSManaged public var bestStreak: Int16
    @NSManaged public var currentStreak: Int16
    @NSManaged public var lastPracticedAt: Date?
    // Phase 1 mastery telemetry — rolling last-20-putt window + manual tier override
    @NSManaged public var recentPutts: Int16
    @NSManaged public var recentOnTargetPutts: Int16
    /// -1 = no override (computed from data); 0–4 = manually locked tier
    @NSManaged public var tierOverride: Int16

    // Computed properties
    var accuracy: Double {
        guard totalPutts > 0 else { return 0 }
        return Double(onTargetPutts) / Double(totalPutts) * 100
    }

    var averageDeviation: Double {
        guard totalPutts > 0 else { return 0 }
        return totalDeviation / Double(totalPutts)
    }

    var averageSignedDeviation: Double {
        guard totalPutts > 0 else { return 0 }
        return totalSignedDeviation / Double(totalPutts)
    }

    var averageActualSpeed: Double {
        guard totalPutts > 0 else { return 0 }
        return sumActualSpeed / Double(totalPutts)
    }

    var standardDeviation: Double {
        guard totalPutts > 1 else { return 0 }
        let mean = sumActualSpeed / Double(totalPutts)
        let variance = (sumSquaredDeviation / Double(totalPutts)) - (mean * mean)
        return variance > 0 ? sqrt(variance) : 0
    }

    /// Tells user whether they tend to miss fast or slow
    var tendencyDescription: String {
        let signed = averageSignedDeviation
        if abs(signed) < 0.1 { return "On target" }
        return signed > 0 ? String(format: "+%.1f MPH fast", signed) : String(format: "%.1f MPH slow", signed)
    }
}

extension SpeedProfileData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SpeedProfileData> {
        return NSFetchRequest<SpeedProfileData>(entityName: "SpeedProfileData")
    }
}

// MARK: - Daily Snapshot (per-calendar-day aggregate)

@objc(DailySnapshotData)
public class DailySnapshotData: NSManagedObject {
    @NSManaged public var date: Date?
    @NSManaged public var totalPutts: Int32
    @NSManaged public var onTargetPutts: Int32
    @NSManaged public var totalDeviation: Double
    @NSManaged public var sumSquaredDeviation: Double
    @NSManaged public var practiceSeconds: Double

    var accuracy: Double {
        guard totalPutts > 0 else { return 0 }
        return Double(onTargetPutts) / Double(totalPutts) * 100
    }

    var averageDeviation: Double {
        guard totalPutts > 0 else { return 0 }
        return totalDeviation / Double(totalPutts)
    }

    var practiceMinutes: Double {
        return practiceSeconds / 60.0
    }
}

extension DailySnapshotData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailySnapshotData> {
        return NSFetchRequest<DailySnapshotData>(entityName: "DailySnapshotData")
    }
}

// MARK: - Block Attempt Telemetry (Phase 1)

@objc(BlockAttemptData)
public class BlockAttemptData: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var dayNumber: Int16
    @NSManaged public var blockId: String?
    @NSManaged public var attemptNumber: Int16
    @NSManaged public var zoneAccuracy: Float
    @NSManaged public var passedThreshold: Bool
    @NSManaged public var passedWithOverride: Bool
    @NSManaged public var attemptedAt: Date?
}

extension BlockAttemptData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BlockAttemptData> {
        return NSFetchRequest<BlockAttemptData>(entityName: "BlockAttemptData")
    }
}
