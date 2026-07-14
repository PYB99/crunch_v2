import Foundation

// Pure calculation engine — maps daily macro targets to per-meal portion multipliers.
// Distribution: 25% breakfast / 35% lunch / 40% dinner (AGENTS.md Portion Engine spec).
// Snack meals are skipped — no distribution defined.
enum PortionEngine {

    private static let distribution: [String: Double] = [
        "breakfast": 0.25,
        "lunch":     0.35,
        "dinner":    0.40
    ]

    // Returns one PortionResult per meal that has macro data and a known meal_time.
    // Input meals are already sorted by sort_order from the caller.
    static func portions(target: MacroTarget, meals: [Meal]) -> [PortionResult] {
        meals.compactMap { meal in
            guard
                let macros = meal.estimatedMacros,
                let share  = distribution[meal.mealTime],
                macros.carbsG > 0
            else { return nil }

            let targetCarbsG   = target.carbsG   * share
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
