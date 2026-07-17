import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "OnboardingSubmitter")

// The screen-28 write pipeline. Runs once, after a Clerk session exists, and
// persists everything onboarding collected: the users row (biometrics + diet +
// activities), the active race, the meal library (each estimated via Claude),
// and a seed macro target for today. Ordered so RLS resolves — create-user-profile
// inserts the row (service role) before any Clerk-JWT update/insert touches it.
enum OnboardingSubmitter {

    // MARK: - Public

    static func submit(data: OnboardingData, clerkId: String) async throws {
        // 1. Ensure the users row exists (service-role insert of clerk_id/email).
        try await createUserProfile()

        let client = try await SupabaseService.shared.authenticatedClient()

        // 2. Fill in the profile the funnel collected.
        try await updateUserProfile(data: data, client: client)

        // 3. Active race (uuid-keyed → needs users.id).
        let userUUID = try await fetchUserUUID(clerkId: clerkId, client: client)
        if let raceType = data.raceType, let raceDateISO = data.raceDateISO {
            try await insertRace(data: data, raceType: raceType, raceDateISO: raceDateISO,
                                 userUUID: userUUID, client: client)
        }

        // 4. Meal library (text-keyed by clerk_id). Estimation failures still
        //    save the meal with nil macros (re-estimated later, per AGENTS).
        try await insertMeals(data: data, clerkId: clerkId, client: client)

        // 5. Seed today's macro target. Today recomputes live from MacroEngine, so
        //    this is a convenience row, not a source of truth — never block on it.
        await seedTodayMacroTarget(data: data, userUUID: userUUID, client: client)
    }

    // Flips has_completed_onboarding once the flow finishes. Best-effort.
    static func markOnboardingComplete() async {
        struct CompleteUpdate: Encodable { let has_completed_onboarding: Bool }
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            try await client.from("users")
                .update(CompleteUpdate(has_completed_onboarding: true))
                .execute()
        } catch {
            logger.error("markOnboardingComplete failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Routing read for ContentView: has this user finished onboarding?
    static func fetchOnboardingComplete() async -> Bool? {
        struct Row: Decodable { let has_completed_onboarding: Bool }
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            let rows: [Row] = try await client.from("users")
                .select("has_completed_onboarding")
                .limit(1)
                .execute()
                .value
            return rows.first?.has_completed_onboarding
        } catch {
            logger.error("fetchOnboardingComplete failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Steps

    private static func updateUserProfile(data: OnboardingData, client: SupabaseClient) async throws {
        struct UserUpdate: Encodable {
            let gender: String?
            let age: Int
            let weight_kg: Double
            let height_cm: Double
            let units: String
            let training_level: String?
            let weekly_activities: [String]
            let diet: String
        }
        try await client.from("users")
            .update(UserUpdate(
                gender: data.gender,
                age: data.age,
                weight_kg: data.weightKg,
                height_cm: data.heightCm,
                units: data.units,
                training_level: data.trainingLevel,
                weekly_activities: data.activities.map(\.rawValue),
                diet: data.diet
            ))
            .execute()
    }

    private static func insertRace(
        data: OnboardingData, raceType: String, raceDateISO: String,
        userUUID: UUID, client: SupabaseClient
    ) async throws {
        struct RaceInsert: Encodable {
            let user_id: String
            let race_type: String
            let race_name: String?
            let race_date: String
            let is_active: Bool
        }
        let name = data.raceName.trimmingCharacters(in: .whitespaces)
        try await client.from("races")
            .insert(RaceInsert(
                user_id: userUUID.uuidString,
                race_type: raceType,
                race_name: name.isEmpty ? nil : name,
                race_date: raceDateISO,
                is_active: true
            ))
            .execute()
    }

    private static func insertMeals(
        data: OnboardingData, clerkId: String, client: SupabaseClient
    ) async throws {
        struct MealInsert: Encodable {
            let user_id: String
            let meal_name: String
            let meal_time: String
            let estimated_macros: EstimatedMacros?
            let portion_baseline: Double
            let is_active: Bool
            let sort_order: Int
        }

        let token = try? await ClerkService.currentToken()
        var sortOrder = 0

        for time in MealTime.allCases {
            for description in data.meals(for: time) {
                let macros: EstimatedMacros? = await {
                    guard let token else { return nil }
                    return try? await AnthropicService.estimateMeal(description: description, clerkToken: token)
                }()

                try await client.from("meals")
                    .insert(MealInsert(
                        user_id: clerkId,
                        meal_name: description,
                        meal_time: time.rawValue,
                        estimated_macros: macros,
                        portion_baseline: 1,
                        is_active: true,
                        sort_order: sortOrder
                    ))
                    .execute()
                sortOrder += 1
                MixpanelService.track(.mealAdded(mealTime: time.rawValue))
            }
        }
    }

    private static func seedTodayMacroTarget(
        data: OnboardingData, userUUID: UUID, client: SupabaseClient
    ) async {
        struct MacroTargetInsert: Encodable {
            let user_id: String
            let target_date: String
            let calories_kcal: Int
            let carbs_g: Int
            let protein_g: Int
            let fat_g: Int
            let target_type: String
        }
        // Neutral rest-day seed; the live engine adjusts per training day.
        let target = MacroEngine.calculate(
            user: data.macroProfile, raceDate: data.raceDateISO, sessionType: "rest"
        )
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        do {
            try await client.from("macro_targets")
                .insert(MacroTargetInsert(
                    user_id: userUUID.uuidString,
                    target_date: f.string(from: Date()),
                    calories_kcal: Int(target.caloriesKcal.rounded()),
                    carbs_g: Int(target.carbsG.rounded()),
                    protein_g: Int(target.proteinG.rounded()),
                    fat_g: Int(target.fatG.rounded()),
                    target_type: "rest"
                ))
                .execute()
        } catch {
            logger.error("seedTodayMacroTarget failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private static func fetchUserUUID(clerkId: String, client: SupabaseClient) async throws -> UUID {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client.from("users")
            .select("id")
            .eq("clerk_id", value: clerkId)
            .limit(1)
            .execute()
            .value
        guard let id = rows.first?.id else { throw AppError.invalidResponse }
        return id
    }

    // Mirrors SignUpView.createUserProfile — inserts the users row via the
    // create-user-profile Edge Function (service role). Idempotent server-side.
    private static func createUserProfile() async throws {
        let token = try await ClerkService.currentToken()
        let url = URL(string: "\(Constants.supabaseURL)/functions/v1/create-user-profile")!
        var request = URLRequest(url: url, timeoutInterval: Constants.apiTimeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Constants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue(token, forHTTPHeaderField: "x-clerk-token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            logger.error("create-user-profile returned \(status, privacy: .public)")
            throw AppError.serverError("Couldn't create your account profile.")
        }
    }
}
