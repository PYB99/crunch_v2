# Crunch Audit Report — Phases 1–7

> **Date:** 2026-07-03
> **Scope:** Read-only audit of the repo + live Supabase project (`ryswtwcgzhmkmgzcklyx`) against AGENTS.md v3.0.
> **Method:** Verified repo, live DB schema/RLS/cron, and deployed Edge Functions. Nothing modified.
> **Next step:** Sonnet 4.6 executes fixes from the prioritized list, one item at a time (plan → review → execute).

Build succeeds (exit 0) with 12 warnings. All 6 documented Edge Functions match their deployed source byte-for-byte. Headline problems: **two macro engines that compute different numbers for the same day**, **empty base-schema migrations** (the live DB can't be rebuilt from the repo), and **two orphaned Edge Functions from the deleted check-in product still deployed live**.

---

## 1. Spec-vs-reality drift

AGENTS.md's schema tables are stale relative to the live DB. The Swift models track the *live* DB (good), so the spec is what's wrong — but anyone trusting the spec will be misled.

| Table | AGENTS.md says | Live DB actually has | Severity |
|---|---|---|---|
| `training_sessions` | `duration_minutes`, `provider_activity_id`, `completed` (bool) | `duration_mins`, `strava_activity_id`, `status` (text), plus `runna_uid`, `perceived_exertion` | Moderate |
| `macro_targets` | `calories`, `session_type`, `training_phase`, `carbs_g numeric` | `calories_kcal`, `target_type`, `session_id`, **no** `training_phase`/`session_type`, `carbs_g integer` | Moderate |
| `integrations` | `access_token_encrypted`, `refresh_token_encrypted`, `runna_uid`, `updated_at` | `access_token`, `refresh_token`, `connected_at` (no `updated_at`, no `runna_uid`) | Moderate |
| `users` | (no push field) | `apns_device_token` added (Phase 7) | Minor (spec not updated) |
| `races` | no uniqueness noted | partial unique index `races_single_active_per_user_idx` (one active race/user) | Minor |

- **Build config contradicts three "final" architecture decisions.** `IPHONEOS_DEPLOYMENT_TARGET = 26.5` (spec: **iOS 17**), `SWIFT_VERSION = 5.0` (spec: **Swift 6**). The app currently won't install below iOS 26.5 and is not in Swift 6 language mode. `project.pbxproj:441,456`. **Severity: Critical** (deployment target) — *needs your decision* (may be intentional for a 2026 launch, but directly violates spec).

Fix owner: doc updates — Sonnet can fix. Deployment-target/Swift-version — needs your decision.

## 2. Cross-phase duplication

**The two macro engines disagree.** `CRUNCH/Engines/MacroEngine.swift` (drives Today/Week live) and `supabase/functions/_shared/macroEngine.ts` (writes `macro_targets` from Strava/Runna) implement the same algorithm differently, so the portions shown on Today can differ from what got stored server-side for the same session:

- **TDEE multiplier keyed on different variables.** Swift keys on *session type* (rest 1.2 … long/race 1.9) — matches spec. TS keys on *training level* (beginner 1.4 / intermediate 1.55 / advanced 1.725) and ignores session type entirely. Completely different calorie/fat outputs. `MacroEngine.swift:108`, `macroEngine.ts:26`.
- **Phase boundaries differ.** Swift: taper = 1–3 wks, race week = 0. TS: taper = 3–4 wks, race week = ≤2. At 4 weeks out Swift says Peak, TS says Taper; at 2 weeks Swift says Taper, TS says Race Week. `MacroEngine.swift:82`, `macroEngine.ts:76`.
- **Race carbs differ from each other and spec.** Spec = 10 g/kg. Swift `carbsPerKg(race)=10` ✓ but race-week forces 11 for all sessions; TS `CARBS_PER_KG.race = 11` ✗. `MacroEngine.swift:119`, `macroEngine.ts:14`.
- **Fallback height differs**: Swift 175 cm (spec), TS 170 cm. `macroEngine.ts:36`.

**Severity: Moderate–Critical** (user sees inconsistent numbers). *Needs your decision* on which engine is canonical, then Sonnet reconciles.

- **Two portion-indicator mechanisms.** `DayRowView.portionArrow/portionLabel/portionColor` (`DayRowView.swift:47-72`) derive Double/Extra/Normal/Lighter straight from session type, while the same view's *expanded* rows call `PortionEngine` (multiplier→level). The compact badge and the detailed rows can disagree. Today tab uses `PortionEngine` only. **Moderate.** Sonnet can unify.
- **`authenticatedClient()` built two ways.** `SupabaseService.authenticatedClient()` (actor, uses `MainActor.run`) vs `AnthropicService.makeAuthenticatedClient()` (private duplicate that exists specifically to avoid the actor hop, per its comment). Redundant client construction in ~6 call sites. **Minor.** Sonnet can consolidate.

## 3. Dead / orphaned code

- **Two orphaned Edge Functions deployed but not in repo or spec:** `checkin-diagnose` and `progress-patterns`. Both are from the **deleted structured-check-in product** ("Coach tab replaces structured check-in flow"; "What NOT to include: Structured check-in modal"). Their live `entrypoint_path` still points at the old repo `/Users/PrakashBhagat/CRUNCH-main/…`, they read `SUPABASE_SERVICE_KEY` (wrong var name — everything else uses `SUPABASE_SERVICE_ROLE_KEY`), and they call `supabase.auth.getUser()` which cannot work with Clerk JWTs. Dead and unreachable. **Moderate** (attack surface + confusion). *Needs your decision* to delete (deploy action).
- **Stale RN reference:** `macroEngine.ts:2` — `// Keep constants in sync with constants/nutrition.ts in the React Native app.` The RN app is gone. **Minor.** Sonnet can remove the comment.
- **Debug `print`s left in production views:** `WeekView.swift:194` and `NutritionView.swift:97` both `print("DEBUG: … body entered")` on every render; `AnthropicService.swift:40` prints raw Edge Function error bodies to stdout. **Minor.** Sonnet can delete.
- **Template test file:** `CRUNCHTests/CRUNCHTests.swift` is the empty Xcode stub (`@Test func example` does nothing). **Minor.** Sonnet can delete.
- **`MainTabView.placeholderTab(...)`** (`MainTabView.swift:44`) is now unused (real tabs wired). **Minor.**

## 4. RLS and auth consistency

Good news: **no table still checks `auth.uid()` against a Clerk JWT.** RLS is enabled on all 8 tables. `requesting_user_id()` reads `request.jwt.claims->>'sub'`. Text-keyed tables (`meals`, `coach_*`) use `requesting_user_id() = user_id`; UUID-keyed tables (`races`, `training_sessions`, `macro_targets`, `integrations`) use the `clerk_id → users.id` subquery. All 6 in-repo Edge Functions consistently use the `x-clerk-token` header pattern. The two orphaned functions (§3) do **not** — another reason they're dead.

- **Duplicate RLS policies on coach tables.** `coach_conversations` and `coach_messages` each carry **two** permissive ALL policies: the migration's `"Users manage own conversations/messages"` (no `WITH CHECK`) *and* an out-of-band `"*_manage_own"` (with `WITH CHECK`). Functionally OR'd so access still works, but redundant and confusing, and the `_manage_own` versions exist only in the live DB (see §9). **Moderate.** Sonnet can drop the duplicates via a migration once you confirm which to keep.

## 5. Edge Function repo/deploy parity

Downloaded all 8 deployed functions and diffed. The 6 documented ones (`strava-webhook`, `strava-oauth`, `runna-sync`, `coach-respond`, `estimate-meal`, `create-user-profile`) plus `_shared/*` match the repo **byte-for-byte**. The only parity gaps are the two orphans in §3 (deployed, not in repo). No in-repo function is un-deployed. **Clean, aside from §3.**

## 6. Concurrency & lifecycle

- **`SupabaseService` actor touches MainActor-isolated state (Swift-6-blocking).** With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target, `Constants.supabaseURL`/`supabaseAnonKey` are MainActor-isolated, but the `SupabaseService` *actor* reads them in `init`/`authenticatedClient()`. Build warns 4× "main actor-isolated static property can not be referenced from a nonisolated context" and 2× "expression is 'async' but is not marked with 'await'; this is an error in the Swift 6 language mode" (`SupabaseService.swift:16,17,32`). These are exactly the class of bug flagged in Phase 7 and **will break the build the moment Swift 6 mode is turned on** (which the spec mandates). **Moderate–Critical.** Sonnet can fix (mark `Constants` `nonisolated`, or make the service `@MainActor`).
- **Unstructured cooldown `Task` not cancelled.** `CoachViewModel.sendMessage` spawns a detached `Task { … sleep(2s); isCooldown = false }` (`CoachView.swift:135`) with no handle; a rapid send + view teardown leaves it running. Low impact (`[weak self]`, MainActor), but it's the pattern to watch. **Minor.**
- The Realtime lifecycle in `TodayViewModel` (`stopRealtimeSubscription` from `onDisappear`, `[weak self]` in the listen loop) is handled correctly — no deinit-isolation bug here.

## 7. Spec-compliance (UI / copy / interaction)

- **Settings button dead on 3 of 4 tabs.** Spec: "Settings `.toolbar` button top-right on **every** tab." Only Today wires it; Week/Nutrition/Coach have gearshape buttons with `// Phase 8: push SettingsView` no-ops (`WeekView.swift:213`, `NutritionView.swift:116`, `CoachView.swift:187`). **Moderate.** Sonnet can wire (Settings shell exists).
- **Confirmation-pattern mismatch:** spec says delete-meal uses `.swipeActions(.destructive) + .alert`; implementation uses a **context menu** + alert (`MealLibraryView.swift`), no swipe action. **Minor.** Your call whether to match spec.
- **Copy drift:** real portion label is "Double portion today" (`PortionResult.swift`) but spec/mockup say "Double portion **tonight**" for dinner; `MealCardView` preview hardcodes "tonight". Cosmetic inconsistency. **Minor.**
- **`Color(hex:)` silent fallback to yellow** on malformed hex (`Theme.swift`) — not hit today, but any bad token renders yellow instead of failing. **Minor.**
- Touch targets (44pt), accessibility labels on portion dots/meal cards/coach bubbles, dark-mode tokens, `.confirmationDialog` vs `.alert` for integrations disconnect — all present and correct.

## 8. Build health

Clean build, exit 0, **12 warnings**:
- 6× MainActor-isolation / async warnings in `SupabaseService.swift` (§6) — the serious ones.
- 4× `Text(_:) + Text(_:)` "'+' deprecated in iOS 26" — `SplashView.swift:51`, `SignInView.swift:143`, `SignUpView.swift:177`, `TodayView.swift:727`.
- 2× "result of 'try?' is unused" — `ClerkService.swift:78`, `ContentView.swift:41`.

No errors, no force-unwraps/force-casts in app code (`try!`/`as!` = none), no suppressed warnings. Sonnet can clear all 12.

## 9. Migrations vs live DB — **most serious structural gap**

`supabase migration list` shows all 6 local migrations applied remotely, **but the two base migrations are 0 bytes:**
- `20260526170000_initial_schema.sql` — **empty**
- `20260527000001_initial_data.sql` — **empty**

Everything foundational — all 8 tables and their columns, `requesting_user_id()`, every unique index (`macro_targets_user_date_idx`, `integrations_user_provider_idx`, the Strava/Runna partial indexes, `races_single_active`), the original `_manage_own` RLS policies, and the duplicate coach policies from §4 — **exists live with no migration source.** A fresh `supabase db reset` would not reproduce this database. Schema drift is effectively total for the base layer. **Severity: Critical.** *Needs your decision* — Sonnet can `db pull`/`db diff` to backfill a baseline migration, but you should confirm the approach before it writes migration files against a live project.

## 10. Secrets & security

Clean. `Secrets.xcconfig` is gitignored and untracked (confirmed via `git ls-files`); only public values in `Constants.swift` (Supabase URL, Strava client ID, Mixpanel token, RC entitlement) — all safe-to-commit. Secret values injected via Info.plist build settings. No secrets in git history (single "Initial Commit", secrets file never tracked). Strava tokens are AES-GCM encrypted at rest (`token-crypto.ts`, encrypt on write in `strava-oauth`, decrypt only server-side); the client's `Integration` model deliberately omits token columns. Runna's plaintext iCal URL in `access_token` is the one documented exception, unchanged. Anthropic key server-side only.

---

## Prioritized fix list (hand to Sonnet one item at a time)

### Critical
1. **Reconcile the two macro engines** (`MacroEngine.swift` ↔ `_shared/macroEngine.ts`): TDEE basis, phase boundaries, race carbs, fallback height. *Decide canonical engine first.* (§2)
2. **Backfill base-schema migrations** so the repo can rebuild the live DB (`db pull`/`db diff` into the two empty files). *Confirm approach first — live project.* (§9)
3. **Fix `SupabaseService` MainActor-isolation warnings** before enabling Swift 6; then decide whether to actually move to `SWIFT_VERSION = 6` and reconcile `IPHONEOS_DEPLOYMENT_TARGET`/`SWIFT_VERSION` with spec. (§6, §1)
4. **Delete orphaned `checkin-diagnose` + `progress-patterns` Edge Functions** (deploy action). (§3)

### Moderate
5. Drop duplicate coach-table RLS policies via migration (confirm keep `_manage_own`). (§4)
6. Fix the TS `rest_day`-vs-`rest` key mismatch so Runna rest days get 4 g/kg, not easy-run 6 g/kg (`macroEngine.ts:8,41`). (§2)
7. Unify `DayRowView`'s badge with `PortionEngine`. (§2)
8. Wire the Settings button on Week/Nutrition/Coach. (§7)
9. Update AGENTS.md schema tables (`training_sessions`, `macro_targets`, `integrations`, `users`) to match live. (§1)

### Minor
10. Remove debug `print`s (`WeekView:194`, `NutritionView:97`, `AnthropicService:40`).
11. Clear the 6 remaining build warnings (deprecated `Text +`, unused `try?`).
12. Delete template `CRUNCHTests/CRUNCHTests.swift` and unused `MainTabView.placeholderTab`.
13. Consolidate the duplicate `authenticatedClient` construction. (§2)
14. Remove stale RN comment (`macroEngine.ts:2`); align "today/tonight" portion copy; harden `Color(hex:)` fallback.

---

## Appendix — Coverage & method

**Read line-by-line:** all Swift source under `CRUNCH/` (app, Core, Services, Engines, Models, Components, all Feature views incl. Auth/Today/Week/Nutrition/Coach/Settings), both engine test files, `CRUNCHApp`/`ContentView`; all 8 Edge Functions + `_shared/*` (`token-crypto.ts`, `apns.ts`, `macroEngine.ts`); all 6 migration files; `Info.plist`, `.gitignore`, `Constants.swift`, and the relevant `project.pbxproj` build settings.

**Verified against the live project** (`ryswtwcgzhmkmgzcklyx`, via Management API + `supabase` CLU): full column list for all 8 tables, every RLS policy + `requesting_user_id()` source, RLS-enabled flags, all unique indexes/constraints/FKs, the realtime publication, the cron job, and a byte-for-byte diff of every deployed Edge Function against the repo.

**Confirmed clean on close read (no findings):** `token-crypto.ts` is correct AES-GCM (random 12-byte IV per op, prepended, GCM tag retained) — §10 holds. `apns.ts` ES256 provider-JWT signing is correct and properly stub-gated (one *marginal* note: the provider JWT is minted fresh per push with no ~1 h reuse/caching — irrelevant at current volume/stub status, revisit if push traffic grows). Coach UI views, `ScienceCardView`, and `ForgotPasswordView` are spec-compliant (accessibility labels, 44 pt targets, client-side max-length enforcement).

**Not exercised:** no runtime/device testing (static audit only); UI test targets (`CRUNCHUITests/*`) were counted, not run; `docs/` reference material and image assets were not reviewed for content.
