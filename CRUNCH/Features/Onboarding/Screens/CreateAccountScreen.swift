import SwiftUI
import ClerkKit

// Screen 28 — the account boundary (mockup .authbtn + fields). Creates the Clerk
// session (Apple / Google / email-code), then hands off to the coordinator, which
// writes the full onboarding payload and advances to the plan reveal. Nothing was
// persisted before this point.
struct CreateAccountScreen: View {
    let coordinator: OnboardingCoordinator

    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var pendingSignUp: SignUp?
    @State private var step: Step = .credentials
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Step { case credentials, verification }
    private enum Field { case email, password, code }

    private var saving: Bool {
        if case .saving = coordinator.submitState { return true }
        return false
    }
    private var submitError: String? {
        if case let .failed(msg) = coordinator.submitState { return msg }
        return nil
    }

    var body: some View {
        OBScreen(coordinator: coordinator) {
            if step == .credentials { credentials } else { verification }
        } footer: {
            EmptyView()
        }
    }

    // MARK: - Credentials

    private var credentials: some View {
        VStack(alignment: .leading, spacing: 12) {
            OBQuestionHeader(title: "Save your fuel plan",
                             subtitle: "So it's here next time you open Crunch.")

            if let msg = errorMessage ?? submitError { errorBanner(msg) }

            authButton("Continue with Apple", system: "applelogo") {
                await authenticate { try await ClerkService.signInWithApple() }
            }
            authButton("Continue with Google", system: "globe") {
                await authenticate { try await ClerkService.signInWithGoogle() }
            }

            HStack {
                Rectangle().fill(OB.cardBorder).frame(height: 1)
                Text("or").font(.system(size: 12.5)).foregroundStyle(OB.ink3)
                Rectangle().fill(OB.cardBorder).frame(height: 1)
            }
            .padding(.vertical, 6)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .focused($focus, equals: .email)
                .onChange(of: email) { _, _ in errorMessage = nil }
                .onSubmit { focus = .password }
                .obField(focused: focus == .email)

            SecureField("Password (min 8 characters)", text: $password)
                .submitLabel(.go)
                .focused($focus, equals: .password)
                .onChange(of: password) { _, _ in errorMessage = nil }
                .onSubmit { Task { await createWithEmail() } }
                .obField(focused: focus == .password)

            OnboardingCTA(title: "Create account", isLoading: isLoading || saving,
                          isDisabled: !credentialsValid) {
                Task { await createWithEmail() }
            }
            .padding(.top, 4)

            Text("By continuing you agree to our Terms and Privacy Policy. Your data stays yours.")
                .font(.system(size: 11.5))
                .foregroundStyle(OB.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    // MARK: - Verification

    private var verification: some View {
        VStack(alignment: .leading, spacing: 14) {
            OBQuestionHeader(title: "Check your email",
                             subtitle: "We sent a 6-digit code to \(email). Enter it below.")

            if let msg = errorMessage ?? submitError { errorBanner(msg) }

            TextField("Verification code", text: $code)
                .keyboardType(.numberPad)
                .focused($focus, equals: .code)
                .onChange(of: code) { _, _ in errorMessage = nil }
                .obField(focused: focus == .code)
                .onAppear { focus = .code }

            OnboardingCTA(title: saving ? "Saving your plan…" : "Verify email",
                          isLoading: isLoading || saving, isDisabled: code.count < 6) {
                Task { await verifyAndFinish() }
            }

            if submitError != nil {
                OnboardingSecondaryCTA(title: "Retry saving your plan") {
                    Task { _ = await coordinator.completeAccountCreation() }
                }
            }

            Button("Back") { step = .credentials; errorMessage = nil }
                .font(.system(size: 14))
                .foregroundStyle(OB.ink2)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
    }

    // MARK: - Actions

    private var credentialsValid: Bool {
        email.contains("@") && password.count >= 8
    }

    private func createWithEmail() async {
        guard credentialsValid else { return }
        isLoading = true; errorMessage = nil
        do {
            pendingSignUp = try await ClerkService.signUp(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password
            )
            step = .verification
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func verifyAndFinish() async {
        guard let signUp = pendingSignUp else { return }
        isLoading = true; errorMessage = nil
        do {
            try await ClerkService.verifyEmail(signUp: signUp, code: code)
            await ClerkService.ensureSessionReady()
            isLoading = false
            _ = await coordinator.completeAccountCreation()   // submits + advances on success
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func authenticate(_ signIn: @escaping () async throws -> Void) async {
        isLoading = true; errorMessage = nil
        do {
            try await signIn()
            await ClerkService.ensureSessionReady()
            isLoading = false
            _ = await coordinator.completeAccountCreation()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Pieces

    private func authButton(_ title: String, system: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack(spacing: 10) {
                Image(systemName: system)
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(OB.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 27).fill(OB.card))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(OB.cardBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || saving)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(OB.ember)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(OB.ember.opacity(0.1)))
    }
}
