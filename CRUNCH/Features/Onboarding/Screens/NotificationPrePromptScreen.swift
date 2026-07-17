import SwiftUI

// Screen 30 — notification pre-prompt (mockup .notif-demo). Shows the exact kind
// of night-before nudge before triggering the system permission dialog, so the
// runner grants it in context. "Not now" is recoverable in Settings.
struct NotificationPrePromptScreen: View {
    let coordinator: OnboardingCoordinator
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("TOMORROW-EVE FUELING")
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(2)
                .foregroundStyle(OB.ink3)
                .padding(.bottom, 18)

            Text("This is exactly what you'll get, the night before a big session")
                .font(OB.serif(23, .semibold))
                .foregroundStyle(OB.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.bottom, 28)

            notifCard

            Text("We'll only nudge you the night before something that matters.")
                .font(.system(size: 13.5))
                .foregroundStyle(OB.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, 24)
            Spacer()

            OnboardingCTA(title: "Allow Notifications", isLoading: requesting) {
                Task {
                    requesting = true
                    _ = await PushNotificationService.shared.requestAuthorizationAndRegister()
                    requesting = false
                    coordinator.advance()
                }
            }
            OnboardingSecondaryCTA(title: "Not now") { coordinator.advance() }
        }
        .padding(.horizontal, OB.gutter)
        .padding(.top, 64)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
    }

    private var notifCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10).fill(OB.ember).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text("Crunch").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(OB.ink)
                Text("Tomorrow: 16K long run — extra portion at dinner tonight.")
                    .font(.system(size: 12.5)).foregroundStyle(OB.ink2)
            }
            Spacer(minLength: 8)
            Text("9:41 PM").font(.system(size: 11)).foregroundStyle(OB.ink3)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .background(RoundedRectangle(cornerRadius: 18).fill(OB.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(OB.cardBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 20, y: 12)
        .frame(maxWidth: 320)
    }
}
