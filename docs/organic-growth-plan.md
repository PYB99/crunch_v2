# Crunch — Organic Growth Plan (ASO · Reddit · SEO)

> **Date:** 2026-07-04
> **Purpose:** A research-backed organic acquisition plan — App Store Search Optimization, Reddit/community, and web SEO/tools — with realistic install and revenue numbers for this niche, *before* paid ads. Sources at end.
> **Feeds:** the funnel + revenue model in `docs/onboarding-and-growth.md` (2% install→paid, ~$9 ARPU, 6% churn).
> **The one number I can't give precisely:** exact App Store keyword *search volumes* aren't published — pull them post-launch from App Store Connect (free) + an ASO tool (AppTweak/Sensor Tower). Everything below is benchmarked; volumes are ranged and flagged.

---

## 0. The honest reality: organic for a *fitness* app is a three-legged stool

Search is 65% of iOS discovery overall — but **Health & Fitness apps get only 27–41% of organic installs from ASO surfaces**; brand, referral, and word-of-mouth carry more weight than in most categories. Translation: **ASO alone will not carry Crunch.** The winning organic motion is three channels that *reinforce* each other:

1. **ASO** — captures people already searching the App Store ("marathon nutrition").
2. **Reddit/community** — *creates* demand and brand in the exact niche, fast, pre-ads.
3. **SEO + free web tools** — captures Google long-tail, compounds, and feeds the other two (content ranks → gets shared on Reddit → drives brand searches that lift ASO).

The keystone that sits in all three: **a free web tool** (carb-loading / race-fuel calculator). It ranks in Google, it's shareable on Reddit *without* being spam, and it drives brand searches + web-to-app installs. Precision Fuel & Hydration proved the model — their free planner reached **31,000+ marathoners**.

---

## 1. ASO — capture App Store search demand

### Benchmarks to design against
- **Search TTI (tap-through-to-install) on iOS: ~33.4%.**
- **Health & Fitness product-page CVR: ~18–31%** (use ~18–20% conservative).
- **Custom Product Pages lift CVR +5.9–8.6%.**
- **Ratings are a top ranking + conversion factor:** <3.5★ = severely reduced visibility; >4.0★ = higher rankings. This is non-negotiable.
- **Seasonality:** fitness keyword demand spikes **January** (resolutions) and **May–June**; marathon training peaks **summer** for fall races. Time pushes to these.

### The work
- **Metadata (the highest-leverage 30-character real estate):**
  - *App name/title*: brand + top keyword — e.g. "Crunch: Marathon Fuel & Nutrition."
  - *Subtitle*: secondary keywords — "Race fueling, carb loading, coach."
  - *Keyword field (100 chars)*: no spaces, no repeats, singular forms — `marathon,nutrition,running,fuel,carb,loading,race,gel,ultra,half,fueling,runner,diet,hydration,coach`.
- **Target keyword themes** (own the gap competitors ignore — Hexis/Runna/MyFitnessPal don't own "marathon fueling"): *marathon nutrition · race fueling · carb loading · running nutrition · marathon fuel plan · gut training · gel/hydration calculator · ultra nutrition.*
- **Custom Product Pages** per theme (marathon / half / ultra / gut-training) — +6–9% CVR, and each is a linkable landing page for Reddit/content campaigns.
- **Screenshots + preview video**: lead with the aha (personalized fuel plan, portions-not-grams, AI coach). First 2 screenshots do ~80% of the work.
- **Reviews engine**: in-app `SKStoreReviewController` prompt *after the aha* (plan reveal / first great coach reply), never mid-task. Target **4.5★+**. This gates everything else.
- **In-App Events**: publish race-season / "New Year fueling reset" events for extra search surfaces + seasonality.

### Realistic ASO numbers (niche = modest but high-intent)
Marathon *nutrition* is a narrow App Store category, so ASO is high-intent but low-volume. Ranged estimate at maturity (months 6–12, good ranking + 4.5★):

| | Conservative | Base | Optimized + seasonal peak |
|---|---|---|---|
| Organic search installs/mo | ~300 | ~700 | ~1,500 |

This modest ceiling is *exactly why* Reddit + content matter — and it aligns with fitness apps getting only ~a third of installs from ASO.

---

## 2. Reddit — the pre-paid-ads wedge

Reddit is where the endurance niche actually lives, and its content now ranks in Google — so good Reddit activity doubles as SEO.

### The communities (approx — verify live counts on-platform)
| Subreddit | ~Members | Fit |
|---|---|---|
| r/running | ~3.5M | Broad top-of-funnel |
| r/AdvancedRunning | ~477k | **Core** — serious, nutrition-literate |
| r/Marathon_Training | ~250k | **Core** — in-market, race-focused |
| r/firstmarathon | ~120k | **High-intent** — anxious first-timers = perfect fit |
| r/trailrunning · r/Ultramarathon | ~200k each | Ultra fueling = strong fit |
| r/XXRunning | ~76k | Female runners → ties to the RED-S module |

### The rules that keep you un-banned
- **90/10 rule**: ≥90% genuine value, ≤10% promotion. Overt "download my app" = downvoted/banned.
- Each subreddit's self-promo rules override sitewide — read every sidebar.
- **Founder-led + transparent** ("I'm building this, here's a free tool") beats brand accounts.

### The play
- **Weeks before promoting**, build genuine karma: answer fueling questions with real expertise (you have the science + Fable to draft rigorous, cited answers).
- **Lead with the free tool, not the app** — "I built a free carb-loading calculator" is Reddit-safe; the app is the soft second step.
- Race-season timing (spring/fall), AMAs ("I'm a run-nutrition nerd, ask me anything"), genuinely useful breakdowns.

### Realistic Reddit numbers
Highly variable, front-loaded, decays without presence:
- A **strong, well-received post** in a core sub: ~20–50k impressions → ~1–5k clicks → **~200–1,000 installs** (warm, relevant audience converts click→install higher than cold ads).
- **Sustained** with consistent value + a few strong posts/month: **~500–2,000 installs/mo** during active periods; a viral post or AMA can spike 1,000–5,000 in a week.
- Compounds via Google (Reddit threads rank for "best marathon nutrition app").

---

## 3. SEO + free web tools — the compounding engine

Slowest to start (6–12 mo to rank), but it compounds and is the CAC-killer long-term.

### Free web tools (the keystone — build first)
Rankable, linkable, Reddit-shareable, and a direct web-to-app funnel (PF&H's playbook):
- **Carb-loading calculator** (g/kg by weight × race distance × days out).
- **Race-day fuel calculator** (carbs/hr × goal time → gels/drink plan) — this is your Phase 10 `FuelEngine` exposed on the web.
- **Sweat/sodium estimator** (hydration module preview).
Each tool ends with "want this auto-adjusted to your training? → Crunch" → App Store CPP.

### Content hub (citation-backed — a Fable strength)
Compete with SiS / PF&H / Styrkr on the high-volume, content-rich space: "marathon carb loading guide," "how many carbs per hour," "gut training for runners," "why runners hit the wall." The science is already in AGENTS.md; Fable writes it accurately and at volume. Content → ranks → shared on Reddit → builds brand searches → lifts ASO.

### Realistic SEO numbers
- Months 0–3: ~0 (indexing/ranking lag).
- Months 6–12: ramping to **~10–50k monthly organic web visitors** with a real tools+content program; web→app at **2–10%** → **~500–2,500 installs/mo**, compounding into year 2 (PF&H's 31k-user planner shows the ceiling is high).

---

## 4. The integrated model — organic install trajectory & revenue

Blended monthly installs, base case (Reddit front-loaded, ASO steady, SEO compounding):

| Month | ASO | Reddit | SEO/tools | **Total/mo** |
|---|---|---|---|---|
| 1–2 | ~150 | ~600 | ~0 | **~750** |
| 3–4 | ~350 | ~900 | ~150 | **~1,400** |
| 6 | ~600 | ~1,000 | ~600 | **~2,200** |
| 9 | ~700 | ~1,200 | ~1,200 | **~3,100** |
| 12 | ~800 | ~1,300 | ~2,000 | **~4,100** |

**Exit run-rate ~4,000 organic installs/mo (base), still climbing via SEO.** Conservative ≈ half; optimistic (a viral moment, a tool that ranks #1, 4.7★) ≈ 2–2.5×.

### Organic → revenue (using `onboarding-and-growth.md`: 2% install→paid, $9 ARPU, 6% churn)

| Scenario | Mo-12 installs/mo | New payers/mo | Steady-state subs | **Steady-state MRR** | ARR |
|---|---|---|---|---|---|
| Conservative | ~2,000 | ~40 | ~670 | **~$6k** | ~$72k |
| **Base** | ~4,000 | ~80 | ~1,330 | **~$12k** | ~$145k |
| Optimistic | ~9,000 | ~180 | ~3,000 | **~$27k** | ~$325k |

Note: install→paid here uses **2%** (between the 1.78% onboarding-paywall-with-trial average and the 2.8% high-price benchmark). MRR lags installs by ~6–12 months (steady state = new payers ÷ churn), so the *exit* MRR above understates the trajectory into year 2 as SEO compounds.

**Bottom line:** a disciplined organic-only program can realistically build to **~$6–27k MRR (base ~$12k) within ~12 months** and keep compounding — *then* paid ads scale on top of a proven funnel. Organic isn't free; it's **labor + consistency** (content cadence, community presence, review generation) instead of ad spend. That's the trade at your stage: time for money, and it builds a moat ads can't.

---

## 5. 90-day action plan

**Phase 0 — Pre-launch (weeks 1–4): foundation**
- ASO: keyword research in App Store Connect + one ASO tool; write title/subtitle/keyword field; design screenshots leading with the aha; build 2–3 Custom Product Pages.
- Wire the **in-app review prompt** after the aha.
- Build the **carb-loading + race-fuel web calculators** (reuse Phase 10 `FuelEngine` logic).
- Reddit: create the founder account; spend the month **being genuinely helpful** in r/AdvancedRunning / r/Marathon_Training / r/firstmarathon — zero promotion, build karma + credibility.
- Draft 5–10 cornerstone content pieces (Fable-authored, cited).

**Phase 1 — Launch (weeks 5–8): ignite**
- ASO live; submit to App Store featuring + In-App Events.
- Reddit: launch the **free tool** (not "my app") across core subs, value-first; do an AMA.
- Publish the content hub; interlink tools ↔ articles ↔ CPPs.
- Push for reviews (target 4.5★ fast — it gates ASO).

**Phase 2 — Compound (weeks 9–12): iterate on real data**
- Read App Store Connect **search-term report**; double down on keywords actually converting; A/B test screenshots/CPPs.
- Content cadence (1–2 pieces/week); build backlinks from running blogs/forums.
- Sustain Reddit value; seed race-season posts (time to spring/fall marathons + Jan).
- Measure channel-level install→paid; reallocate effort to the best channel.

### Tools you'll need
App Store Connect (free, post-launch search terms) · AppTweak or Sensor Tower (keyword volumes — the missing number) · GummySearch (Reddit niche mining) · Google Search Console + a keyword tool (SEO) · RevenueCat (channel-level conversion, already in stack).

---

## Sources

- [ASO 2026 stats — search share, TTI, category data (DigitalApplied)](https://www.digitalapplied.com/blog/app-store-optimization-aso-statistics-2026-data) · [ASO in 2026 (ASOMobile)](https://asomobile.net/en/blog/aso-in-2026-the-complete-guide-to-app-optimization/) · [ASO trends 2026 (Phiture)](https://phiture.com/asostack/aso-trends-in-2026/)
- [App Store conversion by category (Adapty)](https://adapty.io/blog/app-store-conversion-rate/) · [Good CVR benchmarks (AppScreenshotStudio)](https://appscreenshotstudio.com/blog/good-app-store-conversion-rate-benchmarks-2026) · [Health & Fitness subscription benchmarks (Adapty)](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)
- [Reddit self-promotion / 90-10 rule (KarmaGuy)](https://karmaguy.io/en/blog/reddit-self-promotion-rules) · [Reddit organic promotion guide (Francesca Tabor)](https://www.francescatabor.com/articles/2025/8/21/using-reddit-for-organic-brand-promotion-a-step-by-step-guide) · [r/AdvancedRunning stats (GummySearch)](https://gummysearch.com/r/AdvancedRunning/) · [r/XXRunning stats](https://gummysearch.com/r/XXRunning/)
- [Precision Fuel & Hydration planner (web-to-app model)](https://www.precisionhydration.com/planner/) · [SiS carb loading by distance](https://www.scienceinsport.com/sports-nutrition/carb-loading-by-race-distance/) · [RunDida carb-loading calculator (tool example)](https://rundida.com/tools/carb-loading/)
