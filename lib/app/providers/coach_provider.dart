import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/database.dart';
import '../../domain/constants/tunables.dart';
import '../../domain/engine/coach.dart';
import '../../domain/engine/glucose_settlement.dart';
import '../../domain/model/diabetes_context.dart';
import '../../domain/model/models.dart';
import 'database_provider.dart';
import 'profile_provider.dart';

final coachShownMapProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(ledgerDaoProvider).watchKv('coach_shown').map((raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  });
});

final activeCoachSignalProvider = FutureProvider<CoachSignal?>((ref) async {
  final today = ref.watch(effectiveLocalDateProvider);
  final profileAsync = ref.watch(profileStreamProvider);
  final profile = profileAsync.value;
  final userName = profile?.name;

  final completionsDao = ref.watch(completionsDaoProvider);
  final shownMapAsync = ref.watch(coachShownMapProvider);
  final shownMap = shownMapAsync.value ?? <String, dynamic>{};

  final all = await completionsDao.getAllCompletions();

  LocalDate? lastActiveDate;
  for (final c in all) {
    final d = LocalDate.parse(c.localDate);
    if (lastActiveDate == null || d > lastActiveDate) lastActiveDate = d;
  }

  List<CompletionData> dayLogs(LocalDate d) =>
      all.where((c) => LocalDate.parse(c.localDate) == d).toList();

  final todayLogs = dayLogs(today);
  final yesterday = today.subtractDays(1);
  final yesterdayLogs = dayLogs(yesterday);

  final scansToday = todayLogs
      .where((c) => GlucoseContext.fromDb(c.contextJson).isScan)
      .map((c) => ScanLogEntry(
            value: c.numericValue ?? 0,
            at: (c.loggedAt ?? c.createdAt).toLocal(),
          ))
      .toList();

  final waterGlassesToday =
      todayLogs.where((c) => GlucoseContext.fromDb(c.contextJson).isWater).length;
  final mealsToday =
      todayLogs.where((c) => GlucoseContext.fromDb(c.contextJson).isMeal).length;

  // Pre-Bolus Pro: any meal today that waited too long for coverage.
  bool prebolusMissToday = false;
  {
    final insulins = todayLogs
        .where((c) => GlucoseContext.fromDb(c.contextJson).isInsulin)
        .map((c) => (c.loggedAt ?? c.createdAt).toLocal())
        .toList();
    final now = DateTime.now();
    for (final meal in todayLogs.where((c) => GlucoseContext.fromDb(c.contextJson).isMeal)) {
      final mealTs = (meal.loggedAt ?? meal.createdAt).toLocal();
      if (now.difference(mealTs).inMinutes < CoachTunables.coachPrebolusGraceMinutes) {
        continue; // meal is too fresh to judge
      }
      final covered = insulins.any((ts) {
        final delta = mealTs.difference(ts).inMinutes;
        return delta >= -CoachTunables.coachPrebolusGraceMinutes &&
            delta <= CoachTunables.coachPrebolusGraceMinutes;
      });
      if (!covered) {
        prebolusMissToday = true;
        break;
      }
    }
  }

  // Dawn effect: high readings in the 4-8am window several days running.
  int dawnHighStreak = 0;
  {
    for (int i = 0; i < 30; i++) {
      final d = today.subtractDays(i);
      final dawnScans = dayLogs(d).where((c) {
        final ctx = GlucoseContext.fromDb(c.contextJson);
        if (!ctx.isScan || c.numericValue == null) return false;
        final h = (c.loggedAt ?? c.createdAt).toLocal().hour;
        return h >= CoachTunables.coachDawnWindowStartHour &&
            h < CoachTunables.coachDawnWindowEndHour;
      }).toList();
      if (i == 0 && dawnScans.isEmpty) continue; // today not yet judged
      if (dawnScans.any((c) => c.numericValue! > GlucoseTunables.targetHigh)) {
        dawnHighStreak++;
      } else {
        break;
      }
    }
  }

  // Rotation: consecutive days all injecting at the same site.
  int sameSiteForDays = 0;
  {
    InsulinSite? runningSite;
    for (int i = 0; i < 30; i++) {
      final d = today.subtractDays(i);
      final sites = dayLogs(d)
          .map((c) => GlucoseContext.fromDb(c.contextJson))
          .where((ctx) => ctx.isInsulin && ctx.site != null)
          .map((ctx) => ctx.site!)
          .toSet();
      if (i == 0 && sites.isEmpty) continue; // no insulin logged today yet
      if (sites.length != 1) break;
      final site = sites.first;
      runningSite ??= site;
      if (site != runningSite) break;
      sameSiteForDays++;
    }
  }

  // Closed-day settlement reads (yesterday).
  double? minWindowSdYesterday;
  int recoveriesYesterday = 0;
  double? tirPct;
  if (yesterdayLogs.isNotEmpty) {
    final day = GlucoseSettlementEngine.settleDay(
      date: yesterday,
      completions: all,
      isSick: profile?.isSick ?? false,
    );
    if (day.hasData) {
      minWindowSdYesterday = day.minWindowSd;
      recoveriesYesterday = day.recoveries;
      tirPct = day.tir;
    }
  }

  final rawSignals = CoachEngine.evaluateAll(
    input: CoachGlucoseInput(
      today: today,
      isSick: profile?.isSick ?? false,
      lastActiveDate: lastActiveDate,
      scansToday: scansToday,
      waterGlassesToday: waterGlassesToday,
      mealsToday: mealsToday,
      prebolusMissToday: prebolusMissToday,
      recoveriesYesterday: recoveriesYesterday,
      minWindowSdYesterday: minWindowSdYesterday,
      dawnHighStreak: dawnHighStreak,
      sameSiteForDays: sameSiteForDays,
      tirPct: tirPct,
    ),
    userName: userName,
  );

  // Filter against KV cooldowns
  for (final signal in rawSignals) {
    final entry = shownMap[signal.dedupKey];
    if (entry != null) {
      if (entry['once'] == true) {
        continue;
      }
      if (entry['last'] != null) {
        final lastDate = LocalDate.parse(entry['last']);
        final dismissCount = (entry['dismissCount'] as num?)?.toInt() ?? 0;
        final baseCooldown = signal.cooldownDays;
        final effectiveCooldown = dismissCount > 0
            ? min(baseCooldown * (1 << dismissCount), CoachTunables.coachMaxCooldown)
            : baseCooldown;

        if (today.differenceInDays(lastDate) < effectiveCooldown) {
          continue; // Cooldown still active
        }
      }
    }

    // First valid candidate wins
    return signal;
  }

  return null;
});

class CoachController {
  final Ref ref;

  CoachController(this.ref);

  Future<void> dismiss(CoachSignal signal) async {
    final today = ref.read(effectiveLocalDateProvider);
    final ledgerDao = ref.read(ledgerDaoProvider);
    final raw = await ledgerDao.getKv('coach_shown');
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (signal.ruleType == CoachRuleType.milestoneNear) {
      map[signal.dedupKey] = {'once': true};
    } else {
      final prevCount = (map[signal.dedupKey]?['dismissCount'] as num?)?.toInt() ?? 0;
      map[signal.dedupKey] = {
        'last': today.dateString,
        'dismissCount': prevCount + 1,
      };
    }

    await ledgerDao.setKv('coach_shown', jsonEncode(map));
  }

  Future<void> markAccepted(CoachSignal signal) async {
    final today = ref.read(effectiveLocalDateProvider);
    final ledgerDao = ref.read(ledgerDaoProvider);
    final raw = await ledgerDao.getKv('coach_shown');
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (signal.ruleType == CoachRuleType.milestoneNear) {
      map[signal.dedupKey] = {'once': true};
    } else {
      map[signal.dedupKey] = {
        'last': today.dateString,
        'dismissCount': 0,
      };
    }

    await ledgerDao.setKv('coach_shown', jsonEncode(map));
  }
}

final coachControllerProvider = Provider<CoachController>((ref) {
  return CoachController(ref);
});