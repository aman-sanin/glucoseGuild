import 'package:flutter_test/flutter_test.dart';
import 'package:glucose_guild/domain/constants/tunables.dart';
import 'package:glucose_guild/domain/engine/coach.dart';
import 'package:glucose_guild/domain/model/models.dart';

void main() {
  group('Glucose Guild Coach Detectors (Pure)', () {
    final today = LocalDate(2026, 9, 6);

    CoachGlucoseInput base() => CoachGlucoseInput(today: today);

    test('Welcome Back: fires after >= 48h silence, quiet before that', () {
      final away = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, lastActiveDate: today.subtractDays(2)),
      );
      expect(away.any((s) => s.ruleType == CoachRuleType.welcomeBack), isTrue);

      final near = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, lastActiveDate: today.subtractDays(1)),
      );
      expect(near.any((s) => s.ruleType == CoachRuleType.welcomeBack), isFalse);
    });

    test('Survival Mode: fires while the sick-day flag is set', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, isSick: true),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.survivalMode), isTrue);

      final healthy = CoachEngine.evaluateAll(input: base());
      expect(healthy.any((s) => s.ruleType == CoachRuleType.survivalMode), isFalse);
    });

    test('First Responder: recovery yesterday triggers the praise card', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, recoveriesYesterday: 1),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.firstResponder), isTrue);

      final quiet = CoachEngine.evaluateAll(input: base());
      expect(quiet.any((s) => s.ruleType == CoachRuleType.firstResponder), isFalse);
    });

    test('Pre-Bolus Pro: meal today without insulin coverage fires once', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, mealsToday: 1, prebolusMissToday: true),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.prebolusPro), isTrue);

      final covered = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, mealsToday: 1, prebolusMissToday: false),
      );
      expect(covered.any((s) => s.ruleType == CoachRuleType.prebolusPro), isFalse);
    });

    test('Essential Stumble: zero scans before noon (after noon)', () {
      final morning = CoachEngine.evaluateAll(
        input: base(),
        now: DateTime(2026, 9, 6, 9, 0),
      );
      expect(morning.any((s) => s.ruleType == CoachRuleType.essentialStumble), isFalse);

      // No scans at all today before noon.
      final signals = CoachEngine.evaluateAll(
        input: base(),
        now: DateTime(2026, 9, 6, 13, 0),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.essentialStumble), isTrue);

      // A scan before noon silences it.
      final scanned = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(
          today: today,
          scansToday: [ScanLogEntry(value: 110, at: DateTime(2026, 9, 6, 9, 30))],
        ),
        now: DateTime(2026, 9, 6, 13, 0),
      );
      expect(scanned.any((s) => s.ruleType == CoachRuleType.essentialStumble), isFalse);
    });

    test('Stabilizer: 4h-window SD under keep-it-steady tier', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, minWindowSdYesterday: 24),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.stabilizer), isTrue);

      final shaky = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, minWindowSdYesterday: 45),
      );
      expect(shaky.any((s) => s.ruleType == CoachRuleType.stabilizer), isFalse);
    });

    test('Dawn Effect: high dawn readings three days running', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, dawnHighStreak: 3),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.dawnEffect), isTrue);

      final twoDays = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, dawnHighStreak: 2),
      );
      expect(twoDays.any((s) => s.ruleType == CoachRuleType.dawnEffect), isFalse);
    });

    test('Milestone Near: TIR one point below target', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, tirPct: 0.67),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.milestoneNear), isTrue);

      final atTarget = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, tirPct: 0.72),
      );
      expect(atTarget.any((s) => s.ruleType == CoachRuleType.milestoneNear), isFalse);
    });

    test('Hydration Hero: under 4 glasses by 4PM', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, waterGlassesToday: 2),
        now: DateTime(2026, 9, 6, 17, 0),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.hydrationHero), isTrue);

      final hydrated = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, waterGlassesToday: 4),
        now: DateTime(2026, 9, 6, 17, 0),
      );
      expect(hydrated.any((s) => s.ruleType == CoachRuleType.hydrationHero), isFalse);

      final tooEarly = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, waterGlassesToday: 2),
        now: DateTime(2026, 9, 6, 14, 0),
      );
      expect(tooEarly.any((s) => s.ruleType == CoachRuleType.hydrationHero), isFalse);
    });

    test('Rotator Nudge: same site past the rotation window', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, sameSiteForDays: 7),
      );
      expect(signals.any((s) => s.ruleType == CoachRuleType.rotatorNudge), isTrue);

      final fresh = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(today: today, sameSiteForDays: 6),
      );
      expect(fresh.any((s) => s.ruleType == CoachRuleType.rotatorNudge), isFalse);
    });

    test('Deterministic priority ordering: survival > firstResponder > welcomeBack', () {
      final signals = CoachEngine.evaluateAll(
        input: CoachGlucoseInput(
          today: today,
          isSick: true,
          lastActiveDate: today.subtractDays(3),
          recoveriesYesterday: 1,
          minWindowSdYesterday: 20,
          tirPct: 0.66,
          sameSiteForDays: 8,
        ),
      );
      expect(signals[0].ruleType, equals(CoachRuleType.survivalMode));
      expect(signals[1].ruleType, equals(CoachRuleType.firstResponder));
      expect(signals.last.ruleType, equals(CoachRuleType.welcomeBack));
    });

    test('Cooldown constants honor the documented values', () {
      expect(CoachTunables.coachStabilizerCooldown, equals(3));
      expect(CoachTunables.coachFirstResponderCooldown, equals(2));
      expect(CoachTunables.coachRotatorCooldown, equals(30));
      expect(CoachTunables.coachPrebolusCooldown, equals(1));
      expect(CoachTunables.coachSurvivalCooldown, equals(90));
      expect(CoachTunables.coachDawnCooldown, equals(14));
      expect(CoachTunables.coachHydrationCooldown, equals(1));
      expect(CoachTunables.coachEssentialStumbleCooldown, equals(3));
      expect(CoachTunables.coachMilestoneCooldown, equals(7));
      expect(CoachTunables.coachWelcomeCooldown, equals(60));
    });
  });
}