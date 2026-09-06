import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glucose_guild/app/providers/insights_provider.dart';
import 'package:glucose_guild/app/providers/profile_provider.dart';
import 'package:glucose_guild/app/providers/today_provider.dart';
import 'package:glucose_guild/data/db/database.dart';
import 'package:glucose_guild/domain/model/diabetes_context.dart';
import 'package:glucose_guild/domain/model/glucose_chart_point.dart';
import 'package:glucose_guild/domain/model/models.dart';
import 'package:glucose_guild/ui/theme/app_theme.dart';
import 'package:glucose_guild/ui/theme/tokens.dart';
import 'package:glucose_guild/ui/widgets/cgm_line_chart.dart';
import 'package:glucose_guild/ui/widgets/cgm_pet_widget.dart';
import 'package:glucose_guild/ui/widgets/glucose_dashboard_header.dart';

String _ts(String date, int hour, [int minute = 0]) =>
    '${date}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

CompletionData _entry(
  String date,
  GlucoseContext ctx, {
  int hour = 9,
  int minute = 30,
  int reading = 120,
  String? loggedAt,
}) {
  return CompletionData(
    id: '${ctx.type.name}_${date}_$hour${ctx.isScan ? '_$reading' : ''}',
    questId: 'q_${ctx.type.name}',
    localDate: date,
    value: 1,
    timezone: 'UTC',
    createdAt: DateTime.parse(_ts(date, hour, minute)),
    loggedAt: loggedAt != null ? DateTime.parse(loggedAt) : null,
    numericValue: ctx.isScan ? reading.toDouble() : null,
    contextJson: ctx.toDb(),
  );
}

void main() {
  group('P12 Glucose Dashboard — buildGlucoseSeries', () {
    test('includes only scans inside the window, sorted chronologically', () {
      final completions = [
        _entry('2026-09-01', GlucoseContext.cgmScan, hour: 8, reading: 110),
        _entry('2026-09-01', const GlucoseContext(type: GlucoseLogType.water), hour: 9),
        _entry('2026-09-02', GlucoseContext.fingerstick, hour: 20, reading: 145),
        _entry('2026-09-03', GlucoseContext.cgmScan, hour: 21, reading: 160),
        _entry('2026-07-01', GlucoseContext.cgmScan, hour: 8, reading: 100),
      ];

      final series = buildGlucoseSeries(
        completions: completions,
        today: LocalDate(2026, 9, 3),
        windowDays: 30,
      );

      // 2026-07-01 falls outside the window; water log & non-scan excluded.
      expect(series.length, equals(3));
      expect(series.first.value, equals(110));
      expect(series.last.value, equals(160));
    });

    test('falls back to createdAt when loggedAt is missing', () {
      final completions = [
        _entry('2026-09-02', GlucoseContext.cgmScan, hour: 10, loggedAt: null),
      ];
      final series = buildGlucoseSeries(
        completions: completions,
        today: LocalDate(2026, 9, 3),
        windowDays: 30,
      );
      expect(series.single.value, equals(120));
    });
  });

  group('P12 Glucose Dashboard — cgmPetMoodFor', () {
    test('sleeping without data this day', () {
      expect(
        cgmPetMoodFor(hasData: false, latestValue: null, sd: 0, hadHypo: false),
        CgmPetMood.sleeping,
      );
    });

    test('lowWatch below the lower bound', () {
      expect(
        cgmPetMoodFor(hasData: true, latestValue: 62, sd: 12, hadHypo: true),
        CgmPetMood.lowWatch,
      );
    });

    test('highAlert above 180 (neutral, not alarm-red logic)', () {
      expect(
        cgmPetMoodFor(hasData: true, latestValue: 230, sd: 25, hadHypo: false),
        CgmPetMood.highAlert,
      );
    });

    test('serene when in range and low volatility', () {
      expect(
        cgmPetMoodFor(hasData: true, latestValue: 120, sd: 18, hadHypo: false),
        CgmPetMood.serene,
      );
    });

    test('vigilant when in range but volatile', () {
      expect(
        cgmPetMoodFor(hasData: true, latestValue: 140, sd: 42, hadHypo: false),
        CgmPetMood.vigilant,
      );
    });
  });

  group('P12 Glucose Dashboard — Widgets', () {
    testWidgets('CGM line chart renders empty and populated states', (tester) async {
      await tester.pumpWidget(
        _wrap(const CgmLineChart(points: [])),
      );
      expect(find.textContaining('No glucose scans yet'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(CgmLineChart(points: [
          GlucoseChartPoint(time: DateTime(2026, 9, 1, 8), value: 110),
          GlucoseChartPoint(time: DateTime(2026, 9, 1, 12), value: 160),
          GlucoseChartPoint(time: DateTime(2026, 9, 2, 8), value: 90),
        ])),
      );
      expect(find.byType(CgmLineChart), findsOneWidget);
    });

    testWidgets('GlucoseDashboardHeader renders with a seeded scan', (tester) async {
      final scan = _entry('2026-09-03', GlucoseContext.cgmScan, hour: 8, reading: 128);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveLocalDateProvider.overrideWithValue(LocalDate(2026, 9, 3)),
            todayGlucoseCompletionsProvider.overrideWith((ref) => Stream.value([scan])),
            profileStreamProvider.overrideWith((ref) => Stream.value(_profile())),
          ],
          child: MaterialApp(
            theme: AppTheme.buildTheme(isDark: true, accentTheme: AccentTheme.frost),
            home: const Scaffold(body: GlucoseDashboardHeader()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('GLUCOSE DASHBOARD'), findsOneWidget);
      expect(find.textContaining('LATEST 128 mg/dL'), findsOneWidget);
      expect(find.text('1 scan today'), findsOneWidget);
      expect(find.textContaining('TIR TODAY'), findsOneWidget);
    });
  });
}

ProfileData _profile() => ProfileData(
      id: 1,
      calling: null,
      resetMinute: 0,
      weekStart: 1,
      themeMode: 0,
      accent: 'frost',
      digestEnabled: true,
      digestMinute: 540,
      hasGraceToken: true,
      isSick: false,
    );

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.buildTheme(isDark: true, accentTheme: AccentTheme.frost),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}