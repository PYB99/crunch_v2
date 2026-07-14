import SwiftUI

struct MealCardData {
    let mealTime: MealTime
    let mealName: String
    let filledDots: Int
    let portionLabel: String
    let reason: String
    let breakdown: String
    let gramDetails: String
    let scienceTip: String

    enum MealTime {
        case breakfast, lunch, dinner

        var label: String {
            switch self {
            case .breakfast: "Breakfast"
            case .lunch:     "Lunch"
            case .dinner:    "Dinner"
            }
        }

        var symbol: String {
            switch self {
            case .breakfast: "cup.and.saucer.fill"
            case .lunch:     "carrot.fill"
            case .dinner:    "fork.knife"
            }
        }

        var symbolColor: Color {
            switch self {
            case .breakfast: .orange
            case .lunch:     .yellow
            case .dinner:    Color(hex: "#C0A050")
            }
        }
    }
}

struct MealCardView: View {
    let data: MealCardData
    @State private var isExpanded = false
    @State private var showGrams = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            // Meal time label + disclosure chevron
            HStack {
                HStack(spacing: Theme.xs) {
                    Image(systemName: data.mealTime.symbol)
                        .font(.system(size: 14))
                        .foregroundStyle(data.filledDots >= 2 ? data.mealTime.symbolColor : Theme.textSecondary)
                        .opacity(data.filledDots >= 2 ? 1.0 : 0.5)
                    Text(data.mealTime.label)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.brand)
            }

            Text(data.mealName)
                .font(Theme.subheading)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: Theme.sm) {
                PortionDotsView(filled: data.filledDots)
                Text(data.portionLabel)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(data.reason)
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)

            if isExpanded {
                Divider()
                    .background(Theme.subtle)
                    .padding(.vertical, Theme.xs)

                Text(data.breakdown)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showGrams.toggle()
                    }
                } label: {
                    Text("See the numbers \(showGrams ? "↑" : "→")")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.brand)
                }
                .frame(minWidth: 44, minHeight: 44)

                if showGrams {
                    Text(data.gramDetails)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .transition(.opacity)
                }

                Text(data.scienceTip)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(Theme.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.sm))
            }
        }
        .padding(Theme.md)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
                if !isExpanded { showGrams = false }
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.surface.ignoresSafeArea()
        MealCardView(data: MealCardData(
            mealTime: .dinner,
            mealName: "Pasta with chicken",
            filledDots: 4,
            portionLabel: "Double portion tonight",
            reason: "You need ~320g carbs for tomorrow's 22K",
            breakdown: "Cook double your usual pasta — that's about 2 large bowls instead of 1.",
            gramDetails: "~140g carbs · ~52g protein · ~18g fat",
            scienceTip: "Burke et al. (2011): 8–10g carbs/kg in the 24h before a long effort maximises glycogen storage."
        ))
        .padding()
    }
}
