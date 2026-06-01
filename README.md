# Speed Machine iOS App

A comprehensive iOS training application for the Speed Machine putting training device with Bluetooth Low Energy (BLE) connectivity.

## Overview

The Speed Machine app provides a structured 30-day training program designed to improve putting speed control across 5 distinct speed zones (3-20 MPH). The app connects to the Speed Machine device via Bluetooth to receive real-time speed measurements and track progress through a scientifically-designed training protocol.

## Features

### 📱 Core Features
- **30-Day Training Program**: Progressive training across 3 phases and 5 speed zones
- **BLE Connectivity**: Wireless connection to Speed Machine device
- **Combine Mode**: 18-shot challenge with zone-based scoring
- **Progress Tracking**: Comprehensive stats and session history
- **Gate Tests**: 5 milestone assessments throughout the program

### 🎯 Training Program
- **Phase 1 (Days 1-10)**: Foundation - Zones 1-2
- **Phase 2 (Days 11-20)**: Expansion - Zones 3-4
- **Phase 3 (Days 21-30)**: Mastery - All 5 zones

### 📊 Speed Zones
| Zone | Speed Range | Tolerance | Multiplier |
|------|-------------|-----------|------------|
| 1 | 3-7 MPH | ±0.5 MPH | 1.0x |
| 2 | 8-10 MPH | ±0.5 MPH | 1.1x |
| 3 | 11-14 MPH | ±0.5 MPH | 1.25x |
| 4 | 15-18 MPH | ±0.5 MPH | 1.5x |
| 5 | 19-20 MPH | ±0.5 MPH | 2.0x |

## Project Structure

```
SpeedMachineApp/
├── SpeedMachine/
│   ├── App/
│   │   └── SpeedMachineApp.swift          # Main app entry point
│   ├── Models/
│   │   ├── TrainingProgram.swift          # Training data models
│   │   └── CombineGame.swift              # Combine mode logic
│   ├── Views/
│   │   ├── Home/
│   │   │   └── HomeView.swift             # Main dashboard
│   │   ├── Training/
│   │   │   ├── DaySelectionView.swift     # Day picker
│   │   │   └── TrainingSessionView.swift  # Active session
│   │   ├── Combine/
│   │   │   └── CombineModeView.swift      # Combine game
│   │   ├── Progress/
│   │   │   └── ProgressView.swift         # Stats dashboard
│   │   ├── Settings/
│   │   │   └── SettingsView.swift         # App settings
│   │   └── Connection/
│   │       └── ConnectionView.swift       # BLE connection
│   ├── ViewModels/
│   │   ├── TrainingViewModel.swift        # Training logic
│   │   └── CombineViewModel.swift         # Combine logic
│   ├── Services/
│   │   ├── BluetoothService.swift         # BLE manager
│   │   └── DataService.swift              # Core Data service
│   ├── CoreData/
│   │   └── SpeedMachine.xcdatamodeld      # Data model
│   ├── Resources/
│   │   └── speed-machine-training-program.json
│   └── Utilities/
│       ├── Constants.swift                # App constants
│       └── Extensions.swift               # Helper extensions
```

## Technical Requirements

- **iOS Version**: 15.0+
- **Framework**: SwiftUI
- **Architecture**: MVVM
- **Persistence**: Core Data
- **Connectivity**: Core Bluetooth (BLE)

## BLE Specification

### Service UUID
```
4A524954-5350-4545-4400-000000000001
```

### Characteristics
- **Speed**: `4A524954-5350-4545-4400-000000000002` (Notify, Float32)
- **Battery**: `4A524954-5350-4545-4400-000000000003` (Read/Notify, UInt8)

### Connection Flow
1. App scans for "Speed Machine" device
2. User selects device from list
3. App connects and discovers characteristics
4. App subscribes to speed notifications
5. Device broadcasts speed data (Speed Mode only)

## Combine Mode Scoring

### Accuracy Tiers
| Tier | Threshold | Base Points |
|------|-----------|-------------|
| Perfect | ≤25% of tolerance | 10 |
| Excellent | ≤50% of tolerance | 8 |
| Good | ≤75% of tolerance | 6 |
| In Zone | ≤100% of tolerance | 4 |
| Close | ≤150% of tolerance | 2 |
| Miss | >150% of tolerance | 0 |

Final score = Base Points × Zone Multiplier

**Maximum Score**: ~234 points
**Great Round**: 150-180 points

## Setup Instructions

### iOS App
1. Open the **outer** project: `Traning Program App/SpeedMachineApp/SpeedMachineApp.xcodeproj` in Xcode.
   - ⚠️ Do NOT open the renamed `SpeedMachineApp_OLD_DO_NOT_OPEN.xcodeproj` nested one folder deeper — it's a stale duplicate that ships an old UI under the same bundle id.
2. Ensure deployment target is iOS 15.0+
3. Build and run on device or simulator (Clean Build Folder first if a screen looks cached)
4. Grant Bluetooth permissions when prompted

### Firmware
1. Open `SpeedMachine_with_BLE.ino` in Arduino IDE
2. Install ESP32 board support
3. Install BLE libraries (BLEDevice, BLEServer, BLEUtils)
4. Configure pin assignments for your hardware
5. Upload to ESP32 device
6. Enable Bluetooth in device menu

## Key Files

- **[SpeedMachineApp.swift](SpeedMachine/App/SpeedMachineApp.swift)**: App initialization and environment setup
- **[BluetoothService.swift](SpeedMachine/Services/BluetoothService.swift)**: BLE connection and data handling
- **[TrainingViewModel.swift](SpeedMachine/ViewModels/TrainingViewModel.swift)**: Training program logic
- **[speed-machine-training-program.json](SpeedMachine/Resources/speed-machine-training-program.json)**: Complete 30-day program data
- **[SpeedMachine_with_BLE.ino](../SpeedMachine_with_BLE.ino)**: ESP32 firmware

## Design System

### Colors
- **Primary Black**: `#0a0a0a` - Headers, text
- **Accent Green**: `#15803d` - Primary actions
- **Accent Light**: `#dcfce7` - Highlights
- **BLE Blue**: `#3B82F6` - Bluetooth indicators
- **Background**: `#ffffff` / `#f5f5f5`

### Typography
- **Display**: SF Pro Display (Black/Bold)
- **Body**: SF Pro Text (Light/Medium)
- **Numbers**: SF Pro Rounded (Bold)

## Data Models

### Core Data Entities
- **UserProgressData**: Current day, phase, unlocked zones, stats
- **DayCompletionData**: Day completion records
- **SessionData**: Individual training sessions
- **PuttRecordData**: Individual putt measurements
- **CombineGameData**: Combine mode games
- **CombineShotData**: Individual combine shots

## Features Implemented

✅ BLE device connection and management
✅ 30-day progressive training program
✅ Real-time speed measurement display
✅ Session tracking and resume capability
✅ Progress statistics and history
✅ Combine mode with advanced scoring
✅ Gate test special handling
✅ Day unlock logic
✅ Zone-based difficulty progression
✅ Battery level monitoring
✅ Haptic feedback
✅ Audio feedback (toggle)
✅ Auto-reconnect to last device

## Future Enhancements

- Cloud sync for multi-device access
- Social features and leaderboards
- Advanced analytics and insights
- Custom training programs
- Session sharing (image export)
- Apple Watch companion app

## Version

**1.0.0** - Initial Release
Created: January 25, 2026
Author: Claude for Jarit Golf

## License

© 2026 Jarit Golf. All rights reserved.
