import SwiftUI

enum OBSceneMood {
    case neutral, bad
    var accent: Color { self == .bad ? OB.ember : OB.gold }
    var scene: [Color] {
        self == .bad
            ? [Color(hex: "#472310"), Color(hex: "#1A0E08"), OB.bg]
            : [Color(hex: "#3A2F18"), Color(hex: "#16130A"), OB.bg]
    }
}

struct OBSceneConfig {
    let mood: OBSceneMood
    let symbol: String
    let lead: String                                 // may contain {name}
    let big: (OnboardingData) -> String
    let body: (OnboardingData) -> String
}

// Cinematic payoff screens (mockup .scene) — screen 7 "94 days / 280 meals" and
// screen 17 "2 dinners". Full-bleed radial scene, a single glowing object, and a
// big italic serif stat. Art is a tasteful native approximation of the SVG.
struct CinematicSceneScreen: View {
    let coordinator: OnboardingCoordinator
    let config: OBSceneConfig

    private var data: OnboardingData { coordinator.data }

    var body: some View {
        VStack(spacing: 0) {
            art
            VStack(spacing: 12) {
                Text(config.lead.replacingOccurrences(of: "{name}", with: data.displayName))
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(OB.ink)
                    .multilineTextAlignment(.center)
                Text(config.big(data))
                    .font(OB.serif(52, .semibold).italic())
                    .foregroundStyle(config.mood.accent)
                    .multilineTextAlignment(.center)
                Text(config.body(data))
                    .font(.system(size: 15.5))
                    .foregroundStyle(OB.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 310)
            }
            .padding(.horizontal, OB.gutter)
            .padding(.top, 6)

            Spacer(minLength: 12)
            OnboardingCTA(title: "Continue") { coordinator.advance() }
                .padding(.horizontal, OB.gutter)
        }
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
    }

    private var art: some View {
        ZStack {
            RadialGradient(colors: config.mood.scene, center: .init(x: 0.5, y: 0.22),
                           startRadius: 0, endRadius: 320)

            Image(systemName: config.symbol)
                .font(.system(size: 92, weight: .light))
                .foregroundStyle(config.mood.accent.opacity(0.9))
                .shadow(color: config.mood.accent.opacity(0.4), radius: 30, y: 10)
                .offset(y: 14)

            LinearGradient(colors: [.clear, OB.bg], startPoint: .center, endPoint: .bottom)
        }
        .frame(height: 360)
        .overlay(alignment: .top) {
            OnboardingTopBar(coordinator: coordinator, overlayStyle: true)
                .padding(.horizontal, OB.gutter)
                .padding(.top, 64)
        }
    }
}

// MARK: - Presets

extension OBSceneConfig {
    static let hook = OBSceneConfig(
        mood: .neutral,
        symbol: "pills.fill",
        lead: "{name}, here's the math",
        big: { data in "\(data.daysToRace ?? 0) days" },
        body: { data in
            let name = data.raceName.trimmingCharacters(in: .whitespaces)
            let race = name.isEmpty ? "Your race" : name
            let meals = data.mealsToRace ?? 0
            return "\(race) is \(data.daysToRace ?? 0) days out. That's roughly \(meals) meals between now and the start line — and every one of them is training."
        }
    )

    static let bombshell = OBSceneConfig(
        mood: .bad,
        symbol: "fork.knife",
        lead: "Here's the honest part",
        big: { _ in "2 dinners" },
        body: { data in
            "Your long run burns through roughly the fuel of two full dinners. Most runners eat the same on long-run Sunday as on rest-day Tuesday."
        }
    )
}
