import '../constants/tunables.dart';
import '../model/models.dart';
import 'schedule_rule.dart';

enum CoachRuleType {
  welcomeBack,
  survivalMode,
  firstResponder,
  prebolusPro,
  essentialStumble,
  stabilizer,
  dawnEffect,
  milestoneNear,
  hydrationHero,
  rotatorNudge,
}

enum CoachActionType {
  dismiss,
  pause,
  archive,
  export,
  reviewLoad,
  raiseTarget,
  raiseDifficulty,
  lowerTarget,
  suggestCadence,
  understood,
  continueFlow,
}

class CoachAction {
  final String label;
  final CoachActionType type;
  final dynamic payload;

  const CoachAction({
    required this.label,
    required this.type,
    this.payload,
  });

  @override
  String toString() => 'CoachAction($label, $type)';
}

class CoachSignal implements Comparable<CoachSignal> {
  final CoachRuleType ruleType;
  final String? questId;
  final String title;
  final String message;
  final List<CoachAction> actions;
  final String dedupKey;
  final int cooldownDays;
  final double? rate;
  final int? streak;
  final DateTime? createdAt;
  final List<String>? relatedQuestIds;

  const CoachSignal({
    required this.ruleType,
    this.questId,
    required this.title,
    required this.message,
    required this.actions,
    required this.dedupKey,
    required this.cooldownDays,
    this.rate,
    this.streak,
    this.createdAt,
    this.relatedQuestIds,
  });

  int get rulePriority {
    switch (ruleType) {
      case CoachRuleType.survivalMode:
        return 0;
      case CoachRuleType.firstResponder:
        return 1;
      case CoachRuleType.prebolusPro:
        return 2;
      case CoachRuleType.essentialStumble:
        return 3;
      case CoachRuleType.stabilizer:
        return 4;
      case CoachRuleType.dawnEffect:
        return 5;
      case CoachRuleType.milestoneNear:
        return 6;
      case CoachRuleType.hydrationHero:
        return 7;
      case CoachRuleType.rotatorNudge:
        return 8;
      case CoachRuleType.welcomeBack:
        return 9;
    }
  }

  @override
  int compareTo(CoachSignal other) {
    final p = rulePriority.compareTo(other.rulePriority);
    if (p != 0) return p;

    // Within-class tiebreaks
    if (rate != null && other.rate != null) {
      final r = rate!.compareTo(other.rate!);
      if (r != 0) return r;
    }

    final c = (createdAt ?? DateTime(0)).compareTo(other.createdAt ?? DateTime(0));
    if (c != 0) return c;

    return (questId ?? '').compareTo(other.questId ?? '');
  }
}

class QuestHistoryData {
  final String id;
  final String title;
  final ScheduleRule rule;
  final TargetType targetType;
  final int targetValue;
  final Difficulty difficulty;
  final bool essential;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final LocalDate? pausedUntil;
  final Map<LocalDate, int> completions;
  final int currentStreak;
  final bool isSatisfiedToday;

  const QuestHistoryData({
    required this.id,
    required this.title,
    required this.rule,
    required this.targetType,
    required this.targetValue,
    required this.difficulty,
    required this.essential,
    required this.createdAt,
    this.archivedAt,
    this.pausedUntil,
    required this.completions,
    required this.currentStreak,
    required this.isSatisfiedToday,
  });
}

/// A glucose log with its wall-clock timestamp, used by the coach detectors.
class ScanLogEntry {
  final double value;
  final DateTime at;

  const ScanLogEntry({required this.value, required this.at});
}

/// Structured inputs the coach needs for all ten GLUCOSE_GUILD detectors.
class CoachGlucoseInput {
  final LocalDate today;
  final bool isSick;
  final LocalDate? lastActiveDate;
  final List<ScanLogEntry> scansToday;
  final int waterGlassesToday;
  final int mealsToday;

  /// True when a meal today has no insulin within the pre-bolus grace window.
  final bool prebolusMissToday;
  final int recoveriesYesterday;
  final double? minWindowSdYesterday;
  final int dawnHighStreak;
  final int sameSiteForDays;
  final double? tirPct;

  const CoachGlucoseInput({
    required this.today,
    this.isSick = false,
    this.lastActiveDate,
    this.scansToday = const [],
    this.waterGlassesToday = 0,
    this.mealsToday = 0,
    this.prebolusMissToday = false,
    this.recoveriesYesterday = 0,
    this.minWindowSdYesterday,
    this.dawnHighStreak = 0,
    this.sameSiteForDays = 0,
    this.tirPct,
  });
}

class CoachEngine {
  /// Pure function that computes 14d scheduled and satisfied periods for a quest
  static ({int scheduled, int satisfied, double rate}) calculate14dRate({
    required QuestHistoryData quest,
    required LocalDate today,
    required WeekStart weekStart,
  }) {
    final createdLocalDate = LocalDate.fromDateTime(quest.createdAt);
    int scheduled = 0;
    int satisfied = 0;

    for (int i = 13; i >= 0; i--) {
      final d = today.subtractDays(i);

      // Exclude days before birth grace
      if (d < createdLocalDate) continue;

      // Exclude paused days
      if (quest.pausedUntil != null && d <= quest.pausedUntil!) continue;

      // Check if scheduled
      if (quest.rule.isScheduledOn(d, weekStart.value)) {
        scheduled++;
        final dayVal = quest.completions[d] ?? 0;
        if (dayVal >= quest.targetValue) {
          satisfied++;
        }
      }
    }

    final rate = scheduled > 0 ? (satisfied / scheduled) : 0.0;
    return (scheduled: scheduled, satisfied: satisfied, rate: rate);
  }

  /// Pure function evaluating all ten GLUCOSE_GUILD detectors, returning
  /// candidate signals sorted deterministically by priority.
  static List<CoachSignal> evaluateAll({
    required CoachGlucoseInput input,
    String? userName,
    DateTime? now,
  }) {
    final signals = <CoachSignal>[];
    final trimmedName = userName?.trim();
    final namePrefix = (trimmedName != null && trimmedName.isNotEmpty) ? '$trimmedName, ' : '';
    final nameTitle = (trimmedName != null && trimmedName.isNotEmpty) ? 'COACH · ${trimmedName.toUpperCase()}' : 'COACH';
    final today = input.today;
    final referenceNow = now ?? DateTime.now();

    // 1. welcome_back: first log after >= 48h absence
    final lastActive = input.lastActiveDate;
    if (lastActive != null) {
      final absentDays = today.differenceInDays(lastActive);
      if (absentDays >= CoachTunables.coachAbsenceDays) {
        signals.add(CoachSignal(
          ruleType: CoachRuleType.welcomeBack,
          title: nameTitle,
          message: '$namePrefix$absentDays days without a log — the Guild keeps watch. Scan now.',
          actions: const [
            CoachAction(label: 'First scan', type: CoachActionType.continueFlow),
          ],
          dedupKey: 'welcome_back',
          cooldownDays: CoachTunables.coachWelcomeCooldown,
        ));
      }
    }

    // 2. survival_mode: sick day shield active
    if (input.isSick) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.survivalMode,
        title: nameTitle,
        message: '${namePrefix}sick-day mode is on — outcomes are paused while you recover. Rest and stay hydrated.',
        actions: const [
          CoachAction(label: 'Understood', type: CoachActionType.understood),
        ],
        dedupKey: 'survival_mode',
        cooldownDays: CoachTunables.coachSurvivalCooldown,
      ));
    }

    // 3. first_responder: a high caught with insulin within 45 minutes yesterday
    if (input.recoveriesYesterday > 0) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.firstResponder,
        title: nameTitle,
        message: '${namePrefix}yesterday you caught a high within ${GlucoseTunables.recoveryWindowMinutes} minutes — +${GlucoseTunables.recoveryBonusXp} XP.',
        actions: const [
          CoachAction(label: 'Understood', type: CoachActionType.understood),
        ],
        dedupKey: 'first_responder',
        cooldownDays: CoachTunables.coachFirstResponderCooldown,
      ));
    }

    // 4. prebolus_pro: meal logged today but insulin late or missing
    if (input.mealsToday > 0 && input.prebolusMissToday) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.prebolusPro,
        title: nameTitle,
        message: '${namePrefix}a meal was logged without insulin within ${CoachTunables.coachPrebolusGraceMinutes} minutes — dose now to flatten the rise.',
        actions: const [
          CoachAction(label: 'Dose now', type: CoachActionType.dismiss),
        ],
        dedupKey: 'prebolus_pro:$today',
        cooldownDays: CoachTunables.coachPrebolusCooldown,
      ));
    }

    // 5. essential_stumble: zero scans before noon
    if (input.scansToday.isNotEmpty || referenceNow.hour >= 12) {
      final scannedBeforeNoon = input.scansToday.any((s) => s.at.hour < 12);
      final hour = referenceNow.hour;
      if (hour >= 12 && !scannedBeforeNoon) {
        signals.add(CoachSignal(
          ruleType: CoachRuleType.essentialStumble,
          title: nameTitle,
          message: '${namePrefix}no scan before noon — a count breaks the missing-morning pattern.',
          actions: const [
            CoachAction(label: 'Scan now', type: CoachActionType.dismiss),
          ],
          dedupKey: 'essential_stumble:$today',
          cooldownDays: CoachTunables.coachEssentialStumbleCooldown,
        ));
      }
    }

    // 6. stabilizer: 4h-window SD under the silver tier yesterday
    final sdYesterday = input.minWindowSdYesterday;
    if (sdYesterday != null && sdYesterday < GlucoseTunables.sdSilver) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.stabilizer,
        title: nameTitle,
        message: '${namePrefix}steadiness detected — 4h-window SD ${sdYesterday.toStringAsFixed(1)} mg/dL (+${GlucoseTunables.calmSeasBonusXp} XP).',
        actions: const [
          CoachAction(label: 'Understood', type: CoachActionType.understood),
        ],
        dedupKey: 'stabilizer',
        cooldownDays: CoachTunables.coachStabilizerCooldown,
      ));
    }

    // 7. dawn_effect: high readings in the dawn window three days running
    if (input.dawnHighStreak >= CoachTunables.coachDawnHighStreakDays) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.dawnEffect,
        title: nameTitle,
        message: '${namePrefix}high readings at dawn ${input.dawnHighStreak} days in a row — consider a bedtime plan.',
        actions: const [
          CoachAction(label: 'Understood', type: CoachActionType.understood),
        ],
        dedupKey: 'dawn_effect',
        cooldownDays: CoachTunables.coachDawnCooldown,
      ));
    }

    // 8. milestone_near: TIR teetering one point under target
    final tir = input.tirPct;
    if (tir != null &&
        tir >= GlucoseTunables.tirTargetPercentage - 0.05 &&
        tir < GlucoseTunables.tirTargetPercentage) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.milestoneNear,
        title: nameTitle,
        message: '${namePrefix}you are one point from ${(GlucoseTunables.tirTargetPercentage * 100).round()}% time-in-range.',
        actions: const [
          CoachAction(label: 'Understood', type: CoachActionType.understood),
        ],
        dedupKey: 'tir_milestone_near',
        cooldownDays: CoachTunables.coachMilestoneCooldown,
      ));
    }

    // 9. hydration_hero: fewer than 4 glasses in the water by 4PM
    final hour = referenceNow.hour;
    if (hour >= 16 && input.waterGlassesToday < CoachTunables.coachHydrationTargetGlasses) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.hydrationHero,
        title: nameTitle,
        message: '$namePrefix${input.waterGlassesToday}/${CoachTunables.coachHydrationTargetGlasses} glasses of water by 4 PM — water steadies glucose.',
        actions: const [
          CoachAction(label: 'Drink up', type: CoachActionType.dismiss),
        ],
        dedupKey: 'hydration_hero:$today',
        cooldownDays: CoachTunables.coachHydrationCooldown,
      ));
    }

    // 10. rotator_nudge: same injection site for the rotation window
    if (input.sameSiteForDays >= GlucoseTunables.siteRotationDays) {
      signals.add(CoachSignal(
        ruleType: CoachRuleType.rotatorNudge,
        title: nameTitle,
        message: '${namePrefix}you have used the same site ${input.sameSiteForDays} days — rotate to protect tissue.',
        actions: const [
          CoachAction(label: 'Rotate', type: CoachActionType.dismiss),
        ],
        dedupKey: 'rotator_nudge',
        cooldownDays: CoachTunables.coachRotatorCooldown,
      ));
    }

    signals.sort();
    return signals;
  }
}
