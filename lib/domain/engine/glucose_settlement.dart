import 'dart:math';
import '../constants/tunables.dart';
import '../../data/db/database.dart';
import '../model/diabetes_context.dart';
import '../model/models.dart';
import 'settlement.dart';

/// A single completed glucose day, derived from that day's ledger completions.
class GlucoseDayResult {
  final LocalDate date;
  final int scanCount;
  final double tir;
  final double sd;
  final double minWindowSd;
  final int outcomeXp;
  final int effortCoins;
  final int recoveryBonus;
  final bool calmSeas;
  final bool wasSick;
  final bool hadHypo;
  final int preBoluses;
  final int recoveries;

  const GlucoseDayResult({
    required this.date,
    required this.scanCount,
    required this.tir,
    required this.sd,
    required this.minWindowSd,
    required this.outcomeXp,
    required this.effortCoins,
    required this.recoveryBonus,
    required this.calmSeas,
    required this.wasSick,
    required this.hadHypo,
    required this.preBoluses,
    required this.recoveries,
  });

  bool get hasData => scanCount > 0;
}

/// Idempotent daily settle math for the GLUCOSE_GUILD split-track system.
///
/// - Outcome XP (glucose) is hard-capped daily via [GlucoseTunables.dailyOutcomeXpCap].
/// - Effort coins are uncapped and reward the act of logging, never the number.
/// - Recovery bonus rewards catching a spike within [GlucoseTunables.recoveryWindowMinutes].
/// - Calm Seas rewards low volatility over 4-hour windows.
class GlucoseSettlementEngine {
  static DateTime _ts(CompletionData c) => c.loggedAt ?? c.createdAt;

  static GlucoseContext _ctx(CompletionData c) => GlucoseContext.fromDb(c.contextJson);

  static double _sdOf(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  /// Minimum standard deviation across 4-hour windows of scans for [date].
  /// Returns +infinity when there are not enough readings to judge.
  static double min4hWindowSd(List<CompletionData> scans) {
    if (scans.length < 2) return double.infinity;
    final sorted = List<CompletionData>.of(scans)
      ..sort((a, b) => _ts(a).compareTo(_ts(b)));
    final byWindow = <int, List<double>>{};
    for (final s in sorted) {
      final ts = _ts(s);
      final window = ts.hour ~/ 4;
      byWindow.putIfAbsent(window, () => []).add(s.numericValue!);
    }
    double minSd = double.infinity;
    for (final values in byWindow.values) {
      if (values.length >= 2) {
        final wSd = _sdOf(values);
        if (wSd < minSd) minSd = wSd;
      }
    }
    return minSd;
  }

  /// Determines chef's-kiss pre-boluses: an insulin log at-or-before a meal's
  /// start (within [GlucoseTunables.preBolusGraceMinutes]).
  static int countPreBoluses(List<CompletionData> logs) {
    final meals = logs.where((c) => _ctx(c).isMeal).toList();
    final insulins = logs.where((c) => _ctx(c).isInsulin).toList();
    int count = 0;
    for (final meal in meals) {
      final mealTs = _ts(meal);
      for (final ins in insulins) {
        final delta = mealTs.difference(_ts(ins)).inMinutes;
        if (delta >= -GlucoseTunables.preBolusGraceMinutes) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  /// How many times the user caught a high with a correction within the window.
  static int countRecoveries(List<CompletionData> logs) {
    final scans = logs
        .where((c) => _ctx(c).isScan && c.numericValue != null)
        .toList()
      ..sort((a, b) => _ts(a).compareTo(_ts(b)));
    final insulins = logs.where((c) => _ctx(c).isInsulin).toList();
    int count = 0;
    for (final high in scans.where((c) => c.numericValue! > GlucoseTunables.targetHigh)) {
      for (final ins in insulins) {
        final delta = _ts(ins).difference(_ts(high)).inMinutes;
        if (delta > 0 && delta < GlucoseTunables.recoveryWindowMinutes) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  /// Core daily settlement — pure and deterministic.
  static GlucoseDayResult settleDay({
    required LocalDate date,
    required List<CompletionData> completions,
    required bool isSick,
  }) {
    final logs = completions
        .where((c) => LocalDate.parse(c.localDate) == date)
        .toList();

    final scans = logs
        .where((c) => _ctx(c).isScan && c.numericValue != null)
        .toList();

    final inRange = scans.where((s) {
      final v = s.numericValue!;
      return v >= GlucoseTunables.targetLow && v <= GlucoseTunables.targetHigh;
    }).length;

    final tir = scans.isEmpty ? 0.0 : inRange / scans.length;

    final scanValues = scans.map((s) => s.numericValue!).toList();
    final sd = _sdOf(scanValues);
    final minWindowSd = min4hWindowSd(scans);
    final hadHypo = scans.any((s) => s.numericValue! < GlucoseTunables.targetLow);
    final preBoluses = countPreBoluses(logs);
    final recoveries = countRecoveries(logs);

    // Outcome XP — capped to prevent perfectionism. Suspended on sick days.
    int outcomeXp = 0;
    if (!isSick && scans.isNotEmpty) {
      outcomeXp = ((tir / GlucoseTunables.tirTargetPercentage) *
              GlucoseTunables.outcomeXpTargetReward)
          .round()
          .clamp(0, GlucoseTunables.dailyOutcomeXpCap);
    }

    // Effort coins — infinite, tied to logging cadence (even out-of-range logs count).
    final insulinCount = logs.where((c) => _ctx(c).isInsulin).length;
    final mealCount = logs.where((c) => _ctx(c).isMeal).length;
    final waterCount = logs.where((c) => _ctx(c).isWater).length;
    final siteCount = logs.where((c) => _ctx(c).isSiteLog).length;
    final moodCount = logs.where((c) => _ctx(c).isMood).length;
    final ketoneCount = logs.where((c) => _ctx(c).isKetone).length;

    final effortCoins = scans.length * GlucoseTunables.habitCoinPerScan +
        insulinCount * GlucoseTunables.habitCoinPerInsulinLog +
        mealCount * GlucoseTunables.habitCoinPerCarbLog +
        waterCount * GlucoseTunables.habitCoinPerWater +
        siteCount * GlucoseTunables.habitCoinPerSiteRotation +
        moodCount * GlucoseTunables.habitCoinPerMoodAnchor +
        ketoneCount * GlucoseTunables.habitCoinPerKetoneCheck +
        preBoluses * GlucoseTunables.habitCoinPerCarbLog;

    final recoveryBonus = recoveries > 0 ? GlucoseTunables.recoveryBonusXp : 0;

    // Calm Seas: flat line over a 4-hour window (SD < silver), not on sick days.
    final calmSeas =
        !isSick && scans.length >= 3 && minWindowSd < GlucoseTunables.sdSilver;

    return GlucoseDayResult(
      date: date,
      scanCount: scans.length,
      tir: tir,
      sd: sd,
      minWindowSd: minWindowSd,
      outcomeXp: outcomeXp,
      effortCoins: effortCoins,
      recoveryBonus: recoveryBonus,
      calmSeas: calmSeas,
      wasSick: isSick,
      hadHypo: hadHypo,
      preBoluses: preBoluses,
      recoveries: recoveries,
    );
  }

  static String _ref(LocalDate date, String kind) => 'glucose:${date.formatted}:$kind';

  /// Materialize a settled day into idempotent ledger events.
  static List<SettlementPendingEvent> eventsFor(GlucoseDayResult day) {
    final events = <SettlementPendingEvent>[];
    if (day.outcomeXp > 0) {
      events.add(SettlementPendingEvent(
        type: XpEventType.outcomeXp,
        ref: _ref(day.date, 'outcome'),
        amount: day.outcomeXp,
        localDate: day.date,
      ));
    }
    if (day.effortCoins > 0) {
      events.add(SettlementPendingEvent(
        type: XpEventType.effortCoins,
        ref: _ref(day.date, 'coins'),
        amount: day.effortCoins,
        localDate: day.date,
      ));
    }
    if (day.recoveryBonus > 0) {
      events.add(SettlementPendingEvent(
        type: XpEventType.recoveryBonus,
        ref: _ref(day.date, 'recovery'),
        amount: day.recoveryBonus,
        localDate: day.date,
      ));
    }
    if (day.calmSeas) {
      events.add(SettlementPendingEvent(
        type: XpEventType.calmSeas,
        ref: _ref(day.date, 'calm'),
        amount: GlucoseTunables.calmSeasBonusXp,
        localDate: day.date,
      ));
    }
    return events;
  }
}