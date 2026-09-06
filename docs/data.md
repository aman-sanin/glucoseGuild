# `GLUCOSE_GUILD_DATA.md` (Data Configuration Manifest)

## 1. DEFAULT QUEST PACK (Starter JSON)

_Paste this into your `assets/data/default_quest_pack.json` for the 3-step onboarding wizard._

```json
{
  "packName": "Glucose Guild: Starter Kit",
  "quests": [
    {
      "id": "q_daily_scan_fasting",
      "title": "⚔️ The Dawn Scan",
      "description": "Log your fasting glucose within 30 mins of waking.",
      "cadence": "daily",
      "target": 1,
      "scoringType": "checkbox",
      "xpReward": 10,
      "category": "Journey"
    },
    {
      "id": "q_daily_prebolus_breakfast",
      "title": "🍳 The Chef's Kiss",
      "description": "Log your insulin dose BEFORE eating breakfast.",
      "cadence": "daily",
      "target": 1,
      "scoringType": "checkbox",
      "xpReward": 15,
      "category": "Perfection"
    },
    {
      "id": "q_daily_carbs_log",
      "title": "📊 Carb Counter",
      "description": "Log estimated carbs for all meals today.",
      "cadence": "daily",
      "target": 3,
      "scoringType": "counter",
      "xpReward": 5,
      "category": "Economy"
    },
    {
      "id": "q_daily_water",
      "title": "💧 River Flow",
      "description": "Drink 8 glasses of water.",
      "cadence": "daily",
      "target": 8,
      "scoringType": "counter",
      "xpReward": 2,
      "category": "Economy"
    },
    {
      "id": "q_daily_site_check",
      "title": "🌀 Rotator Cuff",
      "description": "Log your current injection/pump site location.",
      "cadence": "daily",
      "target": 1,
      "scoringType": "checkbox",
      "xpReward": 5,
      "category": "Goals"
    },
    {
      "id": "q_weekly_tir_70",
      "title": "🛡️ The Stabilizer",
      "description": "Achieve 70% Time-in-Range for 5 out of 7 days.",
      "cadence": "weekly",
      "target": 5,
      "scoringType": "counter",
      "xpReward": 50,
      "category": "Calling"
    },
    {
      "id": "q_weekly_pizza_gauntlet",
      "title": "🍕 The Pizza Gauntlet",
      "description": "Log a fatty meal, take an extended bolus, AND check BG 3hrs later.",
      "cadence": "weekly",
      "target": 3,
      "scoringType": "counter",
      "xpReward": 30,
      "category": "Rarities"
    },
    {
      "id": "q_single_endocrinologist",
      "title": "🏥 The Endo Briefing",
      "description": "Export your 30-day report and share it with your doctor.",
      "cadence": "single",
      "targetDate": null,
      "scoringType": "checkbox",
      "xpReward": 100,
      "category": "Sealed"
    }
  ]
}
```

---

## 2. DATABASE SCHEMA EXTENSION (Drift Migration)

_Replace your `lib/data/db/tables.dart` with this extended `Completions` table._

```dart
// lib/data/db/tables.dart

@DataClassName('Completion')
class Completions extends Table {
  // --- BASE (Existing) ---
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questId => integer().nullable()();
  DateTimeColumn get completedDate => dateTime()(); // Date of settlement

  // --- SCORING (Existing) ---
  IntColumn get counterValue => integer().nullable();
  // For checkbox: 1 = done. For counter: total count.

  // --- NEW: DIABETES CONTEXT ---
  TextColumn get numericValue => text().nullable();
  // Stores raw number: "182" (mg/dL), "4.5" (units), "60" (carbs)

  TextColumn get contextJson => text().nullable();
  // Stores structured data for granular analytics:
  // {"type":"cgm","device":"libre","correction":false}
  // {"type":"meal","meal":"pizza","fat":"high"}
  // {"type":"insulin","site":"left_arm","delivery":"pen"}

  DateTimeColumn get loggedAt => dateTime().nullable();
  // Critical: The actual timestamp of the fingerstick/injection.
  // Allows "Minutes to Mitigation" calculation even if user logs hours later.

  // --- FOREIGN KEYS (Optional but recommended) ---
  @override
  List<Set<Column>> get uniqueConstraints => [
    {questId, completedDate} // Prevents duplicate logging for daily quests.
  ];
}
```

**Context JSON Schemas (Enums to enforce):**

```dart
// lib/domain/model/diabetes_context.dart
enum ScanType { cgm, fingerstick }
enum MealType { low_carb, medium_carb, high_carb, high_fat }
enum InsulinSite { left_arm, right_arm, left_abdomen, right_abdomen, left_leg, right_leg, buttock }
```

---

## 3. CORE TUNABLES (Constants)

_Paste this into `lib/domain/constants/tunables.dart`. This drives your Settlement Engine._

```dart
library tunables;

class GlucoseTunables {
  // --- GLUCOSE RANGES (mg/dL) ---
  static const int hypoUrgent = 54;
  static const int hypoAlert = 70;
  static const int targetLow = 70;
  static const int targetHigh = 180;
  static const int hyperAlert = 250;

  // --- SETTLEMENT LOGIC ---
  static const double tirTargetPercentage = 0.70;  // 70% TIR to max XP
  static const double tirCapPercentage = 0.80;    // 80% TIR = XP Cap (no extra beyond)
  static const int dailyXpCap = 100;              // Max Outcome XP per day
  static const int habitCoinPerScan = 5;
  static const int habitCoinPerInsulinLog = 10;
  static const int habitCoinPerCarbLog = 3;

  // --- VOLATILITY (Standard Deviation) ---
  static const int sdBronze = 40;   // High Volatility
  static const int sdSilver = 30;   // Medium
  static const int sdGold = 20;     // Low (The "Calm Seas" threshold)

  // --- SPEED OF ACTION ---
  static const int recoveryWindowMinutes = 45; // Must correct high within this time.
  static const int preBolusGraceMinutes = 5;   // Insulin must be logged within 5 mins of meal start.

  // --- ROTATION ---
  static const int siteRotationDays = 7;       // Warn if same site used > 7 days.
}
```

---

## 4. P12b COACH DETECTOR LOGIC (Exact Thresholds)

_Update your `lib/domain/engine/coach.dart` lookup map with these conditions._

| Detector Key        | Condition (Pseudocode)                            | Cooldown (Days) | Output Advice String                                                           |
| :------------------ | :------------------------------------------------ | :-------------- | :----------------------------------------------------------------------------- |
| `stabilizer`        | `SD < 30` for 4 hours                             | 3               | _"Calm seas, captain! Your flat line means your basal is dialed in."_          |
| `first_responder`   | High (>180) + Correction < 45min                  | 2               | _"Heroic recovery! You caught that spike and acted fast. That's control."_     |
| `rotator_nudge`     | Same `InsulinSite` used for 7+ days               | 30              | _"Your scar tissue is begging for a break. Rotate to a new spot today."_       |
| `prebolus_pro`      | Meal logged, Insulin logged >15min _after_ meal   | 1               | _"Prep work wins wars. Try logging your insulin right before your next bite."_ |
| `survival_mode`     | User marks `isSick == true`                       | 90              | _"Survival Mode activated. Penalties suspended. Hydrate and rest today."_      |
| `dawn_effect`       | High (>150) logged between 4-8 AM, 3 days running | 14              | _"The dawn effect strikes again. Log a bedtime snack and morning correction."_ |
| `hydration_hero`    | Water intake < 4 glasses by 4 PM                  | 1               | _"Insulin works 20% better when hydrated. Grab a glass of water now."_         |
| `essential_stumble` | 0 scans logged before 12 PM (noon)                | 3               | _"Mornings are hard. Just one scan now gets you back on the leaderboard."_     |
| `milestone_near`    | Current TIR = 65% - 69% (within 5% of target)     | 7               | _"So close to the 70% target! One more pre-bolus today pushes you over."_      |
| `welcome_back`      | First log after 48+ hours of silence              | 60              | _"Welcome back, warrior. Your guild missed you. Start with a simple scan."_    |

---

## 5. THE 50-BADGE REGISTRY (Core 20 Unlocks)

_Store this in `lib/domain/constants/badge_registry.dart`._

| Badge ID              | Name                      | Category   | Unlock Condition (Settlement Derived)                                  |
| :-------------------- | :------------------------ | :--------- | :--------------------------------------------------------------------- |
| `b_first_responder_1` | First Responder           | Streaks    | Recover from a high (<45min) 5 times total.                            |
| `b_chef_kiss_1`       | Chef's Kiss               | Perfection | Log insulin _before_ a meal 10 times.                                  |
| `b_chef_kiss_2`       | Master Chef               | Perfection | Pre-bolus 50 times.                                                    |
| `b_pizza_gauntlet_1`  | Pizza Survivor            | Calling    | Complete the "Pizza Gauntlet" weekly quest 3 times.                    |
| `b_smooth_operator`   | Smooth Operator           | Journey    | Maintain SD < 30 for a full 24-hour day.                               |
| `b_zentient`          | Zentient                  | Rarities   | Log a Mood Anchor (context) alongside a CGM scan 20 times.             |
| `b_rotator_1`         | Rotator Cuff              | Economy    | Log 7 unique site rotations without repeating a site.                  |
| `b_timetraveler_1`    | Time-Traveler             | Journey    | Improve weekly TIR by 1% over the previous week.                       |
| `b_survivor`          | Survivor                  | Sealed     | Successfully navigate a "Sick Day" without going hypo (<70) for 24hrs. |
| `b_hydration_1`       | Aqua Adept                | Goals      | Hit water goal 30 days in a row.                                       |
| `b_hydration_2`       | The River                 | Goals      | Hit water goal 100 days total.                                         |
| `b_streak_7`          | Week Warrior              | Streaks    | Log a CGM scan every day for 7 days.                                   |
| `b_streak_30`         | Monthly Sentinel          | Streaks    | Log a CGM scan every day for 30 days.                                  |
| `b_tir_70`            | The Stabilizer (Initiate) | Calling    | Achieve 70% TIR for 1 week.                                            |
| `b_tir_80`            | The Stabilizer (Veteran)  | Calling    | Achieve 80% TIR for 1 week (if physically possible).                   |
| `b_data_hoarder`      | Data Hoarder              | Economy    | Log 500 CGM scans total.                                               |
| `b_insulin_100`       | The Chemist               | Economy    | Log 100 insulin doses total.                                           |
| `b_perfect_day`       | Perfect Day               | Perfection | Achieve 100% TIR (without lows) for one single day.                    |
| `b_grace_token`       | The Forgiven              | Sealed     | Use a "Grace Token" to save a streak (Hidden unlock).                  |
| `b_endo_visit`        | The Prepared              | Journey    | Complete the "Endo Briefing" single quest.                             |

---

## 6. CALLING SYSTEM XP CURVES (Level 1-10)

_Currently, your Level 1-10 requires increasing XP. Diabetes thresholds should feel heroic._

```dart
// lib/domain/constants/xp_curves.dart
const Map<String, int> callingXpThresholds = {
  'Level 1 (Initiate)': 0,
  'Level 2 (Acolyte)': 200,
  'Level 3 (Defender)': 500,
  'Level 4 (Knight)': 1000,
  'Level 5 (Commander)': 1800,
  'Level 6 (Champion)': 2800,
  'Level 7 (Warden)': 4000,
  'Level 8 (Sentinel)': 5500,
  'Level 9 (Paragon)': 7500,
  'Level 10 (Guildmaster)': 10000,
};

// Domain Reskin Mapping for UI Crests
const Map<String, String> domainCrests = {
  'The Stabilizer': '🛡️', // Shield
  'The Counter': '⚖️',    // Scales
  'The Hydrator': '💧',   // Droplet
  'The Rotator': '⚙️',    // Gear
  'The Analyst': '👁️',    // Eye
  'The Alchemist': '🧪',  // Flask
};
```

---

## 7. SETTLEMENT IDEMPOTENT LOGIC (The "Settle" Math)

_This is the core function you run daily in your engine. Place this logic in `lib/domain/engine/settlement.dart`._

**Pseudo-code for the daily `settle()` run:**

```dart
SettlementResult settleDay(DateTime date, List<Completion> logs) {
  // 1. FILTER: Get CGM logs only.
  var scans = logs.where((l) => l.contextJson['type'] == 'cgm');

  // 2. CALCULATE TIR:
  int inRange = scans.where((s) => s.numericValue >= 70 && s.numericValue <= 180).length;
  double tir = scans.isEmpty ? 0 : inRange / scans.length;

  // 3. OUTCOME XP (Hard Capped):
  int outcomeXP = 0;
  if (tir >= 0.70) outcomeXP = 100; // MAX
  else outcomeXP = (tir / 0.70 * 100).toInt();
  outcomeXP = min(outcomeXP, 100); // Cap at 100.

  // 4. EFFORT COINS (Uncapped):
  int effortCoins = 0;
  effortCoins += scans.length * 5;
  effortCoins += logs.where((l) => l.contextJson['type'] == 'insulin').length * 10;
  effortCoins += logs.where((l) => l.contextJson['type'] == 'meal').length * 3;

  // 5. RECOVERY DETECTOR (Checks timestamps):
  var high = scans.lastWhere((s) => s.numericValue > 180, orElse: null);
  int recoveryBonus = 0;
  if (high != null) {
    var correction = logs.where((l) => l.loggedAt.isAfter(high.loggedAt) && l.contextJson['type'] == 'insulin');
    if (correction.isNotEmpty && correction.first.loggedAt.difference(high.loggedAt).inMinutes < 45) {
      recoveryBonus = 25; // Award bonus XP for fast recovery.
    }
  }

  // 6. UPDATE LEDGER:
  // Append a new ledger entry: "OutcomeXP", "EffortCoins", "RecoveryBonus".
  // Store TIR and SD in the Profile table for the dashboard.

  return SettlementResult(tir: tir, outcomeXP: outcomeXP, effortCoins: effortCoins, recoveryBonus: recoveryBonus);
}
```

---

## 8. GRACE TOKEN (Streak Forgiveness)

_Add this bool to your `Profile` table. This ensures your "Streak" badges are never lost due to an unavoidable bad day._

```dart
// lib/data/db/tables.dart (Profile table extension)
class Profiles extends Table {
  // ... existing fields ...
  BoolColumn get hasGraceToken => boolean().withDefault(const Constant(true));
  DateTimeColumn get lastGraceTokenUsed => dateTime().nullable();
}

// Logic: If a user misses their "Daily Scan" quest, and `hasGraceToken == true`:
// Automatically complete that quest for them, set `hasGraceToken = false`,
// and set `lastGraceTokenUsed = today`. Refills 30 days later.
```

---

### How to implement this immediately:

1. Create the JSON file above in `assets/`.
2. Paste the Database extension code and run `build_runner`.
3. Copy the Constants into their respective Dart files.
4. Drop the Settlement math into your existing engine loop.
