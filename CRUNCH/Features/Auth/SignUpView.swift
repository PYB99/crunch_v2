import SwiftUI
import ClerkKit
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "SignUpView")

struct SignUpView: View {
    var onSuccess: () -> Void
    var onSignIn: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var pendingSignUp: SignUp?
    @State private var step: Step = .credentials
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    private enum Step { case credentials, verification }
    private enum Field { case email, password, code }

    private var isCredentialsValid: Bool {
        email.contains("@") &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8
    }

    private var emailError: String? {
        guard !email.isEmpty, !email.contains("@") else { return nil }
        return "Enter a valid email address"
    }

    private var passwordError: String? {
        guard !password.isEmpty, password.count < 8 else { return nil }
        return "Password must be at least 8 characters"
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

                    if step == .credentials {
                        credentialsSection
                    } else {
                        verificationSection
                    }
                }
                .padding(.horizontal, Theme.lg)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Credentials

    @ViewBuilder
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: Theme.xs) {
            Text("Sign up")
                .font(Theme.heading)
                .foregroundStyle(Theme.textPrimary)
            Text("Create your free account to save your fuel plan.")
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
        }

        if let errorMessage {
            ErrorBanner(message: errorMessage) { self.errorMessage = nil }
        }

        VStack(spacing: Theme.sm) {
            VStack(alignment: .leading, spacing: Theme.xs) {
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

                if let emailError {
                    Text(emailError)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.error)
                }
            }

            VStack(alignment: .leading, spacing: Theme.xs) {
                SecureField("Password (min 8 characters)", text: $password)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .password)
                    .onChange(of: password) { _, _ in errorMessage = nil }
                    .onSubmit { Task { await submitCredentials() } }
                    .padding(Theme.md)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                    .foregroundStyle(Theme.textPrimary)

                if let passwordError {
                    Text(passwordError)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.error)
                }
            }
        }

        Text("By signing up you agree to our Terms of Service and Privacy Policy.")
            .font(Theme.caption)
            .foregroundStyle(Theme.textSecondary)

        PrimaryButton(
            title: "Create account",
            isLoading: isLoading,
            isDisabled: !isCredentialsValid
        ) {
            Task { await submitCredentials() }
        }

        HStack {
            Rectangle().fill(Theme.subtle).frame(height: 1)
            Text("or").font(Theme.caption).foregroundStyle(Theme.textSecondary)
            Rectangle().fill(Theme.subtle).frame(height: 1)
        }

        Button {
            Task { await signUpWithApple() }
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
            Task { await signUpWithGoogle() }
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

        Button {
            onSignIn()
        } label: {
            (Text("Already have an account? ")
                .foregroundStyle(Theme.textSecondary) +
             Text("Sign in")
                .foregroundStyle(Theme.brand))
            .font(Theme.body)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: 44)
        .padding(.bottom, Theme.xl)
    }

    // MARK: - Verification

    @ViewBuilder
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: Theme.xs) {
            Text("Check your email")
                .font(Theme.heading)
                .foregroundStyle(Theme.textPrimary)
            Text("We sent a 6-digit code to \(email). Enter it below.")
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
        }

        if let errorMessage {
            ErrorBanner(message: errorMessage) { self.errorMessage = nil }
        }

        TextField("Verification code", text: $verificationCode)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: .code)
            .onChange(of: verificationCode) { _, _ in errorMessage = nil }
            .padding(Theme.md)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
            .foregroundStyle(Theme.textPrimary)
            .onAppear { focusedField = .code }

        PrimaryButton(
            title: "Verify email",
            isLoading: isLoading,
            isDisabled: verificationCode.count < 6
        ) {
            Task { await verifyEmail() }
        }

        Button("Back") {
            step = .credentials
            errorMessage = nil
        }
        .font(Theme.body)
        .foregroundStyle(Theme.textSecondary)
        .frame(minHeight: 44)
        .padding(.bottom, Theme.xl)
    }

    // MARK: - Actions

    private func submitCredentials() async {
        guard isCredentialsValid else { return }
        isLoading = true
        errorMessage = nil
        do {
            let signUp = try await ClerkService.signUp(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password
            )
            pendingSignUp = signUp
            step = .verification
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func verifyEmail() async {
        guard let signUp = pendingSignUp else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await ClerkService.verifyEmail(signUp: signUp, code: verificationCode)
            await ClerkService.ensureSessionReady()
            await createUserProfile()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signUpWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            try await ClerkService.signInWithApple()
            await ClerkService.ensureSessionReady()
            await createUserProfile()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signUpWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await ClerkService.signInWithGoogle()
            await ClerkService.ensureSessionReady()
            await createUserProfile()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Calls the create-user-profile Edge Function to insert the users row via service role.
    private func createUserProfile() async {
        do {
            let token = try await ClerkService.currentToken()
            let url = URL(string: "\(Constants.supabaseURL)/functions/v1/create-user-profile")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            // Supabase gateway rejects RS256 Clerk JWTs in Authorization with UNAUTHORIZED_ASYMMETRIC_JWT.
            // Anon key goes in Authorization; Clerk JWT travels in x-clerk-token for the function to read.
            request.setValue("Bearer \(Constants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(Constants.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue(token, forHTTPHeaderField: "x-clerk-token")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = Constants.apiTimeoutSeconds
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 200 {
                logger.error("create-user-profile returned \(status, privacy: .public)")
            }
        } catch {
            logger.error("create-user-profile failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview {
    SignUpView(onSuccess: {}, onSignIn: {})
}
