import SwiftUI
import Supabase
import UserNotifications

// MARK: - ViewModel

@Observable
@MainActor
final class SettingsViewModel {
    var user: User?
    var activeRace: Race?
    var stravaConnected = false
    var runnaConnected = false
    var notificationsAuthorized = false
    var isPro = false
    var isLoading = false
    var errorMessage: String?

    // One authenticated client, a few small reads. Critical reads (user, race)
    // gate the error banner; status reads are best-effort and never block the
    // screen. Cheap enough to re-run whenever a child screen reports a save.
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            let users: [User] = try await client
                .from("users").select().execute().value
            user = users.first

            let races: [Race] = try await client
                .from("races").select()
                .eq("is_active", value: true)
                .limit(1)
                .execute().value
            activeRace = races.first
        } catch {
            errorMessage = "Couldn't load your settings. Tap to retry."
        }

        // Best-effort — a failure here leaves the status as its last value.
        stravaConnected = ((try? await StravaOAuthService.fetchStatus()) ?? nil) != nil
        runnaConnected = ((try? await RunnaService.fetchStatus()) ?? nil) != nil
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
        isPro = RevenueCatService.shared.isPro

        isLoading = false
    }

    // MARK: Detail strings (trailing text on each row)

    var raceDetail: String {
        guard let race = activeRace else { return "Not set" }
        if let name = race.raceName, !name.isEmpty { return name }
        return race.raceType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var personalInfoDetail: String {
        guard let user, let w = user.weightKg, let h = user.heightCm else { return "Not set" }
        if user.units == "imperial" {
            let lb = Int((w * 2.20462).rounded())
            let totalInches = h / 2.54
            let ft = Int(totalInches / 12)
            let inch = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            return "\(lb) lb · \(ft)'\(inch)\""
        }
        return "\(Int(w.rounded())) kg · \(Int(h.rounded())) cm"
    }

    var integrationsDetail: String {
        switch (stravaConnected, runnaConnected) {
        case (true, true):   return "Strava · Runna"
        case (true, false):  return "Strava"
        case (false, true):  return "Runna"
        case (false, false): return "Not connected"
        }
    }

    var notificationsDetail: String { notificationsAuthorized ? "On" : "Off" }

    var unitsDetail: String { user?.units == "imperial" ? "Imperial" : "Metric" }

    // Phase 9 replaces this with Active / Trial / Upgrade wired to RevenueCat.
    var subscriptionDetail: String { isPro ? "Active" : "Free" }

    var accountDetail: String { user?.email ?? "" }
}

// MARK: - View

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) { Task { await viewModel.load() } }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                navRow("My Race", detail: viewModel.raceDetail) {
                    RaceEditView(onSaved: reload)
                }
                navRow("Personal Info", detail: viewModel.personalInfoDetail) {
                    PersonalInfoView(onSaved: reload)
                }
                navRow("Integrations", detail: viewModel.integrationsDetail) {
                    IntegrationsView()
                }
                navRow("Notifications", detail: viewModel.notificationsDetail) {
                    NotificationsView(onChanged: reload)
                }
                navRow("Units", detail: viewModel.unitsDetail) {
                    UnitsView(onSaved: reload)
                }
                navRow("Feedback", detail: nil) {
                    FeedbackView()
                }
            }

            Section {
                // Subscription — status-only stub. Phase 9 wires the paywall.
                HStack {
                    Text("Subscription")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(viewModel.subscriptionDetail)
                        .font(Theme.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
                .listRowBackground(Theme.card)

                navRow("Account", detail: viewModel.accountDetail) {
                    AccountView()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func reload() { Task { await viewModel.load() } }

    // A List row that pushes `destination` and shows an optional trailing detail.
    @ViewBuilder
    private func navRow<Destination: View>(
        _ title: String,
        detail: String?,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(Theme.body)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
        }
        .listRowBackground(Theme.card)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
