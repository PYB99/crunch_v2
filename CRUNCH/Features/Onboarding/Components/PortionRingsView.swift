import SwiftUI

// The app's signature concentric portion rings, used on "3 · The solution" as
// the product demo (mockup .rings). Three rings fill with a staggered spring.
struct PortionRingsView: View {
    var size: CGFloat = 180
    @State private var animate = false

    // (colour, fraction, entrance delay) outer → inner.
    private var rings: [(Color, CGFloat, Double)] {
        [(OB.ember, 0.82, 0.3), (OB.jade, 0.62, 0.5), (OB.gold, 0.42, 0.8)]
    }

    var body: some View {
        ZStack {
            ForEach(Array(rings.enumerated()), id: \.offset) { i, ring in
                let inset = CGFloat(i) * 20
                let dim = size - inset * 2
                ZStack {
                    Circle()
                        .stroke(OB.track, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    Circle()
                        .trim(from: 0, to: animate ? ring.1 : 0)
                        .stroke(ring.0, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.2, dampingFraction: 0.85).delay(ring.2), value: animate)
                }
                .frame(width: dim, height: dim)
            }
        }
        .frame(width: size, height: size)
        .onAppear { animate = true }
    }
}
