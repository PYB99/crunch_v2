import Foundation

struct Race: Codable {
    let id: UUID
    let userId: UUID
    let raceName: String?
    let raceType: String
    let raceDate: String    // "YYYY-MM-DD" — Postgres date decoded as String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case raceName = "race_name"
        case raceType = "race_type"
        case raceDate = "race_date"
        case isActive = "is_active"
    }
}
