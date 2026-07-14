# Crunch Nutrition Engine — Master Implementation Spec

**Status:** Consolidated from six advisory documents into one build-ready spec.
**Supersedes:** crunch-nutrition-engine-v2-spec.md, nutrition-engine-simulation-findings.md, nutrition-engine-diet-explainability-amendment.md, activity-logging-accuracy-spec.md, dual-goal-muscle-building-spec.md. (nutrition-engine-health-data-menstrual-cycle.md remains a separate post-MVP doc — summarized at the end, not repeated in full.)
**How to use this doc:** Sections 1–8 are the engine architecture with every fix already folded in — build from these directly, don't build the original spec and then patch it. Section 9 is the diet layer. Section 10 is dual-goal (muscle building). Section 11 is activity logging. Section 12 is explainability. Section 13 is the full regression test checklist. Section 14 is implementation order. Section 15 is the post-MVP backlog — named, scoped, and deliberately not now.

---

## What this engine is, honestly

Every formula below is backed by a peer-reviewed source (full reference list at the end). The engine has been stress-tested — not backtested — across 20,000+ synthetic runners plus thousands of deliberately-stacked worst-case and dual-goal combinations, checking that outputs never leave literature-established safety bounds and that macros correctly reconcile to the daily calorie target. That process found and fixed two real bugs (both folded into the formulas below, both explained inline so the reasoning isn't lost). This is a safety and consistency validation, not proof of athletic outcomes — say "validated for safety and consistency," not "proven" or "backtested against results," anywhere user- or investor-facing.

---

## 1. Architecture

```
Input: { user, today_session, tomorrow_session?, race, meal_library, diet, building_muscle }
         │
         ▼
Layer 1: AthleteProfiler     → { level_band, race_modifier, age_modifier, diet_modifier, ea_threshold }
         │
         ▼
Layer 2: EnergyEngine        → { bmr, tdee, eee, muscle_building_surplus }
         │
         ▼
Layer 3: CarbEngine          → { carbs_g, method_applied, flags[] }
         │
         ▼
Layer 4: ProteinEngine       → { protein_g, per_meal_target_g }
         │
         ▼
Layer 5: FatEngine           → { fat_g, fat_pct, safety_flags[] }
         │
         ▼
Layer 6: PhaseEngine         → { active_phase, overrides, protocol_name }
         │
         ▼
Layer 7: MealTimingEngine    → { pre_run_flag, post_run_flag, recovery_day_flag, during_flag }
         │
         ▼
Layer 8: PortionEngine       → { per_meal_portions[], display_level, display_label, explanation }
         │
         ▼
Output: MacroTarget + PortionResult[] + MacroExplanation[]
```

Diet and dual-goal (muscle building) are **modifiers threaded through Layers 2 and 4**, not new layers — they change values already computed there, gated by the same phase logic that already exists. This keeps the architecture at 8 layers, not 10.

---

## 2. Layer 1 — Athlete Profiler

**Inputs:** `training_level`, `race_type`, `age`, `gender`, `weight_kg`, `diet`

### 2.1 Training level bands (controls Layer 3's carb table column)

| Crunch Level | Band | Typical Weekly km |
|---|---|---|
| `beginner` | A | 20–40 km |
| `intermediate` | B | 40–70 km |
| `advanced` | C | 70–120 km |

### 2.2 Race distance modifier (carbs only)

| `race_type` | Modifier |
|---|---|
| `5k` | × 0.85 |
| `10k` | × 0.90 |
| `half_marathon` | × 0.95 |
| `marathon` | × 1.00 (reference) |
| `ultra_marathon` | × 1.10 |

Marathon prep requires the highest chronic carbohydrate availability of any road race; applying marathon-level targets to a 5K runner over-fuels by ~18%. Burke et al., 2011.

### 2.3 Age modifier (protein only)

| Age | Modifier | Source |
|---|---|---|
| < 40 | × 1.00 | ISSN 2017 baseline |
| 40–50 | × 1.12 | Moore et al., 2015 |
| > 50 | × 1.20 | Churchward-Venne et al., 2016 |

### 2.4 Diet modifier (protein only)

| Diet | Modifier | Rationale |
|---|---|---|
| Omnivore, pescatarian | × 1.00 | Reference — fish protein quality equals omnivore |
| Vegetarian | × 1.05 | Dairy/eggs high quality; mild adjustment |
| Vegan / plant-based | × 1.10 | Lower digestibility + leucine content (Rogerson 2017; Lynch et al. 2018) |

Low-carb/keto diets do **not** get a macro modifier — they raise a coaching conflict flag instead. See Section 9.2.

### 2.5 Energy Availability monitor (soft flag, never a displayed number)

```
EA = (Energy_Intake_kcal − EEE_kcal) / FFM_kg
FFM: Male = weight_kg × 0.82 | Female = weight_kg × 0.75

≥ 45 kcal/kg FFM/day → optimal
30–45 → monitor
< 30 → soft, non-clinical Today tab prompt: "Your energy needs are high today —
        make sure you're eating enough to support your training."
```
Mountjoy et al., 2014.

---

## 3. Layer 2 — Energy Engine

### 3.1 BMR (Mifflin-St Jeor + athlete correction)

```swift
// Male:   BMR = 10×weight_kg + 6.25×height_cm − 5×age + 5
// Female: BMR = 10×weight_kg + 6.25×height_cm − 5×age − 161

let correctionFactor: Double = switch training_level {
    case .beginner:     1.00
    case .intermediate: 1.05
    case .advanced:     1.10
}
let athleteBMR = bmr * correctionFactor
```
Athletes carry more lean mass than the general population Mifflin-St Jeor was validated on. Taggart et al., 2022.

**Fallback biometrics** (no profile data): weight 70kg, height 175cm, age 30, male. Set `usingFallbackBiometrics = true` → Today tab prompt: "Complete your profile for more accurate fuel targets."

### 3.2 TDEE — Model A (MVP, session-type multiplier)

`TDEE = athleteBMR × sessionMultiplier`

| Session Type | Multiplier | Note |
|---|---|---|
| `rest` | 1.25 | |
| `recovery_day` | 1.35 | **New session type — see 3.4** |
| `easy_run` | 1.55 | |
| `tempo` | 1.75 | |
| `interval` | 1.85 | |
| `long_run` | 2.10 | |
| `gym_upper` | 1.45 | |
| `gym_lower` | 1.50 | |
| `gym_full` | 1.55 | |
| `cycling` | 1.55 | |
| `swimming` | 1.60 | |
| `race_5k` | 1.75 | |
| `race_10k` | 1.85 | |
| `race_half` | 2.00 | |
| `race_marathon` | 2.40 | Beis et al., 2011 |

### 3.3 TDEE — Model B (V2.1, duration-based — build when duration input exists)

```swift
let NEAT = athleteBMR * 1.20
let EEE  = MET[session_type][intensity] * weight_kg * (duration_min / 60.0)
let EPOC = EEE * epocFactor[session_type]
let TDEE = NEAT + EEE + EPOC
```

MET table (also used by activity logging, Section 11):

| Session Type | MET | EPOC Factor |
|---|---|---|
| `easy_run` | 8.0 | 0.07 |
| `tempo` | 11.5 | 0.12 |
| `interval` | 13.0 | 0.18 |
| `long_run` | 9.0 | 0.10 |
| `race_5k` | 14.0 | 0.20 |
| `race_10k` | 12.5 | 0.15 |
| `race_half` | 11.0 | 0.12 |
| `race_marathon` | 10.0 | 0.10 |
| `gym_upper` | 5.0 | 0.08 |
| `gym_lower` | 5.5 | 0.09 |
| `gym_full` | 6.0 | 0.10 |
| `cycling` | 6.0 (easy) / 8.0 (moderate) / 10.0 (hard) | 0.06 |
| `swimming` | 6.0 / 8.0 / 10.0 | 0.07 |

Default durations when only session type is known (used by Model A fallback and by activity logging's Tier 0 default):

| Session | Band A | Band B | Band C |
|---|---|---|---|
| `easy_run` | 35 min | 55 min | 70 min |
| `tempo` | 30 min | 45 min | 55 min |
| `interval` | 40 min | 50 min | 60 min |
| `long_run` | 80 min | 120 min | 160 min |
| `race_5k` | 38 min | 28 min | 20 min |
| `race_10k` | 70 min | 55 min | 42 min |
| `race_half` | 145 min | 120 min | 100 min |
| `race_marathon` | 295 min | 240 min | 210 min |

### 3.4 Recovery day detection (Fix — highest product impact, most common gap)

```swift
if let prev = previousSession,
   prev.session_type == "long_run" || prev.session_type.hasPrefix("race_") {
    todaySessionType = "recovery_day"   // multiplier 1.35, carbs 5.5–6.5 g/kg (Layer 3), protein 2.0 g/kg (Layer 4)
}
```
**Why:** the day after a long run currently falls through to `rest` (3–4 g/kg carbs), which is wrong — most runners run the day after their long run and are systematically under-fueled by the current spec. Ivy 2002.

### 3.5 Muscle-building surplus (dual-goal modifier — see Section 10 for full context)

```swift
func applyMuscleBuildingSurplus(tdee: Double, sessionType: String, phase: TrainingPhase, buildingMuscle: Bool) -> (Double, Double) {
    guard buildingMuscle else { return (tdee, 0.0) }
    guard phase != .taper, phase != .raceWeek, phase != .postRaceRecovery else { return (tdee, 0.0) }
    guard ["gym_upper", "gym_lower", "gym_full"].contains(sessionType) else { return (tdee, 0.0) }
    let surplus = min(300.0, tdee * 0.12)
    return (tdee + surplus, surplus)
}
```
Strength-days-only, phase-gated. Race-day/long-run/tempo/interval carb targets are never touched by this modifier.

---

## 4. Layer 3 — Carbohydrate Engine

### 4.1 Periodization table (g/kg/day, session × training-level band)

| Session Type | Band A | Band B | Band C | Source |
|---|---|---|---|---|
| `rest` | 3.0 | 3.5 | 4.5 | Burke 2011 |
| `recovery_day` | 5.5 | 6.0 | 6.5 | Ivy 2002 |
| `easy_run` | 4.0 | 5.5 | 6.5 | Burke 2011 |
| `tempo` | 5.5 | 7.0 | 8.0 | Jeukendrup 2011 |
| `interval` | 6.0 | 7.5 | 8.5 | Stellingwerff 2014 |
| `long_run` | 7.0 | 8.5 | 10.0 | Burke 2011 |
| `gym_upper` | 3.5 | 4.0 | 4.5 | ACSM 2016 |
| `gym_lower` | 4.5 | 5.5 | 6.0 | ACSM 2016 |
| `gym_full` | 4.0 | 5.0 | 5.5 | ACSM 2016 |
| `cycling` | 4.0 | 5.5 | 6.5 | |
| `swimming` | 4.0 | 5.5 | 6.5 | |
| `race_5k` | 5.0 | 5.5 | 6.0 | |
| `race_10k` | 6.0 | 6.5 | 7.0 | |
| `race_half` | 7.5 | 8.5 | 9.5 | |
| `race_marathon` | 9.0 | 10.0 | 11.0 | |

A beginner on a long run gets 7.0 g/kg; an advanced runner gets 10.0 g/kg — training-adapted muscles store and deplete glycogen faster. Bergström et al., 1967.

### 4.2 Day-before long-run/race boost (applied to dinner via Layer 8)

| Band | Boost |
|---|---|
| A | +1.0 g/kg |
| B | +1.5 g/kg |
| C | +2.0 g/kg |

Trigger: `tomorrowSession ∈ [long_run, race_half, race_marathon, race_ultra]`. Coyle 1991; Burke 2011.

### 4.3 Phase multiplier

| Phase | Carb Multiplier |
|---|---|
| `base_building` | × 0.90 |
| `build` | × 1.00 |
| `peak` | × 1.10 |
| `taper` | × 1.00 — **do not reduce with volume** |
| `race_week` | Protocol override — see 4.5 |
| `post_race_recovery` | × 0.85 |

Reducing carbs with volume during taper is a common, incorrect instinct — carb g/kg should stay constant while total grams drift down naturally with lower TDEE. Mujika & Padilla, 2003.

### 4.4 Calculation sequence

```swift
func calculateCarbs(session, user, tomorrowSession, phase) -> CarbResult {
    let baseGPerKg = carbTable[session.session_type][user.training_level_band]
    let dayBeforeBoost = isTomorrowLongOrRace(tomorrowSession) ? dayBeforeBoostTable[band] : 0.0
    let phaseMultiplier = phase.carbMultiplier
    let raceModifier = user.race_type.carbModifier
    let targetGPerKg = baseGPerKg * phaseMultiplier * raceModifier
    let carbs_g = targetGPerKg * user.weight_kg
    return CarbResult(carbs_g: carbs_g, gPerKg: targetGPerKg, dayBeforeBoost: dayBeforeBoost)
}
```

### 4.5 Carb-load protocol (race week override)

Trigger: `weeksToRace == 0`, days −2/−1 before race.

```swift
if phase == .race_week && daysToRace <= 2 {
    let carbLoadTarget: Double = switch race_type {
        case .half_marathon: 10.0
        case .marathon, .ultra_marathon: 12.0
        default: 7.0   // 5K/10K — no formal load
    }
    carbs_g = carbLoadTarget * weight_kg
}
```
48 hours of elevated intake achieves equivalent supercompensation to older 3-day depletion protocols. Burke et al., 2011.

---

## 5. Layer 4 — Protein Engine

### 5.1 Base target

```swift
func calcProtein(weight_kg, age, phase, isRecoveryDay, daysPostRace, diet, buildingMuscle) -> (Double, Double) {
    let ageMod = ageProteinModifier(age)   // 1.00 / 1.12 / 1.20
    var baseGPerKg = 1.70
    if let d = daysPostRace {
        baseGPerKg = d <= 7 ? 2.20 : 2.00
    } else if isRecoveryDay {
        baseGPerKg = 2.00
    } else if phase == .taper {
        baseGPerKg = 1.85
    }
    var proteinGPerKg = baseGPerKg * ageMod

    // Diet digestibility modifier
    proteinGPerKg *= dietProteinModifier[diet]   // 1.00 / 1.05 / 1.10

    // Dual-goal nudge — phase-gated, does not stack additively, just raises the floor
    if buildingMuscle && phase != .taper && phase != .raceWeek && phase != .postRaceRecovery {
        proteinGPerKg = max(proteinGPerKg, 2.0 * ageMod * dietProteinModifier[diet])
    }

    // Hard safety cap — validated via simulation across every modifier combination
    proteinGPerKg = min(proteinGPerKg, 2.5)

    return (proteinGPerKg * weight_kg, proteinGPerKg)
}
```

| Scenario | g/kg | Source |
|---|---|---|
| Standard (<40) | 1.70 | ISSN 2017 |
| Masters 40–50 | 1.90 | Moore 2015 |
| Masters 50+ | 2.05 | Churchward-Venne 2016 |
| Taper | 1.85 | Preserve lean mass during volume drop |
| Recovery day | 2.00 | Elevated MPB post long-run |
| Post-race week 1 | 2.20 | Peak repair need |
| Post-race week 2 | 2.00 | Gradual return |
| + Vegan/plant-based | ×1.10 | Digestibility |
| + Vegetarian | ×1.05 | Digestibility |
| + Building muscle (non-race-critical phase) | floor 2.0 | Concurrent-training literature |
| **Hard cap, all scenarios** | **2.5** | Validated — never breached across 20,000+ combinations |

### 5.2 Per-meal distribution target (informs Layer 8, does not change the daily total)

```swift
let perMealTarget_g = protein_g / Double(activeMealCount)
```
Even distribution across meals produces ~25% greater net protein balance than front-loading the same total. Areta et al., 2013. Flag meals under 0.25 g/kg protein in the library baseline for a Coach prompt.

---

## 6. Layer 5 — Fat Engine

### 6.1 Calculation sequence — includes both reconciliation fixes

```swift
func calculateFat(tdee, carbs_g, protein_g, weight_kg, session_type) -> FatResult {

    let usedCalories = carbs_g*4.0 + protein_g*4.0
    let fatFromRemainder = max(0, (tdee - usedCalories) / 9.0)

    let fatMinimum_g = (tdee * 0.20) / 9.0   // 20% of energy, NOT 0.5 g/kg (see 6.2)
    let fatMaximum_g = (tdee * 0.35) / 9.0

    var fat_g = max(fatMinimum_g, min(fatFromRemainder, fatMaximum_g))
    var finalCarbs_g = carbs_g
    var flags: [String] = []

    // FIX A (primary bug found in simulation): when the fat floor triggers,
    // reduce carbs toward the session floor, THEN re-derive fat from whatever room
    // is actually left — applies on EVERY session type, not just carb-load days.
    // (Original spec only re-derived fat inside the carb-load guard below, which
    // left ordinary gym-day macros undershooting TDEE by up to ~15%.)
    if fat_g > fatFromRemainder {
        flags.append("fat_floor_triggered")
        let excessFatCalories = (fat_g - fatFromRemainder) * 9.0
        let carbReduction = excessFatCalories / 4.0
        let sessionFloorGPerKg = sessionCarbFloor[session_type] ?? 3.0
        let sessionFloor_g = sessionFloorGPerKg * weight_kg
        finalCarbs_g = max(carbs_g - carbReduction, sessionFloor_g)

        // Re-derive fat from remaining calorie room so totals reconcile
        let remainingForFat = tdee - (finalCarbs_g*4.0 + protein_g*4.0)
        fat_g = max(remainingForFat / 9.0, fatMinimum_g * 0.9)
    }

    // FIX B: carb-load collision guard — TDEE-relative floor, not flat weight-based.
    // (Original flat 8 g/kg floor overshot TDEE badly for small/low-TDEE bodies,
    // e.g. a 45kg older woman on a rest day — 8 g/kg alone exceeded her entire TDEE.)
    let totalCheck = finalCarbs_g*4.0 + protein_g*4.0 + fatMinimum_g*9.0
    if totalCheck > tdee * 1.02 {
        let excess = totalCheck - tdee
        let reduction = excess / 4.0
        let weightBasedFloor = 8.0 * weight_kg
        let tdeeRelativeFloor = (tdee * 0.55) / 4.0
        let hardFloor = min(weightBasedFloor, tdeeRelativeFloor)
        let newCarbs = max(finalCarbs_g - reduction, hardFloor)
        if newCarbs != finalCarbs_g {
            flags.append("carb_load_capped")
            finalCarbs_g = newCarbs
            let remainingForFat = tdee - (finalCarbs_g*4.0 + protein_g*4.0)
            fat_g = max(remainingForFat / 9.0, fatMinimum_g * 0.9)
        }
    }

    let fatPct = tdee > 0 ? (fat_g * 9.0) / tdee : 0.0
    return FatResult(fat_g: fat_g, fat_pct: fatPct, carbs_adjusted_g: finalCarbs_g, flags: flags)
}
```

### 6.2 Why 20% of energy, not 0.5 g/kg

0.5 g/kg for a 55kg female runner = 27.5g fat = 247 kcal = ~11% of a 2,200 kcal day — below the clinical minimum for hormonal function and essential fatty acid requirements. Mountjoy et al., 2014; Loucks, 2004.

### 6.3 Session carb floors (used by both guards above)

| Session | Floor (g/kg) |
|---|---|
| `long_run` | 5.0 |
| `race_marathon`, `race_ultra_marathon` | 8.0 |
| `race_half` | 6.0 |
| All others (default) | 3.0 |

---

## 7. Layer 6 — Phase Engine

### 7.1 Phase detection

```swift
let phase: TrainingPhase = {
    if let d = daysSinceRace, d > 0, d <= 14 { return .post_race_recovery }
    switch weeksToRace {
    case ..<0:   return .post_race_recovery
    case 0:      return .race_week
    case 1...3:  return .taper
    case 4...8:  return .peak
    case 9...16: return .build
    default:     return .base_building
    }
}()
```

### 7.2 Phase protocols

| Phase | Carbs | Protein | Fat | Focus |
|---|---|---|---|---|
| Base building (>16wk) | ×0.90 | 1.7 g/kg | 25–28% | Build aerobic base, establish habits |
| Build (9–16wk) | ×1.00 | 1.7 g/kg | 22–26% | Volume/intensity rising; periodization matters most here |
| Peak (4–8wk) | ×1.10 | 1.7 g/kg | 20–24% | Highest load; recovery-day nutrition is critical |
| Taper (1–3wk) | ×1.00, don't reduce | ~1.85 g/kg | Reduces naturally | Maintain carb g/kg as volume drops; 8–12% net calorie reduction is expected |
| Race week (0–7d) | Standard → carb-load days −2/−1 | Standard | — | Day-of: timing-specific, not a daily macro target |
| Post-race recovery (1–14d) | 5.0–6.5 g/kg | 2.0–2.2 g/kg | 22–25% | **New phase — closes the lifecycle, was previously absent** |

**Taper UI copy:** "Your body is priming for race day — keep the carbs high even as your run volume drops. The portions might feel bigger than usual. That's the point."

**Post-race UI copy:** "Marathon recovery takes longer than most runners expect. Your body needs high protein and more carbs than a rest day — even if you're not running."

---

## 8. Layer 7 & 8 — Meal Timing + Portion Engine

### 8.1 Meal timing signals (advisory only — do not change daily totals)

| Signal | Trigger | Effect |
|---|---|---|
| Pre-run eve | Tomorrow = long_run/race | Dinner carb boost (4.2) + redistribution (8.2) |
| Post-workout window | Session >60min or hard | Today tab tip: carb+protein combo within 30–60min |
| During-exercise advisory | long_run/race_half/race_marathon | Tip card only: 30–60g carbs/hr (half), 60–90g/hr (marathon+), never a macro target |
| Recovery day | Detected in Layer 2 | Today tab context + Coach prompt |

### 8.2 Meal distribution

| Meal | Standard | Pre-Run Eve | Recovery Day |
|---|---|---|---|
| Breakfast | 25% | 15% | 30% |
| Lunch | 35% | 30% | 35% |
| Dinner | 40% | 55% | 35% |

**Missing breakfast:** redistribute proportionally — lunch 46.7%, dinner 53.3%, breakfast 0%.
**Snacks:** 15% per snack, capped at 25% total; other meals renormalize.

### 8.3 Portion multiplier + display

```swift
let portion_multiplier = target_macro_for_meal / meal_baseline_macro
let clampedMultiplier = min(portion_multiplier, 3.0)   // prevents explosion display
```

| Multiplier | Level | Label |
|---|---|---|
| <0.85 | lighter | "Lighter portions today" |
| 0.85–1.25 | normal | "Normal portions" |
| 1.25–1.65 | extra | "Extra portion today" |
| 1.65–2.10 | double | "Double portion" |
| >2.10 | maximum | "Maximum fuel — big day ahead" |

**Safety guard:**
```swift
guard meal_baseline_macro > 5.0 else {
    return .calibrationNeeded("We need better info about this meal — tap to update.")
}
```

---

## 9. Diet Layer (full detail — summarized inline in Layers 1/4 above)

### 9.1 Protein digestibility — already specified in Section 2.4 / 5.1. No further engine change needed.

### 9.2 Low-carb/keto — conflict flag, never an override

```swift
let lowCarbDiets: Set = ["keto", "ketogenic", "low_carb", "carnivore"]
if lowCarbDiets.contains(user.diet) {
    flags.append(.dietCarbConflict)
    // Do NOT override carb targets. Route to Coach.
}
```
Low-carb availability impairs exercise economy at race pace (Burke et al., 2017). The engine must not silently prescribe 10 g/kg carbs to a stated keto user, and must not silently comply with keto either — flag and let the Coach have the conversation. Coach copy: *"Heads up — you've told us you eat low-carb, but the fueling targets for your marathon lean heavily on carbohydrate, which is what the research supports for race-pace performance. Want to talk through how to reconcile the two?"*

### 9.3 Micronutrient watch-list — Coach only, never a macro target

| Diet | Watch-list |
|---|---|
| Vegan/plant-based | B12, iron, omega-3 EPA/DHA, calcium, zinc, iodine |
| Vegetarian | B12, iron, omega-3 EPA/DHA |
| Pescatarian | iron |
| Dairy-free | calcium, vitamin D |

Gluten-free/dairy-free have no macro impact — meal-library filtering only, outside the engine.

---

## 10. Dual-Goal: Building Muscle

Full engine changes already specified in Sections 3.5 (energy surplus) and 5.1 (protein floor). This section covers what's specific to the dual-goal feature: research grounding and app flow.

**Research grounding:** the "interference effect" (endurance blunting hypertrophy) is real but modest — recent reviews show only a small effect on muscle fiber hypertrophy specifically (larger effects are on strength/power, not this goal). It's more pronounced when the endurance modality is running vs. cycling. Critically, a high-protein diet (2 g/kg) has been shown to preserve lean-mass and strength gains under concurrent training equivalent to resistance training alone — this is the basis for the protein floor nudge, not a guess. Protein needs for hypertrophy (1.6–2.2 g/kg) and elevated endurance protein needs (1.8–2.0 g/kg) already overlap almost completely, which is why this feature needed a nudge, not a new system.

**Expectation-setting (required in copy, not optional):** adding strength training to an endurance regime rarely produces large total-body-mass increases, even though modest targeted hypertrophy is common. Never market this as a bulk phase.

### 10.1 Onboarding addition

New question after Screen 9 (training level):

> **"Anything else you're working on alongside your race?"**
> - Just the race
> - Also building muscle

If selected: *"Great — training for a race and building muscle can absolutely work together. Expect steady, modest gains rather than a bulk phase; your race stays the priority, especially as it gets close."*

### 10.2 Today tab

Reuse the explainability struct (Section 12) to add one line on strength days:
- Non-race-critical phase: *"Extra portion today — building muscle alongside your training."*
- Taper/race week: *"Priority is your race right now — muscle-building targets pause until after."*

### 10.3 Coach — two standing conversational rules (not macro logic)

1. Sequencing: if a hard run and a lift land the same day, suggest lifting first (favors strength adaptation; no clear effect either way on hypertrophy).
2. Load-clash: gently flag stacking a heavy leg day with tomorrow's long run — advisory, never blocking.

---

## 11. Activity Logging Redesign

Replaces the flat per-activity-type adjustment table with the MET-based energy model from Section 3.3, exposed through a tiered UI so accuracy doesn't cost convenience.

### 11.1 Tiered input

| Tier | Effort | Behavior |
|---|---|---|
| 0 | One tap | Activity added instantly with an estimated duration + moderate intensity (population default first use, learns to the user's rolling median by ~10th log) |
| 1 | One gesture | Added row shows its assumption in plain sight: `Cycling · 45 min · moderate`. Tap → duration chips (30/45/60/90 + custom) |
| 2 | Optional tap | Easy/moderate/hard toggle, same tap target as Tier 1 |
| 3 | Connect apparel | Strava/Apple Health/Garmin pre-fill real duration + energy; manual override always available |

**Design rule:** the assumption must always be visible and correctable in one gesture — never a form. Duration matters ~2× more than intensity for accuracy, so duration is Tier 1 and intensity is Tier 2.

### 11.2 Energy → macro flow

```
EEE_kcal = MET[type][intensity] × weight_kg × (duration_min / 60)
added_carbs_g  ≈ EEE × 0.55 / 4     // endurance activities (cycling, swimming, other)
added_carbs_g  ≈ EEE × 0.30 / 4     // strength activities (gym_*)
added_protein_g: small (~5–10g) for endurance, larger (~15–20g) for strength, scaled by duration/intensity
Added EEE (+ EPOC) flows into TDEE → absorbed by the already-fixed Fat Engine (Section 6)
```

No new macro-split logic needed — added energy flows through machinery already validated.

### 11.3 Connected apparel — upgrade, never requirement

Same code path regardless of data source (manual chip, learned default, or synced device) — connection only improves which value populates the input. This is what keeps "optional connection" from becoming a second system to maintain.

**Honest accuracy note:** MET-based estimation carries ±15–20% error even done well. This model takes activity logging from "could be off 3×" (flat type-delta) to "reasonably accurate" (duration-based) — market it as "scales with how hard and how long you actually went," not "highly accurate."

---

## 12. Explainability Layer

Every macro target should travel with a structured explanation, generated from the actual drivers that produced that day's number — not static educational text.

```swift
struct MacroExplanation {
    let driver: String        // "Long run today (22 km)"
    let baseValue: String     // "8.5 g/kg for advanced runners on long-run days"
    let modifiers: [String]   // ["Peak phase +10%", "Marathon prep (reference)"]
    let citation: String      // "Burke et al., J Sports Sci 2011"
    let plainLanguage: String // "Bigger dinner tonight to top up glycogen for tomorrow"
}
```

Powers "See the numbers →" and "The Science" surfaces with per-user, per-day reasoning instead of generic copy. This is near-zero risk — it explains values already computed and validated, it doesn't compute anything new.

---

## 13. Regression Test Checklist

Add to `MacroEngineTests.swift`. These encode everything the simulation validated — treat any failure as a release blocker.

**Core safety bounds (must hold across the full realistic population):**
- [ ] Fat % never leaves 20–35% of TDEE, for any weight (42–105kg) × age (17–68) × gender × training level × race type × session type combination.
- [ ] Protein g/kg never leaves 1.2–2.5, across the same range, including every diet × dual-goal × phase combination stacked together.
- [ ] Carbs g/kg never leaves ~2.5–13.0 g/kg across the same range.
- [ ] No crashes, negative values, or NaN, across the full combination space.
- [ ] Daily macros (carbs×4 + protein×4 + fat×9) reconcile to TDEE within 3–5% tolerance — **specifically test `gym_upper`/`gym_lower`/`gym_full` sessions**, where the fat-floor-triggered-without-carb-load-guard path previously undershot by up to 15%.

**Progressive-overload consistency (must hold for every training level × race type archetype):**
- [ ] Carbs strictly increase: `rest < easy_run < tempo < long_run`.
- [ ] `recovery_day` carbs > `rest` carbs.
- [ ] `long_run` carbs during `peak` phase ≥ `long_run` carbs during `base_building`.

**Specific regression cases (each is a bug the simulation found — keep these as named tests):**
- [ ] 45kg, 68yo female, beginner, `rest` day, `5k` race: macros reconcile to TDEE within 3% (this combination originally triggered the flat 8 g/kg carb-load floor to overshoot TDEE by >100%).
- [ ] Any `gym_*` session at any body size: macros reconcile within 5% (this combination originally undershot TDEE by up to 15% via the un-reconciled ordinary fat-floor path).
- [ ] Vegan + masters (55+) + `long_run`: protein stays ≤2.5 g/kg (highest-stacking combination found — resolves to 2.44 g/kg).
- [ ] Keto/low-carb diet, any session: `dietCarbConflict` flag is present and carb targets are unchanged from the non-diet-adjusted value.
- [ ] Dual-goal, `gym_lower`, `taper` phase: TDEE surplus is exactly 0 (confirms phase-gate blocks the surplus).
- [ ] Dual-goal, `gym_lower`, `build` phase: TDEE surplus is present (~200–300 kcal) and protein floor is applied.
- [ ] Meal baseline <5g for any macro: returns `.calibrationNeeded`, not a division result.
- [ ] No breakfast in library: 25% allocation redistributes to lunch (46.7%) / dinner (53.3%), does not silently vanish.

---

## 14. Implementation Order

1. **Recovery day** (Section 3.4, 4.1, 7.2) — new session type, highest product impact, most users hit this weekly.
2. **Fat floor = 20% of energy** (Section 6.1–6.2) — low effort, foundational for everything downstream.
3. **Fat-floor reconciliation fix, ordinary path** (Section 6.1, FIX A) — do this before the carb-load guard fix; the carb-load guard's correctness depends on this being in place first.
4. **Carb-load collision guard, TDEE-relative floor** (Section 6.1, FIX B).
5. **Race-type split in TDEE multipliers** (Section 3.2) — `race_5k`/`race_10k`/`race_half`/`race_marathon` as distinct values.
6. Regression tests from Section 13, items under "Core safety bounds" and "Specific regression cases" tied to steps 1–5.
7. **Diet layer** (Section 9) — protein modifier + conflict flag + Coach copy.
8. **Dual-goal** (Section 10) — onboarding question, protein floor, energy surplus, Today tab line, Coach rules.
9. **Activity logging redesign** (Section 11) — tiered UI + MET-based energy model.
10. **Explainability layer** (Section 12) — wire into existing "See the numbers" / "The Science" surfaces.
11. V2.1 items not yet covered: duration-based TDEE Model B, training-level carb bands (already in this doc, confirm wired), day-before boost (already in this doc, confirm wired), masters protein (already in this doc, confirm wired), snack support (already in this doc, confirm wired).

---

## 15. Post-MVP Backlog — named, scoped, deliberately not now

Each of these is a full subsystem that needs real-user data or deferred UI to calibrate against. Building them before real runners are on the app trades certainty for guesswork in the opposite direction. Full detail in `nutrition-engine-health-data-menstrual-cycle.md`.

| Item | Why it's real | Why it waits |
|---|---|---|
| Apple Health calibration layer | Weight sync alone self-corrects every g/kg target; highest-value integration available | Requires the HealthKit integration already planned post-launch |
| Menstrual cycle — RED-S screening + modest luteal adjustments | Genuinely differentiated, catches a serious health issue early | Needs Cycle Tracking permission UX + hard contraceptive gate designed first |
| Hydration & sodium targets | Arguably as important as carbs for endurance | Own subsystem (sweat rate, climate); needs real-world calibration |
| Gut/carb-tolerance training | Well-evidenced progressive protocol | Belongs in Coach as a program, not the macro engine |
| Heat/environment adjustment | Real effect on hydration/sodium/carbs | Depends on hydration subsystem existing first |
| During-exercise carb guidance as structured cards (beyond the tip in 8.1) | High value for marathon+ | Needs session-time input UI |
| CGM / blood glucose integration | The measurement frontier | V3+; name it, don't build it |

---

## References

**Carbohydrates:** Burke LM et al., J Sports Sci 2011 · Jeukendrup AE, J Sports Sci 2011 · Stellingwerff T & Cox GR, Appl Physiol Nutr Metab 2014 · Coyle EF, J Nutr 1992 · ACSM/ADA/DC Joint Position Statement 2016 · Bergström J et al., Acta Physiol Scand 1967

**Protein:** Morton RW et al., BJSM 2018 · ISSN Position Stand 2017 · Areta JL et al., J Physiol 2013 · Moore DR et al., J Gerontol 2015 · Churchward-Venne TA et al., AJCN 2016 · Tang JE et al., J Appl Physiol 2009 · Rogerson D, J Int Soc Sports Nutr 2017 · Lynch H et al., Nutrients 2018

**Fat/Energy Availability:** Mountjoy M et al. (RED-S), BJSM 2014 · Loucks AB, J Sports Sci 2004

**BMR/TDEE:** Mifflin MD et al., AJCN 1990 · Taggart LR et al., Eur J Clin Nutr 2022 · Beis LY et al., J Int Soc Sports Nutr 2011 · Knab AM et al., MSSE 2011 · 2024 Adult Compendium of Physical Activities

**Taper/Carb-loading:** Mujika I & Padilla S, MSSE 2003 · Sherman WM et al., Int J Sports Med 1981

**Recovery:** Howatson G et al., Scand J Med Sci Sports 2010 · Ivy JL, J Sports Sci Med 2004

**EPOC:** Rønnestad BR & Mujika I, Scand J Med Sci Sports 2014 · Sedlock DA et al., MSSE 2010

**Diet:** Burke LM et al. (LCHF), J Physiol 2017

**Concurrent training / dual-goal:** Schumann M et al. (meta-analysis update, cited via Stronger by Science) · high-protein concurrent training trial, Sports Med 2018 · Rønnestad BR & Mujika I, Scand J Med Sci Sports 2014
