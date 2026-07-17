import SwiftUI

struct DayRowView: View {
    let date: Date
    let session: TrainingSession?
    var previousSessionType: String? = nil
    var nextSessionType: String? = nil
    let userProfile: UserProfile
    let raceDate: String?
    let meals: [Meal]

    @State private var isExpanded = false

    // MARK: - Computed

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var isPast: Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .day) == .orderedAscending
    }

    private var isCompletedRun: Bool {
        guard let s = session else { return false }
        return MacroEngine.isRunSession(s.sessionType) && s.status == "completed"
    }

    // Split race_* types collapse onto "race" for the session-type-derived
    // badge/copy switches below. (Badge unification with PortionEngine is a
    // separate audit item; recovery_day is reflected in the expanded macros,
    // not the compact arrow, until that lands.)
    private var badgeType: String? {
        guard let t = session?.sessionType else { return nil }
        return MacroEngine.isRaceSession(t) ? "race" : t
    }

    private var dayName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    private var dayDateStr: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return fmt.string(from: date)
    }

    private var sessionBadge: String {
        guard let s = session else { return "Rest" }
        let label = s.sessionType.replacingOccurrences(of: "_", with: " ").capitalized
        if let km = s.distanceKm, km > 0 {
            return "\(label) · \(Int(km.rounded())) km"
        }
        return label
    }

    private var portionArrow: String {
        switch badgeType {
        case "long_run", "race":               return "↑↑"
        case "tempo", "interval":              return "↑"
        case "easy_run", "cycling", "swimming": return "→"
        default:                               return "↓"
        }
    }

    private var portionLabel: String {
        switch badgeType {
        case "long_run", "race":               return "Double"
        case "tempo", "interval":              return "Extra"
        case "easy_run", "cycling", "swimming": return "Normal"
        default:                               return "Lighter"
        }
    }

    private var portionColor: Color {
        switch badgeType {
        case "long_run", "race":               return Theme.warning
        case "tempo", "interval":              return Theme.brand
        case "easy_run", "cycling", "swimming": return Theme.textSecondary
        default:                               return Theme.neutral
        }
    }

    private var macroTarget: MacroTarget {
        MacroEngine.calculate(
            user: userProfile,
            raceDate: raceDate,
            sessionType: session?.sessionType ?? "rest",
            previousSessionType: previousSessionType,
            nextSessionType: nextSessionType
        )
    }

    private var portionResults: [PortionResult] {
        guard !meals.isEmpty else { return [] }
        return PortionEngine.portions(target: macroTarget, meals: meals)
    }

    private var fuelingTip: String {
        switch badgeType {
        case "long_run": return "Carb-load the night before. Aim for ~8.5g/kg today — your biggest fuel window."
        case "race":     return "Race day: fuel to your distance. Stay hydrated. Trust your training."
        case "tempo", "interval": return "High-intensity day — carbs are your primary fuel source."
        case "easy_run": return "Easy day: keep it balanced. No need to over-fuel."
        default:         return "Rest day: lighter carbs, maintain protein for muscle recovery."
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Compact row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Theme.sm) {
                    // Day + date
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayName)
                            .font(.system(size: 13, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? Theme.brand : Theme.textPrimary)
                        Text(dayDateStr)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(width: 44)

                    // Session badge
                    Text(sessionBadge)
                        .font(Theme.body)
                        .foregroundStyle(session == nil ? Theme.textSecondary : Theme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Portion indicator
                    HStack(spacing: 2) {
                        Text(portionArrow)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(portionColor)
                        Text(portionLabel)
                            .font(Theme.caption)
                            .foregroundStyle(portionColor)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.md)
                .padding(.vertical, Theme.sm)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                Divider().background(Theme.subtle)
                expandedContent
                    .padding(Theme.md)
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(isToday ? Theme.brand.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, Theme.md)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: Theme.md) {

            // Session detail
            if let s = session {
                VStack(alignment: .leading, spacing: Theme.xs) {
                    HStack(spacing: Theme.sm) {
                        if s.status == "completed" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                        }
                        Text(sessionBadge)
                            .font(Theme.subheading)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    if let mins = s.durationMins, mins > 0 {
                        Text("\(mins) min")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            // Meal portions
            if !portionResults.isEmpty {
                VStack(alignment: .leading, spacing: Theme.xs) {
                    Text("Meal portions")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(portionResults, id: \.meal.id) { result in
                        HStack {
                            Text(result.meal.mealName)
                                .font(Theme.body)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(result.level.label)
                                .font(Theme.caption)
                                .foregroundStyle(result.level == .normal ? Theme.textSecondary : Theme.brand)
                        }
                    }
                }
            }

            // Fueling tip
            HStack(alignment: .top, spacing: Theme.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brand)
                    .padding(.top, 2)
                Text(fuelingTip)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Coach link for past completed runs
            if isPast && isCompletedRun {
                Button {
                    // Phase 7: switch to Coach tab + link session
                } label: {
                    HStack(spacing: Theme.xs) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 12))
                        Text("Ask your Coach about this run")
                            .font(Theme.caption)
                    }
                    .foregroundStyle(Theme.brand)
                }
                .frame(minHeight: 44)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let profile = UserProfile(weightKg: 75, heightCm: 178, age: 32, gender: "male", trainingLevel: "intermediate")
    let meals = [
        Meal(id: UUID(), userId: "u", mealName: "Oats + banana",
             mealTime: "breakfast",
             estimatedMacros: EstimatedMacros(carbsG: 65, proteinG: 12, fatG: 8),
             portionBaseline: 1, isActive: true, sortOrder: 1),
        Meal(id: UUID(), userId: "u", mealName: "Pasta with chicken",
             mealTime: "dinner",
             estimatedMacros: EstimatedMacros(carbsG: 85, proteinG: 40, fatG: 12),
             portionBaseline: 1, isActive: true, sortOrder: 3),
    ]
    ScrollView {
        VStack(spacing: Theme.sm) {
            DayRowView(date: Date(), session: nil, userProfile: profile, raceDate: "2026-10-18", meals: meals)
        }
        .padding(.vertical, Theme.md)
    }
    .background(Theme.surface)
}
