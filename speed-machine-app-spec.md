# Speed Machine iOS App + BLE Firmware Specification
## Final Specification Document v1.0

---

## Project Overview

The Speed Machine putting training device gains Bluetooth Low Energy (BLE) capability to communicate with a companion iOS app. The device retains full standalone functionality (Speed, Distance, Combine modes) while the app provides a structured 30-day training program and its own Combine mode with tighter tolerances.

---

## Part 1: Firmware Modifications

### 1.1 BLE Configuration

**Service UUID:** `4A524954-5350-4545-4400-000000000001` (custom, derived from "JARIT SPEED")

**Characteristics:**

| Characteristic | UUID | Properties | Format |
|----------------|------|------------|--------|
| Speed | `4A524954-5350-4545-4400-000000000002` | Notify | Float32 (4 bytes) |
| Battery | `4A524954-5350-4545-4400-000000000003` | Read, Notify | UInt8 (1 byte, 0-100) |

### 1.2 BLE Behavior

- **Activation:** User-enabled via new "Bluetooth" toggle in menu (4th option)
- **Advertising:** Only when BLE is enabled AND device is in Speed Mode
- **Device Name:** "Speed Machine"
- **Data Transmission:** Broadcasts speed (float, 1 decimal) only when in Speed Mode
- **Connection Indicator:** Ready dot gains blue outer ring when BLE connected

### 1.3 Mode Restrictions

- BLE only active/advertising in Speed Mode
- If user switches to Distance or Combine mode while app connected:
  - Device stops sending speed data
  - App detects silence and prompts: "Switch device to Speed Mode to continue"

### 1.4 Data Flow

```
[Ball passes sensors]
       ↓
[Speed calculated: 7.3 MPH]
       ↓
[Display updated on device]
       ↓
[If BLE connected + Speed Mode]
       ↓
[Notify speed characteristic: 7.3]
       ↓
[iOS app receives, processes against training target]
```

### 1.5 Menu Structure (Updated)

```
┌─────────────────┐
│     Speed       │  ← MODE_SPEED
├─────────────────┤
│    Distance     │  ← MODE_DISTANCE
├─────────────────┤
│    Combine      │  ← MODE_COMBINE
├─────────────────┤
│   Bluetooth     │  ← NEW: BLE toggle
│   [ON/OFF]      │
└─────────────────┘
```

### 1.6 Connection Indicator

Ready dot modification when BLE connected:
- Normal: Green (ready) / Red (cooldown) dot with black ring
- BLE Connected: Add blue outer ring around the existing indicator

---

## Part 2: iOS App Architecture

### 2.1 Technical Requirements

- **Minimum iOS Version:** 15.0
- **Framework:** SwiftUI
- **BLE:** Core Bluetooth
- **Local Storage:** Core Data (designed for future cloud sync)
- **Architecture:** MVVM

### 2.2 Navigation Structure

```
App Launch
    ↓
┌─────────────────────────────────────┐
│              HOME                    │
├─────────────────────────────────────┤
│  ┌─────────┐  ┌─────────────────┐   │
│  │ Device  │  │    Training     │   │
│  │ Status  │  │    Program      │   │
│  └─────────┘  └─────────────────┘   │
│  ┌─────────┐  ┌─────────────────┐   │
│  │ Combine │  │    Progress     │   │
│  │  Mode   │  │     Stats       │   │
│  └─────────┘  └─────────────────┘   │
│           ┌─────────┐               │
│           │Settings │               │
│           └─────────┘               │
└─────────────────────────────────────┘

Training Program Flow:
Home → Day Selection → Block Selection → Active Session → Session Complete

Combine Mode Flow:
Home → Combine Mode → 18 Putts → Final Score → Play Again / Home
```

### 2.3 Screen Specifications

#### 2.3.1 Home Screen
- Device connection status (prominent)
- Quick access to Training Program
- Quick access to Combine Mode
- Progress summary (current day, streak)
- Settings gear icon

#### 2.3.2 Device Connection
- Scan for "Speed Machine" devices
- Show connection status
- Auto-reconnect to last known device
- Manual disconnect option
- Troubleshooting tips if connection fails

#### 2.3.3 Training Program - Day Selection
- 30-day grid/list view
- Visual indicators:
  - Locked (gray, padlock icon)
  - Available (white, accessible)
  - Completed (green checkmark)
  - Current recommended (highlighted border)
- Gate tests marked distinctly
- Phase groupings visible (Phase 1: Days 1-10, etc.)

#### 2.3.4 Training Program - Active Session
```
┌─────────────────────────────────────┐
│  Day 5 • Block C                    │
│  6-7 MPH Introduction               │
├─────────────────────────────────────┤
│                                     │
│         TARGET                      │
│           6                         │
│          MPH                        │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│         LAST PUTT                   │
│          6.2 ✓                      │
│     Zone: 5.5 - 6.5 MPH             │
│                                     │
├─────────────────────────────────────┤
│  Putt 7 of 20                       │
│  Block Accuracy: 85% (6/7)          │
│  ████████████░░░░░░░░               │
└─────────────────────────────────────┘
```

#### 2.3.5 Session Complete
- Block/Day summary
- Accuracy percentage
- Zone breakdown
- Personal bests (if achieved)
- Next action: Continue to next block / Complete day / Retry

#### 2.3.6 Combine Mode
```
┌─────────────────────────────────────┐
│        COMBINE MODE                 │
│         Shot 7/18                   │
├─────────────────────────────────────┤
│                                     │
│         TARGET                      │
│          12                         │
│          MPH                        │
│                                     │
│       Zone 3 (1.25x)                │
│                                     │
├─────────────────────────────────────┤
│  Score: 89                          │
│  High Score: 156                    │
│                                     │
│  Last: 11.8 → +8 pts (Excellent)    │
└─────────────────────────────────────┘
```

#### 2.3.7 Progress/Stats
- Overall completion (days, percentage)
- Current streak
- Zone accuracy breakdown (chart)
- Combine high score
- Session history (list)

#### 2.3.8 Settings
- Audio feedback toggle (on/off)
- Haptic feedback toggle (on/off)
- BLE settings
- About / Version info
- (Future: Account, cloud sync)

---

## Part 3: Data Models

### 3.1 Core Data Entities

```swift
// User Progress
UserProgress {
    currentDay: Int16
    currentPhase: Int16
    unlockedZones: [Int16]  // 1-5
    combineHighScore: Int16
    totalPutts: Int32
    createdAt: Date
    updatedAt: Date
}

// Day Completion
DayCompletion {
    dayNumber: Int16
    completedAt: Date
    overallAccuracy: Float
    totalPutts: Int16
    onTargetPutts: Int16
}

// Session (active or historical)
Session {
    id: UUID
    dayNumber: Int16
    blockId: String
    startedAt: Date
    completedAt: Date?
    targetPutts: Int16
    completedPutts: Int16
    onTargetPutts: Int16
    isComplete: Bool
}

// Individual Putt Record
PuttRecord {
    id: UUID
    sessionId: UUID
    timestamp: Date
    targetSpeed: Float
    actualSpeed: Float
    tolerance: Float
    isOnTarget: Bool
    difference: Float
}

// Combine Game
CombineGame {
    id: UUID
    playedAt: Date
    totalScore: Int16
    isComplete: Bool
}

// Combine Shot
CombineShot {
    id: UUID
    gameId: UUID
    shotNumber: Int16
    targetSpeed: Int16
    actualSpeed: Float
    points: Int16
    accuracy: String  // "perfect", "excellent", "good", "inZone", "close", "miss"
}
```

### 3.2 Training Program Data

Loaded from bundled JSON file (speed-machine-training-program.json):
- 30 days with full protocol details
- 5 speed zones with tolerances
- 5 gate tests with pass requirements
- Scientific foundation content

---

## Part 4: App Combine Mode Scoring

### 4.1 Zone Tolerances (Training Program Standard)

| Zone | Speed Range | Tolerance |
|------|-------------|-----------|
| 1 | 3-7 MPH | ±0.5 MPH |
| 2 | 8-10 MPH | ±0.7 MPH |
| 3 | 11-14 MPH | ±1.0 MPH |
| 4 | 15-18 MPH | ±1.25 MPH |
| 5 | 19-20 MPH | ±1.5 MPH |

### 4.2 Accuracy Tiers

| Tier | Threshold | Base Points |
|------|-----------|-------------|
| Perfect | ≤25% of tolerance | 10 |
| Excellent | ≤50% of tolerance | 8 |
| Good | ≤75% of tolerance | 6 |
| In Zone | ≤100% of tolerance | 4 |
| Close | ≤150% of tolerance | 2 |
| Miss | >150% of tolerance | 0 |

### 4.3 Zone Multipliers

| Zone | Multiplier |
|------|------------|
| 1 | 1.0x |
| 2 | 1.1x |
| 3 | 1.25x |
| 4 | 1.5x |
| 5 | 2.0x |

### 4.4 Scoring Formula

```swift
func calculateCombineScore(target: Int, actual: Float) -> (points: Int, tier: String) {
    let zone = getZone(for: target)
    let tolerance = zone.tolerance
    let difference = abs(actual - Float(target))
    
    let basePoints: Int
    let tier: String
    
    switch difference {
    case 0...(tolerance * 0.25):
        basePoints = 10; tier = "perfect"
    case 0...(tolerance * 0.50):
        basePoints = 8; tier = "excellent"
    case 0...(tolerance * 0.75):
        basePoints = 6; tier = "good"
    case 0...tolerance:
        basePoints = 4; tier = "inZone"
    case 0...(tolerance * 1.5):
        basePoints = 2; tier = "close"
    default:
        basePoints = 0; tier = "miss"
    }
    
    let finalPoints = Int(Float(basePoints) * zone.multiplier)
    return (finalPoints, tier)
}
```

### 4.5 Score Ranges

| Metric | Min | Max | Great Round |
|--------|-----|-----|-------------|
| Per putt | 0 | 20 | - |
| 18-putt round | 0 | ~234 | 150-180 |

---

## Part 5: Branding Specification

### 5.1 Colors

| Name | Hex | CSS Variable | Usage |
|------|-----|--------------|-------|
| Primary Black | `#0a0a0a` | `--color-text` | Headers, text, icons |
| Background | `#ffffff` | `--color-bg` | Main backgrounds |
| Background Alt | `#f5f5f5` | `--color-bg-alt` | Cards, sections |
| Accent Green | `#15803d` | `--color-accent` | Primary accent |
| Accent Light | `#dcfce7` | `--color-accent-light` | Highlights, selection |
| Accent Bright | `#22c55e` | - | Success, in-zone |
| Text Muted | `#525252` | `--color-text-muted` | Secondary text |
| Border | `#e5e5e5` | `--color-border` | Dividers |
| Error/Warning | `#EF4444` | - | Out-of-zone, errors |
| BLE Blue | `#3B82F6` | - | Bluetooth indicators |

### 5.2 Typography (iOS)

| Role | Font | Weight | Fallback |
|------|------|--------|----------|
| Display | SF Pro Display | Black (900) | System |
| Headers | SF Pro Display | Bold (700) | System |
| Body | SF Pro Text | Light (300) | System |
| Medium | SF Pro Text | Medium (500) | System |
| Numbers | SF Pro Rounded | Bold (700) | System |

### 5.3 Design Elements

- Bold black borders (3-6px) with green inner accents
- Rounded corners: 12px (buttons), 16-24px (cards)
- Floating shadow effects on cards
- Clean white/black contrast with green highlights

### 5.4 App Icon

- Jarit Golf cup logo (ball at bottom of cup)
- White background
- Black logo mark
- 1024x1024 master, scaled for all iOS sizes

---

## Part 6: Feedback System

### 6.1 Audio (Optional, User Toggle)

| Event | Sound |
|-------|-------|
| Putt received | Soft tick |
| In zone | Pleasant chime |
| Perfect | Celebratory tone |
| Miss | Subtle low tone |
| Session complete | Success melody |

### 6.2 Haptics (Optional, User Toggle)

| Event | Pattern |
|-------|---------|
| Putt received | Light tap |
| In zone | Medium success |
| Perfect | Strong success |
| Miss | Soft error |
| Gate test passed | Celebration pattern |

---

## Part 7: Implementation Phases

### Phase 1: Firmware BLE (Week 1)
1. Add ESP32 BLE library imports
2. Create BLE service and characteristics
3. Add "Bluetooth" menu option with toggle
4. Implement connection indicator (blue ring)
5. Broadcast speed on measurement (Speed Mode only)
6. Test with nRF Connect / LightBlue

**Deliverable:** Modified .ino file with BLE capability

### Phase 2: iOS Foundation (Week 2)
1. Create Xcode project (SwiftUI, iOS 15+)
2. Implement BLE manager (scan, connect, receive)
3. Basic UI: Home, Connection screen
4. Live speed display when connected
5. Core Data model setup

**Deliverable:** App connects to device, shows live speed

### Phase 3: Training Program (Weeks 3-4)
1. Bundle JSON training data
2. Day selection view with unlock logic
3. Active session view with real-time tracking
4. Session persistence (resume capability)
5. Day/block completion logic
6. Progress tracking

**Deliverable:** Full training program functional

### Phase 4: Combine + Polish (Week 5)
1. App Combine mode with new scoring
2. Gate test special handling
3. Progress/stats views
4. Audio/haptic feedback system
5. Share session summary (image generation)

**Deliverable:** Feature complete app

### Phase 5: Branding & Testing (Week 6)
1. Apply full Jarit Golf branding
2. Create app icon
3. TestFlight distribution
4. Bug fixes and polish

**Deliverable:** TestFlight-ready build

---

## Part 8: File Deliverables

### Firmware
- `SpeedMachine_with_BLE.ino` - Modified firmware with Bluetooth

### iOS App
```
SpeedMachineApp/
├── SpeedMachineApp.xcodeproj
├── SpeedMachine/
│   ├── App/
│   │   └── SpeedMachineApp.swift
│   ├── Models/
│   │   ├── TrainingProgram.swift
│   │   ├── SpeedZone.swift
│   │   └── CombineGame.swift
│   ├── Views/
│   │   ├── Home/
│   │   ├── Training/
│   │   ├── Combine/
│   │   ├── Progress/
│   │   └── Settings/
│   ├── ViewModels/
│   │   ├── BLEManager.swift
│   │   ├── TrainingViewModel.swift
│   │   └── CombineViewModel.swift
│   ├── Services/
│   │   ├── BluetoothService.swift
│   │   └── DataService.swift
│   ├── CoreData/
│   │   └── SpeedMachine.xcdatamodeld
│   ├── Resources/
│   │   ├── speed-machine-training-program.json
│   │   ├── Assets.xcassets
│   │   └── Sounds/
│   └── Utilities/
│       ├── Constants.swift
│       └── Extensions.swift
└── README.md
```

---

## Appendix A: BLE Protocol Details

### Advertising Data
- Local Name: "Speed Machine"
- Service UUID: `4A524954-5350-4545-4400-000000000001`

### Speed Characteristic
- UUID: `4A524954-5350-4545-4400-000000000002`
- Properties: Notify
- Value: 4-byte little-endian float (e.g., 7.3 MPH)
- Update: On each valid speed measurement

### Battery Characteristic
- UUID: `4A524954-5350-4545-4400-000000000003`
- Properties: Read, Notify
- Value: 1-byte unsigned integer (0-100%)
- Update: Every 30 seconds or on significant change

### Connection Flow
1. App scans for service UUID
2. User selects "Speed Machine" from list
3. App connects and discovers characteristics
4. App subscribes to speed notifications
5. App reads battery level
6. Ready to receive speed data

---

## Appendix B: Error Handling

### BLE Connection Errors
| Error | User Message | Action |
|-------|--------------|--------|
| Device not found | "Speed Machine not found. Make sure Bluetooth is enabled on the device." | Show troubleshooting |
| Connection failed | "Could not connect. Please try again." | Retry button |
| Connection lost | "Connection lost. Reconnecting..." | Auto-retry 3x |
| Wrong mode | "Switch device to Speed Mode to continue training." | Show instruction |

### Data Errors
| Error | Handling |
|-------|----------|
| Invalid speed (< 0 or > 30) | Ignore, don't record |
| Missing session | Create new session |
| Corrupted data | Reset to last known good state |

---

*Document Version: 1.0*
*Created: January 25, 2026*
*Author: Claude (Anthropic) for Jarit Golf*
