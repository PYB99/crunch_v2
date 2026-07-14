# Phase 11 Implementation Plan — Female-Athlete Health & RED-S Safety

> **Date:** 2026-07-03
> **Status:** Plan — not yet executed
> **Context:** New product vertical, not in the original AGENTS.md checklist. Rationale in `docs/product-strategy.md` §4. This is the **safety-and-differentiation** bet: Crunch's users skew toward the population (female endurance runners) most at risk of RED-S, and no competitor serves this well. It is also the **highest-stakes** phase in the app — it gives health-adjacent guidance to a vulnerable population, so it carries requirements the other phases do not (clinical review, special-category-data privacy, red-team evals).
> Verified against the as-built code and live DB, not the AGENTS.md spec's assumptions.

---

## 0. Understanding check — what exists, and the three things that make this phase different

Verified against the repo + live project:

- **`users.gender`** is `'male'|'female'` and is **biological sex for BMR only** (AGENTS.md onboarding screen 5). It is **not** menstrual status and **not** gender identity. There is no cycle data, no menstrual-status field, no screening anywhere.
- **`MacroEngine.swift`** already branches on `gender == "female"` for the Mifflin-St Jeor constant. Nothing else is sex-aware.
- **Under-fueling signals already in the data**: `training_sessions.perceived_exertion` (RPE), session completion/`status`, unmet `macro_targets`, and (Phase 10) gut-training logs. Layer 1 reads these — it does not need new tracking to start.
- **No HealthKit integration exists** (it's item 5 in `product-strategy.md` §5). Cycle phase ideally comes from HealthKit; this plan must **degrade gracefully without it** (manual/estimated fallback) and not hard-block on it.
- The **"fuel not weight" copy rules** (forbidden: `calories`/`deficit`/`weight loss`/`body composition`/`diet`/`compliance`) are load-bearing here more than anywhere — this screen talks about eating and periods to people at disordered-eating risk.
- Onboarding (Phase 5) is deferred, so — mirroring the Phase 8 pattern — screening/status live in a **Settings-reachable flow now**, with a Phase 5 coordination note.

**Three things that make Phase 11 unlike Phases 8/10:**

1. **It flags and refers — it never diagnoses.** Every output is "here's something worth a conversation with a professional," never "you have RED-S" or "you're fine."
2. **Menstrual data is special-category health data** (GDPR Art. 9; also post-*Dobbs* US sensitivity). Default posture: **keep cycle timing on-device / in HealthKit, derive phase locally, do not persist raw cycle dates to Supabase.** Only a coarse, non-identifying `menstrual_status` enum syncs, if anything.
3. **Clinical review is a prerequisite, not a polish step.** The screening logic and copy must be validated by a sports dietitian / RED-S specialist **before** build-out of the user-facing flow — see §Architecture.

---

## 1. Scope — two layers, safety first

**Layer 1 — RED-S / Low Energy Availability (LEA) safety.** The spine. Build first; it's higher-certainty and higher-impact.
- Gentle **LEAF-Q-style screening** → risk band (low / moderate / high).
- **Under-fueling signal detection** over existing data (chronic unmet targets, RPE-vs-intake mismatch, unexpected weight drop, amenorrhea from screening).
- Supportive response: awareness + **signposting to real resources / "talk to a sports dietitian or doctor"**, never a deficit, never a diagnosis.

**Layer 2 — cycle-aware fueling.** Modest, individualized, second.
- Branch on menstrual status; **only natural cycles get phase nudges.**
- Luteal: attention to hydration/sodium, a small **visible/optional** protein nudge, carbs pre/during hard sessions. Follicular: favourable for hard sessions/carb-load.
- **Gentle educational notes, not silent macro rewrites** (honesty + keeps `MacroEngine` clean).

**Explicitly deferred / out of scope (flagged, not silently pulled in):**
- A full period-tracker calendar UI — lean on HealthKit; Crunch shows *fueling notes*, not a cycle tracker.
- Iron/bone-health *lab tracking* — this phase surfaces *awareness + food sources*, not blood-panel logging.
- Any pregnancy/postpartum nutrition logic — separate, and out.

---

## 2. Engines / logic (the durable brain — build + test first, after clinical sign-off)

All pure, stateless, Swift-only (no Deno twin — none of this is webhook-triggered).

**`CRUNCH/Engines/LEAScreeningEngine.swift` — NEW.**
- `score(answers:) -> (score: Int, band: RiskBand)` using validated LEAF-Q cutoffs (clinician-confirmed).
- **Amenorrhea / absent periods routes to high-attention regardless of other scores** (it's a primary RED-S red flag, not "no cycle data").
- Deterministic; unit-tested against published cutoffs.

**`CRUNCH/Engines/UnderfuelingSignal.swift` — NEW.**
- `evaluate(targets:sessions:weightTrend:screening:) -> SignalLevel` — a conservative rule set over existing data. Chronic unmet carb targets + unexpected weight drop + menstrual-dysfunction flag → gentle check-in.
- **Tuned to avoid false alarms** (a nagging app is a deleted app) *and* false reassurance. Never emits "you're fine."

**`CRUNCH/Engines/CycleFuelingAdvisor.swift` — NEW.**
- `notes(status:cyclePhase:sessionType:) -> [FuelingNote]?` — returns `nil`/steady for `hormonal_contraception`, `absent_or_amenorrhea`, `perimenopause`, `prefer_not_to_say`.
- For natural cycles: **modest, phase-appropriate educational notes**, plus an *optional, visible* luteal protein nudge (not a hidden engine change). Copy carries the individual-variation caveat.

**Tests** (`LEAScreeningEngineTests`, `UnderfuelingSignalTests`, `CycleFuelingAdvisorTests`) mirroring existing engine-test rigor: LEAF-Q cutoff boundaries, amenorrhea override, branch coverage across all menstrual statuses, phase derivation from a given period-start date, signal trips on synthetic under-fueling data and stays quiet on normal data.

---

## 3. Data model — minimal, privacy-first

Per-user tables: RLS enabled, UUID `users.id` subquery policy **with `WITH CHECK`**.

**`supabase/migrations/2026XXXX_female_health.sql` — NEW**
- `ALTER TABLE users ADD COLUMN menstrual_status text` — enum-checked: `natural` | `hormonal_contraception` | `absent_or_amenorrhea` | `perimenopause` | `prefer_not_to_say`. Coarse, non-identifying — safe to sync.
- `lea_screenings` — screening history: `id uuid pk`, `user_id uuid`, `answers jsonb`, `score int`, `risk_band text`, `screened_at timestamptz`. (Screening answers are sensitive but not cycle-timing; acceptable to store under RLS. If the clinical reviewer objects, downgrade to storing only `score`+`band`.)

**Deliberately NOT stored server-side:** raw cycle/period dates. Cycle timing stays in **HealthKit** (or on-device SwiftData if manual), and `CycleFuelingAdvisor` derives the phase locally. This is a privacy decision, not an oversight — see §Architecture #2.

Models (Swift, `Codable`, snake_case `CodingKeys`): `LEAScreening`, `RiskBand`, `MenstrualStatus`, `FuelingNote`.

---

## 4. UI surfaces (no new tab; no period-tracker)

- **`CRUNCH/Features/Wellbeing/FuelingHealthView.swift` + ViewModel — NEW.** Reached from Settings (and, once Phase 5 lands, from an optional onboarding screen shown only when `gender == female`). Contains: menstrual-status selector, the LEAF-Q screening flow, current status, and — if a signal/band warrants — **supportive resources + a "talk to a professional" signpost** (never a diagnosis banner).
- **`CRUNCH/Features/Wellbeing/ScreeningFlow.swift` — NEW.** The LEAF-Q questionnaire, worded supportively, opt-out at any point, with a plain-language "this isn't medical advice" preamble.
- **Cycle-aware notes** surface as **gentle contextual lines** on Today/Week (via a small addition to the existing card/row views) on relevant days — *not* a calendar UI. Absent entirely for non-natural-cycle statuses.
- **Under-fueling check-in**: a soft, dismissible prompt (not a modal wall) when `UnderfuelingSignal` trips — supportive tone, links to resources, never blocks the app.
- **Copy**: supportive, non-triggering, zero weight/body-comp language, disclaimers present, real signposting (RED-S info; where appropriate, eating-disorder support resources). All copy clinician-reviewed.

---

## 5. Top silent-failure modes for this phase

1. **Screening reads as diagnosis or false reassurance.** "Low risk" must never mean "you're fine"; "high" must never mean "you have RED-S." Mitigation: every output is framed as *awareness + refer*; clinician-reviewed copy; no diagnostic language in the string table (add a copy-lint check).
2. **Assuming every female-sex user cycles naturally.** Contraception flattens the cycle; **amenorrhea is a red flag, not missing data.** Mitigation: `menstrual_status` gates all Layer-2 logic; `absent_or_amenorrhea` routes to Layer 1, never to "skip, no cycle data."
3. **Over-prescribing cycle periodization beyond the evidence.** Mitigation: notes are modest, optional, and carry the individual-variation caveat; Layer 2 never silently rewrites macros.
4. **Leaking sensitive cycle data to the cloud.** Mitigation: raw cycle timing stays on-device/HealthKit by design; a test asserts no period dates are persisted server-side.
5. **The screening itself triggering a vulnerable user.** Mitigation: supportive framing, opt-out at any step, resources on exit regardless of score, and a red-team Coach eval covering disclosure of disordered-eating intent.

---

## 6. Security / safety / privacy checklist (phase-specific)

- [ ] **Clinical sign-off** on screening logic + all copy **before** the user-facing flow is built (§Architecture #3).
- [ ] Raw cycle/period timing **never persisted to Supabase**; HealthKit access is read-only, purpose-stringed, and gated behind explicit consent.
- [ ] New tables: RLS + UUID subquery policy **with `WITH CHECK`**.
- [ ] `menstrual_status` and screening scores are the only synced female-health data; no free-text symptom notes synced without review.
- [ ] **Coach guardrail extension + red-team eval**: RED-S / cycle / body-image questions handled safely — never diagnoses, never enables restriction, always signposts. This is the non-negotiable AI-safety item from `product-strategy.md` §5.
- [ ] No forbidden copy anywhere in the new strings (`calories`/`deficit`/`weight loss`/`body composition`/`diet`/`compliance`); copy-lint the new string table.
- [ ] HealthKit usage complies with App Store health-data + privacy-label requirements (declare, justify, no third-party sharing).
- [ ] Re-run the AGENTS.md 11-rule audit as the phase gate.

---

## 7. Test steps

**Engine (unit, after clinical sign-off, before UI):** LEAF-Q cutoff boundaries; amenorrhea override; all `menstrual_status` branches; phase derivation from a period-start date; under-fueling signal trips on synthetic deficit data and stays quiet on normal data.

**On device:**
1. Female-sex user → FuelingHealthView reachable from Settings; male-sex user → not surfaced.
2. Screening flow: opt-out mid-way works; completion yields a band + supportive result (never a diagnosis); resources shown on exit regardless of score.
3. Status = `hormonal_contraception` / `perimenopause` → **no** cycle nudges anywhere.
4. Status = `natural` + a given period-start → correct phase; luteal shows the modest hydration/protein notes on relevant Today/Week days; follicular differs appropriately.
5. Status = `absent_or_amenorrhea` → routes to Layer-1 attention, not "skip."
6. Under-fueling signal: seed chronic unmet targets + weight drop → gentle check-in appears, dismissible, non-blocking, no diagnosis.
7. **Privacy assertion:** after using cycle features, confirm **no period dates exist in Supabase** (only `menstrual_status` + screening score/band).
8. Copy audit: no forbidden words; supportive tone; disclaimers present.
9. Accessibility (labels, 44 pt, Dynamic Type, contrast); security 11-rule audit + §6 list.

---

## 8. Sequencing

1. **Clinical/expert review of the design + copy** (LEAF-Q scoring, signal thresholds, all strings). Prerequisite — nothing user-facing before this.
2. **`LEAScreeningEngine` + `UnderfuelingSignal` + tests** (Layer 1 brain).
3. **Data model + `menstrual_status`/screening + FuelingHealthView + ScreeningFlow** (Settings-reachable; coordinate Phase 5).
4. **Under-fueling check-in** wired over existing data.
5. **HealthKit cycle read** (depends on the HealthKit phase) *or* minimal on-device manual fallback → **`CycleFuelingAdvisor`** + local phase derivation.
6. **Cycle-aware notes** on Today/Week.
7. **Coach guardrail extension + red-team eval.**
8. **Copy / accessibility / privacy / security audit.**

---

## 9. What to point Fable 5 at specifically (highest-judgment work in the app)

Per `docs/product-strategy.md` §5 — this phase is the densest concentration of judgment-heavy, hard-to-redo work:
- **Design the LEAF-Q scoring + under-fueling signal thresholds** from validated instruments (for clinician confirmation, not to replace it).
- **Calibrate the cycle-fueling advice to the evidence** — modest, individualized, correctly caveated; the hard part is *restraint*, not recall.
- **Author all safety copy** — supportive, non-triggering, diagnosis-free, correctly signposted.
- **Build the red-team Coach eval** for RED-S / disordered-eating / body-image inputs — the single highest-stakes AI-safety artifact in Crunch.

---

## Architecture concerns (flagged once)

1. **HealthKit dependency.** Cycle phase ideally reads from HealthKit; this phase must degrade to a minimal on-device manual entry without it. Don't let Phase 11 hard-block on the HealthKit phase — Layer 1 (the more important half) needs no cycle data at all.
2. **Special-category-data privacy.** Menstrual data is GDPR Art. 9 and post-*Dobbs* sensitive. Default: **on-device only, never synced.** This constrains the data model (§3) and is a deliberate, professional-grade posture — not an optimization.
3. **Clinical review is a real prerequisite.** RED-S screening built by devs + a model alone is a liability. Budget for a sports dietitian / RED-S specialist to validate logic and copy before ship; consider a named clinical advisor as both a safety measure and a credibility asset (the axis Hexis/PF&H compete on).
4. **Evidence modesty.** Cycle-based periodization is individualized and still maturing; the **RED-S safety layer is the higher-value, higher-certainty piece.** If time is constrained, ship Layer 1 alone — it stands on its own and is the differentiator.
5. **Keep it out of `MacroEngine`.** Cycle nudges stay as visible, optional adjustments — not silent engine rewrites. This avoids the two-engine-divergence class of bug (audit §2) and keeps the advice honest.
6. **Ties to the weight-validation thread.** "Weight as an under-fueling *signal*" lives here (Layer 1), framed as fueling adequacy — **not** a weight tracker, never weight-management framing.
