import SwiftUI
import ClerkKit

struct SignInView: View {
    var onSuccess: () -> Void
    var onSignUp: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false

    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var isFormValid: Bool {
        email.contains("@") &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8
    }

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.lg) {
                    // Wordmark
                    Text("CRUNCH")
                        .font(Theme.heroNumber)
                        .foregroundStyle(Theme.brand)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Theme.xl)

                    // Title
                    VStack(alignment: .leading, spacing: Theme.xs) {
                        Text("Sign in")
                            .font(Theme.heading)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Welcome back. Let's fuel your training.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    // Error banner
                    if let errorMessage {
                        ErrorBanner(message: errorMessage) {
                            self.errorMessage = nil
                        }
                    }

                    // Fields
                    VStack(spacing: Theme.sm) {
                        TextField("Email address", text: $email)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .onChange(of: email) { _, _ in errorMessage = nil }
                            .onSubmit { focusedField = .password }
                            .padding(Theme.md)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                            .foregroundStyle(Theme.textPrimary)

                        SecureField("Password", text: $password)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { _, _ in errorMessage = nil }
                            .onSubmit { Task { await signIn() } }
                            .padding(Theme.md)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    // Forgot password
                    Button("Forgot password?") {
                        showForgotPassword = true
                    }
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 44)

                    // Primary CTA
                    PrimaryButton(
                        title: "Sign in",
                        isLoading: isLoading,
                        isDisabled: !isFormValid
                    ) {
                        Task { await signIn() }
                    }

                    // Divider
                    HStack {
                        Rectangle().fill(Theme.subtle).frame(height: 1)
                        Text("or").font(Theme.caption).foregroundStyle(Theme.textSecondary)
                        Rectangle().fill(Theme.subtle).frame(height: 1)
                    }

                    // OAuth buttons
                    VStack(spacing: Theme.sm) {
                        // Apple Sign In — Clerk presents the native ASAuthorization dialog.
                        Button {
                            Task { await signInWithApple() }
                        } label: {
                            HStack(spacing: Theme.sm) {
                                Image(systemName: "applelogo")
                                Text("Continue with Apple")
                                    .font(Theme.subheading)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                        }
                        .frame(minHeight: 44)

                        Button {
                            Task { await signInWithGoogle() }
                        } label: {
                            HStack(spacing: Theme.sm) {
                                Image(systemName: "globe")
                                Text("Continue with Google")
                                    .font(Theme.subheading)
                            }
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                        }
                        .frame(minHeight: 44)
                    }

                    // Toggle to sign up
                    Button { onSignUp() } label: {
                        (Text("Don't have an account? ")
                            .foregroundStyle(Theme.textSecondary) +
                         Text("Sign up")
                            .foregroundStyle(Theme.brand))
                        .font(Theme.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(minHeight: 44)
                    .padding(.bottom, Theme.xl)
                }
                .padding(.horizontal, Theme.lg)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    // MARK: - Actions

    private func signIn() async {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await ClerkService.signIn(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password
            )
            await ClerkService.ensureSessionReady()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            try await ClerkService.signInWithApple()
            await ClerkService.ensureSessionReady()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await ClerkService.signInWithGoogle()
            await ClerkService.ensureSessionReady()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    SignInView(onSuccess: {}, onSignUp: {})
}
