import Foundation

// Dietary preference collected at onboarding screen 20 (single-select) and read
// by the Macro Engine. Only these four are offered in-app; low-carb/keto is not
// an option but the engine still guards against it if the field ever holds one
// (master-spec §9.2). Exclusions/allergies are out of scope this phase (§9.3 —
// meal-library filtering only, no macro impact).
enum DietPreference: String, CaseIterable, Codable {
    case omnivore
    case vegetarian
    case vegan
    case pescatarian

    var displayName: String {
        switch self {
        case .omnivore:    return "Omnivore"
        case .vegetarian:  return "Vegetarian"
        case .vegan:       return "Vegan"
        case .pescatarian: return "Pescatarian"
        }
    }

    // Protein digestibility modifier (§2.4). Omnivore/pescatarian are the 1.00
    // reference (fish protein quality equals omnivore); dairy/eggs give
    // vegetarians a mild 1.05; plant-only 1.10 for lower digestibility + leucine
    // (Rogerson 2017; Lynch et al. 2018).
    var proteinModifier: Double {
        switch self {
        case .omnivore, .pescatarian: return 1.00
        case .vegetarian:             return 1.05
        case .vegan:                  return 1.10
        }
    }
}

// Diet-layer helpers that operate on the stored diet string (User.diet /
// UserProfile.diet), kept string-based to match how gender/training_level flow
// through the engine.
enum DietLayer {
    // Low-carb availability impairs exercise economy at race pace (Burke 2017).
    // The engine must not silently prescribe 10 g/kg carbs to a stated keto user,
    // and must not silently comply either — it raises a flag and lets the Coach
    // have the conversation. These diets are NOT offered in onboarding; the guard
    // exists for imported/edited profiles. Copy lives in Constants.dietCarbConflictCoachCopy.
    static let lowCarbDiets: Set<String> = ["keto", "ketogenic", "low_carb", "carnivore"]

    static let dietCarbConflictFlag = "diet_carb_conflict"

    // Protein modifier for any stored diet string. Unknown or nil → 1.00 (the
    // omnivore reference); low-carb strings also return 1.00 — they get a flag,
    // never a macro modifier.
    static func proteinModifier(for diet: String?) -> Double {
        guard let diet, let pref = DietPreference(rawValue: diet) else { return 1.00 }
        return pref.proteinModifier
    }

    static func isLowCarbConflict(_ diet: String?) -> Bool {
        guard let diet else { return false }
        return lowCarbDiets.contains(diet)
    }
}
