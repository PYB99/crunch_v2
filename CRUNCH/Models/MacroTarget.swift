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

    init(
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        caloriesKcal: Double,
        sessionType: String,
        trainingPhase: String,
        flags: [String] = []
    ) {
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.caloriesKcal = caloriesKcal
        self.sessionType = sessionType
        self.trainingPhase = trainingPhase
        self.flags = flags
    }
}
