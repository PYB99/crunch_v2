import Foundation

// Every answer collected across the 33 steps, held by OnboardingCoordinator and
// never touched by the network until screen 28 (createAccount). Neutral defaults
// (not the mockup's demo values) so a real runner starts from a clean slate.
//
// Persistence split (per Phase 5 decisions 1–2):
//   • DB (users/races/meals): name→(none), gender, age, weight, height, units,
//     trainingLevel, diet, activities, race*, meals.
//   • Mixpanel only (no columns): attribution, longestRunKm, painPoints, commitment.
struct OnboardingData {
    // Identity / personalisation
    var name: String = ""

    // Mixpanel-only signals
    var attribution: String?              // reddit / friend / app_store / social / other
    var longestRunKm: Int = 10
    var painPoints: Set<String> = []      // screen 15 slugs
    var commitment: String?               // screen 27 slug

    // Race
    var raceType: String?                 // 5k / 10k / half_marathon / marathon / ultra_marathon / other
    var raceName: String = ""
    var raceDate: Date?

    // Biometrics
    var gender: String?                   // male / female
    var age: Int = 30
    var weightKg: Double = 70
    var heightCm: Double = 175
    var units: String = "metric"          // metric / imperial (display only)
    var trainingLevel: String?            // beginner / intermediate / advanced

    // Training context
    var activities: Set<ActivityType> = []

    // Diet + meals (each slot allows multiple free-text entries; empty = skipped)
    var diet: String = DietPreference.omnivore.rawValue

    // Optional passthrough so the single-select archetype (which stores into
    // WritableKeyPath<_, String?>) can drive the non-optional diet field.
    var dietOptional: String? {
        get { diet }
        set { if let newValue { diet = newValue } }
    }

    var breakfastMeals: [String] = [""]
    var lunchMeals: [String] = [""]
    var dinnerMeals: [String] = [""]

    // Integrations connected during onboarding (screen 24) — display state only.
    var stravaConnected = false
    var runnaConnected = false

    // MARK: - Derived

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Runner" : trimmed
    }

    var daysToRace: Int? {
        guard let raceDate else { return nil }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: Date()), to: raceDate
        ).day ?? 0
        return max(0, days)
    }

    var weeksToRace: Int? {
        guard let days = daysToRace else { return nil }
        return days / 7
    }

    // "roughly N meals between now and the start line" — 3 meals/day (screen 7).
    var mealsToRace: Int? {
        guard let days = daysToRace else { return nil }
        return days * 3
    }

    // races.race_date wants "YYYY-MM-DD".
    var raceDateISO: String? {
        guard let raceDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: raceDate)
    }

    // Non-empty, trimmed meal descriptions for a slot.
    func meals(for time: MealTime) -> [String] {
        let raw: [String]
        switch time {
        case .breakfast: raw = breakfastMeals
        case .lunch:     raw = lunchMeals
        case .dinner:    raw = dinnerMeals
        }
        return raw.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // Profile for the live macro preview (screens 24 / 29) — falls back safely
    // when a biometric is somehow missing.
    var macroProfile: UserProfile {
        UserProfile(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            gender: gender ?? "male",
            trainingLevel: trainingLevel ?? "intermediate",
            diet: diet
        )
    }
}

enum MealTime: String, CaseIterable {
    case breakfast, lunch, dinner
}
