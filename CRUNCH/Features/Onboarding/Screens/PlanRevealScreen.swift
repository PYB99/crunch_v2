import SwiftUI

// Screen 29 — the peak. Checkmark pop + confetti, count-up stats, and the
// projection chart (mockup .reveal). Data rehydrates from OnboardingData, which
// is intact both on the fresh path and when resuming here after account creation.
struct PlanRevealScreen: View {
    let coordinator: OnboardingCoordinator
    @State private var checkScale: CGFloat = 0

    private var data: OnboardingData { coordinator.data }

    private var raceName: String {
        let n = data.raceName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "race" : n
    }

    private var raceDateLabel: String {
        guard let date = data.raceDate else { return "your race" }
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(OB.jade).frame(width: 56, height: 56)
                        .scaleEffect(checkScale)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .scaleEffect(checkScale)
                        )
                    ConfettiView()
                }
                .frame(height: 80)
                .padding(.top, 10)

                Text("\(data.displayName), your \(raceName) fuel plan is ready")
                    .font(OB.serif(29, .semibold))
                    .foregroundStyle(OB.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Text("Portioned to your training, all the way to the start line.")
                    .font(.system(size: 15))
                    .foregroundStyle(OB.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                Text("Race-ready by \(raceDateLabel)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OB.gold)
                    .padding(.vertical, 11).padding(.horizontal, 18)
                    .background(Capsule().fill(OB.gold.opacity(0.14)))
                    .padding(.top, 20)

                ProjectionChartCard(height: 130).padding(.top, 18)

                HStack(spacing: 10) {
                    statTile(target: data.daysToRace ?? 0, label: "days to race")
                    statTile(target: 3, label: "meals tuned daily")
                    statTile(target: max(1, data.weeksToRace ?? 0), label: "week plan")
                }
                .padding(.vertical, 20)

                OnboardingCTA(title: "See my plan") { coordinator.advance() }
            }
            .padding(.horizontal, OB.gutter)
            .padding(.top, 64)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) { checkScale = 1 }
        }
    }

    private func statTile(target: Int, label: String) -> some View {
        VStack(spacing: 2) {
            CountUpText(target: target)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(OB.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 16).fill(OB.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(OB.cardBorder, lineWidth: 1))
    }
}
