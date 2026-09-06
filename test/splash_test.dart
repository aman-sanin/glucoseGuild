import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:glucose_guild/ui/screens/splash_screen.dart';
import 'package:glucose_guild/ui/theme/app_theme.dart';
import 'package:glucose_guild/ui/theme/tokens.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('shows the required Endo disclaimer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.buildTheme(isDark: true, accentTheme: AccentTheme.frost),
            home: const SplashScreen(duration: Duration(days: 365)),
          ),
        ),
      );

      expect(find.text('GLUCOSE GUILD'), findsOneWidget);
      expect(
        find.textContaining('Always consult your Endo before changing insulin doses.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('This app is for motivation and logging only.'),
        findsOneWidget,
      );
      expect(find.textContaining('100% LOCAL'), findsOneWidget);
    });

    testWidgets('advances to /today after the duration elapses', (tester) async {
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/today',
            builder: (context, state) => const Scaffold(body: Text('TODAY')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.buildTheme(isDark: true, accentTheme: AccentTheme.frost),
            routerConfig: router,
          ),
        ),
      );
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
    });
  });
}