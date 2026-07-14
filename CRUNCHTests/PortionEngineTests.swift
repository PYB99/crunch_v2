import Testing
import Foundation
@testable import CRUNCH

// @MainActor: model/engine types are MainActor-isolated under the app's
// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor; the nonisolated test suite hops to
// MainActor to use them under Swift 6 (see item 3 notes).
@MainActor
struct PortionEngineTests {

    // Helpers

    func makeMeal(time: String, carbsG: Double, proteinG: Double = 20, fatG: Double = 10, order: Int = 1) -> Meal {
        Meal(
            id: UUID(),
            userId: "test_user",
            mealName: "Test \(time)",
            mealTime: time,
            estimatedMacros: EstimatedMacros(carbsG: carbsG, proteinG: proteinG, fatG: fatG),
            portionBaseline: 1,
            isActive: true,
            sortOrder: order
        )
    }

    func makeTarget(carbsG: Double, proteinG: Double = 120, fatG: Double = 60) -> MacroTarget {
        MacroTarget(carbsG: carbsG, proteinG: proteinG, fatG: fatG, caloriesKcal: 2000, sessionType: "rest", trainingPhase: "Base Building")
    }

    // MARK: - Portion Levels

    @Test func normalLevel() {
        // Target carbs for breakfast: 300 * 0.25 = 75g. Baseline: 70g. Multiplier = 75/70 ≈ 1.07 → normal
        let meal   = makeMeal(time: "breakfast", carbsG: 70)
        let target = makeTarget(carbsG: 300)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(results.count == 1)
        #expect(results[0].level == .normal)
        #expect(results[0].level.label == "Normal portions")
        #expect(results[0].level.dotCount == 2)
    }

    @Test func extraLevel() {
        // Target carbs for breakfast: 500 * 0.25 = 125g. Baseline: 80g. Multiplier = 125/80 = 1.5625 → extra
        let meal   = makeMeal(time: "breakfast", carbsG: 80)
        let target = makeTarget(carbsG: 500)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(results[0].level == .extra)
        #expect(results[0].level.dotCount == 3)
    }

    @Test func doubleLevel() {
        // Target carbs for breakfast: 640 * 0.25 = 160g. Baseline: 65g. Multiplier = 160/65 ≈ 2.46 → double
        let meal   = makeMeal(time: "breakfast", carbsG: 65)
        let target = makeTarget(carbsG: 640)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(results[0].level == .double)
        #expect(results[0].level.dotCount == 4)
    }

    // MARK: - Level Boundaries

    @Test func normalExactBoundary() {
        // Multiplier exactly 1.25 → normal (≤ 1.25)
        // meal carbs = 100, 100 * 0.25 = 25 target, baseline = 20 → multiplier = 1.25
        let meal   = makeMeal(time: "breakfast", carbsG: 20)
        let target = makeTarget(carbsG: 100)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(results[0].level == .normal)
    }

    @Test func extraExactBoundary() {
        // Multiplier exactly 1.75 → extra (≤ 1.75)
        // meal carbs = 20, target carbs = 140 * 0.25 = 35 → multiplier = 35/20 = 1.75
        let meal   = makeMeal(time: "breakfast", carbsG: 20)
        let target = makeTarget(carbsG: 140)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(results[0].level == .extra)
    }

    @Test func justAboveExtraBoundary() {
        // Multiplier 1.75 + epsilon → double
        // Baseline 20, target = 140.01 * 0.25 = 35.0025 → multiplier > 1.75
        let meal   = makeMeal(time: "breakfast", carbsG: 20)
        let target = makeTarget(carbsG: 141)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(results[0].level == .double)
    }

    // MARK: - Distribution

    @Test func distributionSumsToOne() {
        // 25% + 35% + 40% = 100%
        let meals = [
            makeMeal(time: "breakfast", carbsG: 65, order: 1),
            makeMeal(time: "lunch",     carbsG: 70, order: 2),
            makeMeal(time: "dinner",    carbsG: 85, order: 3)
        ]
        let target = makeTarget(carbsG: 600, proteinG: 120, fatG: 60)
        let results = PortionEngine.portions(target: target, meals: meals)
        let totalCarbs = results.reduce(0) { $0 + $1.targetCarbsG }
        #expect(abs(totalCarbs - 600) < 0.01)
    }

    @Test func gramDetailsFormatting() {
        let meal   = makeMeal(time: "dinner", carbsG: 85, proteinG: 40, fatG: 12)
        // dinner: 40% of 640g carbs = 256g, 40% of 120g protein = 48g, 40% of 60g fat = 24g
        let target = makeTarget(carbsG: 640, proteinG: 120, fatG: 60)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(results[0].gramDetails.contains("g carbs"))
        #expect(results[0].gramDetails.contains("g protein"))
        #expect(results[0].gramDetails.contains("g fat"))
    }

    // MARK: - Edge Cases

    @Test func mealWithNilMacrosSkipped() {
        let mealWithMacros = makeMeal(time: "lunch", carbsG: 70)
        let mealNoMacros = Meal(
            id: UUID(), userId: "test_user", mealName: "Unknown meal",
            mealTime: "breakfast", estimatedMacros: nil,
            portionBaseline: 1, isActive: true, sortOrder: 1
        )
        let target  = makeTarget(carbsG: 300)
        let results = PortionEngine.portions(target: target, meals: [mealNoMacros, mealWithMacros])
        #expect(results.count == 1)
        #expect(results[0].meal.mealTime == "lunch")
    }

    @Test func snackMealSkipped() {
        let snack  = makeMeal(time: "snack",  carbsG: 30)
        let dinner = makeMeal(time: "dinner", carbsG: 85)
        let target = makeTarget(carbsG: 400)
        let results = PortionEngine.portions(target: target, meals: [snack, dinner])
        #expect(results.count == 1)
        #expect(results[0].meal.mealTime == "dinner")
    }

    @Test func mealWithZeroCarbsSkipped() {
        let zeroCarbMeal = makeMeal(time: "breakfast", carbsG: 0)
        let target  = makeTarget(carbsG: 300)
        let results = PortionEngine.portions(target: target, meals: [zeroCarbMeal])
        #expect(results.isEmpty)
    }

    @Test func multiplierCalculation() {
        // Explicit multiplier check: dinner 40% of 637.5g = 255g target / 85g baseline = 3.0
        let meal   = makeMeal(time: "dinner", carbsG: 85)
        let target = makeTarget(carbsG: 637.5)
        let results = PortionEngine.portions(target: target, meals: [meal])
        #expect(abs(results[0].multiplier - 3.0) < 0.01)
    }
}
