-- Phase 5 (Onboarding v3) — dietary preference.
-- Onboarding screen 20 collects a single diet type; the Macro Engine reads it
-- for the protein digestibility modifier (master-spec §2.4) and the low-carb
-- conflict flag (§9.2). Exclusions/allergies are deliberately out of scope this
-- phase (meal-library filtering, §9.3) so no column for them yet.
--
-- CHECK mirrors the schema's existing enum-guard style (see meals_meal_time_check
-- / coach_messages_role_check) so the column can't drift to free text. Nullable:
-- pre-Phase-5 rows have no diet, and the engine falls back to omnivore.

ALTER TABLE "public"."users"
    ADD COLUMN IF NOT EXISTS "diet" "text";

ALTER TABLE "public"."users"
    DROP CONSTRAINT IF EXISTS "users_diet_check";

ALTER TABLE "public"."users"
    ADD CONSTRAINT "users_diet_check"
    CHECK ("diet" = ANY (ARRAY['omnivore'::"text", 'vegetarian'::"text", 'vegan'::"text", 'pescatarian'::"text"]));
