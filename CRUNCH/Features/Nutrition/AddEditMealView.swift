import SwiftUI
import Supabase

struct AddEditMealView: View {
    let mealTime: String
    let existingMeal: Meal?
    let clerkUserId: String
    var onSaved: () -> Void

    @State private var mealName: String
    @State private var selectedTime: String
    @State private var estimatedMacros: EstimatedMacros?
    @State private var isEstimating = false
    @State private var estimationError: String?
    @State private var isSaving = false
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    init(
        mealTime: String,
        existingMeal: Meal? = nil,
        clerkUserId: String,
        onSaved: @escaping () -> Void
    ) {
        self.mealTime = mealTime
        self.existingMeal = existingMeal
        self.clerkUserId = clerkUserId
        self.onSaved = onSaved
        _mealName     = State(initialValue: existingMeal?.mealName ?? "")
        _selectedTime = State(initialValue: existingMeal?.mealTime ?? mealTime)
        _estimatedMacros = State(initialValue: existingMeal?.estimatedMacros)
    }

    private var canSave: Bool {
        !mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving && !isEstimating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.lg) {

                    // Description field
                    VStack(alignment: .leading, spacing: Theme.xs) {
                        Text("What do you usually eat?")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textSecondary)
                        TextField(
                            "e.g. Oats with banana and honey",
                            text: $mealName,
                            axis: .vertical
                        )
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3, reservesSpace: true)
                        .padding(Theme.md)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                        .focused($nameFocused)
                        .onChange(of: mealName) { _, _ in
                            estimatedMacros = nil
                            estimationError = nil
                        }
                    }

                    // Meal time picker
                    VStack(alignment: .leading, spacing: Theme.xs) {
                        Text("Meal time")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Picker("", selection: $selectedTime) {
                            Text("Breakfast").tag("breakfast")
                            Text("Lunch").tag("lunch")
                            Text("Dinner").tag("dinner")
                            Text("Snack").tag("snack")
                        }
                        .pickerStyle(.segmented)
                    }

                    // Estimation area
                    estimationArea

                    if let err = saveError {
                        Text(err)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.error)
                    }

                    PrimaryButton(
                        title: existingMeal == nil ? "Save meal" : "Update meal",
                        isLoading: isSaving,
                        isDisabled: !canSave
                    ) {
                        Task { await save() }
                    }
                }
                .padding(Theme.md)
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle(existingMeal == nil ? "Add Meal" : "Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onAppear { nameFocused = existingMeal == nil }
        }
    }

    // MARK: - Estimation Area

    @ViewBuilder
    private var estimationArea: some View {
        if isEstimating {
            HStack(spacing: Theme.sm) {
                ProgressView().tint(Theme.brand)
                Text("Estimating portions...")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

        } else if let macros = estimatedMacros {
            HStack {
                VStack(alignment: .leading, spacing: Theme.xs) {
                    Text("Estimated per serving")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("~\(Int(macros.carbsG.rounded()))g carbs · ~\(Int(macros.proteinG.rounded()))g protein · ~\(Int(macros.fatG.rounded()))g fat")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button {
                    Task { await estimate() }
                } label: {
                    Text("Re-estimate")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.brand)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(Theme.md)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

        } else {
            VStack(alignment: .leading, spacing: Theme.xs) {
                let desc = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
                Button {
                    Task { await estimate() }
                } label: {
                    HStack(spacing: Theme.sm) {
                        Image(systemName: "sparkles")
                        Text("Estimate portions")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(desc.isEmpty ? Theme.textSecondary : Theme.brand)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                }
                .disabled(desc.isEmpty)

                if let err = estimationError {
                    Text(err)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.error)
                }
            }
        }
    }

    // MARK: - Actions

    private func estimate() async {
        let desc = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else { return }
        isEstimating = true
        estimationError = nil
        do {
            let token = try await ClerkService.currentToken()
            estimatedMacros = try await AnthropicService.estimateMeal(description: desc, clerkToken: token)
        } catch {
            estimationError = "Couldn't estimate — tap to retry."
        }
        isEstimating = false
    }

    private func save() async {
        let trimmed = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        saveError = nil

        // Auto-estimate on save if not yet done (soft-fail — saves with nil macros on failure)
        if estimatedMacros == nil {
            if let token = try? await ClerkService.currentToken() {
                estimatedMacros = try? await AnthropicService.estimateMeal(description: trimmed, clerkToken: token)
            }
        }

        do {
            let client = try await SupabaseService.shared.authenticatedClient()

            if let existing = existingMeal {
                struct MealUpdate: Encodable {
                    let meal_name: String
                    let meal_time: String
                    let estimated_macros: EstimatedMacros?
                }
                try await client.from("meals")
                    .update(MealUpdate(
                        meal_name: trimmed,
                        meal_time: selectedTime,
                        estimated_macros: estimatedMacros
                    ))
                    .eq("id", value: existing.id.uuidString)
                    .execute()
            } else {
                // Get next sort_order for this meal_time
                struct SortRow: Decodable { let sort_order: Int? }
                let sortRows: [SortRow] = try await client.from("meals")
                    .select("sort_order")
                    .eq("meal_time", value: selectedTime)
                    .order("sort_order", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                let nextOrder = (sortRows.first?.sort_order ?? 0) + 1

                struct MealInsert: Encodable {
                    let user_id: String
                    let meal_name: String
                    let meal_time: String
                    let estimated_macros: EstimatedMacros?
                    let is_active: Bool
                    let sort_order: Int
                }
                try await client.from("meals")
                    .insert(MealInsert(
                        user_id: clerkUserId,
                        meal_name: trimmed,
                        meal_time: selectedTime,
                        estimated_macros: estimatedMacros,
                        is_active: true,
                        sort_order: nextOrder
                    ))
                    .execute()

                MixpanelService.track(.mealAdded(mealTime: selectedTime))
            }

            onSaved()
            dismiss()
        } catch {
            saveError = "Couldn't save. Try again."
        }

        isSaving = false
    }
}

// MARK: - Previews

#Preview("Add") {
    AddEditMealView(mealTime: "breakfast", clerkUserId: "user_xxx") {}
}

#Preview("Edit") {
    AddEditMealView(
        mealTime: "dinner",
        existingMeal: Meal(
            id: UUID(),
            userId: "user_xxx",
            mealName: "Pasta with chicken",
            mealTime: "dinner",
            estimatedMacros: EstimatedMacros(carbsG: 85, proteinG: 40, fatG: 12),
            portionBaseline: 1,
            isActive: true,
            sortOrder: 1
        ),
        clerkUserId: "user_xxx"
    ) {}
}
