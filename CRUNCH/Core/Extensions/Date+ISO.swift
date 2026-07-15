import Foundation

// Shared ISO-8601 timestamp for `updated_at` writes to Postgres timestamptz
// columns. Used by the Settings edit screens (Units, Personal Info, Race).
func isoNow() -> String {
    ISO8601DateFormatter().string(from: Date())
}
