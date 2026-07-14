# Phase 8 Implementation Plan — Settings & Polish

> **Date:** 2026-07-03
> **Status:** Plan — not yet executed
> **Context:** Phases 1–4, 6, 7 built. Phase 5 (17-screen onboarding) intentionally deferred.
> Phase 7 is code-complete but not yet E2E-verified on device (real-Strava-run test pending);
> anything downstream of that test is provisional. Verified against the as-built code, not the
> original spec's assumptions.

---

## 0. Understanding check: Phase 8 scope vs. what Phases 5/7 actually delivered

Verified against the repo:

- **`SettingsView.swift` is a minimal shell** — a single-row `List` pushing `IntegrationsView`, with a comment explicitly deferring the rest to Phase 8. It is the starting point, not a from-scratch build.
- **Only TodayView's gear button actually pushes Settings** (`TodayView.swift:431` via `.navigationDestination`). WeekView (`:213`), NutritionView (`:116`), and CoachView (`:187`) have literal `// Phase 8: push SettingsView` placeholder comments. Wiring those three is unstated but required Phase 8 work.
- **`user_id` keying is split across tables and differs from the AGENTS.md schema section**: `meals`, `coach_conversations`, `coach_messages` key on **Clerk text id**; `races`, `training_sessions`, `macro_targets`, `integrations` key on **UUID FK → `users.id`**; `users` itself keys on `clerk_id`. The delete-account function must handle both keying schemes. Also note the two earliest local migration files (`20260526...`, `20260527...`) are **0 bytes** — the live DB is the only source of truth for the full table list.
- **`MixpanelService.identify()` and `.reset()` are implemented but never called anywhere**, and the same is true of `RevenueCatService.identifyUser()`/`resetUser()`. All Mixpanel events fired to date are anonymous.

Places where Phase 8's checklist assumes something that doesn't exist yet — flagged, not silently planned around:

| Phase 8 checklist item | Assumption that doesn't hold | Disposition |
|---|---|---|
| "VoiceOver: audit Today, Coach, **onboarding**" | Onboarding (Phase 5) intentionally not built | Onboarding portion **deferred** to Phase 5. Audit Today + Coach + new Settings screens now. |
| "Full regression: splash → **onboarding** → all tabs → …" | Same | **Rewritten** in §6 to route around onboarding via a seeded-in-app user (sign-up + RaceEditView + Nutrition tab meals + PersonalInfoView stand in for screens 1–17). |
| "Mixpanel: verify events in dashboard" | Onboarding funnel events (`onboarding_started/screen_viewed/completed`) have no trigger; `identify()` never wired, so existing events aren't attributed | Non-onboarding events verified now; **wiring `identify`/`reset` added to this phase's scope** (prerequisite for meaningful verification). Onboarding funnel **deferred**. |
| Settings spec row "Notifications — On/Off" | Real APNs delivery is not live (.p8 key, secrets, entitlement outstanding — user-side items); `_shared/apns.ts` self-guards and no-ops | NotificationsView is built and tested against **permission status + local notifications** only. Delivery verification **provisional** until APNs setup lands. |
| Settings spec row "Subscription — Active / Trial / Upgrade" | Paywall + restore purchases are Phase 9 | Row shows entitlement **status only** (from `RevenueCatService.isPro`); Upgrade action is a disabled/`Phase 9` stub. |
| "Every screen works. No known bugs." (exit criteria) | Phase 7 post-run pipeline (webhook → Realtime → recalc → push → auto-message) is code-complete but not E2E-verified | Anything downstream of the real-Strava-run test is **provisional**; Phase 8 does not re-test it, only avoids breaking it (see §7). |
| Universal Behaviors: SwiftData offline cache, `NWPathMonitor` | **Never implemented in any phase** (zero references in the codebase) | Not silently pulled into Phase 8 — raised in Architecture concerns as an explicit scope decision, since Phase 8 is the last "polish" gate before TestFlight. |

Additional spec-vs-reality note: the spec's Settings table implies a persisted "Notifications On/Off" preference, but no such column exists — only `users.apns_device_token` (added by migration `20260703000002`). The plan treats "off" as *permission denied OR device token cleared*, using token null-out as the app-level opt-out. No new migration needed.

---

## 1. Checklist mapping

Phase 8 checklist from AGENTS.md, in dependency order within the phase:

| # | Item | Depends on | Builds on existing? | Phase 5 / push-E2E impact |
|---|---|---|---|---|
| 1 | Wire remaining gear buttons (Week/Nutrition/Coach) *(implied by "all settings views")* | nothing | **Extends** existing per-tab `NavigationStack` + `.navigationDestination` pattern from TodayView. No new router — `AppRouter` untouched. | none |
| 2 | SettingsView full row list per spec | nothing | **Extends existing shell** — keeps the working IntegrationsView link | Subscription row = status stub (Phase 9) |
| 3 | UnitsView | 2 | new, pushed from shell | none |
| 4 | PersonalInfoView | 2, 3 (reads `users.units` for picker units) | new | Becomes edit-only fallback once onboarding writes these fields — see §7 |
| 5 | RaceEditView (create + edit) | 2 | new | **Doubles as the onboarding stand-in** for race creation in regression; revisit copy once Phase 5 exists |
| 6 | NotificationsView | 2; small `PushNotificationService` addition | new; **reuses** existing `PushNotificationService` (do not duplicate its permission/registration logic) | **Provisional** — verifies permission + token storage, not APNs delivery |
| 7 | AccountView (email, sign out, delete) | 2, 8 | new | none |
| 8 | Delete account: Supabase data + Clerk delete + sign out | new Edge Function | **Reuses** the established `x-clerk-token` V2 pattern from `coach-respond`/`strava-oauth` `_shared` helpers | none |
| 9 | Mixpanel `identify`/`reset` + RevenueCat `identifyUser`/`resetUser` wiring *(prerequisite for the Mixpanel checklist item)* | nothing | **Extends** existing services — methods exist, call sites don't | Onboarding funnel events **deferred** |
| 10 | Dynamic Type verification | 1–7 done | audit pass, no new files | Onboarding screens deferred |
| 11 | VoiceOver audit (Today, Coach, + new Settings) | 1–7 done | audit pass | **Onboarding portion deferred to Phase 5** |
| 12 | iPhone SE + 15 Pro Max testing | 1–7 done | — | none |
| 13 | Mixpanel dashboard verification | 9 | — | Onboarding events deferred |
| 14 | Full regression | all | — | **Rewritten** — §6 |
| 15 | Final security audit (11 rules) | all | — | none |

`IntegrationsView`, `StravaOAuthService`, `RunnaService`, `AppRouter`, deep-link plumbing: **already done — nothing in this plan touches them** except adding rows/links around them. `StravaOAuthService`/`RunnaService` public signatures are frozen (Screen 15 call site pending).

---

## 2. File-level plan

### Settings screens

**`CRUNCH/Features/Settings/SettingsView.swift` — MODIFIED (extends existing shell)**
Replace the single-row body with the spec's 7-row `List`, preserving the existing dark styling (`.scrollContentBackground(.hidden)`, `Theme.card` row backgrounds) and the existing `IntegrationsView` push. Add a ViewModel for the right-detail values.

- `@Observable @MainActor final class SettingsViewModel`
  - `var user: User?`
  - `var activeRace: Race?`
  - `var stravaConnected: Bool`, `var runnaConnected: Bool`
  - `var notificationsAuthorized: Bool`
  - `var isPro: Bool` (read from `RevenueCatService.shared`)
  - `var isLoading: Bool`, `var errorMessage: String?`
  - `func load() async` — one authenticated client; reads `users` (by RLS), `races` where `is_active`, reuses `StravaOAuthService.fetchStatus()` / `RunnaService.fetchStatus()`, `UNUserNotificationCenter.current().notificationSettings()`
- Rows → `NavigationLink` per spec table: My Race (race name detail) → `RaceEditView`; Personal Info (height/weight summary) → `PersonalInfoView`; Integrations (Strava/Runna status) → existing `IntegrationsView`; Notifications (On/Off) → `NotificationsView`; Units (Metric/Imperial) → `UnitsView`; Subscription (Active/Trial — **status-only, Phase 9 stub**); Account (email) → `AccountView`.
- Reads from: `SupabaseService`, `StravaOAuthService`, `RunnaService`, `RevenueCatService`, `UNUserNotificationCenter`. Writes: nothing.
- `.task { await viewModel.load() }` **re-runs a lightweight refresh on re-appear** so detail rows update after child-screen edits (see failure mode 1).

**`CRUNCH/Features/Settings/RaceEditView.swift` — NEW**
Edit the active race, or create one if none exists (this is the onboarding stand-in path).

- `@Observable @MainActor final class RaceEditViewModel`
  - `var race: Race?`, `var raceName: String`, `var raceType: String`, `var raceDate: Date`
  - `var isSaving: Bool`, `var errorMessage: String?`, `var validationError: String?`
  - `func load() async`
  - `func save() async -> Bool` — upsert into `races` keyed by **UUID `users.id`** (resolve via the same `users.select("id")` pattern `IntegrationsViewModel.load()` uses); sets `is_active = true`
- Validation per Universal Behaviors: name optional ≤100 chars; date required, future ("Pick a date in the future"), validate `.onChange`.
- UI: `TextField` + `DatePicker`, `PrimaryButton` with loading state, `ErrorBanner` on network failure.
- Reads/writes: `races` via `SupabaseService.authenticatedClient()`.

**`CRUNCH/Features/Settings/PersonalInfoView.swift` — NEW**

- `@Observable @MainActor final class PersonalInfoViewModel`
  - `var heightCm: Double`, `var weightKg: Double`, `var age: Int`, `var gender: String`, `var trainingLevel: String`, `var weeklyActivities: [String]`
  - `var units: String` (read-only here; edited in UnitsView — pickers render kg/lb, cm/ft-in accordingly)
  - `func load() async`
  - `func save() async -> Bool` — `UPDATE users SET height_cm, weight_kg, age, gender, training_level, weekly_activities, updated_at` (RLS scopes to own row via `clerk_id`)
- Pickers `.pickerStyle(.wheel)` for age 16–80 / weight / height, matching spec; gender + training level as single-select rows; weekly activities multi-select (same 6 options as ActivityToggleView).
- **No body-composition language anywhere** (copy rule).
- Reads/writes: `users`.

**`CRUNCH/Features/Settings/UnitsView.swift` — NEW**

- `@Observable @MainActor final class UnitsViewModel`
  - `var units: String` ("metric" | "imperial")
  - `func load() async`, `func save(_ units: String) async -> Bool` — `UPDATE users SET units`
- Simple two-option list, immediate save on tap (no confirmation per spec's confirmation table).
- Reads/writes: `users`.

**`CRUNCH/Features/Settings/NotificationsView.swift` — NEW**

- `@Observable @MainActor final class NotificationsViewModel`
  - `var systemStatus: UNAuthorizationStatus`
  - `var pushEnabled: Bool` (derived: authorized **and** `users.apns_device_token != nil`)
  - `func refresh() async`
  - `func enable() async` — if `.notDetermined`: `PushNotificationService.shared.requestAuthorizationAndRegister()`; if `.denied`: open `UIApplication.openSettingsURLString`
  - `func disable() async` — calls new `PushNotificationService.clearDeviceToken()` (app-level opt-out; cannot revoke OS permission programmatically)
- Copy notes the spec's recovery path: "Permission timing: … If denied, recoverable via Settings → Notifications."
- **Provisional**: this screen verifies permission + token persistence only; real delivery blocked on the outstanding APNs user-side setup.
- Reads/writes: `UNUserNotificationCenter`, `users.apns_device_token` via `PushNotificationService`.

**`CRUNCH/Features/Settings/AccountView.swift` — NEW**

- `@Observable @MainActor final class AccountViewModel`
  - `var email: String?`
  - `var isDeleting: Bool`, `var errorMessage: String?`
  - `func signOut() async` — delegates to `AccountService.signOut()`
  - `func deleteAccount() async -> Bool` — delegates to `AccountService.deleteAccount()`
- UI: email row; "Sign Out" button — **immediate, no confirmation** (spec); "Delete Account" destructive button — **`.confirmationDialog` required** (spec — note this is deliberately different from IntegrationsView's `.alert`; both match the spec's confirmation table).
- On successful delete or sign-out, `ContentView` routes back to Splash automatically via `clerk.session == nil` — no manual navigation needed.

### Services / backend

**`CRUNCH/Services/AccountService.swift` — NEW**
Sign-out and deletion orchestration, so the ordering lives in one place:

- `static func signOut() async`
  1. `try? await PushNotificationService.shared.clearDeviceToken()` — while the token is still valid (prevents pushes for user A landing after user B signs in on the same device)
  2. `MixpanelService.reset()`
  3. `RevenueCatService.shared.resetUser()`
  4. `try await ClerkService.signOut()`
- `static func deleteAccount() async throws`
  1. POST `delete-account` Edge Function with `x-clerk-token` header (token from `ClerkService.currentToken()`) — Supabase data deleted server-side first, while the token is still valid
  2. Delete the Clerk user via clerk-ios self-deletion (`Clerk.shared.user`'s delete API — **verify the exact clerk-ios method name at implementation time**, and confirm the "users can delete their accounts" toggle is enabled in the Clerk dashboard; fallback in Architecture concerns)
  3. Local cleanup: `MixpanelService.reset()`, `RevenueCatService.shared.resetUser()`, sign out if the Clerk deletion didn't already end the session
- Reads: `ClerkService`, `Constants` (function URL). Writes: nothing directly.

**`CRUNCH/Services/PushNotificationService.swift` — MODIFIED**

- Add `func clearDeviceToken() async` — sets `users.apns_device_token = NULL` for the current user via authenticated client. Mirror image of existing `storeDeviceToken(_:)`. No other changes; delegate/deep-link pipeline untouched.

**`supabase/functions/delete-account/index.ts` — NEW Edge Function**

- Auth: same `_shared` Clerk-JWT verification used by `coach-respond` / rewritten `strava-oauth` (**verify the JWT, don't just decode it** — this endpoint is destructive).
- With service role, resolve `clerk_id → users.id`, then delete in FK-safe order using **both keying schemes**:
  - by **clerk text id**: `coach_messages`, `coach_conversations`, `meals`
  - by **UUID `users.id`**: `training_sessions` (after conversations — the FK is `ON DELETE SET NULL` so order is forgiving, but delete conversations first anyway), `macro_targets`, `races`, `integrations` (this also destroys the encrypted Strava tokens)
  - finally the `users` row
- Signature sketch: `POST` body `{}`, responses `200 {deleted: true}` / `401` / `500 {error}`. Idempotent — re-running after partial failure is safe.
- **Before writing it, list the live tables** (`supabase db dump` or dashboard) — the two empty local migration files mean the repo cannot be trusted for table inventory.
- No new migration needed; deletion runs as service role so no DELETE policies are required.

**`CRUNCH/Core/Constants.swift` — MODIFIED**
Add the `delete-account` function URL alongside the existing function URL constants.

### Wiring + analytics + polish (all MODIFIED)

- **`Features/Week/WeekView.swift`, `Features/Nutrition/NutritionView.swift`, `Features/Coach/CoachView.swift`** — replace the three `// Phase 8: push SettingsView` placeholders with the exact TodayView pattern: `@State private var showSettings = false`, gear button sets it, `.navigationDestination(isPresented: $showSettings) { SettingsView() }` inside each tab's existing `NavigationStack`. **Extends the existing per-tab navigation; `AppRouter` is not touched.**
- **`ContentView.swift`** — in the existing `.task` / session observation, when a session becomes active call `MixpanelService.identify(clerkUserId:)` and `RevenueCatService.shared.identifyUser(clerkUserId:)` (idempotent). This is the missing prerequisite for the "verify Mixpanel events" checklist item and Phase 9's RevenueCat work.
- **Accessibility pass (no new files)** — audit and fix in place: `.accessibilityLabel` on every new Settings control and status text; `.accessibilityElement(children: .combine)` on composite rows; confirm `PortionDotsView`'s existing label; `.frame(minWidth: 44, minHeight: 44)` on all new tappables; Dynamic Type check (all new text must use `Theme` fonts — no hardcoded sizes); WCAG AA contrast check on `Theme.textSecondary`-on-`Theme.card` combinations in the new screens via Accessibility Inspector.

---

## 3. Sequencing

1. **Gear-button wiring** (Week/Nutrition/Coach) — 10-minute change, makes Settings reachable everywhere for the rest of the phase's testing.
2. **SettingsView full list + ViewModel** — the hub; children can land behind it incrementally.
3. **UnitsView → PersonalInfoView** (PersonalInfo's pickers depend on units).
4. **RaceEditView** — needed early because it's the regression test's onboarding stand-in.
5. **NotificationsView + `PushNotificationService.clearDeviceToken()`**.
6. **`delete-account` Edge Function → `AccountService` → `AccountView`** — backend first so the client has something real to call; deploy + test the function against a throwaway user before wiring UI.
7. **Mixpanel/RevenueCat identify + sign-out reset wiring** (`ContentView`, `AccountService`).
8. **Accessibility + Dynamic Type + SE/Pro Max pass** across new screens plus Today/Coach audit.
9. **Regression (§6) + final security audit (§5)**.

---

## 4. Top 3 silent-failure modes for this phase

1. **Settings edits that don't propagate — stale portions.** TodayView/WeekView/NutritionView ViewModels load the user profile once in `.task`. A weight, units, or race-date change saved in Settings recalculates nothing until those tabs reload; the app looks fine and quietly shows wrong portions — the core product output. Mitigation: verify each tab's `.task`/`.refreshable` re-fires on re-appear after a Settings edit; make the explicit test "change weight 70→80 kg in Settings, return to Today, confirm gram targets moved" part of §6, and if the current `.task` behavior doesn't re-fire, add a lightweight reload-on-appear to the affected ViewModels.

2. **Partial account deletion from the split keying schemes.** If `delete-account` deletes only the UUID-keyed tables (or only the text-keyed ones), it returns 200, the client signs out, and orphaned PII (meal descriptions, coach transcripts) persists with no user-visible symptom ever. Mitigation: function enumerates tables from the live schema, deletes under both keys, and the §6 test asserts **zero rows per table** for the test user's clerk id *and* UUID afterward.

3. **Notifications toggle reading "On" while nothing can ever be delivered.** Permission authorized + token stored reads as "On", but APNs secrets/entitlement are outstanding and `_shared/apns.ts` deliberately no-ops. Everyone — including future-you — will read the toggle as "push works". Mitigation: the screen's state model is explicitly "permission + registration", the test plan (§6) never claims delivery, and §7 carries a re-verify item for when APNs goes live.

(Runner-up, folded into the audit pass rather than top-3: new Settings status texts — "Connected", "On/Off", race-name details — silently unlabeled for VoiceOver, since `List` rows read only their primary text unless children are combined.)

---

## 5. Security audit checklist (phase-specific, then the 11 rules)

Phase-specific:

- [ ] `delete-account` **verifies** the Clerk JWT signature server-side (same `_shared` verification as `coach-respond`) — never trusts a decoded-but-unverified token on a destructive endpoint.
- [ ] Service role key used only inside `delete-account`; nothing new added to the app bundle or `Constants.swift` beyond the function URL.
- [ ] Clerk user deletion: self-serve deletion setting scoped correctly in the Clerk dashboard; no Clerk secret key anywhere client-side.
- [ ] Deleting `integrations` rows destroys the AES-GCM-encrypted Strava tokens (rule 7 continuity through deletion).
- [ ] `apns_device_token` cleared **before** Clerk sign-out in `AccountService.signOut()` (cross-user push leak on shared device).
- [ ] `users` UPDATE paths (PersonalInfo/Units) go through RLS with the Clerk-JWT client — never through any service-role path; confirm the `users` policy covers UPDATE (the July 1/3 fixes covered races/training_sessions/macro_targets/integrations — **spot-check the `users` policy on the live DB** the same way).
- [ ] No `print()`/logging of email, tokens, or biometrics in any new file; `os_log` `.private` where needed (rule 8).
- [ ] Supabase client library query builders only in the Edge Function — no string-built SQL (rule 6).
- [ ] Mixpanel `identify` sends the Clerk user id only — no email or biometrics as event properties.

Then re-run the full 11-rule audit from AGENTS.md as the phase's final gate (it's the checklist's own last item).

---

## 6. Test steps (mapped to Phase 8 exit criteria)

**Settings screens** (per-screen, on device):

1. From every tab's gear button, Settings pushes; back-swipe works (4 entry points).
2. My Race: edit name/date → save → row detail updates → **Today countdown header updates** (stale-read check, failure mode 1). Past-date rejected with "Pick a date in the future".
3. Personal Info: change weight 70→80 kg → Today's gram targets change accordingly (MacroEngine is linear in weight — easy to eyeball).
4. Units: metric→imperial → PersonalInfo pickers re-render in lb/ft-in; underlying stored values unchanged.
5. Integrations: regression-only — confirm the Phase 7 screen still loads status (no changes made to it).
6. Notifications: fresh install → "Off"; enable → OS prompt → "On" → `users.apns_device_token` populated in Supabase. Disable → token NULL. Deny at OS level → screen offers the system-settings deep link. **Delivery itself: explicitly out of scope — blocked on the outstanding APNs .p8/secrets/entitlement setup. Do not mark the notifications row "verified" beyond permission + token storage.** Local-notification tap → Coach deep link still works (existing Phase 7 pipeline, unchanged).
7. Account: sign out is immediate, lands on Splash, token nulled, Mixpanel/RevenueCat reset. Delete account: `.confirmationDialog` → after completion, query Supabase for the test user's **clerk text id and UUID across all 8 tables — zero rows**; Clerk dashboard shows user gone; app is on Splash; sign-in with deleted credentials fails.

**Accessibility / devices:**

8. Dynamic Type at largest accessibility size: Settings screens, Today, Coach — no clipped/overlapping text.
9. VoiceOver: Today (portion dots announce "N of M portions…", meal cards combine), Coach (bubbles announce "Coach said: …"), all new Settings rows announce label + value + button trait. **Onboarding VoiceOver: deferred to Phase 5.**
10. iPhone SE (small width — wheel pickers and Settings rows) + 15 Pro Max.

**Mixpanel:**

11. After sign-in, dashboard shows events attributed to the Clerk user id (identify wired this phase). Fire and verify: `meal_added`, `activity_added`, `coach_message_sent`, `strava_connected`/`runna_connected` if re-tested. **Onboarding funnel events: deferred to Phase 5.**

**Full regression — rewritten to route around missing onboarding:**

> Original: *splash → onboarding → all tabs → settings → sign out → sign in.*
> Onboarding (Phase 5) is intentionally unbuilt, so the seeded-user path below stands in for screens 1–17. What replaces it: **sign-up creates the `users` row (existing `create-user-profile` function), then Settings → My Race creates the race, Settings → Personal Info sets biometrics, and Nutrition → Add Meal builds the meal library** — i.e., the same data onboarding would have written, via in-app screens.

12. Splash → Get Started → sign up (email + verification code) → lands on tabs *(onboarding skipped — not built)*.
13. Seed via app: RaceEditView (race), PersonalInfoView (biometrics), Nutrition tab (3 meals → `estimate-meal` populates macros).
14. Walk all four tabs: Today shows personalized portions from seeded data; Week renders; Coach send/receive round-trips; Nutrition lists meals.
15. Settings: every row per steps 1–7.
16. Sign out → Splash → sign back in → data intact, tabs rehydrate.
17. **Provisional overlay:** any step exercising the post-run pipeline (Realtime recalc, push → Coach deep link, auto-first-message) is treated as provisionally passing until the Phase 7 real-Strava-run device test has actually run; real-push verification additionally waits on the APNs setup. Neither blocks Phase 8 exit; both are tracked in §7.

---

## 7. Phase 5 & Phase 7 handoff notes

**Revisit when Phase 5 (onboarding) lands:**

- `ContentView.swift` routing: insert `!hasCompletedOnboarding → OnboardingCoordinator` (the placeholder comment is already at `ContentView.swift:17`); confirm Settings-seeded users (this phase's regression path) have `has_completed_onboarding` handled so they don't get funneled into onboarding.
- Push-permission timing: spec wants the request after screen 17. Today it fires inside `IntegrationsViewModel.connectStrava()` and (after this phase) from NotificationsView — dedupe when the onboarding call site appears.
- PersonalInfoView/RaceEditView "create" affordances become pure-edit paths once onboarding populates the data; revisit empty-state copy.
- Screen 15 will consume `StravaOAuthService`/`RunnaService` — their signatures were left untouched this phase, as required.
- Run the deferred pieces: onboarding VoiceOver/Dynamic Type audit, onboarding Mixpanel funnel verification, and the regression's original front half.

**Re-verify once the Phase 7 on-device E2E (real Strava run) and APNs setup actually run:**

- Webhook → `training_sessions` upsert → Realtime → Today recalc (Settings-edited biometrics now feed that recalc — confirm fresh values are used).
- Real APNs delivery → deep link → Coach auto-first-message; then re-test NotificationsView's On/Off against **actual delivery**, not just token storage.
- `apns_device_token` re-registration after this phase's new sign-out (which now nulls it) followed by sign-in on the same device.
- Delete-account against a user with a live Strava connection: rows go away, but the app remains authorized on the athlete's Strava account — see concerns below.

---

## Architecture concerns (flagged once, not redesigned)

1. **SwiftData offline cache + `NWPathMonitor` were never built in any phase**, despite being spec'd under Universal Behaviors, and Phase 8 is the last non-subscription phase before TestFlight. Decide explicitly: pull a minimal offline pass into Phase 8, insert a Phase 8.5, or ship the beta online-only. Silence here means beta testers on flaky race-day connectivity hit blank screens.
2. **Clerk self-deletion dependency**: the plan uses clerk-ios client-side user deletion, which requires a Clerk dashboard toggle and SDK support. If either is missing, the fallback is Clerk's Backend API from `delete-account` — which means adding `CLERK_SECRET_KEY` to Edge Function secrets (a new secret not in the AGENTS.md list; fine security-wise, but flag it before doing it).
3. **Deletion doesn't revoke Strava**: dropping the `integrations` row deletes our tokens but leaves Crunch authorized on the user's Strava account, and the webhook may keep firing events for a deleted athlete. Consider a best-effort Strava `/oauth/deauthorize` call inside `delete-account`; also worth checking `strava-webhook` behaves sanely when the user row is gone.
4. **The two 0-byte initial migrations** mean the repo can't reproduce the live schema. Worth one `supabase db dump --schema public` into the repo during this phase — the delete-account function is the first code whose correctness depends on a complete table inventory.
5. **Per-request `SupabaseClient` construction** in `authenticatedClient()` is fine for the current cadence, but Settings adds several small sequential reads per screen; if it ever shows, batch reads per ViewModel (as the plan's `load()` methods already do) rather than caching clients.
6. **Split `user_id` keying** (text vs UUID by table) is now load-bearing in three places (RLS, delete-account, Realtime). It works, but it's the kind of thing the next phase forgets — worth a permanent note at the top of AGENTS.md's schema section, which currently documents the *spec* keying, not the real one.
