import SwiftUI

// Screen 4 (mockup) — the runner's first name, live-bound into every downstream
// "{name}" slot. Its value is personalisation only (not persisted as a column).
struct NameScreen: View {
    @Bindable var coordinator: OnboardingCoordinator
    @FocusState private var focused: Bool

    var body: some View {
        OBScreen(coordinator: coordinator) {
            OBQuestionHeader(
                title: "What should we call you?",
                subtitle: "We'll use it to make this feel like yours."
            )
            TextField("Your first name", text: $coordinator.data.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(advance)
                .obField(focused: focused)
        } footer: {
            OnboardingCTA(title: "Continue", isDisabled: !isValid, action: advance)
        }
        .onAppear { focused = true }
    }

    private var isValid: Bool {
        !coordinator.data.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func advance() {
        guard isValid else { return }
        focused = false
        coordinator.advance()
    }
}
