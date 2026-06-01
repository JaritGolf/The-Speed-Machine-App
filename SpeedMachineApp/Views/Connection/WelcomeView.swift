//
//  WelcomeView.swift
//  SpeedMachine
//
//  First-launch hero (mockup 01). Shown once before Home.
//

import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Chapter: 01. BEGIN
                HStack(alignment: .bottom, spacing: 12) {
                    Text("01.")
                        .font(.custom("Inter-Black", size: 140))
                        .foregroundColor(.black)
                        .tracking(-7)
                    Text("BEGIN")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(2.75)
                        .foregroundColor(.black)
                        .padding(.bottom, 18)
                }

                Image("SpeedMachineLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 73)
                    .padding(.top, 28)

                Text("Train your\nspeed.")
                    .font(.custom("Inter-Black", size: 56))
                    .tracking(-2)
                    .lineSpacing(0)
                    .foregroundColor(.black)
                    .padding(.top, 48)

                Text("Master 18 putt speeds across five zones. Built around your weakest swing, sharpened by every rep.")
                    .font(.custom("Inter-Regular", size: 15))
                    .foregroundColor(AppColors.textMuted)
                    .lineSpacing(4)
                    .frame(maxWidth: 280, alignment: .leading)
                    .padding(.top, 20)

                Spacer(minLength: 24)

                Button(action: onGetStarted) {
                    Text("Get Started →")
                        .font(.custom("Inter-Bold", size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(AppColors.accentGreen)
                        .clipShape(Capsule())
                }

                Text("THE SPEED MACHINE · BY JARIT GOLF")
                    .font(.custom("Inter-SemiBold", size: 10))
                    .kerning(2.2)
                    .foregroundColor(AppColors.textSubdued)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 32)
            .padding(.top, 80)
            .padding(.bottom, 32)
        }
    }
}
