import SwiftUI

// Eased count-up number for the plan-reveal stat row (mockup countUp). Animates
// 0 → target on appear; instant for Reduce Motion.
struct CountUpText: View {
    let target: Int
    var font: Font = OB.serif(23)
    var duration: Double = 0.7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value = 0

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(OB.ink)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear { animate() }
    }

    private func animate() {
        guard !reduceMotion else { value = target; return }
        let steps = 30
        let interval = duration / Double(steps)
        for s in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(s)) {
                let p = Double(s) / Double(steps)
                let eased = 1 - pow(1 - p, 3)
                withAnimation(.linear(duration: interval)) {
                    value = Int((Double(target) * eased).rounded())
                }
            }
        }
    }
}
