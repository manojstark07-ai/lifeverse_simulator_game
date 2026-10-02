import '../achievements/achievement_service.dart';
import '../career/career_service.dart';
import '../character/stats.dart';
import '../core/money.dart';
import '../creator/creator_service.dart';
import '../education/education_models.dart';
import '../education/education_service.dart';
import '../endings/conclusion_service.dart';
import '../engine_context.dart';
import '../finance/finance_service.dart';
import '../game_state.dart';
import '../household/household_service.dart';
import '../journal/journal.dart';
import '../lifestyle/lifestyle_service.dart';
import 'effect.dart';

/// Applies [Effect]s to the draft state held by an [EngineContext].
///
/// Any thrown error aborts the whole engine operation, and because the
/// operation works on a clone, nothing partial is ever committed.
class EffectResolver {
  const EffectResolver._();

  static void applyAll(EngineContext ctx, List<Effect> effects) {
    for (final e in effects) {
      apply(ctx, e);
    }
  }

  /// Resolves the `partner` alias. Null when there is no partner, in which
  /// case relationship effects aimed at them are skipped.
  static String? _npc(EngineContext ctx, Object? id) =>
      id == Effect.partnerAlias ? ctx.s.household.partnerId : id as String;

  static void apply(EngineContext ctx, Effect effect) {
    final s = ctx.s;
    final c = ctx.c;
    final r = effect.raw;
    if (const {'relationship', 'memory', 'meet'}.contains(effect.type) && _npc(ctx, r['npc']) == null) return;
    switch (effect.type) {
      case 'stat':
        final key = r['key'] as String;
        var delta = (r['delta'] as num).toDouble();
        if (delta > 0) {
          delta *= switch (key) {
            StatKeys.knowledge => ctx.modifier(ModifierKeys.knowledgeGain),
            StatKeys.communication => ctx.modifier(ModifierKeys.communicationGain),
            StatKeys.discipline => ctx.modifier(ModifierKeys.disciplineGain),
            StatKeys.wellbeing => ctx.modifier(ModifierKeys.wellbeingRecovery),
            _ => 1.0,
          };
        }
        ctx.addStat(key, delta);
      case 'skill':
        final key = r['key'] as String;
        var delta = (r['delta'] as num).toDouble();
        if (delta > 0) delta *= ctx.modifier(ModifierKeys.skillGain);
        ctx.addSkill(key, delta);
      case 'money':
        final amount = (r['amount'] as num).toInt();
        final label = r['label'] as String;
        final category = r['category'] as String? ?? 'story';
        if (amount >= 0) {
          ctx.credit(amount, category, label);
        } else {
          ctx.payMandatory(-amount, category, label);
        }
      case 'flag':
        s.flags.add(r['key'] as String);
      case 'clearFlag':
        s.flags.remove(r['key'] as String);
      case 'counter':
        // `set` overwrites (to reset a venture or a streak); `delta` adds.
        final key = r['key'] as String;
        s.counters[key] = r['set'] is num ? (r['set'] as num).toInt() : s.counter(key) + (r['delta'] as num).toInt();
      case 'relationship':
        ctx.adjustRelationship(
          _npc(ctx, r['npc'])!,
          affinity: (r['affinity'] as num?)?.toDouble() ?? 0,
          trust: (r['trust'] as num?)?.toDouble() ?? 0,
          conflict: (r['conflict'] as num?)?.toDouble() ?? 0,
        );
      case 'memory':
        ctx.remember(_npc(ctx, r['npc'])!, r['tag'] as String, r['text'] as String,
            (r['weight'] as num?)?.toDouble() ?? 1);
      case 'meet':
        final id = _npc(ctx, r['npc'])!;
        final rel = ctx.rel(id);
        if (!rel.met) {
          rel.met = true;
          rel.lastInteractionDay = s.day;
          ctx.outcomes.add('Met ${c.npcs[id]!.name}');
        }
      case 'journal':
        ctx.journal(r['title'] as String, r['text'] as String, r['kind'] as String? ?? JournalKind.story,
            important: r['important'] as bool? ?? true);
      case 'openBankAccount':
        FinanceService.openAccount(ctx, r['bank'] as String? ?? 'Kaveri Co-operative Bank');
      case 'enroll':
        final program = c.programs[r['program']]!;
        var tierId = r['tier'] as String;
        if (tierId == 'fromExam') {
          final exam = c.exams[program.admissionExamId]!;
          final attempts = s.exams[exam.id]?.attempts ?? const [];
          if (attempts.isEmpty) throw StateError('No ${exam.shortName} result to enrol with');
          final best = attempts.map((a) => exam.tierRank(a.tierId)).reduce((a, b) => a < b ? a : b);
          tierId = exam.tiers[best].id;
        }
        // `transfer: true` swaps a current seat for this one without a
        // drop-out record; fees already paid are forfeited.
        if (r['transfer'] == true && s.education.isEnrolled) {
          ctx.outcomes.add('Gave up your ${c.programs[s.education.programId]?.shortName ?? 'current'} seat');
          s.education.status = EducationStatus.none;
        }
        EducationService.enroll(ctx, program, tierId);
      case 'dropOut':
        EducationService.dropOut(ctx);
      case 'startPartTime':
        CareerService.startPartTime(ctx, c.partTimeJobs[r['job']]!);
      case 'quitPartTime':
        CareerService.quitPartTime(ctx);
      case 'hire':
        CareerService.hire(ctx, c.careers[r['career']]!,
            employer: r['employer'] as String?,
            salaryMultiplier: (r['salaryMultiplier'] as num?)?.toDouble() ?? 1);
      case 'loseJob':
        CareerService.dismiss(ctx, r['reason'] as String? ?? 'Let go');
      case 'salary':
        CareerService.adjustSalary(ctx, (r['percent'] as num).toDouble());
      case 'performance':
        CareerService.adjustPerformance(ctx, (r['delta'] as num).toDouble());
      case 'promote':
        CareerService.promote(ctx, force: r['force'] as bool? ?? false);
      case 'switchEmployer':
        CareerService.switchEmployer(ctx, (r['percent'] as num).toDouble());
      case 'takeLoan':
        final product = c.loanProducts[r['product']]!;
        final amount = r['amount'] == 'remainingFees'
            ? EducationService.remainingFees(ctx)
            : (r['amount'] as num).toInt();
        if (amount > 0) {
          FinanceService.takeLoan(ctx, product, amount, courseEndMonthKey: EducationService.courseEndMonthKey(ctx));
        }
      case 'familySupport':
        final f = s.finance;
        final before = f.familySupportMonthly;
        f.familySupportMonthly = r['set'] is num
            ? (r['set'] as num).toInt()
            : (f.familySupportMonthly + (r['delta'] as num).toInt()).clamp(0, 1 << 30);
        ctx.outcomes.add('Family support ${formatRupees(before)} → ${formatRupees(f.familySupportMonthly)}/month');
      case 'scholarship':
        EducationService.awardScholarship(ctx, (r['share'] as num).toDouble(), r['name'] as String? ?? 'Scholarship');
      case 'schedule':
        final id = r['event'] as String;
        if (!s.story.queue.any((q) => q.eventId == id)) {
          s.story.queue.add(QueuedEvent(eventId: id, dueDay: s.day + ((r['inDays'] as num?)?.toInt() ?? 0)));
        }
      case 'delayed':
        s.scheduled.add(ScheduledEffects(
          dueDay: s.day + (r['inDays'] as num).toInt(),
          note: r['note'] as String,
          effects: effect.nested.map((e) => e.raw).toList(),
        ));
      case 'relocate':
        final city = c.hometowns[r['city']]!;
        s.profile.currentCityId = city.id;
        if (r['independent'] == true) s.flags.add('living_independently');
        ctx.outcomes.add('Moved to ${city.name}');
      case 'endChapter':
        ConclusionService.conclude(ctx);
      case 'achievement':
        AchievementService.unlock(ctx, r['id'] as String);
      case 'roll':
        // Seeded randomness: uncertain for the player, reproducible in replays.
        final key = r['key'] as String;
        s.flags.remove(key);
        if (ctx.rng.chance((r['chance'] as num).toDouble())) s.flags.add(key);
      case 'if':
        applyAll(ctx, effect.when!.evaluate(s, c) ? effect.nested : effect.otherwise);
      case 'programSkill':
        final program = c.programs[s.education.programId] ??
            (s.education.completedPrograms.isEmpty ? null : c.programs[s.education.completedPrograms.last]);
        if (program != null) {
          var delta = (r['delta'] as num).toDouble();
          if (delta > 0) delta *= ctx.modifier(ModifierKeys.skillGain);
          ctx.addSkill(program.gradeSkill, delta);
        }
      case 'giveItem':
        LifestyleService.give(ctx, c.shopItems[r['item']]!);
      case 'loseItem':
        LifestyleService.lose(ctx, itemId: r['item'] as String?, category: r['category'] as String?);
      case 'partner':
        HouseholdService.setPartner(ctx, r['npc'] as String, r['status'] as String);
      case 'partnerStatus':
        final status = r['status'] as String;
        if (status == 'single' || s.household.partnerId != null) HouseholdService.setStatus(ctx, status);
      case 'haveChild':
        HouseholdService.haveChild(ctx, r['name'] as String);
      case 'creator':
        CreatorService.adjust(ctx,
            subsPercent: (r['subsPercent'] as num?)?.toDouble() ?? 0, views: (r['views'] as num?)?.toInt() ?? 0);
      default:
        throw StateError('Unhandled effect type ${effect.type}');
    }
  }
}
