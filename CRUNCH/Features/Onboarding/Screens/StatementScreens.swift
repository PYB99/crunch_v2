import SwiftUI

// Screen 2 — "The problem". Centred statement, guesswork in ember (mockup .statement).
struct ProblemScreen: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("SOUND FAMILIAR?")
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(2)
                .foregroundStyle(OB.ink3)
                .padding(.bottom, 18)

            (Text("You train with a plan.\nYou eat by ")
                .foregroundStyle(OB.ink)
             + Text("guesswork.")
                .foregroundStyle(OB.ember))
                .font(OB.serif(30, .semibold))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: 300)

            Text("Every session is logged. Every dinner is a shrug.")
                .font(.system(size: 14.5))
                .foregroundStyle(OB.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, 18)
            Spacer()

            OnboardingCTA(title: "Continue") { coordinator.advance() }
        }
        .padding(.horizontal, OB.gutter)
        .padding(.top, 64)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
    }
}

// Screen 3 — "The solution". The signature portion rings as the product demo.
struct SolutionScreen: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            PortionRingsView(size: 180)
                .padding(.bottom, 26)
            Text("Crunch reads your training.\nYou get real portions.")
                .font(OB.serif(22, .semibold))
                .foregroundStyle(OB.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 10)
            Text("Never wonder how much to eat for tomorrow's run.")
                .font(.system(size: 14.5))
                .foregroundStyle(OB.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Spacer()

            OnboardingCTA(title: "Continue") { coordinator.advance() }
        }
        .padding(.horizontal, OB.gutter)
        .padding(.top, 64)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
    }
}
