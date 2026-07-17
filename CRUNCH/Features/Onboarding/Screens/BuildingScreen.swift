import SwiftUI

// Screen 26 — "Building your fuel plan" (mockup .build). Theatrical loader with
// a spinning ring and rotating status lines; the plan itself computes live from
// MacroEngine, so this just paces the reveal, then auto-advances to commitment.
struct BuildingScreen: View {
    let coordinator: OnboardingCoordinator

    @State private var spin = false
    @State private var lineIndex = 0

    private let lines = [
        "Setting carb portions for your long-run days…",
        "Balancing recovery meals around your midweek sessions…",
        "Mapping your taper and carb-load to race week…",
        "Translating targets into your usual meals…"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(OB.ember, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: spin)
                .padding(.bottom, 34)

            Text("Building your fuel plan")
                .font(OB.serif(27, .semibold))
                .foregroundStyle(OB.ink)
                .padding(.bottom, 18)

            Text(lines[lineIndex])
                .font(.system(size: 15))
                .foregroundStyle(OB.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300, minHeight: 44)
                .id(lineIndex)
                .transition(.opacity)
            Spacer()
        }
        .padding(.horizontal, OB.gutter)
        .padding(.top, 64)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
        .onAppear {
            spin = true
            rotateLines()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { coordinator.advance() }
        }
    }

    private func rotateLines() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard lineIndex < lines.count - 1 else { return }
            withAnimation(.easeInOut(duration: 0.35)) { lineIndex += 1 }
            rotateLines()
        }
    }
}
