import Foundation

struct User: Codable {
    let id: UUID
    let clerkId: String
    let email: String?
    let heightCm: Double?
    let weightKg: Double?
    let age: Int?
    let gender: String?
    let units: String?
    let trainingLevel: String?
    let diet: String?
    let hasCompletedOnboarding: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case clerkId = "clerk_id"
        case email
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case age, gender, units, diet
        case trainingLevel = "training_level"
        case hasCompletedOnboarding = "has_completed_onboarding"
    }
}

struct UserProfile {
    let weightKg: Double
    let heightCm: Double
    let age: Int
    let gender: String
    let trainingLevel: String
    let diet: String

    static let fallback = UserProfile(
        weightKg: 70, heightCm: 175, age: 30, gender: "male", trainingLevel: "beginner"
    )

    init(from user: User) {
        weightKg      = user.weightKg      ?? Self.fallback.weightKg
        heightCm      = user.heightCm      ?? Self.fallback.heightCm
        age           = user.age           ?? Self.fallback.age
        gender        = user.gender        ?? Self.fallback.gender
        trainingLevel = user.trainingLevel ?? Self.fallback.trainingLevel
        diet          = user.diet          ?? Self.fallback.diet
    }

    // diet defaults to omnivore (the 1.00 protein reference) so existing call
    // sites and the fallback profile keep compiling and computing unchanged.
    init(weightKg: Double, heightCm: Double, age: Int, gender: String,
         trainingLevel: String, diet: String = "omnivore") {
        self.weightKg      = weightKg
        self.heightCm      = heightCm
        self.age           = age
        self.gender        = gender
        self.trainingLevel = trainingLevel
        self.diet          = diet
    }
}
