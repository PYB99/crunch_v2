import UIKit
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "AppDelegate")

// STUB STATUS: didRegisterForRemoteNotificationsWithDeviceToken only fires
// once the Push Notifications capability + aps-environment entitlement are
// enabled in Xcode — not yet done (see PushNotificationService.swift). Until
// then, didFailToRegisterForRemoteNotificationsWithError is the expected path
// and is logged, not treated as an error state.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PushNotificationService.shared.storeDeviceToken(tokenHex) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }
}
