import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class UnitsViewModel {
    var units: String = "metric"
    var isSaving = false
    var errorMessage: String?

    func load() async {
        errorMessage = nil
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            struct Row: Decodable { let units: String? }
            let rows: [Row] = try await client
                .from("users").select("units").execute().value
            units = rows.first?.units ?? "metric"
        } catch {
            errorMessage = "Couldn't load. Tap to retry."
        }
    }

    func save(_ newUnits: String) async -> Bool {
        guard newUnits != units else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        struct Update: Encodable { let units: String; let updated_at: String }
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            try await client
                .from("users")
                .update(Update(units: newUnits, updated_at: isoNow()))
                .execute()
            units = newUnits
            return true
        } catch {
            errorMessage = "Couldn't save. Try again."
            return false
        }
    }
}

// MARK: - View

struct UnitsView: View {
    var onSaved: (() -> Void)? = nil
    @State private var viewModel = UnitsViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) { Task { await viewModel.load() } }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                row("Metric", value: "metric")
                row("Imperial", value: "imperial")
            } footer: {
                Text("Changes how weight and height are shown across the app.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // Immediate save on tap — no confirmation (spec).
    @ViewBuilder
    private func row(_ title: String, value: String) -> some View {
        Button {
            Task {
                if await viewModel.save(value) { onSaved?() }
            }
        } label: {
            HStack {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if viewModel.units == value {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.brand)
                }
            }
            .frame(minHeight: 44)
        }
        .disabled(viewModel.isSaving)
        .listRowBackground(Theme.card)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(viewModel.units == value ? [.isSelected] : [])
    }
}

#Preview {
    NavigationStack {
        UnitsView()
    }
}
