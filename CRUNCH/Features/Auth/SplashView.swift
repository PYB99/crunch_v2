import SwiftUI

struct SplashView: View {
    var onGetStarted: () -> Void
    var onSignIn: () -> Void

    var body: some View {
        ZStack {
            // Background
            Theme.surface
                .ignoresSafeArea()

            // Runner image placeholder (replace with actual asset once added to Assets.xcassets)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1A0F0A"), Theme.surface],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Headline
                VStack(spacing: Theme.sm) {
                    Text("Fuel for your race.")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Not your weight.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.brand)
                }
                .padding(.horizontal, Theme.xl)

                Spacer()
                    .frame(height: Theme.xl * 2)

                // CTAs
                VStack(spacing: Theme.md) {
                    PrimaryButton(title: "Get Started", action: onGetStarted)

                    Button(action: onSignIn) {
                        Text("Already have an account? ")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textSecondary)
                        + Text("Sign in")
                            .font(Theme.body)
                            .foregroundStyle(Theme.brand)
                    }
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, Theme.lg)
                .padding(.bottom, Theme.xl)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    SplashView(onGetStarted: {}, onSignIn: {})
}
