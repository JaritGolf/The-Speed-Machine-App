//
//  TourCopy.swift
//  SpeedMachine
//
//  ── SINGLE SOURCE OF TRUTH FOR ALL ONBOARDING / TOUR COPY ──
//
//  Every word the guided tours show lives in THIS file. To reword a tour,
//  edit the strings here — nothing else needs to change. The Home tour
//  (OnboardingTour.swift) and the six coachmark tours (Day/Track, Block,
//  Call the Speed, Free Practice, Combine, Stats) all read from here.
//
//  Wording rules:
//   • Phone placement is ALWAYS "face-up on the ground on the provided stand"
//     — never "5–6 ft", "set phone down", "on the floor", etc.
//   • Titles are SHORT and ALL-CAPS (they render as the callout heading).
//   • Bodies are 1–2 sentences. Keep them tight.
//

import SwiftUI

enum TourCopy {

    // A reusable title/body pair for the Home tour (which keys copy by step).
    struct Line {
        let title: String
        let body: String
    }

    // ============================================================
    // MARK: 1. HOME  (first-launch dashboard tour — OnboardingTour.swift)
    // ============================================================
    enum Home {
        static let pair = Line(
            title: "PAIR YOUR DEVICE",
            body: "Tap here to connect your Speed Machine over Bluetooth. You only need to do this the first time. Make sure your Speed machine is on and in Speed mode")

        static let dashboard = Line(
            title: "YOUR DASHBOARD",
            body: "Your spot in the 30 block training program, plus overall accuracy, total putts hit, and current day streak. The Focus bars flag the speeds that need the most work as well as your best")

        static let recall = Line(
            title: "CALL THE SPEED",
            body: "Cold recall: We call a speed, you hit it from feel, no number displayed. Get a score at the end. You're only asked for speeds you've unlocked in Training, and the range grows as you progress. Unlocks once you pass Phase 1.")

        static let practice = Line(
            title: "FREE PRACTICE",
            body: "Pick any speed or speeds, set your putt count, and grind. No gates, just reps. Unlocks once you pass Phase 1.")

        static let combine = Line(
            title: "THE COMBINE",
            body: "One putt at each speed. Scored for accuracy. This is the place to compete, whether with yourself or with the homies. Unlocks once you pass Phase 1.")

        static let stats = Line(
            title: "YOUR STATS",
            body: "Lifetime accuracy, trends, and full session history — watch your numbers climb. Unlocks once you pass Phase 1.")

        static let settings = Line(
            title: "SETTINGS",
            body: "Sound, haptics, device pairing, and iCloud backup. Replay this tour from here anytime.")

        static let start = Line(
            title: "START HERE",
            body: "Your daily program builds speed control track by track. This is where it all starts — pass Phase 1 to unlock Call the Speed, Free Practice, Combine, and Stats.")
    }

    // ============================================================
    // MARK: 2. DAY / TRACK SELECTION  (DaySelectionView)
    // ============================================================
    static let daySelection: [CoachmarkStep] = [
        CoachmarkStep("YOUR PROGRESS", "How far you are through the 30-track program.", anchor: 0),
        CoachmarkStep("PICK A TRACK", "Tap any unlocked track. Locked ones open as you progress; completed ones show a check.", anchor: 1),
        CoachmarkStep("KEEP GOING", "Or jump straight back in with Resume.", anchor: 2),
    ]

    // ============================================================
    // MARK: 3. BLOCK SELECTION  (BlockSelectionView)
    // ============================================================
    static let blockSelection: [CoachmarkStep] = [
        CoachmarkStep("BLOCKS", "Each track is a few blocks. The tag shows the type — Standard, Gate Test, Pressure, Ladder.", anchor: 0),
        CoachmarkStep("START", "Tap Start Block to begin the first unfinished one.", anchor: 1),
    ]

    // ============================================================
    // MARK: 4. CALL THE SPEED  (RecallStartView)
    // ============================================================
    static let recall: [CoachmarkStep] = [
        CoachmarkStep("YOUR RANGE", "We're only calling the speeds you've unlocked in Training, it grows as you progress.", anchor: 0),
        CoachmarkStep("ROUND LENGTH", "Pick 6, 9, or 12 putts.", anchor: 1),
        CoachmarkStep("COACHED OR BLIND", "Coached shows each result; Blind hides it until the end for pure recall.", anchor: 2),
        CoachmarkStep("VOICE CALLOUT", "Hear each target spoken, voice-only never seeing the number or flash the number briefly.", anchor: 3),
        CoachmarkStep("READY", "Set your phone face-up on the ground on the provided stand, then Start — targets are called automatically.", anchor: 4),
    ]

    // ============================================================
    // MARK: 5. FREE PRACTICE  (PracticeStartView)
    // ============================================================
    static let practice: [CoachmarkStep] = [
        CoachmarkStep("PICK YOUR SPEEDS", "Tap one or more speeds (3–15 MPH). When more than one speed is selected you'll choose Random or Sequence order.", anchor: 0),
        CoachmarkStep("HOW MANY PUTTS", "Set a count — 5, 10, 25 — or go open-ended (∞).", anchor: 1),
        CoachmarkStep("GO", "Set your phone face-up on the ground on the provided stand, then Start. Putts track live: putts made, putts left, and make %.", anchor: 2),
    ]

    // ============================================================
    // MARK: 6. COMBINE  (CombineModePickerView)
    // ============================================================
    static let combine: [CoachmarkStep] = [
        CoachmarkStep("CHOOSE A MODE", "Main, Low, High, Even — each tests a different speed range.", anchor: 0),
        CoachmarkStep("UNLOCKING MODES", "Locked modes open as you pass Training gate tests; clear the Zone 3 Gate Test to open every speed.", anchor: nil),
    ]

    // ============================================================
    // MARK: 7. STATS  (StatsDashboardView)
    // ============================================================
    static let stats: [CoachmarkStep] = [
        CoachmarkStep("YOUR NUMBERS", "Lifetime accuracy, total putts, and your day streak.", anchor: 0),
        CoachmarkStep("SPEED LADDER", "Accuracy for every speed, weakest on top. Tap a speed to dig in deeper.", anchor: 1),
        CoachmarkStep("MORE VIEWS", "Switch between Stats, Trends, History, and Combine down here.", anchor: 2),
    ]
}
