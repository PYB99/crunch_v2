import Foundation

struct CoachConversation: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: String
    let sessionId: UUID?
    let startedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case sessionId   = "session_id"
        case startedAt   = "started_at"
        case updatedAt   = "updated_at"
    }
}
