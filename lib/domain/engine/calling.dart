import '../model/models.dart';

class CallingInfo {
  final CallingDomain domain;
  final String name;
  final String tagline;
  final String description;
  final List<String> focusAreas;
  final String trialName;
  final String trialDescription;

  const CallingInfo({
    required this.domain,
    required this.name,
    required this.tagline,
    required this.description,
    required this.focusAreas,
    required this.trialName,
    required this.trialDescription,
  });
}

class CallingEngine {
  static const Map<CallingDomain, CallingInfo> callings = {
    CallingDomain.warrior: CallingInfo(
      domain: CallingDomain.warrior,
      name: 'Stabilizer',
      tagline: 'The shield of a steady line.',
      description:
          'Your discipline makes the blood-sugar line hold. Morning scans, fasting calm, and steady routines keep the shield strong.',
      focusAreas: ['Daily scans', 'Fasting', 'Steady rhythm', 'Resilience'],
      trialName: 'Trial of the Steady Grip',
      trialDescription: 'Maintain a 30-day streak on any Stabilizer quest.',
    ),
    CallingDomain.sage: CallingInfo(
      domain: CallingDomain.sage,
      name: 'Counter',
      tagline: 'The scales of precise measurement.',
      description:
          'Carb counting, insulin math, and trend prediction are your craft. Every number you log balances the day.',
      focusAreas: ['Carb counting', 'Insulin math', 'Trends', 'Precision'],
      trialName: 'Trial of the Balanced Ledger',
      trialDescription: 'Log 100 carb or insulin entries while pledged to the Counter.',
    ),
    CallingDomain.monk: CallingInfo(
      domain: CallingDomain.monk,
      name: 'Hydrator',
      tagline: 'The droplet that steadies the flow.',
      description:
          'Water, slow meals, and mindful pacing. Hydration makes insulin work, and calm routine makes control durable.',
      focusAreas: ['Hydration', 'Mindful meals', 'Calm', 'Repose'],
      trialName: 'Trial of the Full Glass',
      trialDescription: 'Hit the water goal for 21 consecutive days while pledged to the Hydrator.',
    ),
    CallingDomain.bard: CallingInfo(
      domain: CallingDomain.bard,
      name: 'Rotator',
      tagline: 'The gear that turns to protect tissue.',
      description:
          'Site discipline and rhythm. Rotating where you inject keeps absorption true and scar tissue at bay.',
      focusAreas: ['Site rotation', 'Pump patrol', 'Rhythm', 'Order'],
      trialName: 'Trial of the Six-Direction Turn',
      trialDescription: 'Log 7 unique insulin sites without repetition while pledged to the Rotator.',
    ),
    CallingDomain.ranger: CallingInfo(
      domain: CallingDomain.ranger,
      name: 'Analyst',
      tagline: 'The eye that reads the long game.',
      description:
          'Dawn patterns, weekly trends, and long-range slopes. You watch the horizon so no spike sneaks past.',
      focusAreas: ['Patterns', 'Dawn watch', 'Weekly trends', 'Foresight'],
      trialName: 'Trial of the Morning Light',
      trialDescription: 'Log a dawn scan 15 days in a row while pledged to the Analyst.',
    ),
    CallingDomain.artificer: CallingInfo(
      domain: CallingDomain.artificer,
      name: 'Alchemist',
      tagline: 'The flask of precise dosing.',
      description:
          'Bolus timing, correction ratios, and device craft. You mix the right dose at the right moment, every time.',
      focusAreas: ['Dosing', 'Corrections', 'Device craft', 'Precision'],
      trialName: 'Trial of the Precise Dose',
      trialDescription: 'Log 100 insulin doses while pledged to the Alchemist.',
    ),
  };

  static CallingInfo getInfo(CallingDomain domain) {
    return callings[domain]!;
  }

  static const List<int> milestoneThresholds = [250, 1000, 5000];

  /// Calculate derived stats and progression tier for a specific calling domain
  static DomainStats calculateDomainStats({
    required CallingDomain domain,
    required int domainXp,
    required int completionsCount,
  }) {
    int tier = 0;
    for (int i = 0; i < milestoneThresholds.length; i++) {
      if (domainXp >= milestoneThresholds[i]) {
        tier = i + 1;
      }
    }

    int prevThreshold = tier == 0 ? 0 : milestoneThresholds[tier - 1];
    int nextThreshold = tier < milestoneThresholds.length
        ? milestoneThresholds[tier]
        : milestoneThresholds.last;

    double progress = 1.0;
    if (tier < milestoneThresholds.length) {
      final range = nextThreshold - prevThreshold;
      final currentInRange = (domainXp - prevThreshold).clamp(0, range);
      progress = range > 0 ? currentInRange / range : 1.0;
    }

    final displayName = getInfo(domain).name.toUpperCase();
    return DomainStats(
      domain: domain,
      info: getInfo(domain),
      totalXp: domainXp,
      completionsCount: completionsCount,
      tier: tier,
      tierTitle: tier == 0
          ? '$displayName RECRUIT'
          : '$displayName ${tierRoman(tier)}',
      progressToNext: progress,
      nextThreshold: nextThreshold,
    );
  }

  static String tierRoman(int tier) {
    switch (tier) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      default:
        return 'III';
    }
  }
}

class DomainStats {
  final CallingDomain domain;
  final CallingInfo info;
  final int totalXp;
  final int completionsCount;
  final int tier; // 0, 1 (250), 2 (1000), 3 (5000)
  final String tierTitle;
  final double progressToNext;
  final int nextThreshold;

  const DomainStats({
    required this.domain,
    required this.info,
    required this.totalXp,
    required this.completionsCount,
    required this.tier,
    required this.tierTitle,
    required this.progressToNext,
    required this.nextThreshold,
  });
}
