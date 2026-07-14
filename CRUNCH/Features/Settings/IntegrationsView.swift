import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class IntegrationsViewModel {
    var strava: Integration?
    var runna: Integration?
    var isLoading = false
    var isConnectingStrava = false
    var isSavingRunna = false
    var errorMessage: String?

    private var userUUID: UUID?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            struct UserRow: Codable { let id: UUID }
            let userRows: [UserRow] = try await client.from("users").select("id").execute().value
            userUUID = userRows.first?.id

            async let stravaStatus = StravaOAuthService.fetchStatus()
            async let runnaStatus = RunnaService.fetchStatus()
            strava = try await stravaStatus
            runna = try await runnaStatus
        } catch {
            errorMessage = "Something went wrong. Tap to retry."
        }
    }

    func connectStrava() async {
        isConnectingStrava = true
        errorMessage = nil
        do {
            try await StravaOAuthService.shared.connect()
            strava = try await StravaOAuthService.fetchStatus()
            await PushNotificationService.shared.requestAuthorizationAndRegister()
        } catch {
            errorMessage = "Couldn't connect Strava. Try again."
        }
        isConnectingStrava = false
    }

    func disconnectStrava() async {
        do {
            try await StravaOAuthService.shared.disconnect()
            strava = nil
        } catch {
            errorMessage = "Couldn't disconnect. Try again."
        }
    }

    func saveRunnaURL(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let userUUID else {
            errorMessage = "Enter a valid iCal URL"
            return
        }
        isSavingRunna = true
        errorMessage = nil
        do {
            try await RunnaService.saveICalURL(url, userUUID: userUUID)
            runna = try await RunnaService.fetchStatus()
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Couldn't save. Try again."
        }
        isSavingRunna = false
    }

    func disconnectRunna() async {
        do {
            try await RunnaService.disconnect()
            runna = nil
        } catch {
            errorMessage = "Couldn't disconnect. Try again."
        }
    }
}

// MARK: - View

struct IntegrationsView: View {
    @State private var viewModel = IntegrationsViewModel()
    @State private var runnaURLText = ""
    @State private var confirmDisconnect: Provider?

    private enum Provider { case strava, runna }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) { Task { await viewModel.load() } }
                }

                if viewModel.isLoading {
                    skeleton
                } else {
                    stravaCard
                    runnaCard
                }
            }
            .padding(Theme.md)
        }
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .alert(
            "Disconnect this integration?",
            isPresented: Binding(
                get: { confirmDisconnect != nil },
                set: { if !$0 { confirmDisconnect = nil } }
            )
        ) {
            Button("Disconnect", role: .destructive) {
                Task {
                    switch confirmDisconnect {
                    case .strava: await viewModel.disconnectStrava()
                    case .runna:  await viewModel.disconnectRunna()
                    case nil:     break
                    }
                    confirmDisconnect = nil
                }
            }
            Button("Cancel", role: .cancel) { confirmDisconnect = nil }
        }
    }

    private var skeleton: some View {
        VStack(spacing: Theme.md) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Theme.card)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
            }
        }
    }

    private var stravaCard: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            HStack {
                Text("Strava")
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(viewModel.strava != nil ? "Connected" : "Not connected")
                    .font(Theme.caption)
                    .foregroundStyle(viewModel.strava != nil ? Theme.success : Theme.textSecondary)
            }

            if viewModel.strava != nil {
                Button("Disconnect") { confirmDisconnect = .strava }
                    .font(Theme.body)
                    .foregroundStyle(Theme.error)
                    .frame(minHeight: 44)
            } else {
                PrimaryButton(
                    title: "Connect Strava",
                    isLoading: viewModel.isConnectingStrava,
                    isDisabled: viewModel.isConnectingStrava
                ) {
                    Task { await viewModel.connectStrava() }
                }
            }
        }
        .padding(Theme.md)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var runnaCard: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            HStack {
                Text("Runna")
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(viewModel.runna != nil ? "Connected" : "Not connected")
                    .font(Theme.caption)
                    .foregroundStyle(viewModel.runna != nil ? Theme.success : Theme.textSecondary)
            }

            if viewModel.runna != nil {
                Button("Disconnect") { confirmDisconnect = .runna }
                    .font(Theme.body)
                    .foregroundStyle(Theme.error)
                    .frame(minHeight: 44)
            } else {
                TextField("Paste your Runna iCal URL", text: $runnaURLText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(Theme.md)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                    .foregroundStyle(Theme.textPrimary)

                PrimaryButton(
                    title: "Save",
                    isLoading: viewModel.isSavingRunna,
                    isDisabled: viewModel.isSavingRunna || runnaURLText.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    Task { await viewModel.saveRunnaURL(runnaURLText) }
                }
            }
        }
        .padding(Theme.md)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

#Preview {
    NavigationStack {
        IntegrationsView()
    }
}
