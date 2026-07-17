import SwiftUI
import ClerkKit

struct ContentView: View {
    @Environment(Clerk.self) private var clerk
    @State private var appState = AppState.shared

    var body: some View {
        Group {
            if appState.onboardingComplete == true {
                MainTabView()
            } else if appState.isActivelyOnboarding || clerk.session == nil {
                // Fresh flow (or the session flip mid-flow at screen 28) — the
                // container starts at Welcome and owns its own coordinator.
                OnboardingContainerView(startAt: .welcome)
            } else if appState.onboardingComplete == false {
                // Authed but not finished (resume after account creation) — the
                // funnel data is already in Supabase, so we re-enter at the reveal.
                OnboardingContainerView(startAt: .planReveal)
            } else {
                // Authed at cold start; onboarding status not yet known.
                loadingView
            }
        }
        .task {
            try? await Clerk.shared.refreshClient()
        }
        .task(id: clerk.user?.id) {
            guard let userId = clerk.user?.id else {
                // Signed out — reset routing so the next user starts clean.
                appState.reset()
                return
            }
            MixpanelService.identify(clerkUserId: userId)
            RevenueCatService.shared.identifyUser(clerkUserId: userId)

            // Cold-start authed users need their onboarding status; skip while a
            // live flow is running (its own completion flips the flag).
            if !appState.isActivelyOnboarding, appState.onboardingComplete == nil {
                appState.onboardingComplete = await OnboardingSubmitter.fetchOnboardingComplete() ?? false
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            ProgressView().tint(OB.ink2)
        }
        .preferredColorScheme(.dark)
    }
}
