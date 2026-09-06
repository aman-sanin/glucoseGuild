import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../domain/model/models.dart';
import '../theme/tokens.dart';
import '../widgets/burst_widget.dart';
import '../widgets/sigil_widget.dart';

/// Launch splash. Required medical disclaimer (§9 of docs/idea.md):
/// the Endo-consult line is always visible before the app shell loads.
class SplashScreen extends StatefulWidget {
  final Duration duration;

  const SplashScreen({super.key, this.duration = const Duration(milliseconds: 1600)});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _advance);
  }

  void _advance() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go('/today');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              BurstWidget(
                size: 140,
                child: SigilWidget(
                  domain: CallingDomain.warrior,
                  size: 48,
                  color: tokens.hero,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'GLUCOSE GUILD',
                textAlign: TextAlign.center,
                style: tokens.display(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gamified glucose logging. Effort coins, not outcomes.',
                textAlign: TextAlign.center,
                style: tokens.body(fontSize: 14, color: tokens.textSecondary),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.lock,
                      size: 18, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text(
                    '100% LOCAL · NO ACCOUNTS · YOU OWN YOUR DATA',
                    style: tokens.monoText(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: tokens.accent,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // REQUIRED disclaimer — always visible.
              Text(
                'Always consult your Endo before changing insulin doses. '
                'This app is for motivation and logging only.',
                textAlign: TextAlign.center,
                style: tokens.body(
                  fontSize: 11,
                  color: tokens.textSecondary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}