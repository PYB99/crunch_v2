import SwiftUI
import UIKit
import UserNotifications
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class NotificationsViewModel {
    var systemStatus: UNAuthorizationStatus = .notDetermined
    // Derived: OS permission authorized AND a device token is stored. This is
    // deliberately "permission + registration", NOT "delivery works" — APNs
    // secrets/entitlement are still outstanding, so a stored token does not
    // prove a push can be delivered (see plan failure mode 3).
    var pushEnabled = false
    var isWorking = false

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemStatus = settings.authorizationStatus
        let authorized = settings.authorizationStatus == .authorized
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            struct Row: Decodable { let apns_device_token: String? }
            let rows: [Row] = try await client
                .from("users").select("apns_device_token").execute().value
            let hasToken = (rows.first?.apns_device_token) != nil
            pushEnabled = authorized && hasToken
        } catch {
            pushEnabled = authorized
        }
    }

    func enable() async {
        isWorking = true
        defer { isWorking = false }
        switch systemStatus {
        case .notDetermined:
            _ = await PushNotificationService.shared.requestAuthorizationAndRegister()
        case .denied:
            openSystemSettings()
        default:
            // Authorized but token missing — re-register to repopulate it.
            UIApplication.shared.registerForRemoteNotifications()
        }
        await refresh()
    }

    func disable() async {
        isWorking = true
        defer { isWorking = false }
        await PushNotificationService.shared.clearDeviceToken()
        await refresh()
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - View

struct NotificationsView: View {
    var onChanged: (() -> Void)? = nil
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        List {
            Section {
                Toggle(isOn: toggleBinding) {
                    Text("Push Notifications")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.brand)
                .disabled(viewModel.isWorking)
                .frame(minHeight: 44)
                .listRowBackground(Theme.card)
            } footer: {
                Text(footerText)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pushEnabled },
            set: { newValue in
                Task {
                    if newValue { await viewModel.enable() } else { await viewModel.disable() }
                    onChanged?()
                }
            }
        )
    }

    private var footerText: String {
        switch viewModel.systemStatus {
        case .denied:
            return "Notifications are turned off in iOS Settings. Tap the toggle to open Settings and allow them."
        default:
            return "Get a heads-up after a run with fueling guidance from your coach."
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
