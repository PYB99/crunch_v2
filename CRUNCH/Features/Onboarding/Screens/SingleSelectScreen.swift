import SwiftUI

// One tappable option that stores a slug into OnboardingData.
struct OBSelectOption: Identifiable {
    let value: String
    let label: String
    var subtitle: String? = nil
    var response: String? = nil     // commitment screen tailored copy
    var id: String { value }
}

// Config for the single-select archetype (mockup radio list). Auto-advancing
// screens commit on tap after a 0.3s beat; the commitment screen instead shows a
// tailored response and a Continue CTA.
struct OBSelectConfig {
    let title: String
    var subtitle: String?
    let options: [OBSelectOption]
    let keyPath: WritableKeyPath<OnboardingData, String?>
    var autoAdvance = true
    var titleUsesName = false       // interpolate the runner's name into the title
}

struct SingleSelectScreen: View {
    let coordinator: OnboardingCoordinator
    let config: OBSelectConfig

    private var selected: String? { coordinator.data[keyPath: config.keyPath] }

    private var resolvedTitle: String {
        config.titleUsesName
            ? config.title.replacingOccurrences(of: "{name}", with: coordinator.data.displayName)
            : config.title
    }

    var body: some View {
        OBScreen(coordinator: coordinator) {
            OBQuestionHeader(title: resolvedTitle, subtitle: config.subtitle)

            VStack(spacing: 12) {
                ForEach(Array(config.options.enumerated()), id: \.element.id) { i, option in
                    OnboardingOptionRow(
                        title: option.label,
                        subtitle: option.subtitle,
                        isSelected: selected == option.value,
                        index: i
                    ) { pick(option) }
                }
            }

            if config.autoAdvance {
                OBHint(text: "Tap to auto-advance")
            } else if let response = selectedResponse {
                Text(response)
                    .font(.system(size: 14))
                    .foregroundStyle(OB.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(OB.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(OB.ember, lineWidth: 1))
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        } footer: {
            if !config.autoAdvance {
                OnboardingCTA(title: "Continue", isDisabled: selected == nil) {
                    coordinator.advance()
                }
            }
        }
    }

    private var selectedResponse: String? {
        config.options.first { $0.value == selected }?.response
    }

    private func pick(_ option: OBSelectOption) {
        withAnimation { coordinator.data[keyPath: config.keyPath] = option.value }
        if config.autoAdvance {
            coordinator.advance(after: 0.3)
        }
    }
}

// MARK: - Presets (one per step the archetype serves)

extension OBSelectConfig {
    static let attribution = OBSelectConfig(
        title: "Where did you hear about Crunch?",
        subtitle: "No wrong answer — it just helps us.",
        options: [
            .init(value: "reddit",    label: "Reddit"),
            .init(value: "friend",    label: "From a friend"),
            .init(value: "app_store", label: "The App Store"),
            .init(value: "social",    label: "Instagram / TikTok / X"),
            .init(value: "other",     label: "Somewhere else"),
        ],
        keyPath: \.attribution
    )

    static let raceType = OBSelectConfig(
        title: "What are you training for, {name}?",
        subtitle: "This shapes everything that follows.",
        options: [
            .init(value: "5k",             label: "5K"),
            .init(value: "10k",            label: "10K"),
            .init(value: "half_marathon",  label: "Half Marathon"),
            .init(value: "marathon",       label: "Marathon"),
            .init(value: "ultra_marathon", label: "Ultra Marathon"),
            .init(value: "other",          label: "Other"),
        ],
        keyPath: \.raceType,
        titleUsesName: true
    )

    static let sex = OBSelectConfig(
        title: "What's your biological sex?",
        subtitle: "Used only for energy and fueling calculations.",
        options: [
            .init(value: "male",   label: "Male"),
            .init(value: "female", label: "Female"),
        ],
        keyPath: \.gender
    )

    static let trainingLevel = OBSelectConfig(
        title: "How serious is your training?",
        subtitle: "Be honest — this tunes everything downstream.",
        options: [
            .init(value: "beginner",     label: "Beginner"),
            .init(value: "intermediate", label: "Intermediate"),
            .init(value: "advanced",     label: "Advanced"),
        ],
        keyPath: \.trainingLevel
    )

    static let diet = OBSelectConfig(
        title: "Any dietary preferences?",
        subtitle: "So your meal estimates actually fit how you eat.",
        options: DietPreference.allCases.map {
            OBSelectOption(value: $0.rawValue, label: $0.displayName)
        },
        keyPath: \.dietOptional
    )

    static let commitment = OBSelectConfig(
        title: "How committed are you to fueling this block, {name}?",
        options: [
            .init(value: "all_in", label: "All in",
                  response: "Love it. Every long run and every taper day, we'll be ready together."),
            .init(value: "mostly", label: "Mostly, life permitting",
                  response: "That's honest — and it's plenty. We'll fit around your week, not fight it."),
            .init(value: "curious", label: "Just seeing what this is",
                  response: "No pressure. Take a look — the plan will be here whenever you're ready to lean in."),
        ],
        keyPath: \.commitment,
        autoAdvance: false,
        titleUsesName: true
    )
}
