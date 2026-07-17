import SwiftUI

// The "fueled vs guesswork" projection chart shared by the outcome (25) and
// plan-reveal (29) screens (mockup .chart-card). Two curves: a flat guesswork
// baseline and a steep Crunch-fueled climb, with a soft area fill.
struct ProjectionChartCard: View {
    var height: CGFloat = 140

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                GuessworkCurve().stroke(OB.ink3, lineWidth: 2)
                FueledArea().fill(
                    LinearGradient(colors: [OB.jade.opacity(0.38), OB.jade.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )
                FueledCurve().stroke(OB.jade, lineWidth: 2.5)
            }
            .frame(height: height)

            HStack(spacing: 18) {
                legend(OB.jade, "Fueled with Crunch")
                legend(OB.ink3, "On guesswork")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(OB.ink2)
        }
        .padding(EdgeInsets(top: 18, leading: 14, bottom: 12, trailing: 14))
        .background(RoundedRectangle(cornerRadius: 20).fill(OB.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(OB.cardBorder, lineWidth: 1))
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label)
        }
    }
}

private struct GuessworkCurve: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0, 0.90))
        p.addCurve(to: pt(r, 1.0, 0.68),
                   control1: pt(r, 0.35, 0.86), control2: pt(r, 0.7, 0.74))
        return p
    }
}

private struct FueledCurve: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0, 0.90))
        p.addCurve(to: pt(r, 1.0, 0.11),
                   control1: pt(r, 0.28, 0.5), control2: pt(r, 0.68, 0.18))
        return p
    }
}

private struct FueledArea: Shape {
    func path(in r: CGRect) -> Path {
        var p = FueledCurve().path(in: r)
        p.addLine(to: pt(r, 1.0, 1.0))
        p.addLine(to: pt(r, 0, 1.0))
        p.closeSubpath()
        return p
    }
}

// nonisolated: Shape.path(in:) is nonisolated, but this module defaults top-level
// functions to MainActor (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
private nonisolated func pt(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
}
