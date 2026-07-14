import SwiftUI

struct MealLibraryView: View {
    let meals: [Meal]
    var onAdd: (String) -> Void
    var onEdit: (Meal) -> Void
    var onDelete: (Meal) -> Void

    @State private var mealToDelete: Meal?

    private let mealTimes: [(id: String, title: String, emoji: String)] = [
        (id: "breakfast", title: "Breakfast", emoji: "🌅"),
        (id: "lunch",     title: "Lunch",     emoji: "☀️"),
        (id: "dinner",    title: "Dinner",    emoji: "🌙"),
        (id: "snack",     title: "Snack",     emoji: "⚡️"),
    ]

    var body: some View {
        LazyVStack(spacing: Theme.sm) {
            ForEach(mealTimes, id: \.id) { group in
                let groupMeals = meals.filter { $0.mealTime == group.id }
                mealGroup(time: group.id, title: group.title, emoji: group.emoji, meals: groupMeals)
            }
        }
        .alert("Delete meal?", isPresented: Binding(
            get: { mealToDelete != nil },
            set: { if !$0 { mealToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let m = mealToDelete { onDelete(m) }
                mealToDelete = nil
            }
            Button("Cancel", role: .cancel) { mealToDelete = nil }
        } message: {
            Text("This removes \"\(mealToDelete?.mealName ?? "")\" from your meal library.")
        }
    }

    // MARK: - Group

    private func mealGroup(time: String, title: String, emoji: String, meals: [Meal]) -> some View {
        VStack(alignment: .leading, spacing: Theme.xs) {
            Text("\(emoji) \(title)")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.md)

            VStack(spacing: 0) {
                ForEach(Array(meals.enumerated()), id: \.element.id) { idx, meal in
                    mealRow(meal)
                    if idx < meals.count - 1 {
                        Divider()
                            .background(Theme.subtle)
                            .padding(.leading, Theme.md)
                    }
                }

                if !meals.isEmpty {
                    Divider()
                        .background(Theme.subtle)
                        .padding(.leading, Theme.md)
                }

                // Add button
                Button {
                    onAdd(time)
                } label: {
                    HStack(spacing: Theme.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add \(title.lowercased()) meal")
                            .font(Theme.body)
                    }
                    .foregroundStyle(Theme.brand)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
                    .padding(.horizontal, Theme.md)
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .padding(.horizontal, Theme.md)
    }

    // MARK: - Row

    private func mealRow(_ meal: Meal) -> some View {
        HStack(spacing: Theme.sm) {
            VStack(alignment: .leading, spacing: Theme.xs) {
                Text(meal.mealName)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let macros = meal.estimatedMacros {
                    Text(
                        "~\(Int(macros.carbsG.rounded()))g C · " +
                        "~\(Int(macros.proteinG.rounded()))g P · " +
                        "~\(Int(macros.fatG.rounded()))g F"
                    )
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("Portions not estimated")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.neutral)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.md)
        .padding(.vertical, Theme.sm)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .onTapGesture { onEdit(meal) }
        .contextMenu {
            Button(role: .destructive) {
                mealToDelete = meal
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let fakeMeals = [
        Meal(id: UUID(), userId: "u", mealName: "Oats + banana + honey",
             mealTime: "breakfast",
             estimatedMacros: EstimatedMacros(carbsG: 65, proteinG: 12, fatG: 8),
             portionBaseline: 1, isActive: true, sortOrder: 1),
        Meal(id: UUID(), userId: "u", mealName: "Chicken rice bowl",
             mealTime: "lunch",
             estimatedMacros: EstimatedMacros(carbsG: 70, proteinG: 35, fatG: 10),
             portionBaseline: 1, isActive: true, sortOrder: 2),
        Meal(id: UUID(), userId: "u", mealName: "Pasta with chicken",
             mealTime: "dinner",
             estimatedMacros: EstimatedMacros(carbsG: 85, proteinG: 40, fatG: 12),
             portionBaseline: 1, isActive: true, sortOrder: 3),
    ]
    ScrollView {
        MealLibraryView(meals: fakeMeals, onAdd: { _ in }, onEdit: { _ in }, onDelete: { _ in })
            .padding(.vertical, Theme.md)
    }
    .background(Theme.surface)
}
