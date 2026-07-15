import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class PersonalInfoViewModel {
    // Canonical storage: always metric. The View converts for display when
    // units == "imperial".
    var weightKg: Double = 70
    var heightCm: Double = 175
    var age: Int = 30
    var gender: String = "male"
    var trainingLevel: String = "beginner"
    var weeklyActivities: [String] = []
    var units: String = "metric"   // read-only here; edited in UnitsView

    var isSaving = false
    var errorMessage: String?

    func load() async {
        errorMessage = nil
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            struct Row: Decodable {
                let height_cm: Double?
                let weight_kg: Double?
                let age: Int?
                let gender: String?
                let training_level: String?
                let weekly_activities: [String]?
                let units: String?
            }
            let rows: [Row] = try await client
                .from("users")
                .select("height_cm, weight_kg, age, gender, training_level, weekly_activities, units")
                .execute().value
            if let r = rows.first {
                weightKg = r.weight_kg ?? 70
                heightCm = r.height_cm ?? 175
                age = r.age ?? 30
                gender = r.gender ?? "male"
                trainingLevel = r.training_level ?? "beginner"
                weeklyActivities = r.weekly_activities ?? []
                units = r.units ?? "metric"
            }
        } catch {
            errorMessage = "Couldn't load. Tap to retry."
        }
    }

    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        struct Update: Encodable {
            let height_cm: Double
            let weight_kg: Double
            let age: Int
            let gender: String
            let training_level: String
            let weekly_activities: [String]
            let updated_at: String
        }
        do {
            let client = try await SupabaseService.shared.authenticatedClient()
            try await client
                .from("users")
                .update(Update(
                    height_cm: heightCm,
                    weight_kg: weightKg,
                    age: age,
                    gender: gender,
                    training_level: trainingLevel,
                    weekly_activities: weeklyActivities,
                    updated_at: isoNow()
                ))
                .execute()
            return true
        } catch {
            errorMessage = "Couldn't save. Try again."
            return false
        }
    }

    func toggleActivity(_ raw: String) {
        if let idx = weeklyActivities.firstIndex(of: raw) {
            weeklyActivities.remove(at: idx)
        } else {
            weeklyActivities.append(raw)
        }
    }
}

// MARK: - View

struct PersonalInfoView: View {
    var onSaved: (() -> Void)? = nil
    @State private var viewModel = PersonalInfoViewModel()

    private let genders: [(value: String, label: String)] = [
        ("male", "Male"), ("female", "Female")
    ]
    private let levels: [(value: String, label: String)] = [
        ("beginner", "Beginner"), ("intermediate", "Intermediate"), ("advanced", "Advanced")
    ]

    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) { Task { await viewModel.load() } }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            weightSection
            heightSection
            ageSection
            genderSection
            levelSection
            activitiesSection
            saveSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Personal Info")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.brand)
    }

    // MARK: Sections

    private var weightSection: some View {
        Section("Weight") {
            Picker("Weight", selection: weightBinding) {
                ForEach(weightRange, id: \.self) { v in
                    Text("\(v) \(viewModel.units == "imperial" ? "lb" : "kg")").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .listRowBackground(Theme.card)
        }
    }

    private var heightSection: some View {
        Section("Height") {
            if viewModel.units == "imperial" {
                HStack(spacing: 0) {
                    Picker("Feet", selection: heightFeetBinding) {
                        ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    Picker("Inches", selection: heightInchBinding) {
                        ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                    }
                    .pickerStyle(.wheel)
                }
                .listRowBackground(Theme.card)
            } else {
                Picker("Height", selection: heightCmBinding) {
                    ForEach(140...210, id: \.self) { Text("\($0) cm").tag($0) }
                }
                .pickerStyle(.wheel)
                .listRowBackground(Theme.card)
            }
        }
    }

    private var ageSection: some View {
        Section("Age") {
            Picker("Age", selection: $viewModel.age) {
                ForEach(16...80, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .listRowBackground(Theme.card)
        }
    }

    private var genderSection: some View {
        Section("Gender") {
            ForEach(genders, id: \.value) { g in
                selectRow(g.label, isSelected: viewModel.gender == g.value) {
                    viewModel.gender = g.value
                }
            }
        }
    }

    private var levelSection: some View {
        Section("Training Level") {
            ForEach(levels, id: \.value) { l in
                selectRow(l.label, isSelected: viewModel.trainingLevel == l.value) {
                    viewModel.trainingLevel = l.value
                }
            }
        }
    }

    private var activitiesSection: some View {
        Section("Weekly Activities") {
            ForEach(ActivityType.allCases) { activity in
                selectRow(
                    activity.label,
                    isSelected: viewModel.weeklyActivities.contains(activity.rawValue)
                ) {
                    viewModel.toggleActivity(activity.rawValue)
                }
            }
        }
    }

    private var saveSection: some View {
        Section {
            PrimaryButton(title: "Save", isLoading: viewModel.isSaving, isDisabled: viewModel.isSaving) {
                Task {
                    if await viewModel.save() { onSaved?() }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    @ViewBuilder
    private func selectRow(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Theme.brand)
                }
            }
            .frame(minHeight: 44)
        }
        .listRowBackground(Theme.card)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Unit-aware picker bindings

    private var weightRange: [Int] {
        viewModel.units == "imperial" ? Array(88...330) : Array(40...150)
    }

    private var weightBinding: Binding<Int> {
        Binding(
            get: {
                viewModel.units == "imperial"
                    ? Int((viewModel.weightKg * 2.20462).rounded())
                    : Int(viewModel.weightKg.rounded())
            },
            set: { newValue in
                viewModel.weightKg = viewModel.units == "imperial"
                    ? Double(newValue) / 2.20462
                    : Double(newValue)
            }
        )
    }

    private var heightCmBinding: Binding<Int> {
        Binding(
            get: { Int(viewModel.heightCm.rounded()) },
            set: { viewModel.heightCm = Double($0) }
        )
    }

    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { Int((viewModel.heightCm / 2.54) / 12) },
            set: { newFeet in
                let inch = Int((viewModel.heightCm / 2.54).truncatingRemainder(dividingBy: 12).rounded())
                viewModel.heightCm = Double(newFeet * 12 + inch) * 2.54
            }
        )
    }

    private var heightInchBinding: Binding<Int> {
        Binding(
            get: { Int((viewModel.heightCm / 2.54).truncatingRemainder(dividingBy: 12).rounded()) },
            set: { newInch in
                let feet = Int((viewModel.heightCm / 2.54) / 12)
                viewModel.heightCm = Double(feet * 12 + newInch) * 2.54
            }
        )
    }
}

#Preview {
    NavigationStack {
        PersonalInfoView()
    }
}
