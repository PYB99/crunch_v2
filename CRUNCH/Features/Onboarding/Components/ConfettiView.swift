import SwiftUI

// One-shot celebratory burst from the plan-reveal checkmark (mockup burstConfetti).
// Brand-colour trio only, never a game mechanic. Honours Reduce Motion.
struct ConfettiView: View {
    var pieceCount = 18
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false

    private let colors = [OB.ember, OB.jade, OB.gold]

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<pieceCount, id: \.self) { i in
                    ConfettiPiece(
                        color: colors[i % colors.count],
                        angle: Double(i) / Double(pieceCount) * 2 * .pi + .random(in: -0.3...0.3),
                        distance: CGFloat.random(in: 60...150),
                        rounded: Bool.random(),
                        fired: fired
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { fired = true }
        }
    }
}

private struct ConfettiPiece: View {
    let color: Color
    let angle: Double
    let distance: CGFloat
    let rounded: Bool
    let fired: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: rounded ? 3.5 : 1)
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(fired ? 0.4 : 1)
            .opacity(fired ? 0 : 1)
            .offset(
                x: fired ? cos(angle) * distance : 0,
                y: fired ? sin(angle) * distance - 20 : 0
            )
            .rotationEffect(.degrees(fired ? .random(in: -180...180) : 0))
    }
}
