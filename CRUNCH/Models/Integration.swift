import Foundation

// Token columns (access_token/refresh_token) are deliberately NOT decoded
// here — the client never reads Strava/Runna tokens, only connection status.
struct Integration: Codable {
    let id: UUID
    let userId: UUID
    let provider: String
    let tokenExpiresAt: Date?
    let connectedAt: Date?
    let isActive: Bool
    let providerUserId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId         = "user_id"
        case provider
        case tokenExpiresAt = "token_expires_at"
        case connectedAt    = "connected_at"
        case isActive       = "is_active"
        case providerUserId = "provider_user_id"
    }
}
