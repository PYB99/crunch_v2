import Foundation
import AuthenticationServices
import UIKit
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "StravaOAuthService")

// The one Strava connection path in the app. Screen15ConnectAppsView (Phase 5)
// will call connect() exactly as Settings → Integrations does today — no
// rework needed once onboarding exists.
@MainActor
final class StravaOAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = StravaOAuthService()

    private override init() {}

    // MARK: - Connect (authorize + exchange in one call)

    func connect() async throws {
        let code = try await authorize()
        try await exchange(code: code)
        MixpanelService.track(.stravaConnected)
    }

    // MARK: - Step 1: Strava consent → auth code

    func authorize() async throws -> String {
        var components = URLComponents(string: Constants.stravaAuthorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.stravaClientID),
            URLQueryItem(name: "redirect_uri", value: Constants.stravaRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "activity:read_all"),
        ]
        guard let authorizeURL = components.url else {
            throw AppError.invalidResponse
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: "crunch"
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? AppError.invalidResponse)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw AppError.invalidResponse
        }

        return code
    }

    // MARK: - Step 2: auth code → tokens (via strava-oauth Edge Function)

    func exchange(code: String) async throws {
        let url = URL(string: "\(Constants.supabaseURL)/functions/v1/strava-oauth?action=exchange")!
        var request = URLRequest(url: url, timeoutInterval: Constants.apiTimeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Constants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(try await ClerkService.currentToken(), forHTTPHeaderField: "x-clerk-token")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            logger.error("strava-oauth exchange \(statusCode)")
            throw AppError.invalidResponse
        }
        _ = data
    }

    // MARK: - Status / disconnect

    static func fetchStatus() async throws -> Integration? {
        let client = try await SupabaseService.shared.authenticatedClient()
        let integrations: [Integration] = try await client
            .from("integrations")
            .select()
            .eq("provider", value: "strava")
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        return integrations.first
    }

    func disconnect() async throws {
        struct IsActiveUpdate: Encodable { let is_active: Bool }
        let client = try await SupabaseService.shared.authenticatedClient()
        try await client
            .from("integrations")
            .update(IsActiveUpdate(is_active: false))
            .eq("provider", value: "strava")
            .execute()
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first else {
            // Only called from a user-triggered, foregrounded OAuth flow — a
            // connected scene is a guaranteed invariant at that point.
            preconditionFailure("No connected UIWindowScene — cannot present ASWebAuthenticationSession")
        }
        return windowScene.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor(windowScene: windowScene)
    }
}
