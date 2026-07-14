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
    }
}


#Preview {
    ContentView()
        .environment(Clerk.shared)
}
