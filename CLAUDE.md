# Speed Machine App — Claude Context

## Working Preferences

- **Arthur does not use the Terminal.** Never instruct him to run terminal commands manually. If anything requires a shell command (clearing DerivedData, running scripts, installing packages, etc.), Claude should run it directly using its Bash tool and report the result.

---

## Admin Panel (`speed-machine-admin`)

The admin panel lives at `/Users/jaritgolf/Documents/Traning Program App/speed-machine-admin` and is deployed via Vercel. **After every change to the admin panel, always `git add`, `git commit`, and `git push` immediately so Vercel picks up the change and Arthur can see it live right away. Never leave admin panel edits uncommitted.**

---

## Project Overview

iOS SwiftUI app for the **Speed Machine** putting training device by Jarit Golf. Connects via Bluetooth Low Energy (BLE) to receive real-time putt speed measurements and guides users through a structured 30-track training program across 5 speed zones (3–20 MPH).

---

## Architecture

- **Pattern**: MVVM (Model-View-ViewModel)
- **UI Framework**: SwiftUI
- **Persistence**: Core Data
- **Connectivity**: BLE via `BluetoothService`
- **Data**: Training program loaded from `speed-machine-training-program.json`

### Key Files

| File | Purpose |
|------|---------|
| `TrainingViewModel.swift` | Central session logic — block start/complete/advance, gate test evaluation |
| `TrainingSessionView.swift` | Live session router — switches between all session view types |
| `TrainingProgram.swift` | All data models + `SessionProgress` + `TrainingProgramLoader` |
| `Constants.swift` | `SpeedZone` definitions with tolerance values |
| `DataService.swift` | Core Data reads/writes + managed object subclasses |
| `StatsService.swift` | Lifetime stats — SpeedProfile updates, DailySnapshot, trends, migration |
| `DaySelectionView.swift` | Track grid + `BlockSelectionView` + navigation to session |
| `StatsView.swift` | Stats dashboard with speed ladder, key metrics, quick links |
| `TrendsView.swift` | Accuracy/deviation/volume trend charts with time range picker |
| `SpeedDetailView.swift` | Per-speed deep dive — accuracy, tendency, streak, consistency |
| `SessionHistoryView.swift` | Session list + putt-by-putt detail view |
| `CombineStatsView.swift` | Combine game score history and trend chart |

### ⚠️ Xcode Project & Build/Deploy — READ THIS FIRST

**There is exactly ONE project to open and build:**

```
Traning Program App/SpeedMachineApp/SpeedMachineApp.xcodeproj      ← THE ONE (outer)
```

It compiles the source under `SpeedMachineApp/SpeedMachineApp/` (`App/`, `Models/`, `Views/`, `ViewModels/`, `Services/`, `Utilities/`, `Resources/`), scheme `SpeedMachineApp`, bundle id `Jarit-Golf.SpeedMachineApp`. This is the only actively-maintained app.

**Historical trap (now defused):** a *duplicate* project used to sit one folder deeper at
`SpeedMachineApp/SpeedMachineApp/SpeedMachineApp.xcodeproj`, compiling a **stale, divergent copy** of the
source in `SpeedMachineApp/SpeedMachineApp/SpeedMachineApp/…`. Both produced the **same bundle id**, so
building the wrong one silently shipped an *old UI* to the phone while the simulator (built from the correct
project) looked correct. That duplicate has been **renamed to `SpeedMachineApp_OLD_DO_NOT_OPEN.xcodeproj`** —
never open or build it. Rule of thumb: if you ever see two `SpeedMachineApp.xcodeproj`, the correct one is the
**shallower** path.

Also present but **NOT used** (do not edit/sync): the older `SpeedMachine/` directory, and a separate legacy
project `Training Program App/Training Program App.xcodeproj` (different bundle id `Jarit-Golf.Training-Program-App`).

**Deploy to the phone:** open the outer project → select the iPhone → Product ▸ Clean Build Folder
(Shift+Cmd+K) → Run. Same bundle id means the new build replaces the installed app. If a screen looks cached,
delete the app from the phone once and Run again.

**Build to verify (Claude runs this — Arthur does not use Terminal):**
```
xcodebuild -project SpeedMachineApp.xcodeproj -scheme SpeedMachineApp \
  -destination 'platform=iOS Simulator,name=iPhone 16e' build
```

### Design System & Fonts (Whoop)

The UI follows the "Whoop minimal athletic" system: white screens, `#22C55E` green accent, `#DC2626` pressure
red, `#1D4ED8` gate blue, `#f0f0f0` hairlines, full-black transition/complete screens, and the **Inter**
typeface. Tokens live in `Utilities/Constants.swift` (`AppColors`) and `Views/Training/SportLive/SportTokens.swift`.

⚠️ **Font bundling gotcha:** Inter `.ttf` files live in `Resources/Fonts/`, but `Info.plist` `UIAppFonts` MUST
list **bare filenames** (`Inter-Black.ttf`), NOT `Fonts/Inter-Black.ttf`. The build flattens `Resources/`
into the bundle root, so a `Fonts/…` path fails to register and **every custom font silently falls back to
SF Pro app-wide** (this was a real, hard-to-spot bug). Use `Font.inter(_:weight:)` or `.custom("Inter-…")`.

---

## Navigation Stack

```
HomeView
  └── TrackSelectionView (fullScreenCover)
        └── BlockSelectionView (fullScreenCover on selectedTrack)
              └── TrainingSessionView (fullScreenCover on isSessionActive)
```

To navigate home programmatically: `endSession()` + `shouldNavigateHome = true` on `TrainingViewModel`. `TrackSelectionView` observes `shouldNavigateHome` and unwinds the full stack.

---

## Session Flow

1. User taps a block → `trainingViewModel.startBlock(block, for: track)`
2. Putts recorded via BLE → `trainingViewModel.recordPutt(speed)`
3. Block complete → `trainingViewModel.completeBlock()`
   - **If next block exists**: sets `nextBlockForTransition` → shows `BlockTransitionView` for 3 seconds → auto-starts next block
   - **If last block of track**: waits 3 seconds → `endSession()` + `shouldNavigateHome = true` → returns to HomeView

---

## UI — Viewing Distance Rules ⚠️

**All live session UIs are viewed from an average distance of 5–6 feet from the screen.** This is a fundamental design constraint that applies to every screen the user sees while actively putting:

- `ActiveSessionView`
- `ExplorationSessionView`
- `PressureSessionView`
- `GateTestSessionView`
- `LadderSessionView`
- `MakeInRowSessionView`
- **`BlockTransitionView`** (the between-block transition screen)

### Rules for live session screens:

- **Text and numbers must be as large as possible** while still following proper iOS design hierarchy
- **Primary metric** (target speed number): minimum 80–100pt, use `.black` weight
- **Secondary labels** (e.g. "TARGET", "MPH", "BLOCK COMPLETE"): minimum 24–32pt, bold/heavy
- **Supporting info** (e.g. block header, putt count): minimum 20–24pt
- **Never use small/caption fonts** on live session screens — if text needs to be small, reconsider whether it belongs on screen at all
- Use `minimumScaleFactor` to handle edge cases rather than shrinking the base font size
- High contrast: dark text on white cards, or white text on dark backgrounds

---

## Speed Zones & Tolerance

There are **4 speed zones (3–15 MPH)** and tolerance **widens as speed increases** — it is NOT uniform. A fixed ±X MPH window is a larger proportional miss on a slow putt than a fast one, so the window opens up slightly in the higher zones to keep the difficulty roughly constant in percentage terms.

| Zone | Name | Speed Range | Tolerance |
|------|------|-------------|-----------|
| 1 | Touch | 3–6 MPH | ±0.5 MPH |
| 2 | Moderate | 7–9 MPH | ±0.5 MPH |
| 3 | Firm | 10–12 MPH | ±0.6 MPH |
| 4 | Power | 13–15 MPH | ±0.7 MPH |

Tolerance is stored in two places in the shipped app — keep them in sync when changing:
1. `Utilities/Constants.swift` — `SpeedZone.zones` array
2. `Resources/speed-machine-training-program.json` — `speedZones[].tolerance`

(The unused root-level and `SpeedMachine/` JSON copies are not built — ignore them.)

---

## Training Program Data

The JSON is the source of truth for training content. The build ships exactly one copy:
- `SpeedMachineApp/SpeedMachineApp/Resources/speed-machine-training-program.json` — **the only copy that ships.**

A root-level `speed-machine-training-program.json` and a `SpeedMachine/Resources/` copy exist but are **NOT built** — ignore them unless deliberately maintaining them.

### ⚠️ JSON ↔ model schema contract: keys are `day` / `days` / `unlockDay`

Although the UI *labels* the 30 elements "Track N", the **Swift model and the shipped JSON keys use `day`** — NOT `track`:
- Model: `TrainingDay` struct (`day: Int`), loaded via `program.days` in `TrainingProgramLoader` (decodes `TrainingProgram`). `SpeedZoneInfo.unlockDay: Int` is **required (non-optional)**.
- Shipped JSON: top-level array `"days"`; each element has `"day"`; each speed zone has `"unlockDay"`.

**Do NOT rename JSON keys to `tracks` / `track` / `unlockTrack` unless you also change the model's `CodingKeys` in `TrainingProgram.swift`.** A prior edit renamed only the JSON → `JSONDecoder` threw `keyNotFound("day")` / `keyNotFound("unlockDay")` → `program` stayed `nil` → the **entire training flow died on a fresh install** (Tracks screen stuck on a loading spinner). The JSON and the model are a matched pair — keep their key names in sync. After any JSON edit, verify it decodes (console prints `Training program loaded successfully with 30 days`).

Calendar-based stats (streaks, DailySnapshot, trend charts) also use "day" internally.

### Target Accuracy

**Target accuracy has been removed as a metric and requirement throughout the app.** It no longer appears in `PassRequirements`, `successMetrics`, or any data-driven field. The only remaining mentions are in plain-text `message` fields inside warning/safety blocks — these are intentional and should be preserved.

---

## Block Header Format (live sessions)

Live session headers render via **`SportRecHeader`** (`Views/Training/SportLive/SportRecHeader.swift`) as a compact single line:
`"T{day} · BLOCK {n} · {BLOCK NAME}"` — uppercase, Inter ExtraBold, colored by type:
- standard / exploration / ladder / make-in-row → black text + green BLE dot (`.rec`)
- pressure → red (`AppColors.error`) + ⚡ (`.bolt`)
- gate test → blue (`AppColors.bleBlue`) + 🏁 (`.flag`)

Block number is computed from the block's index in the day's `blocks`, not stored directly. (The legacy `SessionHeaderCompact` / `PressureHeaderCompact` / `GateTestHeaderCompact` structs still exist but no longer drive live sessions.)

---

## Gate Tests

Gate tests evaluate pass/fail based on **zone accuracy only** (`zoneAccuracy.minimum` putts in zone). Target accuracy is not evaluated.

Gate test tracks: 5, 9, 12, 19, 25, 30.

---

## Key Decisions Log

- **Speed-scaled tolerance** — ±0.5 MPH for zones 1–2 (3–9 MPH), ±0.6 for zone 3 (10–12 MPH), ±0.7 for zone 4 (13–15 MPH). Widens with speed so each zone is roughly the same percentage challenge. `getToleranceForSpeed()` falls back to 0.5 for speeds outside the zone table (e.g. 16–20 MPH, which the Speed Profile tracks but the training program does not target)
- **Auto-advance between blocks** — global, applies to all tracks/block types. 3-second `BlockTransitionView` shown between blocks
- **Auto-navigate home after last block** — no "Continue" button; app returns to HomeView automatically after 3 seconds
- **Target accuracy removed** — only zone accuracy is used as a success metric. Warning message text may still reference it
- **Block header shows Track/Block/Name** — e.g. "Track 7: Block 3: 7 Rung Ladder" on all live session types
- **Stats are protocol-independent** — stats track lifetime putting performance across all modes (training + combine), completely decoupled from the 30-track training program. Resetting training progress does not affect stats. Stats have their own separate reset in Settings.
- **Adaptive speed weighting** — random, warmup, and multi-speed blocks automatically weight weak speeds higher. Gate tests, assessments, and fixed-speed blocks are never modified. See Adaptive Speed Engine section.

---

## Adaptive Speed Engine

`AdaptiveSpeedEngine.swift` generates weighted speed sequences at session start for eligible blocks. The user's SpeedProfile accuracy determines how often each speed appears.

### Block Eligibility

| Adaptation Level | Block Types | Behavior |
|-----------------|-------------|----------|
| **Full** (~3x for weakest) | random, exploration, challenge, reactive, celebration, sequence, alternating (with multi-speed sequences) | Regenerates sequence weighted toward weak speeds |
| **Warmup** (~30% of full bias) | warmup | Light bias, progressive structure (slow→fast) preserved |
| **None** (never touched) | gateTest, assessment, fixed-speed blocked, pressure with fixed speed, elimination ladder, recovery, combine, protocol-based | Original speeds preserved exactly |

### Weight Thresholds

| Accuracy | Weight | Effect |
|----------|--------|--------|
| < 60% | 3.0x | Appears ~3x more often |
| 60–75% | 2.0x | Appears ~2x more often |
| 75–90% | 1.0x | Baseline frequency |
| > 90% | 0.5x | Still appears, just less |
| Unpracticed | 1.5x | Mild priority to gather data |

### Key Rules

1. Never changes a block's zone boundaries — only re-weights within the block's existing speed pool
2. Never changes putt counts, block type, or completion criteria
3. Warmup weights compressed: `1.0 + (fullWeight - 1.0) * 0.3`
4. No more than 3 consecutive putts at the same speed (constrained shuffle)
5. `SessionProgress.adaptiveSequence` overrides `block.sequence` in `currentTargetSpeed`

### Integration

- `TrainingViewModel.startBlock()` calls `adaptiveEngine.generateAdaptiveSequence()` and sets `session.adaptiveSequence`
- `SessionProgress.currentTargetSpeed` checks `adaptiveSequence` before `block.sequence`
- `SessionProgress.recordPutt()` advances `currentSequenceIndex` for adaptive sequences

---

## Stats System

Stats track lifetime putting performance **independent of any training protocol**. Every putt (from training or Combine) feeds into the same unified stats.

### Core Data Entities

- **SpeedProfileData** — 18 rows (one per speed 3–20 MPH). Running aggregates: totalPutts, onTargetPutts, totalDeviation, totalSignedDeviation (for miss direction), sumSquaredDeviation (for std dev), sumActualSpeed, bestStreak, currentStreak, lastPracticedAt
- **DailySnapshotData** — one row per calendar day practiced. Totals, deviation, practice time. Powers trend charts.

### Integration Points

- `TrainingViewModel.recordPutt()` calls `statsService.recordPutt()` after every putt
- `CombineViewModel.recordShot()` calls `statsService.recordPutt()` for every Combine shot
- `TrainingViewModel.endSession()` and `CombineViewModel.completeGame()/endGame()` call `statsService.addPracticeTime()`
- `StatsService.migrateExistingData()` runs once on first launch to backfill from historical PuttRecordData

### Stats UI Screens

- `StatsDashboardView` — key metrics, "Needs Work" callout, speed ladder visual, quick links
- `TrendsView` — accuracy/deviation/volume line charts with 7D/30D/90D/All toggle
- `SpeedDetailView` — per-speed deep dive (accuracy, tendency, streaks, consistency)
- `SessionHistoryView` → `SessionDetailView` — session list with putt-by-putt drill-down
- `CombineStatsView` — score trend, high score, game history

### Reset

Stats reset is in Settings → Data → Reset Stats (double confirmation). Wipes SpeedProfileData and DailySnapshotData only. Training progress and PuttRecordData are unaffected.
