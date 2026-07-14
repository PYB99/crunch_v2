import Foundation
import Supabase
import ClerkKit
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "SupabaseService")

actor SupabaseService {
    static let shared = SupabaseService()

    // Unauthenticated client — for Edge Functions called before sign-in
    let anonClient: SupabaseClient

    private init() {
        anonClient = SupabaseClient(
            supabaseURL: URL(string: Constants.supabaseURL)!,
            supabaseKey: Constants.supabaseAnonKey
        )
    }

    // Authenticated client — injects Clerk JWT so RLS policies resolve correctly.
    // Creates a new client per call; lightweight for the request cadence of this app.
    func authenticatedClient() async throws -> SupabaseClient {
        let session = await MainActor.run { Clerk.shared.session }
        guard let session else {
            throw AppError.notAuthenticated
        }
        guard let jwt = try await session.getToken() else {
            throw AppError.notAuthenticated
        }

        return SupabaseClient(
            supabaseURL: URL(string: Constants.supabaseURL)!,
            supabaseKey: Constants.supabaseAnonKey,
            options: SupabaseClientOptions(
                global: SupabaseClientOptions.GlobalOptions(
                    headers: ["Authorization": "Bearer \(jwt)"]
                )
            )
        )
    }
}

// MARK: - App Errors
enum AppError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return "You are not signed in."
        case .invalidResponse:    return "Something went wrong. Please try again."
        case .serverError(let m): return m
        }
    }
}
