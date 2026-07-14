import Foundation

enum TrainingPhase: String {
    case baseBuilding = "Base Building"
    case build        = "Build"
    case peakTraining = "Peak Training"
    case taper        = "Taper"
    case raceWeek     = "Race Week"
}

// Pure calculation engine — no state, no side effects.
// All formulas per AGENTS.md scientific references:
// BMR: Mifflin-St Jeor (Mifflin 1990)
// Carb targets: Burke et al. 2011, Jeukendrup 2011
// Protein: Morton et al. BJSM 2018, ISSN 2017
// Taper: Mujika & Padilla 2003
enum MacroEngine {

    // MARK: - Public

    static func calculate(
        user: UserProfile,
        raceDate: String?,
        sessionType: String,
        additionalActivities: [ActivityType] = []
    ) -> MacroTarget {
        let kg = user.weightKg

        // BMR (Mifflin-St Jeor)
        let bmr: Double = user.gender == "female"
            ? 10 * kg + 6.25 * user.heightCm - 5 * Double(user.age) - 161
            : 10 * kg + 6.25 * user.heightCm - 5 * Double(user.age) + 5

        // Normalise cycling/swimming → easy_run equivalent (AGENTS.md activity table)
        let normType = normalise(sessionType)

        // TDEE
        let tdee = bmr * tdeeMultiplier(normType)

        // Training phase
        let weeks = raceDate.map { weeksUntil(dateString: $0) } ?? 20
        let phase = trainingPhase(weeksToRace: weeks)

        // Carb target
        var carbsG = phase == .raceWeek
            ? 11.0 * kg          // carb-load: 11 g/kg (Burke 2011, Jeukendrup 2011)
            : carbsPerKg(normType) * kg

        // Protein: fixed 1.7 g/kg (Morton 2018, ISSN 2017)
        var proteinG = 1.7 * kg

        // Fat: derived from remaining TDEE, with floor at 0.5 g/kg
        let fatFloor = 0.5 * kg
        var fatG = max((tdee - carbsG * 4 - proteinG * 4) / 9, fatFloor)

        // Taper: maintain carbs, reduce fat ~12.5% (Mujika & Padilla 2003)
        if phase == .taper {
            fatG = max(fatG * 0.875, fatFloor)
        }

        // Secondary activity adjustments
        for activity in additionalActivities {
            switch activity {
            case .gymUpper:             proteinG += 10
            case .gymLower:             proteinG += 15;  carbsG += 30
            case .gymFull:              proteinG += 15;  carbsG += 20
            case .other:                proteinG += 10;  carbsG += 15
            case .cycling, .swimming:   break   // already handled via normalise() if primary
            }
        }

        return MacroTarget(
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            caloriesKcal: carbsG * 4 + proteinG * 4 + fatG * 9,
            sessionType: sessionType,
            trainingPhase: phase.rawValue
        )
    }

    static func trainingPhase(weeksToRace: Int) -> TrainingPhase {
        switch weeksToRace {
        case let w where w > 12: return .baseBuilding
        case 8...12:             return .build
        case 4..<8:              return .peakTraining
        case 1..<4:              return .taper
        default:                 return .raceWeek
        }
    }

    static func weeksUntil(dateString: String) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        guard let raceDate = fmt.date(from: dateString) else { return 20 }
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: today, to: raceDate).day ?? 0
        return max(0, days / 7)
    }

    // MARK: - Private

    private static func normalise(_ sessionType: String) -> String {
        (sessionType == "cycling" || sessionType == "swimming") ? "easy_run" : sessionType
    }

    private static func tdeeMultiplier(_ sessionType: String) -> Double {
        switch sessionType {
        case "easy_run":  return 1.55
        case "tempo":     return 1.725
        case "interval":  return 1.725
        case "long_run":  return 1.9
        case "race":      return 1.9
        default:          return 1.2     // rest
        }
    }

    private static func carbsPerKg(_ sessionType: String) -> Double {
        switch sessionType {
        case "easy_run":  return 6.0
        case "tempo":     return 7.0
        case "interval":  return 7.0
        case "long_run":  return 8.5
        case "race":      return 10.0
        default:          return 4.0    // rest
        }
    }
}
