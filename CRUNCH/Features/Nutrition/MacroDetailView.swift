import SwiftUI

struct MacroDetailView: View {
    let userProfile: UserProfile
    let race: Race?
    @State private var isExpanded = false

    private let rows: [(type: String, label: String)] = [
        ("rest",      "Rest day"),
        ("easy_run",  "Easy run"),
        ("tempo",     "Tempo / Intervals"),
        ("long_run",  "Long run"),
        ("race",      "Race day"),
    ]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                columnHeaders
                Divider().background(Theme.subtle).padding(.vertical, Theme.xs)
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    let target = MacroEngine.calculate(
                        user: userProfile,
                        raceDate: race?.raceDate,
                        sessionType: row.type
                    )
                    macroRow(label: row.label, target: target)
                    if idx < rows.count - 1 {
                        Divider().background(Theme.subtle)
                    }
                }

                Divider().background(Theme.subtle).padding(.top, Theme.sm)
                Text("Portion mapping: ≤1.25× Normal · 1.25–1.75× Extra · >1.75× Double")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.sm)
            }
            .padding(.top, Theme.sm)
        } label: {
            Text("See the numbers")
                .font(Theme.subheading)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(Theme.md)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .tint(Theme.brand)
        .padding(.horizontal, Theme.md)
    }

    private var columnHeaders: some View {
        HStack {
            Text("Session")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Carbs")
                .frame(width: 52, alignment: .trailing)
            Text("Protein")
                .frame(width: 60, alignment: .trailing)
            Text("Fat")
                .frame(width: 44, alignment: .trailing)
        }
        .font(Theme.caption)
        .foregroundStyle(Theme.textSecondary)
    }

    private func macroRow(label: String, target: MacroTarget) -> some View {
        HStack {
            Text(label)
                .font(Theme.body)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(Int(target.carbsG.rounded()))g")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, alignment: .trailing)
            Text("\(Int(target.proteinG.rounded()))g")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 60, alignment: .trailing)
            Text("\(Int(target.fatG.rounded()))g")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, Theme.xs)
    }
}

#Preview {
    ScrollView {
        MacroDetailView(
            userProfile: UserProfile(weightKg: 70, heightCm: 175, age: 30, gender: "male", trainingLevel: "intermediate"),
            race: nil
        )
        .padding(.vertical, Theme.md)
    }
    .background(Theme.surface)
}
