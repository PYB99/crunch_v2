import Foundation

// Pure calculation engine — maps daily macro targets to per-meal portion multipliers.
// Base distribution: 25% breakfast / 35% lunch / 40% dinner (master-spec §8.2).
// Snacks take 15% each, capped at 25% total; the three main meals renormalize to
// fill the remainder (§8.2). The day-before long-run/race carb boost (§4.2) is
// added to dinner on top of its share (master-spec Layer 8).
enum PortionEngine {

    private static let mainDistribution: [String: Double] = [
        "breakfast": 0.25,
        "lunch":     0.35,
        "dinner":    0.40
    ]

    private static let snackSharePerMeal: Double = 0.15
    private static let snackShareCap: Double = 0.25

    // Returns one PortionResult per meal that has macro data and a known meal_time
    // (breakfast/lunch/dinner/snack). Input meals are already sorted by sort_order.
    static func portions(target: MacroTarget, meals: [Meal]) -> [PortionResult] {
        // Snacks eligible for a share: those that will actually render a result.
        let snackCount = meals.filter {
            $0.mealTime == "snack" && ($0.estimatedMacros?.carbsG ?? 0) > 0
        }.count
        let snackShareTotal = min(snackSharePerMeal * Double(snackCount), snackShareCap)
        let perSnackShare   = snackCount > 0 ? snackShareTotal / Double(snackCount) : 0
        let mainScale       = 1.0 - snackShareTotal   // main meals renormalize (§8.2)

        return meals.compactMap { meal in
            guard let macros = meal.estimatedMacros, macros.carbsG > 0 else { return nil }

            let share: Double
            if meal.mealTime == "snack" {
                share = perSnackShare
            } else if let mainShare = mainDistribution[meal.mealTime] {
                share = mainShare * mainScale
            } else {
                return nil   // unknown meal_time
            }

            // Day-before boost lands entirely on dinner, over and above its share.
            let dinnerBoostG   = meal.mealTime == "dinner" ? target.dayBeforeCarbBoostG : 0
            let targetCarbsG   = target.carbsG   * share + dinnerBoostG
            let targetProteinG = target.proteinG * share
            let targetFatG     = target.fatG     * share

            let multiplier = targetCarbsG / macros.carbsG
            let level      = portionLevel(multiplier)

            return PortionResult(
                meal: meal,
                multiplier: multiplier,
                level: level,
                targetCarbsG: targetCarbsG,
                targetProteinG: targetProteinG,
                targetFatG: targetFatG,
                breakdown: breakdown(for: meal, multiplier: multiplier, level: level),
                gramDetails: "~\(Int(targetCarbsG.rounded()))g carbs · ~\(Int(targetProteinG.rounded()))g protein · ~\(Int(targetFatG.rounded()))g fat"
            )
        }
    }

    // MARK: - Private

    private static func portionLevel(_ multiplier: Double) -> PortionLevel {
        if multiplier <= 1.25 { return .normal }
        if multiplier <= 1.75 { return .extra }
        return .double
    }

    private static func breakdown(for meal: Meal, multiplier: Double, level: PortionLevel) -> String {
        switch level {
        case .normal:
            return "Your usual \(meal.mealName) — no change needed."
        case .extra:
            return "About \(String(format: "%.1f", multiplier))× your usual serving of \(meal.mealName)."
        case .double:
            return "Double your usual \(meal.mealName) — this is your biggest fuel window today."
        }
    }
}
