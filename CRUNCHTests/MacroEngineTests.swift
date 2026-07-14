import Testing
import Foundation
@testable import CRUNCH

struct MacroEngineTests {

    // Shared test profiles
    let male75 = UserProfile(weightKg: 75, heightCm: 178, age: 32, gender: "male",   trainingLevel: "intermediate")
    let female60 = UserProfile(weightKg: 60, heightCm: 165, age: 28, gender: "female", trainingLevel: "beginner")

    // Race dates (relative strings resolved at test-run time — use fixed offsets)
    func raceDateString(weeksAway: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: weeksAway * 7, to: Date())!
        return formatter.string(from: date)
    }

    // MARK: - BMR / TDEE

    @Test func maleBMRRestDay() {
        // male 75kg 178cm age 32: BMR = 10*75 + 6.25*178 - 5*32 + 5 = 750+1112.5-160+5 = 1707.5
        // TDEE (rest) = 1707.5 * 1.2 = 2049.0
        let target = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let expectedBMR = 10 * 75.0 + 6.25 * 178.0 - 5 * 32.0 + 5.0
        let expectedTDEE = expectedBMR * 1.2
        // Carbs: 4 g/kg * 75 = 300g. Protein: 1.7*75 = 127.5g
        // Fat: (TDEE - 300*4 - 127.5*4) / 9, floor 0.5*75=37.5
        let expectedCarbs   = 4.0 * 75.0
        let expectedProtein = 1.7 * 75.0
        let expectedFat     = max((expectedTDEE - expectedCarbs * 4 - expectedProtein * 4) / 9, 0.5 * 75.0)
        #expect(abs(target.carbsG   - expectedCarbs)   < 0.01)
        #expect(abs(target.proteinG - expectedProtein) < 0.01)
        #expect(abs(target.fatG     - expectedFat)     < 0.01)
    }

    @Test func maleLongRunCarbs() {
        // 75kg long_run: carbs = 8.5 * 75 = 637.5g
        let target = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "long_run")
        #expect(abs(target.carbsG - 637.5) < 0.01)
        #expect(abs(target.proteinG - 127.5) < 0.01)
    }

    @Test func femaleBMR() {
        // female 60kg 165cm age 28: BMR = 10*60 + 6.25*165 - 5*28 - 161 = 600+1031.25-140-161 = 1330.25
        let target = MacroEngine.calculate(user: female60, raceDate: nil, sessionType: "rest")
        let expectedBMR     = 10 * 60.0 + 6.25 * 165.0 - 5 * 28.0 - 161.0
        let expectedCarbs   = 4.0 * 60.0
        let expectedProtein = 1.7 * 60.0
        let expectedTDEE    = expectedBMR * 1.2
        let expectedFat     = max((expectedTDEE - expectedCarbs * 4 - expectedProtein * 4) / 9, 0.5 * 60.0)
        #expect(abs(target.carbsG   - expectedCarbs)   < 0.01)
        #expect(abs(target.fatG     - expectedFat)     < 0.01)
    }

    // MARK: - Training Phase

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

    // MARK: - Special Protocols

    @Test func raceWeekCarbLoad() {
        // 0 weeks to race → 11 g/kg
        let target = MacroEngine.calculate(user: male75, raceDate: raceDateString(weeksAway: 0), sessionType: "rest")
        #expect(abs(target.carbsG - 11.0 * 75.0) < 0.01)
        #expect(target.trainingPhase == TrainingPhase.raceWeek.rawValue)
    }

    @Test func taperFatReduction() {
        // Taper: fat reduced to 87.5% of base calculation
        let base   = MacroEngine.calculate(user: male75, raceDate: raceDateString(weeksAway: 10), sessionType: "long_run")
        let taper  = MacroEngine.calculate(user: male75, raceDate: raceDateString(weeksAway: 2),  sessionType: "long_run")
        // Carbs should be the same (8.5 g/kg for long_run regardless of phase, unless race week)
        #expect(abs(taper.carbsG - base.carbsG) < 0.01)
        // Fat in taper should be ≤ fat in base
        #expect(taper.fatG <= base.fatG + 0.01)
    }

    @Test func fatFloor() {
        // Extreme case: very high carbs → fat could go negative without floor
        // 75kg race: carbs=750g (10g/kg), protein=127.5g → calories=750*4+127.5*4=3510
        // TDEE(race)=1707.5*1.9=3244.25 → fat=(3244.25-3510)/9 < 0 → floor = 0.5*75=37.5
        let target = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "race")
        #expect(target.fatG >= 0.5 * 75.0 - 0.01)
    }

    @Test func fallbackProfile() {
        // Fallback: 70kg male 175cm age 30 — must not crash
        let target = MacroEngine.calculate(user: .fallback, raceDate: nil, sessionType: "easy_run")
        #expect(target.carbsG   > 0)
        #expect(target.proteinG > 0)
        #expect(target.fatG     > 0)
    }

    // MARK: - Activity Adjustments

    @Test func gymLowerAdjustment() {
        let base     = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let adjusted = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest", additionalActivities: [.gymLower])
        #expect(abs(adjusted.carbsG   - (base.carbsG   + 30)) < 0.01)
        #expect(abs(adjusted.proteinG - (base.proteinG + 15)) < 0.01)
    }

    @Test func gymUpperAdjustment() {
        let base     = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let adjusted = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest", additionalActivities: [.gymUpper])
        #expect(abs(adjusted.carbsG   - base.carbsG)          < 0.01)  // no carb change
        #expect(abs(adjusted.proteinG - (base.proteinG + 10)) < 0.01)
    }

    @Test func gymFullAdjustment() {
        let base     = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let adjusted = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest", additionalActivities: [.gymFull])
        #expect(abs(adjusted.carbsG   - (base.carbsG   + 20)) < 0.01)
        #expect(abs(adjusted.proteinG - (base.proteinG + 15)) < 0.01)
    }

    @Test func otherActivityAdjustment() {
        let base     = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest")
        let adjusted = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "rest", additionalActivities: [.other])
        #expect(abs(adjusted.carbsG   - (base.carbsG   + 15)) < 0.01)
        #expect(abs(adjusted.proteinG - (base.proteinG + 10)) < 0.01)
    }

    @Test func cyclingNormalisedToEasyRun() {
        // Cycling as primary session → same as easy_run
        let cycling  = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "cycling")
        let easyRun  = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "easy_run")
        #expect(abs(cycling.carbsG   - easyRun.carbsG)   < 0.01)
        #expect(abs(cycling.proteinG - easyRun.proteinG) < 0.01)
    }

    @Test func caloriesAreConsistent() {
        let target = MacroEngine.calculate(user: male75, raceDate: nil, sessionType: "long_run")
        let expected = target.carbsG * 4 + target.proteinG * 4 + target.fatG * 9
        #expect(abs(target.caloriesKcal - expected) < 0.01)
    }
}
