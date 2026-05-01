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
    let tracks: [TrainingTrack]
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
    let totalTracks: Int
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
    let unlockTrack: Int
    let description: String
}

struct Phase: Codable, Identifiable {
    var id: Int { phase }
    let phase: Int
    let name: String
    let tracks: String
    let startTrack: Int
    let endTrack: Int
    let speedRange: String
    let focus: String
    let goals: [String]
}

struct GateTest: Codable, Identifiable {
    var id: String { gateId }
    let gateId: String
    let name: String
    let track: Int
    let unlocksZone: Int
    let unlocksSpeeds: [Int]
    let protocol_: [ProtocolStep]
    let totalPutts: Int
    let passRequirements: PassRequirements

    enum CodingKeys: String, CodingKey {
        case gateId = "id"
        case name, track, unlocksZone, unlocksSpeeds
        case protocol_ = "protocol"
        case totalPutts, passRequirements
    }
}

struct ProtocolStep: Codable {
    let speed: Int
    let putts: Int
}

struct PassRequirements: Codable {
    // Phase 4 four-criterion schema (all optional for backward compat with old JSON)
    let minOverallInZone:  Int?
    let minPerSpeedInZone: Int?
    let avgDeviationCapMph: Float?
    let maxSingleMissMph:  Float?
    // Legacy single-criterion field — kept for any unconverted blocks
    let zoneAccuracy: AccuracyRequirement?
}

struct AccuracyRequirement: Codable {
    let minimum: Int
    let percentage: Int
}

struct TrainingTrack: Codable, Identifiable {
    var id: Int { number }
    let number: Int
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

    enum CodingKeys: String, CodingKey {
        case number = "track"
        case phase, title, duration, targetPutts, availableSpeeds, speedRange
        case objective, science, blocks, successMetrics, coachingNotes, warnings
    }
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
    // Phase 1 Skill Gating fields
    let blockPassThreshold: Float?
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
        case adaptiveMode, adaptivePool
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
    case eliminationLadder  // Ladder: speeds 3→7, specific advancement rules
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
    }

    private func loadProgram() {
        guard let url = Bundle.main.url(forResource: "speed-machine-training-program", withExtension: "json") else {
            print("Error: Training program JSON file not found")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            program = try decoder.decode(TrainingProgram.self, from: data)
            print("Training program loaded successfully with \(program?.tracks.count ?? 0) tracks")
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

    func getTrack(_ trackNumber: Int) -> TrainingTrack? {
        return program?.tracks.first { $0.number == trackNumber }
    }

    func getGateTest(forTrack trackNumber: Int) -> GateTest? {
        return program?.gateTests.first { $0.track == trackNumber }
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

    func isGateTestTrack(_ trackNumber: Int) -> Bool {
        return program?.gateTests.contains { $0.track == trackNumber } ?? false
    }

    func getBlocksForTrack(_ trackNumber: Int) -> [TrainingBlock] {
        return getTrack(trackNumber)?.blocks ?? []
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
    let trackNumber: Int
    /// Override for putt count — set on hard-gate auto-halved repeats (Phase 4).
    let puttsOverride: Int?

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

    init(block: TrainingBlock, trackNumber: Int, puttsOverride: Int? = nil) {
        self.block = block
        self.trackNumber = trackNumber
        self.puttsOverride = puttsOverride
        self.consecutiveTarget = block.consecutiveRequired ?? 0
        self.livesRemaining = block.lives ?? 3

        // Initialize block session type and ladder state
        self.blockSessionType = BlockSessionType(from: block.type, challengeType: block.challengeType)
        self.requiredConsecutive = block.consecutiveRequired ?? 0

        // Initialize ladder if this is an elimination ladder block
        if self.blockSessionType == .eliminationLadder {
            self.ladderSpeeds = [3, 4, 5, 6, 7]
            self.currentRung = 0  // Start at speed 3

        }
    }

    // MARK: - Ladder Methods

    /// Advance to the next rung (up to rung 4, which is speed 7)
    func advanceRung() -> Bool {
        guard blockSessionType == .eliminationLadder else { return false }
        guard currentRung < 4 else { return false }  // Can't go past rung 4

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
        let tolerance = TrainingProgramLoader.shared.getToleranceForSpeed(targetSpeed)
        let difference = abs(actualSpeed - Float(targetSpeed))
        let isOnTarget = actualSpeed >= 0 && actualSpeed <= 30 // Valid reading
        let isInZone = difference <= tolerance

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

        // For regular blocks — puttsOverride takes priority (hard-gate halved repeat)
        let targetPutts = puttsOverride ?? block.putts
        guard let targetPutts else { return false }
        return currentPutt >= targetPutts
    }

    var totalPutts: Int {
        if let override = puttsOverride { return override }
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
