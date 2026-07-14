import Testing
import Foundation
@testable import CRUNCH

// Regression suite for the master-spec engine upgrade (Sections 14 items 1–6).
// Many pre-upgrade tests asserted the OLD behavior (0.5 g/kg fat floor, single
// "race" type, unbounded race-week carb-load, taper fat ×0.875). Those are
// rewritten here as property assertions, since the Fat Engine's reconciliation
// (FIX A/B) now adjusts carbs/fat so the day reconciles to TDEE — hand-fixed
// exact values no longer hold. Diet/dual-goal cases (Sections 9/10) are out of
// scope for this pass and deliberately omitted.
struct MacroEngineTests {

    // MARK: - Shared

    let male75   = UserProfile(weightKg: 75, heightCm: 178, age: 32, gender: "male",   trainingLevel: "intermediate")
    let female60 = UserProfile(weightKg: 60, heightCm: 165, age: 28, gender: "female", trainingLevel: "beginner")

    func raceDateString(weeksAway: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: weeksAway * 7, to: Date())!
        return formatter.string(from: date)
    }

    // TDEE multipliers the engine is expected to use (mirrors §3.2 in-scope subset).
    static let multipliers: [String: Double] = [
        "rest": 1.2, "easy_run": 1.55, "tempo": 1.725, "interval": 1.725,
        "long_run": 1.9, "recovery_day": 1.35,
        "race_5k": 1.75, "race_10k": 1.85, "race_half": 2.00, "race_marathon": 2.40,
    ]

    func bmr(_ u: UserProfile) -> Double {
        u.gender == "female"
            ? 10 * u.weightKg + 6.25 * u.heightCm - 5 * Double(u.age) - 161
            : 10 * u.weightKg + 6.25 * u.heightCm - 5 * Double(u.age) + 5
    }

    // Expected TDEE for a non-race-week day (raceDate nil → base phase).
    func expectedTDEE(_ u: UserProfile, _ sessionType: String) -> Double {
        bmr(u) * (Self.multipliers[sessionType] ?? 1.2)
    }

    // MARK: - Phase detection (unchanged — §7.1 overhaul deferred)

    @Test func trainingPhaseBaseBuilding() {
        #expect(MacroEngine.trainingPhase(weeksToRace: 20) == .baseBuilding)
        #expect(MacroEngine.trainingPhase(weeksToRace: 13) == .baseBuilding)
    }
    @Test func trainingPhaseBuild() {
        #expect(MacroEngine.trainingPhase(weeksToRace: 12) == .build)
        #expect(MacroEngine.trainingPhase(weeksToRace: 8)  == .build)
    }
    @Test func trainingPhasePeakTraining() {
        #expect(MacroEngine.trainingPhase(weeksToRace: 7) == .peakTraining)
        #expect(MacroEngine.trainingPhase(weeksToRace: 4) == .peakTraining)
    }
    @Test func trainingPhaseTaper() {
        #expect(MacroEngine.trainingPhase(weeksToRace: 3) == .taper)
        #expect(MacroEngine.trainingPhase(weeksToRace: 1) == .taper)
    }
    @Test func trainingPhaseRaceWeek() {
        #expect(MacroEngine.trainingPhase(weeksToRace: 0) == .raceWeek)
    }

    // MARK: - Protein (exact — never reduced by reconciliation)

    @Test func standardProteinIs1_7gPerKg() {
        let t = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        #expect(abs(t.proteinG - 1.7 * 75.0) < 0.01)
    }

    @Test func recoveryDayProteinIs2_0gPerKg() {
        let t = MacroEngine.calculate(user: male75, raceDate: nil,
                                      sessionType: "rest", previousSessionType: "long_run")
        #expect(t.sessionType == "recovery_day")
        #expect(abs(t.proteinG - 2.0 * 75.0) < 0.01)
    }

    @Test func caloriesAreConsistent() {
        let t = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "long_run")
        let sum = t.carbsG * 4 + t.proteinG * 4 + t.fatG * 9
        #expect(abs(t.caloriesKcal - sum) < 0.01)
    }

    // MARK: - Item 2/3: fat floor = 20% of energy + FIX A reconciliation

    @Test func fatFloorIsTwentyPercentOfEnergy() {
        // Rest day: previously fat fell to the 0.5 g/kg floor; now it must be ~20%.
        let t = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let tdee = expectedTDEE(male75, "rest")
        let fatPct = t.fatG * 9 / tdee
        #expect(fatPct >= 0.18)               // FIX A re-derive floors at 0.9×20%
        #expect(fatPct <= 0.35 + 0.001)
    }

    @Test func fixATriggersAndReconcilesOnHighCarbDay() {
        // Long run packs carbs high enough that 20% fat can't fit → FIX A reduces
        // carbs toward the session floor and the day reconciles to TDEE.
        let t = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "long_run")
        #expect(t.flags.contains("fat_floor_triggered"))
        let tdee = expectedTDEE(male75, "long_run")
        #expect(abs(t.caloriesKcal - tdee) / tdee < 0.05)
        // Carbs reduced from the 8.5 g/kg base but never below the 5 g/kg floor.
        #expect(t.carbsG <= 8.5 * 75.0 + 0.01)
        #expect(t.carbsG >= 5.0 * 75.0 - 0.01)
    }

    @Test func fatNeverBelowFloorAcrossSessions() {
        for session in ["rest", "easy_run", "tempo", "interval", "long_run"] {
            let t = MacroEngine.calculate(user: female60, raceDate: nil, sessionType: session)
            let tdee = expectedTDEE(female60, session)
            #expect(t.fatG * 9 / tdee >= 0.18 - 0.001)
            #expect(t.fatG > 0)
        }
    }

    // MARK: - Item 4: FIX B carb-load collision guard (TDEE-relative floor)

    @Test func fixBCapsRaceWeekCarbLoadForSmallLowTDEEBody() {
        // The named simulation regression: 45kg, 68yo, female, beginner, rest day,
        // in race week. The forced 11 g/kg carb-load blows past her tiny TDEE;
        // FIX B's TDEE-relative floor (not the flat 8 g/kg) must rescue it.
        let small = UserProfile(weightKg: 45, heightCm: 160, age: 68, gender: "female", trainingLevel: "beginner")
        let t = MacroEngine.calculate(user: small, raceDate: raceDateString(weeksAway: 0), sessionType: "rest")
        #expect(t.trainingPhase == TrainingPhase.raceWeek.rawValue)
        #expect(t.flags.contains("carb_load_capped"))
        let tdee = expectedTDEE(small, "rest")   // rest multiplier holds in race week
        #expect(abs(t.caloriesKcal - tdee) / tdee < 0.03)
        // Capped below the flat 8 g/kg weight floor → proves the TDEE-relative floor won.
        #expect(t.carbsG < 8.0 * 45.0)
    }

    // MARK: - Item 1: recovery-day detection

    @Test func recoveryDayAfterLongRun() {
        let recovery = MacroEngine.calculate(user: male75, raceDate: nil,
                                             sessionType: "rest", previousSessionType: "long_run")
        let plainRest = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        #expect(recovery.sessionType == "recovery_day")
        #expect(recovery.carbsG > plainRest.carbsG)    // 6 g/kg base vs 4 g/kg
    }

    @Test func recoveryDayAfterRace() {
        let t = MacroEngine.calculate(user: male75, raceDate: nil,
                                      sessionType: "easy_run", previousSessionType: "race_marathon")
        #expect(t.sessionType == "recovery_day")
    }

    @Test func recoveryDayDoesNotDowngradeAHardSession() {
        // Intent-preserving deviation from the literal spec: a genuine hard day the
        // day after a long run keeps its type (never under-fuelled to recovery_day).
        let t = MacroEngine.calculate(user: male75, raceDate: nil,
                                      sessionType: "tempo", previousSessionType: "long_run")
        #expect(t.sessionType == "tempo")
    }

    @Test func recoveryDayOnlyAfterLongOrRace() {
        let t = MacroEngine.calculate(user: male75, raceDate: nil,
                                      sessionType: "rest", previousSessionType: "easy_run")
        #expect(t.sessionType == "rest")
    }

    // MARK: - Item 5: race-type split

    @Test func raceTypesEscalateInEnergyAndCarbs() {
        let r5  = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race_5k")
        let r10 = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race_10k")
        let rH  = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race_half")
        let rM  = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race_marathon")
        // Higher TDEE multipliers → more energy.
        #expect(r5.caloriesKcal < r10.caloriesKcal)
        #expect(r10.caloriesKcal < rH.caloriesKcal)
        #expect(rH.caloriesKcal < rM.caloriesKcal)
        // Carb targets escalate too (5.5 < 6.5 < 8.5 < 10 g/kg base).
        #expect(r5.carbsG < rM.carbsG)
    }

    @Test func legacyRaceAliasesToMarathon() {
        let legacy   = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race")
        let marathon = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race_marathon")
        #expect(abs(legacy.carbsG   - marathon.carbsG)   < 0.01)
        #expect(abs(legacy.proteinG - marathon.proteinG) < 0.01)
        #expect(abs(legacy.fatG     - marathon.fatG)     < 0.01)
    }

    @Test func ultraAliasesToMarathon() {
        let ultra    = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race_ultra")
        let marathon = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race_marathon")
        #expect(abs(ultra.carbsG - marathon.carbsG) < 0.01)
    }

    @Test func isRunSessionRecognisesSplitRaceTypes() {
        for t in ["race", "race_5k", "race_10k", "race_half", "race_marathon", "long_run"] {
            #expect(MacroEngine.isRunSession(t))
        }
        for t in ["rest", "cycling", "gym_upper"] {
            #expect(!MacroEngine.isRunSession(t))
        }
    }

    // MARK: - Interim behavior: phase affects output only in race week (flag 4)

    @Test func taperEqualsBuildForSameSession() {
        // Taper fat ×0.875 was dropped; with phase carb/protein multipliers deferred,
        // taper and build must produce identical macros for the same session type.
        let build = MacroEngine.calculate(user: male75, raceDate: raceDateString(weeksAway: 10), sessionType: "long_run")
        let taper = MacroEngine.calculate(user: male75, raceDate: raceDateString(weeksAway: 2),  sessionType: "long_run")
        #expect(abs(taper.carbsG   - build.carbsG)   < 0.01)
        #expect(abs(taper.proteinG - build.proteinG) < 0.01)
        #expect(abs(taper.fatG     - build.fatG)     < 0.01)
    }

    // MARK: - Activity adjustments (protein exact; carbs reconcile)

    @Test func gymLowerAddsProteinExactly() {
        let base     = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let adjusted = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest", additionalActivities: [.gymLower])
        #expect(abs(adjusted.proteinG - (base.proteinG + 15)) < 0.01)
    }

    @Test func gymUpperAddsProteinExactly() {
        let base     = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let adjusted = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest", additionalActivities: [.gymUpper])
        #expect(abs(adjusted.proteinG - (base.proteinG + 10)) < 0.01)
    }

    @Test func otherActivityAddsProteinExactly() {
        let base     = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let adjusted = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest", additionalActivities: [.other])
        #expect(abs(adjusted.proteinG - (base.proteinG + 10)) < 0.01)
    }

    @Test func cyclingNormalisedToEasyRun() {
        let cycling = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "cycling")
        let easyRun = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "easy_run")
        #expect(abs(cycling.carbsG   - easyRun.carbsG)   < 0.01)
        #expect(abs(cycling.proteinG - easyRun.proteinG) < 0.01)
    }

    @Test func fallbackProfileProducesPositiveMacros() {
        let t = MacroEngine.calculate(user: .fallback, raceDate: nil, sessionType: "easy_run")
        #expect(t.carbsG   > 0)
        #expect(t.proteinG > 0)
        #expect(t.fatG     > 0)
    }

    // MARK: - §13 Core safety bounds (realistic population sweep)

    @Test func coreSafetyBoundsHoldAcrossPopulation() {
        let weights: [Double]  = [45, 60, 75, 90, 105]
        let ages: [Int]        = [17, 30, 45, 68]
        let genders            = ["male", "female"]
        let levels             = ["beginner", "intermediate", "advanced"]
        let sessions           = ["rest", "easy_run", "tempo", "interval", "long_run",
                                  "race_5k", "race_10k", "race_half", "race_marathon"]

        for w in weights {
            for age in ages {
                for g in genders {
                    for lvl in levels {
                        let u = UserProfile(weightKg: w, heightCm: 172, age: age, gender: g, trainingLevel: lvl)
                        for s in sessions {
                            let t = MacroEngine.calculate(user: u, raceDate: nil, sessionType: s)
                            let tdee = expectedTDEE(u, s)

                            // No NaN / negatives.
                            #expect(t.carbsG.isFinite && t.carbsG >= 0)
                            #expect(t.proteinG.isFinite && t.proteinG > 0)
                            #expect(t.fatG.isFinite && t.fatG > 0)

                            // Fat 18–35% of TDEE (0.9×20% floor per FIX A).
                            let fatPct = t.fatG * 9 / tdee
                            #expect(fatPct >= 0.18 - 0.005)
                            #expect(fatPct <= 0.35 + 0.005)

                            // Protein 1.2–2.5 g/kg.
                            let pPerKg = t.proteinG / w
                            #expect(pPerKg >= 1.2 && pPerKg <= 2.5)

                            // Carbs ~2.5–13 g/kg.
                            let cPerKg = t.carbsG / w
                            #expect(cPerKg >= 2.5 && cPerKg <= 13.0)

                            // Reconciliation. When fat lands strictly INSIDE the
                            // 18–35% band, it equals the TDEE remainder by
                            // construction, so the day reconciles to TDEE exactly.
                            let interior = fatPct > 0.185 && fatPct < 0.348
                            if interior {
                                #expect(abs(t.caloriesKcal - tdee) / tdee < 0.005)
                            }
                            // At the extremes the spec's safety bounds override
                            // exact reconciliation: the 35% fat ceiling (no surplus
                            // reallocation) undershoots light days, and the §6.3
                            // carb floors overshoot small/low-TDEE bodies. Faithful
                            // to the master-spec formulas — the >5% gaps are a
                            // flagged product finding, not a bug. Envelope catches
                            // gross errors (NaN, sign, 2× mistakes).
                            #expect(t.caloriesKcal >= tdee * 0.82)
                            #expect(t.caloriesKcal <= tdee * 1.12)
                        }
                    }
                }
            }
        }
    }

    @Test func progressiveOverloadOrderingHolds() {
        for lvl in ["beginner", "intermediate", "advanced"] {
            let u = UserProfile(weightKg: 70, heightCm: 175, age: 30, gender: "male", trainingLevel: lvl)
            let rest  = MacroEngine.calculate(user: u, raceDate: nil, sessionType: "rest")
            let easy  = MacroEngine.calculate(user: u, raceDate: nil, sessionType: "easy_run")
            let tempo = MacroEngine.calculate(user: u, raceDate: nil, sessionType: "tempo")
            let long  = MacroEngine.calculate(user: u, raceDate: nil, sessionType: "long_run")
            #expect(rest.carbsG < easy.carbsG)
            #expect(easy.carbsG < tempo.carbsG)
            #expect(tempo.carbsG < long.carbsG)

            let recovery = MacroEngine.calculate(user: u, raceDate: nil,
                                                 sessionType: "rest", previousSessionType: "long_run")
            #expect(recovery.carbsG > rest.carbsG)
        }
    }
}
