import SwiftUI
import ClerkKit

@main
struct CRUNCHApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // configure() is lightweight (sets the publishable key only) and must run
        // before body accesses Clerk.shared. refreshClient() stays in ContentView.task
        // so the async network call doesn't block the launch screen.
        Clerk.configure(publishableKey: Constants.clerkPublishableKey)
        RevenueCatService.shared.configure()
        MixpanelService.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(Clerk.shared)
                .environment(AppRouter.shared)
                .preferredColorScheme(.dark)
                .background(Theme.surface.ignoresSafeArea())
        }
    }
}
