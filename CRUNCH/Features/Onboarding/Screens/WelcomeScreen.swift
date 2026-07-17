import SwiftUI

// Screen 1 — cinematic hero splash (mockup .splash.hero). Full-bleed dawn scene
// approximated natively: gradient sky, sun bloom, layered ridgelines, a lone
// runner. "Get Started" begins the flow; the secondary link opens sign-in.
struct WelcomeScreen: View {
    let coordinator: OnboardingCoordinator
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeroScene()
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, OB.bg], startPoint: .top, endPoint: .bottom)
                        .frame(height: 130)
                }

            VStack(spacing: 0) {
                Text("CRUNCH")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(5)
                    .foregroundStyle(OB.ink2)
                    .padding(.top, 24)

                Text("Hey.")
                    .font(OB.serif(36, .bold))
                    .foregroundStyle(OB.ink)
                    .padding(.top, 16)

                Text("You train with a plan. Let's make sure you eat with one too.")
                    .font(.system(size: 15.5))
                    .foregroundStyle(OB.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 300)
                    .padding(.top, 16)

                Spacer(minLength: 20)

                OnboardingCTA(title: "Get Started") {
                    coordinator.trackStartedIfNeeded()
                    coordinator.advance()
                }
                OnboardingSecondaryCTA(title: "Already have an account? Sign in", action: onSignIn)
            }
            .padding(.horizontal, OB.gutter)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
    }
}

private struct HeroScene: View {
    @State private var bloom = false
    @State private var jog = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#0C1320"), Color(hex: "#3B2B26"), Color(hex: "#945123")],
                    startPoint: .top, endPoint: .bottom
                )

                // Sun bloom + core
                Circle()
                    .fill(RadialGradient(
                        colors: [OB.gold.opacity(0.5), .clear],
                        center: .center, startRadius: 0, endRadius: 180))
                    .frame(width: 360, height: 360)
                    .position(x: w * 0.54, y: h * 0.62)
                    .scaleEffect(bloom ? 1 : 0.88)
                    .opacity(bloom ? 1 : 0.4)

                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: "#FFE7C0"), Color(hex: "#F08A4A").opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 150, height: 150)
                    .position(x: w * 0.54, y: h * 0.6)

                // Ridgelines
                Ridge(offset: 0.66, amp: 0.05).fill(Color(hex: "#54402F").opacity(0.8))
                Ridge(offset: 0.74, amp: 0.06).fill(Color(hex: "#181109"))

                // Runner
                Ellipse()
                    .fill(Color(hex: "#060504"))
                    .frame(width: 6, height: 20)
                    .position(x: w * 0.54, y: h * 0.76 + (jog ? -2 : 0))
            }
            .onAppear {
                withAnimation(.easeOut(duration: 3)) { bloom = true }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { jog = true }
            }
        }
    }
}

// A soft mountain ridge as a filled path across the frame.
private struct Ridge: Shape {
    let offset: CGFloat   // baseline as a fraction of height
    let amp: CGFloat      // peak amplitude as a fraction of height

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let base = rect.height * offset
        let a = rect.height * amp
        p.move(to: CGPoint(x: 0, y: base))
        let steps = 6
        for i in 1...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let y = base + (i % 2 == 0 ? a : -a) * 0.6
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}
