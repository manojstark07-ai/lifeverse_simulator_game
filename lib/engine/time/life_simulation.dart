import 'dart:math' as math;

import '../career/career_service.dart';
import '../character/stats.dart';
import '../content/content_bundle.dart';
import '../core/game_calendar.dart';
import '../core/json_utils.dart';
import '../creator/creator_service.dart';
import '../education/education_service.dart';
import '../effects/effect.dart';
import '../effects/effect_resolver.dart';
import '../engine_context.dart';
import '../finance/finance_models.dart';
import '../finance/finance_service.dart';
import '../finance/investment_service.dart';
import '../game_events.dart';
import '../game_state.dart';
import '../household/household_service.dart';
import '../journal/journal.dart';
import '../lifestyle/lifestyle_service.dart';
import '../life/life_system_service.dart';
import '../relationships/relationship_service.dart';
import '../story/story_models.dart';
import 'routine.dart';

/// How the player's week is spent, after fixed commitments.
class RoutineBudget {
  RoutineBudget._({
    required this.commitments,
    required this.commitmentLines,
    required this.free,
    required this.study,
    required this.exercise,
    required this.social,
    required this.family,
  });

  /// Normalises the player's routine so planned hours never exceed the time
  /// actually available — you cannot study 40 hours on top of a full-time job.
  factory RoutineBudget.of(GameState s, ContentBundle c) {
    final lines = <String, double>{};
    final e = s.education;
    if (e.isEnrolled) {
      final p = c.programs[e.programId];
      if (p != null) lines['${p.shortName} classes'] = p.weeklyHours;
    }
    final pt = c.partTimeJobs[s.career.partTimeJobId];
    if (pt != null) lines[pt.name] = pt.weeklyHours;
    final career = c.careers[s.career.careerId];
    if (career != null) lines['Work'] = career.weeklyHours;
    if (s.creator?.fullTime ?? false)
      lines['Filming & editing'] = CreatorService.fullTimeWeeklyHours;
    if (lines.isNotEmpty) {
      // A vehicle shortens the commute.
      final commute =
          (c.hometowns[s.profile.currentCityId]?.commuteHoursWeekly ?? 0) -
          LifestyleService.commuteHoursSaved(s, c);
      if (commute > 0) lines['Commute'] = commute;
    }
    final commitments = lines.values.fold<double>(0, (a, b) => a + b);
    final free = math.max(
      0.0,
      Routine.freeHoursBeforeCommitments - commitments,
    );
    final r = s.routine;
    final scale = r.planned > free && r.planned > 0 ? free / r.planned : 1.0;
    return RoutineBudget._(
      commitments: commitments,
      commitmentLines: lines,
      free: free,
      study: r.study * scale,
      exercise: r.exercise * scale,
      social: r.social * scale,
      family: r.family * scale,
    );
  }

  final double commitments;
  final Map<String, double> commitmentLines;
  final double free;
  final double study;
  final double exercise;
  final double social;
  final double family;

  double get leisure => math.max(0, free - study - exercise - social - family);

  /// Share of waking discretionary time spent on obligations and study.
  double get load => (commitments + study) / Routine.freeHoursBeforeCommitments;

  /// Daily energy settles toward this value.
  double get energyTarget => clampDouble(
    85 - math.max(0, load - 0.55) * 90 + math.min(exercise, 6) * 1.0,
    20,
    95,
  );
}

/// Advances the world: days, months, delayed consequences and random events.
class LifeSimulation {
  const LifeSimulation._();

  /// How effectively time converts into learning this month (0.5..1).
  static double efficiency(GameState s) {
    var e = 0.55 + 0.45 * (s.stat(StatKeys.energy) / 100);
    if (s.stat(StatKeys.wellbeing) < 30) e *= 0.8;
    return e;
  }

  static int livingCost(GameState s, ContentBundle c) {
    final city = c.hometowns[s.profile.currentCityId];
    if (city == null) return 0;
    var cost =
        city.livingCostMonthly *
        (c.backgrounds[s.profile.backgroundId]?.lifestyleCostMultiplier ?? 1);
    if (s.career.hasCareer) cost *= 1.6; // an earning adult pays their share
    if (s.flags.contains('living_independently') &&
        !s.flags.contains('homeowner'))
      cost += city.rentMonthly;
    if (s.household.isMarried) cost *= 1.5; // a household of two
    if (s.flags.contains('frugal_mode')) cost *= 0.85;
    return cost.round();
  }

  /// Moves the clock forward by exactly one day.
  static void advanceDay(EngineContext ctx) {
    final s = ctx.s;
    final previousMonth = GameCalendar.monthKeyOfDay(s.day);
    s.day++;
    s.actionsToday = 0;

    final budget = RoutineBudget.of(s, ctx.c);
    final energy = s.stat(StatKeys.energy);
    // Poor health caps how rested you can feel.
    final target =
        budget.energyTarget - math.max(0, 50 - s.stat(StatKeys.health)) * 0.4;
    ctx.addStat(StatKeys.energy, (target - energy) * 0.2, record: false);

    final currentMonth = GameCalendar.monthKeyOfDay(s.day);
    if (currentMonth != previousMonth) {
      for (var m = s.lastSettledMonthKey + 1; m < currentMonth; m++) {
        settleMonth(ctx, m);
      }
      rollRandomEvents(ctx);
    }
    applyDueScheduledEffects(ctx);
    LifeSystemService.checkAge(ctx);
  }

  static void applyDueScheduledEffects(EngineContext ctx) {
    final s = ctx.s;
    final due = s.scheduled.where((x) => x.dueDay <= s.day).toList();
    if (due.isEmpty) return;
    s.scheduled.removeWhere((x) => x.dueDay <= s.day);
    for (final item in due) {
      final effects = item.effects.map(Effect.fromJson).toList();
      ctx.outcomes.clear();
      EffectResolver.applyAll(ctx, effects);
      final summary = ctx.outcomes.join(', ');
      ctx.journal(
        item.note,
        summary.isEmpty ? item.note : summary,
        JournalKind.story,
        important: true,
      );
      ctx.emit(Notice('${item.note}${summary.isEmpty ? '' : ' — $summary'}'));
      ctx.outcomes.clear();
    }
  }

  /// Settles one calendar month: income, bills, learning, careers, bonds.
  /// Idempotent per month thanks to [GameState.lastSettledMonthKey].
  static void settleMonth(EngineContext ctx, int monthKey) {
    final s = ctx.s;
    if (monthKey <= s.lastSettledMonthKey) return;
    final c = ctx.c;
    final ledger = MonthLedger();
    final budget = RoutineBudget.of(s, c);
    final eff = efficiency(s);

    // 1. Income.
    if (s.finance.familySupportMonthly > 0) {
      ctx.credit(
        s.finance.familySupportMonthly,
        'family',
        'Family support',
        record: false,
      );
      ledger.addIncome(s.finance.familySupportMonthly, 'Family support');
    }
    CareerService.settleMonth(ctx, ledger, eff);

    // 2. Obligations: overdue bills first, then living costs and loans.
    FinanceService.settleArrears(ctx, ledger);
    final living = livingCost(s, c);
    ctx.payMandatory(living, 'living', 'Living expenses', record: false);
    ledger.addExpense(living, 'Living expenses');
    FinanceService.settleLoans(ctx, monthKey, ledger);
    if (s.flags.contains('remit_home') && s.career.hasCareer) {
      final remit = (s.career.monthlySalary * 0.1).round();
      if (ctx.trySpend(remit, 'family', 'Sent home', record: false))
        ledger.addExpense(remit, 'Sent home to family');
    }

    // Possessions, family and the channel.
    LifestyleService.settleMonth(ctx, ledger);
    HouseholdService.settleMonth(ctx, ledger, livingCost: living);
    CreatorService.settleMonth(ctx, ledger);

    // Ongoing habits and situations defined in content.
    _applyMonthlyRules(ctx, ledger);

    // 3. Personal development from the weekly routine.
    _applyRoutine(ctx, budget, eff, living);

    // 4. Education (may charge next semester's fees).
    EducationService.settleMonth(ctx, ledger, eff);

    // 5. Bonds.
    RelationshipService.settleMonth(
      ctx,
      familyHours: budget.family,
      socialHours: budget.social,
    );

    // 6. Savings interest and arrears tracking.
    FinanceService.savingsInterest(ctx, ledger);
    InvestmentService.settleMonth(ctx, ledger);
    LifeSystemService.settleMonth(ctx, ledger);
    final f = s.finance;
    if (f.arrears > 0) {
      f.monthsInArrears++;
      f.creditScore = math.max(FinanceService.minCredit, f.creditScore - 10);
      s.flags.add('money_trouble');
    } else {
      f.monthsInArrears = 0;
    }

    f.history.add(
      MonthlySnapshot(
        monthKey: monthKey,
        cash: f.cash,
        debt: f.totalDebt,
        income: ledger.income,
        expenses: ledger.expenses,
      ),
    );
    s.counters['monthsPlayed'] = s.counter('monthsPlayed') + 1;
    s.lastSettledMonthKey = monthKey;

    final title = GameCalendar.formatMonthKey(monthKey);
    ctx.journal(
      '$title summary',
      'Income ${ledger.income}, expenses ${ledger.expenses}. ${ledger.lines.where((l) => !l.startsWith('+') && !l.startsWith('−')).join(' ')}',
      JournalKind.month,
    );
    ctx.emit(
      MonthSettled(
        monthKey: monthKey,
        income: ledger.income,
        expenses: ledger.expenses,
        lines: ledger.lines,
      ),
    );
  }

  static void _applyMonthlyRules(EngineContext ctx, MonthLedger ledger) {
    final ids = ctx.c.monthlyRules.keys.toList()..sort();
    for (final id in ids) {
      final rule = ctx.c.monthlyRules[id]!;
      if (!rule.when.evaluate(ctx.s, ctx.c)) continue;
      final saved = List.of(ctx.outcomes);
      EffectResolver.applyAll(ctx, rule.effects);
      ctx.outcomes
        ..clear()
        ..addAll(saved);
      for (final e in rule.effects.where((e) => e.type == 'money')) {
        final amount = (e.raw['amount'] as num).toInt();
        if (amount < 0) {
          ledger.addExpense(-amount, rule.label);
        } else {
          ledger.addIncome(amount, rule.label);
        }
      }
      if (!rule.effects.any((e) => e.type == 'money'))
        ledger.lines.add(rule.label);
    }
  }

  static void _applyRoutine(
    EngineContext ctx,
    RoutineBudget b,
    double eff,
    int living,
  ) {
    final s = ctx.s;
    final k = s.stat(StatKeys.knowledge);
    var knowledge =
        b.study *
        0.11 *
        eff *
        (1 - k / 120) *
        ctx.modifier(ModifierKeys.knowledgeGain);
    if (b.study < 2 && !s.education.isEnrolled)
      knowledge -= 0.3; // unused knowledge fades
    ctx.addStat(StatKeys.knowledge, knowledge, record: false);

    var discipline = b.study >= 8 ? 0.6 : (b.study < 3 ? -0.4 : 0.1);
    if (b.exercise >= 3) discipline += 0.2;
    if (s.career.hasCareer) discipline += 0.3;
    if (discipline > 0) discipline *= ctx.modifier(ModifierKeys.disciplineGain);
    ctx.addStat(StatKeys.discipline, discipline, record: false);

    var communication = b.social * 0.06 + (s.career.hasCareer ? 0.3 : 0);
    communication *= ctx.modifier(ModifierKeys.communicationGain);
    ctx.addStat(StatKeys.communication, communication, record: false);

    final moneyStress = s.finance.arrears > 0
        ? 12.0
        : (s.finance.cash < living ? 6.0 : 0.0);
    final target = clampDouble(
      50 +
          math.min(b.exercise * 2.0, 12) +
          math.min(b.social * 1.0, 10) +
          math.min(b.family * 0.8, 8) +
          math.min(b.leisure * 0.35, 12) -
          math.max(0, b.load - 0.75) * 80 -
          moneyStress,
      5,
      95,
    );
    final wb = s.stat(StatKeys.wellbeing);
    var delta = (target - wb) * 0.35;
    if (delta > 0) delta *= ctx.modifier(ModifierKeys.wellbeingRecovery);
    ctx.addStat(StatKeys.wellbeing, delta, record: false);

    // Health drifts toward what your habits support. Smoking and drinking
    // also cost health directly through their monthly rules.
    final healthTarget = clampDouble(
      70 +
          math.min(b.exercise * 2.5, 15) -
          math.max(0, b.load - 0.85) * 40 -
          (wb < 25 ? 5 : 0),
      20,
      95,
    );
    ctx.addStat(
      StatKeys.health,
      (healthTarget - s.stat(StatKeys.health)) * 0.1,
      record: false,
    );

    // A haircut does not last forever.
    if (s.stat(StatKeys.looks) > 35)
      ctx.addStat(StatKeys.looks, -1.0, record: false);
  }

  /// Monthly roll for random world events. A hit queues the event for a
  /// random day this month; its conditions are re-checked when it fires.
  static void rollRandomEvents(EngineContext ctx) {
    final s = ctx.s;
    final candidates =
        ctx.c.events.values
            .where(
              (e) =>
                  e.trigger.kind == TriggerKind.random &&
                  e.inChapter(s.chapter),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    for (final e in candidates) {
      if (!e.repeatable && s.story.completed.contains(e.id)) continue;
      if (s.story.queue.any((q) => q.eventId == e.id)) continue;
      final last = s.story.lastFiredDay[e.id];
      if (last != null && s.day - last < 120) continue; // cooldown
      if (!e.trigger.condition.evaluate(s, ctx.c)) continue;
      if (ctx.rng.chance(e.trigger.chancePerMonth)) {
        s.story.queue.add(
          QueuedEvent(eventId: e.id, dueDay: s.day + ctx.rng.nextInt(20)),
        );
      }
    }
  }
}
