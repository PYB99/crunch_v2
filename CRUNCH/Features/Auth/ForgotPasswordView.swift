import SwiftUI
import ClerkKit

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var pendingSignIn: SignIn?
    @State private var step: Step = .email
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    @FocusState private var focusedField: Field?

    private enum Step { case email, reset }
    private enum Field { case email, code, password }

    private var isEmailValid: Bool {
        email.contains("@") && !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isResetValid: Bool {
        code.count >= 6 && newPassword.count >= 8
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.lg) {
                        if didSucceed {
                            successView
                        } else if step == .email {
                            emailStep
                        } else {
                            resetStep
                        }
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.lg)
                }
            }
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.brand)
                }
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var emailStep: some View {
        VStack(alignment: .leading, spacing: Theme.xs) {
            Text("Forgot your password?")
                .font(Theme.heading)
                .foregroundStyle(Theme.textPrimary)
            Text("Enter your email and we'll send a reset code.")
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
        }

        if let errorMessage {
            ErrorBanner(message: errorMessage) { self.errorMessage = nil }
        }

        TextField("Email address", text: $email)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
            .focused($focusedField, equals: .email)
            .onChange(of: email) { _, _ in errorMessage = nil }
            .onSubmit { Task { await sendResetCode() } }
            .padding(Theme.md)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
            .foregroundStyle(Theme.textPrimary)
            .onAppear { focusedField = .email }

        PrimaryButton(
            title: "Send reset code",
            isLoading: isLoading,
            isDisabled: !isEmailValid
        ) {
            Task { await sendResetCode() }
        }
    }

    @ViewBuilder
    private var resetStep: some View {
        VStack(alignment: .leading, spacing: Theme.xs) {
            Text("Enter your new password")
                .font(Theme.heading)
                .foregroundStyle(Theme.textPrimary)
            Text("Check \(email) for your 6-digit code.")
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
        }

        if let errorMessage {
            ErrorBanner(message: errorMessage) { self.errorMessage = nil }
        }

        VStack(spacing: Theme.sm) {
            TextField("Reset code", text: $code)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .code)
                .onChange(of: code) { _, _ in errorMessage = nil }
                .padding(Theme.md)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                .foregroundStyle(Theme.textPrimary)
                .onAppear { focusedField = .code }

            SecureField("New password (min 8 characters)", text: $newPassword)
                .focused($focusedField, equals: .password)
                .onChange(of: newPassword) { _, _ in errorMessage = nil }
                .onSubmit { Task { await resetPassword() } }
                .padding(Theme.md)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                .foregroundStyle(Theme.textPrimary)
        }

        PrimaryButton(
            title: "Reset password",
            isLoading: isLoading,
            isDisabled: !isResetValid
        ) {
            Task { await resetPassword() }
        }

        Button("Back") {
            step = .email
            errorMessage = nil
        }
        .font(Theme.body)
        .foregroundStyle(Theme.textSecondary)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var successView: some View {
        VStack(spacing: Theme.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.success)
            Text("Password reset!")
                .font(Theme.heading)
                .foregroundStyle(Theme.textPrimary)
            Text("You can now sign in with your new password.")
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Done") { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.xl)
    }

    // MARK: - Actions

    private func sendResetCode() async {
        guard isEmailValid else { return }
        isLoading = true
        errorMessage = nil
        do {
            let signIn = try await ClerkService.requestPasswordReset(
                email: email.trimmingCharacters(in: .whitespaces).lowercased()
            )
            pendingSignIn = signIn
            step = .reset
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func resetPassword() async {
        guard let signIn = pendingSignIn, isResetValid else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await ClerkService.resetPassword(signIn: signIn, code: code, newPassword: newPassword)
            didSucceed = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ForgotPasswordView()
}
