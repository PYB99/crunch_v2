# Crunch — Product Strategy & Competitive Analysis

> **Date:** 2026-07-03
> **Purpose:** Where Crunch sits in the marathon-nutrition market, the gaps worth owning, and the highest-leverage work to do now. Grounded in competitive + sports-science research (sources at end).

---

## 1. Competitive landscape

| Player | What it is | Strength | Weakness Crunch can exploit |
|---|---|---|---|
| **Hexis** | Carb-periodisation app for endurance athletes ("Carb Coding") | Same core thesis as Crunch; science-led; pro-team users | Clunky/complex UI, cycling-first, ~$20/mo, poor food logging, **shows grams not portions**, "launched too early" (per App Store + TrainerRoad reviews) |
| **Precision Fuel & Hydration (PF&H)** | Race-day fuel + hydration planner + products | Owns race-day & sodium; **31,000+ marathoners** used the free planner; sweat testing | Product company, not a daily companion app; no daily periodisation, no AI, no meal personalisation |
| **MyFitnessPal / Cronometer / MacroFactor / PlateLens** | Calorie/macro logging | Huge food DBs, accurate logging | Weight-loss framed, gram-counting, not endurance-periodised — the thing Crunch deliberately rejects |
| **Runna / TrainingPeaks** | Training plans | Plan generation, wearable sync | Nutrition is thin/absent — **complementary** (Crunch already ingests Runna as a data source) |

**Takeaway:** The direct competitor (Hexis) is beatable on UX and positioning, and the most-proven adjacent demand (PF&H race-day/hydration) is a vertical Crunch doesn't touch at all.

## 2. Crunch's existing moat — keep and sharpen

- **Portions, not grams.** Hexis shows numbers; Crunch shows "double your usual pasta." This is the winning consumer UX — protect it.
- **Meal-library personalisation** built during onboarding — advice anchored to what the user actually eats.
- **Conversational AI coach** — Hexis has no good equivalent.
- **Anti-diet / "fuel for your race, not your weight" / no-compliance framing** — a defensible brand position that is also RED-S-aligned (see §4). Genuinely differentiated in a market saturated with calorie-deficit apps.
- **Strava + Runna integration** already shipped.

## 3. The whitespace — what would make Crunch best-in-class

The winning move is **not** more meal tracking (a losing race vs MyFitnessPal). It's to unify the three fueling phases no one has put in one clean, portions-first app:

1. **Daily fueling** — Crunch's current strength.
2. **Race-day + in-run fueling** — **the biggest gap.** Carbs/hour, gel/drink-mix timing by km or split ("at 15 km, gel #2"), personalised to duration and gut-trained level. PF&H's 31k-user planner proves the demand; Crunch has zero here today.
3. **Gut training** — progressive carb-tolerance protocol (≈30 → 90 g/hr over 8–10 weeks), anchored to the race countdown Crunch already computes. Science-backed, almost unowned in consumer apps, and fits the "training companion" theme perfectly.

**Adjacent gaps also worth owning:**
- **Hydration & sodium** — sweat rate + personalised fluid/sodium. Half of what PF&H is famous for; absent from Crunch.
- **Female-athlete / RED-S safety** — see §4.

**Current science to bake in** (updates vs the numbers in AGENTS.md, which cap race intake lower):
- Race intake: **60–90 g carbs/hr** (serious recreational), **90–120 g/hr** (gut-trained), via **glucose:fructose ≈ 2:1** (separate GLUT5 transporter enables higher totals).
- Gut training: start 8–10 weeks out, ~30–40 g/hr, +10–15 g every 2–3 weeks; small amounts every 15–20 min.

## 4. Safety as a differentiator (not an afterthought)

A nutrition app that *gives advice* carries real risk, and Crunch's users skew toward the exact population — endurance runners, especially female — at elevated risk of **RED-S** (Relative Energy Deficiency in Sport). Turning that risk into a moat is the "fuel not weight" brand made literal. Detailed build plan: `docs/phase11-plan.md`.

The female-athlete work has **two layers, and the ordering is deliberate — the safety spine first, the optimization second:**

**Layer 1 — RED-S / low-energy-availability safety (higher certainty, higher impact).** Female endurance runners carry elevated risk of the Female Athlete Triad (low energy availability → menstrual dysfunction → low bone density) plus iron deficiency (menstrual losses + foot-strike hemolysis). The module should:
- Screen gently with a validated instrument (**LEAF-Q**-style: irregular/absent periods, GI symptoms, stress-fracture history).
- Detect chronic under-fueling from data Crunch already holds — targets consistently unmet, RPE-vs-intake mismatch, and (see the weight-validation note) an unexpected **weight drop** as a signal.
- Respond by surfacing support and **never** pushing a deficit — which *reinforces* the brand instead of fighting it. It **flags and refers; it never diagnoses.**

**Layer 2 — cycle-aware fueling (real, but nuance-heavy — treat modestly).** The physiology is genuine: the **luteal phase** brings higher core temperature (hydration/sodium matter more), increased protein catabolism (nudge protein up slightly), harder carb access at high intensity, and often worse GI tolerance; the **follicular phase** favours carb use and hard sessions. But individual variation is large, the evidence is still maturing, and reviews caution against *over*-prescribing rigid cycle periodization — so this stays **modest and individualized** (gentle, visible nudges — never silent macro rewrites), and must branch correctly across **natural cycle / hormonal contraception (no periodization) / amenorrhea (itself a RED-S flag) / perimenopause**. Cycle timing comes from **HealthKit**, kept **on-device** (menstrual data is special-category health data — don't sync it to the cloud).

**Two hard requirements that make this professional rather than reckless:**
- **Clinical review before ship.** RED-S screening logic + copy should be validated by a sports dietitian / RED-S specialist — not shipped by a dev+model team alone.
- **Medical disclaimers + citation-backed coaching**, and a **red-team Coach eval** proving it responds safely to a vulnerable user (never enables disordered eating, never diagnoses).

This is also what separates "professional grade" from "toy": measurable AI quality and safety, not vibes.

## 5. Where to point Fable 5 now — prioritized

Highest value from a frontier model = the **durable "brain" pieces**: knowledge-intensive work (algorithm design from literature, eval sets, safety guardrails) that is hard and expensive to redo later. Do these while you have the access.

1. **Fix the audit's Critical items first** (`docs/phase7-audit.md`) — reconcile the two macro engines, backfill the empty base migrations, resolve Swift 6. No new verticals on a cracked foundation.
2. **Race-Day Fueling engine + UI** — deterministic algorithm (carbs/hr by duration × gut-trained level, 2:1 glucose:fructose, fluid + sodium/hr), Edge Function, race-week → race-plan surface. **The single biggest differentiator.**
3. **Gut-Training protocol engine** — 8–10-week progressive plan anchored to race date, weekly targets, logged tolerance, auto-adjust. Nearly unowned.
4. **AI safety + eval harness** — RED-S guardrails, disordered-eating-safe language, medical disclaimers, citation-backed Coach system prompts, and a **golden-set eval** for `estimate-meal` + `coach-respond` so quality is measured. Fable is unusually strong at authoring evals + red-teaming prompts. Non-negotiable; run in parallel.
5. **HealthKit integration** — weight, workouts, resting HR, VO₂max, sleep, menstrual cycle from Apple Health. Kills manual entry, powers personalisation, table-stakes for a premium iOS health app.
6. **Hydration & sodium module** — sweat-rate flow + personalised fluid/sodium, folded into the race plan.
7. **Curated sports-nutrition product DB** — gels/drinks/real-food carb+sodium seed data so plans are concrete ("2 Maurten 160 + 1 SIS Beta Fuel").
8. **Female-athlete / RED-S module** — screening + low-EA detection. High value, sensitive — design carefully; likely a fast-follow, not the first bet.
9. **Onboarding conversion / science storytelling** and **App Store launch readiness** — privacy nutrition labels, ATT, VoiceOver + Dynamic Type audit, paywall polish, TestFlight.

**Recommended sequence:** foundation (1) → race-day + gut-training vertical (2, 3) → AI safety/eval layer (4, in parallel) → HealthKit (5) → hydration (6) + product DB (7) → female/RED-S (8) → launch polish (9).

**Honest caveat:** Crunch is mid-build (Phase 7). Adding race-day + hydration + gut-training + female modules at once is scope overload. The focused bet that vaults past Hexis and into PF&H's territory in one coherent story is **race-day fueling + gut training + the safety/eval layer**. Everything else is fast-follow.

---

## Sources

- [Hexis](https://hexis.live/) · [Hexis App Store reviews](https://apps.apple.com/us/app/hexis-live/id1610334327) · [TrainerRoad: experience with Hexis](https://www.trainerroad.com/forum/t/anyone-with-experience-using-nutrition-app-hexis/85624)
- [Precision Fuel & Hydration — Fuel & Hydration Planner](https://www.precisionhydration.com/planner/) · [PF&H marathon fueling](https://www.precisionhydration.com/marathon-fueling/)
- [Best calorie/nutrition apps for runners 2026 (BestCalorieApps)](https://bestcalorieapps.com/en/articles/best-calorie-tracking-apps-for-runners-endurance-athletes-2026/) · [MAVR: best running apps 2026](https://www.mavr.app/blog/best-running-apps-2026-complete-guide)
- [Carbs per hour for a marathon (Run Your Personal Best)](https://www.runyourpersonalbest.com/post/how-many-carbs-per-hour-marathon) · [Marathon gut training (RunnersConnect)](https://runnersconnect.net/marathon-gut-training/) · [The Running Channel: marathon fuelling](https://therunningchannel.com/marathon-fuelling-strategy/)
- [Periodized carbohydrate intake & running economy (Frontiers, 2025)](https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2025.1750042/full) · [Marathon Handbook: matching carbs to load](https://marathonhandbook.com/are-endurance-athletes-matching-their-carbs-to-training-load/)
- [Nutritional considerations for female athletes (Sports Medicine, 2021)](https://link.springer.com/article/10.1007/s40279-021-01508-8) · [LCA & RED-S in female endurance athletes (review)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10609849/) · [Nutrition for female runners: iron deficiency & RED-S](https://www.momsontherun.com/2026/07/02/nutrition-for-female-runners-proper-fueling-to-avoid-iron-deficiency-and-red-s/)
