# Crunch — Conversion Onboarding, Market Size & Pricing

> **Date:** 2026-07-03
> **Purpose:** A conversion-optimized onboarding funnel (Cal AI-style, research-grounded), the total addressable market, and a pricing + revenue model. Sources at end.
> **Companion docs:** `product-strategy.md` (positioning), `phase10/11-plan.md` (feature verticals), AGENTS.md (existing 17-screen onboarding spec this supersedes).

---

## Part 1 — The onboarding funnel (the #1 conversion lever)

### What the research says (apply all of it)

- **Long, invested onboarding beats short.** Cal AI's extensive quiz gets users "psychologically invested before they're asked to pay" — high drop-off, but completers "are far more likely to convert and stay." More screens, done right, = more revenue.
- **Hard paywall, not freemium.** Hard paywalls convert **10.7% trial→paid at D35 vs 2.1% for freemium — ~5×.** Gate the app behind the plan + trial.
- **Day 0 is everything.** 82% of trials start, 55% of cancels happen, and ~50% of conversions happen **on install day.** The first session must reach the "aha" and the paywall.
- **Long trials convert better.** 17–32-day trials convert ~42.5% vs 25.5% for <4-day trials. AGENTS.md's 7-day trial is the floor — **A/B test 14-day.**
- **Price high enough.** High-priced apps convert downloads **2× better** than cheap ones (2.8% vs ~1.4%) — premium signals value. Don't race Cal AI to $30/yr.
- **Instant personalized value.** Cal AI shows a projected graph from quiz answers before the paywall. Crunch's analog is the **personalized race fuel plan reveal** — but framed as *readiness*, never weight (brand rule).
- **Anchor + recover.** Annual anchored as "best value" against monthly; a one-time discount offer catches decliners.

### Brand guardrail (important tension)

Aggressive funnels lean on fear/shame/streaks. Crunch is deliberately anti-diet ("suggestions, not obligations"; forbidden: `deficit`/`weight loss`/`compliance`). **Use aspiration and mastery, not shame:** "fuel right, race strong," "don't hit the wall," race-day anticipation — not "you're failing." The motivation is the *race*, not the body.

### The flow — ~28 screens in five acts *(Rev 2, 2026-07-04 — see revision note below)*

Builds on the AGENTS.md 17-screen spec; the **new** conversion screens are marked ★.

**Act 1 — Hook (first tap within two screens; interaction = investment)**
1. Splash — "Fuel for your race. Not your weight." → Get Started
2. ★ Pain question (interactive) — "Ever hit the wall?" → *Yes, in a race / Yes, in training / Not yet — racing soon* (pain admission as a tap, not a poster; personalizes downstream copy)
3. ★ Social proof + problem — "Most runners under-fuel. Join the runners fueling smarter" + star rating (merged; race-framed, never body-framed)

**Act 2 — Goal & commitment (single-select auto-advances)**
4. ★ Attribution — "Where did you hear about Crunch?" (Reddit / friend / App Store / social / other — channel measurement from day one)
5. ★ "What's your goal?" — Finish my first / Chase a PB / Feel strong to the line / Stop bonking
6. Race type — 5K / 10K / Half / Marathon / Ultra
7. Race name + date → instant "**98 days to go**"
8. Hook — "Amsterdam Marathon is in 98 days" (dynamic, emotional, brand-colored number)

**Act 3 — Personalization quiz (the "investment" — biometrics → training → meals)**
9. Biological sex — framed "so we calculate your fuel accurately" (BMR)
10. Age · 11. Weight (unit-aware + validated) · 12. Height
13. Training level · 14. Days/week running · 15. Other activities (gym/cycle/swim)
16. ★ "How's your fueling now?" — bonk often? GI issues on long runs? (seeds gut-training & RED-S modules)
17–19. Meals: breakfast / lunch / dinner free-text (the personalization core; estimated post-signup)

**Act 4 — Build & aha (the payoff — the reason they'll pay)**
20. ★ "Building your personalized fuel plan…" — animated progress with rotating science proof-points; "how Crunch works" woven into the build copy (perceived effort → perceived value)
21. ★ **Aha reveal** — "Your race fuel plan is ready": personalized daily portions + "on race week, double portions of pasta"
22. ★ **Rating request** — immediately after the aha, at peak delight ("Help other runners find this") → `SKStoreReviewController`. The Cal AI signature move, and it feeds the ASO flywheel in `organic-growth-plan.md` — ratings gate search visibility.
23. Fueling-readiness chart — current vs optimized (the motivating *gap*, framed as readiness never weight)
24. ★ "Meet your coach" — a sample Coach message personalized to *their* race + *their* meals (second aha)

**Act 5 — Convert (paywall BEFORE account — see revision note)**
25. Connect Strava/Runna intent (Skip allowed) — "auto-adjust your fuel to every run" (OAuth runs post-signup)
26. ★ Notification priming + commitment — "You're 98 days out. Want post-run fueling tips and race-week reminders?" (merged soft-ask + commitment line)
27. ★ **Paywall (hard)** — Annual hero ($89.99 · "~$0.25/day" · 7-day free trial) anchored above Monthly ($14.99); one testimonial on-page; **trial-timeline visual** ("Today: full access → Day 5: we remind you → Day 7: first charge") + **"Remind me before my trial ends" toggle** (Blinkist-tested — lifts trial starts and cuts refunds/cancels); "cancel anytime" + restore link. Decline → ★ one-time discounted-annual offer.
28. ★ **Create account AFTER purchase** — "Save your plan" — **Sign in with Apple as the hero** (one tap, no password, no email code); Google/email fallback. Post-payment completion is near-certain. **Non-buyers who declined both offers also get this screen** — email capture for race-week lifecycle emails (a recovery channel).
→ OS push permission → backend batch write → Today tab, plan live.

**Why this converts:** first tap by screen 2, ~24 screens of investment, a rating ask at peak delight, two aha moments — and the paywall hits at peak perceived value **before** any signup friction. Account creation (the highest-friction screen in any funnel, especially with email verification) moves *after* the purchase, where it costs nothing.

> **Revision note (Rev 2, max-effort review):** four upgrades over Rev 1, each research-backed:
> 1. **Paywall moved before account creation.** RevenueCat supports anonymous purchases aliased to identity later (`Purchases.logIn(clerkId)`), so signup friction — previously placed at peak drop-off, directly ahead of the money ask — now sits post-payment. Also friendlier to App Store guideline 5.1.1.
> 2. **In-onboarding rating request** added post-aha — Rev 1 omitted it while `organic-growth-plan.md` simultaneously said ratings gate ASO; the docs contradicted each other.
> 3. **Trial-timeline + reminder toggle** added to the paywall (the tested Blinkist pattern; transparency lifts trial starts ~2× in their published case and reduces Day-7 surprise cancels).
> 4. **Tightened 31 → ~28**: problem screen became an interactive question; testimonial/how-it-works stacked-info screens folded into the build screen and paywall (four consecutive non-interactive screens was a drop-off cliff); attribution question added for channel measurement.

---

## Part 2 — Total addressable market

Illustrative, with explicit assumptions — treat as sizing, not forecast.

| Layer | Definition | Size | Annual value @ ~$90 ACV |
|---|---|---|---|
| **TAM** | Endurance runners globally training for races who'd pay for nutrition guidance | ~20–40M runners | **~$2–4B** |
| **SAM** | iOS, English-first, marathon/half/ultra racers who care about fueling | ~3–6M | ~$300–500M |
| **SOM (3-yr, ambitious)** | Realistic capture as the category's nutrition companion | ~30k–120k subs | ~$3–11M ARR |
| **SOM (18-mo, conservative)** | Early traction | ~5k–15k subs | ~$0.5–1.5M ARR |

**Grounding:** the running-apps market is ~$1.8B (2025) → $4.6B (2034); >200M running-app users; the endurance-event market is ~$11B. The decisive comp is **Runna: ~1M MAU and ~$40M ARR run-rate in ~3 years** at $17.99/mo, then **acquired by Strava (Apr 2025)** — proof both of willingness-to-pay for running subscriptions and of a concrete **exit path** (Strava/Runna, or a fuel brand like Precision/Maurten, buying the nutrition companion). Crunch doesn't need Runna's scale; **2% of Runna is a real business.**

---

## Part 3 — Pricing & revenue model

### Recommended pricing

| Plan | Price | Effective | Role |
|---|---|---|---|
| **Annual** (hero) | **$89.99/yr** + 7-day trial | ~$7.50/mo (~50% off) | Drives the base; anchor as "best value" |
| **Monthly** | **$14.99/mo** | — | The expensive alternative that makes annual look cheap |
| Launch/founder (optional) | $59.99 first year | — | Early-adopter urgency |

Positioned **just under Runna ($17.99 / $109.99) and Hexis ($20/mo)** — Crunch is a focused companion, not a full plan — but **well above mass-market Cal AI (~$30/yr)**, because premium pricing both signals quality and converts 2× better. AGENTS.md's RevenueCat scaffold (monthly/annual products, `pro` entitlement, 7-day trial) already supports this; only the price points are new.

### Unit economics (per 1,000 installs, base case)

| Step | Rate | Result |
|---|---|---|
| Complete onboarding → reach paywall | 60% | 600 |
| Start free trial (hard paywall) | 30% of paywall | 180 |
| Trial → paid | 12% | ~22 payers |
| **Install → paid** | **~2.2%** | (vs 2.8% high-price benchmark — conservative) |

### Steady-state MRR by install volume

Assumes 2.5% install→paid, **$9 blended ARPU/mo** (annual-heavy mix), **6% monthly churn** (annual lowers it). Steady state ≈ new-payers ÷ churn; reached in ~12–18 months.

| Installs/mo | New payers/mo | Steady-state subs | **Steady-state MRR** | ARR |
|---|---|---|---|---|
| 3,000 (organic / early) | 75 | ~1,250 | **~$11k** | ~$135k |
| 10,000 (modest paid + content) | 250 | ~4,170 | **~$37k** | ~$450k |
| 30,000 (scaling) | 750 | ~12,500 | **~$112k** | ~$1.35M |

**Sensitivity:** at conservative 1.5% install→paid, halve these; at optimized 3.5% (well-tuned funnel, Cal AI improved trial→paid 31% via testing), roughly +40%.

### The real constraint: installs & CAC

Revenue is gated by **installs**, not the funnel math. First-year value per payer ≈ **$75** (annual-heavy); with renewals, LTV ≈ **$110–140**. That supports a blended CAC of only **~$1.50–3.00/install** for healthy payback — thin for paid social alone. **Implication: organic is the growth engine** — running communities, Strava clubs, RED-S/female-athlete content, race-day SEO (PF&H's playbook), Runna-style App-Store editorial. The content/credibility moat from `product-strategy.md` isn't just brand — it's the CAC strategy.

### Bottom line

A tuned funnel + premium annual pricing makes **~$35–110k MRR realistic at 10–30k installs/month once ramped** — a **$0.5–1.5M ARR** business inside ~18 months at modest scale, with a **$3–11M** ceiling as the category's nutrition companion and a credible Strava/fuel-brand acquisition path. The gating factor is distribution, not monetization — so invest the Fable-grade effort in the onboarding funnel (this doc) and the credibility content (strategy doc), which are exactly the two things that lift both conversion *and* organic install volume.

---

## Sources

- [Cal AI onboarding breakdown (screensdesign)](https://screensdesign.com/showcase/cal-ai-calorie-tracker) · [Cal AI × Superwall — 3× revenue, 123 paywall experiments](https://superwall.com/case-studies/cal-ai) · [Cal AI to $2M/mo case study](https://sebastianstef.com/resources/cal-ai-case-study)
- [RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/) · [SaaStr — top 10 learnings (hard paywall 5×, trial-length data)](https://www.saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps-how-115000-mobile-apps-deliver-16b-in-revenue-whats-working-whats-quietly-killing-growth/) · [Business of Apps — trial benchmarks 2026](https://www.businessofapps.com/data/app-subscription-trial-benchmarks/)
- [Running apps market size](https://dataintelo.com/report/global-running-apps-market) · [Marathon Handbook — how many run marathons](https://marathonhandbook.com/how-many-people-have-run-a-marathon/) · [Strava statistics 2026 (Business of Apps)](https://www.businessofapps.com/data/strava-statistics/)
- [Runna case study (RevenueCat)](https://www.revenuecat.com/customers/runna) · [Why Strava acquired Runna](https://stysin.com/p/strava-acquired-runna) · [Runna pricing](https://www.runna.com/pricing) · [Hexis App Store](https://apps.apple.com/us/app/hexis-live/id1610334327)
