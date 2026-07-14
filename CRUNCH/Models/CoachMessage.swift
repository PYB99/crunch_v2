import Foundation

struct CoachMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let conversationId: UUID
    let userId: String
    let role: MessageRole
    let content: String
    let createdAt: Date

    enum MessageRole: String, Codable, Sendable {
        case user      = "user"
        case assistant = "assistant"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId         = "user_id"
        case role
        case content
        case createdAt      = "created_at"
    }
}
