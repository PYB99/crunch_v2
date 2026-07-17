import SwiftUI

struct OBLetterConfig {
    let lines: (OnboardingData) -> [String]   // markdown-bold strings
    let cta: String
}

// Reflection (16) and bridge (18) — serif lines that fade up in sequence
// (mockup .letter). No top bar; a single CTA at the bottom.
struct LetterScreen: View {
    let coordinator: OnboardingCoordinator
    let config: OBLetterConfig
    @State private var appeared = false

    private var lines: [String] { config.lines(coordinator.data) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                Text(.init(line))
                    .font(OB.serif(19.5, .regular))
                    .foregroundStyle(OB.ink2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.7).delay(0.1 + Double(i) * 0.6), value: appeared)
            }
            Spacer()
            OnboardingCTA(title: config.cta) { coordinator.advance() }
        }
        .padding(.horizontal, OB.gutter)
        .padding(.top, 64)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(OB.bg.ignoresSafeArea())
        .onAppear { appeared = true }
    }
}

// MARK: - Presets

extension OBLetterConfig {
    static let reflection = OBLetterConfig(
        lines: { data in
            let level = data.trainingLevel ?? "training"
            let race = data.raceName.trimmingCharacters(in: .whitespaces)
            let raceName = race.isEmpty ? "your race" : race
            let weeks = data.weeksToRace ?? 0
            var lines = [
                "So — you're **\(level)**, \(weeks) weeks out from **\(raceName)**.",
                "Your longest run so far is **\(data.longestRunKm)K**."
            ]
            if data.painPoints.contains("hit_the_wall") {
                lines.append("And the wall late in a race has bitten before.")
            } else if !data.painPoints.isEmpty {
                lines.append("And fueling has tripped you up before.")
            }
            lines.append("Let's make sure it doesn't again, **\(data.displayName)**.")
            return lines
        },
        cta: "Continue"
    )

    static let bridge = OBLetterConfig(
        lines: { data in
            [
                "It doesn't have to be guesswork.",
                "Two more minutes, **\(data.displayName)** —",
                "let's build your fuel plan."
            ]
        },
        cta: "Let's do it"
    )
}
