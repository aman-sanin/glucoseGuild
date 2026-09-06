import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../app/providers/database_provider.dart';
import '../../app/providers/profile_provider.dart';
import '../../domain/model/models.dart';
import '../../domain/templates.dart';
import '../theme/tokens.dart';
import '../widgets/action_button.dart';
import '../widgets/app_input.dart';
import '../widgets/burst_widget.dart';
import '../widgets/sigil_widget.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final TextEditingController _nameController = TextEditingController();
  final Set<int> _selectedTemplateIndices = {0, 4, 8}; // Default 3 starter quests

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await ref.read(profileActionsProvider).setName(name);
    }

    final questActions = ref.read(questActionsProvider);
    final now = DateTime.now();
    final today = ref.read(effectiveLocalDateProvider);
    final weekStart = ref.read(weekStartProvider);

    for (final index in _selectedTemplateIndices) {
      final t = StarterTemplates.templates[index];
      await questActions.createQuest(
        title: t.title,
        rule: t.rule,
        targetType: t.targetType,
        targetValue: t.targetValue,
        unit: t.unit,
        difficulty: t.difficulty,
        essential: t.essential,
        domain: t.domain,
        now: now,
        today: today,
        weekStart: weekStart,
      );
    }

    await ref.read(ledgerDaoProvider).markMomentSeen('onboarding', now);

    if (mounted) {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _buildCurrentStep(tokens),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AppTokens tokens) {
    switch (_step) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
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
              style: tokens.display(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your quests. Your cadence. No accounts.',
              textAlign: TextAlign.center,
              style: tokens.body(
                fontSize: 15,
                color: tokens.textSecondary,
              ),
            ),
            const Spacer(),
            ActionButton(
              label: 'BEGIN',
              onPressed: () => setState(() => _step = 1),
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'STEP 1 OF 2',
              style: tokens.monoText(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How should the ledger address you?',
              style: tokens.headline(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            AppInput(
              controller: _nameController,
              hintText: 'Enter your name or alias',
              autofocus: true,
            ),
            const Spacer(),
            ActionButton(
              label: 'CONTINUE',
              onPressed: () => setState(() => _step = 2),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STEP 2 OF 3',
              style: tokens.monoText(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select starter quests',
              style: tokens.headline(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a few habits to anchor your daily discipline.',
              style: tokens.body(fontSize: 13, color: tokens.textSecondary),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: StarterTemplates.templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = StarterTemplates.templates[index];
                  final isSelected = _selectedTemplateIndices.contains(index);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTemplateIndices.remove(index);
                        } else {
                          _selectedTemplateIndices.add(index);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? tokens.tonal : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? tokens.accent : tokens.lineRule,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          SigilWidget(domain: t.domain, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: tokens.title(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.category} · ${t.rule.cadence.name.toUpperCase()}',
                                  style: tokens.monoText(
                                    fontSize: 11,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? Symbols.check_box : Symbols.check_box_outline_blank,
                            size: 20,
                            color: isSelected ? tokens.hero : tokens.textSecondary.withOpacity(0.4),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ActionButton(
              label: 'CONTINUE',
              onPressed: () => setState(() => _step = 3),
            ),
          ],
        );

      case 3:
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            BurstWidget(
              size: 120,
              child: SigilWidget(
                domain: CallingDomain.warrior,
                size: 40,
                color: tokens.hero,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'THE ONBOARDING OATH',
              textAlign: TextAlign.center,
              style: tokens.monoText(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.tonal,
                border: Border.all(color: tokens.lineRule),
              ),
              child: Text(
                '"I vow to log my data before I judge my numbers.\n\n'
                'I will treat every scan as intel, not a grade.\n\n'
                'I am the hero of my own glucose journey."',
                textAlign: TextAlign.center,
                style: tokens.body(
                  fontSize: 16,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Settlement begins when the first scan is logged. Missing an essential quest forfeits your streak.',
              textAlign: TextAlign.center,
              style: tokens.body(fontSize: 12, color: tokens.textSecondary),
            ),
            const Spacer(),
            ActionButton(
              label: 'I VOW · ENTER THE LEDGER',
              onPressed: _finishOnboarding,
            ),
          ],
        );
    }
  }
}
