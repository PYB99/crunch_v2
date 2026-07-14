# Phase 10 Implementation Plan — Race-Day Fueling & Gut Training

> **Date:** 2026-07-03
> **Status:** Plan — not yet executed
> **Context:** New product vertical, **not** in the original AGENTS.md Phase checklist (which ends at Phase 9 — Subscriptions/TestFlight). Rationale in `docs/product-strategy.md`: this is the differentiating bet that moves Crunch from "a carb-periodisation app" (Hexis's turf) into the race-day + in-run fueling territory that Precision Fuel & Hydration proved (31k+ marathoners on their free planner), which Crunch currently does **not** touch at all.
> Verified against the as-built code and the live DB, not the AGENTS.md spec's assumptions.

---

## 0. Understanding check — what exists, and the one distinction that must not be blurred

Verified against the repo + live project:

- **Crunch today is 100% *daily* fueling.** `MacroEngine.swift` and `_shared/macroEngine.ts` compute **daily** macro *targets* (carbs/protein/fat per day, shown as meal portions). There is **zero** in-race / intra-workout fueling anywhere — no carbs-per-hour, no gels, no hydration, no timeline.
- **The two engines already diverge** (audit finding #1, `docs/phase7-audit.md` §2). This plan must **not** create a third split. The fueling algorithm is display/interaction-time only (not webhook-triggered), so it lives in **one** Swift engine — see §Architecture.
- **`races`** keys on UUID `users.id`, one active race per user (`races_single_active_per_user_idx`), columns `race_type`, `race_date`, `race_name`. **There is no goal-time/target-duration column** — needed to compute race duration → total in-race carbs. New field required.
- **UUID-keyed tables** (`races`, `training_sessions`, `macro_targets`, `integrations`) use the RLS subquery pattern `user_id = (select id from users where clerk_id = requesting_user_id())`. New per-user tables here follow that exact pattern.
- **`training_sessions`** has `session_type` (`long_run` etc.), `session_date`, `distance_km`, `duration_mins`, `status` — the anchor for gut-training prompts (practice on long runs).
- **`MacroEngine.weeksUntil(dateString:)`** already computes weeks-to-race; reuse it, don't reimplement.
- **The two 0-byte base migrations** mean the live DB is the only trustworthy table inventory. This phase adds real migration files (and is a natural moment to honour audit item #2 — backfill a baseline — though that's tracked separately, not blocked here).

**The distinction that must not be blurred (write it into AGENTS.md):**

| | **Daily carb target** (existing) | **In-race carb rate** (this phase) |
|---|---|---|
| Unit | grams **per day** (`g/kg/day`, e.g. race day 10 g/kg) | grams **per hour** during the run (e.g. 60–90 g/hr) |
| Source | Burke daily periodisation | Jeukendrup multiple-transportable-carbs (glucose:fructose ~2:1) |
| Ceiling | appetite / daily intake | **gut tolerance** — trainable, and the whole point of §Gut Training |
| Owner | `MacroEngine` | new `FuelEngine` |

AGENTS.md's "race = 10 g/kg" is the **daily** number and is unrelated to the in-race g/hr this phase introduces. Conflating them is the most likely conceptual bug in review.

---

## 1. Scope — two paired features, one vertical

**A. Race-Day Fueling Plan** — given the race duration (from a goal finish time) and the athlete's trained gut ceiling, produce an in-race strategy: target **carbs/hr**, **fluid/hr**, **sodium/hr**, and a **timeline** ("every 20 min: 1 gel + sips of drink mix"), mapped to concrete products, editable by the user. Portions-first (products/counts), grams on a "see the numbers" toggle — mirrors the existing `MealCardView` pattern.

**B. Gut Training** — an 8–10-week progressive protocol anchored to `race_date`, scheduled onto **long-run** sessions, ramping ~30→90 g/hr. The athlete logs GI comfort + actual intake per practice; the achieved ceiling **feeds A** so the race target is never above what they've trained. This is the piece almost no competitor owns cleanly.

**Explicitly deferred (separate future phases, flagged not silently pulled in):**
- Deep hydration (sweat-test protocol, personalised sodium from field testing) — this phase ships *sensible defaults* + a simple salty-sweater flag, not a sweat-test flow.
- Female-specific / RED-S module — separate phase (sensitive; see `product-strategy.md` §4).
- Real-time on-watch in-race delivery / Apple Watch app.

---

## 2. The engine (the durable "brain" — build + test this first)

**`CRUNCH/Engines/FuelEngine.swift` — NEW.** Pure, stateless, deterministic. Single source of truth — **no Deno twin** (it is never webhook-triggered; generated on demand when the user opens/edits the plan). This is the deliberate correction of the macro-engine split.

Inputs: `goalDurationMins`, `gutCeilingCarbsPerHour` (from gut-training logs, else a `trainingLevel` default), `saltySweater: Bool`, optional `bodyWeightKg`.

Algorithm (literature-grounded — cite in code comments as `MacroEngine` already does):
- **Carbs/hr target** = min(durationBand, gutCeiling):
  - < 75 min → 0–30 (often unnecessary; surface a "you may not need to fuel" note)
  - 75–120 min → 30–60
  - 2–3 h → 60–90
  - > 3 h → 75–90 (up to 90–120 only if `gutCeiling` supports it)
  - **Hard cap at `gutCeiling`** — never prescribe above trained tolerance.
- **Multiple-transportable-carbs note** when target > 60 g/hr (needs glucose:fructose ~2:1; single-source glucose maxes ~60 g/hr).
- **Fluid/hr**: default 500 ml/hr (band 400–800); this phase does not personalise beyond the salty-sweater flag → sodium.
- **Sodium/hr**: default ~500 mg/hr, ~800–1000 for salty sweaters (documented defaults; sweat-test personalisation deferred).
- **Timeline**: intake every 20 min from `t=20min` to `goalDuration − 15min`; distribute total carbs across "units" and map to products (§4).

Outputs a `RaceFuelPlan` value type (targets + `[FuelTimelineItem]`).

**`CRUNCH/Engines/GutTrainingEngine.swift` — NEW.** Pure, deterministic.
- Inputs: `weeksToRace` (via `MacroEngine.weeksUntil`), `startCarbsPerHour` (default 40), `raceTargetCarbsPerHour`.
- Produces a weekly progression (`+~10–15 g/hr` every ~2 weeks, ceiling = race target) mapped to the long-run in each week.
- **Short-window handling**: if `weeksToRace < ~4` (already taper/race week), do **not** prescribe aggressive ramps — return "maintain what you've trained" and surface a gentle note. This is the top correctness risk (§5).
- `nextTargetFor(session:logs:)` — given practice logs, decides progress / hold / step-back from GI comfort scores.

**`CRUNCH/Engines/FuelEngineTests.swift`, `GutTrainingEngineTests.swift` — NEW.** Mirror the existing `MacroEngineTests`/`PortionEngineTests` rigor: band boundaries, gut-ceiling cap, sub-75-min case, >3h case, salty-sweater sodium, short-window gut-training guard, progression/step-back logic, timeline sums to total carbs.

Build order: **engine + tests must pass before any UI or DB work** (matches Phase 4's engine-first approach).

---

## 3. Data model — migrations (real files; base is empty)

All per-user tables: RLS enabled, UUID `users.id` keying via the subquery pattern, `WITH CHECK` on the policy (fixing the missing-`WITH_CHECK` weakness noted in the audit §4 — do it right for new tables).

**`supabase/migrations/2026XXXX_fuel_products.sql` — NEW**
`fuel_products` — global reference (gels, drink mixes, chews, real food):
`id uuid pk`, `brand text`, `name text`, `kind text` (`gel`|`drink_mix`|`chew`|`real_food`), `carbs_g numeric`, `sodium_mg numeric`, `caffeine_mg numeric null`, `glucose_fructose_ratio text null`, `serving_label text` (e.g. "1 gel", "500 ml @ 1 scoop"), `is_active bool default true`.
RLS: enabled; **SELECT policy `using (true)` for authenticated** (read-only reference); no INSERT/UPDATE/DELETE policy (service-role seed only). Seed data curated by Fable (§ what-to-use-Fable-for) — real market products with correct carb/sodium (Maurten, SIS Beta Fuel, Precision, Gu, Neversecond, + real-food options like banana, dates).

**`supabase/migrations/2026XXXX_race_fuel_plans.sql` — NEW**
Add `goal_finish_mins integer null` to `races` (the missing duration input).
`race_fuel_plans` — one editable plan per race:
`id uuid pk`, `user_id uuid not null`, `race_id uuid not null references races(id) on delete cascade`, `carbs_per_hour integer`, `fluid_ml_per_hour integer`, `sodium_mg_per_hour integer`, `timeline jsonb` (array of `{minute, product_id, note}`), `created_at`, `updated_at`. Unique `(user_id, race_id)`.

**`supabase/migrations/2026XXXX_gut_training.sql` — NEW**
`gut_training_plans` — lightweight editable state, one per race:
`id uuid pk`, `user_id uuid`, `race_id uuid references races(id) on delete cascade`, `start_carbs_per_hour integer default 40`, `target_carbs_per_hour integer`, `created_at`, `updated_at`. Unique `(user_id, race_id)`.
`gut_training_logs` — one per practice long run:
`id uuid pk`, `user_id uuid`, `session_id uuid null references training_sessions(id) on delete set null`, `log_date date`, `target_carbs_per_hour integer`, `actual_carbs_per_hour integer null`, `gi_comfort smallint` (1–5), `notes text null`, `created_at`.

Models (Swift, `Codable`, snake_case `CodingKeys` — match existing model conventions): `FuelProduct`, `RaceFuelPlan`, `FuelTimelineItem`, `GutTrainingPlan`, `GutTrainingLog`.

---

## 4. UI surfaces (no new tab — spec fixes 4 tabs)

**Race-Day Plan**
- **`CRUNCH/Features/Today/RaceDayCard.swift` — NEW.** A card that appears on Today **as the race approaches** (e.g. ≤ 3 weeks, and prominently in race week), summarising "Race plan: 75 g/hr · gel every 20 min", tapping → `RaceFuelPlanView`. Reuses `Theme.card` styling.
- **`CRUNCH/Features/Race/RaceFuelPlanView.swift` + `RaceFuelPlanViewModel` — NEW.** Goal-time input (if `races.goal_finish_mins` unset), computed targets, editable timeline; each timeline slot lets the user swap the product (picker from `fuel_products`). Portions-first ("1 gel + sips"), grams behind a "see the numbers" toggle. Also reachable from the Week header. Loading/error/empty states per Universal Behaviors.

**Gut Training**
- **`CRUNCH/Features/Nutrition/GutTrainingSection.swift` — NEW**, rendered inside the existing `NutritionView` (alongside "The Science") — progress ("Week 6: practicing 70 g/hr", ramp visualisation to race target).
- **`CRUNCH/Features/Week/DayRowView.swift` — MODIFIED.** On long-run days inside the training window, add a "Practice fueling: X g/hr" line + a "Log it" affordance → `GutTrainingLogSheet`. Extends existing expandable row; no structural change.
- **`CRUNCH/Features/Race/GutTrainingLogSheet.swift` — NEW.** Log actual g/hr + GI comfort (1–5) + notes; on save, `GutTrainingEngine.nextTargetFor` updates the plan.

**Optional AI layer (second increment, mirrors `estimate-meal`)**
- **`supabase/functions/suggest-fuel-products/index.ts` — NEW.** Given the athlete's target g/hr + "what I can get / what I like", Claude returns a concrete product/timeline suggestion (JSON-validated, same `x-clerk-token` + strip-fences + positive-number validation as `estimate-meal`). Deterministic engine stays canonical; this only *suggests product mixes*. Guarded by the §6 safety rules.

---

## 5. Top silent-failure modes for this phase

1. **Prescribing above trained tolerance → race-day GI disaster.** If `FuelEngine` ever emits a carbs/hr above the logged gut ceiling, the user follows it and blows up at km 30 — and the app looks authoritative doing it. Mitigation: the cap is a **unit-tested invariant** (`target ≤ gutCeiling`, always); race plan shows "trained to X g/hr" provenance; if no gut-training data exists, default the ceiling conservatively by `training_level` and label it an estimate.
2. **Wrong race duration → every downstream number wrong.** Total carbs scale with duration; if `goal_finish_mins` is unset the engine falls back to a `race_type` default pace, which can be far off. Mitigation: prompt for goal time before showing a plan; show the assumed duration explicitly; make "change goal time, totals move" a §7 test.
3. **Gut-training schedule mis-anchored for near-term races.** A user 3 weeks out is already tapering; an aggressive 40→90 ramp is wrong and unsafe. Mitigation: `GutTrainingEngine` short-window guard (unit-tested) returns "maintain, don't ramp in taper".
4. **Accidental third engine / drift.** Adding a Deno twin of `FuelEngine` re-creates the audit's #1 bug. Mitigation: **no server-side fueling engine** — the plan is generated client-side; the Edge Function only does AI product suggestion, never recomputes targets.
5. **Date/timezone math** in weeks-to-race and the practice-window boundaries (recurring pattern in this codebase). Mitigation: reuse `MacroEngine.weeksUntil`; unit-test window edges (exactly 10, 4, 1, 0 weeks).

---

## 6. Security / safety checklist (phase-specific)

- [ ] `fuel_products` SELECT-only for authenticated; **no** client write path (service-role seed only).
- [ ] All new per-user tables: RLS enabled, UUID subquery policy **with `WITH CHECK`** (don't repeat the coach-table missing-check pattern).
- [ ] `suggest-fuel-products` **verifies** (not just decodes) the Clerk JWT if it ever writes; strips HTML, enforces max length, validates JSON + positive numbers, rejects on failure (reuse `estimate-meal` hardening).
- [ ] **Fueling-advice safety guardrails** (ties into the strategy doc's safety layer): never prescribe intake above trained tolerance; disclaimer for GI conditions ("if you have a medical condition, consult…"); no under-fueling / weight framing — the advice is *additive* ("fuel more"), consistent with the "fuel not weight" brand and the forbidden-copy list.
- [ ] No PII/biometrics in `suggest-fuel-products` logs.
- [ ] Re-run the AGENTS.md 11-rule audit as the phase gate.

---

## 7. Test steps

**Engine (unit, first):** all boundaries, gut-ceiling cap, sub-75-min, >3h, salty-sweater sodium, short-window guard, progression/step-back, timeline-sums-to-total. Must be green before UI.

**On device:**
1. Set a race + goal time → `RaceFuelPlanView` shows sane targets; change goal time 4h→3h → totals + timeline shrink (failure mode 2).
2. No gut-training data → race target defaults conservatively by training level, labelled as an estimate; add gut-training logs reaching 80 g/hr → race target rises to (capped at) 80 (failure mode 1).
3. Race 3 weeks out → gut-training section says "maintain, don't ramp" (failure mode 3).
4. Long-run day in-window shows "Practice fueling: X g/hr" on the Week row; log comfort 2/5 → next target holds/steps back; log 5/5 → next target progresses.
5. Timeline product swap persists (`race_fuel_plans.timeline` updated); reopen → change intact.
6. Portions-first: plan reads "1 gel + sips every 20 min"; "see the numbers" reveals g/hr + ml + mg.
7. RaceDayCard appears on Today only as the race approaches; absent for a far-off race.
8. (If built) `suggest-fuel-products` returns a valid product mix; malformed model output is rejected with a retry, never crashes.
9. Accessibility: new controls labelled, 44 pt targets, Dynamic Type, WCAG AA on new cards.
10. Security: 11-rule audit + §6 list.

---

## 8. Sequencing

1. **`FuelEngine` + `GutTrainingEngine` + tests** (engine-first; the durable brain).
2. **Migrations + models + seed `fuel_products`** (Fable curates the product data).
3. **Race plan generation + `RaceFuelPlanView` + `RaceDayCard`** — the headline surface.
4. **Gut-training schedule + `DayRowView` prompts + log sheet + Nutrition section** — the paired half that feeds #3.
5. **(Optional) `suggest-fuel-products` Edge Function** — AI product layer, after the deterministic core works.
6. **Analytics** (`race_plan_generated`, `race_plan_viewed`, `gut_training_logged`, `fuel_product_swapped`) + accessibility/Dynamic Type pass.
7. **Tests (§7) + security audit.**

---

## 9. What to point Fable 5 at specifically (highest-leverage, hard-to-redo)

Per `docs/product-strategy.md` §5 — the knowledge-dense pieces where a frontier model is the differentiator:
- **Design `FuelEngine`/`GutTrainingEngine` from the literature** (bands, ratios, ramp rates, short-window handling) with citations — the durable brain.
- **Curate the `fuel_products` seed** — accurate carb/sodium/glucose:fructose for real market products + real-food options.
- **Author the safety guardrails + `suggest-fuel-products` system prompt**, and a **golden-set eval** for it (mirrors the strategy doc's non-negotiable AI-quality layer).

---

## Architecture concerns (flagged once)

1. **Prerequisite: the audit's Critical items** (`phase7-audit.md`). This vertical assumes a *single, correct* daily engine; reconcile `MacroEngine` ↔ `macroEngine.ts` **before** building on top, or the race plan inherits divergent daily numbers. Also honour the migration backfill — this phase adds real migrations and is the moment to stop the 0-byte-base bleeding.
2. **Single-engine discipline.** `FuelEngine` stays Swift-only by design. If a future webhook ever needs server-side fueling (it shouldn't), extract a shared spec rather than hand-porting — the macro-engine split is the cautionary tale.
3. **`goal_finish_mins` on `races`** is a schema change to a table onboarding (Phase 5) will also write — coordinate so Phase 5's race screen sets it, and Settings' `RaceEditView` (Phase 8) gains the field.
4. **No new tab** (spec fixes four). Race plan lives as a Today card + pushed screen; gut training lives in Nutrition + Week. If this feels cramped in testing, that's a product-nav conversation, not a silent fifth-tab addition.
5. **Hydration depth and female/RED-S are deliberately out** — sensible defaults only here. Don't let scope creep pull sweat-testing or cycle-aware logic into this phase; they're their own bets in the strategy doc.
