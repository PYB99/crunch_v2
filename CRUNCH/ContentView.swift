import SwiftUI
import ClerkKit

struct ContentView: View {
    @Environment(Clerk.self) private var clerk

    @State private var authDestination: AuthDestination?

    private enum AuthDestination: String, Identifiable {
        case signIn, signUp
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if clerk.session != nil {
                // Phase 5 inserts: !hasCompletedOnboarding → OnboardingCoordinator
                MainTabView()
            } else {
                SplashView(
                    onGetStarted: { authDestination = .signUp },
                    onSignIn:     { authDestination = .signIn }
                )
                .sheet(item: $authDestination) { destination in
                    switch destination {
                    case .signIn:
                        SignInView(
                            onSuccess: { authDestination = nil },
                            onSignUp:  { authDestination = .signUp }
                        )
                    case .signUp:
                        SignUpView(
                            onSuccess: { authDestination = nil },
                            onSignIn:  { authDestination = .signIn }
                        )
                    }
                }
            }
        }
        .task {
            try? await Clerk.shared.refreshClient()
        }
        .task(id: clerk.user?.id) {
            // When a session becomes active, attach analytics + subscription
            // identity to the Clerk user id. Idempotent — safe to re-run. This
            // is the prerequisite for Mixpanel event attribution and Phase 9's
            // RevenueCat entitlement lookups.
            guard let userId = clerk.user?.id else { return }
            MixpanelService.identify(clerkUserId: userId)
            RevenueCatService.shared.identifyUser(clerkUserId: userId)
        }
    }
}


#Preview {
    ContentView()
        .environment(Clerk.shared)
}
