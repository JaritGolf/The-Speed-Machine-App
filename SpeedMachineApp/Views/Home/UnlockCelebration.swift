//
//  UnlockCelebration.swift
//  SpeedMachine
//
//  Congratulatory popups shown on Home the next time the player returns after
//  crossing a milestone that unlocks a feature, Combine mode, or speed range.
//  Each milestone fires once; "already shown" is persisted in DataService.
//

import SwiftUI

// MARK: - Milestones

enum UnlockMilestone: String, CaseIterable {
    // Ordered by when they occur in the program.
    case features       // pass Zone 2 gate (track 11): the 4 Home modes unlock
    case speed12        // Call the Speed reaches 3–12 (≈track 16)
    case combineFull    // pass Zone 3 gate (track 19): full Combine
    case speed15        // Call the Speed reaches 3–15 (≈track 24)
    case programComplete // finish all 30 tracks: Daily Tune-Up

    var id: String { rawValue }

    var title: String {
        switch self {
        case .features:        return "NEW MODES UNLOCKED"
        case .speed12:         return "SPEEDS UP TO 12"
        case .combineFull:     return "FULL COMBINE UNLOCKED"
        case .speed15:         return "SPEEDS UP TO 15"
        case .programComplete: return "PROGRAM COMPLETE"
        }
    }

    var bodyText: String {
        switch self {
        case .features:
            return "Great work passing the Zone 2 Gate! You've unlocked Call the Speed, Free Practice, Combine, and Stats. Call the Speed starts you at 3–9 MPH."
        case .speed12:
            return "You've trained through 12 MPH — Call the Speed now serves the full 3–12 MPH range."
        case .combineFull:
            return "Zone 3 cleared! Combine's High and Even modes are open, with every speed up to 20 MPH."
        case .speed15:
            return "You've reached the top — Call the Speed now covers the full 3–15 MPH range."
        case .programComplete:
            return "You've finished all 30 tracks. Daily Tune-Up is now unlocked to keep your speeds sharp."
        }
    }

    var icon: String {
        switch self {
        case .programComplete: return "trophy.fill"
        default:               return "lock.open.fill"
        }
    }

    func isAchieved(passedGates: Set<String>, currentDay: Int, totalTracks: Int, maxTrainedSpeed: Int) -> Bool {
        switch self {
        case .features:        return passedGates.contains("gate-zone2")
        case .speed12:         return maxTrainedSpeed >= 12
        case .combineFull:     return passedGates.contains("gate-zone3")
        case .speed15:         return maxTrainedSpeed >= 15
        case .programComplete: return currentDay > totalTracks
        }
    }
}

// MARK: - Modal

struct UnlockCelebrationModal: View {
    let milestone: UnlockMilestone
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentGreen.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: milestone.icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(AppColors.accentGreen)
                }
                .padding(.bottom, 18)

                Text(milestone.title)
                    .font(.custom("Inter-ExtraBold", size: 18))
                    .kerning(1.5)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text(milestone.bodyText)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 24)

                Button(action: onDismiss) {
                    Text("Let's go")
                        .font(.custom("Inter-Bold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppColors.accentGreen)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
            .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 8)
        }
    }
}
