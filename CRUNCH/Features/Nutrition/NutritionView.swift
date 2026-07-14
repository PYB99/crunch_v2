import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class NutritionViewModel {

    var meals: [Meal] = []
    var userProfile: UserProfile = .fallback
    var race: Race?
    var clerkUserId: String = ""
    var isLoading = false
    var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try await SupabaseService.shared.authenticatedClient()

            struct UserRow: Codable {
                let clerkId: String
                let weightKg: Double?
                let heightCm: Double?
                let age: Int?
                let gender: String?
                let trainingLevel: String?
                enum CodingKeys: String, CodingKey {
                    case clerkId      = "clerk_id"
                    case weightKg     = "weight_kg"
                    case heightCm     = "height_cm"
                    case age, gender
                    case trainingLevel = "training_level"
                }
            }
            let userRows: [UserRow] = try await client.from("users").select().execute().value
            if let u = userRows.first {
                clerkUserId = u.clerkId
                userProfile = UserProfile(
                    weightKg:      u.weightKg      ?? UserProfile.fallback.weightKg,
                    heightCm:      u.heightCm      ?? UserProfile.fallback.heightCm,
                    age:           u.age           ?? UserProfile.fallback.age,
                    gender:        u.gender        ?? UserProfile.fallback.gender,
                    trainingLevel: u.trainingLevel ?? UserProfile.fallback.trainingLevel
                )
            }

            let races: [Race] = try await client.from("races")
                .select()
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value
            race = races.first

            meals = try await client.from("meals")
                .select()
                .eq("is_active", value: true)
                .order("sort_order")
                .execute()
                .value
        } catch {
            errorMessage = "Something went wrong. Tap to retry."
        }
    }

    func deleteMeal(_ meal: Meal) async {
        struct SoftDelete: Encodable { let is_active: Bool }
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            try await client.from("meals")
                .update(SoftDelete(is_active: false))
                .eq("id", value: meal.id.uuidString)
                .execute()
            meals.removeAll { $0.id == meal.id }
        } catch {
            errorMessage = "Couldn't delete meal. Try again."
        }
    }
}

// MARK: - View

struct NutritionView: View {
    @State private var viewModel = NutritionViewModel()
    @State private var showingAddSheet = false
    @State private var addingForTime = "breakfast"
    @State private var showingEditSheet = false
    @State private var mealToEdit: Meal?

    var body: some View {
        let _ = print("DEBUG: NutritionView.body entered")
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.meals.isEmpty {
                    loadingContent
                } else {
                    mainContent
                }
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Nutrition")
                        .font(Theme.subheading)
                        .foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Phase 8: push SettingsView
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditMealView(
                mealTime: addingForTime,
                existingMeal: nil,
                clerkUserId: viewModel.clerkUserId
            ) {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let meal = mealToEdit {
                AddEditMealView(
                    mealTime: meal.mealTime,
                    existingMeal: meal,
                    clerkUserId: viewModel.clerkUserId
                ) {
                    Task { await viewModel.load() }
                }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: Theme.md) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonView(height: 72).padding(.horizontal, Theme.md)
                }
            }
            .padding(.top, Theme.md)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.lg) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) { Task { await viewModel.load() } }
                        .padding(.horizontal, Theme.md)
                }

                mealsSection
                scienceSection
                macroDetailSection

                Color.clear.frame(height: Theme.sm)
            }
            .padding(.top, Theme.md)
        }
        .contentMargins(.bottom, Theme.xl, for: .scrollContent)
        .refreshable { await viewModel.load() }
    }

    // MARK: - My Meals

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            Text("My Meals")
                .font(Theme.subheading)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.md)

            if viewModel.meals.isEmpty {
                EmptyStateView(
                    systemImage: "fork.knife",
                    title: "No meals yet",
                    subtitle: "Add your usual meals and Crunch will calculate your exact portions.",
                    actionLabel: "+ Add your first meal"
                ) {
                    addingForTime = "breakfast"
                    showingAddSheet = true
                }
                .padding(.horizontal, Theme.md)
            } else {
                MealLibraryView(
                    meals: viewModel.meals,
                    onAdd: { time in
                        addingForTime = time
                        showingAddSheet = true
                    },
                    onEdit: { meal in
                        mealToEdit = meal
                        showingEditSheet = true
                    },
                    onDelete: { meal in
                        Task { await viewModel.deleteMeal(meal) }
                    }
                )
            }
        }
    }

    // MARK: - The Science

    private var scienceSection: some View {
        let kg = viewModel.userProfile.weightKg
        let weeksLeft = viewModel.race.map {
            MacroEngine.weeksUntil(dateString: $0.raceDate)
        } ?? 16
        let phase = MacroEngine.trainingPhase(weeksToRace: weeksLeft).rawValue
        let maxCarbsG = Int((10.0 * kg).rounded())
        let proteinG   = Int((1.7  * kg).rounded())
        let fatFloorG  = Int((0.5  * kg).rounded())

        return VStack(alignment: .leading, spacing: Theme.sm) {
            Text("The Science")
                .font(Theme.subheading)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.md)

            ScienceCardView(
                title: "Carbohydrate targets",
                bodyText: "On training days, you need 6–10g of carbs per kg bodyweight — up to \(maxCarbsG)g on a race or long run day for your \(Int(kg))kg. Rest days drop to ~\(Int((4.0 * kg).rounded()))g. Eating more fuel on the days you actually burn it is called carb periodisation — it's one of the biggest levers in endurance nutrition.",
                citation: "Burke LM et al. Carbohydrates for training and competition. Journal of Sports Sciences, 2011."
            )

            ScienceCardView(
                title: "Protein for endurance runners",
                bodyText: "Endurance runners need more protein than sedentary adults — 1.7g per kg supports muscle repair and glycogen resynthesis. For you, that's ~\(proteinG)g daily. This target stays constant regardless of training intensity. Spread it across meals; the body absorbs roughly 25–40g per sitting.",
                citation: "Morton RW et al. Protein supplementation meta-analysis. BJSM, 2018; ISSN Position Stand, 2017."
            )

            ScienceCardView(
                title: "Fat in your training diet",
                bodyText: "Fat is essential, not optional. A minimum of 0.5g/kg (~\(fatFloorG)g for you) provides essential fatty acids, fat-soluble vitamins, and supports hormonal health. On high-carb training days, fat portions adjust down automatically so carbs aren't crowded out — Crunch enforces this floor automatically.",
                citation: "ACSM & AND. Joint Position Statement: Nutrition and Athletic Performance, 2016."
            )

            ScienceCardView(
                title: "Training phases and fueling",
                bodyText: "You are currently in \(phase). As the race approaches, carb targets peak then stabilise during the taper — maintaining carbs while training volume drops keeps glycogen stores full. In the 3 days before your race, carbs jump to 11g/kg for maximum pre-race glycogen loading.",
                citation: "Mujika I & Padilla S. Precompetition tapering strategies. MSSE, 2003; Burke LM et al., 2011."
            )
        }
    }

    // MARK: - Macro Detail

    private var macroDetailSection: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            MacroDetailView(
                userProfile: viewModel.userProfile,
                race: viewModel.race
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NutritionView()
}
