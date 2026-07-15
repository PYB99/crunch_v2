import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class RaceEditViewModel {
    var race: Race?
    var raceName: String = ""
    var raceType: String = "marathon"
    var raceDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    var isSaving = false
    var errorMessage: String?
    var validationError: String?

    // Postgres `date` column ⇄ "yyyy-MM-dd". Fixed locale/timezone so the
    // calendar day round-trips regardless of device settings.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func load() async {
        errorMessage = nil
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            let races: [Race] = try await client
                .from("races").select()
                .eq("is_active", value: true)
                .limit(1)
                .execute().value
            if let r = races.first {
                race = r
                raceName = r.raceName ?? ""
                raceType = r.raceType
                if let d = Self.dateFormatter.date(from: r.raceDate) { raceDate = d }
            }
        } catch {
            errorMessage = "Couldn't load your race. Tap to retry."
        }
    }

    @discardableResult
    func validate() -> Bool {
        validationError = nil
        if raceName.count > Constants.maxRaceNameLength {
            validationError = "Race name must be \(Constants.maxRaceNameLength) characters or fewer"
            return false
        }
        let today = Calendar.current.startOfDay(for: Date())
        if Calendar.current.startOfDay(for: raceDate) <= today {
            validationError = "Pick a date in the future"
            return false
        }
        return true
    }

    func save() async -> Bool {
        guard validate() else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let dateStr = Self.dateFormatter.string(from: raceDate)
        // Nullable column; store the trimmed string ("" reads as "no name"
        // everywhere it's consumed) to avoid optional-null encoding pitfalls.
        let name = raceName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            if let existing = race {
                struct Update: Encodable {
                    let race_name: String
                    let race_type: String
                    let race_date: String
                    let is_active: Bool
                }
                try await client
                    .from("races")
                    .update(Update(race_name: name, race_type: raceType, race_date: dateStr, is_active: true))
                    .eq("id", value: existing.id)
                    .execute()
            } else {
                // UUID-keyed table: resolve users.id the same way IntegrationsVM does.
                struct UserRow: Decodable { let id: UUID }
                let users: [UserRow] = try await client
                    .from("users").select("id").execute().value
                guard let userUUID = users.first?.id else {
                    errorMessage = "Couldn't save. Try again."
                    return false
                }
                struct Insert: Encodable {
                    let user_id: UUID
                    let race_name: String
                    let race_type: String
                    let race_date: String
                    let is_active: Bool
                }
                try await client
                    .from("races")
                    .insert(Insert(user_id: userUUID, race_name: name, race_type: raceType, race_date: dateStr, is_active: true))
                    .execute()
            }
            await load()   // re-capture the row (and its id) after create
            return true
        } catch {
            errorMessage = "Couldn't save. Try again."
            return false
        }
    }
}

// MARK: - View

struct RaceEditView: View {
    var onSaved: (() -> Void)? = nil
    @State private var viewModel = RaceEditViewModel()

    private let raceTypes: [(value: String, label: String)] = [
        ("5k", "5K"),
        ("10k", "10K"),
        ("half_marathon", "Half Marathon"),
        ("marathon", "Marathon"),
        ("ultra_marathon", "Ultra Marathon"),
        ("other", "Other"),
    ]

    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) { Task { await viewModel.load() } }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section("Race Name") {
                TextField("Optional", text: $viewModel.raceName)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                    .listRowBackground(Theme.card)
            }

            Section("Race Type") {
                Picker("Race Type", selection: $viewModel.raceType) {
                    ForEach(raceTypes, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.menu)
                .tint(Theme.textSecondary)
                .listRowBackground(Theme.card)
            }

            Section("Race Date") {
                DatePicker(
                    "Race Date",
                    selection: $viewModel.raceDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Theme.brand)
                .listRowBackground(Theme.card)
                .onChange(of: viewModel.raceDate) { _, _ in viewModel.validate() }

                if let validationError = viewModel.validationError {
                    Text(validationError)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.error)
                        .listRowBackground(Theme.card)
                }
            }

            Section {
                PrimaryButton(title: "Save", isLoading: viewModel.isSaving, isDisabled: viewModel.isSaving) {
                    Task {
                        if await viewModel.save() { onSaved?() }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("My Race")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

#Preview {
    NavigationStack {
        RaceEditView()
    }
}
