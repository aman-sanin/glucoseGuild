import 'engine/schedule_rule.dart';
import 'model/models.dart';

class QuestTemplate {
  final String title;
  final String category;
  final ScheduleRule rule;
  final TargetType targetType;
  final int targetValue;
  final String? unit;
  final Difficulty difficulty;
  final bool essential;
  final CallingDomain domain;

  const QuestTemplate({
    required this.title,
    required this.category,
    required this.rule,
    this.targetType = TargetType.checkbox,
    this.targetValue = 1,
    this.unit,
    this.difficulty = Difficulty.medium,
    this.essential = false,
    required this.domain,
  });
}

class StarterTemplates {
  static const List<QuestTemplate> templates = [
    // JOURNEY (Warrior / Ranger)
    QuestTemplate(
      title: '⚔️ The Dawn Scan',
      category: 'JOURNEY',
      rule: DailyEveryDayRule(),
      difficulty: Difficulty.medium,
      essential: true,
      domain: CallingDomain.warrior,
    ),
    QuestTemplate(
      title: '🚶 Post-Meal Walk',
      category: 'JOURNEY',
      rule: DailyEveryDayRule(),
      difficulty: Difficulty.easy,
      essential: false,
      domain: CallingDomain.ranger,
    ),

    // PERFECTION (Sage / Ranger)
    QuestTemplate(
      title: '🍳 The Chef\'s Kiss',
      category: 'PERFECTION',
      rule: DailyEveryDayRule(),
      difficulty: Difficulty.medium,
      essential: true,
      domain: CallingDomain.sage,
    ),
    QuestTemplate(
      title: '✋ The Two-Hour Rule',
      category: 'PERFECTION',
      rule: DailyEveryDayRule(),
      targetType: TargetType.counter,
      targetValue: 3,
      unit: 'checks',
      difficulty: Difficulty.easy,
      essential: false,
      domain: CallingDomain.ranger,
    ),
    QuestTemplate(
      title: '🌙 Nighttime Glucoguard',
      category: 'PERFECTION',
      rule: DailyEveryDayRule(),
      difficulty: Difficulty.easy,
      essential: false,
      domain: CallingDomain.ranger,
    ),

    // ECONOMY (Sage / Monk)
    QuestTemplate(
      title: '📊 Carb Counter',
      category: 'ECONOMY',
      rule: DailyEveryDayRule(),
      targetType: TargetType.counter,
      targetValue: 3,
      unit: 'meals',
      difficulty: Difficulty.easy,
      essential: false,
      domain: CallingDomain.sage,
    ),
    QuestTemplate(
      title: '💧 River Flow',
      category: 'ECONOMY',
      rule: DailyEveryDayRule(),
      targetType: TargetType.counter,
      targetValue: 8,
      unit: 'glasses',
      difficulty: Difficulty.easy,
      essential: false,
      domain: CallingDomain.monk,
    ),
    QuestTemplate(
      title: '🥗 Low-Carb Lunch',
      category: 'ECONOMY',
      rule: DailyEveryDayRule(),
      difficulty: Difficulty.easy,
      essential: false,
      domain: CallingDomain.sage,
    ),

    // GOALS (Bard)
    QuestTemplate(
      title: '🌀 Rotator Cuff',
      category: 'GOALS',
      rule: DailyEveryDayRule(),
      difficulty: Difficulty.easy,
      essential: false,
      domain: CallingDomain.bard,
    ),

    // CALLING (Warrior)
    QuestTemplate(
      title: '🛡️ The Stabilizer',
      category: 'CALLING',
      rule: WeeklyTimesRule(times: 5),
      targetType: TargetType.counter,
      targetValue: 5,
      unit: 'days',
      difficulty: Difficulty.hard,
      essential: false,
      domain: CallingDomain.warrior,
    ),

    // RARITIES (Artificer)
    QuestTemplate(
      title: '🍕 The Pizza Gauntlet',
      category: 'RARITIES',
      rule: WeeklyTimesRule(times: 3),
      targetType: TargetType.counter,
      targetValue: 3,
      unit: 'trials',
      difficulty: Difficulty.hard,
      essential: false,
      domain: CallingDomain.artificer,
    ),

    // SEALED (Ranger)
    QuestTemplate(
      title: '🏥 The Endo Briefing',
      category: 'SEALED',
      rule: SingleRule(),
      difficulty: Difficulty.hard,
      essential: false,
      domain: CallingDomain.ranger,
    ),
  ];

  static List<String> get categories => [
    'ALL',
    'JOURNEY',
    'PERFECTION',
    'ECONOMY',
    'GOALS',
    'CALLING',
    'RARITIES',
    'SEALED',
  ];
}