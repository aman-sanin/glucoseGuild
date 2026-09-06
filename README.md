# GLUCOSE GUILD

> **Gamified glucose logging. Effort coins, not outcomes. No accounts.**

Glucose Guild is a local-first diabetes habit tracker that turns your care routine into a quest — you log the *behaviors* (scans, doses, water, site rotation) and the app rewards the effort, never the blood-sugar number itself.

All data stays on-device. The app requires **no internet permission** and uses no accounts.

---

## ✦ Core Philosophy — Sacred Progress
Information is treated as a rare commodity. The user authors only completions. Everything else — today's list, streaks, levels, badges, insights, and XP — is dynamically derived from those completions and schedule rules at read time.

**Effort coins, not outcomes:** XP is earned by logging care actions (CGM scans, insulin doses, meals, water, site rotation), not by hitting a blood-glucose target. Settlement is an idempotent foreground convergence run that materializes BONUS points and milestone grants into an append-only ledger.

---

## ⚔️ Key Features

- **Today Glucose Dashboard**: Animated CGM pet companion, latest-reading card, TIR-day ring (70–180 mg/dL band), and a "Sea Level" volatility readout (4-hour-window SD). A **SURVIVAL MODE** badge appears while the sick-day flag is set.
- **Insights CGM Line Chart**: 30-day scan line with dashed 70–180 target-band guides, alongside month/year heatmaps and XP insights.
- **Diabetes Coach Engine**: 10 deterministic detectors with exponential cooldown backoff —
  *Welcome Back, Survival Mode, First Responder, Pre-Bolus Pro, Essential Stumble, Stabilizer, Dawn Effect, Milestone Near, Hydration Hero, Rotator Nudge* — giving gain-framed, personalized advice.
- **50-Badge Achievement Registry**: Complete registry across 8 categories (*Journey, Streaks, Perfection, Goals, Economy, Rarities, Calling, Sealed*), with secrecy dialogs and calling trials.
- **Calling System & The Path**: Choose from 6 glucose-aligned callings — *Stabilizer, Counter, Hydrator, Rotator, Analyst, Alchemist* — each with its own crest sigil, trial quests, and leveling ladder.
- **Starter Quest Pack**: Ships with `default_quest_pack.json` (2 goals, 8 quests mirroring the docs' onboarding trio — dawn scan, site rotation, pre-bolus) and the **RESTORE STARTER PACK** action in Settings.
- **Flexible Cadences**: Daily, Weekly, Monthly, Yearly, and **Single (Non-Repeating)** quests with target dates and checkbox/counter modes, plus `contextJson` structure for scans/bolus/meals/hydration/site with numeric values.
- **First-Launch Onboarding**: 3-step wizard — adventurer name, primary-quest selection, and the **Onboarding Oath** ("log before I judge, treat every scan as intel, not a grade").
- **Splash + Medical Disclaimer**: Launch splash always shows *"Always consult your Endo before changing insulin doses. This app is for motivation and logging only."*
- **Quest Packs & Backup**: Export/import local JSON backups (transactional swap, preserves deep-typed completion notes) and shareable Quest Packs.
- **Tactile Audio & Haptics**: Persistent sound toggle and haptic feedback on completions and ceremonies.

---

## 🛠️ Tech Stack
* **Platform**: Android (offline-first, `allowBackup = true` — one file, back up the whole world).
* **Framework**: Flutter
* **State Management**: [Riverpod](https://riverpod.dev)
* **Local Persistence**: [Drift](https://drift.simonbinder.eu) (SQLite ORM)
* **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
* **Routing**: [go_router](https://pub.dev/packages/go_router)
* **Clock**: Injected for 100% deterministic time-travel and settlement testing.

---

## 🎨 Design System ("Onyx & Glacier")
Neo-brutalist constraints (hard edges, 1dp hairline borders, zero shadows/gradients) with a cool medical palette.
* **Onyx (Dark Mode)**: Pure `#000000` background.
* **Ivory (Light Mode)**: Soft `#FAF7F2` warm paper background.
* **Frost (Motion)**: Swappable accent (Frost, Sage, Ice, Copper, Ember) indicating metric progression.
* **Ember (Arrival)**: Hero gold for quest completion, milestones, and ceremonies.
* **Neutral Aqua (Glucose Readings)**: High glucose is shown with calm neutral/aqua tones — never red "glaze" alarms.

---

## 📂 Project Structure

```
lib/
  main.dart                                     (Initialization, minute ticker, app shell)
  data/
    db/          (Drift database, tables, converters — v2 schema: numericValue/contextJson/loggedAt/isSick)
    dao/         (Data Access Objects: Quests, Completions, Ledger, Profile, Goals, SeenMoments)
    backup/      (JSON backup export/import, transactional swap)
    packs/       (Quest pack service + default starter pack loader)
  domain/        (Pure Dart logic - no Flutter imports)
    engine/      (Recurrence, QuestState, Streak, XP, Settlement, GlucoseSettlement, Badges, Coach, Calling, Insights)
    model/       (Value types, LocalDate, Cadence, CallingDomain, DiabetesContext, GlucoseChartPoint)
    constants/   (Tunables incl. 70–180 target band, XP constants, Titles)
  app/
    providers/   (Riverpod providers incl. todayGlucoseCompletionsProvider)
    write/       (Transactional complete/undo, profile, quest, goal, sick-day actions)
    services/    (Rollover, notifications, widget bridge, haptics, sound)
  ui/
    theme/       (App theme, tokens, typography)
    screens/     (Splash, Today, Insights, Profile, Badges, Path, Settings, Onboarding, Pack Preview, Recap)
    sheets/      (Quest Editor, Goal Editor, Triage Sheet, Badge Sheet, Day Sheet)
    widgets/     (GlucoseDashboardHeader, CgmPetWidget, CgmLineChart, CoachCard, QuestRow, SigilWidget, HeatmapGrid)
```

---

## ⚡ Development & Commands

### 1. Running Tests
Run the complete automated suite (pure engine, settlement, coach detectors, badge registry, and widget flows):
```bash
flutter test
```

### 2. Static Analysis
```bash
flutter analyze
```

### 3. Code Generation
If you modify database tables in `lib/data/db/tables.dart`, regenerate files with:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 🔒 Privacy & Security
Glucose Guild is fully self-contained. The Android manifest declares **no internet access permissions**, rendering the app physically incapable of sending metrics, diagnostics, or tracking data anywhere. Your glucose history is yours alone.

## ⚕️ Medical Disclaimer
Glucose Guild is a motivation and logging tool — **not** a medical device. Always consult your endocrinologist before changing insulin doses or treatment routines.