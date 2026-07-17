import Foundation

struct MacroTarget {
    let carbsG: Double
    let proteinG: Double
    let fatG: Double
    let caloriesKcal: Double
    let sessionType: String
    let trainingPhase: String
    // Reconciliation flags raised by the Fat Engine (master spec §6.1):
    // "fat_floor_triggered" (FIX A ran) / "carb_load_capped" (FIX B ran).
    // Computed for testability + future explainability UI; no reader yet.
    let flags: [String]
    // Extra dinner-only carbs for tomorrow's long run/race (§4.2). Deliberately
    // NOT part of the reconciled daily totals above — the Portion Engine adds it
    // to the dinner meal (Layer 8). 0 on ordinary days.
    let dayBeforeCarbBoostG: Double

    init(
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        caloriesKcal: Double,
        sessionType: String,
        trainingPhase: String,
        flags: [String] = [],
        dayBeforeCarbBoostG: Double = 0
    ) {
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.caloriesKcal = caloriesKcal
        self.sessionType = sessionType
        self.trainingPhase = trainingPhase
        self.flags = flags
        self.dayBeforeCarbBoostG = dayBeforeCarbBoostG
    }
}
