import SwiftUI
import ClerkKit
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "Onboarding")

// Data-driven step engine for the 33-screen onboarding story. Holds every
// collected answer (OnboardingData) in memory until screen 28 (createAccount),
// where OnboardingSubmitter writes it all to Supabase in one pass. Nothing here
// touches the network before that point.
@MainActor
@Observable
final class OnboardingCoordinator {
    var data = OnboardingData()
    private(set) var index: Int
    private(set) var transitionForward = true

    // Async lifecycle state surfaced to the relevant screens.
    enum SubmitState: Equatable { case idle, saving, failed(String) }
    var submitState: SubmitState = .idle

    private let steps = OnboardingStep.allCases
    private var didTrackStart = false

    // startAt lets ContentView resume an authed-but-incomplete user at the
    // post-account tail (screen 29) instead of replaying the whole flow.
    init(startAt: OnboardingStep = .welcome) {
        index = steps.firstIndex(of: startAt) ?? 0
    }

    var current: OnboardingStep { steps[index] }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index == steps.count - 1 }

    // Fraction of the progress-bearing spine completed at the current step.
    var progressFraction: Double {
        guard let rank = OnboardingStep.progressBearing.firstIndex(of: current) else {
            return 0
        }
        return Double(rank + 1) / Double(OnboardingStep.progressBearing.count)
    }

    // MARK: - Navigation

    func advance(after delay: TimeInterval = 0) {
        guard delay > 0 else { return step(by: 1) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            step(by: 1)
        }
    }

    func back() { step(by: -1) }

    func goTo(_ target: OnboardingStep) {
        guard let i = steps.firstIndex(of: target) else { return }
        transitionForward = i >= index
        withAnimation(.easeInOut(duration: 0.28)) { index = i }
    }

    private func step(by delta: Int) {
        let next = index + delta
        guard next >= 0, next < steps.count else { return }
        transitionForward = delta > 0
        withAnimation(.easeInOut(duration: 0.28)) { index = next }
    }

    // MARK: - Analytics

    func trackStartedIfNeeded() {
        guard !didTrackStart else { return }
        didTrackStart = true
        AppState.shared.isActivelyOnboarding = true   // hold routing through the session flip
        MixpanelService.track(.onboardingStarted)
    }

    func trackAppeared() {
        MixpanelService.track(.onboardingScreenViewed(number: index + 1, name: current.screenName))
    }

    // MARK: - Account creation + submit (screen 28 → 29)

    // Called by CreateAccountScreen once a Clerk session exists (email-verified,
    // Apple, or Google). Attaches RevenueCat/Mixpanel identity, then writes the
    // full onboarding payload. Returns true on success so the screen can advance.
    func completeAccountCreation() async -> Bool {
        guard let clerkId = Clerk.shared.user?.id else {
            submitState = .failed("You're not signed in. Please try again.")
            return false
        }

        // Identity for analytics + subscriptions, from screen 28 onward.
        MixpanelService.identify(clerkUserId: clerkId)
        RevenueCatService.shared.identifyUser(clerkUserId: clerkId)

        submitState = .saving
        do {
            try await OnboardingSubmitter.submit(data: data, clerkId: clerkId)
            // If the runner asked to link Strava on screen 24, do it now that a
            // session exists (Runna's iCal URL is set up later in Settings).
            if data.stravaConnected {
                do {
                    try await StravaOAuthService.shared.connect()
                    MixpanelService.track(.stravaConnected)
                } catch {
                    data.stravaConnected = false
                }
            }
            submitState = .idle
            advance()   // → planReveal
            return true
        } catch {
            logger.error("onboarding submit failed: \(error.localizedDescription, privacy: .public)")
            submitState = .failed("We couldn't save your plan. Tap to retry.")
            return false
        }
    }

    // MARK: - Finish (after paywall / notification prompt)

    // Marks onboarding complete both remotely and in AppState so ContentView
    // routes to the main tabs. Best-effort on the remote flag — the local flip
    // always happens so the user is never trapped in onboarding.
    func finish() async {
        // Analytics-only funnel signals (Phase 5 decision 1 — no user columns).
        MixpanelService.setUserProperties([
            "attribution":   data.attribution ?? "unknown",
            "longest_run_km": data.longestRunKm,
            "pain_points":   Array(data.painPoints).sorted().joined(separator: ","),
            "commitment":    data.commitment ?? "unknown",
            "diet":          data.diet
        ])
        MixpanelService.track(.onboardingCompleted(
            raceType: data.raceType ?? "unknown",
            trainingLevel: data.trainingLevel ?? "unknown"
        ))
        await OnboardingSubmitter.markOnboardingComplete()
        AppState.shared.isActivelyOnboarding = false
        AppState.shared.onboardingComplete = true
    }
}
