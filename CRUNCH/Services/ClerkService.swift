import Foundation
import ClerkKit

// Thin wrapper around Clerk.shared.auth. Auth screens call these methods;
// ContentView observes Clerk.shared directly (it is @Observable) for session state.
enum ClerkService {

    // MARK: - Sign In

    static func signIn(email: String, password: String) async throws {
        _ = try await Clerk.shared.auth.signInWithPassword(
            identifier: email,
            password: password
        )
    }

    static func signInWithApple() async throws {
        // Clerk presents the native Apple Sign In dialog internally.
        _ = try await Clerk.shared.auth.signInWithApple()
    }

    static func signInWithGoogle() async throws {
        _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    }

    // MARK: - Sign Up (email + password — requires email verification)
    // Returns the pending SignUp so the caller can drive the verification step.

    @discardableResult
    static func signUp(email: String, password: String) async throws -> SignUp {
        let signUp = try await Clerk.shared.auth.signUp(
            emailAddress: email,
            password: password
        )
        _ = try await signUp.sendEmailCode()
        return signUp
    }

    static func verifyEmail(signUp: SignUp, code: String) async throws {
        _ = try await signUp.verifyEmailCode(code)
    }

    // MARK: - Forgot Password
    // Step 1: initiate flow and send reset code.
    // Step 2: verifyCode unlocks the sign-in, then resetPassword sets the new password.

    @discardableResult
    static func requestPasswordReset(email: String) async throws -> SignIn {
        let signIn = try await Clerk.shared.auth.signIn(email)
        return try await signIn.sendResetPasswordEmailCode()
    }

    static func resetPassword(signIn: SignIn, code: String, newPassword: String) async throws {
        let verified = try await signIn.verifyCode(code)
        _ = try await verified.resetPassword(newPassword: newPassword)
    }

    // MARK: - Sign Out

    static func signOut() async throws {
        try await Clerk.shared.auth.signOut()
    }

    // MARK: - Token

    static func currentToken() async throws -> String {
        guard let token = try await Clerk.shared.session?.getToken() else {
            throw AppError.notAuthenticated
        }
        return token
    }

    // MARK: - Session Readiness

    // refreshClient() can return before the session is committed to client.currentSession.
    // This polls for up to 3 seconds as a fallback so callers can rely on session being set.
    static func ensureSessionReady() async {
        try? await Clerk.shared.refreshClient()
        guard Clerk.shared.session == nil else { return }
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            if Clerk.shared.session != nil { return }
        }
    }
}
