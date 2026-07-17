import SwiftUI

// Screen 6 — race name (optional) + date (required, future). The date is what
// every countdown and carb-load counts against.
struct RaceDetailsScreen: View {
    @Bindable var coordinator: OnboardingCoordinator
    @FocusState private var nameFocused: Bool
    @State private var showDatePicker = false

    // Default the picker to a sensible future date so the wheel opens somewhere useful.
    private var dateBinding: Binding<Date> {
        Binding(
            get: { coordinator.data.raceDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())! },
            set: { coordinator.data.raceDate = $0 }
        )
    }

    var body: some View {
        OBScreen(coordinator: coordinator) {
            OBQuestionHeader(
                title: "What's it called, and when?",
                subtitle: "The date is what everything gets counted against."
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    OBFieldLabel(text: "Race name (optional)")
                    TextField("e.g. Amsterdam Marathon", text: $coordinator.data.raceName)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .obField(focused: nameFocused)
                }

                VStack(alignment: .leading, spacing: 7) {
                    OBFieldLabel(text: "Race date")
                    DatePicker(
                        "",
                        selection: dateBinding,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(OB.ember)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 16).fill(OB.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(OB.cardBorder, lineWidth: 1.5))
                    .colorScheme(.dark)
                    .onChange(of: coordinator.data.raceDate) { _, _ in dateChosen = true }
                }
            }
        } footer: {
            OnboardingCTA(title: "Continue", isDisabled: !isValid) {
                nameFocused = false
                coordinator.advance()
            }
        }
    }

    // Require an explicit future date choice.
    @State private var dateChosen = false
    private var isValid: Bool {
        guard let d = coordinator.data.raceDate else { return false }
        return dateChosen && d > Date()
    }
}
