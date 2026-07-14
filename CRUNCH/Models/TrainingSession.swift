import Foundation

struct TrainingSession: Codable {
    let id: UUID
    let userId: UUID
    let source: String
    let sessionDate: String    // "YYYY-MM-DD"
    let sessionType: String
    let distanceKm: Double?
    let durationMins: Int?
    let status: String         // "planned" | "completed" | "skipped"

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case source
        case sessionDate = "session_date"
        case sessionType = "session_type"
        case distanceKm  = "distance_km"
        case durationMins = "duration_mins"
        case status
    }
}
