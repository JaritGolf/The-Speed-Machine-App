# Speed Machine App — Claude Context

## Working Preferences

- **Arthur does not use the Terminal.** Never instruct him to run terminal commands manually. If anything requires a shell command (clearing DerivedData, running scripts, installing packages, etc.), Claude should run it directly using its Bash tool and report the result.

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

### Two Code Targets

There are two parallel directories:
- `SpeedMachineApp/SpeedMachineApp/` — the **primary active target** (this is what gets built)
- `SpeedMachine/` — an older/secondary target. Keep in sync when making changes.

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

All zones use a **uniform ±0.5 MPH tolerance** — this was intentionally set equal across all zones.

| Zone | Name | Speed Range | Tolerance |
|------|------|-------------|-----------|
| 1 | Touch | 3–7 MPH | ±0.5 MPH |
| 2 | Moderate | 8–10 MPH | ±0.5 MPH |
| 3 | Firm | 11–14 MPH | ±0.5 MPH |
| 4 | Power | 15–18 MPH | ±0.5 MPH |
| 5 | Maximum | 19–20 MPH | ±0.5 MPH |

Tolerance is stored in three places — keep all in sync when changing:
1. `Constants.swift` (both targets) — `SpeedZone.zones` array
2. `speed-machine-training-program.json` (both locations) — `speedZones` array
3. `SpeedMachine/Resources/speed-machine-training-program.json` — `zones` array + per-block `tolerance` fields

---

## Training Program Data

The JSON is the source of truth for all training content. Two copies exist:
- `SpeedMachineApp/SpeedMachineApp/Resources/speed-machine-training-program.json` — used by the active build target
- `speed-machine-training-program.json` (root) — master/reference copy

Keep both in sync. The `SpeedMachine/Resources/` JSON has a slightly different schema (uses `zones` instead of `speedZones`, snake_case keys, per-block `tolerance` fields).

### Terminology: Tracks not Days

The 30 structured program elements are called **Tracks** (not Days). This reflects that some tracks may take more than one calendar day to complete. The terminology throughout the codebase, UI, and JSON uses "Track/Tracks":
- UI: "Track 1", "Track 7: Block 3: ..."
- Swift model: `TrainingTrack` struct, `track.number`, `selectedTrack`
- JSON key: `"track"` (the number), top-level `"tracks"` array
- Calendar-based stats (streaks, DailySnapshot, trend charts) still use "day" internally since they measure calendar-day activity, not track completion.

### Target Accuracy

**Target accuracy has been removed as a metric and requirement throughout the app.** It no longer appears in `PassRequirements`, `successMetrics`, or any data-driven field. The only remaining mentions are in plain-text `message` fields inside warning/safety blocks — these are intentional and should be preserved.

---

## Block Header Format

All live session headers display: `"Track X: Block Y: Block Name"`

- `SessionHeaderCompact` — standard/exploration/ladder/make-in-row blocks (BLE dot + text)
- `PressureHeaderCompact` — pressure blocks (⚡ bolt icon + text in red)
- `GateTestHeaderCompact` — gate test blocks (🏁 flag icon + text in blue)

Block number is always computed from the block's index in `track.blocks`, not stored directly.

---

## Gate Tests

Gate tests evaluate pass/fail based on **zone accuracy only** (`zoneAccuracy.minimum` putts in zone). Target accuracy is not evaluated.

Gate test tracks: 5, 9, 12, 19, 25, 30.

---

## Key Decisions Log

- **Uniform ±0.5 MPH tolerance across all zones** — applied to make the standard consistent regardless of speed zone
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
