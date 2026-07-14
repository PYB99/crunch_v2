import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class WeekViewModel {

    var sessions: [TrainingSession] = []
    var meals: [Meal] = []
    var userProfile: UserProfile = .fallback
    var race: Race?
    var weekOffset: Int = 0
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed Header

    var weekHeaderTitle: String {
        guard let race else { return "Training Week" }
        let total = Self.planWeeks(raceType: race.raceType)
        let weeksLeft = MacroEngine.weeksUntil(dateString: race.raceDate)
        let currentWeek = max(1, total - weeksLeft + 1)
        let displayed = max(1, min(total + 1, currentWeek + weekOffset))
        return "Week \(displayed) of \(total)"
    }

    var phaseLabel: String {
        guard let race else { return "" }
        let weeksLeft = MacroEngine.weeksUntil(dateString: race.raceDate)
        let adjusted = max(0, weeksLeft - weekOffset)
        return MacroEngine.trainingPhase(weeksToRace: adjusted).rawValue
    }

    var weekDateRangeStr: String {
        let (start, end) = Self.weekBounds(offset: weekOffset)
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    // sessions includes one extra leading day (for recovery-day detection);
    // summary/empty-state must only count the displayed Mon–Sun window.
    private var displayWeekSessions: [TrainingSession] {
        let (start, end) = Self.weekBounds(offset: weekOffset)
        let startStr = Self.ymd(start)
        let endStr = Self.ymd(end)
        return sessions.filter { $0.sessionDate >= startStr && $0.sessionDate <= endStr }
    }

    var weekSummaryStr: String {
        let display = displayWeekSessions
        let runSessions = display.filter { MacroEngine.isRunSession($0.sessionType) }
        let totalKm = display.compactMap { $0.distanceKm }.reduce(0, +)

        var parts: [String] = []
        if totalKm > 0 { parts.append("Total: \(Int(totalKm.rounded())) km") }
        if !runSessions.isEmpty {
            parts.append("\(runSessions.count) session\(runSessions.count == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "Rest week" : parts.joined(separator: " · ")
    }

    // 7 (date, session?, previousSessionType?) tuples for the displayed week.
    // previousSessionType is the prior day's run type (loadSessions fetches one
    // extra leading day), which drives recovery-day detection in the engine.
    var weekDays: [(date: Date, session: TrainingSession?, previousSessionType: String?)] {
        let (start, _) = Self.weekBounds(offset: weekOffset)
        let cal = Calendar(identifier: .gregorian)
        return (0..<7).map { i in
            let date = cal.date(byAdding: .day, value: i, to: start)!
            let dateStr = Self.ymd(date)
            let session = sessions.first { $0.sessionDate == dateStr }
            let prevDate = cal.date(byAdding: .day, value: -1, to: date)!
            let prevStr = Self.ymd(prevDate)
            let previousType = sessions.first {
                $0.sessionDate == prevStr && MacroEngine.isRunSession($0.sessionType)
            }?.sessionType
            return (date, session, previousType)
        }
    }

    var showNoRunnaPrompt: Bool {
        displayWeekSessions.isEmpty && weekOffset >= 0 && !isLoading
    }

    // MARK: - Data Loading

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try await SupabaseService.shared.authenticatedClient()

            // User profile
            struct UserRow: Codable {
                let weightKg: Double?
                let heightCm: Double?
                let age: Int?
                let gender: String?
                let trainingLevel: String?
                enum CodingKeys: String, CodingKey {
                    case weightKg = "weight_kg"
                    case heightCm = "height_cm"
                    case age, gender
                    case trainingLevel = "training_level"
                }
            }
            let userRows: [UserRow] = try await client.from("users").select().execute().value
            if let u = userRows.first {
                userProfile = UserProfile(
                    weightKg:      u.weightKg      ?? UserProfile.fallback.weightKg,
                    heightCm:      u.heightCm      ?? UserProfile.fallback.heightCm,
                    age:           u.age           ?? UserProfile.fallback.age,
                    gender:        u.gender        ?? UserProfile.fallback.gender,
                    trainingLevel: u.trainingLevel ?? UserProfile.fallback.trainingLevel
                )
            }

            // Active race
            let races: [Race] = try await client.from("races")
                .select()
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value
            race = races.first

            // Meals for expanded portion display
            meals = try await client.from("meals")
                .select()
                .eq("is_active", value: true)
                .order("sort_order")
                .execute()
                .value

            // Sessions for displayed week
            await loadSessions(client: client)
        } catch {
            errorMessage = "Something went wrong. Tap to retry."
        }
    }

    func navigateWeek(by delta: Int) async {
        weekOffset += delta
        errorMessage = nil
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            await loadSessions(client: client)
        } catch {
            errorMessage = "Something went wrong. Tap to retry."
        }
    }

    // MARK: - Private

    private func loadSessions(client: SupabaseClient) async {
        let (start, end) = Self.weekBounds(offset: weekOffset)
        // Fetch one extra leading day so the Monday row can see the prior
        // Sunday's session for recovery-day detection.
        let cal = Calendar(identifier: .gregorian)
        let queryStart = cal.date(byAdding: .day, value: -1, to: start) ?? start
        do {
            sessions = try await client.from("training_sessions")
                .select()
                .gte("session_date", value: Self.ymd(queryStart))
                .lte("session_date", value: Self.ymd(end))
                .order("session_date")
                .execute()
                .value
        } catch {
            // Sessions not critical — keep existing list, log silently
        }
    }

    private static func planWeeks(raceType: String) -> Int {
        switch raceType {
        case "marathon":       return 16
        case "half_marathon":  return 12
        case "10k":            return 10
        case "5k":             return 8
        case "ultra_marathon": return 20
        default:               return 12
        }
    }

    static func weekBounds(offset: Int) -> (start: Date, end: Date) {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        let monday = cal.date(byAdding: .day, value: -daysFromMonday + offset * 7, to: today)!
        let sunday = cal.date(byAdding: .day, value: 6, to: monday)!
        return (monday, sunday)
    }

    static func ymd(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

// MARK: - View

struct WeekView: View {
    @State private var viewModel = WeekViewModel()
    @State private var showSettings = false

    var body: some View {
        let _ = print("DEBUG: WeekView.body entered")
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.weekDays.isEmpty {
                    loadingContent
                } else {
                    mainContent
                }
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Week")
                        .font(Theme.subheading)
                        .foregroundStyle(Theme.textPrimary)
                }
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
        }
        .task { await viewModel.load() }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: Theme.sm) {
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonView(height: 56).padding(.horizontal, Theme.md)
                }
            }
            .padding(.top, Theme.md)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) { Task { await viewModel.load() } }
                        .padding(.horizontal, Theme.md)
                }

                weekNavigationHeader
                weekSummaryCard
                dayRows

                if viewModel.showNoRunnaPrompt {
                    noRunnaCard
                }

                Color.clear.frame(height: Theme.sm)
            }
            .padding(.top, Theme.md)
        }
        .contentMargins(.bottom, Theme.xl, for: .scrollContent)
        .refreshable { await viewModel.load() }
    }

    // MARK: - Week Header

    private var weekNavigationHeader: some View {
        VStack(spacing: Theme.xs) {
            HStack {
                Button {
                    Task { await viewModel.navigateWeek(by: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .frame(minWidth: 44, minHeight: 44)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(viewModel.weekHeaderTitle)
                        .font(Theme.heading)
                        .foregroundStyle(Theme.textPrimary)
                    if !viewModel.phaseLabel.isEmpty {
                        Text(viewModel.phaseLabel)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.brand)
                    }
                }

                Spacer()

                Button {
                    Task { await viewModel.navigateWeek(by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, Theme.md)

            Text(viewModel.weekDateRangeStr)
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Summary Card

    private var weekSummaryCard: some View {
        HStack {
            Text(viewModel.weekSummaryStr)
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Theme.md)
        .padding(.vertical, Theme.sm)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .padding(.horizontal, Theme.md)
    }

    // MARK: - Day Rows

    private var dayRows: some View {
        LazyVStack(spacing: Theme.sm) {
            ForEach(Array(viewModel.weekDays.enumerated()), id: \.offset) { _, day in
                DayRowView(
                    date: day.date,
                    session: day.session,
                    previousSessionType: day.previousSessionType,
                    userProfile: viewModel.userProfile,
                    raceDate: viewModel.race?.raceDate,
                    meals: viewModel.meals
                )
            }
        }
    }

    // MARK: - No Runna Prompt

    private var noRunnaCard: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            Text("No sessions this week")
                .font(Theme.subheading)
                .foregroundStyle(Theme.textPrimary)
            Text("Connect Runna to see your training plan, or sessions will appear here after your runs sync from Strava.")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
            Button {
                // Phase 7: Runna iCal + Strava OAuth
            } label: {
                Text("Connect Runna →")
                    .font(Theme.body)
                    .foregroundStyle(Theme.brand)
            }
            .frame(minHeight: 44)
        }
        .padding(Theme.md)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .padding(.horizontal, Theme.md)
    }
}

// MARK: - Preview

#Preview {
    WeekView()
}
