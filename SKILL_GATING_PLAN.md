# Skill-Based Progression Gating — Plan

**Status:** proposal, not yet implemented
**Decisions baked in:** tiered enforcement (soft early, hard late), per-block + per-speed gating, plan-only deliverable

---

## 1. Diagnosis — what gates progression today

Verified by reading `TrainingViewModel.swift`, `AdaptiveSpeedEngine.swift`, `DataService.swift`, and the program JSON.

**Block completion is putt-count-only.** `TrainingViewModel.completeBlock()` (line 272) runs as soon as the configured number of putts is recorded. There is no skill check. A user can finish a block having missed the zone on every single putt and still advance to the next block, with `BlockTransitionView` showing for 4 seconds before the next block auto-starts.

**Day-to-day progression is linear with one gate.** `isDayUnlocked()` (lines 53–77) only requires the previous day to be marked complete and, if the previous day contained an official gate test, that the gate test was passed. There is no skill-state check beyond that.

**Gate tests use a single weak criterion.** `evaluateGateTest()` (lines 418–476) only checks `session.inZonePutts >= passRequirements.zoneAccuracy.minimum`. The Day 5 (Zone 1) gate, for example, requires 5 of 9 putts in zone — **a 56% pass rate**. That number is below most mastery-learning floors and well below tour-pro speed-control consistency. There is no check on:
  - Standard deviation of the 9 putts
  - Per-speed accuracy within the protocol (a user can ace 3 MPH and bomb 5 MPH and still pass)
  - Magnitude of misses (a 3-MPH miss counts the same as a 0.6-MPH miss)
  - Tendency / signed bias

**The adaptive engine never blocks a speed.** `AdaptiveSpeedEngine` re-weights speeds (3.0× / 2.0× / 1.0× / 0.5× / 1.5× unpracticed) but every speed in a block's `adaptivePool` always appears in the sequence, regardless of whether the user has demonstrated competence at the easier speeds first.

**The data we need already exists.** `SpeedProfileData` (DataService.swift:445–454) already tracks per-speed `totalPutts`, `onTargetPutts`, `totalDeviation`, `totalSignedDeviation`, `sumSquaredDeviation`, `sumActualSpeed`, `bestStreak`, `currentStreak`, and `lastPracticedAt`. Computed `accuracy` and `standardDeviation` are exposed. **There is no missing telemetry — the gating layer simply doesn't read it.**

**Net.** The system today is a putt-count timer with one easy bottleneck every 5–7 days. A user can be objectively unprepared and still cruise to Day 30.

---

## 2. Science anchors — what good gating should do

Five evidence threads from the literature inform the design.

**Challenge Point Framework (Guadagnoli & Lee, 2004).** Optimal motor learning happens at *moderate functional task difficulty* calibrated to the learner's current skill. Too easy = no new information to encode; too hard = the learner can't process the available information. Engagement and learning peak in the same zone. This is the formal name for the Goldilocks principle.

**Mastery learning research.** A common criterion is 80% accuracy across 3 consecutive observations, but follow-up retention studies show 80% deteriorates rapidly post-training while 90–100% criteria maintain skill for at least a month. Implication: **the threshold should rise late in a program**, not stay flat.

**Progressive, individually adjusted difficulty.** A 2020 *Scientific Reports* study trained two groups on a motor task — one constant difficulty, one progressively adjusted to the individual. The progressive group showed **2× the performance gain at advanced task levels** plus measurable corticospinal plasticity. Implication: gating must be personalized, not group-policy.

**Variable / random practice (contextual interference).** Variable practice degrades acquisition slightly but improves retention and transfer. The app's `AdaptiveSpeedEngine` already does this. Gating logic should preserve variability — don't punish the user for slower acquisition curves that are actually producing better long-term skill.

**Real-world putting consistency.** Tour-pro impact-ball-speed range on an 8-foot putt is roughly **1.29 MPH** for a successful putt. The app's ±0.5 MPH zone tolerance is therefore tighter than tour-level variance — a meaningful target, but proof that 100% accuracy is unrealistic. Gating thresholds should respect this ceiling.

**Sources** are listed at the end.

---

## 3. The proposed system — three coordinated layers

Three independent gating layers, each calibrated to the same per-speed mastery state.

### Layer A — Per-speed Mastery Tiers (the foundation)

Every individual speed (3–20 MPH) gets a tier derived from `SpeedProfileData`. This becomes the source of truth that all three gating layers and the existing adaptive engine consult.

| Tier | Reps | Lifetime accuracy | Std dev (MPH) | Notes |
|------|------|-------------------|---------------|-------|
| 0 — Unpracticed | < 10 | n/a | n/a | Default state |
| 1 — Familiar | ≥ 10 | ≥ 40% | n/a | Demonstrated basic control |
| 2 — Competent | ≥ 20 | ≥ 60% | ≤ 0.8 | Below current "weak" threshold |
| 3 — Proficient | ≥ 30 | ≥ 75% | ≤ 0.6 | Matches existing `moderateThreshold` |
| 4 — Mastered | ≥ 40 | ≥ 85% | ≤ 0.5 | Std dev within zone tolerance |

Reps and lifetime accuracy already live in `SpeedProfileData`. We add one field — `recentAccuracy` (rolling last 20 reps) — to detect form drops without resetting lifetime stats.

**Decay rule.** A speed not practiced in 14+ days drops one tier (capped at Tier 1). This prevents stale mastery from gating future progression unfairly when a user returns from a break.

### Layer B — Per-block soft/hard gates

Triggered at `completeBlock()` for every non-gate-test block that has an evaluable target speed or zone.

**Block evaluation criterion** (Goldilocks-anchored, per CPF):
- Block accuracy (zone hits / total putts in block) ≥ phase-floor

**Phase floors** (rises with the program, matching mastery-learning retention research):

| Days | Floor |
|------|-------|
| 1–4 | 40% |
| 5–9 | 50% |
| 10–12 | 60% |
| 13–18 | 65% |
| 19–24 | 70% |
| 25–30 | 75% |

**Soft vs. hard force is determined by speed, not day.** A block is soft-gated if its highest target speed is **≤ 10 MPH** (Zones 1–2 — Touch and Moderate). A block is hard-gated if any target speed is **≥ 11 MPH** (Zones 3–5 — Firm, Power, Maximum). For mixed-speed pools, the rule is "hardest speed wins" — if the pool contains an 11+ MPH speed, the block is hard-gated even if most putts will be slower.

This anchors the cutover to the underlying biomechanical break (lag/touch feel → firm/aggressive control) rather than calendar day, so a user who races ahead or lags behind the 30-day cadence gets the right enforcement for the skill they're actually attempting.

**Effect on the existing gate-test days:**

| Gate | Day | Speeds tested | Force |
|------|-----|---------------|-------|
| Zone 1 | 5 | 3–7 MPH | Soft |
| Zone 2 | 9 | 8–10 MPH | Soft |
| Zone 3 intro | 12 | 11+ MPH | **Hard** |
| Zone 3 full | 19 | 11–14 MPH | Hard |
| Zone 4 | 25 | 15–18 MPH | Hard |
| Final | 30 | full ladder | Hard |

**Soft gate UX.** Block ends below floor → `SkillCheckResultView` slides in (replaces silent transition):
- Shows: "Block accuracy: 42% (target: 50%). The next block builds on this."
- Two buttons: **"Repeat this block"** (default, large) and **"Continue anyway"** (smaller, labeled "Override")
- Override allowed; flagged in `BlockAttemptData` as `passedWithOverride: true` so retention can be analyzed later.

**Hard gate UX.** Same screen, but the "Continue anyway" button is **only enabled after 3 failed attempts on the same block**. Until then the only forward action is "Repeat." This preserves the Goldilocks principle — the user is never trapped, but they can't spam past the gate.

**Critical: no infinite-loop trap.** After 3 attempts at the same block, the third retry auto-shortens to half the rep count (the user has now done 2× the putts at this skill); failing the third unlocks the override path. Prevents frustration spiral.

#### Per-block thresholds — Phase 1 (locked)

The phase-floor table above is the *default* a block falls back to. Each block can override that floor in the JSON via `blockPassThreshold`, or opt out entirely via `skipGating: true`. Phase 1 (Days 1–10) values were tuned interactively and are locked below. Phase 2 and Phase 3 will be tuned the same way in subsequent passes.

| Day | Block | Type | Putts | Threshold | In-zone required |
|-----|-------|------|-------|-----------|------------------|
| 1 | 1A Free Exploration | exploration | 16 | **off** | — |
| 1 | 1B Finding 4 MPH | blocked | 16 | 40% | ≥ 7 of 16 |
| 1 | 1C Finding 5 MPH | blocked | 16 | 40% | ≥ 7 of 16 |
| 1 | 1D Alternating 4 and 5 | alternating | 16 | 40% | ≥ 7 of 16 |
| 2 | 2A 3 MPH Development | blocked | 20 | 40% | ≥ 8 of 20 |
| 2 | 2B Zone 1 Speed Development | blocked | 16 | 40% | ≥ 7 of 16 |
| 2 | 2C Zone 1 Speed Challenge | blocked | 16 | 40% | ≥ 7 of 16 |
| 2 | 2D Sequential Challenge | sequence | 12 | 40% | ≥ 5 of 12 |
| 3 | 3A Warm-Up Review | warmup | 12 | **off** | — |
| 3 | 3B Zone 1 Predictive Practice | predictive | 20 | 40% | ≥ 8 of 20 |
| 3 | 3C Zone 1 Predictive Focus | predictive | 20 | 40% | ≥ 8 of 20 |
| 3 | 3D Zone 1 Predictive Build | predictive | 20 | 40% | ≥ 8 of 20 |
| 4 | 4A Rapid Alternation | alternating | 24 | 40% | ≥ 10 of 24 |
| 4 | 4B Fine Discrimination | alternating | 24 | 40% | ≥ 10 of 24 |
| 5 | 5A Warm-Up | warmup | 12 | **off** | — |
| 5 | 5C 6 MPH Introduction | blocked | 20 | 50% | ≥ 10 of 20 |
| 5 | 5D 7 MPH Introduction | blocked | 20 | 50% | ≥ 10 of 20 |
| 5 | 5E Full Zone 1 Integration | random | 12 | 50% | ≥ 6 of 12 |
| 6 | 6A 6-7 MPH Blocked Practice | blocked | 24 | 50% | ≥ 12 of 24 |
| 6 | 6B Ladder Ascending | sequence | 16 | 50% | ≥ 8 of 16 |
| 6 | 6C Random Zone 1 | random | 24 | 50% | ≥ 12 of 24 |
| 6 | 6D Challenge Round | challenge | 8 | 50% | ≥ 4 of 8 |
| 7 | 7A Warm-Up | warmup | 16 | **off** | — |
| 7 | 7B Make 5 in a Row | pressure | variable | **built-in** | consecutiveRequired (existing) |
| 7 | 7C Elimination Ladder | pressure | variable | **built-in** | elimination logic (existing) |
| 7 | 7D Recovery Practice | recovery | 8 | **off** | — |
| 8 | 8A Zone 1 Mastery Drill | sequence | 32 | 50% | ≥ 16 of 32 |
| 8 | 8B Random Zone 1 Assessment | random | 24 | 50% | ≥ 12 of 24 |
| 9 | 9A Warm-Up | warmup | 12 | **off** | — |
| 9 | 9C 8 MPH Introduction | blocked | 16 | **55%** | ≥ 9 of 16 |
| 9 | 9D 9 MPH Introduction | blocked | 16 | **55%** | ≥ 9 of 16 |
| 9 | 9E 10 MPH Introduction | blocked | 12 | **55%** | ≥ 7 of 12 |
| 9 | 9F Cool-Down | recovery | 8 | **off** | — |
| 10 | 10A Warm-Up | warmup | 16 | **off** | — |
| 10 | 10C Best Speed Challenge | challenge | 16 | 60% | ≥ 10 of 16 |

**Reading the curve.**

- **Block thresholds track the phase floor for Days 1–8.** No deviation — the bands hold cleanly through the first two-thirds of Phase 1.
- **Day 9 sits 5 points above the phase floor (55% vs 50%).** This is a deliberate bump on the three Zone 2 introduction blocks (8/9/10 MPH) because Day 9 also contains the Zone 2 gate test. A user who passes the gate but is sloppy on the introduction blocks would carry weak Zone 2 form into Day 10+. The bump enforces a tighter Day 9 standard than the floor would allow.
- **Day 10 jumps to 60%, matching the next phase band.** Day 10 is the Phase 1 assessment day; the one tunable block (10C Best Speed Challenge) gets evaluated at the entry-criterion for Phase 2 rather than the exit-criterion of Phase 1. Effectively a leading indicator — pass at the new band before you cross the line.
- **Twelve of thirty-five Phase 1 blocks have gating off** (warmups, recoveries, exploration, and the two pressure blocks with built-in criteria). About a third of Phase 1 is intentionally ungated, preserving the Goldilocks principle — early in the program, a meaningful fraction of practice is non-evaluative by design.

#### Per-block thresholds — Phase 2 (locked)

Phase 2 (Days 11–20) values were tuned interactively in the same way. Gate tests (Day 12B, Day 19B) and the Phase 2 Assessment block (Day 20B) are evaluated by Layer D / their own assessment logic and are excluded from this table. The phase-floor defaults that anchor each day are: Days 11–12 = 60%, Days 13–18 = 65%, Days 19–20 = 70%.

| Day | Block | Type | Putts | Threshold | In-zone required |
|-----|-------|------|-------|-----------|------------------|
| 11 | 11A Zone 1 Maintenance | random | 16 | 50% | ≥ 8 of 16 |
| 11 | 11B Zone 2 Blocked Practice | blocked | 32 | 55% | ≥ 18 of 32 |
| 11 | 11C Transition Practice | random | 16 | 55% | ≥ 9 of 16 |
| 12 | 12A Warm-Up | warmup | 12 | 50% | ≥ 6 of 12 |
| 12 | 12C 11 MPH Introduction | blocked | 24 | 55% | ≥ 14 of 24 |
| 12 | 12D 8-11 Integration | sequence | 20 | 60% | ≥ 12 of 20 |
| 12 | 12E Cool-Down | recovery | 8 | 55% | ≥ 5 of 8 |
| 13 | 13A Zone 1-2 Quick Review | random | 16 | 60% | ≥ 10 of 16 |
| 13 | 13B Zone 3 Reinforcement | blocked | 12 | 65% | ≥ 8 of 12 |
| 13 | 13C 12 MPH Introduction | blocked | 16 | 55% | ≥ 9 of 16 |
| 13 | 13D 13 MPH Introduction | blocked | 16 | 55% | ≥ 9 of 16 |
| 13 | 13E Zone 3 Integration | sequence | 12 | 60% | ≥ 8 of 12 |
| 14 | 14A Warm-Up | warmup | 16 | 60% | ≥ 10 of 16 |
| 14 | 14B 14 MPH Introduction | blocked | 20 | 55% | ≥ 11 of 20 |
| 14 | 14C Full Zone 3 Practice | random | 24 | 60% | ≥ 15 of 24 |
| 14 | 14D Cross-Zone Challenge | random | 20 | 65% | ≥ 13 of 20 |
| 15 | 15A Full Range Random | random | 32 | 60% | ≥ 20 of 32 |
| 15 | 15B Extreme Jumps | sequence | 20 | 55% | ≥ 11 of 20 |
| 15 | 15C Call Your Shot | reactive | 20 | 65% | ≥ 13 of 20 |
| 16 | 16A Zone Jumping | sequence | 24 | 60% | ≥ 15 of 24 |
| 16 | 16B Consecutive Challenge (ladder) | pressure | variable | **built-in** | ladder logic (existing): reach end speed in one unbroken run |
| 16 | 16C Reverse Ladder | sequence | 24 | 65% | ≥ 16 of 24 |
| 17 | 17A Warm-Up | warmup | 16 | 60% | ≥ 10 of 16 |
| 17 | 17B 7 in a Row Challenge | pressure | variable | **built-in** | consecutiveRequired (existing): 7 in a row in zone |
| 17 | 17C Elimination Tournament | pressure | variable | **built-in** | elimination logic (existing): in-zone count before 3 lives spent |
| 17 | 17D Recovery | recovery | 8 | 60% | ≥ 5 of 8 |
| 18 | 18A Zone 3 Mastery Drill | sequence | 32 | 65% | ≥ 21 of 32 |
| 18 | 18B Gate Test Simulation | gate-sim | 24 | 70% | ≥ 17 of 24 |
| 18 | 18C Mental Preparation | blocked | 16 | 70% | ≥ 12 of 16 |
| 19 | 19A Warm-Up | warmup | 12 | 65% | ≥ 8 of 12 |
| 19 | 19C 15 MPH Introduction | blocked | 20 | 50% | ≥ 10 of 20 |
| 19 | 19D 16 MPH Introduction | blocked | 20 | 50% | ≥ 10 of 20 |
| 19 | 19E Cool-Down | recovery | 12 | 55% | ≥ 7 of 12 |
| 20 | 20A Warm-Up | warmup | 16 | 65% | ≥ 11 of 16 |
| 20 | 20C Best Speed Challenge | challenge | 16 | 70% | ≥ 12 of 16 |

**Reading the curve.**

- **Phase 2 has no `skipGating: true` blocks.** Every standard practice block is evaluated by Layer B's percentage threshold, including warmups and recovery. This is a deliberate shift from Phase 1, where ~⅓ of blocks were ungated. By Day 11 the user has 10 days of feel-building behind them — warmups now serve as a calibration check (am I ready to drive harder today?) rather than free exploration. Pressure blocks (16B, 17B, 17C) are the only Phase 2 blocks Layer B doesn't touch; they keep their existing native success criteria as in Phase 1.
- **Pressure blocks (16B, 17B, 17C) keep their built-in success criteria.** Same pattern as Phase 1's 7B and 7C: ladder reach, consecutive streak, and elimination score are evaluated by the existing pressure-block logic, not the new percentage-threshold field. They have no fixed putt count by design and are best judged on their native game terms. Layer B's threshold logic explicitly skips them.
- **The 10/11 MPH cutover shows up vividly inside Phase 2.** Days 11–12 sit below their 60% phase floor on most blocks (50–55%) — these are the last few softly-gated practice days at the Zone 1–2 boundary, and the lower thresholds reflect that. From Day 13 onward, where 11+ MPH Zone 3 practice begins in earnest and gating becomes hard-enforced, thresholds either match the phase floor or sit above it.
- **New-speed introduction blocks dip 10 points below their day's floor.** 12C (11 MPH), 13C (12 MPH), 13D (13 MPH), 14B (14 MPH), 19C (15 MPH), and 19D (16 MPH) are all the first time the user has ever seen that target speed. Each gets a relaxed threshold (50–55%) on the day of introduction. The day after, the speed appears in mixed-pool blocks at the full phase-floor rate. This protects the introduction day from auto-failing — being terrible at a speed you've never seen before is information, not a gate failure.
- **Day 18 is the strictest Phase 2 day.** All three blocks sit at 65–70%. Day 18 is the gate-prep day — the day's *purpose* is to confirm gate-test readiness, so 18B (the gate simulation) and 18C (mental prep at gate-target speeds) match the Day 19 gate's accuracy expectations. A user who can't clear 70% on the simulation will not pass tomorrow's official gate, and we'd rather they know that today than push through and fail the official record.
- **Day 19 dips again because of the new-speed rule.** 19C and 19D introduce 15 and 16 MPH. The day's phase floor is 70% but those two blocks land at 50% — same logic as 12C/13C/13D/14B, applied to the Zone 4 transition. The warmup and cool-down on Day 19 stay closer to the floor (65%/55%) because they cover already-established speeds.
- **Day 20 (Phase 2 Assessment day) flags the entry criterion for Phase 3.** The non-assessment blocks (20A warmup, 20C Best Speed Challenge) sit at 65–70% — the user's strongest speed should be at or above that to comfortably enter the Mastery phase.

#### Per-block thresholds — Phase 3 (locked)

Phase 3 (Days 21–30) closes out the program. Excluded entirely from this table: the Zone 5 official gate test (Day 25B → Layer D) and the Final Assessment (Day 30B → its own assessment logic). Built-in blocks — pressure (23C, 28B) and Combine (28C, 29B/29D/29E) — appear in the table for completeness but are evaluated by existing logic, not by Layer B's percentage threshold. Phase-floor defaults: Days 21–24 = 70%, Days 25–30 = 75%.

| Day | Block | Type | Putts | Threshold | In-zone required |
|-----|-------|------|-------|-----------|------------------|
| 21 | 21A Zone 1-3 Maintenance | random | 16 | 65% | ≥ 11 of 16 |
| 21 | 21B 15-16 MPH Reinforcement | blocked | 16 | 60% | ≥ 10 of 16 |
| 21 | 21C 17 MPH Introduction | blocked | 24 | 55% | ≥ 14 of 24 |
| 21 | 21D 15-17 Integration | sequence | 16 | 70% | ≥ 12 of 16 |
| 22 | 22A Warm-Up | warmup | 16 | 60% | ≥ 10 of 16 |
| 22 | 22B Zone 4 Reinforcement | blocked | 12 | 65% | ≥ 8 of 12 |
| 22 | 22C 18 MPH Introduction | blocked | 24 | 55% | ≥ 14 of 24 |
| 22 | 22D Zone 4 Full Integration | random | 20 | 65% | ≥ 13 of 20 |
| 23 | 23A Full Range Random | random | 24 | 65% | ≥ 16 of 24 |
| 23 | 23B Zone 4 Intensive | random | 24 | 65% | ≥ 16 of 24 |
| 23 | 23C Pressure Test | pressure | variable | **built-in** | 5-in-a-row at adaptive challenge speed (existing) |
| 24 | 24A Zone 4 Peak Performance | sequence | 32 | 70% | ≥ 23 of 32 |
| 24 | 24B Gate Test Simulation | gate-sim | 24 | 70% | ≥ 17 of 24 |
| 24 | 24C Mental Preparation | blocked | 16 | 65% | ≥ 11 of 16 |
| 25 | 25A Warm-Up | warmup | 12 | 60% | ≥ 8 of 12 |
| 25 | 25C 19 MPH CAREFUL Introduction | blocked (safety) | 20 | 45% | ≥ 9 of 20 |
| 25 | 25D 17-19 Integration | sequence | 20 | 60% | ≥ 12 of 20 |
| 25 | 25E Cool-Down | recovery | 8 | 65% | ≥ 6 of 8 |
| 26 | 26A Full Range Review | random | 16 | 75% | ≥ 12 of 16 |
| 26 | 26B Zone 5 Reinforcement | blocked | 16 | 75% | ≥ 12 of 16 |
| 26 | 26C 20 MPH EXTREME CAUTION Introduction | blocked (safety) | 20 | 45% | ≥ 9 of 20 |
| 26 | 26D 18-20 Integration | sequence | 16 | 60% | ≥ 10 of 16 |
| 26 | 26E Cool-Down | recovery | 8 | 65% | ≥ 6 of 8 |
| 27 | 27A Complete Range Random | random | 32 | 65% | ≥ 21 of 32 |
| 27 | 27B Extreme Contrast | sequence | 20 | 60% | ≥ 12 of 20 |
| 27 | 27C Zone Sweeps | sequence | 20 | 70% | ≥ 14 of 20 |
| 28 | 28A Warm-Up | warmup | 16 | 70% | ≥ 12 of 16 |
| 28 | 28B Perfect 10 Challenge | pressure | variable | **built-in** | 10 consecutive on-target + in-zone (existing) |
| 28 | 28C Combine Mode Preview | combine | variable | **built-in** | Combine score (existing scoring) |
| 29 | 29A Warm-Up | warmup | 16 | 65% | ≥ 11 of 16 |
| 29 | 29B Competition Session 1 | combine | variable | **built-in** | Combine score (existing scoring) |
| 29 | 29C Brief Reset | recovery | 8 | 65% | ≥ 6 of 8 |
| 29 | 29D Competition Session 2 | combine | variable | **built-in** | Combine score (compare to S1) |
| 29 | 29E Competition Session 3 | combine | variable | **built-in** | Combine score (optional) |
| 30 | 30A Warm-Up | warmup | 16 | 70% | ≥ 12 of 16 |
| 30 | 30C Victory Lap | celebration | 16 | **off** | — |

**Reading the curve.**

- **Day 25 and Day 26 are the only days with safety-overridden thresholds.** 25C (19 MPH first introduction) and 26C (20 MPH first introduction) sit at 45% — 30 points below their day's phase floor. This is deliberate and tracks the JSON's existing safety design: those two blocks have explicit emergency-stop protocols ("3 consecutive misses → reduce to 16 MPH immediately" / "stop and do not attempt again today"), and the program's own success metrics for these speeds are 35–40%. Layer B's threshold respects that envelope rather than fighting it. Pushing these higher would create a gating system at war with the safety system.
- **Day 26 is the strictest day in Phase 3 on already-known speeds.** 26A (Full Range Review) and 26B (Zone 5 Reinforcement at 17–20 MPH adaptive) both sit at full 75% phase floor. The logic: by Day 26 the user has cleared every official gate and seen 18 MPH for four days. If they can't hold 75% on the speeds they already know, introducing 20 MPH today is a bad idea. The strict known-speed bar is the unstated entry condition for the lenient new-speed bar.
- **Day 24 is the gate-prep day** — same pattern as Day 18 in Phase 2. All three blocks at 65–70% with the gate simulation (24B) at the highest. A user who can't clear 70% on the simulation today is unlikely to pass the official Zone 5 gate tomorrow, and rerunning Day 24 today is a much smaller setback than failing 25B and burning the remediation flow.
- **Pressure and Combine blocks are universally built-in across Phase 3.** Six blocks in total (23C, 28B, 28C, 29B, 29D, 29E) — the most of any phase. By the time a user is in Phase 3, they're being evaluated on the program's native success criteria as much as on Layer B's percentage thresholds. This is consistent with the Phase 1 (7B/7C) and Phase 2 (16B/17B/17C) treatment — pressure-style blocks are pass/fail by their game terms, not by aggregate accuracy.
- **Victory Lap (30C) is the only Phase 3 block with `skipGating: true`.** The user has just finished the Final Assessment; this is the program's coda. Same spirit as Day 1's Free Exploration block — not every minute of putting needs a passing grade.
- **Days 28–30 (post-gate, pre-graduation) hold a moderate band.** Warmups at 65–70%, recovery at 65%. No pressure, no introduction surprises — just the user demonstrating sustained performance. The Combine sessions on Days 28–29 carry the load on those days; the surrounding tunable blocks just need to show the user is warm and dialed-in.
- **New-speed introductions follow the Phase 2 pattern.** 21C (17 MPH) at 55%, 22C (18 MPH) at 55% — both 15 points below their day's floor of 70%. Same "first time you see this speed, you get a softer landing" rule as 12C/13C/13D/14B/19C/19D in Phase 2. The dangerous Zone 5 introductions (25C/26C) drop further (to 45%) only because the safety protocols demand it — not because they introduce a new speed.

This per-block table writes directly into the JSON as `blockPassThreshold` and `skipGating` overrides; defaults still come from the phase-floor table for any block not explicitly listed.

### Layer C — Per-speed adaptive lock

Today, `AdaptiveSpeedEngine` reweights every pool speed in eligible blocks (random / exploration / challenge / reactive / celebration / sequence / alternating). Proposed change: a pool speed is *eligible to appear at all* only if the user has demonstrated minimum readiness for it.

**Rule.** In an adaptive block targeting pool `[3, 4, 5, 6, 7]`, a speed S is included only if:
- S is the pool's lowest speed, OR
- The user is at Tier 1+ on speed S−1 (or, if S sits in a zone they haven't entered yet, on the highest speed of the previous zone)

If a pool speed is locked, it is removed from the active rotation and the block fills the missing slots with weighted reps of the next-tier-down speed. **The block still completes**; the adaptive engine just doesn't dump unprepared speeds on the user.

This codifies what the engine already implies with the 1.5× unpracticed weight and 3.0× weak weight, but instead of "appears too often" it means "doesn't appear until you're ready."

**Excluded from this rule** (same protected types as today): gate tests, assessments, fixed-speed blocks, recovery blocks, pressure with fixed speed, elimination ladder, combine, protocol-based.

### Layer D — Gate-test redesign

The single most important change. Today's gate test passes at 56%, fails almost no one, and ignores deviation and per-speed performance.

**Pass criteria are four-part and all must hold.** Every gate evaluates the same four criteria but with **per-gate thresholds** (not a global ruleset) — the values reflect the difficulty curve of each zone and were tuned interactively rather than chosen by formula.

1. **Min in-zone overall** — minimum count of putts that must land in the ±0.5 MPH zone across the full protocol.
2. **Min in-zone per speed** — minimum count of in-zone putts at each individual speed within the protocol. Prevents passing by acing one speed and bombing another.
3. **Average absolute deviation cap** — `sum(|actual − target|) / total_putts` across the gate test must be at or below this. Catches "in zone but always near the edge" patterns.
4. **Max single-miss cap** — no individual putt may deviate more than this from target. Catches fliers that overall stats would smooth over.

**Locked thresholds (decided by Arthur via interactive tuner):**

| Gate | Day | Force | Protocol | Min overall | Per speed | Avg dev cap | Max miss |
|------|-----|-------|----------|-------------|-----------|-------------|----------|
| Zone 1 | 5 | Soft | 3 MPH ×3, 4 MPH ×3, 5 MPH ×3 (9 putts) | 6 of 9 (67%) | ≥ 1 of 3 (33%) | ≤ 0.70 MPH | ≤ 1.25 MPH |
| Zone 2 | 9 | Soft | 5 MPH ×4, 6 MPH ×4, 7 MPH ×4 (12 putts) | 8 of 12 (67%) | ≥ 2 of 4 (50%) | ≤ 0.70 MPH | ≤ 1.25 MPH |
| Zone 3 intro | 12 | Hard | 8 MPH ×4, 9 MPH ×4, 10 MPH ×4 (12 putts) | 8 of 12 (67%) | ≥ 2 of 4 (50%) | ≤ 0.75 MPH | ≤ 1.20 MPH |
| Zone 4 | 19 | Hard | 10 MPH ×4, 12 MPH ×4, 14 MPH ×4 (12 putts) | 9 of 12 (75%) | ≥ 2 of 4 (50%) | ≤ 0.80 MPH | ≤ 1.25 MPH |
| Zone 5 | 25 | Hard | 15/16/17/18 MPH ×3 (12 putts) | 9 of 12 (75%) | ≥ 2 of 3 (67%) | ≤ 0.90 MPH | ≤ 1.30 MPH |

**Reading the curve.**

- **Overall accuracy stairs up at the 10/11 boundary.** Soft gates (Zones 1–2) and the Zone 3 intro gate all sit at 67% — generous enough to let early-phase users build confidence and pass with focused practice. Hard gates from Zone 4 forward step up to 75%, mirroring the mastery-learning literature on long-term retention requiring ≥75–80% criterion levels.
- **Per-speed floors are lenient.** The 33%/50%/67% per-speed values are the structural minimums that prevent a single bombed speed from passing — they're not the place to force consistency. Consistency is enforced by the deviation caps (criteria 3 and 4).
- **Deviation caps loosen with speed.** 0.70 MPH at touch speeds tightens the consistency requirement (slow putts have lower natural scatter). 0.90 MPH at maximum speeds acknowledges that an 18 MPH putt has more inherent variance than a 4 MPH lag putt. This is biomechanically honest — chasing 0.6 MPH average deviation at 18 MPH is unrealistic for non-elite players.
- **Max-miss caps tighten with speed.** Counterintuitive at first: 1.25 MPH at slow speeds, 1.20 MPH at the first hard gate, 1.25 at Zone 4, 1.30 at Zone 5. The pattern reflects "no fliers allowed when you're ramping into the next phase" — Day 12 is the strictest individual-miss gate because that's where unprepared speed becomes a habit-forming problem.

**Tiered enforcement on failure.**

| Gate | Day | Force | On fail |
|------|-----|-------|---------|
| Zone 1 | 5 | Soft | Strong recommendation to repeat Days 3–4; override available immediately (unlimited use) |
| Zone 2 | 9 | Soft | Strong recommendation to repeat Days 7–8; override available immediately |
| Zone 3 intro | 12 | Hard | Auto-prescribe a Recovery day on weakest speed; override only after 2 retries |
| Zone 4 | 19 | Hard | Auto-prescribe Recovery; override only after 2 retries |
| Zone 5 | 25 | Hard | Auto-prescribe Recovery; override only after 2 retries |

The Zone-3-intro gate (Day 12) is the first hard checkpoint, mirroring the per-block 10/11 MPH cutover.

**Failure-reason routing.** Because criteria are independent, the result screen shows *which* failed and the remediation message changes accordingly:
- Failed criterion 1 (overall) → "Across all speeds, in-zone count is short" → recommend balanced retry
- Failed criterion 2 (per-speed) → "One speed is dragging the test down: X MPH" → Recovery day targets X MPH specifically
- Failed criterion 3 (avg dev) → "In-zone hits are there but consistency is wide" → Recovery day emphasizes deviation drills, not zone hits
- Failed criterion 4 (max miss) → "One putt was way off — control isn't reliable yet" → Recovery day adds make-in-row blocks at the offending speed

This means the same gate test fail produces different remediation experiences depending on *why* the user failed, not just *that* they failed.

**Auto-prescribed Recovery day.** On hard-gate failure, the next day inserted into the program is a generated `RecoveryDay` keyed off the user's weakest tier-3-or-below speed in the failed zone:
- 4 blocks, ~12 minutes total
- 60% reps on the weakest speed, 40% reps on adjacent speeds
- No new content, no new zones, no surprise drills
- Marked in stats but does not count against the 30-day day count for the user-facing program

This is the science-anchored remediation: progressive, individually adjusted, low-stakes. It keeps the user moving and engaged without letting them advance to material they're not ready for.

---

## 4. Data model & code changes

### New service: `MasteryService.swift`

The single new service. Reads `SpeedProfileData`, exposes:

```
func tier(forSpeed s: Int) -> MasteryTier
func recentAccuracy(forSpeed s: Int) -> Double      // rolling last 20
func isSpeedUnlockedForAdaptive(_ s: Int, in pool: [Int]) -> Bool
func evaluateBlock(_ session: SessionProgress, block: TrainingBlock, day: Int) -> BlockEvaluation
func evaluateGateTest(_ session: SessionProgress, block: TrainingBlock) -> GateTestResult
func phaseFloor(forDay d: Int) -> Float
func gateForce(forDay d: Int) -> GateForce  // .soft or .hard
```

`MasteryService` becomes the single source of truth. `AdaptiveSpeedEngine` consults it; `TrainingViewModel.completeBlock()` consults it; `evaluateGateTest()` is moved into it.

### `SpeedProfileData` additions

Two new fields:
- `recentPutts: Int16` — rolling sample size (capped at 20)
- `recentOnTargetPutts: Int16` — for `recentAccuracy` computation
- `tierOverride: Int16` — manual override (defaults -1, used by debug/admin and decay logic)

Schema migration is straightforward — all defaultable to 0/-1.

### New Core Data entity: `BlockAttemptData`

Existing `SessionData` records one row per block attempt but doesn't capture the gating outcome. New entity:
```
id: UUID
dayNumber: Int16
blockId: String
attemptNumber: Int16
zoneAccuracy: Float
passedThreshold: Bool
passedWithOverride: Bool
attemptedAt: Date
```
Lets us measure how often soft overrides are used (engagement-vs-rigor tradeoff data) and gate the "third-attempt auto-shorten" logic.

### `GateTestResult` additions

```swift
struct GateTestResult {
  let gateId: String
  let passed: Bool
  let zoneAccuracy: Float
  let perSpeedAccuracy: [Int: Float]         // NEW
  let avgAbsDeviation: Float                  // NEW
  let maxDeviation: Float                     // NEW
  let failureReasons: [GateFailureReason]     // NEW (typed enum: zoneAccuracy, perSpeedFloor, deviationCap, catastrophicMiss)
}
```

### JSON schema

Backwards-compatible additions to `speed-machine-training-program.json`:
- Per-block: optional `blockPassThreshold: Float` (overrides phase floor for unusual blocks)
- Per-block: optional `skipGating: Bool` (for true exploration / warmup blocks where gating is silly)
- Per-gate: required `gateForce: "soft" | "hard"` (no global default — every gate states its own force)
- Top-level: `phaseFloors` array (lets you tune the 40/50/60/65/70/75 ladder without code changes)

**Per-gate criteria** replace the existing single `passRequirements.zoneAccuracy.minimum` field. New shape on each gate test:

```json
"passRequirements": {
  "minOverallInZone": 6,
  "minPerSpeedInZone": 1,
  "avgDeviationCapMph": 0.70,
  "maxSingleMissMph": 1.25
}
```

**Locked starting values** (Arthur's tuner output — to be written into the JSON on implementation):

| Gate | minOverall | minPerSpeed | avgDevCap | maxMiss | gateForce |
|------|-----------|-------------|-----------|---------|-----------|
| gate-zone1 | 6 | 1 | 0.70 | 1.25 | soft |
| gate-zone2 | 8 | 2 | 0.70 | 1.25 | soft |
| gate-zone3 | 8 | 2 | 0.75 | 1.20 | hard |
| gate-zone4 | 9 | 2 | 0.80 | 1.25 | hard |
| gate-zone5 | 9 | 2 | 0.90 | 1.30 | hard |

Note: `minPerSpeedInZone` is a single integer applied uniformly across the protocol's speeds. If a future gate has uneven putts-per-speed (e.g. 4-3-3 split), this will need to evolve to a dictionary `[speed: int]`. Current protocols are uniform, so the integer form is sufficient.

Both copies of the JSON (`SpeedMachineApp/Resources/...` and the root reference) get updated, per the project's two-target sync rule in `CLAUDE.md`.

### Modified files (estimated)

| File | Change |
|------|--------|
| `MasteryService.swift` | NEW — central skill state |
| `TrainingViewModel.swift` | `completeBlock()` calls `MasteryService.evaluateBlock()`, branches to `SkillCheckResultView` on fail; `evaluateGateTest()` moved out |
| `AdaptiveSpeedEngine.swift` | `generateAdaptiveSequence()` calls `MasteryService.isSpeedUnlockedForAdaptive()` to filter pool |
| `DataService.swift` | Add `BlockAttemptData` CRUD + `SpeedProfileData` migration |
| `SkillCheckResultView.swift` | NEW — between-block soft/hard gate UI |
| `BlockThresholdStrip.swift` | NEW — persistent threshold indicator under the header on every live session view (see §5.1). Reads block + live `SessionProgress`, renders count vs. threshold, handles built-in / skipped / gate-test variants |
| `TrainingSessionView.swift` (live views) | `ActiveSessionView`, `ExplorationSessionView`, `PressureSessionView`, `GateTestSessionView` updated to host the strip directly under their existing header. `LadderSessionView` and `MakeInRowSessionView` likewise |
| `RecoveryDayGenerator.swift` | NEW — produces auto-prescribed recovery days |
| `GateTestResultView.swift` | Updated to render new failure reasons + std dev |
| `BlockSelectionView.swift` | Show mastery tier badges on block cards |
| `DaySelectionView.swift` | Show "skill state" indicator per day |
| `StatsView.swift` / `SpeedDetailView.swift` | Surface tier + "next-tier requirements" tease |
| Both `speed-machine-training-program.json` files | New optional fields |

The `SpeedMachine/` parallel target needs the same changes per project rules.

---

## 5. UX flows — three things the user actually sees

**Flow 1 — block fail, soft phase (Day 6, after a 38% block).**
Block transition screen replaced by `SkillCheckResultView`:
> **Almost there**
> Block accuracy: 38% — we're looking for 50% on Day 6.
> A repeat will help this lock in.
> [ Repeat block ] [ Continue anyway ]

Default focus is on Repeat. Continue is grey, smaller. User retains agency; engagement isn't broken; the data records both choices.

**Flow 2 — gate test fail, hard phase (Day 19, missed deviation cap).**
> **Gate Test — needs another look**
> Zone accuracy: 78% ✓
> Per-speed floor: ✓
> Avg deviation: 0.81 MPH (target ≤ 0.6)
> Largest miss: 1.2 MPH ✓
>
> Your zone hits are there but consistency is wide. We've added Day 19R: a focused recovery on 12 MPH (your weakest speed in this zone).
> [ Start Recovery Day ]

Override is not visible on the first failure. Becomes available after 2 retries.

**Flow 3 — adaptive block, locked speed (Day 8, exploration block with pool [3,4,5,6,7], user is Tier 0 on 7 MPH).**
No special UI. The block runs with [3,4,5,6] only, weighted normally. The "your weakest speed" telemetry on the day-summary screen says "12 MPH not yet introduced — keep building 6 MPH" so the user understands. This is invisible scaffolding, not a failure state.

### 5.1 Persistent threshold indicator (always-on during live session)

A non-negotiable UI requirement of this gating system: **the pass threshold for the current block must be visible at all times on every live session view**. The user is putting 5–6 feet from the screen and needs to know, at a glance, what they're working toward and how close they are. Hidden thresholds (revealed only at block-end via `SkillCheckResultView`) are not acceptable — they create a "surprise fail" experience and rob the user of in-block agency to bear down or reset.

**Component.** A new `BlockThresholdStrip` view sits as a second row directly under the existing block header (`SessionHeaderCompact` / `PressureHeaderCompact` / `GateTestHeaderCompact`). It renders on top of every live session view: `ActiveSessionView`, `ExplorationSessionView`, `PressureSessionView`, `GateTestSessionView`, `LadderSessionView`, `MakeInRowSessionView`. (`BlockTransitionView` is excluded — that's a 3-second between-block screen with its own purpose.)

**Per the live-view UI rules** (`CLAUDE.md` §"Viewing Distance Rules"): the strip's primary count must be at least 32–40pt bold, secondary labels at least 20–24pt heavy. High contrast, white card on the existing header surface.

**Render rules by block type.**

| Block kind | Strip content | Example |
|------------|---------------|---------|
| Standard threshold block (random/blocked/sequence/alternating/predictive/challenge/reactive) | `IN ZONE: X / Y · PASS ≥ Z (P%)` — live putt counter on the left, threshold on the right | `IN ZONE: 8 / 16 · PASS ≥ 9 (55%)` |
| Gate test (Layer D) | `IN ZONE: X / Y · PASS ≥ Zmin overall, ≥ Zper per speed` — second line shows live deviation: `AVG DEV: D MPH (cap C)` | `IN ZONE: 5 / 9 · PASS ≥ 6 overall, ≥ 1 per speed` + `AVG DEV: 0.42 (cap 0.70)` |
| Pressure (built-in: ladder / consecutive / elimination) | Native progress instead of percentage: `STREAK: X / Y` or `RUNG: X / Y` or `LIVES: X / Y` | `STREAK: 3 / 5` |
| Combine block | `COMBINE — score not gated` (running score appears in the existing combine UI, no need to duplicate) | `COMBINE — score not gated` |
| Skipped (`skipGating: true`: warmup, recovery, exploration, celebration) | `FREE PRACTICE — no gate` in muted weight | `FREE PRACTICE — no gate` |

**Live color states** (the strip itself stays neutral; the in-zone count and threshold value carry the color):

- **Below threshold, still mathematically possible** — neutral primary text. No alarm.
- **At or above threshold** — count goes green with a small check glyph. The user keeps putting; the block doesn't end early. Positive feedback, not a stop signal.
- **Mathematically impossible to pass** (remaining putts × max-possible can't reach the threshold) — count goes amber. Tells the user "this attempt will fail, but the learning still counts — finish the block." We do *not* abort the block early; aborting destroys the rep volume that makes the next attempt better.

**No threshold strip on `BlockTransitionView`.** The transition screen is the celebration/handoff between blocks — its own design language (3-second timer, next-block preview). The threshold strip's job ends when the block ends.

**Override and retry surfaces.** When a user fails a block and lands on `SkillCheckResultView`, the strip's last state is preserved as a static summary (`IN ZONE: 7 / 16 · NEEDED ≥ 9`) at the top of that screen — continuity of information from the live session into the result. On a retry, the strip resets and runs again from zero.

**Why this is required and not optional.**

1. **Engagement under the Goldilocks principle requires the user know the bar.** A user told "you didn't pass" at the end of a block they thought they were doing fine on is a churn moment. A user who sees "5 / 9 in zone, need 4 more in 7 putts" 30 seconds before block end has agency — they can lock in.
2. **It surfaces the gating system without lecturing.** No tutorial needed. The strip self-explains the system over the first few blocks.
3. **It de-risks the override-spam concern.** Users who see they were genuinely close are less likely to override; users who see they were 30% away from the bar are more likely to repeat. This is a behavioral-economics nudge built into the always-on UI.
4. **It matches the existing app philosophy.** Stats are already protocol-independent and surfaced everywhere in the app; the threshold strip is the in-session counterpart to the always-visible per-speed accuracy in `StatsView`.

---

## 6. Risks and tradeoffs

**Engagement risk (the real one).** Hard gates drop completion rates. The literature on app churn says any hard friction in the first 7 days is fatal to D7 retention. Mitigation: all gates in days 1–12 are soft, with explicit override copy ("we strongly recommend… but you can continue"). Hard gates only appear after the user has invested 12+ days, when sunk cost favors finishing.

**Override-spam risk.** Soft gates with overrides may be ignored entirely. Mitigation: the data layer records every override. After ship, look at the `passedWithOverride` rate in `BlockAttemptData`. If >40% of fails get overridden, tighten copy or auto-prescribe a "make-up" mini-block at session end.

**Recovery-day fatigue.** If a user fails Day 19 three times, three Recovery days stack up. Mitigation: cap auto-prescribed Recovery days at 1 per gate fail; subsequent failures simply re-attempt the gate without a new Recovery prefix.

**Tolerance ceiling realism.** Tour pros run ~1.29 MPH ball-speed range on an 8-foot putt. The app's ±0.5 MPH tolerance is *tighter* than tour-level. The Tier 4 std-dev cap of ≤ 0.5 MPH is therefore "elite consistency." This is intentional — Tier 4 is the ceiling, not the gate. Phase floors top out at 75% accuracy and the deviation cap is 0.6 MPH (above tolerance, below tour-pro variance). Reasonable for a serious recreational golfer; not punitive.

**JSON drift between the two targets.** Project rule already documented in `CLAUDE.md`. Plan introduces 4–5 new optional JSON keys; sync discipline still applies. Suggest a small unit test that asserts both files parse with the new schema.

**Migration safety.** `SpeedProfileData` schema additions all default to zero, so existing user data is preserved. `BlockAttemptData` is a new entity — no migration needed. The first launch after upgrade should backfill `recentPutts/recentOnTargetPutts` from the most recent 20 entries in `PuttRecordData` (similar to the existing `migrateExistingData()` pattern in `StatsService`).

---

## 7. Decisions (locked)

The five open questions have been resolved:

1. **Phase floors:** 40% / 50% / 60% / 65% / 70% / 75% across the six bands. Locked.
2. **Soft/hard cutover:** speed-based at the **10/11 MPH boundary**, not day-based. A block or gate test is hard-gated iff any target speed ≥ 11 MPH. Mixed pools: hardest speed wins.
3. **Override-spam tolerance:** **unlimited soft overrides.** Telemetry on `passedWithOverride` will inform later tightening if needed.
4. **Recovery day shape:** 4 blocks / ~12 minutes / 60% reps on weakest speed + 40% on adjacent speeds. Locked.
5. **Existing in-flight users:** **option B** — recompute mastery tiers retroactively from `PuttRecordData` on first launch after upgrade. Some users may effectively be demoted (e.g., reach Day 22 having never demonstrated Tier 2 on 12 MPH); the system trusts the data.

### Implications of #5 — retroactive recomputation

This is the highest-impact decision and deserves spelling out. On first launch after the gating system ships:

- A migration pass (`MasteryService.recomputeFromHistory()`) walks every `PuttRecordData` row, replays the running aggregates into `SpeedProfileData.recentPutts/recentOnTargetPutts`, and computes the user's tier per speed from scratch.
- A user who has been advancing on putt-count alone may now sit at Tier 0 or 1 on speeds the program assumes they've mastered. The next adaptive block they start could remove higher speeds from rotation. The next hard-gated block they hit could fail immediately.
- Two safeguards:
  - **One-time "Skill Reassessment" intro screen** on the first post-migration launch. Shows the user their tier per speed, explains the new system, and frames any apparent regression as "this is what the data actually says — let's build it back."
  - **No retroactive failure state.** Days they've already marked complete stay complete. The new gating only affects forward motion (the next block, the next gate test). They don't lose progress; they just have to clear stricter checks going forward.
- For users currently sitting on a *future* gate test day (e.g., Day 19 unstarted), the gate test will use the new criteria the moment they begin it. Soft gates that they walked past under the old system are not retroactively re-failed.

This is the science-honest choice (Option B from the original question) but it's also the option with the most engagement risk. The reassessment intro screen is the mitigation.

---

## 8. Suggested rollout order

If/when you greenlight implementation:

1. **Telemetry first.** Add `BlockAttemptData` + `recentAccuracy` fields, log everything, ship without enforcing. Two weeks of data to validate that the proposed thresholds match real user distributions.
2. **MasteryService skeleton + StatsView surfacing.** Show tiers in the UI without gating yet. Educates the user about the concept before it starts blocking them.
3. **Per-speed adaptive lock (Layer C).** Lowest user-visible friction — invisible scaffolding. Ship it first to validate the engine integration.
4. **Soft gates (Layer B, days 1–12).** Two-week observation window for override rates.
5. **Hard gates + Recovery days (Layer B days 13+, Layer D).** Last because they carry the most engagement risk.

Each step is independently shippable and revertible.

---

## Sources

- Guadagnoli & Lee (2004), *Challenge Point: A Framework for Conceptualizing the Effects of Various Practice Conditions in Motor Learning* — https://pubmed.ncbi.nlm.nih.gov/15130871/
- Guadagnoli & Lindquist (2007), *Challenge Point Framework and Efficient Learning of Golf* — https://journals.sagepub.com/doi/10.1260/174795407789705505
- Lundbye-Jensen et al. (2020), *Long-term motor skill training with individually adjusted progressive difficulty enhances learning and promotes corticospinal plasticity*, Scientific Reports — https://www.nature.com/articles/s41598-020-72139-8
- Pitts et al. (2021), *Mastery criteria and the maintenance of skills*, Behavioral Interventions — https://onlinelibrary.wiley.com/doi/full/10.1002/bin.1778
- Anonymous (2018), *A Preliminary Analysis of Mastery Criterion Level: Effects on Response Maintenance*, PMC — https://pmc.ncbi.nlm.nih.gov/articles/PMC5843573/
- Bjork & Bjork (2011), *Creating Desirable Difficulties to Enhance Learning* — https://bjorklab.psych.ucla.edu/wp-content/uploads/sites/13/2016/04/EBjork_RBjork_2011.pdf
- Wright et al. (2024), *High contextual interference improves retention in motor learning: systematic review and meta-analysis*, Scientific Reports — https://www.nature.com/articles/s41598-024-65753-3
- TrackMan, *Use the Consistency Number for Better Golf Performance* — https://www.trackman.com/blog/golf/how-to-utilize-the-consistency-number
- 2025 systematic scoping review of CPF applications — https://www.tandfonline.com/doi/full/10.1080/00222895.2025.2508283
