class CoachTunables {
  static const int coachBaseCooldown = 7;
  static const int coachMaxCooldown = 90;
  static const int coachWelcomeCooldown = 60;
  static const int coachStabilizerCooldown = 3;
  static const int coachFirstResponderCooldown = 2;
  static const int coachRotatorCooldown = 30;
  static const int coachPrebolusCooldown = 1;
  static const int coachSurvivalCooldown = 90;
  static const int coachDawnCooldown = 14;
  static const int coachHydrationCooldown = 1;
  static const int coachEssentialStumbleCooldown = 3;
  static const int coachMilestoneCooldown = 7;

  /// A meal needs insulin within this many minutes for Pre-Bolus Pro to stay quiet.
  static const int coachPrebolusGraceMinutes = 15;
  static const int coachHydrationTargetGlasses = 4;
  static const int coachDawnHighStreakDays = 3;
  static const int coachDawnWindowStartHour = 4;
  static const int coachDawnWindowEndHour = 8;

  /// Absence (in days) before the Welcome Back detector speaks.
  static const int coachAbsenceDays = 2;
}

class GlucoseTunables {
  // ── GLUCOSE RANGES (mg/dL) ─────────────────────────────────────────────────
  static const double hypoUrgent = 54;
  static const double hypoAlert = 70;
  static const double targetLow = 70;
  static const double targetHigh = 180;
  static const double hyperAlert = 250;

  // ── SETTLEMENT LOGIC ───────────────────────────────────────────────────────
  static const double tirTargetPercentage = 0.70;
  static const double tirCapPercentage = 0.80;
  static const int dailyOutcomeXpCap = 100;
  static const int outcomeXpTargetReward = 100;
  static const int habitCoinPerScan = 5;
  static const int habitCoinPerWater = 1;
  static const int habitCoinPerSiteRotation = 10;
  static const int habitCoinPerMoodAnchor = 2;
  static const int habitCoinPerInsulinLog = 10;
  static const int habitCoinPerCarbLog = 3;
  static const int habitCoinPerKetoneCheck = 15;
  static const int recoveryBonusXp = 25;

  // ── VOLATILITY (Standard Deviation) ─────────────────────────────────────────
  static const double sdBronze = 40;
  static const double sdSilver = 30;
  static const double sdGold = 20;
  static const int calmSeasBonusXp = 15;

  // ── SPEED OF ACTION ─────────────────────────────────────────────────────────
  static const int recoveryWindowMinutes = 45;
  static const int preBolusGraceMinutes = 5;

  // ── ROTATION & PET ──────────────────────────────────────────────────────────
  static const int siteRotationDays = 7;
  static const int petDanceScanTarget = 8;
  static const int essentialStumbleScanTarget = 3;
}
