import SwiftUI

struct OBMealConfig {
    let time: MealTime
    let title: String
    let subtitle: String
    let placeholder: String
    var skipLabel: String?
    let keyPath: WritableKeyPath<OnboardingData, [String]>
}

// Screens 20–22 — free-text meal descriptions (mockup .field textarea + "Add
// another" + optional skip). Estimation is deferred to submit; here we only
// collect. Nothing is written until account creation.
struct MealEntryScreen: View {
    @Bindable var coordinator: OnboardingCoordinator
    let config: OBMealConfig
    @FocusState private var focusedIndex: Int?

    private var entries: [String] { coordinator.data[keyPath: config.keyPath] }

    var body: some View {
        OBScreen(coordinator: coordinator) {
            OBQuestionHeader(title: config.title, subtitle: config.subtitle)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(entries.indices, id: \.self) { i in
                    ZStack(alignment: .topLeading) {
                        if entries[i].isEmpty {
                            Text(config.placeholder)
                                .font(.system(size: 15))
                                .foregroundStyle(OB.ink3)
                                .padding(EdgeInsets(top: 20, leading: 22, bottom: 0, trailing: 18))
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: entryBinding(i))
                            .font(.system(size: 15))
                            .foregroundStyle(OB.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 92)
                            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 12))
                            .focused($focusedIndex, equals: i)
                            .onChange(of: entries[i]) { _, newValue in
                                if newValue.count > Constants.maxMealDescriptionLength {
                                    coordinator.data[keyPath: config.keyPath][i] =
                                        String(newValue.prefix(Constants.maxMealDescriptionLength))
                                }
                            }
                    }
                    .background(RoundedRectangle(cornerRadius: 16).fill(OB.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(focusedIndex == i ? OB.ember : OB.cardBorder, lineWidth: 1.5)
                    )
                }

                Button {
                    coordinator.data[keyPath: config.keyPath].append("")
                } label: {
                    Text("+ Add another")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OB.ember)
                }
                .buttonStyle(.plain)
            }
        } footer: {
            VStack(spacing: 0) {
                OnboardingCTA(title: "Continue") {
                    focusedIndex = nil
                    coordinator.advance()
                }
                if let skip = config.skipLabel {
                    OnboardingSecondaryCTA(title: skip) {
                        coordinator.data[keyPath: config.keyPath] = [""]
                        coordinator.advance()
                    }
                }
            }
        }
    }

    private func entryBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { coordinator.data[keyPath: config.keyPath].indices.contains(i)
                    ? coordinator.data[keyPath: config.keyPath][i] : "" },
            set: { coordinator.data[keyPath: config.keyPath][i] = $0 }
        )
    }
}

// MARK: - Presets

extension OBMealConfig {
    static let breakfast = OBMealConfig(
        time: .breakfast,
        title: "What do you usually have for breakfast?",
        subtitle: "Describe it your way — we'll do the rest.",
        placeholder: "e.g. Greek yoghurt with granola and a banana",
        skipLabel: "I don't eat breakfast",
        keyPath: \.breakfastMeals
    )

    static let lunch = OBMealConfig(
        time: .lunch,
        title: "What about lunch?",
        subtitle: "Same idea — just describe your usual.",
        placeholder: "e.g. Chicken burrito bowl",
        skipLabel: "I skip lunch",
        keyPath: \.lunchMeals
    )

    static let dinner = OBMealConfig(
        time: .dinner,
        title: "And dinner?",
        subtitle: "Last one — then we'll show you something.",
        placeholder: "e.g. Salmon, rice, greens",
        keyPath: \.dinnerMeals
    )
}
