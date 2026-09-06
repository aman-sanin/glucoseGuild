# QUESTLOG: DIABETES EDITION

## (Codename: `GLUCOSE_GUILD`)

**Version:** 1.0.0  
**Date:** 2026-09-06  
**Build Status:** Repurposing existing QUESTLOG Engine (Flutter + Drift + Riverpod).  
**Core Mandate:** Gamify diabetes management using **effort-based positive reinforcement**, not outcome-based punishment.

---

## 1. ✦ Vision & Philosophy

> _"Punish effort, not outcomes."_

Blood glucose is affected by hormones, stress, sleep, and sheer bad luck. This app rewards **observability, velocity, and agency**.

- **Outcome XP** (Glucose) is capped daily to prevent perfectionism.
- **Effort Coins** (Habit logging) are infinite—users earn them for every CGM scan, insulin dose, and carb entry, even (and especially) when numbers are out of range.
- The app provides **zero internet permission** (inherited from QUESTLOG), ensuring absolute privacy for sensitive health data.

---

## 2. Architectural Reuse (The "Drop-In" Strategy)

We are **not** rewriting the engine. We are extending it.

| QUESTLOG Component        | Diabetes Repurpose                                                                              |
| :------------------------ | :---------------------------------------------------------------------------------------------- |
| **Append-Only Ledger**    | Stores CGM scans, insulin units, carb estimates, and water intake as `Completions`.             |
| **Idempotent Settlement** | Calculates Time-in-Range (TIR), Standard Deviation (SD), and "Minutes to Mitigation" daily.     |
| **P12b Coach Engine**     | 10 deterministic detectors (Mastery, Stumble, Zombie, etc.) rewired for diabetic behaviors.     |
| **50-Badge Registry**     | Renamed badges (e.g., "First Responder", "Chef's Kiss", "The Pizza Gauntlet").                  |
| **Calling System**        | 6 Domains reskinned as diabetes archetypes (_The Stabilizer, The Counter, The Hydrator, etc._). |
| **Cadences**              | Daily (scans), Weekly (TIR targets), Single (Endo appointments).                                |

---

## 3. Data Model Migration (Database Extension)

_Action Required:_ Extend the Drift `completions` table without breaking existing habit-tracker logic.

```dart
// lib/data/db/tables.dart
class Completions extends Table {
  // --- EXISTING COLUMNS (Keep as-is) ---
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questId => integer().nullable()();
  DateTimeColumn get completedDate => dateTime()();
  IntColumn get counterValue => integer().nullable(); // For scaling

  // --- NEW DIABETES COLUMNS ---
  TextColumn get numericValue => text().nullable();
  // Stores glucose mg/dL (e.g., "180"), insulin units (e.g., "3.5"), or carbs (e.g., "45")

  TextColumn get contextJson => text().nullable();
  // Stores JSON: {"type": "cgm_scan", "device": "dexcom"} or {"meal_type": "pizza", "bolus_type": "extended"}

  DateTimeColumn get loggedAt => dateTime().nullable();
  // Critical: The exact timestamp of the physical action (vs. when the user logged it).
}
```

**Migration Command:** `dart run build_runner build --delete-conflicting-outputs`

---

## 4. Core Gameplay Loops (The Features)

### A. Split-Track XP System

- **Glucose XP (Outcome):** Earned for TIR ≥ 70%. **Hard Cap:** No extra points for going above 80%. Prevents obsessive stacking.
- **Habit Coins (Effort):** Earned for _every_ scan, carb log, and insulin log. Logging a high (250 mg/dL) + correction dose gives _more_ coins than logging nothing. **This is the primary reward currency.**

### B. The "Stabilizer" Volatility Score

- Visual: A "Sea Level" gauge on the Insights screen.
- **Logic:** Reward users for low Standard Deviation (SD < 30) over 4-hour windows. If glucose stays flat (even at 160-180 mg/dL), grant a **"Calm Seas"** bonus during settlement.

### C. The "Recovery Streak" (Speed of Action)

- **Trigger:** User logs a high (>180 mg/dL).
- **Timer:** Starts a countdown. If they log a correction dose AND a CGM scan within 45 minutes, they earn the **"First Responder"** badge and bonus XP. This turns anxiety into an actionable puzzle.

### D. Pre-Bolus Precision (The Golden Rule)

- **Trigger:** User logs a meal (Carbs).
- **Challenge:** If the user logs Insulin _before_ the meal timestamp (or within 5 minutes of starting), trigger a **"Chef's Kiss"** bonus that doubles their Habit Coins for that meal.

### E. The CGM Pet (Tamagotchi Style - Non-Judgmental)

- **Feature:** A pixel-art companion on the Today screen.
- **Behavior:** The pet’s _mood_ is tied to _logging cadence_, not glucose levels.
  - Scans > 8 times a day? The pet dances.
  - Low glucose? The pet sits down and holds a "Snack Time!" sign (no sad animations—only gentle, actionable reminders).

### F. "Power-Up" Days (Boss Battles)

- **Pizza Gauntlet:** A weekly quest rewarding users for logging extended/square-wave boluses and checking BG 3 hours post-meal.
- **Sick Day Shield:** If the user marks "Ill", the app switches to **Survival Mode**. Logging fluids and ketone checks grants massive XP, and **all TIR penalties are suspended** for that day via the settlement engine.

### G. Hydration & Site Rotation

- **Hydration:** A "River Flow" progress bar. Drinking water grants visual "sparkle" animations and counts toward the _Hydrator_ Calling domain.
- **Site Rotation:** A visual "Pinwheel" dial tracking the last 7 injection/pump sites. Logging a new site grants a **"Rotator Cuff"** point.

### H. The "Time-Traveler" (Improvement Percentage)

- **Insight:** Compares current 7-day TIR vs. previous 7-day TIR.
- **Trigger:** If TIR improves even by **1%** (e.g., 55% → 56%), trigger full-screen "Ember" confetti and a notification: _"Personal Best Trend! +1% to Time in Range!"_

---

## 5. Remapping the P12b Coach Engine (10 Detectors)

Update the `lib/domain/engine/coach.dart` logic. Keep the exponential KV cooldown (`30 → 60 → 90` days) **exactly as built**.

| New Detector Name     | Logic Trigger                                     | Gain-Framed Output String                                                                        |
| :-------------------- | :------------------------------------------------ | :----------------------------------------------------------------------------------------------- |
| **Stabilizer**        | SD < 30 over 4 hours                              | "Calm seas, captain! Your flat line means your basal is dialed in. Take a bow."                  |
| **First Responder**   | High logged + correction within 45m               | "Heroic recovery! You caught that spike and acted fast. That's control."                         |
| **Rotator Nudge**     | Same injection site > 7 days                      | "Your scar tissue is begging for a break. Rotate to a new spot today for bonus coins."           |
| **Pre-bolus Pro**     | Meal logged, but insulin logged > 15m late        | "Prep work wins wars. Try logging your insulin right before your next bite for a bonus."         |
| **Survival Mode**     | User marks "Sick Day"                             | "Survival Mode activated. Your only quest today is hydration and rest. Penalties suspended."     |
| **Dawn Phenomenon**   | High BG detected between 4 AM - 8 AM consistently | "The dawn effect strikes again. Log your bedtime snack and morning correction for insight."      |
| **Hydration Hero**    | Water log < 4 glasses by 4 PM                     | "Your cells are thirsty! Insulin works 20% better when you're hydrated. Grab a glass."           |
| **Essential Stumble** | Missed logging > 3 scans before 12 PM             | "Mornings are hard. Just one scan now will get you back on the guild leaderboard."               |
| **Milestone Near**    | TIR at 65% (close to 70% target)                  | "So close to the 70% target! One more pre-bolus today will push you over."                       |
| **Welcome Back**      | First log after 2+ days of absence                | "Welcome back, warrior. Your data is safe, and your guild missed you. Start with a simple scan." |

---

## 6. Remapping the 50-Badge Registry & Calling System

### Calling Domains (Reskin of Warrior, Sage, Monk, Bard, Ranger, Artificer)

| New Domain         | Crest Sigil | Unlock Requirement                              |
| :----------------- | :---------- | :---------------------------------------------- |
| **The Stabilizer** | Shield      | Achieve 70% TIR for 5 consecutive days.         |
| **The Counter**    | Scales      | Log carbs for 50 meals with accurate estimates. |
| **The Hydrator**   | Droplet     | Hit daily water goal for 7 straight days.       |
| **The Rotator**    | Gear        | Log 10 unique site-rotation swaps.              |
| **The Analyst**    | Eye         | Perform 100 CGM scans (total).                  |
| **The Alchemist**  | Flask       | Log extended boluses for 5 high-fat meals.      |

### New Badge Registry (Partial list - 15 of 50)

| Badge Name             | Category   | Criteria                                                      |
| :--------------------- | :--------- | :------------------------------------------------------------ |
| **Chef's Kiss**        | Perfection | Pre-bolus correctly 10 times.                                 |
| **First Responder**    | Streaks    | Recover from a high within 45 mins, 5 times.                  |
| **The Pizza Gauntlet** | Calling    | Complete the weekly extended-bolus quest.                     |
| **Smooth Operator**    | Journey    | Maintain SD < 30 for an entire 24-hour day.                   |
| **Zentient**           | Rarities   | Log a "Mood" anchor alongside a BG scan 20 times.             |
| **Rotator Cuff**       | Economy    | Rotate sites 7 times without repeating.                       |
| **The Time-Traveler**  | Journey    | Improve weekly TIR by 1% over previous week.                  |
| **Survivor**           | Sealed     | Successfully navigate a Sick Day Shield without a severe low. |

---

## 7. UI/UX Adaptations (Onyx & Ivory)

- **Today Screen:** Replaces the generic quest list with a **"Glucose Dashboard"**.
  - Top: CGM Pet with animated mood.
  - Middle: 3 Primary Quests (Pre-bolus, Hydration, Site Rotation).
  - Bottom: Current "Sea Level" SD indicator and Live TIR ring.
- **Insights Screen:** Retains the Heatmap but adds a **CGM Line Chart** (`fl_chart`). Settlement feeds the `numericValue` list directly into this chart.
- **Ceremonies:** The existing "Ember" gold animation and haptic feedback trigger precisely when a user achieves a new TIR personal best or completes the "Pizza Gauntlet".
- **Failure States:** Missed Essential Quests are displayed in **Muted Red**, but the app never uses red alerts or buzzer sounds for high glucose (uses neutral blue/purple tones instead).

### The Onboarding Oath (3-Step Wizard)

Rewrite the Step 3 oath:

> _"I vow to log my data before I judge my numbers. I will treat every scan as intel, not a grade. I am the hero of my own glucose journey."_

---

## 8. Development Roadmap (Phased Approach)

- **Phase 1: Data & Engine (Week 1)**
  - Run Drift migration (`numericValue`, `contextJson`, `loggedAt`).
  - Update Settlement logic to calculate TIR, SD, and "Minutes to Mitigation".
  - Rewrite P12b Coach advice strings.

- **Phase 2: UI & Graphics (Week 2)**
  - Replace Heatmap with CGM Line Chart on Insights.
  - Implement the CGM Pet widget (simple animated Lottie or Flutter `AnimationController`).
  - Reskin Calling Crests (SVG/Canvas).

- **Phase 3: Quest Packs & Polish (Week 3)**
  - Generate the default "Starter Pack" JSON (daily/weekly quests).
  - Implement "Grace Token" logic (allows 1 free skip per month to preserve streaks).
  - Test time-travel settlement with historical `.csv` imports.

- **Phase 4: Internal Dogfooding (Week 4)**
  - Use the app personally for 7 days.
  - Tweak cooldown backoffs based on real-world notification fatigue.

---

## 9. Medical & Ethical Considerations (CRITICAL)

1.  **FDA/Clearance Disclaimer:** This app is classified as a **wellness/lifestyle app**, not a Class II medical device. It does not automate insulin delivery or provide diagnostic treatment decisions.
2.  **No Liability:** The splash screen must include: _"Always consult your Endo before changing insulin doses. This app is for motivation and logging only."_
3.  **Data Sovereignty:** `android:allowBackup="true"` is preserved. Users own their 100% offline data. Backup JSONs are encrypted via your existing export utility.

---

## 10. How to Start Coding Today

1.  **Copy** the existing `QUESTLOG` project folder to a new directory (e.g., `glucose_guild/`).
2.  **Update** `pubspec.yaml` (App name, version, description).
3.  **Implement** the Drift migration from **Section 3**.
4.  **Replace** the strings in your `lib/domain/constants/coach_pool.dart` with the table from **Section 5**.
5.  **Run** `flutter clean && flutter pub get && dart run build_runner build`.

The engine is already built. You are now just steering it toward saving lives and mental health.

---
