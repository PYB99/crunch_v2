import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class AccountViewModel {
    var email: String?
    var isDeleting = false
    var errorMessage: String?

    func load() async {
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            struct EmailRow: Decodable { let email: String? }
            let rows: [EmailRow] = try await client
                .from("users")
                .select("email")
                .execute()
                .value
            email = rows.first?.email
        } catch {
            // Non-fatal: the row falls back to a placeholder. Deliberately no
            // logging of the email here (rule 8).
            email = nil
        }
    }

    // Immediate, no confirmation (per spec). ContentView routes to Splash once
    // the Clerk session clears — no manual navigation needed here.
    func signOut() async {
        await AccountService.signOut()
    }

    func deleteAccount() async -> Bool {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await AccountService.deleteAccount()
            return true
        } catch {
            errorMessage = "Couldn't delete your account. Try again."
            return false
        }
    }
}

// MARK: - View

struct AccountView: View {
    @State private var viewModel = AccountViewModel()
    @State private var confirmDelete = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                HStack {
                    Text("Email")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(viewModel.email ?? "—")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .listRowBackground(Theme.card)
            }

            Section {
                Button {
                    Task { await viewModel.signOut() }
                } label: {
                    Text("Sign Out")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                }
                .listRowBackground(Theme.card)
            }

            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    HStack {
                        Text("Delete Account")
                            .font(Theme.body)
                            .foregroundStyle(Theme.error)
                        Spacer()
                        if viewModel.isDeleting {
                            ProgressView().tint(Theme.error)
                        }
                    }
                    .frame(minHeight: 44)
                }
                .disabled(viewModel.isDeleting)
                .listRowBackground(Theme.card)
            } footer: {
                Text("Permanently deletes your account and all your data. This can't be undone.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { _ = await viewModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all your data. This can't be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
}
