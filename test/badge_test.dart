import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glucose_guild/app/providers/badges_provider.dart';
import 'package:glucose_guild/data/db/database.dart';
import 'package:glucose_guild/domain/engine/badges.dart';
import 'package:glucose_guild/domain/engine/schedule_rule.dart';
import 'package:glucose_guild/domain/model/diabetes_context.dart';
import 'package:glucose_guild/domain/model/models.dart';
import 'package:glucose_guild/ui/screens/badges_screen.dart';
import 'package:glucose_guild/ui/theme/app_theme.dart';
import 'package:glucose_guild/ui/theme/tokens.dart';
import 'package:glucose_guild/ui/widgets/badge_tile.dart';

ProfileData _profile({int? calling, bool isSick = false}) => ProfileData(
      id: 1,
      calling: calling,
      resetMinute: 0,
      weekStart: 1,
      themeMode: 0,
      accent: 'frost',
      digestEnabled: true,
      digestMinute: 540,
      hasGraceToken: true,
      isSick: isSick,
    );

String _dateTime(String date, int hour, [int minute = 30]) =>
    '${date}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

/// A single glucose log row with a structured context; scans carry a reading.
CompletionData _entry(
  String date,
  GlucoseContext ctx, {
  String? questId,
  int hour = 9,
  int minute = 30,
  int reading = 120,
  String? note,
}) {
  return CompletionData(
    id: '${ctx.type.name}_${date}_$hour${ctx.type == GlucoseLogType.scan ? '_$reading' : ''}',
    questId: questId ?? 'q_${ctx.type.name}',
    localDate: date,
    value: 1,
    timezone: 'UTC',
    createdAt: DateTime.parse(_dateTime(date, hour, minute)),
    numericValue: ctx.isScan ? reading.toDouble() : null,
    contextJson: ctx.toDb(),
    note: note,
  );
}

Map<String, BadgeStatus> _evaluate({
  List<CompletionData>? completions,
  List<QuestData> quests = const [],
  List<GoalData> goals = const [],
  List<XpEventData> xpEvents = const [],
  ProfileData? profile,
  Map<String, int> questMaxStreaks = const {},
  Set<String> seenBadgeKeys = const {},
}) {
  final result = BadgeEngine.evaluate(
    completions: completions ?? const [],
    quests: quests,
    goals: goals,
    xpEvents: xpEvents,
    streakRepairs: const [],
    profile: profile ?? _profile(),
    questMaxStreaks: questMaxStreaks,
    perfectDays: const {},
    seenBadgeKeys: seenBadgeKeys,
  );
  return {for (final b in result) b.definition.key: b};
}

QuestData _quest(String id, String title, {int? domain}) {
  return QuestData(
    id: id,
    title: title,
    rule: const DailyEveryDayRule(),
    targetType: 0,
    targetValue: 1,
    difficulty: 1,
    essential: false,
    domain: domain,
    createdAt: DateTime(2026, 1, 1),
  );
}

String _date(int offset) {
  final d = DateTime(2026, 8, 1).add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

List<XpEventData> _xp(int total, {int type = 0}) {
  final events = <XpEventData>[];
  var remaining = total;
  while (remaining > 0) {
    final amount = remaining >= 10000 ? 10000 : remaining;
    events.add(XpEventData(
      id: 'e${events.length}',
      type: type,
      amount: amount,
      localDate: '2026-01-31',
      createdAt: DateTime(2026, 1, 31 + events.length),
      ref: 'test:$type:${events.length}',
    ));
    remaining -= amount;
  }
  return events;
}

void main() {
  group('P9b: 50-Badge Registry & Evaluation Suite', () {
    test('Registry Integrity: exactly 50 badges with unique keys and valid fields', () {
      expect(BadgeEngine.catalog.length, equals(50));

      final keys = <String>{};
      for (final badge in BadgeEngine.catalog) {
        expect(keys.contains(badge.key), isFalse, reason: 'Duplicate badge key: ${badge.key}');
        keys.add(badge.key);
        expect(badge.title.isNotEmpty, isTrue);
        expect(badge.flavor.isNotEmpty, isTrue);
        expect(badge.requirement.isNotEmpty, isTrue);
      }

      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.journey).length, equals(6));
      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.streaks).length, equals(7));
      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.perfection).length, equals(6));
      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.goals).length, equals(3));
      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.economy).length, equals(4));
      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.rarities).length, equals(6));
      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.calling).length, equals(10));
      expect(BadgeEngine.catalog.where((b) => b.category == BadgeCategory.sealed).length, equals(8));
      expect(BadgeEngine.catalog.where((b) => b.sealed).length, equals(8));
    });

    test('Docs parity: all 20 documented badge IDs exist', () {
      const docKeys = {
        'b_first_responder_1',
        'b_chef_kiss_1',
        'b_chef_kiss_2',
        'b_pizza_gauntlet_1',
        'b_smooth_operator',
        'b_zentient',
        'b_rotator_1',
        'b_timetraveler_1',
        'b_survivor',
        'b_hydration_1',
        'b_hydration_2',
        'b_streak_7',
        'b_streak_30',
        'b_tir_70',
        'b_tir_80',
        'b_data_hoarder',
        'b_insulin_100',
        'b_perfect_day',
        'b_grace_token',
        'b_endo_visit',
      };
      final catalogKeys = BadgeEngine.catalog.map((b) => b.key).toSet();
      expect(docKeys.difference(catalogKeys), isEmpty);
    });

    test('Journey: First Reading and Century of Scans derive from scan totals', () {
      final completions = [
        for (var i = 0; i < 100; i++)
          _entry('2026-08-${(i % 20 + 1).toString().padLeft(2, '0')}', GlucoseContext.cgmScan, reading: 120),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_first_scan']!.isEarned, isTrue);
      expect(badges['b_scan_100']!.isEarned, isTrue);
      expect(badges['b_scan_100']!.currentValue, equals(100));
      expect(badges['b_data_hoarder']!.isEarned, isFalse);
    });

    test('Journey: Endo Briefing quest completion unlocks The Prepared', () {
      final quest = _quest('q_endo', 'Endo Briefing');
      final badges = _evaluate(
        quests: [quest],
        completions: [_entry('2026-08-01', GlucoseContext.cgmScan, questId: 'q_endo', reading: 120)],
      );
      expect(badges['b_endo_visit']!.isEarned, isTrue);
    });

    test('Streaks: 7-day scan streak earns Week Warrior, not Monthly Sentinel', () {
      final completions = [
        for (var i = 0; i < 7; i++)
          _entry('2026-08-${(i + 1).toString().padLeft(2, '0')}', GlucoseContext.cgmScan, reading: 120),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_streak_7']!.isEarned, isTrue);
      expect(badges['b_streak_30']!.isEarned, isFalse);
    });

    test('Streaks: 5 fast recoveries earn First Responder', () {
      final completions = <CompletionData>[];
      for (var i = 1; i <= 5; i++) {
        final date = '2026-08-${i.toString().padLeft(2, '0')}';
        completions.add(_entry(date, GlucoseContext.cgmScan, hour: 10, minute: 10, reading: 190));
        completions.add(_entry(date, const GlucoseContext(type: GlucoseLogType.insulin), hour: 10, minute: 30));
      }
      final badges = _evaluate(completions: completions);
      expect(badges['b_first_responder_1']!.isEarned, isTrue);
      expect(badges['b_first_responder_1']!.currentValue, equals(5));
    });

    test('Perfection: 10 pre-boluses earn Chef\'s Kiss, 50 earns Master Chef', () {
      final t10 = <CompletionData>[];
      final t50 = <CompletionData>[];
      for (var i = 1; i <= 50; i++) {
        final date = '2026-08-${(i % 28 + 1).toString().padLeft(2, '0')}';
        final insulin = _entry(date, const GlucoseContext(type: GlucoseLogType.insulin), hour: 11, minute: 50, questId: 'q_bolus');
        final meal = _entry(date, const GlucoseContext(type: GlucoseLogType.meal), hour: 12, questId: 'q_bolus');
        if (i <= 10) {
          t10.add(insulin);
          t10.add(meal);
        }
        t50.add(insulin);
        t50.add(meal);
      }
      final b10 = _evaluate(completions: t10);
      expect(b10['b_chef_kiss_1']!.isEarned, isTrue);
      expect(b10['b_chef_kiss_2']!.isEarned, isFalse);

      final b50 = _evaluate(completions: t50);
      expect(b50['b_chef_kiss_2']!.isEarned, isTrue);
    });

    test('Perfection: full in-range day earns Perfect Day, but not Flawless Week alone', () {
      final completions = [
        for (var i = 0; i < 5; i++)
          _entry('2026-08-01', GlucoseContext.cgmScan, hour: 8 + i, reading: 120),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_perfect_day']!.isEarned, isTrue);
      expect(badges['b_perfect_full_week']!.isEarned, isFalse);
    });

    test('Goals: 30-day water run earns Aqua Adept; 100 total earns The River', () {
      final completions = <CompletionData>[];
      for (var d = 0; d < 40; d++) {
        final date = _date(d);
        for (var g = 0; g < 4; g++) {
          completions.add(_entry(date, const GlucoseContext(type: GlucoseLogType.water)));
        }
      }
      final badges = _evaluate(completions: completions);
      expect(badges['b_hydration_1']!.isEarned, isTrue);
      expect(badges['b_hydration_2']!.isEarned, isFalse);
    });

    test('Goals: river at 100 hydrated days; goal completion unlocks First Frontier', () {
      final completions = <CompletionData>[];
      for (var d = 0; d < 100; d++) {
        final date = _date(d);
        for (var g = 0; g < 4; g++) {
          completions.add(_entry(date, const GlucoseContext(type: GlucoseLogType.water)));
        }
      }
      final badges = _evaluate(completions: completions);
      expect(badges['b_hydration_2']!.isEarned, isTrue);

      final goal = GoalData(
        id: 'g_1',
        title: 'Stabilize mornings',
        emoji: '🌅',
        createdAt: DateTime(2026, 1, 1),
        completedAt: DateTime(2026, 3, 1),
      );
      final withGoal = _evaluate(goals: [goal]);
      expect(withGoal['b_goal_1']!.isEarned, isTrue);
    });

    test('Economy: 500 scans earn Data Hoarder; coins accrue toward The Coiner', () {
      final completions = [
        for (var i = 0; i < 500; i++)
          _entry('2026-08-${(i % 28 + 1).toString().padLeft(2, '0')}', GlucoseContext.cgmScan, reading: 120),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_data_hoarder']!.isEarned, isTrue);
      expect(badges['b_coin_bank']!.isEarned, isTrue); // 500 * 5 coins = 2500
    });

    test('Economy: 7 unique sites earn Rotator Cuff; 100 doses earn The Chemist', () {
      final completions = <CompletionData>[
        for (final (i, site) in InsulinSite.values.indexed)
          _entry('2026-08-${(i + 1).toString().padLeft(2, '0')}',
              GlucoseContext(type: GlucoseLogType.site, site: site)),
        for (var i = 0; i < 100; i++)
          _entry('2026-08-${(i % 28 + 1).toString().padLeft(2, '0')}',
              const GlucoseContext(type: GlucoseLogType.insulin)),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_rotator_1']!.isEarned, isTrue);
      expect(badges['b_rotator_1']!.currentValue, equals(7));
      expect(badges['b_insulin_100']!.isEarned, isTrue);
    });

    test('Rarities: seasonal and hour badges unlock on exact windows', () {
      final badges = _evaluate(completions: [
        _entry('2026-01-01', GlucoseContext.cgmScan, hour: 9, reading: 120),
        _entry('2024-02-29', GlucoseContext.cgmScan, hour: 9, reading: 120),
        _entry('2026-08-01', GlucoseContext.cgmScan, hour: 3, reading: 120),
        _entry('2026-08-01', const GlucoseContext(type: GlucoseLogType.insulin), hour: 2),
      ]);
      expect(badges['b_new_years_scan']!.isEarned, isTrue);
      expect(badges['b_leap_day']!.isEarned, isTrue);
      expect(badges['b_guardian_dark']!.isEarned, isTrue);
      expect(badges['b_midnight_oil']!.isEarned, isTrue);
    });

    test('Rarities: 20 mood+scan days earn Zentient; day-365 span earns Circle of Seasons', () {
      final completions = <CompletionData>[];
      for (var d = 1; d <= 20; d++) {
        final date = '2026-08-${(d % 28 + 1).toString().padLeft(2, '0')}';
        completions.add(_entry(date, GlucoseContext.cgmScan, hour: 12, reading: 120));
        completions.add(_entry(date, const GlucoseContext(type: GlucoseLogType.mood)));
      }
      completions.add(_entry('2027-08-02', GlucoseContext.cgmScan, reading: 120));
      final badges = _evaluate(completions: completions);
      expect(badges['b_zentient']!.isEarned, isTrue);
      expect(badges['b_zentient']!.currentValue, equals(20));
      expect(badges['b_year_365']!.isEarned, isTrue);
    });

    test('Calling: a week at 70% TIR earns Stabilizer Initiate; 80% does not', () {
      final completions = <CompletionData>[
        // Mon 2026-08-03 .. Sat 2026-08-08, 14 scans: 10 in range, 4 high.
        _entry('2026-08-03', GlucoseContext.cgmScan, hour: 9, reading: 130),
        _entry('2026-08-03', GlucoseContext.cgmScan, hour: 12, reading: 190),
        _entry('2026-08-04', GlucoseContext.cgmScan, hour: 9, reading: 140),
        _entry('2026-08-04', GlucoseContext.cgmScan, hour: 12, reading: 190),
        _entry('2026-08-05', GlucoseContext.cgmScan, hour: 9, reading: 150),
        _entry('2026-08-05', GlucoseContext.cgmScan, hour: 12, reading: 190),
        _entry('2026-08-06', GlucoseContext.cgmScan, hour: 9, reading: 160),
        _entry('2026-08-06', GlucoseContext.cgmScan, hour: 12, reading: 190),
        _entry('2026-08-07', GlucoseContext.cgmScan, hour: 9, reading: 120),
        _entry('2026-08-07', GlucoseContext.cgmScan, hour: 12, reading: 125),
        _entry('2026-08-07', GlucoseContext.cgmScan, hour: 18, reading: 130),
        _entry('2026-08-08', GlucoseContext.cgmScan, hour: 9, reading: 115),
        _entry('2026-08-08', GlucoseContext.cgmScan, hour: 12, reading: 128),
        _entry('2026-08-08', GlucoseContext.cgmScan, hour: 18, reading: 132),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_tir_70']!.isEarned, isTrue);
      expect(badges['b_tir_80']!.isEarned, isFalse);
    });

    test('Calling: Time-Traveler needs a ≥1% week-over-week TIR improvement', () {
      final completions = <CompletionData>[
        // Week 1 (Aug 3-6): 8 scans, 4 in range -> 50%
        for (var d = 3; d <= 6; d++)
          for (final r in [120, 190])
            _entry('2026-08-${d.toString().padLeft(2, '0')}',
                GlucoseContext.cgmScan, hour: r == 190 ? 12 : 9, reading: r),
        // Week 2 (Aug 10-13): 8 scans all in range -> 100%
        for (var d = 10; d <= 13; d++)
          for (final r in [120, 130])
            _entry('2026-08-${d.toString().padLeft(2, '0')}',
                GlucoseContext.cgmScan, hour: r == 130 ? 12 : 9, reading: r),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_timetraveler_1']!.isEarned, isTrue);
    });

    test('Calling: Pizza Survivor needs the Pizza Gauntlet dimmed in 3 weeks', () {
      final quest = _quest('q_pizza', 'Pizza Gauntlet');
      final badges = _evaluate(
        quests: [quest],
        completions: [
          _entry('2026-08-03', GlucoseContext.cgmScan, questId: 'q_pizza', reading: 120),
          _entry('2026-08-10', GlucoseContext.cgmScan, questId: 'q_pizza', reading: 120),
          _entry('2026-08-17', GlucoseContext.cgmScan, questId: 'q_pizza', reading: 120),
        ],
      );
      expect(badges['b_pizza_gauntlet_1']!.isEarned, isTrue);
      expect(badges['b_pizza_gauntlet_1']!.currentValue, equals(3));
    });

    test('Calling trials: strictly gated by pledged calling and per-domain metric', () {
      final completions = <CompletionData>[];
      for (var i = 0; i < 30; i++) {
        completions.add(_entry(_date(i), GlucoseContext.cgmScan, reading: 120));
      }
      final warrior = _evaluate(
        completions: completions,
        profile: _profile(calling: CallingDomain.warrior.index),
      );
      expect(warrior['b_stabilizer_trial']!.isEarned, isTrue);
      expect(warrior['b_stabilizer_trial']!.isEligible, isTrue);

      final sage = _evaluate(
        completions: completions,
        profile: _profile(calling: CallingDomain.sage.index),
      );
      expect(sage['b_stabilizer_trial']!.isEarned, isFalse);
      expect(sage['b_stabilizer_trial']!.isEligible, isFalse);
    });

    test('Calling: Guild Sentinel requires 10,000 non-coin XP', () {
      final lowXp = _evaluate(xpEvents: _xp(9000), completions: []);
      expect(lowXp['b_guild_sentinel']!.isEarned, isFalse);

      final coinFlood = _evaluate(xpEvents: _xp(50000, type: 6), completions: []);
      expect(coinFlood['b_guild_sentinel']!.isEarned, isFalse);

      final highXp = _evaluate(xpEvents: [..._xp(10000), ..._xp(50000, type: 6)], completions: []);
      expect(highXp['b_guild_sentinel']!.isEarned, isTrue);
      expect(highXp['b_guild_sentinel']!.currentValue, equals(10000));
    });

    test('Sealed: Grace Token usage unlocks The Forgiven', () {
      final badges = _evaluate(completions: [
        _entry('2026-08-01', GlucoseContext.cgmScan, reading: 120, note: 'grace:token auto-completed'),
      ]);
      expect(badges['b_grace_token']!.isEarned, isTrue);
    });

    test('Sealed: Survivor needs an active sick day with a clean log', () {
      final completions = [
        for (var i = 0; i < 4; i++)
          _entry('2026-08-01', GlucoseContext.cgmScan, hour: 8 + i, reading: 150),
      ];
      final sick = _evaluate(completions: completions, profile: _profile(isSick: true));
      expect(sick['b_survivor']!.isEarned, isTrue);

      final healthy = _evaluate(completions: completions, profile: _profile(isSick: false));
      expect(healthy['b_survivor']!.isEarned, isFalse);
    });

    test('Sealed: 25 fingerstick scans earn The Slow Roll', () {
      final completions = [
        for (var i = 0; i < 25; i++)
          _entry('2026-08-${(i % 28 + 1).toString().padLeft(2, '0')}',
              GlucoseContext.fingerstick, reading: 120),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_slow_roll']!.isEarned, isTrue);
      expect(badges['b_slow_roll']!.currentValue, equals(25));
    });

    test('Sealed: three nights with a 02:00-05:00 scan earn Night Shift', () {
      final badges = _evaluate(completions: [
        _entry('2026-08-01', GlucoseContext.cgmScan, hour: 3, reading: 110),
        _entry('2026-08-02', GlucoseContext.cgmScan, hour: 4, reading: 115),
        _entry('2026-08-05', GlucoseContext.cgmScan, hour: 2, reading: 120),
      ]);
      expect(badges['b_all_nighter']!.isEarned, isTrue);
    });

    test('Sealed: 12 logs in one day earn Marathon Day; 14 clean days perfect Perfectionist', () {
      final completions = <CompletionData>[
        for (var i = 0; i < 12; i++)
          _entry('2026-08-01', GlucoseContext.cgmScan, hour: 7 + (i % 12), reading: 120),
        for (var d = 1; d <= 14; d++)
          _entry('2026-08-${(d + 14).toString().padLeft(2, '0')}',
              GlucoseContext.cgmScan, hour: 9, reading: 120),
      ];
      final badges = _evaluate(completions: completions);
      expect(badges['b_marathon_day']!.isEarned, isTrue);
      expect(badges['b_perfectionist']!.isEarned, isFalse);
    });

    test('Seen badges persist regardless of current progress', () {
      final badges = _evaluate(seenBadgeKeys: {'b_streak_365'});
      expect(badges['b_streak_365']!.isEarned, isTrue);
      expect(badges['b_streak_30']!.isEarned, isFalse);
    });

    test('Consecutive no-low days climb the no-hypo ladder', () {
      final completions = <CompletionData>[];
      for (var d = 1; d <= 30; d++) {
        final date = '2026-09-${d.toString().padLeft(2, '0')}';
        completions.add(_entry(date, GlucoseContext.cgmScan, hour: 9, reading: 120));
        completions.add(_entry(date, GlucoseContext.cgmScan, hour: 18, reading: 130));
      }
      final badges = _evaluate(completions: completions);
      expect(badges['b_no_hypo_30']!.isEarned, isTrue);
      expect(badges['b_perfectionist']!.isEarned, isTrue);
    });
  });

  group('Badges UI Widget Tests', () {
    testWidgets('BadgeTile renders locked and earned states', (tester) async {
      final badgeDef = BadgeEngine.catalog.first;

      final lockedBadge = BadgeStatus(definition: badgeDef, isEarned: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(isDark: true, accentTheme: AccentTheme.frost),
          home: Scaffold(
            body: BadgeTile(badge: lockedBadge),
          ),
        ),
      );
      expect(find.byType(BadgeTile), findsOneWidget);

      final earnedBadge = BadgeStatus(definition: badgeDef, isEarned: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(isDark: true, accentTheme: AccentTheme.frost),
          home: Scaffold(
            body: BadgeTile(badge: earnedBadge),
          ),
        ),
      );
      expect(find.byType(BadgeTile), findsOneWidget);
    });

    testWidgets('BadgesScreen renders categories and tiles', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            badgesStateProvider.overrideWithValue(
              AsyncData(
                BadgesScreenState(
                  allBadges: BadgeEngine.catalog.map((b) => BadgeStatus(definition: b, isEarned: false)).toList(),
                  earnedCount: 5,
                  totalCount: 50,
                  groupedByCategory: {
                    for (final cat in BadgeCategory.values)
                      cat: BadgeEngine.catalog
                          .where((b) => b.category == cat)
                          .map((b) => BadgeStatus(definition: b, isEarned: false))
                          .toList(),
                  },
                  sealedCount: 8,
                  revealedSealedCount: 0,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.buildTheme(isDark: true, accentTheme: AccentTheme.frost),
            home: const BadgesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('BADGES'), findsOneWidget);
      expect(find.text('5/50'), findsOneWidget);
      expect(find.text('JOURNEY'), findsOneWidget);
      expect(find.text('STREAKS'), findsOneWidget);
    });
  });
}