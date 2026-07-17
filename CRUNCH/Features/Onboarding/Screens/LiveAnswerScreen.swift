import SwiftUI

// Screen 23 — the climax. Shimmer ("Reading your meals…") resolves after ~1.4s
// into two Today-tab meal tiles built from the runner's own dinner (mockup
// .live-answer). A teaser of the real Today tab, not the stored plan.
struct LiveAnswerScreen: View {
    let coordinator: OnboardingCoordinator
    @State private var revealed = false

    private var dinnerName: String {
        coordinator.data.meals(for: .dinner).first ?? "your dinner"
    }

    var body: some View {
        OBScreen(coordinator: coordinator) {
            if revealed {
                answer.transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                loading
            }
        } footer: {
            if revealed {
                OnboardingCTA(title: "That's exactly what I needed") { coordinator.advance() }
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.6)) { revealed = true }
            }
        }
    }

    private var loading: some View {
        VStack(spacing: 16) {
            Spacer()
            ShimmerBar()
            Text("Reading your meals…")
                .font(.system(size: 13.5))
                .foregroundStyle(OB.ink3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Here's a taste, \(coordinator.data.displayName)")
                .font(.system(size: 15))
                .foregroundStyle(OB.ink2)
                .frame(maxWidth: .infinity)
            Text("This is your Today tab")
                .font(OB.serif(21, .semibold))
                .foregroundStyle(OB.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            Text("Same \(dinnerName) you told us about — two different nights.")
                .font(.system(size: 13))
                .foregroundStyle(OB.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 22)

            OBMealTile(
                eyebrow: "LONG-RUN EVE · DINNER",
                name: dinnerName,
                level: .extra,
                why: "Tomorrow's 16K needs topping up — **an extra portion of rice** tonight.",
                portionText: "**1.5 cups rice** instead of your usual 1 cup.",
                macros: (140, 28, 14),
                startsOpen: false
            )
            Divider().overlay(OB.cardBorder)
            OBMealTile(
                eyebrow: "RACE EVE · DINNER",
                name: dinnerName,
                level: .double,
                why: "**Double portion** the night before your race — this is what carries you to the finish.",
                portionText: "**2 full bowls** instead of your usual 1 — same meal, twice the rice.",
                macros: (210, 34, 16),
                startsOpen: true
            )
        }
    }
}

private struct ShimmerBar: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        RoundedRectangle(cornerRadius: 99)
            .fill(OB.track)
            .frame(width: 230, height: 11)
            .overlay(
                RoundedRectangle(cornerRadius: 99)
                    .fill(LinearGradient(colors: [.clear, OB.cardBorder, .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .offset(x: phase * 230)
                    .mask(RoundedRectangle(cornerRadius: 99))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

private enum OBPortionLevel {
    case extra, double
    var label: String { self == .double ? "DOUBLE" : "EXTRA" }
    var color: Color { self == .double ? OB.ember : OB.gold }
    var filled: Int { self == .double ? 4 : 3 }
    var emoji: String { self == .double ? "🏁" : "🌙" }
}

private struct OBMealTile: View {
    let eyebrow: String
    let name: String
    let level: OBPortionLevel
    let why: String
    let portionText: String
    let macros: (Int, Int, Int)
    let startsOpen: Bool

    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 13) {
                Text(level.emoji)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11).fill(OB.track))
                VStack(alignment: .leading, spacing: 1) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(OB.ink3)
                    Text(name)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(OB.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(level.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(level.color)
                    HStack(spacing: 4) {
                        ForEach(0..<4) { i in
                            Circle()
                                .fill(i < level.filled ? level.color : OB.track)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }

            Text(.init(why))
                .font(.system(size: 12.5))
                .foregroundStyle(OB.ink2)
                .lineSpacing(2)

            if open {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 12) {
                        Text("🍚").font(.system(size: 26))
                        Text(.init(portionText))
                            .font(.system(size: 13.5))
                            .foregroundStyle(OB.ink2)
                    }
                    HStack {
                        macroCell("\(macros.0)g", "carbs")
                        Spacer()
                        macroCell("\(macros.1)g", "protein")
                        Spacer()
                        macroCell("\(macros.2)g", "fat")
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(OB.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(OB.cardBorder, lineWidth: 1))
                }
                .padding(.top, 4)
                .transition(.opacity)
            }

            Text(open ? "Tap to collapse" : "Tap to see the numbers")
                .font(.system(size: 11.5))
                .foregroundStyle(OB.ink3)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { open.toggle() } }
        .onAppear { open = startsOpen }
    }

    private func macroCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(OB.serif(15)).foregroundStyle(OB.ink)
            Text(label).font(.system(size: 12.5)).foregroundStyle(OB.ink2)
        }
    }
}
