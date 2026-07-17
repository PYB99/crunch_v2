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
// Scope note (master-spec Sections 14 items 1–7 + the §14.11 "confirm wired"
// tail): targeted upgrade of the single-value engine, NOT the full 8-layer
// rebuild. Now switched on (Phase 5.1): training-level A/B/C carb bands (§4.1),
// day-before long-run/race carb boost (§4.2, surfaced via Layer 8), and the
// masters age protein modifier with the §5.1 2.5 g/kg hard cap. Already live:
// diet protein modifier (§2.4) + low-carb conflict flag (§9.2). Still deferred
// to the Section 7–12 phase: phase carb/protein multipliers (§4.3), the new
// phase detection (§7.1 post_race_recovery), and the duration/MET model (§3.3).
enum MacroEngine {

    // MARK: - Public

    static func calculate(
        user: UserProfile,
        raceDate: String?,
        sessionType: String,
        previousSessionType: String? = nil,
        nextSessionType: String? = nil,
        additionalActivities: [ActivityType] = []
    ) -> MacroTarget {
        let kg = user.weightKg

        // Training-level band (§2.1) — selects the Layer 3 carb-table column.
        let band = trainingBand(user.trainingLevel)

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
            : carbsPerKg(type, band: band) * kg

        // Protein: 1.7 g/kg baseline; recovery day 2.0 g/kg (§5.1 in-scope subset).
        // Order per §5.1: base × age modifier (§2.3) × diet digestibility modifier
        // (§2.4), then the 2.5 g/kg hard cap — all on the per-kg value, before the
        // fixed absolute activity additions below. Taper 1.85 / post-race 2.2 and
        // the dual-goal floor remain deferred.
        let baseProteinPerKg: Double = (type == "recovery_day" ? 2.0 : 1.7)
        let ageModifier = ageProteinModifier(user.age)
        let dietModifier = DietLayer.proteinModifier(for: user.diet)
        let proteinPerKg = min(baseProteinPerKg * ageModifier * dietModifier, 2.5)
        var proteinG = proteinPerKg * kg

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
        // isCarbLoad gates the training-day carb ceiling off during race-week
        // carb-load, whose deliberate TDEE overshoot is FIX B's job (see E1 note).
        let (fatG, adjustedCarbsG, fatFlags) = calculateFat(
            tdee: tdee, carbsG: carbsG, proteinG: proteinG, kg: kg, type: type,
            isCarbLoad: phase == .raceWeek
        )
        carbsG = adjustedCarbsG

        // Low-carb/keto conflict (§9.2): raise a coaching flag, never override the
        // carb target. Not reachable from onboarding (only omni/veg/vegan/pesc are
        // offered) but honoured for imported/edited profiles.
        var flags = fatFlags
        if DietLayer.isLowCarbConflict(user.diet) {
            flags.append(DietLayer.dietCarbConflictFlag)
        }

        // Day-before long-run/race carb boost (§4.2). Extra glycogen-topping carbs
        // for tomorrow's big session, surfaced on dinner by the Portion Engine
        // (Layer 8). Kept OUT of the reconciled daily totals above (per §4.4 it
        // rides separately) so the Fat Engine's FIX A/B can't claw it back.
        let dayBeforeBoostG = isDayBeforeLongOrRace(nextSessionType)
            ? dayBeforeBoostPerKg(band) * kg
            : 0.0

        return MacroTarget(
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            caloriesKcal: carbsG * 4 + proteinG * 4 + fatG * 9,
            sessionType: resolvedType,
            trainingPhase: phase.rawValue,
            flags: flags,
            dayBeforeCarbBoostG: dayBeforeBoostG
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

    // Training-level → band (§2.1): beginner A / intermediate B / advanced C.
    // Any non-standard string falls to B, preserving the prior Band-B behavior.
    private static func trainingBand(_ level: String) -> String {
        switch level {
        case "beginner":  return "A"
        case "advanced":  return "C"
        default:          return "B"   // intermediate + unknown
        }
    }

    // Carbohydrate g/kg (§4.1) — full session × training-level band matrix. Only
    // the canonical primary session types are reachable here (cycling/swimming
    // fold to easy_run; gym_* are additive activities), so the §4.1 gym/cross-
    // training rows are intentionally omitted. Unknown band defaults to B.
    private static func carbsPerKg(_ type: String, band: String) -> Double {
        let (a, b, c): (Double, Double, Double)
        switch type {
        case "easy_run":       (a, b, c) = (4.0, 5.5, 6.5)
        case "tempo":          (a, b, c) = (5.5, 7.0, 8.0)
        case "interval":       (a, b, c) = (6.0, 7.5, 8.5)
        case "long_run":       (a, b, c) = (7.0, 8.5, 10.0)
        case "recovery_day":   (a, b, c) = (5.5, 6.0, 6.5)
        case "race_5k":        (a, b, c) = (5.0, 5.5, 6.0)
        case "race_10k":       (a, b, c) = (6.0, 6.5, 7.0)
        case "race_half":      (a, b, c) = (7.5, 8.5, 9.5)
        case "race_marathon":  (a, b, c) = (9.0, 10.0, 11.0)
        default:               (a, b, c) = (3.0, 3.5, 4.5)   // rest
        }
        switch band {
        case "A":  return a
        case "C":  return c
        default:   return b
        }
    }

    // Masters age → protein modifier (§2.3): <40 ×1.00 / 40–50 ×1.12 / >50 ×1.20.
    private static func ageProteinModifier(_ age: Int) -> Double {
        switch age {
        case ..<40:  return 1.00
        case 40...50: return 1.12
        default:     return 1.20   // > 50
        }
    }

    // Day-before boost trigger (§4.2): tomorrow is a long run or a half/full/ultra
    // race. Canonicalise first so legacy "race"/"race_ultra" fold to race_marathon;
    // short races (5k/10k) deliberately do NOT trigger a night-before load.
    private static func isDayBeforeLongOrRace(_ nextSessionType: String?) -> Bool {
        guard let next = nextSessionType else { return false }
        switch canonical(next) {
        case "long_run", "race_half", "race_marathon": return true
        default:                                       return false
        }
    }

    // Day-before boost g/kg by band (§4.2): A +1.0 / B +1.5 / C +2.0.
    private static func dayBeforeBoostPerKg(_ band: String) -> Double {
        switch band {
        case "A":  return 1.0
        case "C":  return 2.0
        default:   return 1.5
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
        tdee: Double, carbsG: Double, proteinG: Double, kg: Double, type: String,
        isCarbLoad: Bool = false
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

        // Training-day carb ceiling (E1 monotonicity guard). On non-carb-load days,
        // never let reconciled carbs sit above the value that reconciles the day to
        // TDEE at the 20% fat floor. FIX A's 0.9×floor relaxation and FIX B's 2%
        // trigger tolerance can otherwise leave a lower training-level band above the
        // ceiling while a higher band gets clamped to it — inverting the §4.1 bands
        // (e.g. an 85kg long run, where advanced fell below intermediate). This cap
        // forbids the inversion; it is deliberately skipped on race-week carb-load,
        // whose intended TDEE overshoot is governed by FIX B. Full de-collapse of the
        // bands above the ceiling remains Section 7's job (AGENTS.md tech-debt E1).
        if !isCarbLoad {
            let carbCeiling = (tdee - proteinG * 4 - fatMinimum * 9) / 4
            let ceilingCap = max(carbCeiling, sessionCarbFloor(type) * kg)
            if finalCarbsG > ceilingCap + 0.0001 {
                flags.append("training_carb_ceiling_capped")
                finalCarbsG = ceilingCap
                let remainingForFat = tdee - (finalCarbsG * 4 + proteinG * 4)
                fatG = max(remainingForFat / 9, fatMinimum * 0.9)
            }
        }

        return (fatG, finalCarbsG, flags)
    }
}
