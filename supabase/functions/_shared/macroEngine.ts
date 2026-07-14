// Macro calculation shared by strava-webhook and runna-sync.
// Keep constants in sync with constants/nutrition.ts in the React Native app.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Constants ─────────────────────────────────────────────────────────────────

const CARBS_PER_KG: Record<string, number> = {
  rest_day: 4,
  easy_run: 6,
  tempo:    7,
  interval: 7,
  long_run: 8.5,
  race:     11,
};

const CARB_LOAD_TARGET        = 11;   // Burke 2010 — 10–12 g/kg, midpoint
const PROTEIN_PER_KG          = 1.7;  // Morton et al. 2018 — midpoint of 1.6–1.8
const FAT_MIN_PER_KG          = 0.5;
const KCAL_CARBS              = 4;
const KCAL_PROTEIN            = 4;
const KCAL_FAT                = 9;
const TAPER_REDUCTION         = 0.125; // Mujika & Padilla 2003 — midpoint of 10–15%
const CARB_LOAD_DAYS          = 3;

const ACTIVITY_MULTIPLIER: Record<string, number> = {
  beginner:     1.4,
  intermediate: 1.55,
  advanced:     1.725,
};
const DEFAULT_MULTIPLIER = 1.55;

const FALLBACK = {
  weight_kg:      70,
  height_cm:      170,
  age:            30,
  gender:         "male",
  training_level: "intermediate",
};

const SESSION_TO_TARGET_TYPE: Record<string, string> = {
  rest_day: "rest",
  easy_run: "easy",
  tempo:    "tempo",
  interval: "interval",
  long_run: "long",
  race:     "race",
};

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
}

function getDaysToRace(raceDate: string, sessionDate: string): number {
  const race    = new Date(raceDate);
  const session = new Date(sessionDate);
  race.setUTCHours(0, 0, 0, 0);
  session.setUTCHours(0, 0, 0, 0);
  return Math.round((race.getTime() - session.getTime()) / 86_400_000);
}

function getPhase(weeksToRace: number): TrainingPhase {
  if (weeksToRace > 12) return "base_building";
  if (weeksToRace > 8)  return "build_phase";
  if (weeksToRace > 4)  return "peak_training";
  if (weeksToRace > 2)  return "taper";
  return "race_week";
}

function calcBmr(
  weight: number, height: number, age: number, gender: string,
): number {
  const base = 10 * weight + 6.25 * height - 5 * age;
  return gender === "female" ? base - 161 : base + 5;
}

function calcMacros(
  weight: number, height: number, age: number,
  gender: string, level: string,
  sessionType: string, sessionDate: string, raceDate: string,
): MacroResult {
  const tdee       = calcBmr(weight, height, age, gender) * (ACTIVITY_MULTIPLIER[level] ?? DEFAULT_MULTIPLIER);
  const daysToRace = getDaysToRace(raceDate, sessionDate);
  const phase      = getPhase(daysToRace / 7);
  const protein_g  = Math.round(PROTEIN_PER_KG * weight);
  const fatMin     = Math.round(FAT_MIN_PER_KG * weight);

  if (daysToRace > 0 && daysToRace <= CARB_LOAD_DAYS) {
    const carbs_g = Math.round(CARB_LOAD_TARGET * weight);
    const fat_g   = Math.max(
      Math.round((tdee - carbs_g * KCAL_CARBS - protein_g * KCAL_PROTEIN) / KCAL_FAT),
      fatMin,
    );
    return {
      calories_kcal: Math.round(carbs_g * KCAL_CARBS + protein_g * KCAL_PROTEIN + fat_g * KCAL_FAT),
      carbs_g, protein_g, fat_g,
      target_type: "carb_load", training_phase: phase,
    };
  }

  const carbsPerKg = CARBS_PER_KG[sessionType] ?? CARBS_PER_KG["easy_run"];
  const carbs_g    = Math.round(carbsPerKg * weight);

  if (phase === "taper") {
    const fat_g = Math.max(
      Math.round((tdee * (1 - TAPER_REDUCTION) - carbs_g * KCAL_CARBS - protein_g * KCAL_PROTEIN) / KCAL_FAT),
      fatMin,
    );
    return {
      calories_kcal: Math.round(carbs_g * KCAL_CARBS + protein_g * KCAL_PROTEIN + fat_g * KCAL_FAT),
      carbs_g, protein_g, fat_g,
      target_type: "taper", training_phase: phase,
    };
  }

  const fat_g = Math.max(
    Math.round((tdee - carbs_g * KCAL_CARBS - protein_g * KCAL_PROTEIN) / KCAL_FAT),
    fatMin,
  );
  return {
    calories_kcal: Math.round(carbs_g * KCAL_CARBS + protein_g * KCAL_PROTEIN + fat_g * KCAL_FAT),
    carbs_g, protein_g, fat_g,
    target_type: SESSION_TO_TARGET_TYPE[sessionType] ?? "easy", training_phase: phase,
  };
}

// ── DB helper ─────────────────────────────────────────────────────────────────

export async function generateAndSaveMacroTarget(
  supabase: SupabaseClient,
  params: {
    userId:      string;
    sessionId:   string;
    sessionDate: string;
    sessionType: string;
  },
): Promise<void> {
  const { userId, sessionId, sessionDate, sessionType } = params;

  const [userRes, raceRes] = await Promise.all([
    supabase
      .from("users")
      .select("weight_kg, height_cm, age, gender, training_level")
      .eq("id", userId)
      .single(),
    supabase
      .from("races")
      .select("race_date")
      .eq("user_id", userId)
      .eq("is_active", true)
      .single(),
  ]);

  if (userRes.error || !userRes.data || raceRes.error || !raceRes.data) return;

  const u = userRes.data as {
    weight_kg: number | null; height_cm: number | null;
    age: number | null; gender: string | null; training_level: string | null;
  };
  const raceDate = (raceRes.data as { race_date: string }).race_date;

  const result = calcMacros(
    u.weight_kg      ?? FALLBACK.weight_kg,
    u.height_cm      ?? FALLBACK.height_cm,
    u.age            ?? FALLBACK.age,
    u.gender         ?? FALLBACK.gender,
    u.training_level ?? FALLBACK.training_level,
    sessionType,
    sessionDate,
    raceDate,
  );

  await supabase.from("macro_targets").upsert(
    {
      user_id:      userId,
      target_date:  sessionDate,
      session_id:   sessionId,
      calories_kcal: result.calories_kcal,
      carbs_g:       result.carbs_g,
      protein_g:     result.protein_g,
      fat_g:         result.fat_g,
      target_type:   result.target_type,
    },
    { onConflict: "user_id,target_date" },
  );
}
