# Phase 5 Implementation Plan — Onboarding & Conversion Funnel

> **Date:** 2026-07-03
> **Status:** Plan — not yet executed
> **Context:** Builds the AGENTS.md Phase 5 onboarding, but **replaces the 17-screen spec with the ~31-screen conversion funnel** in `docs/onboarding-and-growth.md` (grounded in Cal AI / RevenueCat research). Onboarding is the #1 conversion lever, so this phase is scoped for conversion, not just data collection.
> **Roadmap wrinkle (read §0.1):** the funnel puts a **hard paywall inside onboarding**, which pulls the RevenueCat purchase/trial work forward from Phase 9 into this phase.
> Verified against the as-built code and live DB.

---

## 0. Understanding check — what exists

- **Nothing in `Features/Onboarding/` is built.** `ContentView.swift:17` has the placeholder `// Phase 5 inserts: !hasCompletedOnboarding → OnboardingCoordinator`; today a signed-in user goes straight to `MainTabView`.
- **Today already computes portions live** from `MacroEngine` (pure, no network) in `TodayViewModel.load()` — it does **not** read stored `macro_targets`. So the checklist's "initial macro-target generation post-signup" is largely vestigial; the aha screen can compute a plan client-side with zero backend.
- **`users` currently gets only `clerk_id`/`email`** from `create-user-profile`; every biometric is null → the 70 kg fallback. This phase is what finally populates real biometrics (and makes the weight-validation work from the chat thread reachable).
- **Reusable pieces already exist:** `ClerkService.signUp/verifyEmail/signInWithApple/Google`, `AnthropicService.estimateMeal` (needs `x-clerk-token`), `StravaOAuthService`/`RunnaService` (signatures frozen for exactly this screen), `MacroEngine`/`PortionEngine`, `RevenueCatService` (configured, `identifyUser`/`isPro` unused), and the Mixpanel onboarding events (`onboarding_started/screen_viewed/completed` — **defined but never fired**).
- **`MixpanelService.identify()` is never called** (noted in Phase 8 plan) — funnel attribution depends on wiring it; do it here.

### 0.1 The paywall reorders the roadmap — decide this first

The conversion funnel's whole mechanism is a **hard paywall at the end of onboarding** (research: hard paywall converts ~5× freemium; Day 0 drives ~50% of conversions). That paywall *is* AGENTS.md Phase 9's `PaywallView` + RevenueCat purchase flow. Two options:

- **(A) Recommended — pull the paywall into Phase 5.** Onboarding cannot convert without it; a soft/no-gate onboarding leaves the single biggest revenue lever on the floor. Phase 5 absorbs `PaywallView` + trial-start + entitlement check. Phase 9 keeps only **restore-purchases, archive, TestFlight**.
- (B) Ship onboarding now with a stub "Continue" where the paywall goes, add the hard paywall when Phase 9 lands. Faster to a testable flow, but you validate the funnel *without its converting mechanism* — low-signal.

**This plan assumes (A).** If you choose (B), §4's `PaywallStep` becomes a stub and §Architecture #1 is the switch-back note.

### 0.2 The load-bearing constraint: the auth boundary

Screens 1–27 are **anonymous** (no Clerk session yet — account creation is screen 28). Therefore **everything before account creation must be client-side, pure, or templated** — no `estimate-meal`, no `coach-respond`, no DB writes (they all need `x-clerk-token`). Consequences, designed for below:
- The **aha plan reveal (screen 20)** uses `MacroEngine` (pure) → daily targets + representative portions. Real per-meal portions come *after* signup.
- The **coach preview (screen 22)** is a **locally-templated** message string-interpolated from their race + meals — **not** a live Claude call. (Also better: instant, free, controlled.)
- All network + auth + DB work is **batched immediately after account creation** (screen 28), then `has_completed_onboarding` flips.

Getting this wrong = calling `estimate-meal` with no token mid-funnel and showing a broken aha. It's the #1 failure mode (§5).

---

## 1. Architecture — template-driven, not 31 hand-built screens

AGENTS.md lists `Screen01…Screen17` as separate files. **Deliberately diverging:** a ~31-screen funnel that Cal AI-style optimization will reorder and A/B test (they ran 123 experiments) must be **data-driven**, not 31 bespoke files. Structure:

- **`OnboardingCoordinator.swift` — NEW `@Observable @MainActor`.** Single source of truth: holds **all** answers, the ordered `[OnboardingStep]`, current index, `NavigationStack` path, computed progress, and `advance()`/`back()`. Every screen binds to the coordinator — no `@State` answer storage (that's how back-navigation loses data → failure mode 2).
- **`OnboardingStep.swift` — NEW enum**, the ordered funnel (the one place screen order lives — reorder here to A/B test).
- **Reusable screen views (NEW):** `InfoScreen` (hook/problem/social-proof/how-it-works), `SingleSelectScreen` (goal, race type, sex, training level, fueling self-assessment — auto-advance 0.3 s), `WheelPickerScreen` (age/weight/height — `.pickerStyle(.wheel)`, **unit-aware + range-bounded**), `MultiSelectScreen` (activities), `TextEntryScreen` (race name, meals — `TextEditor`), `DatePickerScreen` (race date, future-validated), `TestimonialScreen`.
- **Bespoke screens (NEW):** `BuildingPlanScreen` (animated loading + rotating proof-points), `PlanRevealScreen` (aha — `MacroEngine`), `ReadinessChartScreen`, `CoachPreviewScreen` (templated), `ConnectAppsScreen` (reuses Strava/Runna services), `CreateAccountScreen` (reuses `ClerkService`), `PaywallScreen` (RevenueCat), `NotificationPrimingScreen`.
- **`OnboardingProgressBar.swift` — NEW** (hidden on hook/aha/paywall per spec intent).
- **`OnboardingContainerView.swift` — NEW** — `NavigationStack(path:)` driven by the coordinator, renders the view for the current step.

~31 screens from ~8 reusable + ~8 bespoke views. Reorder/copy-test by editing `OnboardingStep`, not by moving files.

---

## 2. The funnel → steps (maps `docs/onboarding-and-growth.md` Part 1)

| # | Step | Screen type | Writes to coordinator | Backend? |
|---|---|---|---|---|
| 1 | Splash/promise | Info | — | none |
| 2 | Social proof | Info (Testimonial) | — | none |
| 3 | The problem | Info | — | none |
| 4 | Goal | SingleSelect | `goal` | none |
| 5 | Race type | SingleSelect | `raceType` | none |
| 6 | Race name + date | TextEntry + DatePicker | `raceName`, `raceDate` | none |
| 7 | Hook ("98 days") | Info (dynamic) | — | none |
| 8 | Biological sex | SingleSelect | `gender` | none |
| 9–11 | Age / Weight / Height | WheelPicker | `age`,`weightKg`,`heightCm` | none |
| 12 | Training level | SingleSelect | `trainingLevel` | none |
| 13 | Days/week running | WheelPicker/Select | `runDaysPerWeek` | none |
| 14 | Other activities | MultiSelect | `weeklyActivities` | none |
| 15 | Fueling self-assessment | SingleSelect | `fuelingProfile` (seeds Ph10/11) | none |
| 16–18 | Breakfast/Lunch/Dinner | TextEntry | `meals[]` (text only) | none |
| 19 | Building plan | BuildingPlan | — | none (theatre) |
| 20 | **Plan reveal (aha)** | PlanReveal | — | `MacroEngine` (pure) |
| 21 | Readiness chart | ReadinessChart | — | `MacroEngine` (pure) |
| 22 | Coach preview | CoachPreview | — | **templated string** |
| 23 | Connect Strava/Runna | ConnectApps | `stravaPending`… | post-auth defer* |
| 24 | Testimonials | Testimonial | — | none |
| 25 | How Crunch works | Info | — | none |
| 26 | Notification priming | Info (soft ask) | `wantsPush` | none |
| 27 | Commitment reinforce | Info | — | none |
| 28 | **Create account** | CreateAccount | — | Clerk + `create-user-profile` + **batch write** |
| 29 | **Paywall (hard)** | Paywall | — | RevenueCat trial start |
| 30 | One-time offer (decline) | Paywall variant | — | RevenueCat |
| 31 | Push permission (OS) → Today | — | — | `UNUserNotificationCenter` |

*Connecting Strava/Runna at 23 needs auth. Since account creation is 28, either (a) move the *actual* OAuth to just-after-signup and show 23 as "we'll connect these next," or (b) allow "connect later" and surface it in the post-signup batch / Settings. **Recommend (a):** collect intent at 23, run the OAuth right after account creation. Note in the flow.

---

## 3. Data & submission

**`CRUNCH/Services/OnboardingSubmitService.swift` — NEW.** Orchestrates the post-account-creation batch (the auth boundary crossing), idempotent + resumable:
1. `create-user-profile` (existing, `x-clerk-token`) → `users` row.
2. `UPDATE users` set biometrics (`weight_kg`,`height_cm`,`age`,`gender`,`training_level`,`weekly_activities`) + `primary_goal` + `fueling_profile` (via RLS authenticated client).
3. `INSERT races` (active) keyed by UUID `users.id`.
4. For each meal: `estimate-meal` (now authed) → `INSERT meals` (soft-fail per meal → save with nil macros, matching `AddEditMealView`).
5. (If Strava/Runna intent) run OAuth / save iCal.
6. Set `has_completed_onboarding = true` **only after 1–4 succeed** (5 is best-effort).

**Migration `2026XXXX_onboarding_fields.sql` — NEW:** `ALTER TABLE users ADD COLUMN primary_goal text`, `ADD COLUMN fueling_profile jsonb`. (Coarse, non-sensitive; `fueling_profile` seeds the gut-training/RED-S phases.) No other schema change — races/meals/biometrics all use existing columns.

**Initial macro target:** not required — Today computes live via `MacroEngine`. Skip unless/until a surface reads stored `macro_targets` for a session-less user.

---

## 4. Paywall (pulled from Phase 9 — see §0.1)

**`CRUNCH/Features/Onboarding/PaywallScreen.swift` + `Features/Paywall/PaywallView.swift` — NEW.**
- Annual hero ($89.99 + 7-day trial) anchored above Monthly ($14.99); benefits; social proof; "cancel anytime" (pricing per `onboarding-and-growth.md` Part 3).
- Purchase via `RevenueCatService` (add `purchase(package:)` + `startTrial`); on success set `pro` entitlement, `MixpanelService.track(.subscriptionStarted…)`.
- **Decline → one-time offer (step 30)** then continue (trial not mandatory to *enter*, per AGENTS.md "all features accessible during trial"; but this is the hard-paywall moment — the offer is the recovery).
- **`RevenueCatService.swift` — MODIFIED:** add purchase/trial methods (currently only entitlement read exists). Public SDK key only.

---

## 5. Top silent-failure modes

1. **Crossing the auth boundary early.** Any `estimate-meal`/`coach-respond`/DB call before step 28 has no token → fails, breaks the aha. Mitigation: §0.2 discipline — pre-auth screens are pure/templated; a code-review checklist item asserts no authed call is reachable before `CreateAccountScreen`.
2. **State lost on back-navigation.** An answer stored in a screen's `@State` instead of the coordinator vanishes when the user goes back. Mitigation: coordinator is the sole store; screens bind to it; test back-nav from step 27 preserves everything.
3. **Partial batch write → half-onboarded ghost.** If step 3 (batch) fails mid-way, the user has an account but no race/meals and `has_completed_onboarding` half-set. Mitigation: `OnboardingSubmitService` is idempotent/resumable; the flag flips only on full success; `ContentView` resumes an incomplete onboarding rather than dumping them into gated tabs (§Architecture #4).
4. **Generic-looking aha.** If a biometric was skippable and fell back to defaults, the "personalized" plan at step 20 looks canned and the funnel dies at its most important screen. Mitigation: biometrics (8–12) are required (picker, no skip); validate before reveal.
5. **Paywall traps a failed purchase.** Purchase error or cancelled trial must not strand the user. Mitigation: graceful continue on failure (they land in the app in trial-or-limited state), retry available; never a dead end.
6. **Weight unit confusion** (from the chat thread): 160 lb entered as kg → 2× macros → wrong aha. Mitigation: `WheelPickerScreen` is unit-aware and converts to `weight_kg`; range-bounded.

---

## 6. Security / privacy checklist

- [ ] No authed endpoint (`estimate-meal`, `coach-respond`, DB writes) reachable before account creation (§0.2).
- [ ] Batch writes go through the RLS Clerk-JWT client; `create-user-profile` via `x-clerk-token` (existing pattern).
- [ ] RevenueCat public SDK key only; no secret key client-side.
- [ ] No `print()`/logging of email, biometrics, or tokens in any onboarding file; `os_log .private`.
- [ ] `fueling_profile`/`primary_goal` are coarse and non-sensitive; no free-text health data synced without review (ties to Phase 11 privacy posture).
- [ ] Mixpanel `identify` sends Clerk id only — biometrics never as event properties.
- [ ] Re-run the AGENTS.md 11-rule audit as the phase gate.

---

## 7. Test steps

**On device:**
1. Full funnel splash→Today; `OnboardingProgressBar` shows on quiz screens, hidden on hook/aha/paywall.
2. Single-selects auto-advance (0.3 s); pickers are `.wheel`; weight picker in imperial stores correct `weight_kg` (failure mode 6).
3. Back-navigate from step 27 to step 4 and forward again — **every answer intact** (failure mode 2).
4. Aha (20) shows numbers that visibly reflect *their* inputs (change weight in a re-run → plan moves); coach preview (22) names their race + a meal — with **no network call** (failure mode 1/4).
5. Create account (email + verify, and Apple/Google) → batch write completes → Supabase shows `users` biometrics, `races` row, `meals` (estimated) — **all present** (failure mode 3).
6. Strava/Runna intent at 23 → OAuth runs post-signup → `integrations` row.
7. Paywall: annual/monthly render; start trial in **StoreKit + RevenueCat sandbox** → `pro` active → lands on Today with live plan. Decline → one-time offer → continue without trapping (failure mode 5).
8. Kill the app mid-batch (airplane mode at step 28) → relaunch → onboarding **resumes**, not gated-tab dump (failure mode 3 / Architecture #4).
9. Notification priming (26) soft-ask → OS prompt (31) → token stored.
10. Mixpanel: `onboarding_started`, `onboarding_screen_viewed` (per screen), `onboarding_completed`, `subscription_started` all fire, attributed to the Clerk id (identify wired).
11. Accessibility: labels on every control, 44 pt targets, Dynamic Type, contrast; VoiceOver walk of the funnel.
12. Security 11-rule audit + §6.

---

## 8. Sequencing

1. **Coordinator + `OnboardingStep` + container + progress bar + reusable screen templates** (skeleton; nav works end-to-end with placeholder content).
2. **Acts 1–3** (steps 1–18) — all client-side, no backend.
3. **Act 4 aha** (19–23) — `PlanReveal`/`ReadinessChart` via `MacroEngine`, templated `CoachPreview`, `ConnectApps` intent.
4. **`OnboardingSubmitService` + `CreateAccountScreen` + migration** — the auth-boundary crossing; test batch write against a throwaway user before wiring the paywall.
5. **Paywall + RevenueCat purchase/trial** (§0.1 merge) — sandbox test.
6. **Notification priming + OS prompt + route to Today.**
7. **Analytics** (identify + funnel events) + **`ContentView` routing** (onboarding / resume-incomplete / main).
8. **Tests (§7) + accessibility + security audit.**

---

## 9. What to point Fable 5 at specifically

- **The aha screens (20–22) copy + the templated coach-preview generator** — the highest-conversion, most-personalized moment; getting the string interpolation to feel individually written is judgment work.
- **Funnel copy across all 31 screens** — aspirational/race-anchored, brand-safe (no `deficit`/`weight loss`/`compliance`), high-converting.
- **The A/B-test scaffolding** — structure `OnboardingStep` + a remote-config or Superwall/RevenueCat paywall hook so screen order, copy, trial length, and price can be tested without a release (Cal AI's 123-experiment advantage).

---

## Architecture concerns (flagged once)

1. **Paywall merge reorders the roadmap** (§0.1). Phase 9 shrinks to restore-purchases + archive + TestFlight. Update AGENTS.md's phase list so the next session doesn't rebuild the paywall.
2. **Template-driven screens diverge from the spec's `Screen01…17` files** — deliberate, to enable A/B reordering. Note it in AGENTS.md.
3. **Auth boundary (§0.2)** is the load-bearing design constraint — the pre-auth/post-auth split must survive future edits; keep the "no authed call before step 28" rule visible in code comments.
4. **New app state: incomplete onboarding.** `ContentView` currently has two states (session or not). It now needs three: no session → splash/onboarding; session + `!has_completed_onboarding` → **resume onboarding**; session + completed → main tabs. The resume path is new and easy to forget (failure mode 3).
5. **`estimate-meal` cost at signup scale** — 3+ Claude calls per new user in the batch. Fine now; if signups spike, consider batching into one call or deferring estimation to first Today load. Minor.
6. **Ties to prior threads:** steps 9–11 are where the **weight-validation** work lands; steps 4 & 15 (`goal`, `fueling_profile`) seed **Phase 10 (gut training)** and **Phase 11 (RED-S)**. Collect them cleanly now so those phases have data.
7. **Trial length is a revenue lever** — research says 14–32-day trials convert ~70% better than <4-day. AGENTS.md fixes 7 days; make trial length a testable config (§9), not a hardcode.
