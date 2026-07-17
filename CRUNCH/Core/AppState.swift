import Foundation

// Launch-time routing state that ContentView observes to choose between
// onboarding and the main tabs. `onboardingComplete` is loaded from the users
// row after sign-in (nil = not yet known → show a brief loading state) and
// flipped to true by OnboardingCoordinator when the flow finishes.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    private init() {}

    var onboardingComplete: Bool?

    // True while a fresh flow (from Welcome) is in progress. Keeps ContentView on
    // the live onboarding container when account creation at screen 28 flips the
    // Clerk session mid-flow — without it, routing would tear the coordinator down.
    var isActivelyOnboarding = false

    func reset() {
        onboardingComplete = nil
        isActivelyOnboarding = false
    }
}
