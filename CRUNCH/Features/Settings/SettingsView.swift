import SwiftUI

// Minimal shell — full Settings spec (Personal Info, Notifications, Units,
// Subscription, Account) is Phase 8. Phase 7 only needs the Integrations
// entry point this exists to provide.
struct SettingsView: View {
    var body: some View {
        List {
            NavigationLink {
                IntegrationsView()
            } label: {
                Text("Integrations")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
