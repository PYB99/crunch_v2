import Foundation
import UserNotifications
import UIKit
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "PushNotificationService")

// STUB STATUS: registerForRemoteNotifications() and the resulting device
// token are inert until the Push Notifications capability + aps-environment
// entitlement are enabled in Xcode (Signing & Capabilities) and a real APNs
// key is configured server-side (see supabase/functions/_shared/apns.ts).
// Everything else here — permission prompt, delegate wiring, deep-link
// routing on notification tap — works today independent of that, including
// via a locally-scheduled test notification.
@MainActor
final class PushNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    private override init() {}

    // Called from Settings → Integrations after a successful Strava connect,
    // and (once Phase 5 lands) after onboarding screen 17 — identical call site.
    @discardableResult
    func requestAuthorizationAndRegister() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            logger.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func storeDeviceToken(_ tokenHex: String) async {
        struct TokenUpdate: Encodable { let apns_device_token: String }
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            try await client
                .from("users")
                .update(TokenUpdate(apns_device_token: tokenHex))
                .execute()
        } catch {
            logger.error("storeDeviceToken failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let conversationId = (userInfo["conversation_id"] as? String).flatMap(UUID.init)
        AppRouter.shared.openCoachConversation(conversationId)
    }
}
