import SwiftUI

// Screen 24 — connect Strava / Runna (mockup .connectcard). Integrations require
// an authenticated user, which doesn't exist yet, so this captures intent:
// data.stravaConnected triggers the real OAuth right after account creation
// (see OnboardingCoordinator.completeAccountCreation); Runna's iCal URL is set up
// later in Settings → Integrations.
struct ConnectAppsScreen: View {
    @Bindable var coordinator: OnboardingCoordinator

    var body: some View {
        OBScreen(coordinator: coordinator) {
            OBQuestionHeader(
                title: "Make it automatic",
                subtitle: "Connect and your portions update themselves after every run."
            )

            VStack(spacing: 12) {
                connectCard(
                    mark: "S", markColor: OB.ember, name: "Strava",
                    detail: "Auto-sync runs and long sessions",
                    isOn: coordinator.data.stravaConnected
                ) { coordinator.data.stravaConnected.toggle() }

                connectCard(
                    mark: "R", markColor: OB.jade, name: "Runna",
                    detail: "Sync your training calendar",
                    isOn: coordinator.data.runnaConnected
                ) { coordinator.data.runnaConnected.toggle() }
            }

            Text("You'll confirm the link after your plan is saved.")
                .font(.system(size: 12))
                .foregroundStyle(OB.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)
        } footer: {
            VStack(spacing: 0) {
                OnboardingCTA(title: "Continue") { coordinator.advance() }
                OnboardingSecondaryCTA(title: "Skip for now") {
                    coordinator.data.stravaConnected = false
                    coordinator.data.runnaConnected = false
                    coordinator.advance()
                }
            }
        }
    }

    private func connectCard(
        mark: String, markColor: Color, name: String, detail: String,
        isOn: Bool, action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Text(mark)
                .font(OB.serif(15, .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12).fill(markColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(OB.ink)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(OB.ink2)
            }
            Spacer()
            Button(action: action) {
                Text(isOn ? "Added ✓" : "Connect")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isOn ? OB.ctaInk : OB.ink)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(isOn ? OB.trackFill : OB.track))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .background(RoundedRectangle(cornerRadius: 18).fill(OB.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(OB.cardBorder, lineWidth: 1))
    }
}
