import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class TodayViewModel {

    // MARK: UI State

    var state: TodayState = .trainingDay
    var mealCards: [MealCardData] = []
    var raceName: String = ""
    var weeksToRace: Int = 0
    var trainingPhaseName: String = ""
    var sessionLabel: String = ""
    var sessionSubtitle: String = ""
    var completedSessionLabel: String = ""
    var isLoading = false
    var errorMessage: String?

    // Activity confirmed in DB + used by recalculate()
    var addedActivity: ActivityType?
    var otherActivityDescription: String = ""

    // MARK: Private

    private var userProfile: UserProfile = .fallback
    private var userUUID: UUID?
    private var race: Race?
    private var primarySession: TrainingSession?
    private var previousSessionType: String?   // yesterday's run — drives recovery-day detection
    private var meals: [Meal] = []

    // MARK: - Data Loading

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try await SupabaseService.shared.authenticatedClient()

            // 1. User profile
            struct UserRow: Codable {
                let id: UUID
                let weightKg: Double?
                let heightCm: Double?
                let age: Int?
                let gender: String?
                let trainingLevel: String?
                enum CodingKeys: String, CodingKey {
                    case id
                    case weightKg = "weight_kg"
                    case heightCm = "height_cm"
                    case age, gender
                    case trainingLevel = "training_level"
                }
            }
            let userRows: [UserRow] = try await client.from("users").select().execute().value
            if let u = userRows.first {
                userUUID    = u.id
                userProfile = UserProfile(
                    weightKg:      u.weightKg      ?? UserProfile.fallback.weightKg,
                    heightCm:      u.heightCm      ?? UserProfile.fallback.heightCm,
                    age:           u.age           ?? UserProfile.fallback.age,
                    gender:        u.gender        ?? UserProfile.fallback.gender,
                    trainingLevel: u.trainingLevel ?? UserProfile.fallback.trainingLevel
                )
            }

            // 2. Active race
            let races: [Race] = try await client.from("races")
                .select()
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value
            race = races.first

            // 3. Today's sessions — separate run from activity sessions
            let allSessions: [TrainingSession] = try await client.from("training_sessions")
                .select()
                .eq("session_date", value: todayDateString())
                .execute()
                .value

            primarySession = allSessions.first { MacroEngine.isRunSession($0.sessionType) }
            let activitySessions = allSessions.filter {
                !MacroEngine.isRunSession($0.sessionType) && $0.sessionType != "rest"
            }
            if let dbActivity = activitySessions.first {
                addedActivity = ActivityType(rawValue: dbActivity.sessionType)
            }

            // Yesterday's run — drives recovery-day detection (master spec §3.4)
            let yesterdaySessions: [TrainingSession] = try await client.from("training_sessions")
                .select()
                .eq("session_date", value: yesterdayDateString())
                .execute()
                .value
            previousSessionType = yesterdaySessions.first { MacroEngine.isRunSession($0.sessionType) }?.sessionType

            // 4. Meals ordered by sort_order
            meals = try await client.from("meals")
                .select()
                .eq("is_active", value: true)
                .order("sort_order")
                .execute()
                .value

            recalculate()
        } catch {
            errorMessage = "Something went wrong. Tap to retry."
        }
    }

    // MARK: - Realtime

    private var realtimeListenTask: Task<Void, Never>?
    private var realtimeDebounceTask: Task<Void, Never>?

    // Called from TodayView's .onDisappear — deinit runs nonisolated even on
    // a @MainActor class, so it can't touch these actor-isolated properties.
    func stopRealtimeSubscription() {
        realtimeListenTask?.cancel()
        realtimeListenTask = nil
        realtimeDebounceTask?.cancel()
        realtimeDebounceTask = nil
    }

    // Recalculates Today whenever training_sessions changes for this user —
    // e.g. a Strava webhook write. Debounced and coalesced so a burst of
    // events (or an event arriving while a load() is already in flight)
    // results in exactly one reload afterwards, never a dropped one.
    func startRealtimeSubscription() async {
        guard realtimeListenTask == nil else { return }
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            let token = try await ClerkService.currentToken()
            await client.realtimeV2.setAuth(token)

            let channel = client.channel("training_sessions_changes")
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "training_sessions"
            )
            try await channel.subscribeWithError()

            realtimeListenTask = Task { [weak self] in
                for await _ in changes {
                    self?.scheduleDebouncedReload()
                }
            }
        } catch {
            // Realtime is a freshness optimisation, not a correctness
            // dependency — .task + .refreshable already keep Today
            // eventually consistent without it.
        }
    }

    private func scheduleDebouncedReload() {
        realtimeDebounceTask?.cancel()
        realtimeDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            while self.isLoading {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
            }
            await self.load()
        }
    }

    // MARK: - Activity Management

    func addActivity(_ activity: ActivityType, description: String = "") async {
        addedActivity             = activity
        otherActivityDescription  = description

        // Write to DB (soft-fail — recalculate runs either way)
        if let uuid = userUUID {
            struct ActivityInsert: Encodable {
                let user_id: UUID
                let session_date: String
                let session_type: String
                let source: String
                let status: String
            }
            do {
                let client = try await SupabaseService.shared.authenticatedClient()
                try await client.from("training_sessions").insert(
                    ActivityInsert(
                        user_id: uuid,
                        session_date: todayDateString(),
                        session_type: activity.rawValue,
                        source: "manual",
                        status: "planned"
                    )
                ).execute()
            } catch { /* soft-fail */ }
        }

        recalculate()
    }

    func clearActivity() async {
        let removed              = addedActivity
        addedActivity            = nil
        otherActivityDescription = ""

        if let activity = removed, let uuid = userUUID {
            do {
                let client = try await SupabaseService.shared.authenticatedClient()
                try await client.from("training_sessions")
                    .delete()
                    .eq("user_id", value: uuid.uuidString)
                    .eq("session_date", value: todayDateString())
                    .eq("session_type", value: activity.rawValue)
                    .eq("source", value: "manual")
                    .execute()
            } catch { /* soft-fail */ }
        }

        recalculate()
    }

    // MARK: - Calculation

    func recalculate() {
        // When no primary session exists today → rest day (clarification 1)
        let sessionType = primarySession?.sessionType ?? "rest"
        let activities  = addedActivity.map { [$0] } ?? []

        let target = MacroEngine.calculate(
            user: userProfile,
            raceDate: race?.raceDate,
            sessionType: sessionType,
            previousSessionType: previousSessionType,
            additionalActivities: activities
        )

        // Race header
        if let r = race {
            raceName         = r.raceName ?? "your race"
            weeksToRace      = MacroEngine.weeksUntil(dateString: r.raceDate)
            trainingPhaseName = target.trainingPhase
        } else {
            raceName          = "your race"
            weeksToRace       = 0
            trainingPhaseName = target.trainingPhase
        }

        // Session label — nil session is a first-class rest day (clarification 1)
        if let session = primarySession {
            let typeLabel = session.sessionType.replacingOccurrences(of: "_", with: " ").capitalized
            if let km = session.distanceKm, km > 0 {
                sessionLabel = "Today: \(typeLabel) · \(Int(km.rounded())) km"
            } else {
                sessionLabel = "Today: \(typeLabel)"
            }
            sessionSubtitle = sessionSubtitleText(for: session.sessionType)

            if session.status == "completed" {
                let km = session.distanceKm.map { "\(Int($0.rounded()))K " } ?? ""
                completedSessionLabel = "\(km)\(typeLabel) Complete"
            }
        } else {
            sessionLabel          = "Rest & Recovery"
            sessionSubtitle       = "Normal portions today — your body is rebuilding."
            completedSessionLabel = ""
        }

        // View state
        if meals.isEmpty {
            state = .noMeals
        } else if let session = primarySession, session.status == "completed" {
            state = .postRun
        } else if primarySession == nil {
            state = .restDay    // first-class: nil session → rest macros + rest layout
        } else {
            state = .trainingDay
        }

        // Meal cards
        let portions = PortionEngine.portions(target: target, meals: meals)
        mealCards = portions.map { result in
            MealCardData(
                mealTime: mealTimeEnum(from: result.meal.mealTime),
                mealName: result.meal.mealName,
                filledDots: result.level.dotCount,
                portionLabel: result.level.label,
                reason: reasonText(for: result, totalCarbsG: target.carbsG),
                breakdown: result.breakdown,
                gramDetails: result.gramDetails,
                scienceTip: scienceTip(for: result.meal.mealTime, sessionType: sessionType)
            )
        }
    }

    // MARK: - Preview Support

    static func preview(state: TodayState) -> TodayViewModel {
        let vm = TodayViewModel()
        vm.state = state
        vm.raceName = "Amsterdam Marathon"
        vm.weeksToRace = 15
        vm.trainingPhaseName = "Peak Training"
        vm.sessionLabel = state == .restDay ? "Rest & Recovery" : "Today: Long Run · 22 km"
        vm.sessionSubtitle = state == .restDay
            ? "Normal portions today — your body is rebuilding."
            : "Fuel up tonight — carb loading starts now"
        vm.completedSessionLabel = state == .postRun ? "22K Long Run Complete" : ""

        let fakeMeals = [
            Meal(id: UUID(), userId: "preview", mealName: "Oats + banana + honey",
                 mealTime: "breakfast", estimatedMacros: EstimatedMacros(carbsG: 65, proteinG: 12, fatG: 8),
                 portionBaseline: 1, isActive: true, sortOrder: 1),
            Meal(id: UUID(), userId: "preview", mealName: "Chicken rice bowl",
                 mealTime: "lunch",     estimatedMacros: EstimatedMacros(carbsG: 70, proteinG: 35, fatG: 10),
                 portionBaseline: 1, isActive: true, sortOrder: 2),
            Meal(id: UUID(), userId: "preview", mealName: "Pasta with chicken",
                 mealTime: "dinner",    estimatedMacros: EstimatedMacros(carbsG: 85, proteinG: 40, fatG: 12),
                 portionBaseline: 1, isActive: true, sortOrder: 3)
        ]
        let target = MacroEngine.calculate(
            user: UserProfile(weightKg: 75, heightCm: 178, age: 32, gender: "male", trainingLevel: "intermediate"),
            raceDate: nil,
            sessionType: state == .restDay ? "rest" : "long_run"
        )
        vm.mealCards = PortionEngine.portions(target: target, meals: fakeMeals).map { result in
            MealCardData(
                mealTime: vm.mealTimeEnum(from: result.meal.mealTime),
                mealName: result.meal.mealName,
                filledDots: result.level.dotCount,
                portionLabel: result.level.label,
                reason: vm.reasonText(for: result, totalCarbsG: target.carbsG),
                breakdown: result.breakdown,
                gramDetails: result.gramDetails,
                scienceTip: vm.scienceTip(for: result.meal.mealTime, sessionType: target.sessionType)
            )
        }
        return vm
    }

    // MARK: - Private Helpers

    private func mealTimeEnum(from string: String) -> MealCardData.MealTime {
        switch string {
        case "breakfast": return .breakfast
        case "lunch":     return .lunch
        default:          return .dinner
        }
    }

    private func reasonText(for result: PortionResult, totalCarbsG: Double) -> String {
        switch result.level {
        case .normal:
            return result.meal.mealTime == "breakfast"
                ? "Keep it steady — your biggest carb window is dinner."
                : "Normal load today — standard portions work."
        case .extra:
            return "Training load is up — add an extra serving here."
        case .double:
            return "You need ~\(Int(totalCarbsG.rounded()))g carbs today — make this your fuel meal."
        }
    }

    private func scienceTip(for mealTime: String, sessionType rawType: String) -> String {
        // Collapse split race_* types onto "race" for copy lookup.
        let sessionType = MacroEngine.isRaceSession(rawType) ? "race" : rawType
        switch (mealTime, sessionType) {
        case ("dinner", "long_run"), ("dinner", "race"):
            return "Burke et al. (2011): 8–10g carbs/kg in the 24h before a long effort maximises glycogen storage."
        case ("breakfast", _):
            return "Breakfast tops up liver glycogen depleted overnight. Your biggest carb window is dinner."
        case ("lunch", "long_run"), ("lunch", "race"):
            return "Steady carbs at lunch prime muscle glycogen ahead of tonight's big carb load."
        default:
            return "Carbohydrate periodisation: match carb intake to your training load for optimal performance."
        }
    }

    private func sessionSubtitleText(for rawType: String) -> String {
        // Collapse split race_* types onto "race" for copy lookup.
        let sessionType = MacroEngine.isRaceSession(rawType) ? "race" : rawType
        switch sessionType {
        case "recovery_day": return "Recovery day — refuel and rebuild after yesterday's effort"
        case "long_run":  return "Fuel up tonight — carb loading starts now"
        case "race":      return "Race day fuel — carb-load complete, stay topped up"
        case "tempo":     return "High-intensity day — carbs are your fuel"
        case "interval":  return "High-intensity day — carbs are your fuel"
        case "easy_run":  return "Easy day — balanced portions"
        default:          return "Moderate load — balanced portions"
        }
    }

    private func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func yesterdayDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return fmt.string(from: yesterday)
    }
}

// MARK: - View

enum TodayState {
    case trainingDay
    case postRun
    case restDay
    case noStrava
    case noMeals
}

struct TodayView: View {
    @State private var viewModel = TodayViewModel()
    @State private var showActivitySheet = false
    @State private var pendingActivity: ActivityType?
    @State private var pendingOtherDescription = ""
    @State private var showSettings = false
    @State private var showIntegrations = false

    var body: some View {
        NavigationStack {
            stateContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .navigationDestination(isPresented: $showSettings) {
                    SettingsView()
                }
                .navigationDestination(isPresented: $showIntegrations) {
                    IntegrationsView()
                }
        }
        .background(Theme.surface.ignoresSafeArea())
        .sheet(isPresented: $showActivitySheet, onDismiss: {
            if let activity = pendingActivity {
                let desc = pendingOtherDescription
                Task { await viewModel.addActivity(activity, description: desc) }
                pendingActivity = nil
                pendingOtherDescription = ""
            }
        }) {
            ActivityToggleView(
                selectedActivity: $pendingActivity,
                otherDescription: $pendingOtherDescription
            )
            .presentationDetents([.medium])
        }
        .task {
            await viewModel.load()
            await viewModel.startRealtimeSubscription()
        }
        .onDisappear {
            viewModel.stopRealtimeSubscription()
        }
    }

    // MARK: - State Router

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.isLoading && viewModel.mealCards.isEmpty {
            loadingContent
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 0) {
                ErrorBanner(message: error) { Task { await viewModel.load() } }
                    .padding(Theme.md)
                Spacer()
            }
        } else {
            switch viewModel.state {
            case .trainingDay: trainingDayContent
            case .postRun:     postRunContent
            case .restDay:     restDayContent
            case .noStrava:    noStravaContent
            case .noMeals:     noMealsContent
            }
        }
    }

    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: Theme.md) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .fill(Theme.card)
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .padding(.horizontal, Theme.md)
                }
            }
            .padding(.top, Theme.md)
        }
    }

    // MARK: - Training Day

    private var trainingDayContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.md) {
                raceCountdownHeader
                    .padding(.horizontal, Theme.md)

                sessionContextCard
                    .padding(.horizontal, Theme.md)

                Text("Your meals today")
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.md)

                ForEach(viewModel.mealCards.indices, id: \.self) { i in
                    MealCardView(data: viewModel.mealCards[i])
                        .padding(.horizontal, Theme.md)
                }

                Text("Want something different?")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.xs)

                activityCard
                    .padding(.horizontal, Theme.md)

                postRunPromptCard
                    .padding(.horizontal, Theme.md)

                Color.clear.frame(height: Theme.sm)
            }
            .padding(.top, Theme.md)
        }
        .contentMargins(.bottom, Theme.xl, for: .scrollContent)
        .refreshable { await viewModel.load() }
    }

    // MARK: - Post-Run State

    private var postRunContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.md) {
                raceCountdownHeader
                    .padding(.horizontal, Theme.md)

                VStack(alignment: .leading, spacing: Theme.xs) {
                    HStack(spacing: Theme.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                        Text(viewModel.completedSessionLabel)
                            .font(Theme.subheading)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("Recovery portions active — protein first, then carbs.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .padding(.horizontal, Theme.md)

                Button {
                    AppRouter.shared.openCoachConversation(nil)
                } label: {
                    Text("Ask your Coach how the run felt →")
                        .font(Theme.body)
                        .foregroundStyle(Theme.brand)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, Theme.md)

                Text("Your recovery meals")
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.md)

                ForEach(viewModel.mealCards.indices, id: \.self) { i in
                    MealCardView(data: viewModel.mealCards[i])
                        .padding(.horizontal, Theme.md)
                }

                Spacer(minLength: Theme.xl)
            }
            .padding(.top, Theme.md)
        }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Rest Day State
    // Shown when todaySession is nil (first-class rest day) or session_type == "rest"

    private var restDayContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.md) {
                raceCountdownHeader
                    .padding(.horizontal, Theme.md)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.neutral)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: Theme.xs) {
                        Text(viewModel.sessionLabel)
                            .font(Theme.subheading)
                            .foregroundStyle(Theme.textPrimary)
                        Text(viewModel.sessionSubtitle)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(Theme.md)
                    Spacer()
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .padding(.horizontal, Theme.md)

                Text("Your meals today")
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.md)

                ForEach(viewModel.mealCards.indices, id: \.self) { i in
                    MealCardView(data: viewModel.mealCards[i])
                        .padding(.horizontal, Theme.md)
                }

                activityCard
                    .padding(.horizontal, Theme.md)

                Spacer(minLength: Theme.xl)
            }
            .padding(.top, Theme.md)
        }
        .refreshable { await viewModel.load() }
    }

    // MARK: - No Strava State

    private var noStravaContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.md) {
                raceCountdownHeader
                    .padding(.horizontal, Theme.md)

                VStack(alignment: .leading, spacing: Theme.sm) {
                    Text("Connect Strava to see your session")
                        .font(Theme.subheading)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Portions adjust automatically based on your runs.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Button {
                        showIntegrations = true
                    } label: {
                        Text("Connect Strava →")
                            .font(Theme.body)
                            .foregroundStyle(Theme.brand)
                    }
                    .frame(minHeight: 44)
                }
                .padding(Theme.md)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .padding(.horizontal, Theme.md)

                Text("Your meals today")
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.md)

                ForEach(viewModel.mealCards.indices, id: \.self) { i in
                    MealCardView(data: viewModel.mealCards[i])
                        .padding(.horizontal, Theme.md)
                }

                Spacer(minLength: Theme.xl)
            }
            .padding(.top, Theme.md)
        }
        .refreshable { await viewModel.load() }
    }

    // MARK: - No Meals State

    private var noMealsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.md) {
                raceCountdownHeader
                    .padding(.horizontal, Theme.md)

                VStack(alignment: .leading, spacing: Theme.sm) {
                    Text("Let's set up your meals")
                        .font(Theme.subheading)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tell Crunch what you usually eat and it'll calculate your exact portions.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Button {
                        // Phase 6: switch to Nutrition tab
                    } label: {
                        Text("Set up meals →")
                            .font(Theme.body)
                            .foregroundStyle(Theme.brand)
                    }
                    .frame(minHeight: 44)
                }
                .padding(Theme.md)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .padding(.horizontal, Theme.md)

                Spacer(minLength: Theme.xl)
            }
            .padding(.top, Theme.md)
        }
    }

    // MARK: - Reusable Sub-Views

    private var raceCountdownHeader: some View {
        VStack(alignment: .leading, spacing: Theme.xs) {
            (Text("\(viewModel.weeksToRace)").foregroundStyle(Theme.brand) +
             Text(" weeks to \(viewModel.raceName)").foregroundStyle(Theme.textPrimary))
                .font(.system(size: 28, weight: .bold))
            Text(viewModel.trainingPhaseName)
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var sessionContextCard: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.brand)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: Theme.xs) {
                Text(viewModel.sessionLabel)
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                Text(viewModel.sessionSubtitle)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.md)
            Spacer()
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            if let activity = viewModel.addedActivity {
                HStack {
                    Image(systemName: activity.symbol)
                        .foregroundStyle(Theme.brand)
                    let displayName = (activity == .other && !viewModel.otherActivityDescription.isEmpty)
                        ? viewModel.otherActivityDescription
                        : activity.label
                    Text("\(displayName) added")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        Task { await viewModel.clearActivity() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            } else {
                Text("Did you do anything else today?")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                Button {
                    showActivitySheet = true
                } label: {
                    Text("+ Add activity")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(Theme.md)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(
                    viewModel.addedActivity != nil ? Theme.brand.opacity(0.4) : Theme.subtle,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var postRunPromptCard: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            HStack(spacing: Theme.sm) {
                Image(systemName: "figure.run")
                    .foregroundStyle(Theme.brand)
                Text("After your long run")
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
            }
            Text("Eat within 30 minutes — protein triggers recovery, carbs refill glycogen.")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
            Button {
                AppRouter.shared.openCoachConversation(nil)
            } label: {
                Text("Ask your Coach →")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.brand)
            }
            .frame(minHeight: 44)
        }
        .padding(Theme.md)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

// MARK: - Preview Init

extension TodayView {
    /// Injects a pre-configured viewmodel for Xcode Previews.
    /// In an extension so the compiler-synthesised TodayView() init is preserved.
    init(viewModel: TodayViewModel) {
        _viewModel = State(initialValue: viewModel)
        _showActivitySheet = State(initialValue: false)
        _pendingActivity = State(initialValue: nil)
        _pendingOtherDescription = State(initialValue: "")
    }
}

// MARK: - Previews

#Preview("Training Day") {
    TodayView(viewModel: .preview(state: .trainingDay))
}

#Preview("Post-Run") {
    TodayView(viewModel: .preview(state: .postRun))
}

#Preview("Rest Day") {
    TodayView(viewModel: .preview(state: .restDay))
}

#Preview("No Strava") {
    TodayView(viewModel: .preview(state: .noStrava))
}

#Preview("No Meals") {
    TodayView(viewModel: .preview(state: .noMeals))
}
