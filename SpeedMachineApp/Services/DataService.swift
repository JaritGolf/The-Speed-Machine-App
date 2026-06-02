//
//  DataService.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import CoreData
import Combine
import CloudKit

enum CloudKitSyncStatus: Equatable {
    case idle, syncing, synced, error
}

class DataService: ObservableObject {
    static let shared = DataService()

    // NSPersistentContainer (base class) so the fallback path can use a plain local store.
    let container: NSPersistentContainer

    @Published var userProgress: UserProgressData
    @Published var combineHighScore: Int = 0
    @Published var cloudKitSyncStatus: CloudKitSyncStatus = .idle
    @Published var cloudKitAccountStatus: String = "Checking…"

    private init() {
        // Attempt 1: CloudKit-backed store.
        let cloudContainer = NSPersistentCloudKitContainer(name: "SpeedMachine")
        if let description = cloudContainer.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.Jarit-Golf.SpeedMachineApp"
            )
            description.setOption(true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        var cloudKitLoadError: Error?
        cloudContainer.loadPersistentStores { _, error in
            if let error {
                let nsErr = error as NSError
                print("CloudKit store failed: [\(nsErr.domain) \(nsErr.code)] \(nsErr.localizedDescription)")
                if let under = nsErr.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("  Underlying: [\(under.domain) \(under.code)] \(under.localizedDescription)")
                }
                cloudKitLoadError = error
            }
        }

        if cloudKitLoadError == nil {
            print("CloudKit store loaded successfully.")
            container = cloudContainer
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.automaticallyMergesChangesFromParent = true

            userProgress = Self.loadUserProgress(context: container.viewContext)
            combineHighScore = Int(userProgress.combineHighScore)

            migrateGateTestsToICloudKV()
            restoreProgressFromKVIfNeeded()
            restoreStatsFromKVIfNeeded()

            NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: cloudContainer,
                queue: .main
            ) { [weak self] notification in
                self?.handleCloudKitEvent(notification)
            }

            checkCloudKitAccountStatus()
        } else {
            // Attempt 2: plain local SQLite store (data won't sync but app stays functional).
            print("Falling back to local-only Core Data store.")
            let localContainer = NSPersistentContainer(name: "SpeedMachine")
            if let description = localContainer.persistentStoreDescriptions.first {
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
            localContainer.loadPersistentStores { _, error in
                if let error {
                    print("Local fallback failed: \(error.localizedDescription)")
                }
            }
            container = localContainer
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.automaticallyMergesChangesFromParent = true

            userProgress = Self.loadUserProgress(context: container.viewContext)
            combineHighScore = Int(userProgress.combineHighScore)

            migrateGateTestsToICloudKV()
            restoreProgressFromKVIfNeeded()
            restoreStatsFromKVIfNeeded()
            checkCloudKitAccountStatus()
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        let typeLabel = event.type == .setup ? "setup" : event.type == .import ? "import" : "export"
        print("CloudKit event: \(typeLabel) ended=\(event.endDate != nil) succeeded=\(event.succeeded)")
        if event.endDate == nil {
            cloudKitSyncStatus = .syncing
        } else if event.succeeded {
            cloudKitSyncStatus = .synced
        } else {
            cloudKitSyncStatus = .error
        }
    }

    func checkCloudKitAccountStatus() {
        CKContainer(identifier: "iCloud.Jarit-Golf.SpeedMachineApp").accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.cloudKitAccountStatus = "iCloud Available ✓"
                case .noAccount:
                    self?.cloudKitAccountStatus = "No iCloud Account"
                case .restricted:
                    self?.cloudKitAccountStatus = "iCloud Restricted"
                case .temporarilyUnavailable:
                    self?.cloudKitAccountStatus = "Temporarily Unavailable"
                case .couldNotDetermine:
                    self?.cloudKitAccountStatus = "Error: \(error?.localizedDescription ?? "unknown")"
                @unknown default:
                    self?.cloudKitAccountStatus = "Unknown"
                }
                print("CloudKit account status: \(self?.cloudKitAccountStatus ?? "")")
            }
        }
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

    func updateProgress(currentDay: Int, phase: Int) {
        userProgress.currentDay = Int16(currentDay)
        userProgress.currentPhase = Int16(phase)
        userProgress.updatedAt = Date()
        saveContext()
        // Mirror to iCloud KV so track position survives reinstalls even without CloudKit.
        NSUbiquitousKeyValueStore.default.set(Int64(currentDay), forKey: kvCurrentDayKey)
        NSUbiquitousKeyValueStore.default.synchronize()
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
        let array = NSUbiquitousKeyValueStore.default.array(forKey: passedGateTestsKey) as? [String] ?? []
        return Set(array)
    }

    func recordGateTestPassed(gateId: String) {
        var passed = getPassedGateTests()
        passed.insert(gateId)
        NSUbiquitousKeyValueStore.default.set(Array(passed), forKey: passedGateTestsKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func hasPassedGateTest(gateId: String) -> Bool {
        return getPassedGateTests().contains(gateId)
    }

    private func migrateGateTestsToICloudKV() {
        let migrationDoneKey = "gateTestsKVMigrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }
        let localArray = UserDefaults.standard.stringArray(forKey: passedGateTestsKey) ?? []
        if !localArray.isEmpty {
            let cloudArray = NSUbiquitousKeyValueStore.default.array(forKey: passedGateTestsKey) as? [String] ?? []
            let merged = Array(Set(localArray).union(Set(cloudArray)))
            NSUbiquitousKeyValueStore.default.set(merged, forKey: passedGateTestsKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }

    // MARK: - iCloud KV Progress Backup
    // Mirrors critical progress to NSUbiquitousKeyValueStore so it survives reinstalls
    // even when NSPersistentCloudKitContainer is unavailable.

    private let kvCurrentDayKey = "userCurrentDay"
    private let kvCompletedDaysKey = "completedDayNumbers"

    private func restoreProgressFromKVIfNeeded() {
        // Only restore on a fresh install (no progress recorded yet).
        guard userProgress.currentDay <= 1 else { return }
        let savedDay = NSUbiquitousKeyValueStore.default.longLong(forKey: kvCurrentDayKey)
        guard savedDay > 1 else { return }
        print("Restoring track \(savedDay) from iCloud KV backup.")
        userProgress.currentDay = Int16(savedDay)
        userProgress.updatedAt = Date()
        saveContext()
    }

    private let kvSpeedProfileKey   = "speedProfileSnapshot"
    private let kvDailySnapshotsKey = "dailySnapshotsSnapshot"

    func restoreStatsFromKVIfNeeded() {
        // Only restore on a fresh install (no practiced speed profiles exist yet).
        let profileRequest: NSFetchRequest<SpeedProfileData> = SpeedProfileData.fetchRequest()
        profileRequest.predicate = NSPredicate(format: "totalPutts > 0")
        profileRequest.fetchLimit = 1
        let hasExistingStats = (try? container.viewContext.count(for: profileRequest)) ?? 0
        guard hasExistingStats == 0 else { return }

        let kv = NSUbiquitousKeyValueStore.default
        var restored = false

        if let json = kv.string(forKey: kvSpeedProfileKey),
           let data = json.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in array {
                guard let speed = dict["targetSpeed"] as? Int, speed >= 3, speed <= 20 else { continue }
                let profile = SpeedProfileData(context: container.viewContext)
                profile.targetSpeed          = Int16(speed)
                profile.totalPutts           = Int32(dict["totalPutts"]           as? Int ?? 0)
                profile.onTargetPutts        = Int32(dict["onTargetPutts"]        as? Int ?? 0)
                profile.totalDeviation       = dict["totalDeviation"]       as? Double ?? 0
                profile.totalSignedDeviation = dict["totalSignedDeviation"]  as? Double ?? 0
                profile.sumSquaredDeviation  = dict["sumSquaredDeviation"]   as? Double ?? 0
                profile.sumActualSpeed       = dict["sumActualSpeed"]        as? Double ?? 0
                profile.bestStreak           = Int16(dict["bestStreak"]      as? Int ?? 0)
                profile.currentStreak        = Int16(dict["currentStreak"]   as? Int ?? 0)
                profile.recentPutts          = Int16(dict["recentPutts"]     as? Int ?? 0)
                profile.recentOnTargetPutts  = Int16(dict["recentOnTargetPutts"] as? Int ?? 0)
                profile.tierOverride         = Int16(dict["tierOverride"]    as? Int ?? -1)
                if let ts = dict["lastPracticedAt"] as? Double {
                    profile.lastPracticedAt = Date(timeIntervalSince1970: ts)
                }
            }
            print("Restored \(array.count) speed profiles from iCloud KV backup.")
            restored = true
        }

        if let json = kv.string(forKey: kvDailySnapshotsKey),
           let data = json.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in array {
                guard let ts = dict["date"] as? Double else { continue }
                let snapshot = DailySnapshotData(context: container.viewContext)
                snapshot.date                = Date(timeIntervalSince1970: ts)
                snapshot.totalPutts          = Int32(dict["totalPutts"]    as? Int ?? 0)
                snapshot.onTargetPutts       = Int32(dict["onTargetPutts"] as? Int ?? 0)
                snapshot.totalDeviation      = dict["totalDeviation"]    as? Double ?? 0
                snapshot.sumSquaredDeviation = dict["sumSquaredDeviation"] as? Double ?? 0
                snapshot.practiceSeconds     = dict["practiceSeconds"]   as? Double ?? 0
            }
            print("Restored \(array.count) daily snapshots from iCloud KV backup.")
            restored = true
        }

        if restored {
            try? container.viewContext.save()
        }
    }

    // MARK: - Day Completion

    func markDayComplete(dayNumber: Int, accuracy: Float, totalPutts: Int, onTargetPutts: Int) {
        let completion = DayCompletionData(context: container.viewContext)
        completion.dayNumber = Int16(dayNumber)
        completion.completedAt = Date()
        completion.overallAccuracy = accuracy
        completion.totalPutts = Int16(totalPutts)
        completion.onTargetPutts = Int16(onTargetPutts)

        saveContext()
        // Mirror completed day list to KV backup.
        let allCompleted = getAllCompletedDays().map { Int($0.dayNumber) }
        NSUbiquitousKeyValueStore.default.set(allCompleted, forKey: kvCompletedDaysKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func isDayCompleted(_ dayNumber: Int) -> Bool {
        let request: NSFetchRequest<DayCompletionData> = DayCompletionData.fetchRequest()
        request.predicate = NSPredicate(format: "dayNumber == %d", dayNumber)

        do {
            let results = try container.viewContext.fetch(request)
            return !results.isEmpty
        } catch {
            return false
        }
    }

    func getDayCompletion(_ dayNumber: Int) -> DayCompletionData? {
        let request: NSFetchRequest<DayCompletionData> = DayCompletionData.fetchRequest()
        request.predicate = NSPredicate(format: "dayNumber == %d", dayNumber)

        do {
            let results = try container.viewContext.fetch(request)
            return results.first
        } catch {
            return nil
        }
    }

    // MARK: - Session Management

    func createSession(dayNumber: Int, blockId: String, targetPutts: Int) -> SessionData {
        let session = SessionData(context: container.viewContext)
        session.id = UUID()
        session.dayNumber = Int16(dayNumber)
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

    func getAllCompletedDays() -> [DayCompletionData] {
        let request: NSFetchRequest<DayCompletionData> = DayCompletionData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DayCompletionData.completedAt, ascending: true)]

        do {
            return try container.viewContext.fetch(request)
        } catch {
            return []
        }
    }

    func getCompletedBlockCount(dayNumber: Int, blockIds: [String]) -> Int {
        guard !blockIds.isEmpty else { return 0 }

        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.predicate = NSPredicate(
            format: "dayNumber == %d AND isComplete == YES AND blockId IN %@",
            dayNumber,
            blockIds
        )

        do {
            return try container.viewContext.count(for: request)
        } catch {
            return 0
        }
    }

    func getSessionsForDay(_ dayNumber: Int) -> [SessionData] {
        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.predicate = NSPredicate(format: "dayNumber == %d AND isComplete == YES", dayNumber)

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch sessions for day \(dayNumber): \(error)")
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

    func isBlockCompleted(dayNumber: Int, blockId: String) -> Bool {
        let request: NSFetchRequest<SessionData> = SessionData.fetchRequest()
        request.predicate = NSPredicate(
            format: "dayNumber == %d AND isComplete == YES AND blockId == %@",
            dayNumber,
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
    @NSManaged public var recentPutts: Int16
    @NSManaged public var recentOnTargetPutts: Int16
    @NSManaged public var tierOverride: Int16
    @NSManaged public var lastPracticedAt: Date?

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
