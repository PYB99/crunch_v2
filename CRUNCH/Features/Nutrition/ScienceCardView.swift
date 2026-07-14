import SwiftUI

struct ScienceCardView: View {
    let title: String
    let bodyText: String
    let citation: String
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Theme.sm) {
                Text(bodyText)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(citation)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.neutral)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Theme.sm)
        } label: {
            Text(title)
                .font(Theme.subheading)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(Theme.md)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .tint(Theme.brand)
        .padding(.horizontal, Theme.md)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.sm) {
            ScienceCardView(
                title: "Carbohydrate targets",
                bodyText: "On training days, you need 6–10g of carbs per kg — that's up to 700g on a race day. Rest days drop to ~280g. Carb periodisation means eating more fuel on the days you actually burn it.",
                citation: "Burke LM et al. Carbohydrates for training and competition. Journal of Sports Sciences, 2011."
            )
            ScienceCardView(
                title: "Protein for endurance runners",
                bodyText: "Endurance runners need 1.7g of protein per kg daily — about 119g for a 70kg runner. Spread it across meals; your body can only absorb 25–40g per sitting.",
                citation: "Morton RW et al. BJSM, 2018."
            )
        }
        .padding(.vertical, Theme.md)
    }
    .background(Theme.surface)
}
