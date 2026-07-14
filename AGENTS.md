# AGENTS.md — Crunch V2 (SwiftUI)

> **Version:** 3.0  
> **Last updated:** 2026-06-29  
> **Purpose:** Single source of truth for Crunch architecture, build rules, and UI spec. Claude Code must read this file in full before starting any phase. Do not deviate without explicit approval.

---

## What Crunch Is

Crunch is a race nutrition app for marathon and endurance runners. It connects to Strava and Runna, generates race-specific daily meal portion guidance using proven sports nutrition science, and provides AI-powered post-run fueling diagnosis via a conversational Coach powered by Claude API.

**V2 product direction:**
- Macros shown as real meal portions, not gram numbers
- Meal library built during onboarding — personalised to what the user actually eats
- Coach tab replaces structured check-in flow — natural conversation
- Four tabs (Today / Week / Nutrition / Coach)
- No compliance tracking — suggestions, not obligations
- Activity tracking for gym/cycling/swimming alongside running
- Subscription-based (monthly + annual + 7-day free trial via RevenueCat)

---

## Architecture Decisions

These decisions are final. Do not revisit during build phases.

| Decision | Choice | Rationale |
|---|---|---|
| Frontend | SwiftUI native iOS | Native performance, Xcode on Mac, no abstraction layer |
| Language | Swift 6 | Strict concurrency, async/await throughout |
| Minimum iOS target | iOS 17 | Modern SwiftUI, NavigationStack |
| Backend | Supabase only | Postgres, Edge Functions, Realtime |
| Edge Functions runtime | Deno | All server-side logic in Supabase Edge Functions |
| Auth | Clerk (clerk-ios SDK) | Apple, Google, email — handles all session lifecycle |
| Subscriptions | RevenueCat | StoreKit 2 abstraction, subscription dashboard |
| Analytics | Mixpanel | Event-based, onboarding funnel tracking |
| AI | Claude API (claude-sonnet-4-20250514) | Coach conversation, meal macro estimation |
| State management | SwiftUI @Observable + @StateObject | No third-party state library |
| Local persistence | SwiftData | Offline cache only — Supabase is source of truth |
| Integration tokens | AES-GCM encryption | Strava OAuth tokens encrypted at rest in Supabase |
| Package manager | Swift Package Manager (SPM) | Built into Xcode |
| Build & distribution | Xcode + TestFlight | Native toolchain |

### Infrastructure IDs

| Resource | Value |
|---|---|
| Supabase project ref | `ryswtwcgzhmkmgzcklyx` |
| Supabase URL | `https://ryswtwcgzhmkmgzcklyx.supabase.co` |
| Strava Client ID | `251794` |
| Strava webhook subscription ID | `349281` |
| Bundle ID | `com.pyb99.crunch` |
| RevenueCat entitlement ID | `pro` |
| RevenueCat monthly product ID | `com.pyb99.crunch.monthly` |
| RevenueCat annual product ID | `com.pyb99.crunch.annual` |
| Mixpanel project token | `6bfd597733d1ff2d47ce3b622cb2dc72` |

---

## Swift Package Dependencies

Add via Xcode > File > Add Package Dependencies. 14-day rule applies — no package published less than 14 days ago.

| Package | URL | Purpose |
|---|---|---|
| supabase-swift | `https://github.com/supabase/supabase-swift` | Supabase client |
| clerk-ios | `https://github.com/clerk/clerk-ios` | Authentication |
| purchases-ios | `https://github.com/RevenueCat/purchases-ios` | Subscriptions |
| mixpanel-swift | `https://github.com/mixpanel/mixpanel-swift` | Analytics |

No other third-party packages without explicit approval. Use SwiftUI and Foundation for everything else.

---

## Project Structure

Starting from Xcode-generated project at `/Users/prakash/dev/personal/CRUNCH/`:

```
CRUNCH/
  CRUNCHApp.swift                    # @main — init Clerk, Supabase, RevenueCat, Mixpanel
  ContentView.swift                  # Root routing — splash / onboarding / main tabs

  Core/
    Theme.swift                      # All design tokens (colours, fonts, spacing, radius)
    Constants.swift                  # IDs, limits, API URLs
    Extensions/
      Color+Theme.swift
      View+Theme.swift

  Services/
    SupabaseService.swift            # Supabase client with Clerk JWT injection
    ClerkService.swift               # Sign in/out, OAuth, session
    RevenueCatService.swift          # Subscription status, purchase
    MixpanelService.swift            # Event tracking
    AnthropicService.swift           # Edge Function calls (coach-respond, estimate-meal)

  Models/
    User.swift
    Race.swift
    TrainingSession.swift
    MacroTarget.swift
    Meal.swift
    PortionResult.swift
    CoachConversation.swift
    CoachMessage.swift

  Engines/
    MacroEngine.swift                # BMR, TDEE, macro calculations
    PortionEngine.swift              # Gram targets to portion multipliers

  Features/
    Auth/
      SplashView.swift
      SignInView.swift
      SignUpView.swift
      ForgotPasswordView.swift

    Onboarding/
      OnboardingCoordinator.swift    # @Observable state machine for 17 screens
      OnboardingProgressBar.swift
      Screen01ScienceView.swift
      Screen02RaceTypeView.swift
      Screen03RaceDetailsView.swift
      Screen04HookView.swift
      Screen05GenderView.swift
      Screen06AgeView.swift
      Screen07WeightView.swift
      Screen08HeightView.swift
      Screen09TrainingLevelView.swift
      Screen10ActivitiesView.swift
      Screen11BreakfastView.swift
      Screen12LunchView.swift
      Screen13DinnerView.swift
      Screen14ReadinessView.swift
      Screen15ConnectAppsView.swift
      Screen16CreateAccountView.swift
      Screen17PlanReadyView.swift

    Today/
      TodayView.swift
      MealCardView.swift
      PortionDotsView.swift
      ActivityToggleView.swift

    Week/
      WeekView.swift
      DayRowView.swift

    Nutrition/
      NutritionView.swift
      MealLibraryView.swift
      ScienceCardView.swift
      MacroDetailView.swift

    Coach/
      CoachView.swift
      CoachMessageView.swift
      CoachInputView.swift

    Settings/
      SettingsView.swift
      RaceEditView.swift
      PersonalInfoView.swift
      IntegrationsView.swift
      NotificationsView.swift
      UnitsView.swift
      AccountView.swift

    Paywall/
      PaywallView.swift              # Deferred to Phase 9

  Components/
    PrimaryButton.swift              # CTA button with loading + disabled states
    ErrorBanner.swift                # Inline red error banner
    SkeletonView.swift               # Loading placeholder
    EmptyStateView.swift             # Empty state with CTA

CRUNCHTests/
  MacroEngineTests.swift
  PortionEngineTests.swift

supabase/                            # Existing — do not touch unless phase requires it
  functions/
    strava-webhook/
    strava-oauth/
    runna-sync/
    coach-respond/
    estimate-meal/
    create-user-profile/
  migrations/
```

---

## Database Schema

Auth identity is the Clerk user ID (text, format `user_xxx`), read by `requesting_user_id()` from `current_setting('request.jwt.claims')->>'sub'`. Text-keyed tables (`meals`, `coach_conversations`, `coach_messages`) store it directly in `user_id`; uuid-keyed tables (`races`, `training_sessions`, `macro_targets`, `integrations`) store `users.id` (uuid) in `user_id` and resolve via the `clerk_id → users.id` subquery in RLS.

### `users`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| clerk_id | text | Unique, not null — Clerk user ID |
| email | text | |
| height_cm | numeric | Nullable |
| weight_kg | numeric | Nullable |
| age | integer | Nullable |
| gender | text | 'male' or 'female' |
| units | text | 'metric' or 'imperial' |
| training_level | text | 'beginner', 'intermediate', 'advanced' |
| weekly_activities | jsonb | Array of activity types |
| has_completed_onboarding | boolean | Default false |
| created_at | timestamptz | |
| updated_at | timestamptz | |
| apns_device_token | text | Nullable — APNs push token (Phase 7) |

### `races`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | FK → users.id |
| race_type | text | '5k','10k','half_marathon','marathon','ultra_marathon','other' |
| race_name | text | Optional |
| race_date | date | |
| is_active | boolean | Not null, default true |
| created_at | timestamptz | |
| Unique | | partial `races_single_active_per_user_idx` on `(user_id) WHERE is_active` — one active race/user |

### `training_sessions`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | FK → users.id |
| source | text | 'strava','runna','manual' |
| session_date | date | |
| session_type | text | 'easy_run','tempo','interval','long_run','race','rest', activity types |
| distance_km | numeric(6,2) | Nullable |
| duration_mins | integer | Nullable |
| status | text | Not null, default 'planned' ('planned','completed') |
| strava_activity_id | text | Nullable |
| perceived_exertion | integer | Nullable |
| runna_uid | text | Nullable |
| created_at | timestamptz | |
| Unique | | partial `(user_id, strava_activity_id)` and `(user_id, runna_uid)` |

### `macro_targets`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | FK → users.id |
| target_date | date | |
| session_id | uuid | FK training_sessions, nullable |
| calories_kcal | integer | |
| carbs_g | integer | |
| protein_g | integer | |
| fat_g | integer | |
| target_type | text | Not null (e.g. 'rest','easy','long','carb_load') |
| created_at | timestamptz | |
| Unique | | `macro_targets_user_date_idx` on `(user_id, target_date)` |

### `integrations`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | FK → users.id |
| provider | text | 'strava' or 'runna' |
| access_token | text | AES-GCM encrypted at rest (Runna: plaintext iCal URL) |
| refresh_token | text | AES-GCM encrypted at rest |
| token_expires_at | timestamptz | Nullable |
| connected_at | timestamptz | Not null, default now() |
| is_active | boolean | Not null, default true |
| provider_user_id | text | Nullable |
| Unique | | `integrations_user_provider_idx` on `(user_id, provider)` |

### `meals`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| user_id | text | |
| meal_name | text | User's description |
| meal_time | text | 'breakfast','lunch','dinner','snack' |
| estimated_macros | jsonb | `{carbs_g, protein_g, fat_g}` |
| portion_baseline | numeric | Default 1 |
| is_active | boolean | Default true |
| sort_order | integer | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### `coach_conversations`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| user_id | text | |
| session_id | uuid | FK training_sessions, nullable |
| started_at | timestamptz | |
| updated_at | timestamptz | |

### `coach_messages`
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| conversation_id | uuid | |
| user_id | text | Denormalised for RLS |
| role | text | 'user' or 'assistant' |
| content | text | |
| created_at | timestamptz | |

---

## Row Level Security

```sql
create or replace function requesting_user_id()
returns text as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'sub', '')::text;
$$ language sql stable;
```

All tables: RLS enabled. Two keying patterns:
- **Text-keyed** (`meals`, `coach_conversations`, `coach_messages`): scope `requesting_user_id() = user_id`.
- **UUID-keyed** (`races`, `training_sessions`, `macro_targets`, `integrations`): scope `user_id = (select id from users where clerk_id = requesting_user_id())`.
- **`users`**: scope on `clerk_id = requesting_user_id()` (separate SELECT + UPDATE policies).

No exceptions.

### Known Technical Debt (DB — deferred, tracked)

Surfaced in the 2026-07-14 live-schema review (cross-ref `docs/phase7-remediation-plan.md` item 8). Not fixed — this is their permanent home.

| ID | Debt | Fix when addressed |
|---|---|---|
| D1 | Duplicate index on `coach_messages`: `coach_messages_conversation_date` and `coach_messages_conversation_idx` both cover `(conversation_id, created_at)`. | `drop index` one, via a cleanup migration |
| D2 | Duplicate FK on `coach_conversations.session_id`: `coach_conversations_session_fk` and `coach_conversations_session_id_fkey`, both → `training_sessions(id) ON DELETE SET NULL`. | `drop constraint` one, via a cleanup migration |
| D3 | `handle_auth_user_created()` (public) is fired by a trigger on `auth.users`, which a `--schema public` dump/baseline does not capture — a fresh `db reset` won't auto-insert `public.users` rows on signup. | add the `auth.users` trigger to a migration, or document that `create-user-profile` covers it |
| D4 | `requesting_user_id()` doc previously said `auth.jwt()->>'sub'`; it actually reads `current_setting('request.jwt.claims')`. **Resolved in this update** (function block + schema header above). | — (done) |

---

## Security Rules

1. No API keys in app bundle. `SUPABASE_URL` and `SUPABASE_ANON_KEY` only on client.
2. Supabase service role key: Edge Functions only, never in app.
3. Clerk secret key: never in app. Publishable key only.
4. RevenueCat: public SDK key on client. Secret key server-side only.
5. RLS on all tables. No exceptions.
6. Parameterised queries only. No string-concatenated SQL.
7. AES-GCM encryption for Strava tokens.
8. No `print()` of tokens or PII. Use `os_log` with `.private` privacy level.
9. Validate all webhook payloads server-side before DB write.
10. 14-day SPM package rule. Check GitHub release date before adding any dependency.
11. Swift 6 strict concurrency. No data races. All async work on correct actors.

---

## Token Efficiency Rules

1. Read AGENTS.md first. Every session.
2. Stage-gated: Stage 1 plan → advisory review → execute → self-review → test on device.
3. One phase per session. Fresh session per phase.
4. Do not re-read files already read in current session.
5. Do not ask questions answered in this file.
6. Minimal diffs — change only what the phase requires.
7. No exploratory coding. Know what you're building before writing a line.
8. Build and run on device before marking phase complete.

---

## Macro Engine Algorithm

### BMR (Mifflin-St Jeor)

```swift
// Male:   BMR = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
// Female: BMR = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
```

Fallback if no biometrics: weight 70kg, height 175cm, age 30, male.

### TDEE

`TDEE = BMR * activityMultiplier`

| Session Type | Multiplier |
|---|---|
| rest | 1.2 |
| easy_run | 1.55 |
| tempo | 1.725 |
| interval | 1.725 |
| long_run | 1.9 |
| race | 1.9 |

### Carbohydrate Targets (g/kg body weight)

Source: Burke LM et al., Journal of Sports Sciences, 2011.

| Session Type | g/kg Midpoint |
|---|---|
| rest | 4 |
| easy_run | 6 |
| tempo | 7 |
| interval | 7 |
| long_run | 8.5 |
| race | 10 |

### Protein

Fixed at **1.7 g/kg**. Source: Morton RW et al., BJSM 2018; ISSN 2017.

### Fat

```swift
fat_g = (TDEE - (carbs_g * 4) - (protein_g * 4)) / 9
// Minimum floor: 0.5 g/kg
```

### Training Phases

| Weeks to Race | Phase |
|---|---|
| > 12 | Base Building |
| 8–12 | Build |
| 4–8 | Peak Training |
| 1–4 | Taper |
| 0 | Race Week |

### Special Protocols

- **Taper:** Maintain carb targets, reduce fat for ~12.5% calorie reduction. Source: Mujika & Padilla, 2003.
- **Carb-load (3 days pre-race):** Carbs to 11 g/kg. Source: Burke et al. 2011; Jeukendrup 2011.

### Activity Adjustments

| Activity | Protein | Carbs |
|---|---|---|
| gym_upper | +10g | — |
| gym_lower | +15g | +30g |
| gym_full | +15g | +20g |
| cycling | Easy run equivalent | |
| swimming | Easy run equivalent | |
| other | +10g | +15g |

### Portion Engine

```swift
portion_multiplier = target_macro_for_meal / meal_baseline_macro
// Distribution: 25% breakfast, 35% lunch, 40% dinner
// Display levels: normal (≤1.25x) / extra (1.25–1.75x) / double (>1.75x)
```

---

## Meal Library

### How Meals Enter the System

1. Onboarding screens 11–13: free text description
2. Description → `estimate-meal` Edge Function → Claude API → estimated macros
3. Macros stored in `meals` table
4. Add/edit anytime via Nutrition tab

### estimate-meal Edge Function

**Model:** claude-sonnet-4-20250514 | **Max tokens:** 300

**System prompt:**
```
You are a sports nutritionist. Estimate the macronutrient content of this meal.
Return ONLY a JSON object: {"carbs_g": number, "protein_g": number, "fat_g": number}
Values are grams for one normal serving. No other text.
```

Response: strip markdown fences, decode JSON, validate all three fields are positive numbers. Reject and return error on failure.

---

## Coach Tab (AI Conversation)

### coach-respond Edge Function

**Model:** claude-sonnet-4-20250514 | **Max tokens:** 500

**System prompt template:**
```
You are a sports nutritionist specialising in endurance running. You know this runner
personally: their race is {race_name}, {weeks_to_race} weeks away, in {training_phase}
phase. Their usual meals: {meal_library}. Biometrics: {height}/{weight}/{age}/{gender}.

Speak conversationally — like a running mate who knows nutrition. Reference their
actual meals by name. Never give generic advice. Never mention calories, deficits, or
body composition. Anchor to their race and training. Use portions and real food.
```

### Post-Run Flow

1. Strava webhook → upsert `training_sessions`
2. Push notification: "Nice work on that {X}K — how did it feel?"
3. Deep link → Coach tab
4. Auto-create conversation linked to session
5. Auto-send first message referencing the run and last dinner
6. Runner responds → coach-respond → store in `coach_messages`

### Conversation Rules

- Last 20 messages sent to API (10 user + 10 assistant). System prompt always included.
- Conversations tagged with date and linked session.
- Optimistic local insert — confirm from DB.

### Empty State

- "Hey! I'm your Crunch coach"
- "Ask me anything about fueling for your {race_name}."
- Three tappable chips: "What should I eat today?" / "Explain carb loading" / "Help me plan race day nutrition"

---

## Subscriptions (RevenueCat)

### Products

| Product | ID | Duration | Trial |
|---|---|---|---|
| Monthly | `com.pyb99.crunch.monthly` | 1 month | 7 days |
| Annual | `com.pyb99.crunch.annual` | 1 year | 7 days |

Entitlement ID: `pro`

### Rules

- Initialise RevenueCat in `CRUNCHApp.swift` with public SDK key only
- Check entitlement on launch, store in `@Observable AppState`
- Paywall UI deferred to Phase 9
- Use StoreKit sandbox + RevenueCat sandbox during development
- All features accessible during trial. After trial: main tabs require `pro` entitlement.

---

## Analytics (Mixpanel)

**Token:** `6bfd597733d1ff2d47ce3b622cb2dc72`

### Events

| Event | Properties | Trigger |
|---|---|---|
| `onboarding_started` | — | Get Started tapped |
| `onboarding_screen_viewed` | `screen_number`, `screen_name` | Each screen appears |
| `onboarding_completed` | `race_type`, `training_level` | Screen 17 → Today |
| `meal_added` | `meal_time` | Meal saved |
| `activity_added` | `activity_type` | Toggle tapped |
| `coach_message_sent` | `is_post_run` | Message sent |
| `subscription_started` | `product_id`, `is_trial` | Purchase confirmed |
| `strava_connected` | — | OAuth complete |
| `runna_connected` | — | iCal saved |

Identify user after sign-in: `Mixpanel.mainInstance().identify(distinctId: clerkUserId)`

---

## Edge Functions

| Function | Trigger | Purpose |
|---|---|---|
| strava-webhook | POST from Strava | Validate, upsert runs, trigger recalc, push notification |
| strava-oauth | POST from app | Token exchange, encrypt, store |
| runna-sync | Cron 04:00 UTC | Parse iCal, upsert sessions |
| coach-respond | POST from app | Claude conversation, save messages |
| estimate-meal | POST from app | Claude macro estimation |
| create-user-profile | POST from app | Insert users row on sign-up (service role) |

### Edge Function Secrets

```
SUPABASE_SERVICE_ROLE_KEY
SUPABASE_URL
STRAVA_CLIENT_ID
STRAVA_CLIENT_SECRET
STRAVA_WEBHOOK_VERIFY_TOKEN
INTEGRATION_ENCRYPTION_KEY
ANTHROPIC_API_KEY
APNS_KEY
APNS_KEY_ID
APNS_TEAM_ID
```

---

## Environment Configuration

Never commit secrets to git. Store in Xcode scheme environment variables or `Secrets.xcconfig` (gitignored).

**App-side values only:**
```
SUPABASE_URL=https://ryswtwcgzhmkmgzcklyx.supabase.co
SUPABASE_ANON_KEY=
CLERK_PUBLISHABLE_KEY=pk_...
REVENUECAT_PUBLIC_KEY=
```

Access via `Config.swift` reading from `Info.plist` keys injected from build scheme.

---

## Scientific References

### Carbohydrate targets
- Burke LM et al. — Carbohydrates for training and competition. Journal of Sports Sciences, 2011.
- Jeukendrup A. — Nutrition for Endurance Sports. Sports Medicine, 2011.
- Jeukendrup A. — Personalised Sports Nutrition. IJSNEM, 2014.
- ACSM & AND — Joint Position Statement: Nutrition and Athletic Performance, 2016.
- Viribay et al. — 120 g/h Carbohydrates during Mountain Marathon. Nutrients, 2020.

### Protein
- Morton RW et al. — Protein supplementation meta-analysis. BJSM, 2018.
- ISSN Position Stand — Protein and Exercise, 2017.
- Areta JL et al. — Protein timing during recovery. Journal of Physiology, 2013.

### BMR
- Mifflin MD et al. — Resting energy expenditure equation. AJCN, 1990.
- 2024 Adult Compendium of Physical Activities.

### Taper & carb-loading
- Mujika I & Padilla S — Precompetition tapering strategies. MSSE, 2003.

### Nutrient timing
- ISSN Position Stand — Nutrient Timing, 2017.

---

## Design Spec (V2)

Authoritative reference for all SwiftUI implementation. All values map directly to SwiftUI modifiers.

### Design Tokens (Theme.swift)

```swift
// Colours
static let brand         = Color(hex: "#C4622D")   // Burnt orange — primary accent
static let brandDark     = Color(hex: "#A3501F")   // Pressed/active
static let surface       = Color(hex: "#0A0A0A")   // App background
static let card          = Color(hex: "#1A1A1A")   // Card background
static let subtle        = Color(hex: "#2A2A2A")   // Borders, dividers
static let textPrimary   = Color(hex: "#FFFFFF")
static let textSecondary = Color(hex: "#9CA3AF")
static let textInverse   = Color(hex: "#1E2A23")
static let success       = Color(hex: "#22C55E")
static let warning       = Color(hex: "#F59E0B")
static let neutral       = Color(hex: "#6B7280")
static let error         = Color(hex: "#EF4444")

// Typography
static let heroNumber  = Font.system(size: 32, weight: .bold)
static let heading     = Font.system(size: 22, weight: .bold)
static let subheading  = Font.system(size: 17, weight: .semibold)
static let body        = Font.system(size: 15, weight: .regular)
static let caption     = Font.system(size: 13, weight: .regular)
static let tabLabel    = Font.system(size: 10, weight: .medium)

// Spacing
static let xs: CGFloat = 4
static let sm: CGFloat = 8
static let md: CGFloat = 16
static let lg: CGFloat = 24
static let xl: CGFloat = 32

// Corner radius
static let cardRadius:   CGFloat = 16
static let buttonRadius: CGFloat = 14
static let inputRadius:  CGFloat = 14
static let pillRadius:   CGFloat = 20

// Touch targets: .frame(minWidth: 44, minHeight: 44) on all interactive elements
```

### Navigation Structure

`TabView` with four tabs. Always visible on main screens.

| Tab | SF Symbol | Label |
|---|---|---|
| Today | `house.fill` | Today |
| Week | `calendar` | Week |
| Nutrition | `leaf.fill` | Nutrition |
| Coach | `bubble.left.fill` | Coach |

- Tab bar background: `surface`. Active tint: `brand`.
- Settings: `.toolbar` button top-right on every tab. Pushes `SettingsView`.
- Hide tab bar on splash, auth, onboarding: `.toolbar(.hidden, for: .tabBar)`

### Splash Screen

`ZStack`:
- Full-screen background image (runner at dawn, dark overlay)
- "Fuel for your race." — `.font(Theme.heading)`, white, centred
- "Not your weight." — `.font(Theme.body)`, `Theme.brand`
- `PrimaryButton("Get Started")` → onboarding
- Text button "Already have an account? Sign in" → SignInView

### Auth Screens

- "CRUNCH" wordmark top
- Title: "Sign in" / "Sign up"
- Conversational subtitle
- `TextField` email (`.keyboardType(.emailAddress)`, `.autocorrectionDisabled()`, `.textInputAutocapitalization(.never)`)
- `SecureField` password
- `PrimaryButton` with loading state
- `SignInWithAppleButton` (native)
- Google OAuth via Clerk
- "Forgot password?" text button (sign-in only)
- Toggle link between sign in / sign up

### Today Tab

**Race countdown header:**
```
14 weeks to Amsterdam Marathon   [heading]
Peak Training Phase              [caption, textSecondary]
```

**Session context:** `Today: Long Run · 22 km` (body, textSecondary) or `Rest & Recovery`

**Meal cards** — `LazyVStack` of 3 `MealCardView`:
- Meal time emoji + label
- "Your usual: [meal name]"
- `PortionDotsView` (filled ● / empty ○ circles)
- Portion label: "Normal portions" / "Extra portion today" / "Double portion tonight"
- Reason text anchored to today's or tomorrow's session
- "Tap to see breakdown"
- Expanded: portion in real terms ("2 cups rice instead of your usual 1 cup"), "See the numbers →" toggle (grams), science tip

**Activity toggle:** card below meals → sheet with 6 options. One tap adds. Portions recalculate.

**Today tab states:**

| State | Display |
|---|---|
| Training day | Session label, adjusted portions + reason |
| Post-run | "22K Long Run Complete", recovery portions, Coach link |
| Rest day | "Rest & Recovery", normal/reduced portions |
| No Strava | Generic portions + "Connect Strava" prompt |
| No meal library | "Let's set up your meals" card → Nutrition tab |

### Week Tab

Header: `◄ Week 8 of 16 — Peak Training ►`
Summary: `Total: 48 km | 5 sessions` (no compliance %)

Day rows (`List` or `LazyVStack`):
- Day + date
- Session badge text
- Portion indicator: ↑↑ Double / ↑ Extra / → Normal / ↓ Lighter
- Tap to expand: detail, meal portions, fueling tip, Coach link for past runs

### Nutrition Tab

**My Meals:** `List` grouped by meal_time. Each row: name + macros caption + Edit chevron. "+ Add meal" at bottom of each group.

**The Science:** 4 `DisclosureGroup` cards with 3–4 sentences + citation, anchored to user's numbers.

**Macro Detail:** Toggle. Carbs / Protein / Fat in grams, portion mapping, phase explanation.

### Coach Tab

- `ScrollView` + `LazyVStack` of `CoachMessageView` bubbles
- User: right-aligned, `brand` background. Coach: left-aligned, `card` background.
- `CoachInputView` pinned at bottom (safe area aware)
- Auto-scroll to bottom on new message (`ScrollViewReader`)
- Typing indicator (3 animated dots) while waiting
- Date section headers

### Settings

`List` with `NavigationLink`:

| Row | Right detail |
|---|---|
| My Race | Race name |
| Personal Info | Height, weight... |
| Integrations | Strava + Runna status |
| Notifications | On/Off |
| Units | Metric / Imperial |
| Subscription | Active / Trial / Upgrade |
| Account | Email + sign out + delete (destructive) |

Delete account: `.confirmationDialog` required.

### Onboarding Flow (17 screens)

`NavigationStack` managed by `OnboardingCoordinator` (`@Observable`). All state held in coordinator — never lost between screens.

| # | View | Title | Input | Advance |
|---|---|---|---|---|
| 1 | Screen01ScienceView | Built on proven sports nutrition science | 3 citation cards | Continue |
| 2 | Screen02RaceTypeView | What are you training for? | 5K/10K/Half/Marathon/Ultra/Other | Auto (0.3s delay) |
| 3 | Screen03RaceDetailsView | What's it called and when is it? | TextField + DatePicker | Continue |
| 4 | Screen04HookView | {Race} is in {X} days | Dynamic text (brand colour on number) | Continue |
| 5 | Screen05GenderView | What's your biological sex? | Male / Female | Auto |
| 6 | Screen06AgeView | How old are you? | Picker wheel 16–80 | Continue |
| 7 | Screen07WeightView | What's your current weight? | Picker + metric/imperial toggle | Continue |
| 8 | Screen08HeightView | How tall are you? | Picker + same toggle persists | Continue |
| 9 | Screen09TrainingLevelView | How serious is your training? | Beginner/Intermediate/Advanced | Auto |
| 10 | Screen10ActivitiesView | Do you do anything else during the week? | Multi-select (gym upper/lower/full, cycling, swimming, other, nothing) | Continue |
| 11 | Screen11BreakfastView | What do you usually have for breakfast? | TextEditor + "I don't eat breakfast" + "Add another" | Continue |
| 12 | Screen12LunchView | What about lunch? | Same | Continue |
| 13 | Screen13DinnerView | And dinner? | Same | Continue |
| 14 | Screen14ReadinessView | Fueling readiness | Spider chart | Continue |
| 15 | Screen15ConnectAppsView | Connect your apps | Strava + Runna + Skip | Continue |
| 16 | Screen16CreateAccountView | Save your fuel plan | Email + password + privacy note | Create account |
| 17 | Screen17PlanReadyView | Your race fuel plan is ready! | Race + countdown + curve | Start My Plan |

**Onboarding UX Rules:**
- `OnboardingProgressBar` on all screens except 17
- Back always available (`.navigationBarBackButtonHidden(false)`)
- Single-select auto-advances with 0.3s delay
- `OnboardingCoordinator` holds all state — never lost between screens
- No body composition question — ever
- Pickers: `.pickerStyle(.wheel)`

---

## Copy Tone Rules

- Conversational — running mate, not a coach
- Direct — specific portions and actions
- Race-anchored — reference the runner's specific race
- Portion-first — "double portion of pasta" not "320g carbs"
- Suggestions, not obligations — "try an extra portion" not "you need to eat more"

**Never use:** "calories", "deficit", "weight loss", "body composition", "diet", "compliance"

**Prefer:** "fuel", "portions", "recovery", "race day", "your next session", "your usual [meal]"

---

## What NOT to Include in UI

- Raw calorie totals as primary display
- Weight loss or body composition language
- Compliance percentages or dots
- Food photographs or recipes
- Gamification (badges, streaks)
- Social features
- Structured check-in modal

---

## Universal Behaviors

Every screen must handle these. Stage 1 plans missing relevant states are incomplete.

### Loading States

| Situation | SwiftUI Implementation |
|---|---|
| Screen loads, data pending | `SkeletonView` — `RoundedRectangle` placeholders with shimmer |
| Pull to refresh | `.refreshable {}` |
| Coach waiting for response | Animated typing dots bubble. User message appears immediately. |
| Meal estimation | Inline `ProgressView()` next to entry. Input remains editable. |
| Button submitting | `PrimaryButton` shows `ProgressView()`, `.disabled(true)`, label changes |
| Tab switch | Instant. Cache last state. Background `Task` refresh if stale. |

### Error States

| Situation | Implementation |
|---|---|
| Network failure | `ErrorBanner` top of content — red, "Something went wrong. Tap to retry." |
| Auth error | Red `.caption` text below the offending field. Clear on `.onChange`. |
| Coach API error | Error coach bubble + Retry button. Do not lose user message. |
| Meal estimation failure | "Couldn't estimate — tap to retry". Save meal with nil macros anyway. |
| RLS error | Generic "Something went wrong" + retry. `os_log` error type only. |

Never show raw errors, HTTP codes, or stack traces.

### Empty States

| Screen | Content |
|---|---|
| Today — no meals | "Let's set up your meals" → Nutrition tab |
| Today — no race | "Set up your race" → Settings |
| Today — no Strava | "Connect Strava" prompt below session label |
| Week — no sessions | "Rest" all days + "Connect Runna" prompt |
| Nutrition — no meals | "+ Add your first meal" |
| Coach — no conversations | Greeting + subtitle + 3 chips |

### Offline Behavior

Use `NWPathMonitor`. Cache in SwiftData.

| Situation | Behavior |
|---|---|
| App opens offline | Show SwiftData cache. If none, empty states. |
| Coach offline | Disable send. "You're offline" caption. |
| Add meal offline | Allow input. Save with `estimationPending = true`. Estimate on reconnect. |
| Sign in offline | "No internet connection" inline error. |
| Reconnects | `Task { await refreshCurrentTab() }` silently. |

### Form Validation

| Field | Rules | Error copy |
|---|---|---|
| Email | Required, valid format, lowercased | "Enter a valid email address" |
| Password | Required, min 8 chars | "Password must be at least 8 characters" |
| Race name | Optional, max 100 chars | — |
| Race date | Required, future date | "Pick a date in the future" |
| Weight / Height / Age | Picker — no invalid input | — |
| Meal description | Required unless skipped, max 500 chars | "Describe what you usually eat" |
| Coach input | Non-empty trimmed, max 2000 chars | Send `.disabled(true)` |

- Validate `.onChange` on text fields
- Continue always visible — `.opacity(isValid ? 1.0 : 0.5)` when disabled
- On failure: `ScrollViewReader.scrollTo` first error field

### Keyboard Handling

- `.ignoresSafeArea(.keyboard)` on screens where keyboard should push content
- Coach input: `ScrollViewReader` scroll to bottom on keyboard appear
- `TextEditor` for multi-line meal descriptions
- `@FocusState` to advance between fields
- `.submitLabel(.next)` / `.submitLabel(.done)` as appropriate

### Navigation Patterns

| Pattern | Implementation |
|---|---|
| Tab switch | `TabView` selection binding. ViewModels `@StateObject` preserve state. |
| Onboarding back | `NavigationStack` path in `OnboardingCoordinator`. |
| Settings push | `NavigationLink` in `List`. Standard iOS swipe-back. |
| Push notification deep link | `UNUserNotificationCenterDelegate` → set tab + present conversation. |

### Confirmation Patterns

| Action | Pattern |
|---|---|
| Delete account | `.confirmationDialog` — destructive button |
| Sign out | Immediate, no confirmation |
| Disconnect integration | `.alert` |
| Delete meal | `.swipeActions(.destructive)` + `.alert` |
| Add activity | Immediate |

### Data Freshness

| Data | Strategy |
|---|---|
| Today's portions | `.task` + `.refreshable`. SwiftData cache. |
| Week | `.task` + `.refreshable`. Cache per week. |
| Meal library | `.task`. SwiftData cache. |
| Coach messages | `.task`. Optimistic local insert. |
| Strava sessions | Supabase Realtime `channel.on(.postgresChanges)` on `training_sessions`. |

### Claude API Rules

| Rule | Detail |
|---|---|
| Timeout | 30s `URLSession` timeout |
| Max tokens | coach-respond: 500. estimate-meal: 300. |
| Retry | Client retry button. No auto-retry. |
| Input sanitisation | Strip HTML. Enforce max length client-side. |
| Response validation (meals) | Decode JSON. Validate positive numbers. Reject on failure. |
| History | Last 20 messages (10+10). System prompt always included. |
| Rate limiting | Disable send for 2s after each message. |

### Push Notifications

| Event | Copy | On Tap |
|---|---|---|
| Strava run complete | "Nice work on that {X}K — how did it feel?" | Coach tab, linked conversation |

**Permission timing:** After screen 17 completes, before Today tab appears. `UNUserNotificationCenter.requestAuthorization`. If denied, recoverable via Settings → Notifications.

### Accessibility

| Element | Implementation |
|---|---|
| Portion dots | `.accessibilityLabel("2 of 4 portions — normal serving")` on group |
| Meal card | `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)` |
| Coach bubbles | `.accessibilityLabel("Coach said: \(content)")` |
| Colour contrast | Verify all combinations WCAG AA (4.5:1) in Xcode Accessibility Inspector |
| Dynamic Type | All fonts via `Theme` static values — scale automatically |
| Touch targets | `.frame(minWidth: 44, minHeight: 44)` on all interactive elements |

---

## V2 Build Phase Checklist

> **Philosophy:** Product-first. See the product on device early. Layer real data underneath.
>
> **Every phase workflow:**
> 1. Claude Code (Opus 4): Stage 1 Plan only — list files + what each does
> 2. Paste plan into advisory chat for review and approval
> 3. Approved → Claude Code (Sonnet 4.6): execute
> 4. Self-review vs AGENTS.md
> 5. Build + run on iPhone
> 6. Commit with phase summary
>
> **Never skip Step 2. Never advance with known bugs. Always test on device.**

### Phase 1 — Project Setup & Auth

- [ ] Add SPM packages: supabase-swift, clerk-ios, purchases-ios, mixpanel-swift
- [ ] `Core/Theme.swift` — all design tokens
- [ ] `Core/Constants.swift` — all IDs, limits, URLs
- [ ] `Services/SupabaseService.swift` — client singleton with Clerk JWT injection
- [ ] `Services/ClerkService.swift` — sign in, sign up, sign out, Apple OAuth, Google OAuth
- [ ] `Services/RevenueCatService.swift` — initialise, entitlement check (stub)
- [ ] `Services/MixpanelService.swift` — initialise with token
- [ ] `CRUNCHApp.swift` — initialise all services on launch
- [ ] `ContentView.swift` — routing: splash / onboarding / main tabs based on Clerk + onboarding state
- [ ] `Features/Auth/SplashView.swift` — per spec
- [ ] `Features/Auth/SignInView.swift` — email + Apple + Google + forgot password
- [ ] `Features/Auth/SignUpView.swift` — email + Apple + Google
- [ ] `Features/Auth/ForgotPasswordView.swift`
- [ ] `Components/PrimaryButton.swift` — loading + disabled states
- [ ] `Components/ErrorBanner.swift`
- [ ] Empty `TabView` shell with four placeholder tabs
- [ ] Run on device: sign up (email), sign in, sign out, Apple sign-in
- [ ] Verify Supabase `users` table shows row with `clerk_id`
- [ ] **Security audit:** no secrets in bundle, RLS confirmed

**Exit criteria:** Sign up, sign in (email + Apple + Google), sign out all work on iPhone. Supabase shows user row with clerk_id.

### Phase 2 — Today Tab (hardcoded data)

- [ ] `Features/Today/TodayView.swift` — full layout, hardcoded data
- [ ] `Features/Today/MealCardView.swift` — collapsed + expanded states
- [ ] `Features/Today/PortionDotsView.swift` — with accessibility label
- [ ] `Features/Today/ActivityToggleView.swift` — sheet with 6 options
- [ ] Race countdown header (hardcoded)
- [ ] Session context label (hardcoded)
- [ ] 3 hardcoded meal cards
- [ ] "Want something different?" (UI only)
- [ ] Activity add → local `@State` update, no backend
- [ ] Post-run prompt card
- [ ] All tab states as `enum` with SwiftUI previews
- [ ] Test on device: scroll, expand, collapse, add activity
- [ ] **Security audit**

**Exit criteria:** Today tab looks and feels like design spec on iPhone.

### Phase 3 — Coach Tab

- [ ] `Features/Coach/CoachView.swift` — full chat interface
- [ ] `Features/Coach/CoachMessageView.swift` — user + coach bubbles
- [ ] `Features/Coach/CoachInputView.swift` — pinned input + send
- [ ] Empty state with 3 prompt chips
- [ ] Typing indicator (animated dots)
- [ ] `Services/AnthropicService.swift` — POST to `coach-respond` Edge Function
- [ ] Wire send → Edge Function → display response
- [ ] Conversation + message storage in Supabase
- [ ] Load history on tab appear
- [ ] Date section headers
- [ ] Auto-scroll to bottom
- [ ] Test on device: send message, verify Coach response uses portion language
- [ ] **Security audit:** Anthropic key only in Edge Function

**Exit criteria:** Coach conversation works end-to-end. Messages persist across restarts.

### Phase 4 — Macro Engine & Portion Engine

- [ ] `Engines/MacroEngine.swift` — BMR, TDEE, carbs, protein, fat per spec
- [ ] `Engines/PortionEngine.swift` — gram targets → portion multipliers
- [ ] `CRUNCHTests/MacroEngineTests.swift` — unit tests for key calculations
- [ ] `CRUNCHTests/PortionEngineTests.swift`
- [ ] Replace hardcoded Today tab data with real calculations (test user profile)
- [ ] Activity toggle writes to `training_sessions` + triggers recalculation
- [ ] Pre-populated gym days from user profile (with dismiss)
- [ ] All Today states working with real data
- [ ] Test on device: portion dots change on activity add
- [ ] **Security audit**

**Exit criteria:** Today tab shows real portions. Unit tests pass.

### Phase 5 — Onboarding (17 screens)

- [ ] `Features/Onboarding/OnboardingCoordinator.swift` — `@Observable`, holds all state
- [ ] `OnboardingProgressBar.swift`
- [ ] All 17 screen views per table in spec
- [ ] Auto-advance single-select (0.3s delay)
- [ ] `.pickerStyle(.wheel)` for age, weight, height
- [ ] Multi-select screen 10 with "Nothing else" deselects all
- [ ] `TextEditor` meal screens 11–13 with skip + add another
- [ ] Wire meals → `estimate-meal` → `meals` table
- [ ] Write all data to Supabase on account creation (screen 16)
- [ ] Initial macro target generation post-signup
- [ ] Screen 17 → push notification permission request → Today tab
- [ ] Full flow test on device. Verify Supabase: meals, race, user, macro_targets
- [ ] **Security audit**

**Exit criteria:** Full 17-screen flow works. All data in Supabase. Today tab shows real personalised portions.

### Phase 6 — Nutrition Tab & Week Tab

- [ ] `Features/Nutrition/NutritionView.swift`
- [ ] `MealLibraryView.swift` — grouped, edit, add
- [ ] `ScienceCardView.swift` — 4 `DisclosureGroup` cards with citations
- [ ] `MacroDetailView.swift` — opt-in toggle
- [ ] Add/edit meal → estimate-meal → Supabase
- [ ] `Features/Week/WeekView.swift` — nav, summary, 7 day rows
- [ ] `DayRowView.swift` — expandable
- [ ] Week navigation prev/next with phase label
- [ ] Gym days pre-populated from profile
- [ ] No Runna state
- [ ] Test on device: all interactions
- [ ] **Security audit**

**Exit criteria:** All 4 tabs functional. Nutrition shows real meal library. Week shows training week.

### Phase 7 — Integrations

- [ ] Strava OAuth in screen 15 + Settings → Integrations
- [ ] Runna iCal URL in Settings → Integrations
- [ ] Verify `strava-webhook` processes real run
- [ ] Verify `runna-sync` cron
- [ ] Supabase Realtime on `training_sessions` → recalc Today portions
- [ ] Push notification on completed run → deep link Coach
- [ ] Coach auto-first-message linked to session
- [ ] Test: real Strava run → full post-run flow on device
- [ ] **Security audit**

**Exit criteria:** Real Strava run triggers notification → Coach conversation → Today portions update.

### Phase 8 — Settings & Polish

- [ ] All settings views per spec
- [ ] Delete account: Supabase data + Clerk delete + sign out
- [ ] Dynamic Type: verify all text scales
- [ ] VoiceOver: audit Today, Coach, onboarding with screen reader
- [ ] Test iPhone SE + iPhone 15 Pro Max
- [ ] Mixpanel: verify events in dashboard
- [ ] Full regression: splash → onboarding → all tabs → settings → sign out → sign in
- [ ] **Final security audit — all 11 rules**

**Exit criteria:** Every screen works. No known bugs. Accessibility passes.

### Phase 9 — Subscriptions & TestFlight

- [ ] `Features/Paywall/PaywallView.swift` — monthly + annual + trial
- [ ] RevenueCat purchase flow (monthly + annual)
- [ ] Entitlement gate on main tabs
- [ ] Restore purchases in Settings → Subscription
- [ ] StoreKit sandbox test on device
- [ ] Xcode archive → App Store Connect upload
- [ ] TestFlight submission
- [ ] Invite 3–5 beta testers (real runners)
- [ ] Monitor RevenueCat + Mixpanel + Supabase during beta

**Exit criteria:** Real runners on TestFlight. Subscription flow works end-to-end.

---

## Reference Files

- `docs/crunch-design-spec-v2.md` — Complete V2 UI spec
- `docs/crunch-mockup.tsx` — Interactive mockup (React web — visual reference only, translate to SwiftUI)
- `supabase/` — Live Edge Functions and migrations (do not modify unless phase requires it)
