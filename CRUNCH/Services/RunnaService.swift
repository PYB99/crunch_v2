import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "RunnaService")

// Runna connection via capability URL — no OAuth exchange, so this is a
// thinner counterpart to StravaOAuthService. Screen15ConnectAppsView (Phase 5)
// will call saveICalURL(_:userUUID:) exactly as Settings → Integrations does.
enum RunnaService {

    private struct RunnaUpsert: Encodable {
        let user_id: UUID
        let provider: String
        let access_token: String
        let is_active: Bool
    }

    static func saveICalURL(_ url: URL, userUUID: UUID) async throws {
        guard
            let scheme = url.scheme?.lowercased(),
            ["https", "webcal"].contains(scheme),
            let host = url.host, !host.isEmpty
        else {
            throw AppError.serverError("Enter a valid iCal URL")
        }

        let client = try await SupabaseService.shared.authenticatedClient()
        try await client
            .from("integrations")
            .upsert(
                RunnaUpsert(user_id: userUUID, provider: "runna", access_token: url.absoluteString, is_active: true),
                onConflict: "user_id,provider"
            )
            .execute()

        MixpanelService.track(.runnaConnected)
        await triggerSyncNow()
    }

    static func fetchStatus() async throws -> Integration? {
        let client = try await SupabaseService.shared.authenticatedClient()
        let integrations: [Integration] = try await client
            .from("integrations")
            .select()
            .eq("provider", value: "runna")
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        return integrations.first
    }

    static func disconnect() async throws {
        struct IsActiveUpdate: Encodable { let is_active: Bool }
        let client = try await SupabaseService.shared.authenticatedClient()
        try await client
            .from("integrations")
            .update(IsActiveUpdate(is_active: false))
            .eq("provider", value: "runna")
            .execute()
    }

    // Fire-and-forget — lets Week populate immediately instead of waiting
    // for the 04:00 UTC cron. Failure is non-fatal; the cron will catch up.
    static func triggerSyncNow() async {
        guard let url = URL(string: "\(Constants.supabaseURL)/functions/v1/runna-sync") else { return }
        var request = URLRequest(url: url, timeoutInterval: Constants.apiTimeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("triggerSyncNow failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
