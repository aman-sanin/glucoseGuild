import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/db/database.dart';
import '../constants/tunables.dart';
import '../model/diabetes_context.dart';
import '../model/models.dart';
import 'glucose_settlement.dart';

enum BadgeCategory {
  journey,
  streaks,
  perfection,
  goals,
  economy,
  rarities,
  calling,
  sealed,
}

enum ProgressKind {
  cumulative,
  peak,
  event,
}

class BadgeDefinition {
  final String key;
  final String title;
  final BadgeCategory category;
  final IconData icon;
  final String flavor;
  final String requirement;
  final ProgressKind progressKind;
  final int targetValue;
  final bool sealed;
  final CallingDomain? domain;

  const BadgeDefinition({
    required this.key,
    required this.title,
    required this.category,
    required this.icon,
    required this.flavor,
    required this.requirement,
    required this.progressKind,
    this.targetValue = 1,
    this.sealed = false,
    this.domain,
  });
}

class BadgeStatus {
  final BadgeDefinition definition;
  final bool isEarned;
  final int currentValue;
  final String? earnedDate;
  final bool isEligible;

  const BadgeStatus({
    required this.definition,
    required this.isEarned,
    this.currentValue = 0,
    this.earnedDate,
    this.isEligible = true,
  });

  double get progressRatio {
    if (definition.targetValue <= 0) return isEarned ? 1.0 : 0.0;
    return (currentValue / definition.targetValue).clamp(0.0, 1.0);
  }
}

/// Per-date rollup of every glucose log, used to derive settlement-grade badges.
class _DayAgg {
  int scans = 0;
  int scanRows = 0;
  int lows = 0;
  int insulins = 0;
  int insulinRows = 0;
  int meals = 0;
  int waters = 0;
  int moods = 0;
  int ketones = 0;
  int totalRows = 0;

  bool get scanDay => scans >= 1;
  bool get cleanDay => scanDay && lows == 0 && scanRows >= 2;
  bool get hydratedDay => waters >= CoachTunables.coachHydrationTargetGlasses;
}

class BadgeEngine {
  static const List<BadgeDefinition> catalog = [
    // ── 1. JOURNEY (6) ────────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_first_scan',
      title: 'First Reading',
      category: BadgeCategory.journey,
      icon: Symbols.radar,
      flavor: 'The line begins.',
      requirement: 'Log your first CGM or fingerstick scan.',
      progressKind: ProgressKind.cumulative,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_smooth_operator',
      title: 'Smooth Operator',
      category: BadgeCategory.journey,
      icon: Symbols.water,
      flavor: 'A flat sea, all day.',
      requirement: 'Hold SD under 30 for a full 24-hour day (4+ scans).',
      progressKind: ProgressKind.cumulative,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_timetraveler_1',
      title: 'Time-Traveler',
      category: BadgeCategory.journey,
      icon: Symbols.timelapse,
      flavor: 'Today beat yesterday by a point.',
      requirement: 'Improve weekly TIR by 1% over the previous week.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_endo_visit',
      title: 'The Prepared',
      category: BadgeCategory.journey,
      icon: Symbols.medical_services,
      flavor: 'You walked in with the data.',
      requirement: 'Complete the "Endo Briefing" quest.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_scan_100',
      title: 'Century of Scans',
      category: BadgeCategory.journey,
      icon: Symbols.timeline,
      flavor: 'A hundred readings in the ledger.',
      requirement: 'Log 100 CGM or fingerstick scans.',
      progressKind: ProgressKind.cumulative,
      targetValue: 100,
    ),
    BadgeDefinition(
      key: 'b_ketone_10',
      title: 'Ketone Scout',
      category: BadgeCategory.journey,
      icon: Symbols.science,
      flavor: 'Ten checks, ten answers.',
      requirement: 'Log 10 ketone checks.',
      progressKind: ProgressKind.cumulative,
      targetValue: 10,
    ),

    // ── 2. STREAKS (7) ────────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_first_responder_1',
      title: 'First Responder',
      category: BadgeCategory.streaks,
      icon: Symbols.emergency,
      flavor: 'Five spikes caught in time.',
      requirement: 'Recover from a high with a correction within 45 minutes, 5 times.',
      progressKind: ProgressKind.cumulative,
      targetValue: 5,
    ),
    BadgeDefinition(
      key: 'b_streak_7',
      title: 'Week Warrior',
      category: BadgeCategory.streaks,
      icon: Symbols.local_fire_department,
      flavor: 'Seven days, never blind.',
      requirement: 'Log at least one scan every day for 7 consecutive days.',
      progressKind: ProgressKind.peak,
      targetValue: 7,
    ),
    BadgeDefinition(
      key: 'b_streak_14',
      title: 'Two-Week Sentinel',
      category: BadgeCategory.streaks,
      icon: Symbols.date_range,
      flavor: 'A fortnight with eyes open.',
      requirement: 'Log at least one scan every day for 14 consecutive days.',
      progressKind: ProgressKind.peak,
      targetValue: 14,
    ),
    BadgeDefinition(
      key: 'b_streak_30',
      title: 'Monthly Sentinel',
      category: BadgeCategory.streaks,
      icon: Symbols.calendar_month,
      flavor: 'A full moon of daily scans.',
      requirement: 'Log at least one scan every day for 30 consecutive days.',
      progressKind: ProgressKind.peak,
      targetValue: 30,
    ),
    BadgeDefinition(
      key: 'b_streak_100',
      title: 'Century Sentinel',
      category: BadgeCategory.streaks,
      icon: Symbols.military_tech,
      flavor: 'One hundred dawns, faced.',
      requirement: 'Log at least one scan every day for 100 consecutive days.',
      progressKind: ProgressKind.peak,
      targetValue: 100,
    ),
    BadgeDefinition(
      key: 'b_streak_365',
      title: 'Eternal Sentinel',
      category: BadgeCategory.streaks,
      icon: Symbols.event_available,
      flavor: 'A whole year, never blind.',
      requirement: 'Log at least one scan every day for 365 consecutive days.',
      progressKind: ProgressKind.peak,
      targetValue: 365,
    ),
    BadgeDefinition(
      key: 'b_insulin_streak_30',
      title: 'Daily Dosing',
      category: BadgeCategory.streaks,
      icon: Symbols.medication,
      flavor: 'Thirty days of honest dosing.',
      requirement: 'Log at least one insulin dose every day for 30 consecutive days.',
      progressKind: ProgressKind.peak,
      targetValue: 30,
    ),

    // ── 3. PERFECTION (6) ─────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_chef_kiss_1',
      title: "Chef's Kiss",
      category: BadgeCategory.perfection,
      icon: Symbols.restaurant_menu,
      flavor: 'Ten times, insulin led the meal.',
      requirement: 'Log insulin before a meal 10 times.',
      progressKind: ProgressKind.cumulative,
      targetValue: 10,
    ),
    BadgeDefinition(
      key: 'b_chef_kiss_2',
      title: 'Master Chef',
      category: BadgeCategory.perfection,
      icon: Symbols.menu_book,
      flavor: 'Fifty pre-boluses, perfectly timed.',
      requirement: 'Pre-bolus 50 times.',
      progressKind: ProgressKind.cumulative,
      targetValue: 50,
    ),
    BadgeDefinition(
      key: 'b_perfect_day',
      title: 'Perfect Day',
      category: BadgeCategory.perfection,
      icon: Symbols.verified,
      flavor: 'All in range, no lows.',
      requirement: 'Achieve 100% TIR (without any low) for a single day.',
      progressKind: ProgressKind.cumulative,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_perfect_full_week',
      title: 'Flawless Week',
      category: BadgeCategory.perfection,
      icon: Symbols.task_alt,
      flavor: 'Seven days camped in range.',
      requirement: 'Achieve 70%+ TIR on 7 consecutive days.',
      progressKind: ProgressKind.peak,
      targetValue: 7,
    ),
    BadgeDefinition(
      key: 'b_no_hypo_30',
      title: 'The Untouchable',
      category: BadgeCategory.perfection,
      icon: Symbols.shield_moon,
      flavor: 'A month without a low.',
      requirement: '30 consecutive days without a single low reading.',
      progressKind: ProgressKind.peak,
      targetValue: 30,
    ),
    BadgeDefinition(
      key: 'b_calm_week',
      title: 'Still Water Week',
      category: BadgeCategory.perfection,
      icon: Symbols.blur_on,
      flavor: 'A week of smooth water.',
      requirement: 'Average SD under 30 across 7 consecutive days of readings.',
      progressKind: ProgressKind.peak,
      targetValue: 7,
    ),

    // ── 4. GOALS (3) ──────────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_hydration_1',
      title: 'Aqua Adept',
      category: BadgeCategory.goals,
      icon: Symbols.water_drop,
      flavor: 'Thirty days of full glasses.',
      requirement: 'Hit the water goal 30 days in a row.',
      progressKind: ProgressKind.peak,
      targetValue: 30,
    ),
    BadgeDefinition(
      key: 'b_hydration_2',
      title: 'The River',
      category: BadgeCategory.goals,
      icon: Symbols.waves,
      flavor: 'One hundred rivers crossed.',
      requirement: 'Hit the water goal 100 days total.',
      progressKind: ProgressKind.cumulative,
      targetValue: 100,
    ),
    BadgeDefinition(
      key: 'b_goal_1',
      title: 'First Frontier',
      category: BadgeCategory.goals,
      icon: Symbols.flag,
      flavor: 'First settled goal.',
      requirement: 'Complete 1 overarching goal.',
      progressKind: ProgressKind.cumulative,
      targetValue: 1,
    ),

    // ── 5. ECONOMY (4) ────────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_rotator_1',
      title: 'Rotator Cuff',
      category: BadgeCategory.economy,
      icon: Symbols.sync_alt,
      flavor: 'Every spoke of the wheel touched.',
      requirement: 'Log 7 unique injection sites without repeating.',
      progressKind: ProgressKind.cumulative,
      targetValue: 7,
    ),
    BadgeDefinition(
      key: 'b_data_hoarder',
      title: 'Data Hoarder',
      category: BadgeCategory.economy,
      icon: Symbols.database,
      flavor: 'Five hundred points on the map.',
      requirement: 'Log 500 CGM or fingerstick scans total.',
      progressKind: ProgressKind.cumulative,
      targetValue: 500,
    ),
    BadgeDefinition(
      key: 'b_insulin_100',
      title: 'The Chemist',
      category: BadgeCategory.economy,
      icon: Symbols.biotech,
      flavor: 'A hundred doses, recorded.',
      requirement: 'Log 100 insulin doses total.',
      progressKind: ProgressKind.cumulative,
      targetValue: 100,
    ),
    BadgeDefinition(
      key: 'b_coin_bank',
      title: 'The Coiner',
      category: BadgeCategory.economy,
      icon: Symbols.monetization_on,
      flavor: 'A thousand coins to the guild.',
      requirement: 'Earn 1,000 effort coins through daily logging.',
      progressKind: ProgressKind.cumulative,
      targetValue: 1000,
    ),

    // ── 6. RARITIES (6) ───────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_zentient',
      title: 'Zentient',
      category: BadgeCategory.rarities,
      icon: Symbols.self_improvement,
      flavor: 'Twenty days of body and number.',
      requirement: 'Log a mood anchor alongside a scan 20 times.',
      progressKind: ProgressKind.cumulative,
      targetValue: 20,
    ),
    BadgeDefinition(
      key: 'b_new_years_scan',
      title: "New Year's Dawn",
      category: BadgeCategory.rarities,
      icon: Symbols.celebration,
      flavor: 'The year began at a steady level.',
      requirement: 'Log a scan on January 1st.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_midnight_oil',
      title: 'Midnight Oil',
      category: BadgeCategory.rarities,
      icon: Symbols.dark_mode,
      flavor: 'A dose while the guild slept.',
      requirement: 'Log an insulin dose between midnight and 04:00.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_guardian_dark',
      title: 'Guardian of the Dark',
      category: BadgeCategory.rarities,
      icon: Symbols.bedtime,
      flavor: 'Watching through the small hours.',
      requirement: 'Log a scan between 02:00 and 04:00.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_leap_day',
      title: 'Leap of Faith',
      category: BadgeCategory.rarities,
      icon: Symbols.event,
      flavor: 'Once every four years, recorded.',
      requirement: 'Log a scan on February 29th.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_year_365',
      title: 'Circle of Seasons',
      category: BadgeCategory.rarities,
      icon: Symbols.autorenew,
      flavor: 'A full year turned.',
      requirement: 'Log a completion 365 days after your very first.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),

    // ── 7. CALLING (10) ───────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_tir_70',
      title: 'The Stabilizer (Initiate)',
      category: BadgeCategory.calling,
      icon: Symbols.shield,
      flavor: 'One week at the 70% line.',
      requirement: 'Achieve 70% TIR for a full week.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_tir_80',
      title: 'The Stabilizer (Veteran)',
      category: BadgeCategory.calling,
      icon: Symbols.workspace_premium,
      flavor: 'One week at the 80% line.',
      requirement: 'Achieve 80% TIR for a full week.',
      progressKind: ProgressKind.event,
      targetValue: 1,
    ),
    BadgeDefinition(
      key: 'b_pizza_gauntlet_1',
      title: 'Pizza Survivor',
      category: BadgeCategory.calling,
      icon: Symbols.local_pizza,
      flavor: 'Three gauntlets, three wins.',
      requirement: 'Complete the "Pizza Gauntlet" weekly quest 3 times.',
      progressKind: ProgressKind.cumulative,
      targetValue: 3,
    ),
    BadgeDefinition(
      key: 'b_stabilizer_trial',
      title: 'Trial of Steady Hands',
      category: BadgeCategory.calling,
      icon: Symbols.handshake,
      domain: CallingDomain.warrior,
      flavor: 'Thirty days, one steady grip.',
      requirement: 'Reach a 30-day scan streak while pledged to the Stabilizer.',
      progressKind: ProgressKind.peak,
      targetValue: 30,
    ),
    BadgeDefinition(
      key: 'b_counter_trial',
      title: 'Trial of the Scales',
      category: BadgeCategory.calling,
      icon: Symbols.balance,
      domain: CallingDomain.sage,
      flavor: 'A hundred numbers balanced.',
      requirement: 'Log 100 carb or insulin entries while pledged to the Counter.',
      progressKind: ProgressKind.cumulative,
      targetValue: 100,
    ),
    BadgeDefinition(
      key: 'b_hydrator_trial',
      title: 'Trial of the Droplet',
      category: BadgeCategory.calling,
      icon: Symbols.local_drink,
      domain: CallingDomain.monk,
      flavor: 'Twenty-one rivers run to the sea.',
      requirement: 'Hit the water goal 21 days in a row while pledged to the Hydrator.',
      progressKind: ProgressKind.peak,
      targetValue: 21,
    ),
    BadgeDefinition(
      key: 'b_rotator_trial',
      title: 'Trial of the Pinwheel',
      category: BadgeCategory.calling,
      icon: Symbols.rotate_right,
      domain: CallingDomain.bard,
      flavor: 'Seven turns, every spoke fresh.',
      requirement: 'Log 7 site rotations while pledged to the Rotator.',
      progressKind: ProgressKind.cumulative,
      targetValue: 7,
    ),
    BadgeDefinition(
      key: 'b_analyst_trial',
      title: 'Trial of the Eye',
      category: BadgeCategory.calling,
      icon: Symbols.visibility,
      domain: CallingDomain.ranger,
      flavor: 'Fifteen dawns observed.',
      requirement: 'Log 15 dawn scans (04:00-08:00) while pledged to the Analyst.',
      progressKind: ProgressKind.cumulative,
      targetValue: 15,
    ),
    BadgeDefinition(
      key: 'b_alchemist_trial',
      title: 'Trial of the Flask',
      category: BadgeCategory.calling,
      icon: Symbols.science,
      domain: CallingDomain.artificer,
      flavor: 'A hundred precise doses.',
      requirement: 'Log 100 insulin doses while pledged to the Alchemist.',
      progressKind: ProgressKind.cumulative,
      targetValue: 100,
    ),
    BadgeDefinition(
      key: 'b_guild_sentinel',
      title: 'Guild Sentinel',
      category: BadgeCategory.calling,
      icon: Symbols.diamond,
      flavor: 'The guild trusts you with the gate.',
      requirement: 'Reach 10,000 lifetime XP (Calling Level 10).',
      progressKind: ProgressKind.cumulative,
      targetValue: 10000,
    ),

    // ── 8. SEALED (8) ─────────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'b_survivor',
      title: 'Survivor',
      category: BadgeCategory.sealed,
      icon: Symbols.volunteer_activism,
      flavor: 'A sick day, and you held the line.',
      requirement: 'Navigate a Sick Day without going hypo (<70) for 24 hours.',
      progressKind: ProgressKind.event,
      targetValue: 1,
      sealed: true,
    ),
    BadgeDefinition(
      key: 'b_grace_token',
      title: 'The Forgiven',
      category: BadgeCategory.sealed,
      icon: Symbols.redeem,
      flavor: 'The token saved your streak.',
      requirement: 'Use a Grace Token to save a streak. (Hidden unlock.)',
      progressKind: ProgressKind.event,
      targetValue: 1,
      sealed: true,
    ),
    BadgeDefinition(
      key: 'b_slow_roll',
      title: 'The Slow Roll',
      category: BadgeCategory.sealed,
      icon: Symbols.bloodtype,
      flavor: 'Twenty-five checks the old way.',
      requirement: 'Log 25 fingerstick (manual) scans.',
      progressKind: ProgressKind.cumulative,
      targetValue: 25,
      sealed: true,
    ),
    BadgeDefinition(
      key: 'b_hyde',
      title: 'The Hyde Files',
      category: BadgeCategory.sealed,
      icon: Symbols.edit_note,
      flavor: 'Fifty moods, honestly filed.',
      requirement: 'Log a mood context 50 times.',
      progressKind: ProgressKind.cumulative,
      targetValue: 50,
      sealed: true,
    ),
    BadgeDefinition(
      key: 'b_ketone_storm',
      title: 'Ketone Sleuth',
      category: BadgeCategory.sealed,
      icon: Symbols.cyclone,
      flavor: 'Twenty-five storms investigated.',
      requirement: 'Log ketone checks 25 times.',
      progressKind: ProgressKind.cumulative,
      targetValue: 25,
      sealed: true,
    ),
    BadgeDefinition(
      key: 'b_all_nighter',
      title: 'Night Shift',
      category: BadgeCategory.sealed,
      icon: Symbols.nights_stay,
      flavor: 'Three nights watched to morning.',
      requirement: 'Log a scan between 02:00 and 05:00 on 3 different nights.',
      progressKind: ProgressKind.peak,
      targetValue: 3,
      sealed: true,
    ),
    BadgeDefinition(
      key: 'b_perfectionist',
      title: 'Perfectionist',
      category: BadgeCategory.sealed,
      icon: Symbols.grade,
      flavor: 'Fourteen days without a low.',
      requirement: 'Achieve 14 consecutive no-low days.',
      progressKind: ProgressKind.peak,
      targetValue: 14,
      sealed: true,
    ),
    BadgeDefinition(
      key: 'b_marathon_day',
      title: 'Marathon Day',
      category: BadgeCategory.sealed,
      icon: Symbols.directions_run,
      flavor: 'One very full page.',
      requirement: 'Log 12 or more glucose logs on a single calendar day.',
      progressKind: ProgressKind.peak,
      targetValue: 12,
      sealed: true,
    ),
  ];

  static String _weekKey(LocalDate d) {
    final dt = DateTime(d.year, d.month, d.day);
    final monday = dt.subtract(Duration(days: dt.weekday - 1));
    return monday.toIso8601String().substring(0, 10);
  }

  static int _maxConsecutiveRun(Iterable<LocalDate> days) {
    final sorted = days.toList()..sort();
    if (sorted.isEmpty) return 0;
    int best = 1;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].differenceInDays(sorted[i - 1]) == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  /// Pure deterministic evaluation of all 50 badges from the glucose logbook.
  ///
  /// Day-level metrics are derived through [GlucoseSettlementEngine.settleDay].
  /// Per-day sickness is not persisted in v2, so [b_survivor] requires the
  /// profile to be currently marked sick alongside a clean logged day.
  static List<BadgeStatus> evaluate({
    required List<CompletionData> completions,
    required List<QuestData> quests,
    required List<GoalData> goals,
    required List<XpEventData> xpEvents,
    required List<StreakRepairData> streakRepairs,
    required ProfileData profile,
    required Map<String, int> questMaxStreaks,
    required Set<LocalDate> perfectDays,
    required Set<String> seenBadgeKeys,
  }) {
    final questMap = {for (final q in quests) q.id: q};
    final userCalling = profile.calling != null ? CallingDomain.values[profile.calling!] : null;

    GlucoseContext cctx(CompletionData c) => GlucoseContext.fromDb(c.contextJson);

    // ── Aggregate by date ──────────────────────────────────────────────────
    final byDate = <LocalDate, _DayAgg>{};
    final siteSequence = <({DateTime ts, InsulinSite site})>[];
    LocalDate? earliest;

    for (final c in completions) {
      final d = LocalDate.parse(c.localDate);
      final cc = cctx(c);
      final v = c.value;
      final agg = byDate.putIfAbsent(d, () => _DayAgg());
      agg.totalRows++;

      if (cc.isScan && c.numericValue != null) {
        agg.scans += v;
        agg.scanRows++;
        agg.lows += (c.numericValue! < GlucoseTunables.targetLow ? 1 : 0);
      } else if (cc.isInsulin) {
        agg.insulins += v;
        agg.insulinRows++;
      } else if (cc.isMeal) {
        agg.meals += v;
      } else if (cc.isWater) {
        agg.waters += v;
      } else if (cc.isMood) {
        agg.moods += v;
      } else if (cc.isKetone) {
        agg.ketones += v;
      } else if (cc.isSiteLog && cc.site != null) {
        siteSequence.add((ts: c.loggedAt ?? c.createdAt, site: cc.site!));
      }

      if (earliest == null || d < earliest) earliest = d;
    }

    // ── Settle each day through the canonical engine ───────────────────────
    final dayResults = <LocalDate, GlucoseDayResult>{};
    for (final d in byDate.keys.toList()..sort()) {
      dayResults[d] = GlucoseSettlementEngine.settleDay(
        date: d,
        completions: completions,
        isSick: false,
      );
    }

    final scanDays = byDate.keys.where((d) => byDate[d]!.scanDay).toSet();
    final cleanDays = byDate.keys.where((d) => byDate[d]!.cleanDay).toSet();
    final hydratedDays = byDate.keys.where((d) => byDate[d]!.hydratedDay).toSet();
    final moodAndScanDays = <LocalDate>{};
    for (final d in byDate.keys) {
      final agg = byDate[d]!;
      if (agg.moods >= 1 && agg.scanRows >= 1) moodAndScanDays.add(d);
    }

    final totalKetones = byDate.values.fold<int>(0, (s, a) => s + a.ketones);
    final totalMoods = byDate.values.fold<int>(0, (s, a) => s + a.moods);
    final totalScanCount = byDate.values.fold<int>(0, (s, a) => s + a.scans);
    final totalInsulinCount = byDate.values.fold<int>(0, (s, a) => s + a.insulins);
    final totalCarbOrInsulinCount = byDate.values.fold<int>(0, (s, a) => s + a.insulins + a.meals);
    final totalPreBoluses = dayResults.values.fold<int>(0, (s, d) => s + d.preBoluses);
    final totalRecoveries = dayResults.values.fold<int>(0, (s, d) => s + d.recoveries);
    final totalCoins = dayResults.values.fold<int>(0, (s, d) => s + d.effortCoins);
    final perfectDayCount = dayResults.values.where((d) => d.tir >= 1.0 && !d.hadHypo).length;
    final smoothDayCount = dayResults.values.where((d) => d.scanCount >= 4 && d.sd < GlucoseTunables.sdSilver && d.sd > 0).length;

    final maxScanStreak = _maxConsecutiveRun(scanDays);
    final maxCleanStreak = _maxConsecutiveRun(cleanDays);
    final maxHydratedStreak = _maxConsecutiveRun(hydratedDays);

    // ── Weekly TIR windows ─────────────────────────────────────────────────
    final weekAgg = <String, ({int scans, int inRange, int days})>{};
    for (final entry in dayResults.entries) {
      final key = _weekKey(entry.key);
      final w = weekAgg[key] ?? (scans: 0, inRange: 0, days: 0);
      final r = entry.value;
      if (r.scanCount > 0) {
        final inRange = (r.tir * r.scanCount).round();
        weekAgg[key] = (
          scans: w.scans + r.scanCount,
          inRange: w.inRange + inRange,
          days: w.days + 1,
        );
      }
    }
    const int minWeekDays = 4;

    bool hasWeek(double target) => weekAgg.values.any((w) =>
        w.days >= minWeekDays &&
        w.scans > 0 &&
        (w.inRange / w.scans) >= target);

    bool hasWeekImprovement() {
      final keys = weekAgg.keys.toList()..sort();
      double? prevTir;
      for (final k in keys) {
        final w = weekAgg[k]!;
        if (w.days < minWeekDays || w.scans == 0) continue;
        final tir = w.inRange / w.scans;
        if (prevTir != null && tir - prevTir >= 0.01) {
          return true;
        }
        prevTir = tir;
      }
      return false;
    }

    // ── Site rotation ──────────────────────────────────────────────────────
    siteSequence.sort((a, b) => a.ts.compareTo(b.ts));
    final uniqueSites = siteSequence.map((e) => e.site).toSet().length;
    int rotations = 0;
    for (int i = 1; i < siteSequence.length; i++) {
      if (siteSequence[i].site != siteSequence[i - 1].site) rotations++;
    }

    // ── Pizza Gauntlet + Endo Briefing ─────────────────────────────────────
    int pizzaWeeks = 0;
    bool hasEndo = false;
    {
      final pizzaWeeksSet = <String>{};
      for (final c in completions) {
        final q = questMap[c.questId];
        if (q == null) continue;
        final title = q.title.toLowerCase();
        if (title.contains('pizza')) {
          pizzaWeeksSet.add(_weekKey(LocalDate.parse(c.localDate)));
        }
        if (title.contains('endo')) hasEndo = true;
      }
      pizzaWeeks = pizzaWeeksSet.length;
    }

    // ── Dawn / night scans ─────────────────────────────────────────────────
    int dawnScans = 0;
    final nightScanDays = <LocalDate>{};
    bool hasJan1Scan = false;
    bool hasFeb29Scan = false;
    bool hasGuardianDark = false;
    bool hasMidnightOil = false;
    bool hasGraceUsed = false;
    int fingerstickCount = 0;

    for (final c in completions) {
      final cc = cctx(c);
      final ts = c.loggedAt ?? c.createdAt;
      final hour = ts.hour;
      final d = LocalDate.parse(c.localDate);

      if (cc.isScan && c.numericValue != null) {
        if (hour >= 4 && hour < 8) dawnScans += c.value;
        if (hour >= 2 && hour < 4) hasGuardianDark = true;
        if (hour >= 2 && hour < 5) nightScanDays.add(d);
        if (cc.scanType == ScanType.fingerstick) fingerstickCount += c.value;
        if (d.month == 1 && d.day == 1) hasJan1Scan = true;
        if (d.month == 2 && d.day == 29) hasFeb29Scan = true;
      }
      if (cc.isInsulin && hour >= 0 && hour < 4) hasMidnightOil = true;
      if (c.note != null && c.note!.toLowerCase().contains('grace')) hasGraceUsed = true;
    }

    // ── Year One ───────────────────────────────────────────────────────────
    bool hasYearOne = false;
    if (earliest != null) {
      for (final d in byDate.keys) {
        if (d.differenceInDays(earliest) >= 365) {
          hasYearOne = true;
          break;
        }
      }
    }

    // ── Sick day survival (see class doc) ──────────────────────────────────
    final survivor =
        profile.isSick && dayResults.values.any((d) => d.hasData && !d.hadHypo);

    // ── Guild XP (all non-coin events) ─────────────────────────────────────
    final guildXp = xpEvents
        .where((e) => !XpEventType.values[e.type].isCoin)
        .fold<int>(0, (s, e) => s + e.amount);

    // ── Evaluate all catalog badges ────────────────────────────────────────
    return catalog.map((b) {
      bool earned = seenBadgeKeys.contains('badge:${b.key}') || seenBadgeKeys.contains(b.key);
      int currentVal = 0;
      bool eligible = true;

      switch (b.key) {
        // JOURNEY
        case 'b_first_scan':
          currentVal = totalScanCount;
          earned = earned || currentVal >= 1;
          break;
        case 'b_smooth_operator':
          currentVal = smoothDayCount;
          earned = earned || currentVal >= 1;
          break;
        case 'b_timetraveler_1':
          currentVal = hasWeekImprovement() ? 1 : 0;
          earned = earned || currentVal >= 1;
          break;
        case 'b_endo_visit':
          currentVal = hasEndo ? 1 : 0;
          earned = earned || currentVal >= 1;
          break;
        case 'b_scan_100':
          currentVal = totalScanCount;
          earned = earned || currentVal >= 100;
          break;
        case 'b_ketone_10':
          currentVal = totalKetones;
          earned = earned || currentVal >= 10;
          break;

        // STREAKS
        case 'b_first_responder_1':
          currentVal = totalRecoveries;
          earned = earned || currentVal >= 5;
          break;
        case 'b_streak_7':
          currentVal = maxScanStreak;
          earned = earned || currentVal >= 7;
          break;
        case 'b_streak_14':
          currentVal = maxScanStreak;
          earned = earned || currentVal >= 14;
          break;
        case 'b_streak_30':
          currentVal = maxScanStreak;
          earned = earned || currentVal >= 30;
          break;
        case 'b_streak_100':
          currentVal = maxScanStreak;
          earned = earned || currentVal >= 100;
          break;
        case 'b_streak_365':
          currentVal = maxScanStreak;
          earned = earned || currentVal >= 365;
          break;
        case 'b_insulin_streak_30':
          currentVal = _maxConsecutiveRun(
              byDate.keys.where((d) => byDate[d]!.insulinRows >= 1));
          earned = earned || currentVal >= 30;
          break;

        // PERFECTION
        case 'b_chef_kiss_1':
          currentVal = totalPreBoluses;
          earned = earned || currentVal >= 10;
          break;
        case 'b_chef_kiss_2':
          currentVal = totalPreBoluses;
          earned = earned || currentVal >= 50;
          break;
        case 'b_perfect_day':
          currentVal = perfectDayCount;
          earned = earned || currentVal >= 1;
          break;
        case 'b_perfect_full_week':
          currentVal = _perfectWeekStreak(dayResults);
          earned = earned || currentVal >= 7;
          break;
        case 'b_no_hypo_30':
          currentVal = maxCleanStreak;
          earned = earned || currentVal >= 30;
          break;
        case 'b_calm_week':
          currentVal = _calmWeekStreak(dayResults);
          earned = earned || currentVal >= 7;
          break;

        // GOALS
        case 'b_hydration_1':
          currentVal = maxHydratedStreak;
          earned = earned || currentVal >= 30;
          break;
        case 'b_hydration_2':
          currentVal = hydratedDays.length;
          earned = earned || currentVal >= 100;
          break;
        case 'b_goal_1':
          currentVal = goals.where((g) => g.completedAt != null).length;
          earned = earned || currentVal >= 1;
          break;

        // ECONOMY
        case 'b_rotator_1':
          currentVal = uniqueSites;
          earned = earned || currentVal >= 7;
          break;
        case 'b_data_hoarder':
          currentVal = totalScanCount;
          earned = earned || currentVal >= 500;
          break;
        case 'b_insulin_100':
          currentVal = totalInsulinCount;
          earned = earned || currentVal >= 100;
          break;
        case 'b_coin_bank':
          currentVal = totalCoins;
          earned = earned || currentVal >= 1000;
          break;

        // RARITIES
        case 'b_zentient':
          currentVal = moodAndScanDays.length;
          earned = earned || currentVal >= 20;
          break;
        case 'b_new_years_scan':
          currentVal = hasJan1Scan ? 1 : 0;
          earned = earned || hasJan1Scan;
          break;
        case 'b_midnight_oil':
          currentVal = hasMidnightOil ? 1 : 0;
          earned = earned || hasMidnightOil;
          break;
        case 'b_guardian_dark':
          currentVal = hasGuardianDark ? 1 : 0;
          earned = earned || hasGuardianDark;
          break;
        case 'b_leap_day':
          currentVal = hasFeb29Scan ? 1 : 0;
          earned = earned || hasFeb29Scan;
          break;
        case 'b_year_365':
          currentVal = hasYearOne ? 1 : 0;
          earned = earned || hasYearOne;
          break;

        // CALLING
        case 'b_tir_70':
          currentVal = hasWeek(0.70) ? 1 : 0;
          earned = earned || currentVal >= 1;
          break;
        case 'b_tir_80':
          currentVal = hasWeek(0.80) ? 1 : 0;
          earned = earned || currentVal >= 1;
          break;
        case 'b_pizza_gauntlet_1':
          currentVal = pizzaWeeks;
          earned = earned || currentVal >= 3;
          break;
        case 'b_stabilizer_trial':
          eligible = userCalling == CallingDomain.warrior;
          currentVal = maxScanStreak;
          earned = earned || (eligible && currentVal >= 30);
          break;
        case 'b_counter_trial':
          eligible = userCalling == CallingDomain.sage;
          currentVal = totalCarbOrInsulinCount;
          earned = earned || (eligible && currentVal >= 100);
          break;
        case 'b_hydrator_trial':
          eligible = userCalling == CallingDomain.monk;
          currentVal = maxHydratedStreak;
          earned = earned || (eligible && currentVal >= 21);
          break;
        case 'b_rotator_trial':
          eligible = userCalling == CallingDomain.bard;
          currentVal = rotations;
          earned = earned || (eligible && currentVal >= 7);
          break;
        case 'b_analyst_trial':
          eligible = userCalling == CallingDomain.ranger;
          currentVal = dawnScans;
          earned = earned || (eligible && currentVal >= 15);
          break;
        case 'b_alchemist_trial':
          eligible = userCalling == CallingDomain.artificer;
          currentVal = totalInsulinCount;
          earned = earned || (eligible && currentVal >= 100);
          break;
        case 'b_guild_sentinel':
          currentVal = guildXp;
          earned = earned || currentVal >= 10000;
          break;

        // SEALED
        case 'b_survivor':
          currentVal = survivor ? 1 : 0;
          earned = earned || survivor;
          break;
        case 'b_grace_token':
          currentVal = hasGraceUsed ? 1 : 0;
          earned = earned || hasGraceUsed;
          break;
        case 'b_slow_roll':
          currentVal = fingerstickCount;
          earned = earned || currentVal >= 25;
          break;
        case 'b_hyde':
          currentVal = totalMoods;
          earned = earned || currentVal >= 50;
          break;
        case 'b_ketone_storm':
          currentVal = byDate.values.fold<int>(0, (s, a) => s + a.ketones);
          earned = earned || currentVal >= 25;
          break;
        case 'b_all_nighter':
          currentVal = nightScanDays.length;
          earned = earned || currentVal >= 3;
          break;
        case 'b_perfectionist':
          currentVal = maxCleanStreak;
          earned = earned || currentVal >= 14;
          break;
        case 'b_marathon_day':
          currentVal = byDate.values.fold<int>(0, (s, a) => (a.totalRows > s ? a.totalRows : s));
          earned = earned || currentVal >= 12;
          break;
      }

      return BadgeStatus(
        definition: b,
        isEarned: earned,
        currentValue: currentVal,
        isEligible: eligible,
      );
    }).toList();
  }

  static int _calmWeekStreak(Map<LocalDate, GlucoseDayResult> results) {
    final days = results.entries
        .where((e) => e.value.scanCount >= 2 && e.value.sd > 0 && e.value.sd < GlucoseTunables.sdSilver)
        .map((e) => e.key)
        .toList()
      ..sort();
    return _maxConsecutiveRun(days);
  }

  static int _perfectWeekStreak(Map<LocalDate, GlucoseDayResult> results) {
    final days = results.entries
        .where((e) => e.value.scanCount >= 1 && e.value.tir >= 0.70)
        .map((e) => e.key)
        .toList()
      ..sort();
    return _maxConsecutiveRun(days);
  }
}