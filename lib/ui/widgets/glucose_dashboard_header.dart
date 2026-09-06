import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../app/providers/profile_provider.dart';
import '../../app/providers/today_provider.dart';
import '../../data/db/database.dart';
import '../../domain/constants/tunables.dart';
import '../../domain/engine/glucose_settlement.dart';
import '../../domain/model/diabetes_context.dart';
import '../theme/tokens.dart';
import '../widgets/cgm_pet_widget.dart';
import '../widgets/completion_ring.dart';

/// The "Glucose Dashboard" header: CGM pet + Live TIR ring + Sea Level (SD)
/// indicator. Pinned to the top of TodayScreen as the docs (§7) specify.
class GlucoseDashboardHeader extends ConsumerWidget {
  const GlucoseDashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final today = ref.watch(effectiveLocalDateProvider);
    final todayAsync = ref.watch(todayGlucoseCompletionsProvider);
    final profileAsync = ref.watch(profileStreamProvider);

    final completions = todayAsync.value ?? const <CompletionData>[];
    final isSick = profileAsync.value?.isSick ?? false;

    final day = GlucoseSettlementEngine.settleDay(
      date: today,
      completions: completions,
      isSick: isSick,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.tonal,
        border: Border.all(color: tokens.lineRule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CgmPetWidget(
                mood: _moodFor(day, completions),
                size: 72,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GLUCOSE DASHBOARD',
                          style: tokens.monoText(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: tokens.accent,
                          ),
                        ),
                        if (isSick)
                          _SickBadge(tokens: tokens),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _LatestReading(tokens: tokens, completions: completions),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _TirRing(tokens: tokens, ratio: day.tir),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SeaLevel(
                            tokens: tokens,
                            sd: day.sd,
                            minWindowSd: day.minWindowSd,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  CgmPetMood _moodFor(GlucoseDayResult day, List<CompletionData> completions) {
    final scans = completions
        .where((c) => GlucoseContext.fromDb(c.contextJson).isScan && c.numericValue != null)
        .toList()
      ..sort((a, b) =>
          (b.loggedAt ?? b.createdAt).compareTo(a.loggedAt ?? a.createdAt));

    return cgmPetMoodFor(
      hasData: day.hasData,
      latestValue: scans.isEmpty ? null : scans.first.numericValue,
      sd: day.sd,
      hadHypo: day.hadHypo,
    );
  }
}

class _LatestReading extends StatelessWidget {
  final AppTokens tokens;
  final List<CompletionData> completions;

  const _LatestReading({required this.tokens, required this.completions});

  @override
  Widget build(BuildContext context) {
    final scans = completions
        .where((c) => GlucoseContext.fromDb(c.contextJson).isScan && c.numericValue != null)
        .toList()
      ..sort((a, b) =>
          (b.loggedAt ?? b.createdAt).compareTo(a.loggedAt ?? a.createdAt));

    if (scans.isEmpty) {
      return Text(
        'No scans logged yet. Settle your first scan to wake the CGM pet.',
        style: tokens.body(fontSize: 12, color: tokens.textSecondary),
      );
    }

    final latest = scans.first;
    final value = latest.numericValue!;
    final inRange = value >= GlucoseTunables.targetLow && value <= GlucoseTunables.targetHigh;

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          inRange ? Symbols.water_drop : Symbols.warning,
          size: 16,
          color: inRange ? tokens.hero : tokens.accent,
        ),
        Text(
          'LATEST ${value.round()} mg/dL',
          style: tokens.monoText(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: inRange ? tokens.textPrimary : tokens.accent,
          ),
        ),
        Text(
          _scansTodayLabel(scans.length),
          style: tokens.monoText(fontSize: 10, color: tokens.textSecondary),
        ),
      ],
    );
  }

  static String _scansTodayLabel(int count) => '$count scan${count == 1 ? '' : 's'} today';
}

class _TirRing extends StatelessWidget {
  final AppTokens tokens;
  final double ratio;

  const _TirRing({required this.tokens, required this.ratio});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CompletionRing(progress: ratio, size: 42, strokeWidth: 4),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(ratio * 100).round()}%',
                  style: tokens.title(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  'TIR TODAY',
                  style: tokens.monoText(fontSize: 9, color: tokens.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SeaLevel extends StatelessWidget {
  final AppTokens tokens;
  final double sd;
  final double minWindowSd;

  const _SeaLevel({required this.tokens, required this.sd, required this.minWindowSd});

  @override
  Widget build(BuildContext context) {
    final calmSeas = minWindowSd < GlucoseTunables.sdSilver && sd > 0;
    final title = sd == 0 ? 'SEA LEVEL' : 'SEA LEVEL ${sd.round()} SD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: calmSeas ? tokens.hero.withOpacity(0.12) : tokens.bg,
        border: Border.all(
          color: calmSeas ? tokens.hero : tokens.lineRule,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: tokens.monoText(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: calmSeas ? tokens.hero : tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            calmSeas ? 'Calm seas — steady 4h window' : 'Volatility readout',
            style: tokens.body(fontSize: 10, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SickBadge extends StatelessWidget {
  final AppTokens tokens;

  const _SickBadge({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.accent.withOpacity(0.15),
        border: Border.all(color: tokens.accent, width: 1),
      ),
      child: Text(
        'SURVIVAL MODE',
        style: tokens.monoText(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: tokens.accent,
        ),
      ),
    );
  }
}