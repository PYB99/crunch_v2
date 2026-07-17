import SwiftUI

// Screen 25 — outcome projection (mockup .chart-card + .milestone). Sells the
// race-week payoff with the fueled-vs-guesswork chart and the carb-load note.
struct OutcomeProjectionScreen: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        OBScreen(coordinator: coordinator) {
            VStack(spacing: 0) {
                Text("By race week, you'll know exactly what to eat")
                    .font(OB.serif(24, .semibold))
                    .foregroundStyle(OB.ink)
                    .multilineTextAlignment(.center)
                Text("Every single day — including the three-day carb load most runners get wrong.")
                    .font(.system(size: 15))
                    .foregroundStyle(OB.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.bottom, 22)

                ProjectionChartCard()

                HStack(spacing: 10) {
                    Circle().fill(OB.gold).frame(width: 9, height: 9)
                    Text(.init("**Race week:** your carb-load protocol starts automatically — three days, dialled to your race distance."))
                        .font(.system(size: 13.5))
                        .foregroundStyle(OB.ink2)
                }
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                .background(RoundedRectangle(cornerRadius: 16).fill(OB.card))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(OB.cardBorder, lineWidth: 1))
                .padding(.top, 16)
            }
        } footer: {
            OnboardingCTA(title: "Continue") { coordinator.advance() }
        }
    }
}
