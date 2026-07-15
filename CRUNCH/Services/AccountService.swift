import Foundation
import ClerkKit
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "AccountService")

// Centralises sign-out and account-deletion ordering so the security-sensitive
// sequence lives in exactly one place (Phase 8 plan §2 + §5). Nothing here logs
// email, tokens, or other PII.
enum AccountService {

    // Sign out. Order matters: clear the APNs token while the Clerk session is
    // still valid (otherwise pushes queued for user A can reach user B after
    // they sign in on the same device), then reset analytics/subscription
    // identity, then end the Clerk session — which flips ContentView to Splash.
    static func signOut() async {
        await PushNotificationService.shared.clearDeviceToken()
        MixpanelService.reset()
        RevenueCatService.shared.resetUser()
        do {
            try await ClerkService.signOut()
        } catch {
            logger.error("signOut failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Irreversible. Deletes all Supabase data server-side first (while the Clerk
    // token is still valid), then the Clerk user, then resets local identity.
    // Throws only if the server-side data deletion fails — that's the step the
    // UI must surface, because leaving PII behind is the real hazard.
    static func deleteAccount() async throws {
        // 1. Server-side data deletion via the signature-verified Edge Function.
        let clerkToken = try await ClerkService.currentToken()
        let url = URL(string: Constants.deleteAccountFunctionURL)!
        var request = URLRequest(url: url, timeoutInterval: Constants.apiTimeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Constants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(clerkToken, forHTTPHeaderField: "x-clerk-token")
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(binary)"
            logger.error("delete-account \(statusCode, privacy: .public): \(body, privacy: .public)")
            throw AppError.invalidResponse
        }

        // 2. Delete the Clerk user (self-service deletion — requires the "Allow
        //    users to delete their accounts" toggle in the Clerk dashboard). If
        //    this fails, the Supabase data is already gone; we do NOT rethrow —
        //    instead we fall through to sign out so the app can't sit in a
        //    half-deleted state showing a phantom logged-in user.
        do {
            let user = await MainActor.run { Clerk.shared.user }
            _ = try await user?.delete()
        } catch {
            logger.error("Clerk user delete failed: \(error.localizedDescription, privacy: .public)")
        }

        // 3. Reset local identity. The users row (and its apns_device_token) is
        //    already deleted server-side, so there's no token left to clear.
        //    Ensure the session is ended (Clerk delete usually ends it).
        MixpanelService.reset()
        RevenueCatService.shared.resetUser()
        let hasSession = await MainActor.run { Clerk.shared.session != nil }
        if hasSession {
            try? await ClerkService.signOut()
        }
    }
}
