//
//  TrainingProgram.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import Combine

// MARK: - Training Program Structure

struct TrainingProgram: Codable {
    let program: ProgramInfo
    let speedZones: [SpeedZoneInfo]
    let phases: [Phase]
    let gateTests: [GateTest]
    let days: [TrainingDay]
    let scientificFoundation: [ScientificPrinciple]?
    let supplementaryMaterials: SupplementaryMaterials?
}

struct SupplementaryMaterials: Codable {
    let videos: [VideoMaterial]?
    let graphics: [GraphicMaterial]?
}

struct VideoMaterial: Codable, Identifiable {
    let id: Int
    let title: String
    let duration: String
    let topics: [String]
}

struct GraphicMaterial: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
}

struct ProgramInfo: Codable {
    let name: String
    let version: String
    let author: String
    let website: String
    let totalDays: Int
    let dailyDuration: String
    let puttsPerMinute: Int
    let deviceSpecs: DeviceSpecs
}

struct DeviceSpecs: Codable {
    let openingWidth: String
    let ballDistance: String
    let minSpace: String
}

struct SpeedZoneInfo: Codable {
    let zone: Int
    let name: String
    let speedRange: String
    let minSpeed: Int
    let maxSpeed: Int
    let tolerance: Float
    let toleranceDisplay: String
    let example: String
    let unlockDay: Int
    let description: String
}

struct Phase: Codable, Identifiable {
    var id: Int { phase }
    let phase: Int
    let name: String
    let days: String
    let startDay: Int
    let endDay: Int
    let speedRange: String
    let focus: String
    let goals: [String]
}

struct GateTest: Codable, Identifiable {
    var id: String { gateId }
    let gateId: String
    let name: String
    let day: Int
    let unlocksZone: Int
    let unlocksSpeeds: [Int]
    let protocol_: [ProtocolStep]
    let totalPutts: Int
    let passRequirements: PassRequirements

    enum CodingKeys: String, CodingKey {
        case gateId = "id"
        case name, day, unlocksZone, unlocksSpeeds
        case protocol_ = "protocol"
        case totalPutts, passRequirements
    }
}

struct ProtocolStep: Codable {
    let speed: Int
    let putts: Int
}

struct PassRequirements: Codable {
    let zoneAccuracy: AccuracyRequirement
}

struct AccuracyRequirement: Codable {
    let minimum: Int
    let percentage: Int
}

struct TrainingDay: Codable, Identifiable {
    var id: Int { day }
    let day: Int
    let phase: Int
    let title: String
    let duration: String
    let targetPutts: Int
    let availableSpeeds: [Int]
    let speedRange: String
    let objective: String
    let science: ScienceInfo?
    let blocks: [TrainingBlock]
    let successMetrics: [SuccessMetric]
    let coachingNotes: String?
    let warnings: [Warning]
}

struct ScienceInfo: Codable {
    let principle: String
    let explanation: String
    let citation: String
}

struct SuccessMetric: Codable {
    let metric: String
    let target: String
    let note: String?
}

struct Warning: Codable {
    let type: String
    let message: String
}

struct TrainingBlock: Codable, Identifiable {
    var id: String { blockId }
    let blockId: String
    let name: String
    let duration: String
    let putts: Int?
    let targetSpeed: Int?
    let type: BlockType
    let description: String?
    let sequence: [Int]?
    let protocol_: [ProtocolStep]?
    let acceptRange: AcceptRange?
    let focus: [String]?
    let rounds: Int?
    let isOfficial: Bool?
    let gateId: String?
    let passRequirements: PassRequirements?
    let onPass: String?
    let onFail: String?
    let challengeType: String?
    let consecutiveRequired: Int?
    let requirements: [String]?
    let lives: Int?
    let startSpeed: Int?
    let endSpeed: Int?
    let speedRange: SpeedRangeBlock?
    let isPhaseAssessment: Bool?
    let isFinalAssessment: Bool?
    let allowSpeedChange: Bool?
    let emergencyProtocol: EmergencyProtocol?
    let entryRequirement: EntryRequirement?
    let maxAttempts: Int?
    let safetyChecklist: [String]?
    /// Signals that this block's speed(s) should be chosen at runtime from SpeedProfile data.
    /// Values: "recovery" (highest-accuracy confidence builder),
    ///         "challenge" (optimal challenge point ~70% accuracy),
    ///         "predictive" (full-weighted interleave across pool).
    let adaptiveMode: String?
    /// Eligible speed pool for adaptive selection. Engine picks from these speeds only.
    let adaptivePool: [Int]?
    /// When true, the adaptive engine drills ONE speed exclusively (single-speed focus) instead of
    /// featuring the relevant speeds more often across the full pool. nil/false = full-pool variety.
    let adaptiveSingleSpeed: Bool?
    /// Per-block pass threshold override (0.0–1.0). nil = use phase floor.
    let blockPassThreshold: Float?
    /// true = block is not pass-gated (warmups, recovery, free practice).
    let skipGating: Bool?

    enum CodingKeys: String, CodingKey {
        case blockId = "id"
        case name, duration, putts, targetSpeed, type, description
        case sequence
        case protocol_ = "protocol"
        case acceptRange, focus, rounds, isOfficial, gateId
        case passRequirements, onPass, onFail
        case challengeType, consecutiveRequired, requirements
        case lives, startSpeed, endSpeed, speedRange
        case isPhaseAssessment, isFinalAssessment, allowSpeedChange
        case emergencyProtocol, entryRequirement, maxAttempts, safetyChecklist
        case adaptiveMode, adaptivePool, adaptiveSingleSpeed
        case blockPassThreshold, skipGating
    }
}

enum BlockType: String, Codable {
    case exploration
    case blocked
    case alternating
    case sequence
    case warmup
    case predictive
    case gateTest
    case random
    case pressure
    case recovery
    case challenge
    case assessment
    case reactive
    case combine
    case celebration
}

// MARK: - Block Session Type (for Day 7 and beyond)

enum BlockSessionType: String, Codable {
    case standard           // Standard: fixed speed, target putts
    case warmup             // Warm-up: random speeds, fixed putt count
    case makeInRow          // Make N in a row: fixed speed, requires N consecutive hits
    case eliminationLadder  // Ladder: speeds from block.startSpeed→endSpeed
    case recovery           // Recovery: fixed speed, fixed putt count

    init(from blockType: BlockType, challengeType: String? = nil) {
        if blockType == .warmup {
            self = .warmup
        } else if blockType == .recovery {
            self = .recovery
        } else if blockType == .pressure && challengeType == "consecutive" {
            self = .makeInRow
        } else if blockType == .pressure && challengeType == "ladder" {
            self = .eliminationLadder
        } else {
            self = .standard
        }
    }
}

struct AcceptRange: Codable {
    let min: Float
    let max: Float
}

struct SpeedRangeBlock: Codable {
    let min: Int
    let max: Int
}

struct EmergencyProtocol: Codable {
    let trigger: String
    let action: String
}

struct EntryRequirement: Codable {
    let metric: String
    let target: Int
}

struct ScientificPrinciple: Codable, Identifiable {
    let id: Int
    let principle: String
    let explanation: String
    let application: String
    let citation: Citation
}

struct Citation: Codable {
    let authors: String
    let year: Int
    let title: String
    let journal: String?
    let volume: String?
    let pages: String?
    let publisher: String?
    let edition: String?
}

// MARK: - Training Program Loader

class TrainingProgramLoader {
    static let shared = TrainingProgramLoader()

    private(set) var program: TrainingProgram?

    private init() {
        loadProgram()
        // Check the admin backend for a newer published program. Non-blocking;
        // the bundled program above is used until/unless this succeeds.
        Task { await NetworkService.shared.fetchProgramIfNeeded() }
    }

    private func loadProgram() {
        guard let url = Bundle.main.url(forResource: "speed-machine-training-program", withExtension: "json") else {
            print("Error: Training program JSON file not found")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            // Accept either schema: the bundle may be the older "days" JSON or the
            // newer "tracks" JSON published from admin. remapTracksSchema is a no-op
            // on "days" data and renames "tracks" data to match the model.
            let remapped = try Self.remapTracksSchema(data)
            let decoder = JSONDecoder()
            program = try decoder.decode(TrainingProgram.self, from: remapped)
            print("Training program loaded successfully with \(program?.days.count ?? 0) days")
            if let loaded = program { validateProgram(loaded) }
        } catch let DecodingError.dataCorrupted(context) {
            print("Data corrupted: \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        } catch let DecodingError.keyNotFound(key, context) {
            print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        } catch let DecodingError.valueNotFound(value, context) {
            print("Value '\(value)' not found: \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        } catch let DecodingError.typeMismatch(type, context) {
            print("Type '\(type)' mismatch: \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        } catch {
            print("Error loading training program: \(error)")
        }
    }

    /// Decode and apply a program downloaded from the admin backend. The admin
    /// publishes a "tracks" schema; this app's model uses the older "days" schema,
    /// so the JSON keys are remapped before decoding. On any failure the bundled
    /// program is left in place.
    func useRemoteProgram(_ data: Data) {
        do {
            let remapped = try Self.remapTracksSchema(data)
            let decoded = try JSONDecoder().decode(TrainingProgram.self, from: remapped)
            DispatchQueue.main.async {
                self.program = decoded
                self.validateProgram(decoded)
                print("🔄 Applied remote program: \(decoded.days.count) tracks")
            }
        } catch {
            print("🔄 Failed to decode remote program (keeping bundle): \(error)")
        }
    }

    /// Rename the admin "tracks" schema keys to the bundled "days" schema names
    /// (tracks→days, track→day, unlockTrack→unlockDay) and drop scientificFoundation,
    /// whose shape isn't decoded here. Unknown keys are ignored by the decoder.
    static func remapTracksSchema(_ data: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        if let tracks = root["tracks"] as? [[String: Any]] {
            root["days"] = tracks.map { tr -> [String: Any] in
                var t = tr
                if let v = t["track"] { t["day"] = v; t.removeValue(forKey: "track") }
                return t
            }
            root.removeValue(forKey: "tracks")
        }
        if let gates = root["gateTests"] as? [[String: Any]] {
            root["gateTests"] = gates.map { g -> [String: Any] in
                var x = g
                if let v = x["track"] { x["day"] = v; x.removeValue(forKey: "track") }
                return x
            }
        }
        if let zones = root["speedZones"] as? [[String: Any]] {
            root["speedZones"] = zones.map { z -> [String: Any] in
                var x = z
                if let v = x["unlockTrack"] { x["unlockDay"] = v; x.removeValue(forKey: "unlockTrack") }
                return x
            }
        }
        if let phases = root["phases"] as? [[String: Any]] {
            root["phases"] = phases.map { p -> [String: Any] in
                var x = p
                if let v = x["startTrack"] { x["startDay"] = v; x.removeValue(forKey: "startTrack") }
                if let v = x["endTrack"] { x["endDay"] = v; x.removeValue(forKey: "endTrack") }
                if let v = x["tracks"] { x["days"] = v; x.removeValue(forKey: "tracks") }
                return x
            }
        }
        root.removeValue(forKey: "scientificFoundation")
        return try JSONSerialization.data(withJSONObject: root)
    }

    func getDay(_ dayNumber: Int) -> TrainingDay? {
        return program?.days.first { $0.day == dayNumber }
    }

    func getGateTest(forDay dayNumber: Int) -> GateTest? {
        return program?.gateTests.first { $0.day == dayNumber }
    }

    func getGateTest(byId gateId: String) -> GateTest? {
        return program?.gateTests.first { $0.gateId == gateId }
    }

    func getPhase(_ phaseNumber: Int) -> Phase? {
        return program?.phases.first { $0.phase == phaseNumber }
    }

    func getSpeedZone(_ zoneNumber: Int) -> SpeedZoneInfo? {
        return program?.speedZones.first { $0.zone == zoneNumber }
    }

    func getToleranceForSpeed(_ speed: Int) -> Float {
        guard let zones = program?.speedZones else { return 0.5 }
        for zone in zones {
            if speed >= zone.minSpeed && speed <= zone.maxSpeed {
                return zone.tolerance
            }
        }
        return 0.5
    }

    func isGateTestDay(_ dayNumber: Int) -> Bool {
        return program?.gateTests.contains { $0.day == dayNumber } ?? false
    }

    func getBlocksForDay(_ dayNumber: Int) -> [TrainingBlock] {
        return getDay(dayNumber)?.blocks ?? []
    }

    func validateProgram(_ program: TrainingProgram) {
        for day in program.days {
            let t = day.day
            for block in day.blocks {
                let b = block.blockId
                if block.type == .pressure {
                    if block.challengeType == "ladder" {
                        if block.startSpeed == nil || block.endSpeed == nil {
                            print("⚠️ [TrainingProgram] Track \(t) Block \(b): pressure/ladder missing startSpeed or endSpeed")
                        } else if let s = block.startSpeed, let e = block.endSpeed, e <= s {
                            print("⚠️ [TrainingProgram] Track \(t) Block \(b): pressure/ladder endSpeed (\(e)) must be > startSpeed (\(s))")
                        }
                    } else if block.challengeType == "consecutive" && block.consecutiveRequired == nil {
                        print("⚠️ [TrainingProgram] Track \(t) Block \(b): pressure/consecutive missing consecutiveRequired")
                    } else if block.challengeType == "elimination" && block.lives == nil {
                        print("⚠️ [TrainingProgram] Track \(t) Block \(b): pressure/elimination missing lives")
                    }
                }
                if block.type == .gateTest {
                    if block.protocol_?.isEmpty ?? true {
                        print("⚠️ [TrainingProgram] Track \(t) Block \(b): gateTest has empty or missing protocol")
                    }
                    if block.isOfficial == true && block.passRequirements == nil {
                        print("⚠️ [TrainingProgram] Track \(t) Block \(b): official gateTest missing passRequirements")
                    }
                }
                if let ar = block.acceptRange, ar.min >= ar.max {
                    print("⚠️ [TrainingProgram] Track \(t) Block \(b): acceptRange.min (\(ar.min)) must be < acceptRange.max (\(ar.max))")
                }
            }
        }
    }
}

// MARK: - Session Progress Tracking

class SessionProgress: ObservableObject {
    @Published var currentPutt: Int = 0
    @Published var onTargetPutts: Int = 0
    @Published var inZonePutts: Int = 0
    @Published var puttRecords: [PuttResult] = []
    @Published var consecutiveSuccesses: Int = 0
    @Published var consecutiveTarget: Int = 0
    @Published var livesRemaining: Int = 3
    @Published var currentSequenceIndex: Int = 0
    @Published var pressureChallengeComplete: Bool = false

    // Ladder-specific tracking (Day 7 Block 7C)
    @Published var currentRung: Int = 0           // 0-4 (maps to speeds 3-7)
    @Published var ladderSpeeds: [Int] = []
    @Published var blockSessionType: BlockSessionType = .standard
    @Published var requiredConsecutive: Int = 0
    @Published var ladderCompleted: Bool = false  // true only after top rung hit in zone

    // Adaptive speed engine — generated at session start for eligible blocks
    @Published var adaptiveSequence: [Int]?

    let block: TrainingBlock
    let dayNumber: Int

    var currentTargetSpeed: Int {
        // Adaptive sequence takes priority when present (generated by AdaptiveSpeedEngine)
        if let adaptive = adaptiveSequence, !adaptive.isEmpty {
            let effectiveIndex = currentSequenceIndex % adaptive.count
            return adaptive[effectiveIndex]
        }

        // For blocks with sequences, return the current target from sequence
        if let sequence = block.sequence, !sequence.isEmpty {
            let effectiveIndex = currentSequenceIndex % sequence.count
            return sequence[effectiveIndex]
        }

        // For protocol-based blocks with rounds (gate tests, pressure, etc.)
        if let protocol_ = block.protocol_, !protocol_.isEmpty {
            // Calculate protocol size (total putts in one complete round)
            let protocolSize = protocol_.reduce(0) { $0 + $1.putts }

            // If there are rounds, we need to cycle through the protocol multiple times
            if let rounds = block.rounds, rounds > 1 {
                // Get position within the current round
                let positionInRound = currentPutt % protocolSize

                // Find which speed applies at this position
                var puttCount = 0
                for step in protocol_ {
                    puttCount += step.putts
                    if positionInRound < puttCount {
                        return step.speed
                    }
                }
                // Shouldn't reach here, but return last speed as fallback
                return protocol_.last?.speed ?? 0
            } else {
                // Single round protocol - original logic
                var puttCount = 0
                for step in protocol_ {
                    puttCount += step.putts
                    if currentPutt < puttCount {
                        return step.speed
                    }
                }
                // If we've completed all protocol steps, return the last speed
                return protocol_.last?.speed ?? 0
            }
        }

        // Default to block's explicit target speed
        if let targetSpeed = block.targetSpeed, targetSpeed > 0 {
            return targetSpeed
        }

        // Last resort: return 0 (should rarely happen with proper data)
        print("⚠️ Warning: No target speed found for block \(block.blockId)")
        return 0
    }

    init(block: TrainingBlock, dayNumber: Int) {
        self.block = block
        self.dayNumber = dayNumber
        self.consecutiveTarget = block.consecutiveRequired ?? 0
        self.livesRemaining = block.lives ?? 3

        // Initialize block session type and ladder state
        self.blockSessionType = BlockSessionType(from: block.type, challengeType: block.challengeType)
        self.requiredConsecutive = block.consecutiveRequired ?? 0

        // Initialize ladder speeds from admin-configured range
        if self.blockSessionType == .eliminationLadder {
            let start = block.startSpeed ?? 3
            let end = block.endSpeed.map { max($0, start + 1) } ?? max(start + 1, 7)
            self.ladderSpeeds = Array(start...end)
            self.currentRung = 0
        }
    }

    // MARK: - Ladder Methods

    /// Advance to the next rung up to the top rung.
    func advanceRung() -> Bool {
        guard blockSessionType == .eliminationLadder else { return false }
        guard currentRung < ladderSpeeds.count - 1 else { return false }

        currentRung += 1
        return true
    }

    /// Reset to rung 0 (speed 3) — used when missing at speeds 3-5
    func resetRung() {
        guard blockSessionType == .eliminationLadder else { return }
        currentRung = 0
    }

    /// Drop one rung — used when missing at speeds 6-7
    func dropRung() -> Bool {
        guard blockSessionType == .eliminationLadder else { return false }
        guard currentRung > 0 else { return false }

        currentRung -= 1
        return true
    }

    /// Get the current target speed for the ladder
    func getCurrentLadderSpeed() -> Int {
        guard blockSessionType == .eliminationLadder, currentRung >= 0, currentRung < ladderSpeeds.count else {
            return 0
        }
        return ladderSpeeds[currentRung]
    }

    /// True only after the top rung (speed 7, index 4) is hit in zone.
    /// BUG FIX: the old check fired as soon as currentRung reached 4 (after hitting
    /// rung 3 / 6 MPH), which marked the ladder complete one rung too early.
    var isLadderComplete: Bool {
        blockSessionType == .eliminationLadder && ladderCompleted
    }

    /// Called by the ViewModel when the top rung is successfully hit in zone.
    func markLadderComplete() {
        guard blockSessionType == .eliminationLadder else { return }
        ladderCompleted = true
    }

    /// Record a successful consecutive hit (for make-N-in-a-row challenges)
    func recordConsecutiveSuccess() {
        guard blockSessionType == .makeInRow else { return }
        consecutiveSuccesses += 1
    }

    /// Reset the consecutive counter (for make-N-in-a-row challenges)
    func resetConsecutiveCount() {
        guard blockSessionType == .makeInRow else { return }
        consecutiveSuccesses = 0
    }

    func recordPutt(actualSpeed: Float) {
        // Ladder blocks must use the current rung speed, not currentTargetSpeed.
        // currentTargetSpeed returns 0 for ladder blocks (block.targetSpeed is null in JSON),
        // which makes isInZone permanently false and causes the red/X bug.
        let targetSpeed: Int
        if blockSessionType == .eliminationLadder {
            targetSpeed = getCurrentLadderSpeed()
        } else {
            targetSpeed = currentTargetSpeed
        }
        let difference = abs(actualSpeed - Float(targetSpeed))
        let tolerance: Float
        let isInZone: Bool
        if let acceptRange = block.acceptRange {
            tolerance = (acceptRange.max - acceptRange.min) / 2
            isInZone = actualSpeed >= acceptRange.min && actualSpeed <= acceptRange.max
        } else {
            let t = TrainingProgramLoader.shared.getToleranceForSpeed(targetSpeed)
            tolerance = t
            isInZone = difference <= t
        }
        let isOnTarget = actualSpeed >= 0 && actualSpeed <= 30 // Valid reading

        let result = PuttResult(
            puttNumber: currentPutt + 1,
            targetSpeed: Float(targetSpeed),
            actualSpeed: actualSpeed,
            tolerance: tolerance,
            isOnTarget: isOnTarget,
            isInZone: isInZone,
            difference: difference
        )

        puttRecords.append(result)
        currentPutt += 1

        if isOnTarget {
            onTargetPutts += 1
        }

        if isInZone {
            inZonePutts += 1
            consecutiveSuccesses += 1

            // Check pressure challenge completion
            if block.type == .pressure && consecutiveTarget > 0 {
                if consecutiveSuccesses >= consecutiveTarget {
                    pressureChallengeComplete = true
                }
            }
        } else {
            // Reset consecutive on miss for pressure challenges
            if block.type == .pressure {
                consecutiveSuccesses = 0
                if block.challengeType == "elimination" {
                    livesRemaining -= 1
                }
            }
        }

        // Advance sequence index for sequence-based blocks (including adaptive sequences)
        if adaptiveSequence != nil {
            // Adaptive sequence — advance and wrap
            currentSequenceIndex += 1
            if currentSequenceIndex >= adaptiveSequence!.count {
                currentSequenceIndex = 0
            }
        } else if block.sequence != nil {
            currentSequenceIndex += 1
            if let rounds = block.rounds, let sequence = block.sequence {
                let totalSequence = sequence.count * rounds
                if currentSequenceIndex >= totalSequence {
                    currentSequenceIndex = 0
                }
            } else if let sequence = block.sequence, currentSequenceIndex >= sequence.count {
                currentSequenceIndex = 0
            }
        }
    }

    var zoneAccuracy: Float {
        guard currentPutt > 0 else { return 0 }
        return Float(inZonePutts) / Float(currentPutt)
    }

    var isComplete: Bool {
        // For pressure challenges
        if block.type == .pressure {
            if block.challengeType == "consecutive" && pressureChallengeComplete {
                return true
            }
            if block.challengeType == "elimination" && livesRemaining <= 0 {
                return true
            }
            // Pressure challenges without fixed putts don't auto-complete
            if block.putts == nil {
                return false
            }
        }

        // For regular blocks
        guard let targetPutts = block.putts else { return false }
        return currentPutt >= targetPutts
    }

    var totalPutts: Int {
        if let putts = block.putts {
            return putts
        }
        if let protocol_ = block.protocol_, let rounds = block.rounds {
            return protocol_.reduce(0) { $0 + $1.putts } * rounds
        }
        if let protocol_ = block.protocol_ {
            return protocol_.reduce(0) { $0 + $1.putts }
        }
        return 0
    }
}

struct PuttResult: Identifiable {
    let id = UUID()
    let puttNumber: Int
    let targetSpeed: Float
    let actualSpeed: Float
    let tolerance: Float
    let isOnTarget: Bool
    let isInZone: Bool
    let difference: Float

    var accuracyPercentage: Float {
        guard tolerance > 0 else { return 0 }
        let accuracyRatio = 1.0 - (difference / (tolerance * 1.5))
        return max(0, min(1, accuracyRatio))
    }
}

// MARK: - Network Service

/// Fetches the training program from the Speed Machine admin backend on launch.
/// Caches the last download in UserDefaults so the app keeps working offline,
/// and falls back to the bundled JSON if the backend is unreachable.
final class NetworkService {
    static let shared = NetworkService()

    private let baseURL = "https://speed-machine-admin.vercel.app"
    private let versionKey = "remoteProgramVersion"
    private let dataKey = "remoteProgramData"
    static let statusKey = "networkServiceStatus"

    private init() {}

    /// Called at app launch from TrainingProgramLoader. Non-blocking.
    func fetchProgramIfNeeded() async {
        setStatus("Checking…")

        // Version check (a few retries for transient network/SSL hiccups).
        var remoteVersion: String?
        for attempt in 1...3 {
            do {
                remoteVersion = try await fetchVersion()
                if remoteVersion != nil { break }
            } catch {
                if attempt < 3 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
            }
        }

        guard let remoteVersion else {
            setStatus("Offline — using bundled")
            // Apply any previously cached remote program so we're not stuck on bundle.
            if let cached = UserDefaults.standard.data(forKey: dataKey) {
                TrainingProgramLoader.shared.useRemoteProgram(cached)
            }
            return
        }

        let cachedVersion = UserDefaults.standard.string(forKey: versionKey) ?? ""
        if remoteVersion == cachedVersion,
           let cachedData = UserDefaults.standard.data(forKey: dataKey) {
            TrainingProgramLoader.shared.useRemoteProgram(cachedData)
            setStatus("v\(displayVersion(remoteVersion)) (cached)")
            return
        }

        // Download the newer published program.
        setStatus("Downloading…")
        do {
            let data = try await fetchProgramData()
            UserDefaults.standard.set(data, forKey: dataKey)
            UserDefaults.standard.set(remoteVersion, forKey: versionKey)
            TrainingProgramLoader.shared.useRemoteProgram(data)
            setStatus("v\(displayVersion(remoteVersion)) ✓")
        } catch {
            setStatus("Download failed — using bundled")
            if let cachedData = UserDefaults.standard.data(forKey: dataKey) {
                TrainingProgramLoader.shared.useRemoteProgram(cachedData)
            }
        }
    }

    private func setStatus(_ status: String) {
        UserDefaults.standard.set(status, forKey: NetworkService.statusKey)
    }

    /// The cache key is "version|publishedAt"; show just the version for display.
    private func displayVersion(_ raw: String) -> String {
        raw.split(separator: "|").first.map(String.init) ?? raw
    }

    private func fetchVersion() async throws -> String? {
        guard let url = URL(string: "\(baseURL)/api/program/version") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
        // Include publishedAt so a re-publish of the same version still busts the cache.
        return "\(decoded.version)|\(decoded.publishedAt)"
    }

    private func fetchProgramData() async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/program/current") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private struct VersionResponse: Decodable {
        let version: String
        let publishedAt: String
    }
}
