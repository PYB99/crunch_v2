import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "AnthropicService")

// MARK: - Response type returned by the coach-respond Edge Function

struct CoachRespondResult: Sendable {
    let conversationId: UUID
    let assistantMessage: CoachMessage
}

enum AnthropicService {

    // MARK: - coach-respond Edge Function call

    static func coachRespond(
        conversationId: UUID?,
        userMessage: String,
        clerkToken: String
    ) async throws -> CoachRespondResult {
        let url = URL(string: "\(Constants.supabaseURL)/functions/v1/coach-respond")!
        var request = URLRequest(url: url, timeoutInterval: Constants.apiTimeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json",          forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Constants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(clerkToken,                  forHTTPHeaderField: "x-clerk-token")

        var body: [String: Any] = ["message": userMessage]
        if let cid = conversationId { body["conversation_id"] = cid.uuidString }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(binary)"
            logger.error("coach-respond \(statusCode): \(body)")
            print("[AnthropicService] coach-respond \(statusCode): \(body)")
            throw AppError.invalidResponse
        }

        struct EdgePayload: Decodable {
            let conversationId: String
            let messageId: String
            let content: String
            let userId: String
            let createdAt: String
            enum CodingKeys: String, CodingKey {
                case conversationId = "conversation_id"
                case messageId      = "message_id"
                case content
                case userId         = "user_id"
                case createdAt      = "created_at"
            }
        }

        let payload = try JSONDecoder().decode(EdgePayload.self, from: data)

        guard let convId = UUID(uuidString: payload.conversationId),
              let msgId  = UUID(uuidString: payload.messageId) else {
            throw AppError.invalidResponse
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAt = isoFormatter.date(from: payload.createdAt) ?? Date()

        let message = CoachMessage(
            id: msgId,
            conversationId: convId,
            userId: payload.userId,
            role: .assistant,
            content: payload.content,
            createdAt: createdAt
        )

        return CoachRespondResult(conversationId: convId, assistantMessage: message)
    }

    // MARK: - estimate-meal Edge Function call

    static func estimateMeal(description: String, clerkToken: String) async throws -> EstimatedMacros {
        let url = URL(string: "\(Constants.supabaseURL)/functions/v1/estimate-meal")!
        var request = URLRequest(url: url, timeoutInterval: Constants.apiTimeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json",          forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Constants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(clerkToken,                  forHTTPHeaderField: "x-clerk-token")

        request.httpBody = try JSONSerialization.data(withJSONObject: ["description": description])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(binary)"
            logger.error("estimate-meal \(statusCode): \(body)")
            throw AppError.invalidResponse
        }

        struct MacroPayload: Decodable {
            let carbsG: Double
            let proteinG: Double
            let fatG: Double
            enum CodingKeys: String, CodingKey {
                case carbsG   = "carbs_g"
                case proteinG = "protein_g"
                case fatG     = "fat_g"
            }
        }

        let payload = try JSONDecoder().decode(MacroPayload.self, from: data)
        guard payload.carbsG > 0, payload.proteinG > 0, payload.fatG > 0 else {
            throw AppError.invalidResponse
        }

        return EstimatedMacros(carbsG: payload.carbsG, proteinG: payload.proteinG, fatG: payload.fatG)
    }

    // MARK: - Load latest conversation + messages from Supabase

    static func loadLatestConversationWithMessages() async throws -> (CoachConversation, [CoachMessage])? {
        let client = try await makeAuthenticatedClient()

        let conversations: [CoachConversation] = try await client
            .from("coach_conversations")
            .select()
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let conversation = conversations.first else { return nil }

        let messages: [CoachMessage] = try await client
            .from("coach_messages")
            .select()
            .eq("conversation_id", value: conversation.id.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return (conversation, messages)
    }

    // MARK: - Load a specific conversation (push-notification deep link)

    static func loadConversation(id: UUID) async throws -> (CoachConversation, [CoachMessage])? {
        let client = try await makeAuthenticatedClient()

        let conversations: [CoachConversation] = try await client
            .from("coach_conversations")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let conversation = conversations.first else { return nil }

        let messages: [CoachMessage] = try await client
            .from("coach_messages")
            .select()
            .eq("conversation_id", value: conversation.id.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return (conversation, messages)
    }

    // Builds a Supabase client with the Clerk JWT injected — stays on MainActor,
    // no actor hop, avoids the MainActor.run re-entrancy deadlock in SupabaseService.
    private static func makeAuthenticatedClient() async throws -> SupabaseClient {
        let token = try await ClerkService.currentToken()
        return SupabaseClient(
            supabaseURL: URL(string: Constants.supabaseURL)!,
            supabaseKey: Constants.supabaseAnonKey,
            options: SupabaseClientOptions(
                global: SupabaseClientOptions.GlobalOptions(
                    headers: ["Authorization": "Bearer \(token)"]
                )
            )
        )
    }
}
