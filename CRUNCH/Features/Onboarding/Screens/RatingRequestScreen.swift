import SwiftUI
import StoreKit

// Inserted after the plan reveal (no dedicated UI in the mockup). Fires the system
// review prompt via SKStoreReviewController once, right at the emotional peak,
// then auto-advances to the notification pre-prompt.
struct RatingRequestScreen: View {
    let coordinator: OnboardingCoordinator
    @Environment(\.requestReview) private var requestReview
    @State private var fired = false

    var body: some View {
        VStack {
            ProgressView().tint(OB.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
        .onAppear {
            guard !fired else { return }
            fired = true
            requestReview()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { coordinator.advance() }
        }
    }
}
