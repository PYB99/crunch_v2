import Foundation

struct EstimatedMacros: Codable {
    let carbsG: Double
    let proteinG: Double
    let fatG: Double

    enum CodingKeys: String, CodingKey {
        case carbsG   = "carbs_g"
        case proteinG = "protein_g"
        case fatG     = "fat_g"
    }
}

struct Meal: Codable {
    let id: UUID
    let userId: String              // clerk_id — meals.user_id is text
    let mealName: String
    let mealTime: String            // "breakfast" | "lunch" | "dinner" | "snack"
    let estimatedMacros: EstimatedMacros?
    let portionBaseline: Double?
    let isActive: Bool?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId         = "user_id"
        case mealName       = "meal_name"
        case mealTime       = "meal_time"
        case estimatedMacros = "estimated_macros"
        case portionBaseline = "portion_baseline"
        case isActive       = "is_active"
        case sortOrder      = "sort_order"
    }
}
