import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/database.dart';
import '../../domain/engine/glucose_settlement.dart';
import '../../domain/engine/schedule_rule.dart';
import '../../domain/engine/settlement.dart';
import '../../domain/engine/xp.dart';
import '../../domain/model/diabetes_context.dart';
import '../../domain/model/models.dart';

class QuestActions {
  final AppDatabase db;
  final _uuid = const Uuid();

  QuestActions(this.db);

  /// Settle closed periods and materialize pending bonuses
  Future<void> settle({
    required LocalDate today,
    required WeekStart weekStart,
    required DateTime now,
  }) async {
    final profile = await db.profileDao.getProfile();

    // 0. Refill grace token if the 30-day cooldown has elapsed.
    await db.profileDao.refillGraceToken(today: today);

    // 1. Apply grace completions for missed essential daily quests (closed days).
    await _applyGraceTokens(today: today, now: now);

    final activeQuests = await db.questsDao.getActiveQuests();
    final allEvents = await db.ledgerDao.getAllXpEvents();
    final existingEventRefs = allEvents.map((e) => e.ref).toSet();

    final sixtyDaysAgo = today.subtractDays(60);
    final completions = await db.completionsDao.getCompletionsInDateRange(
      sixtyDaysAgo.formatted,
      today.formatted,
    );

    final Map<String, Map<LocalDate, int>> completionsByQuest = {};
    for (final c in completions) {
      final date = LocalDate.parse(c.localDate);
      completionsByQuest.putIfAbsent(c.questId, () => {})[date] =
          (completionsByQuest[c.questId]?[date] ?? 0) + c.value;
    }

    final List<Map<String, dynamic>> questsData = activeQuests
        .map((q) => {
              'id': q.id,
              'essential': q.essential,
              'rule': q.rule,
              'targetValue': q.targetValue,
            })
        .toList();

    LocalDate? profileSettledThrough;
    if (profile.settledThrough != null) {
      try {
        profileSettledThrough = LocalDate.parse(profile.settledThrough!);
      } catch (_) {}
    }

    final settlementResult = SettlementEngine.settle(
      questsData: questsData,
      completionsByQuest: completionsByQuest,
      profileSettledThrough: profileSettledThrough,
      today: today,
      weekStart: weekStart,
      existingEventRefs: existingEventRefs,
    );

    if (settlementResult.newEvents.isNotEmpty || settlementResult.profileSettledThrough != null) {
      await db.transaction(() async {
        for (final event in settlementResult.newEvents) {
          await db.ledgerDao.insertXpEvent(
            XpEventsCompanion(
              id: Value(_uuid.v4()),
              type: Value(event.type.index),
              ref: Value(event.ref),
              periodRef: Value(event.periodRef),
              amount: Value(event.amount),
              localDate: Value(event.localDate.formatted),
              createdAt: Value(now),
            ),
          );
        }

        if (settlementResult.profileSettledThrough != null) {
          await db.profileDao.updateSettledThrough(
            settlementResult.profileSettledThrough!.formatted,
          );
        }
      });
    }

    // 2. Glucose settlement catch-up through yesterday.
    await _settleGlucoseCatchUp(today: today, now: now);
  }

  /// Insert a grace completion for a missed essential daily quest, consuming
  /// the profile's grace token. Keeps streaks/badges intact on bad days.
  Future<void> _applyGraceTokens({
    required LocalDate today,
    required DateTime now,
  }) async {
    final profile = await db.profileDao.getProfile();
    if (!profile.hasGraceToken) return;

    final essentialDailyQuests = (await db.questsDao.getActiveQuests())
        .where((q) => q.essential && q.rule is DailyRule && q.pausedUntil == null)
        .toList();
    if (essentialDailyQuests.isEmpty) return;

    final closedSince = profile.glucoseSettledThrough != null
        ? LocalDate.parse(profile.glucoseSettledThrough!)
        : today.subtractDays(30);

    for (int i = 1; i <= 30; i++) {
      final day = today.subtractDays(i);
      if (day < closedSince) break;
      if (!profile.hasGraceToken) break;

      for (final q in essentialDailyQuests) {
        // Skip if the day predates the quest's creation.
        if (day < LocalDate.fromDateTime(q.createdAt)) continue;

        if (!q.rule.isScheduledOn(day)) continue;

        final dayCompletions = (await db.completionsDao.getCompletionsForQuest(q.id))
            .where((c) => c.localDate == day.formatted)
            .toList();
        final total = dayCompletions.fold<int>(0, (sum, c) => sum + c.value);
        if (total >= q.targetValue) continue;

        // Grant token only once per day; do not stack multiple grace fills.
        await db.completionsDao.insertCompletion(
          CompletionsCompanion(
            id: Value(_uuid.v4()),
            questId: Value(q.id),
            localDate: Value(day.formatted),
            value: const Value(1),
            note: const Value('grace:token'),
            timezone: Value('UTC'),
            createdAt: Value(now),
          ),
        );
        await db.profileDao.consumeGraceToken(now);
        break;
      }
    }
  }

  /// Settle all closed days since the last glucose settlement, idempotently.
  Future<void> _settleGlucoseCatchUp({
    required LocalDate today,
    required DateTime now,
  }) async {
    final profile = await db.profileDao.getProfile();
    final allEvents = await db.ledgerDao.getAllXpEvents();
    final existingRefs = allEvents.map((e) => e.ref).toSet();

    LocalDate? through;
    if (profile.glucoseSettledThrough != null) {
      try {
        through = LocalDate.parse(profile.glucoseSettledThrough!);
      } catch (_) {}
    }
    final start = through != null ? through.addDays(1) : today.subtractDays(30);
    final yesterday = today.subtractDays(1);
    if (start.isAfter(yesterday)) return;

    LocalDate? lastSettled;
    await db.transaction(() async {
      for (var day = start; !day.isAfter(yesterday); day = day.addDays(1)) {
        final logs = await db.completionsDao.getCompletionsInDateRange(
          day.formatted,
          day.formatted,
        );
        final result = GlucoseSettlementEngine.settleDay(
          date: day,
          completions: logs,
          isSick: profile.isSick,
        );
        for (final event in GlucoseSettlementEngine.eventsFor(result)) {
          if (existingRefs.contains(event.ref)) continue;
          await db.ledgerDao.insertXpEvent(
            XpEventsCompanion(
              id: Value(_uuid.v4()),
              type: Value(event.type.index),
              ref: Value(event.ref),
              amount: Value(event.amount),
              localDate: Value(event.localDate.formatted),
              createdAt: Value(now),
            ),
          );
          existingRefs.add(event.ref);
        }
        if (result.hasData || result.effortCoins > 0 || result.outcomeXp > 0) {
          lastSettled = day;
        }
      }
    });

    if (lastSettled != null) {
      await db.profileDao.updateGlucoseSettledThrough(lastSettled!.formatted);
    }
  }

  /// Settle a single glucose day (used after logging a reading today).
  Future<void> settleGlucoseDay({
    required LocalDate date,
    required DateTime now,
  }) async {
    final profile = await db.profileDao.getProfile();
    final allEvents = await db.ledgerDao.getAllXpEvents();
    final existingRefs = allEvents.map((e) => e.ref).toSet();

    final logs = await db.completionsDao.getCompletionsInDateRange(date.formatted, date.formatted);
    final dayClosed = date.isBefore(LocalDate.fromDateTime(now));
    final result = GlucoseSettlementEngine.settleDay(
      date: date,
      completions: logs,
      isSick: profile.isSick,
    );

    for (final event in GlucoseSettlementEngine.eventsFor(result)) {
      // Today's partially-collected day banks coins immediately; outcomes wait
      // until the day closes (the catch-up loop is idempotent via refs).
      if (!dayClosed && event.type.isOutcomeXp) continue;
      if (existingRefs.contains(event.ref)) continue;
      await db.ledgerDao.insertXpEvent(
        XpEventsCompanion(
          id: Value(_uuid.v4()),
          type: Value(event.type.index),
          ref: Value(event.ref),
          amount: Value(event.amount),
          localDate: Value(event.localDate.formatted),
          createdAt: Value(now),
        ),
      );
      existingRefs.add(event.ref);
    }
  }

  /// Toggle survival mode (Sick Day Shield).
  Future<void> setSickDay({
    required bool isSick,
    LocalDate? today,
    WeekStart? weekStart,
    DateTime? now,
  }) async {
    await db.profileDao.setSick(isSick);
    if (today != null && weekStart != null && now != null) {
      await settle(today: today, weekStart: weekStart, now: now);
    }
  }

  /// Complete a quest (or increment its counter) for a scoring date
  Future<String> completeQuest({
    required QuestData quest,
    required LocalDate date,
    int incrementValue = 1,
    String? note,
    required WeekStart weekStart,
    String timezone = 'UTC',
    required DateTime now,
    double? numericValue,
    GlucoseContext? context,
    DateTime? loggedAt,
  }) async {
    final completionId = _uuid.v4();

    // 1. Get current completions in period to calculate incremental XP
    final period = quest.rule.periodOf(date, weekStart);
    final completionsInPeriod = await db.completionsDao.getCompletionsInDateRange(
      period.startLocalDate.formatted,
      period.endLocalDate.formatted,
    );

    int prevCount = 0;
    for (final c in completionsInPeriod) {
      if (c.questId == quest.id) {
        final cDate = LocalDate.parse(c.localDate);
        if (quest.rule is WeeklyRule &&
            (quest.rule as WeeklyRule).allowedDays != null &&
            (quest.rule as WeeklyRule).allowedDays!.isNotEmpty) {
          if ((quest.rule as WeeklyRule).allowedDays!.contains(cDate.toDateTime().weekday)) {
            prevCount += c.value;
          }
        } else {
          prevCount += c.value;
        }
      }
    }

    final isScheduled = quest.rule is WeeklyRule &&
            (quest.rule as WeeklyRule).allowedDays != null &&
            (quest.rule as WeeklyRule).allowedDays!.isNotEmpty
        ? (quest.rule as WeeklyRule).allowedDays!.contains(date.toDateTime().weekday)
        : (quest.rule.isWindowScheduled
            ? period.contains(date)
            : quest.rule.isScheduledOn(date));

    final newCount = isScheduled ? (prevCount + incrementValue) : prevCount;

    int target = quest.targetValue;
    if (quest.rule is WeeklyRule && (quest.rule as WeeklyRule).times != null) {
      target = (quest.rule as WeeklyRule).times!;
    } else if (quest.rule is MonthlyRule && (quest.rule as MonthlyRule).times != null) {
      target = (quest.rule as MonthlyRule).times!;
    } else if (quest.rule is YearlyRule && (quest.rule as YearlyRule).times != null) {
      target = (quest.rule as YearlyRule).times!;
    }

    final xpAmount = XpEngine.calculateIncrementalXp(
      rule: quest.rule,
      difficulty: Difficulty.values[quest.difficulty],
      target: target,
      previousCount: prevCount,
      newCount: newCount,
      isScheduled: isScheduled,
    );

    final periodKey = quest.rule.periodKey(period.startLocalDate, weekStart);

    await db.transaction(() async {
      // Insert completion row
      await db.completionsDao.insertCompletion(
        CompletionsCompanion(
          id: Value(completionId),
          questId: Value(quest.id),
          localDate: Value(date.formatted),
          value: Value(incrementValue),
          note: Value(note),
          timezone: Value(timezone),
          createdAt: Value(now),
          numericValue: Value(numericValue),
          contextJson: Value(context?.toDb()),
          loggedAt: Value(loggedAt),
        ),
      );

      // Insert XP event if any XP earned
      if (xpAmount > 0) {
        await db.ledgerDao.insertXpEvent(
          XpEventsCompanion(
            id: Value(_uuid.v4()),
            type: Value(XpEventType.quest.index),
            ref: Value(completionId),
            periodRef: Value('${quest.id}|$periodKey'),
            amount: Value(xpAmount),
            localDate: Value(date.formatted),
            createdAt: Value(now),
          ),
        );
      }
    });

    // Settle glucose whenever a glucose action was logged (coins now, outcomes
    // once the day closes).
    if (context != null) {
      await settleGlucoseDay(date: date, now: now);
    }

    // Run settlement
    await settle(today: date, weekStart: weekStart, now: now);

    return completionId;
  }

  /// Undo a completion within the undo window
  Future<void> undoCompletion(String completionId, {LocalDate? today, WeekStart? weekStart, DateTime? now}) async {
    await db.transaction(() async {
      await db.completionsDao.deleteCompletion(completionId);
      await db.ledgerDao.deleteXpEventsByRef(completionId);
    });

    if (today != null && weekStart != null && now != null) {
      await settle(today: today, weekStart: weekStart, now: now);
    }
  }

  /// Decrement a counter quest by removing its latest completion log entry on date
  Future<void> decrementQuest({
    required String questId,
    required LocalDate date,
    required WeekStart weekStart,
    required DateTime now,
  }) async {
    final completions = await db.completionsDao.getCompletionsInDateRange(date.formatted, date.formatted);
    final questCompletions = completions.where((c) => c.questId == questId).toList();
    if (questCompletions.isNotEmpty) {
      final latest = questCompletions.last;
      await undoCompletion(latest.id, today: date, weekStart: weekStart, now: now);
    }
  }

  /// Create a new quest
  Future<String> createQuest({
    required String title,
    String? note,
    required ScheduleRule rule,
    required TargetType targetType,
    int targetValue = 1,
    String? unit,
    required Difficulty difficulty,
    bool essential = false,
    String? goalId,
    CallingDomain? domain,
    int? reminderMinute,
    required DateTime now,
    LocalDate? today,
    WeekStart? weekStart,
  }) async {
    final id = _uuid.v4();
    await db.questsDao.insertQuest(
      QuestsCompanion(
        id: Value(id),
        title: Value(title),
        note: Value(note),
        rule: Value(rule),
        targetType: Value(targetType.index),
        targetValue: Value(targetValue),
        unit: Value(unit),
        difficulty: Value(difficulty.index),
        essential: Value(essential),
        goalId: Value(goalId),
        domain: Value(domain?.index),
        reminderMinute: Value(reminderMinute),
        createdAt: Value(now),
      ),
    );

    if (today != null && weekStart != null) {
      await settle(today: today, weekStart: weekStart, now: now);
    }

    return id;
  }

  /// Update an existing quest
  Future<void> updateQuest({
    required String id,
    required String title,
    String? note,
    required ScheduleRule rule,
    required TargetType targetType,
    int targetValue = 1,
    String? unit,
    required Difficulty difficulty,
    bool essential = false,
    String? goalId,
    CallingDomain? domain,
    int? reminderMinute,
    String? pausedUntil,
    DateTime? archivedAt,
    required DateTime createdAt,
    LocalDate? today,
    WeekStart? weekStart,
    DateTime? now,
  }) async {
    await db.questsDao.updateQuest(
      QuestsCompanion(
        id: Value(id),
        title: Value(title),
        note: Value(note),
        rule: Value(rule),
        targetType: Value(targetType.index),
        targetValue: Value(targetValue),
        unit: Value(unit),
        difficulty: Value(difficulty.index),
        essential: Value(essential),
        goalId: Value(goalId),
        domain: Value(domain?.index),
        reminderMinute: Value(reminderMinute),
        pausedUntil: Value(pausedUntil),
        archivedAt: Value(archivedAt),
        createdAt: Value(createdAt),
      ),
    );

    if (today != null && weekStart != null && now != null) {
      await settle(today: today, weekStart: weekStart, now: now);
    }
  }

  /// Pause a quest until a local date
  Future<void> pauseQuest(String questId, LocalDate? pausedUntil) async {
    await db.questsDao.pauseQuest(questId, pausedUntil?.formatted);
  }

  /// Archive a quest
  Future<void> archiveQuest(String questId, DateTime now) async {
    await db.questsDao.archiveQuest(questId, now);
  }

  /// Update target value (safe edit)
  Future<void> updateTargetValue(String questId, int targetValue) async {
    await db.questsDao.updateTargetValue(questId, targetValue);
  }

  /// Update difficulty (safe edit)
  Future<void> updateDifficulty(String questId, Difficulty difficulty) async {
    await db.questsDao.updateDifficulty(questId, difficulty.index);
  }
}
