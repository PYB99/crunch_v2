import SwiftUI

// Root of the onboarding flow. Owns the coordinator, renders the current step's
// view with a directional slide, fires per-step analytics, and hosts the sign-in
// sheet reachable from the Welcome screen.
struct OnboardingContainerView: View {
    @State private var coordinator: OnboardingCoordinator
    @State private var showSignIn = false

    init(startAt: OnboardingStep = .welcome) {
        _coordinator = State(initialValue: OnboardingCoordinator(startAt: startAt))
    }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()

            screen(for: coordinator.current)
                .id(coordinator.index)
                .transition(.asymmetric(
                    insertion: .move(edge: coordinator.transitionForward ? .trailing : .leading)
                        .combined(with: .opacity),
                    removal: .move(edge: coordinator.transitionForward ? .leading : .trailing)
                        .combined(with: .opacity)
                ))
                .onAppear { coordinator.trackAppeared() }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSignIn) {
            SignInView(
                onSuccess: {
                    // Existing user: leave the flow so routing lands on the tabs.
                    AppState.shared.isActivelyOnboarding = false
                    showSignIn = false
                },
                onSignUp: { showSignIn = false }
            )
        }
    }

    @ViewBuilder
    private func screen(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:            WelcomeScreen(coordinator: coordinator, onSignIn: { showSignIn = true })
        case .problem:            ProblemScreen(coordinator: coordinator)
        case .solution:           SolutionScreen(coordinator: coordinator)
        case .attribution:        SingleSelectScreen(coordinator: coordinator, config: .attribution)
        case .name:               NameScreen(coordinator: coordinator)
        case .raceType:           SingleSelectScreen(coordinator: coordinator, config: .raceType)
        case .raceDetails:        RaceDetailsScreen(coordinator: coordinator)
        case .hook:               CinematicSceneScreen(coordinator: coordinator, config: .hook)
        case .sex:                SingleSelectScreen(coordinator: coordinator, config: .sex)
        case .age:                BigNumberSliderScreen(coordinator: coordinator, measure: .age)
        case .weight:             BigNumberSliderScreen(coordinator: coordinator, measure: .weight)
        case .height:             BigNumberSliderScreen(coordinator: coordinator, measure: .height)
        case .trainingLevel:      SingleSelectScreen(coordinator: coordinator, config: .trainingLevel)
        case .longestRun:         BigNumberSliderScreen(coordinator: coordinator, measure: .longestRun)
        case .activities:         MultiSelectScreen(coordinator: coordinator, config: .activities(coordinator))
        case .painPoints:         MultiSelectScreen(coordinator: coordinator, config: .painPoints(coordinator))
        case .reflection:         LetterScreen(coordinator: coordinator, config: .reflection)
        case .bombshell:          CinematicSceneScreen(coordinator: coordinator, config: .bombshell)
        case .bridge:             LetterScreen(coordinator: coordinator, config: .bridge)
        case .diet:               SingleSelectScreen(coordinator: coordinator, config: .diet)
        case .breakfast:          MealEntryScreen(coordinator: coordinator, config: .breakfast)
        case .lunch:              MealEntryScreen(coordinator: coordinator, config: .lunch)
        case .dinner:             MealEntryScreen(coordinator: coordinator, config: .dinner)
        case .liveAnswer:         LiveAnswerScreen(coordinator: coordinator)
        case .connectApps:        ConnectAppsScreen(coordinator: coordinator)
        case .outcomeProjection:  OutcomeProjectionScreen(coordinator: coordinator)
        case .building:           BuildingScreen(coordinator: coordinator)
        case .commitment:         SingleSelectScreen(coordinator: coordinator, config: .commitment)
        case .createAccount:      CreateAccountScreen(coordinator: coordinator)
        case .planReveal:         PlanRevealScreen(coordinator: coordinator)
        case .ratingRequest:      RatingRequestScreen(coordinator: coordinator)
        case .notificationPrompt: NotificationPrePromptScreen(coordinator: coordinator)
        case .paywall:            PaywallScreen(coordinator: coordinator)
        }
    }
}
