import SwiftUI

enum ActivityType: String, CaseIterable, Identifiable {
    case gymUpper = "gym_upper"
    case gymLower = "gym_lower"
    case gymFull  = "gym_full"
    case cycling  = "cycling"
    case swimming = "swimming"
    case other    = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gymUpper: "Gym — Upper Body"
        case .gymLower: "Gym — Lower Body"
        case .gymFull:  "Gym — Full Body"
        case .cycling:  "Cycling"
        case .swimming: "Swimming"
        case .other:    "Other"
        }
    }

    var symbol: String {
        switch self {
        case .gymUpper: "figure.arms.open"
        case .gymLower: "figure.run"
        case .gymFull:  "figure.strengthtraining.functional"
        case .cycling:  "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .other:    "plus.circle"
        }
    }
}

struct ActivityToggleView: View {
    @Binding var selectedActivity: ActivityType?
    @Binding var otherDescription: String
    @Environment(\.dismiss) private var dismiss

    @State private var showOtherInput = false
    @State private var otherText = ""
    @FocusState private var isOtherTextFocused: Bool

    var body: some View {
        NavigationStack {
            if showOtherInput {
                otherInputView
                    .navigationTitle("What did you do?")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                showOtherInput = false
                                otherText = ""
                            }
                            .foregroundStyle(Theme.brand)
                        }
                    }
            } else {
                activityListView
                    .navigationTitle("Add activity")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                                .foregroundStyle(Theme.brand)
                        }
                    }
            }
        }
    }

    // MARK: - Activity list

    private var activityListView: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            LazyVStack(spacing: Theme.sm) {
                ForEach(ActivityType.allCases) { activity in
                    Button {
                        if activity == .other {
                            showOtherInput = true
                        } else {
                            selectedActivity = activity
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: Theme.md) {
                            Image(systemName: activity.symbol)
                                .frame(width: 24)
                                .foregroundStyle(Theme.brand)
                            Text(activity.label)
                                .font(Theme.body)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if selectedActivity == activity {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.brand)
                            }
                        }
                        .padding(Theme.md)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                    }
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, Theme.md)
            .padding(.top, Theme.sm)
        }
    }

    // MARK: - Other text input

    private var otherInputView: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.md) {
                TextField("e.g. Yoga, hiking, stretching…", text: $otherText)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(Theme.md)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                    .focused($isOtherTextFocused)
                    .submitLabel(.done)
                    .onSubmit { saveOther() }
                    .onAppear { isOtherTextFocused = true }

                PrimaryButton(
                    title: "Save",
                    isDisabled: otherText.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    saveOther()
                }

                Spacer()
            }
            .padding(Theme.md)
            .padding(.top, Theme.sm)
        }
    }

    // MARK: - Actions

    private func saveOther() {
        let trimmed = otherText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        otherDescription = trimmed
        selectedActivity = .other
        dismiss()
    }
}

#Preview("Activity list") {
    ActivityToggleView(selectedActivity: .constant(nil), otherDescription: .constant(""))
}

#Preview("Other input") {
    ActivityToggleView(selectedActivity: .constant(.other), otherDescription: .constant("Yoga"))
}
