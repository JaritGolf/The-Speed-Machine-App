# Speed Machine — Skill Gating Implementation Prompt

You are the implementing engineer for a planned, fully-specified feature on the Speed Machine iOS app: a science-anchored skill-based progression gating system. The plan was designed and locked by Arthur (founder, Jarit Golf) in a prior session. Your job is to ship it.

## Before you start

1. **Read `CLAUDE.md` at the repo root.** It encodes critical project rules including: two parallel code targets (`SpeedMachineApp/SpeedMachineApp/` is primary, `SpeedMachine/` is secondary; keep both in sync), the live-session viewing-distance rule (5–6 feet → fonts must be large), the JSON sync rule (two copies of `speed-machine-training-program.json` must match), and the "target accuracy was removed" rule (preserve only plain-text `message` mentions).

2. **Read `SKILL_GATING_PLAN.md` at the repo root.** This is the authoritative spec — every decision is locked, every threshold is tuned. Do not relitigate it. If you find ambiguity, flag it; do not invent.

3. **Read these existing files before touching them** so your changes are surgical:
   - `SpeedMachineApp/SpeedMachineApp/ViewModels/TrainingViewModel.swift` — `completeBlock()`, `evaluateGateTest()`, `recordPutt()`, `isDayUnlocked()`
   - `SpeedMachineApp/SpeedMachineApp/Services/AdaptiveSpeedEngine.swift` — adaptive sequence generation
   - `SpeedMachineApp/SpeedMachineApp/Services/DataService.swift` — Core Data entities, especially `SpeedProfileData`
   - `SpeedMachineApp/SpeedMachineApp/Services/StatsService.swift` — telemetry pattern; `migrateExistingData()` is the model for the mastery-recompute migration
   - `SpeedMachineApp/SpeedMachineApp/Views/Training/TrainingSessionView.swift` — all live session views and the three header components live here
   - `SpeedMachineApp/SpeedMachineApp/Models/TrainingProgram.swift` — JSON models and `SessionProgress`
   - `SpeedMachineApp/SpeedMachineApp/Resources/speed-machine-training-program.json` — the program data

## What you are building

A four-layer gating system that prevents users from advancing through the 30-day training program when they haven't actually built the underlying skill. The system preserves engagement (Goldilocks principle) while enforcing genuine skill development. All five fundamental decisions are locked:

1. **Phase floors:** 40% / 50% / 60% / 65% / 70% / 75% across day bands 1–4, 5–9, 10–12, 13–18, 19–24, 25–30.
2. **Soft/hard cutover:** speed-based at the **10/11 MPH boundary**, not day-based. A block or gate test is hard-gated iff any target speed ≥ 11 MPH. Mixed pools: hardest speed wins.
3. **Override-spam tolerance:** unlimited soft overrides. Telemetry records every override for later tightening.
4. **Recovery day shape:** 4 blocks / ~12 minutes / 60% reps on weakest speed + 40% on adjacent speeds.
5. **Existing in-flight users:** retroactive mastery-tier recomputation from `PuttRecordData` on first launch after upgrade. Days already marked complete stay complete; new gating only affects forward motion. A one-time "Skill Reassessment" intro screen explains apparent regressions.

## The four layers (summary; full detail in SKILL_GATING_PLAN.md)

**Layer A — Per-speed Mastery Tiers.** Tier 0–4 derived from `SpeedProfileData`. Foundation for all other layers and the existing adaptive engine. Add `recentPutts`, `recentOnTargetPutts`, `tierOverride` to `SpeedProfileData`. 14-day decay rule (drops one tier, capped at Tier 1).

**Layer B — Per-block soft/hard gates.** At `completeBlock()`, evaluate block accuracy against per-block threshold (or phase-floor default). Soft → "Repeat / Continue anyway" UI with override always enabled. Hard → "Continue anyway" only enabled after 3 failed attempts; third retry auto-shortens to half rep count.

**Layer C — Per-speed adaptive lock.** A pool speed appears in adaptive sequences only if the user is at Tier 1+ on the speed below it (or on the highest speed of the previous zone for cross-zone transitions). The block still completes — locked speeds are filled with reps of the next-tier-down speed. Excludes gate tests, assessments, fixed-speed blocks, recovery, pressure with fixed speed, elimination ladder, combine, protocol-based.

**Layer D — Gate-test redesign.** Four-criterion test (all must hold): min in-zone overall, min in-zone per speed, average absolute deviation cap, max single-miss cap. Per-gate values are locked (table below). On hard-gate fail: auto-prescribe a generated Recovery Day; override only after 2 retries. Failure-reason routing: the four criteria are independent, so the result screen shows *which* failed and the remediation message changes accordingly.

## Locked tables — do not change these values

### Gate test criteria (Layer D)

| Gate | Day | Force | Protocol | Min overall | Per speed | Avg dev cap | Max miss |
|------|-----|-------|----------|-------------|-----------|-------------|----------|
| gate-zone1 | 5 | Soft | 3,4,5 MPH ×3 (9 putts) | 6 of 9 | ≥ 1 of 3 | ≤ 0.70 MPH | ≤ 1.25 MPH |
| gate-zone2 | 9 | Soft | 5,6,7 MPH ×4 (12 putts) | 8 of 12 | ≥ 2 of 4 | ≤ 0.70 MPH | ≤ 1.25 MPH |
| gate-zone3 | 12 | Hard | 8,9,10 MPH ×4 (12 putts) | 8 of 12 | ≥ 2 of 4 | ≤ 0.75 MPH | ≤ 1.20 MPH |
| gate-zone4 | 19 | Hard | 10,12,14 MPH ×4 (12 putts) | 9 of 12 | ≥ 2 of 4 | ≤ 0.80 MPH | ≤ 1.25 MPH |
| gate-zone5 | 25 | Hard | 15,16,17,18 MPH ×3 (12 putts) | 9 of 12 | ≥ 2 of 3 | ≤ 0.90 MPH | ≤ 1.30 MPH |

Note: `minPerSpeedInZone` is currently a single integer applied uniformly. If a future gate has uneven putts-per-speed, evolve to `[speed: int]`.

### Phase 1 block thresholds (Days 1–10)

| Day | Block | Type | Putts | Threshold |
|-----|-------|------|-------|-----------|
| 1 | 1A Free Exploration | exploration | 16 | **off** (skipGating) |
| 1 | 1B Finding 4 MPH | blocked | 16 | 40% |
| 1 | 1C Finding 5 MPH | blocked | 16 | 40% |
| 1 | 1D Alternating 4 and 5 | alternating | 16 | 40% |
| 2 | 2A 3 MPH Development | blocked | 20 | 40% |
| 2 | 2B Zone 1 Speed Development | blocked | 16 | 40% |
| 2 | 2C Zone 1 Speed Challenge | blocked | 16 | 40% |
| 2 | 2D Sequential Challenge | sequence | 12 | 40% |
| 3 | 3A Warm-Up Review | warmup | 12 | **off** |
| 3 | 3B Zone 1 Predictive Practice | predictive | 20 | 40% |
| 3 | 3C Zone 1 Predictive Focus | predictive | 20 | 40% |
| 3 | 3D Zone 1 Predictive Build | predictive | 20 | 40% |
| 4 | 4A Rapid Alternation | alternating | 24 | 40% |
| 4 | 4B Fine Discrimination | alternating | 24 | 40% |
| 5 | 5A Warm-Up | warmup | 12 | **off** |
| 5 | 5C 6 MPH Introduction | blocked | 20 | 50% |
| 5 | 5D 7 MPH Introduction | blocked | 20 | 50% |
| 5 | 5E Full Zone 1 Integration | random | 12 | 50% |
| 6 | 6A 6-7 MPH Blocked Practice | blocked | 24 | 50% |
| 6 | 6B Ladder Ascending | sequence | 16 | 50% |
| 6 | 6C Random Zone 1 | random | 24 | 50% |
| 6 | 6D Challenge Round | challenge | 8 | 50% |
| 7 | 7A Warm-Up | warmup | 16 | **off** |
| 7 | 7B Make 5 in a Row | pressure | variable | **built-in** (consecutiveRequired) |
| 7 | 7C Elimination Ladder | pressure | variable | **built-in** (elimination logic) |
| 7 | 7D Recovery Practice | recovery | 8 | **off** |
| 8 | 8A Zone 1 Mastery Drill | sequence | 32 | 50% |
| 8 | 8B Random Zone 1 Assessment | random | 24 | 50% |
| 9 | 9A Warm-Up | warmup | 12 | **off** |
| 9 | 9C 8 MPH Introduction | blocked | 16 | 55% |
| 9 | 9D 9 MPH Introduction | blocked | 16 | 55% |
| 9 | 9E 10 MPH Introduction | blocked | 12 | 55% |
| 9 | 9F Cool-Down | recovery | 8 | **off** |
| 10 | 10A Warm-Up | warmup | 16 | **off** |
| 10 | 10C Best Speed Challenge | challenge | 16 | 60% |

### Phase 2 block thresholds (Days 11–20)

Phase floors: Days 11–12 = 60%, Days 13–18 = 65%, Days 19–20 = 70%. Gate tests (12B, 19B) and assessment (20B) are excluded — they go through Layer D / assessment logic.

| Day | Block | Type | Putts | Threshold |
|-----|-------|------|-------|-----------|
| 11 | 11A Zone 1 Maintenance | random | 16 | 50% |
| 11 | 11B Zone 2 Blocked Practice | blocked | 32 | 55% |
| 11 | 11C Transition Practice | random | 16 | 55% |
| 12 | 12A Warm-Up | warmup | 12 | 50% |
| 12 | 12C 11 MPH Introduction | blocked | 24 | 55% |
| 12 | 12D 8-11 Integration | sequence | 20 | 60% |
| 12 | 12E Cool-Down | recovery | 8 | 55% |
| 13 | 13A Zone 1-2 Quick Review | random | 16 | 60% |
| 13 | 13B Zone 3 Reinforcement | blocked | 12 | 65% |
| 13 | 13C 12 MPH Introduction | blocked | 16 | 55% |
| 13 | 13D 13 MPH Introduction | blocked | 16 | 55% |
| 13 | 13E Zone 3 Integration | sequence | 12 | 60% |
| 14 | 14A Warm-Up | warmup | 16 | 60% |
| 14 | 14B 14 MPH Introduction | blocked | 20 | 55% |
| 14 | 14C Full Zone 3 Practice | random | 24 | 60% |
| 14 | 14D Cross-Zone Challenge | random | 20 | 65% |
| 15 | 15A Full Range Random | random | 32 | 60% |
| 15 | 15B Extreme Jumps | sequence | 20 | 55% |
| 15 | 15C Call Your Shot | reactive | 20 | 65% |
| 16 | 16A Zone Jumping | sequence | 24 | 60% |
| 16 | 16B Consecutive Challenge (ladder) | pressure | variable | **built-in** |
| 16 | 16C Reverse Ladder | sequence | 24 | 65% |
| 17 | 17A Warm-Up | warmup | 16 | 60% |
| 17 | 17B 7 in a Row Challenge | pressure | variable | **built-in** |
| 17 | 17C Elimination Tournament | pressure | variable | **built-in** |
| 17 | 17D Recovery | recovery | 8 | 60% |
| 18 | 18A Zone 3 Mastery Drill | sequence | 32 | 65% |
| 18 | 18B Gate Test Simulation | gate-sim | 24 | 70% |
| 18 | 18C Mental Preparation | blocked | 16 | 70% |
| 19 | 19A Warm-Up | warmup | 12 | 65% |
| 19 | 19C 15 MPH Introduction | blocked | 20 | 50% |
| 19 | 19D 16 MPH Introduction | blocked | 20 | 50% |
| 19 | 19E Cool-Down | recovery | 12 | 55% |
| 20 | 20A Warm-Up | warmup | 16 | 65% |
| 20 | 20C Best Speed Challenge | challenge | 16 | 70% |

### Phase 3 block thresholds (Days 21–30)

Phase floors: Days 21–24 = 70%, Days 25–30 = 75%. Gate test (25B) and final assessment (30B) excluded.

| Day | Block | Type | Putts | Threshold |
|-----|-------|------|-------|-----------|
| 21 | 21A Zone 1-3 Maintenance | random | 16 | 65% |
| 21 | 21B 15-16 MPH Reinforcement | blocked | 16 | 60% |
| 21 | 21C 17 MPH Introduction | blocked | 24 | 55% |
| 21 | 21D 15-17 Integration | sequence | 16 | 70% |
| 22 | 22A Warm-Up | warmup | 16 | 60% |
| 22 | 22B Zone 4 Reinforcement | blocked | 12 | 65% |
| 22 | 22C 18 MPH Introduction | blocked | 24 | 55% |
| 22 | 22D Zone 4 Full Integration | random | 20 | 65% |
| 23 | 23A Full Range Random | random | 24 | 65% |
| 23 | 23B Zone 4 Intensive | random | 24 | 65% |
| 23 | 23C Pressure Test | pressure | variable | **built-in** |
| 24 | 24A Zone 4 Peak Performance | sequence | 32 | 70% |
| 24 | 24B Gate Test Simulation | gate-sim | 24 | 70% |
| 24 | 24C Mental Preparation | blocked | 16 | 65% |
| 25 | 25A Warm-Up | warmup | 12 | 60% |
| 25 | 25C 19 MPH CAREFUL Introduction | blocked (safety) | 20 | 45% |
| 25 | 25D 17-19 Integration | sequence | 20 | 60% |
| 25 | 25E Cool-Down | recovery | 8 | 65% |
| 26 | 26A Full Range Review | random | 16 | 75% |
| 26 | 26B Zone 5 Reinforcement | blocked | 16 | 75% |
| 26 | 26C 20 MPH EXTREME CAUTION Introduction | blocked (safety) | 20 | 45% |
| 26 | 26D 18-20 Integration | sequence | 16 | 60% |
| 26 | 26E Cool-Down | recovery | 8 | 65% |
| 27 | 27A Complete Range Random | random | 32 | 65% |
| 27 | 27B Extreme Contrast | sequence | 20 | 60% |
| 27 | 27C Zone Sweeps | sequence | 20 | 70% |
| 28 | 28A Warm-Up | warmup | 16 | 70% |
| 28 | 28B Perfect 10 Challenge | pressure | variable | **built-in** |
| 28 | 28C Combine Mode Preview | combine | variable | **built-in** |
| 29 | 29A Warm-Up | warmup | 16 | 65% |
| 29 | 29B Competition Session 1 | combine | variable | **built-in** |
| 29 | 29C Brief Reset | recovery | 8 | 65% |
| 29 | 29D Competition Session 2 | combine | variable | **built-in** |
| 29 | 29E Competition Session 3 | combine | variable | **built-in** |
| 30 | 30A Warm-Up | warmup | 16 | 70% |
| 30 | 30C Victory Lap | celebration | 16 | **off** |

### Mastery tiers (Layer A)

| Tier | Reps | Lifetime accuracy | Std dev (MPH) |
|------|------|-------------------|---------------|
| 0 — Unpracticed | < 10 | n/a | n/a |
| 1 — Familiar | ≥ 10 | ≥ 40% | n/a |
| 2 — Competent | ≥ 20 | ≥ 60% | ≤ 0.8 |
| 3 — Proficient | ≥ 30 | ≥ 75% | ≤ 0.6 |
| 4 — Mastered | ≥ 40 | ≥ 85% | ≤ 0.5 |

## Non-negotiable UX requirement: persistent threshold strip

Every live session view (`ActiveSessionView`, `ExplorationSessionView`, `PressureSessionView`, `GateTestSessionView`, `LadderSessionView`, `MakeInRowSessionView`) must show a `BlockThresholdStrip` directly under the existing block header. The strip is visible at all times during the block — not revealed only at block-end.

**Render rules:**

- **Standard threshold blocks:** `IN ZONE: X / Y · PASS ≥ Z (P%)` with X being a live count.
- **Gate tests:** `IN ZONE: X / Y · PASS ≥ Zmin overall, ≥ Zper per speed` plus a second line `AVG DEV: D MPH (cap C)`.
- **Pressure (built-in):** native progress — `STREAK: X / Y` or `RUNG: X / Y` or `LIVES: X / Y`.
- **Combine:** `COMBINE — score not gated`.
- **Skipped (`skipGating: true`):** `FREE PRACTICE — no gate` in muted weight.

**Live color states** (color carried by the count + threshold value, not the strip itself):

- Below threshold, mathematically possible → neutral text. No alarm.
- At or above threshold → green count + small check glyph. Block does *not* end early; user keeps putting.
- Mathematically impossible to pass → amber. Block does *not* abort — finishing matters for rep volume.

**Sizing per CLAUDE.md viewing-distance rule:** primary count 32–40pt bold, labels 20–24pt heavy. The user is 5–6 feet from the screen.

`BlockTransitionView` is **excluded** from the threshold strip — that's the 3-second between-block screen with its own design language. On `SkillCheckResultView`, the strip's last state appears as a static summary at the top so the user sees the same numbers they saw at block-end.

## Build phases — ship each independently

Follow the rollout order from `SKILL_GATING_PLAN.md` §8. Each phase is a separately revertible merge.

### Phase 1: telemetry only (no enforcement)

**Goal:** capture the data needed to validate the proposed thresholds against real user behavior.

1. Add `recentPutts: Int16`, `recentOnTargetPutts: Int16`, `tierOverride: Int16` to `SpeedProfileData` (default 0/-1). Schema migration is straightforward.
2. Create new Core Data entity `BlockAttemptData`: `id: UUID`, `dayNumber: Int16`, `blockId: String`, `attemptNumber: Int16`, `zoneAccuracy: Float`, `passedThreshold: Bool`, `passedWithOverride: Bool`, `attemptedAt: Date`.
3. In `TrainingViewModel.completeBlock()`, write a `BlockAttemptData` row on every block completion. Compute `passedThreshold` against the locked thresholds for visibility but do NOT branch on it yet.
4. In `recordPutt()`, update `recentPutts` / `recentOnTargetPutts` (rolling cap at 20).
5. **Also implement the `BlockThresholdStrip` in this phase.** It surfaces threshold visibility before enforcement bites — users see what they're aiming at, you see telemetry.
6. Add a `MasteryService.swift` skeleton with `tier(forSpeed:)`, `recentAccuracy(forSpeed:)`, `phaseFloor(forDay:)`, `gateForce(forDay:)`. Compute, log, expose to UI in `StatsView` and `SpeedDetailView`. Do not gate on it.

Ship it. Two weeks of data validates that the threshold curve matches reality before enforcement.

### Phase 2: per-speed adaptive lock (Layer C)

**Goal:** invisible scaffolding — keeps unprepared speeds out of adaptive sequences.

1. Add `MasteryService.isSpeedUnlockedForAdaptive(_ s: Int, in pool: [Int]) -> Bool`.
2. In `AdaptiveSpeedEngine.generateAdaptiveSequence()`, filter the pool through `isSpeedUnlockedForAdaptive` before weighting. Locked speeds get filled with reps of the next-tier-down speed; the block still runs to its full putt count.
3. Excluded block types (do not filter): `gateTest`, `assessment`, fixed-speed `blocked`, `recovery`, pressure with fixed speed, elimination ladder, `combine`, protocol-based.
4. UI: on day-summary screen, surface "X MPH not yet introduced — keep building Y MPH" so users understand. No failure UI; this is invisible scaffolding.

Lowest user-visible friction. Ship to validate engine integration.

### Phase 3: soft gates (Days 1–12, Layer B partial)

**Goal:** enforce block thresholds in the soft phase. All overrides allowed unlimited.

1. Add `MasteryService.evaluateBlock(_ session: SessionProgress, block: TrainingBlock, day: Int) -> BlockEvaluation`. Returns pass/fail + the threshold used.
2. JSON schema additions (both copies of `speed-machine-training-program.json`): per-block optional `blockPassThreshold: Float`, optional `skipGating: Bool`. Update both files with the locked Phase 1–3 values from this prompt.
3. Top-level `phaseFloors` array in JSON.
4. In `TrainingViewModel.completeBlock()`, branch on `MasteryService.evaluateBlock()`. On fail, route to a new `SkillCheckResultView`.
5. `SkillCheckResultView` content:
   - "Block accuracy: X% (target: Y%). The next block builds on this."
   - Two buttons: **Repeat this block** (default, large) and **Continue anyway** (smaller, labeled "Override")
   - Override allowed unlimited; flagged in `BlockAttemptData` as `passedWithOverride: true`.
6. Two-week observation window after ship. Watch the `passedWithOverride` rate — if >40%, tighten copy.

### Phase 4: hard gates + Recovery days (Layer B remainder, Layer D)

**Goal:** hard enforcement for blocks/gates with target speed ≥ 11 MPH.

1. Extend `evaluateBlock()` with `gateForce` logic. Hard gates: "Continue anyway" only enabled after 3 failed attempts; third retry auto-shortens to half the rep count.
2. Replace `evaluateGateTest()` in `TrainingViewModel` with a four-criterion implementation in `MasteryService`. Use the locked gate-test table values verbatim.
3. JSON schema: replace `passRequirements.zoneAccuracy.minimum` with the new shape:
   ```json
   "passRequirements": {
     "minOverallInZone": 6,
     "minPerSpeedInZone": 1,
     "avgDeviationCapMph": 0.70,
     "maxSingleMissMph": 1.25
   }
   ```
   Apply the locked values to all five gates in both JSON copies.
4. Add `gateForce: "soft" | "hard"` to each gate test in JSON.
5. `GateTestResult` struct additions: `perSpeedAccuracy: [Int: Float]`, `avgAbsDeviation: Float`, `maxDeviation: Float`, `failureReasons: [GateFailureReason]` enum (zoneAccuracy, perSpeedFloor, deviationCap, catastrophicMiss).
6. Failure-reason routing: gate-test result screen shows *which* criterion failed and the remediation message branches accordingly.
7. New `RecoveryDayGenerator.swift`: produces a 4-block / ~12-min day on hard-gate failure. 60% reps on weakest tier-3-or-below speed in the failed zone, 40% on adjacent. Marked in stats but does NOT count against the 30-day day count for the user-facing program.
8. Cap auto-prescribed Recovery days at 1 per gate fail; subsequent failures simply re-attempt without a new Recovery prefix.

### Phase 5: existing-user migration

**Goal:** retroactive mastery-tier recomputation for users already in flight.

1. Add `MasteryService.recomputeFromHistory()`. On first launch after upgrade: walk every `PuttRecordData` row, replay running aggregates into `SpeedProfileData.recentPutts/recentOnTargetPutts`, compute tier per speed from scratch. Modeled on the existing `StatsService.migrateExistingData()` pattern.
2. **One-time "Skill Reassessment" intro screen** on first post-migration launch. Shows tier per speed, frames any apparent regression as "this is what the data actually says — let's build it back." User must tap acknowledge to proceed.
3. **No retroactive failure state.** Days marked complete stay complete. New gating only affects forward motion.

## Implementation rules

1. **Two-target sync.** Every code change touches both `SpeedMachineApp/SpeedMachineApp/` (primary) and `SpeedMachine/` (secondary). Every JSON change touches both `SpeedMachineApp/SpeedMachineApp/Resources/speed-machine-training-program.json` and the root reference copy. Note the `SpeedMachine/Resources/` copy uses a different schema (snake_case, `zones` instead of `speedZones`, per-block `tolerance` fields) — adapt accordingly.

2. **Live session UI sizing.** Every UI you add to a live session view must follow the 5–6 foot viewing distance rule from `CLAUDE.md`. Primary metric ≥ 80–100pt black weight. Secondary labels ≥ 24–32pt bold. Supporting info ≥ 20–24pt. Use `minimumScaleFactor` for edge cases, never shrink the base font.

3. **Block header format unchanged.** The existing "Day X: Block Y: Block Name" format on `SessionHeaderCompact` / `PressureHeaderCompact` / `GateTestHeaderCompact` stays. Threshold strip sits *under* the header, doesn't replace it.

4. **Stats are protocol-independent.** Per `CLAUDE.md`, stats track lifetime putting performance across all modes. The mastery system reads from `SpeedProfileData` (which feeds stats) — do not introduce a new per-day or per-protocol mastery store. The mastery tier travels with the user across training, Combine, and any future modes.

5. **Adaptive engine eligibility unchanged.** The existing block-type eligibility list in `AdaptiveSpeedEngine` (full / warmup / none) is correct. Layer C adds a *speed filter* on top of the existing weighting; it does not change which block types adapt.

6. **JSON-driven, not code-driven.** Thresholds, phase floors, gate criteria, and `skipGating` flags live in JSON. Phase floors are the fallback for any block not explicitly listed. Code reads JSON; code does not hardcode threshold values. (Acceptable to hardcode the phase-floor *table* itself in `MasteryService` if you parse it from JSON `phaseFloors` lazily — your call, but the JSON is the source of truth.)

7. **No `localStorage`-style ephemeral state.** This is a native app — use Core Data for persistence and `@Published` ViewModels for live state. Do not introduce singletons that store gating state in memory only.

8. **Tests.** Each phase ships with at least one unit test:
   - Phase 1: `MasteryService.tier(forSpeed:)` returns the expected tier for synthetic `SpeedProfileData`.
   - Phase 2: `AdaptiveSpeedEngine` with a Tier-0 user filters the pool correctly.
   - Phase 3: `evaluateBlock()` returns pass/fail correctly across the 35 Phase 1 blocks.
   - Phase 4: `evaluateGateTest()` returns the right `failureReasons` for each contrived failure mode.
   - Phase 5: `recomputeFromHistory()` produces the expected tier from a fixed `PuttRecordData` set.

## Verification before each merge

For every phase, before declaring done, verify:

1. App builds and launches without crash on the primary target.
2. Both JSON copies parse without error; assert this with a small unit test.
3. Existing flows (start a session, complete a block, finish a day, return home) work end-to-end.
4. Stats reset still works (Settings → Data → Reset Stats wipes only `SpeedProfileData` and `DailySnapshotData`; training progress and `PuttRecordData` unaffected).
5. The relevant unit test for the phase passes.
6. Take a screenshot of any new live-session UI and verify text is readable from a simulated 5–6 foot distance (eyeball: text at the top of the screen should be readable when the simulator window is sized to fit a real iPhone-distance frame).

## What success looks like

- A user with weak Zone 1 accuracy cannot brute-force their way to Day 30 by ignoring zone hits.
- A user who passes Day 5's gate cleanly and is on track sees no friction beyond the threshold strip.
- A user who fails Day 19's hard gate gets a Recovery Day generated, runs it, and re-attempts — no manual intervention needed.
- A user who returns from a 3-week break sees their Tier 4 mastery on 8 MPH drop to Tier 3, gets a "rebuild" framing, and isn't surprised when the adaptive engine eases them back in.
- The "needs work" callout in Stats highlights speeds that genuinely need work, not speeds that haven't been practiced because the user is on Day 6.

## When in doubt

- Read `SKILL_GATING_PLAN.md` first.
- If the plan is silent or ambiguous on a specific implementation question, prefer the option that:
  1. Preserves existing user data and the existing 30-day flow,
  2. Errs on the side of more telemetry rather than less,
  3. Leaves the user with override agency rather than locking them out,
  4. Keeps the live-session UI legible from 5–6 feet.
- Surface ambiguities as comments in the PR description rather than picking silently.

## Project context (for grounding)

- App: Speed Machine, an iOS SwiftUI putting trainer by Jarit Golf.
- Architecture: MVVM, Core Data persistence, BLE for putt speed.
- Founder: Arthur (`arthur@jaritgolf.com`).
- The `speed-machine-training-program.json` is the single source of truth for training content. Two copies exist; sync rules in `CLAUDE.md`.
- Tolerance: uniform ±0.5 MPH across all zones (not zone-dependent — confirmed in `Constants.swift`).
- Stats system already tracks lifetime per-speed performance via `SpeedProfileData`. The gating system reads from this — no parallel data store.

Build it carefully. Ship one phase at a time. Each phase is independently revertible.
