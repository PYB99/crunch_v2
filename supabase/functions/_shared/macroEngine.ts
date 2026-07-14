// Macro calculation shared by strava-webhook and runna-sync.
// Mirrors CRUNCH/Engines/MacroEngine.swift — master spec §3–6 (Section 14 items 1–6).
// Scope: targeted single-value engine upgrade. Training-level carb bands (§4.1
// columns), race/age/diet modifiers, phase carb multipliers, and the §7.1 phase
// detection (post_race_recovery) are deferred to the Section 7–12 phase.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Constants ─────────────────────────────────────────────────────────────────

// TDEE multipliers (§3.2). Existing run values unchanged; recovery_day + race_*
// split are the in-scope additions.
const TDEE_MULTIPLIER: Record<string, number> = {
  rest:          1.2,
  recovery_day:  1.35,
  easy_run:      1.55,
  tempo:         1.725,
  interval:      1.725,
  long_run:      1.9,
  race_5k:       1.75,
  race_10k:      1.85,
  race_half:     2.00,
  race_marathon: 2.40,
};
const DEFAULT_MULTIPLIER = 1.2; // rest

// Carbohydrate g/kg (§4.1, Band-B representative).
const CARBS_PER_KG: Record<string, number> = {
  rest:          4,
  recovery_day:  6,
  easy_run:      6,
  tempo:         7,
  interval:      7,
  long_run:      8.5,
  race_5k:       5.5,
  race_10k:      6.5,
  race_half:     8.5,
  race_marathon: 10,
};

// Session carb floors (§6.3) — lower bound both fat guards reduce toward.
const SESSION_CARB_FLOOR: Record<string, number> = {
  long_run:      5.0,
  race_half:     6.0,
  race_marathon: 8.0,
  race_ultra:    8.0,
};
const DEFAULT_CARB_FLOOR = 3.0;

const PROTEIN_PER_KG          = 1.7;   // Morton et al. 2018
const RECOVERY_PROTEIN_PER_KG = 2.0;   // Ivy 2002 (recovery-day only; §5.1 subset)
const RACE_WEEK_CARB_LOAD     = 11;    // flat carb-load; §4.5 race-specific values deferred
const KCAL_CARBS              = 4;
const KCAL_PROTEIN            = 4;
const KCAL_FAT                = 9;
const FAT_MIN_PCT             = 0.20;  // 20% of energy (not 0.5 g/kg — §6.2)
const FAT_MAX_PCT             = 0.35;

const FALLBACK = {
  weight_kg: 70,
  height_cm: 175,   // matches Swift fallback (was 170)
  age:       30,
  gender:    "male",
};

const SESSION_TO_TARGET_TYPE: Record<string, string> = {
  rest:          "rest",
  recovery_day:  "recovery",
  easy_run:      "easy",
  tempo:         "tempo",
  interval:      "interval",
  long_run:      "long",
  race_5k:       "race_5k",
  race_10k:      "race_10k",
  race_half:     "race_half",
  race_marathon: "race_marathon",
};

const HARD_SESSION_TYPES = new Set([
  "tempo", "interval", "long_run",
  "race", "race_5k", "race_10k", "race_half", "race_marathon", "race_ultra",
]);
const RUN_SESSION_TYPES = new Set([
  "easy_run", "tempo", "interval", "long_run",
  "race", "race_5k", "race_10k", "race_half", "race_marathon", "race_ultra",
]);

// ── Session-type resolution ─────────────────────────────────────────────────────

// Maps aliases onto canonical lookup keys. Legacy/ultra "race" folds to
// race_marathon so it can never fall through to the rest default (defensive alias).
function canonical(type: string): string {
  if (type === "cycling" || type === "swimming") return "easy_run";
  if (type === "race" || type === "race_ultra" || type === "race_ultra_marathon") {
    return "race_marathon";
  }
  return type;
}

function isRaceType(type: string): boolean {
  return type === "race" || type.startsWith("race_");
}

// Recovery-day detection (§3.4). Upgrades a light day that follows a long run or
// race; deliberately does not downgrade a genuine hard session (would under-fuel).
function resolveSessionType(today: string, previous: string | null): string {
  if (previous && (previous === "long_run" || previous === "race" || previous.startsWith("race_"))) {
    return HARD_SESSION_TYPES.has(today) ? today : "recovery_day";
  }
  return today;
}

// ── Pure calculation ──────────────────────────────────────────────────────────

type TrainingPhase =
  | "base_building"
  | "build_phase"
  | "peak_training"
  | "taper"
  | "race_week";

interface MacroResult {
  calories_kcal:  number;
  carbs_g:        number;
  protein_g:      number;
  fat_g:          number;
  target_type:    string;
  training_phase: TrainingPhase;
  flags:          string[];
}

function getDaysToRace(raceDate: string, sessionDate: string): number {
  const race    = new Date(raceDate);
  const session = new Date(sessionDate);
  race.setUTCHours(0, 0, 0, 0);
  session.setUTCHours(0, 0, 0, 0);
  return Math.round((race.getTime() - session.getTime()) / 86_400_000);
}

// Matches Swift MacroEngine.trainingPhase: >12 base, 8–12 build, 4–7 peak,
// 1–3 taper, 0 race week. Weeks are floored and clamped at 0 (Swift weeksUntil).
function getPhase(daysToRace: number): TrainingPhase {
  const weeks = Math.max(0, Math.floor(daysToRace / 7));
  if (weeks > 12) return "base_building";
  if (weeks >= 8) return "build_phase";
  if (weeks >= 4) return "peak_training";
  if (weeks >= 1) return "taper";
  return "race_week";
}

function calcBmr(weight: number, height: number, age: number, gender: string): number {
  const base = 10 * weight + 6.25 * height - 5 * age;
  return gender === "female" ? base - 161 : base + 5;
}

// Fat Engine (§6.1): 20–35%-of-energy band + FIX A (ordinary fat-floor
// reconciliation) + FIX B (carb-load collision guard).
function calcFat(
  tdee: number, carbs: number, protein: number, weight: number, type: string,
): { fat: number; carbs: number; flags: string[] } {
  const usedCalories = carbs * KCAL_CARBS + protein * KCAL_PROTEIN;
  const fatFromRemainder = Math.max(0, (tdee - usedCalories) / KCAL_FAT);

  const fatMin = (tdee * FAT_MIN_PCT) / KCAL_FAT;
  const fatMax = (tdee * FAT_MAX_PCT) / KCAL_FAT;

  let fat = Math.max(fatMin, Math.min(fatFromRemainder, fatMax));
  let finalCarbs = carbs;
  const flags: string[] = [];

  // FIX A — reduce carbs toward the session floor when the fat floor triggers,
  // then re-derive fat from the room actually left. Every session type.
  if (fat > fatFromRemainder) {
    flags.push("fat_floor_triggered");
    const carbReduction = ((fat - fatFromRemainder) * KCAL_FAT) / KCAL_CARBS;
    const sessionFloor = (SESSION_CARB_FLOOR[type] ?? DEFAULT_CARB_FLOOR) * weight;
    finalCarbs = Math.max(carbs - carbReduction, sessionFloor);
    const remainingForFat = tdee - (finalCarbs * KCAL_CARBS + protein * KCAL_PROTEIN);
    fat = Math.max(remainingForFat / KCAL_FAT, fatMin * 0.9);
  }

  // FIX B — carb-load collision guard, TDEE-relative floor (not flat 8 g/kg).
  const totalCheck = finalCarbs * KCAL_CARBS + protein * KCAL_PROTEIN + fatMin * KCAL_FAT;
  if (totalCheck > tdee * 1.02) {
    const reduction = (totalCheck - tdee) / KCAL_CARBS;
    const hardFloor = Math.min(8.0 * weight, (tdee * 0.55) / KCAL_CARBS);
    const newCarbs = Math.max(finalCarbs - reduction, hardFloor);
    if (Math.abs(newCarbs - finalCarbs) > 1e-6) {
      flags.push("carb_load_capped");
      finalCarbs = newCarbs;
      const remainingForFat = tdee - (finalCarbs * KCAL_CARBS + protein * KCAL_PROTEIN);
      fat = Math.max(remainingForFat / KCAL_FAT, fatMin * 0.9);
    }
  }

  return { fat, carbs: finalCarbs, flags };
}

function calcMacros(
  weight: number, height: number, age: number, gender: string,
  sessionType: string, previousSessionType: string | null,
  sessionDate: string, raceDate: string,
): MacroResult {
  const resolved = resolveSessionType(sessionType, previousSessionType);
  const type = canonical(resolved);

  const tdee = calcBmr(weight, height, age, gender) * (TDEE_MULTIPLIER[type] ?? DEFAULT_MULTIPLIER);
  const phase = getPhase(getDaysToRace(raceDate, sessionDate));

  // Race week forces the flat carb-load; otherwise the session's g/kg.
  const baseCarbs = phase === "race_week"
    ? RACE_WEEK_CARB_LOAD * weight
    : (CARBS_PER_KG[type] ?? CARBS_PER_KG["easy_run"]) * weight;
  const protein = (type === "recovery_day" ? RECOVERY_PROTEIN_PER_KG : PROTEIN_PER_KG) * weight;

  const { fat, carbs, flags } = calcFat(tdee, baseCarbs, protein, weight, type);

  const targetType = phase === "race_week"
    ? "carb_load"
    : (SESSION_TO_TARGET_TYPE[resolved] ?? "easy");

  return {
    calories_kcal:  Math.round(carbs * KCAL_CARBS + protein * KCAL_PROTEIN + fat * KCAL_FAT),
    carbs_g:        Math.round(carbs),
    protein_g:      Math.round(protein),
    fat_g:          Math.round(fat),
    target_type:    targetType,
    training_phase: phase,
    flags,
  };
}

// ── DB helper ─────────────────────────────────────────────────────────────────

function previousDate(sessionDate: string): string {
  const d = new Date(sessionDate);
  d.setUTCHours(0, 0, 0, 0);
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().substring(0, 10);
}

export async function generateAndSaveMacroTarget(
  supabase: SupabaseClient,
  params: {
    userId:      string;
    sessionId:   string;
    sessionDate: string;
    sessionType: string;   // already race-resolved by the caller (see strava-webhook)
  },
): Promise<void> {
  const { userId, sessionId, sessionDate, sessionType } = params;

  const [userRes, raceRes, prevRes] = await Promise.all([
    supabase
      .from("users")
      .select("weight_kg, height_cm, age, gender")
      .eq("id", userId)
      .single(),
    supabase
      .from("races")
      .select("race_date")
      .eq("user_id", userId)
      .eq("is_active", true)
      .single(),
    // Yesterday's run — drives recovery-day detection (§3.4).
    supabase
      .from("training_sessions")
      .select("session_type")
      .eq("user_id", userId)
      .eq("session_date", previousDate(sessionDate)),
  ]);

  if (userRes.error || !userRes.data || raceRes.error || !raceRes.data) return;

  const u = userRes.data as {
    weight_kg: number | null; height_cm: number | null;
    age: number | null; gender: string | null;
  };
  const raceDate = (raceRes.data as { race_date: string }).race_date;

  const prevRows = (prevRes.data ?? []) as { session_type: string }[];
  const previousSessionType =
    prevRows.find((r) => RUN_SESSION_TYPES.has(r.session_type))?.session_type ?? null;

  const result = calcMacros(
    u.weight_kg ?? FALLBACK.weight_kg,
    u.height_cm ?? FALLBACK.height_cm,
    u.age       ?? FALLBACK.age,
    u.gender    ?? FALLBACK.gender,
    sessionType,
    previousSessionType,
    sessionDate,
    raceDate,
  );

  await supabase.from("macro_targets").upsert(
    {
      user_id:       userId,
      target_date:   sessionDate,
      session_id:    sessionId,
      calories_kcal: result.calories_kcal,
      carbs_g:       result.carbs_g,
      protein_g:     result.protein_g,
      fat_g:         result.fat_g,
      target_type:   result.target_type,
    },
    { onConflict: "user_id,target_date" },
  );
}

// Distance-bucket race resolution (master spec flag 2, distance PRIMARY).
// Callers pass a bare "race" (e.g. Strava workout_type=1); bucket by the actual
// session distance so a marathon-training user's 10K tune-up gets race_10k fuel.
// distance_km null → race_marathon (the safe default; the race_type fallback is
// applied by the legacy-row backfill migration, where distance may be absent).
export function resolveRaceSessionType(sessionType: string, distanceKm: number | null): string {
  if (!isRaceType(sessionType)) return sessionType;
  if (distanceKm == null) return "race_marathon";
  if (distanceKm < 7)  return "race_5k";
  if (distanceKm < 15) return "race_10k";
  if (distanceKm < 25) return "race_half";
  return "race_marathon";
}
