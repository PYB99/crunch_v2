import Foundation

enum TrainingPhase: String {
    case baseBuilding = "Base Building"
    case build        = "Build"
    case peakTraining = "Peak Training"
    case taper        = "Taper"
    case raceWeek     = "Race Week"
}

// Pure calculation engine — no state, no side effects.
// All formulas per docs/crunch-nutrition-engine-MASTER-SPEC.md §3–6:
// BMR: Mifflin-St Jeor (Mifflin 1990)
// Carb targets: Burke et al. 2011, Jeukendrup 2011
// Protein: Morton et al. BJSM 2018, ISSN 2017; recovery-day 2.0 g/kg (Ivy 2002)
// Fat: 20–35% of energy with reconciliation guards (Mountjoy 2014, Loucks 2004)
//
// Scope note (master-spec Section 14, items 1–6 only): this is a targeted upgrade
// of the single-value engine, NOT the full 8-layer rebuild. Training-level carb
// bands (§4.1 columns), race/age modifiers, phase carb multipliers, and the
// new phase detection (§7.1 post_race_recovery) are deferred to the Section 7–12
// phase. The diet layer (§2.4 protein modifier + §9.2 low-carb conflict flag) is
// implemented here (Phase 5). Representative Band-B values stand in where a band
// table would apply.
enum MacroEngine {

    // MARK: - Public

    static func calculate(
        user: UserProfile,
        raceDate: String?,
        sessionType: String,
        previousSessionType: String? = nil,
        additionalActivities: [ActivityType] = []
    ) -> MacroTarget {
        let kg = user.weightKg

        // Resolve recovery-day (§3.4), then canonicalise aliases (cycling/swimming
        // → easy_run; legacy/ultra "race" → race_marathon).
        let resolvedType = resolveSessionType(today: sessionType, previous: previousSessionType)
        let type = canonical(resolvedType)

        // BMR (Mifflin-St Jeor)
        let bmr: Double = user.gender == "female"
            ? 10 * kg + 6.25 * user.heightCm - 5 * Double(user.age) - 161
            : 10 * kg + 6.25 * user.heightCm - 5 * Double(user.age) + 5

        // TDEE
        let tdee = bmr * tdeeMultiplier(type)

        // Training phase.
        // TODO(Section 7 — Phase Engine, deferred): base/build/peak/taper
        // currently compute identically for a given session_type; only
        // race_week diverges (via the carb-load protocol). This is correct
        // interim behavior, not a bug — full phase-based carb/protein
        // multipliers land when Sections 7.1-7.2 are implemented.
        let weeks = raceDate.map { weeksUntil(dateString: $0) } ?? 20
        let phase = trainingPhase(weeksToRace: weeks)

        // Carb target (race week forces carb-load; §4.5's race-type-specific
        // load values are deferred, so the flat 11 g/kg race-week load stands,
        // bounded below by FIX B).
        var carbsG = phase == .raceWeek
            ? 11.0 * kg
            : carbsPerKg(type) * kg

        // Protein: 1.7 g/kg baseline; recovery day 2.0 g/kg (§5.1 in-scope subset).
        // Diet digestibility modifier (§2.4) scales the per-kg target before any
        // activity additions (which are fixed absolute grams). Taper 1.85 /
        // post-race 2.2 / age modifiers remain deferred.
        let baseProteinPerKg: Double = (type == "recovery_day" ? 2.0 : 1.7)
        let dietModifier = DietLayer.proteinModifier(for: user.diet)
        var proteinG = baseProteinPerKg * kg * dietModifier

        // Secondary activity adjustments (interim additive model — Section 11's
        // MET/EEE→TDEE routing is deferred; these deltas are applied pre-fat so
        // the Fat Engine reconciles the day's total to TDEE).
        for activity in additionalActivities {
            switch activity {
            case .gymUpper:             proteinG += 10
            case .gymLower:             proteinG += 15;  carbsG += 30
            case .gymFull:              proteinG += 15;  carbsG += 20
            case .other:                proteinG += 10;  carbsG += 15
            case .cycling, .swimming:   break   // already handled via canonical() if primary
            }
        }

        // Fat Engine (§6.1) — 20% floor / 35% ceiling + both reconciliation fixes.
        let (fatG, adjustedCarbsG, fatFlags) = calculateFat(
            tdee: tdee, carbsG: carbsG, proteinG: proteinG, kg: kg, type: type
        )
        carbsG = adjustedCarbsG

        // Low-carb/keto conflict (§9.2): raise a coaching flag, never override the
        // carb target. Not reachable from onboarding (only omni/veg/vegan/pesc are
        // offered) but honoured for imported/edited profiles.
        var flags = fatFlags
        if DietLayer.isLowCarbConflict(user.diet) {
            flags.append(DietLayer.dietCarbConflictFlag)
        }

        return MacroTarget(
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            caloriesKcal: carbsG * 4 + proteinG * 4 + fatG * 9,
            sessionType: resolvedType,
            trainingPhase: phase.rawValue,
            flags: flags
        )
    }

    // Recovery-day detection (§3.4). Upgrades a *light* day that follows a long
    // run or race — deliberately does NOT downgrade a genuine hard session the
    // day after a long run (that would under-fuel it), which is a small,
    // intent-preserving deviation from the spec's literal unconditional override.
    static func resolveSessionType(today: String, previous: String?) -> String {
        guard let prev = previous,
              prev == "long_run" || prev == "race" || prev.hasPrefix("race_") else {
            return today
        }
        let hardTypes: Set<String> = [
            "tempo", "interval", "long_run",
            "race", "race_5k", "race_10k", "race_half", "race_marathon", "race_ultra"
        ]
        return hardTypes.contains(today) ? today : "recovery_day"
    }

    // True for session types that drive the primary TDEE/carb calc (runs + races,
    // incl. the split race_* values and the legacy "race"). Used by callers to
    // separate the primary run from logged activities.
    static func isRunSession(_ sessionType: String) -> Bool {
        switch sessionType {
        case "easy_run", "tempo", "interval", "long_run": return true
        case "race": return true
        default: return sessionType.hasPrefix("race_")
        }
    }

    static func isRaceSession(_ sessionType: String) -> Bool {
        sessionType == "race" || sessionType.hasPrefix("race_")
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

    // Maps aliases onto the canonical session types used by the lookup tables.
    // Legacy/ultra "race" strings fold to race_marathon so they can never fall
    // through to the rest default (defensive alias, master-spec flag 2).
    private static func canonical(_ sessionType: String) -> String {
        switch sessionType {
        case "cycling", "swimming":                     return "easy_run"
        case "race", "race_ultra", "race_ultra_marathon": return "race_marathon"
        default:                                        return sessionType
        }
    }

    // TDEE multipliers (§3.2). Existing run values unchanged; recovery_day + the
    // race_* split are the in-scope additions. The full §3.2 recalibration of
    // easy/tempo/interval/long is deferred.
    private static func tdeeMultiplier(_ type: String) -> Double {
        switch type {
        case "easy_run":       return 1.55
        case "tempo":          return 1.725
        case "interval":       return 1.725
        case "long_run":       return 1.9
        case "recovery_day":   return 1.35
        case "race_5k":        return 1.75
        case "race_10k":       return 1.85
        case "race_half":      return 2.00
        case "race_marathon":  return 2.40
        default:               return 1.2     // rest
        }
    }

    // Carbohydrate g/kg (§4.1, Band-B representative). Existing run values
    // unchanged; recovery_day + race_* split are the in-scope additions.
    private static func carbsPerKg(_ type: String) -> Double {
        switch type {
        case "easy_run":       return 6.0
        case "tempo":          return 7.0
        case "interval":       return 7.0
        case "long_run":       return 8.5
        case "recovery_day":   return 6.0
        case "race_5k":        return 5.5
        case "race_10k":       return 6.5
        case "race_half":      return 8.5
        case "race_marathon":  return 10.0
        default:               return 4.0    // rest
        }
    }

    // Session carb floors (§6.3) — the lower bound both fat guards reduce toward.
    private static func sessionCarbFloor(_ type: String) -> Double {
        switch type {
        case "long_run":                    return 5.0
        case "race_half":                   return 6.0
        case "race_marathon", "race_ultra": return 8.0
        default:                            return 3.0
        }
    }

    // Fat Engine (§6.1): derive fat from the 20–35%-of-energy band, then run
    // FIX A (ordinary fat-floor reconciliation) and FIX B (carb-load collision
    // guard) so the day's macros reconcile to TDEE. Returns (fat_g, adjusted
    // carbs_g, flags).
    private static func calculateFat(
        tdee: Double, carbsG: Double, proteinG: Double, kg: Double, type: String
    ) -> (fatG: Double, carbsG: Double, flags: [String]) {

        let usedCalories = carbsG * 4 + proteinG * 4
        let fatFromRemainder = max(0, (tdee - usedCalories) / 9)

        let fatMinimum = (tdee * 0.20) / 9   // 20% of energy (not 0.5 g/kg — §6.2)
        let fatMaximum = (tdee * 0.35) / 9

        var fatG = max(fatMinimum, min(fatFromRemainder, fatMaximum))
        var finalCarbsG = carbsG
        var flags: [String] = []

        // FIX A — when the fat floor triggers, reduce carbs toward the session
        // floor, then re-derive fat from the room actually left. Every session.
        if fatG > fatFromRemainder {
            flags.append("fat_floor_triggered")
            let excessFatCalories = (fatG - fatFromRemainder) * 9
            let carbReduction = excessFatCalories / 4
            let sessionFloorG = sessionCarbFloor(type) * kg
            finalCarbsG = max(carbsG - carbReduction, sessionFloorG)

            let remainingForFat = tdee - (finalCarbsG * 4 + proteinG * 4)
            fatG = max(remainingForFat / 9, fatMinimum * 0.9)
        }

        // FIX B — carb-load collision guard, TDEE-relative floor (not a flat
        // 8 g/kg, which overshoots small/low-TDEE bodies).
        let totalCheck = finalCarbsG * 4 + proteinG * 4 + fatMinimum * 9
        if totalCheck > tdee * 1.02 {
            let excess = totalCheck - tdee
            let reduction = excess / 4
            let weightBasedFloor = 8.0 * kg
            let tdeeRelativeFloor = (tdee * 0.55) / 4
            let hardFloor = min(weightBasedFloor, tdeeRelativeFloor)
            let newCarbs = max(finalCarbsG - reduction, hardFloor)
            if abs(newCarbs - finalCarbsG) > 0.0001 {
                flags.append("carb_load_capped")
                finalCarbsG = newCarbs
                let remainingForFat = tdee - (finalCarbsG * 4 + proteinG * 4)
                fatG = max(remainingForFat / 9, fatMinimum * 0.9)
            }
        }

        return (fatG, finalCarbsG, flags)
    }
}
