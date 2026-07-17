import SwiftUI

struct OBMultiConfig {
    let title: String
    var subtitle: String?
    let options: [OBSelectOption]
    var exclusiveValue: String?          // e.g. "nothing" — clears all others when picked
    let initial: Set<String>
    let onCommit: (Set<String>) -> Void
}

// Multi-select archetype (mockup .opt[data-multi]). Keeps a local selection so the
// "Nothing else" sentinel (which isn't a stored ActivityType) can be shown picked
// without polluting the model; commits on Continue.
struct MultiSelectScreen: View {
    let coordinator: OnboardingCoordinator
    let config: OBMultiConfig

    @State private var selection: Set<String> = []

    var body: some View {
        OBScreen(coordinator: coordinator) {
            OBQuestionHeader(title: config.title, subtitle: config.subtitle)

            VStack(spacing: 12) {
                ForEach(Array(config.options.enumerated()), id: \.element.id) { i, option in
                    OnboardingOptionRow(
                        title: option.label,
                        subtitle: option.subtitle,
                        isSelected: selection.contains(option.value),
                        isMultiSelect: true,
                        index: i
                    ) { toggle(option.value) }
                }
            }
        } footer: {
            OnboardingCTA(title: "Continue") {
                config.onCommit(sanitised)
                coordinator.advance()
            }
        }
        .onAppear { selection = config.initial }
    }

    private func toggle(_ value: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            if value == config.exclusiveValue {
                selection = [value]
            } else {
                if let ex = config.exclusiveValue { selection.remove(ex) }
                if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
            }
        }
    }

    // Drop the exclusive sentinel before it reaches the model.
    private var sanitised: Set<String> {
        var s = selection
        if let ex = config.exclusiveValue { s.remove(ex) }
        return s
    }
}

// MARK: - Presets

extension OBMultiConfig {
    static func activities(_ coordinator: OnboardingCoordinator) -> OBMultiConfig {
        OBMultiConfig(
            title: "Anything else during the week?",
            subtitle: "Select all that apply.",
            options: ActivityType.allCases.map {
                OBSelectOption(value: $0.rawValue, label: $0.label)
            } + [OBSelectOption(value: "nothing", label: "Nothing else")],
            exclusiveValue: "nothing",
            initial: Set(coordinator.data.activities.map(\.rawValue)),
            onCommit: { set in
                coordinator.data.activities = Set(set.compactMap(ActivityType.init(rawValue:)))
                for a in set { MixpanelService.track(.activityAdded(activityType: a)) }
            }
        )
    }

    static func painPoints(_ coordinator: OnboardingCoordinator) -> OBMultiConfig {
        OBMultiConfig(
            title: "What's gone wrong before?",
            subtitle: "Pick everything that's happened to you.",
            options: [
                .init(value: "hit_the_wall",  label: "Hit the wall late in a race"),
                .init(value: "stomach",       label: "Stomach turned mid-run"),
                .init(value: "dead_legs",     label: "Dead legs on back-to-back days"),
                .init(value: "no_appetite",   label: "No appetite after hard sessions"),
                .init(value: "just_guessing", label: "Honestly, just guessing"),
            ],
            initial: coordinator.data.painPoints,
            onCommit: { coordinator.data.painPoints = $0 }
        )
    }
}
