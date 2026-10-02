import 'dart:math' as math;

import '../character/stats.dart';
import '../content/content_bundle.dart';
import '../core/money.dart';
import '../core/rng.dart';
import '../engine_context.dart';
import '../finance/finance_service.dart';
import '../game_events.dart';
import '../game_state.dart';
import '../journal/journal.dart';
import '../puzzles/puzzle.dart';
import '../puzzles/puzzle_selector.dart';
import 'career_models.dart';

class CareerService {
  const CareerService._();

  static void startPartTime(EngineContext ctx, PartTimeJob job) {
    final c = ctx.s.career;
    if (c.hasCareer) throw StateError('Already working full time');
    c.partTimeJobId = job.id;
    ctx.outcomes.add('Started: ${job.name} at ${job.employer}');
    ctx.journal('New part-time job', '${job.name} at ${job.employer}, ${job.weeklyHours.round()} h/week.',
        JournalKind.career, important: true);
  }

  static void quitPartTime(EngineContext ctx) {
    final id = ctx.s.career.partTimeJobId;
    if (id == null) return;
    ctx.s.career.partTimeJobId = null;
    ctx.outcomes.add('Left part-time job');
    ctx.journal('Left part-time job', 'Stopped working at ${ctx.c.partTimeJobs[id]?.employer ?? id}.',
        JournalKind.career);
  }

  /// Weighted interview score in 0..1. Puzzle performance dominates, but
  /// skills, communication and institution reputation all count, so neither
  /// a degree nor a lucky answer guarantees an offer.
  static double interviewScore(EngineContext ctx, Career career, ChallengeResult result) {
    final s = ctx.s;
    final tier = ctx.c.programs[s.education.programId]?.tier(s.education.tierId ?? '');
    final reputation = tier?.reputation ?? 0.3;
    var score = result.fraction * 0.5 +
        s.skill(career.primarySkill) / 100 * 0.25 +
        s.stat(StatKeys.communication) / 100 * 0.15 +
        reputation * 0.1;
    for (final m in ctx.c.interviewModifiers.values) {
      if (m.when.evaluate(s, ctx.c)) {
        score += m.delta;
        ctx.outcomes.add(m.reason);
      }
    }
    return score;
  }

  /// Threshold eases slightly when the job market wants this profession.
  static double interviewThreshold(Career career) => 0.55 - career.demand * 0.1;

  static void hire(EngineContext ctx, Career career, {String? employer, double salaryMultiplier = 1}) {
    final c = ctx.s.career;
    if (c.partTimeJobId != null) quitPartTime(ctx);
    final s = ctx.s;
    final tier = ctx.c.programs[s.education.programId]?.tier(s.education.tierId ?? '');
    final reputationBonus = 1 + ((tier?.reputation ?? 0.3) - 0.5) * 0.2;
    final wage = ctx.c.hometowns[s.profile.currentCityId]?.wageMultiplier ?? 1;
    final salary = (career.ladder.first.monthlySalary * reputationBonus * salaryMultiplier * wage / 100).round() * 100;
    c
      ..careerId = career.id
      ..level = 0
      ..monthsInRole = 0
      ..performance = 55
      ..monthlySalary = salary
      ..employer = employer ?? c.employer;
    c.history.add('${career.ladder.first.title} — ${employer ?? career.name}');
    s.flags.add('hired');
    s.flags.add('hired_${career.id}');
    s.finance.familySupportMonthly = 0;
    ctx.outcomes.add('Hired as ${career.ladder.first.title} (${formatRupees(salary)}/month)');
    ctx.journal(c.history.length > 1 ? 'New job' : 'First job offer accepted',
        '${career.ladder.first.title}${employer == null ? '' : ' at $employer'}. Salary ${formatRupees(salary)} a month.',
        JournalKind.career,
        important: true);
  }

  // ---------------------------------------------------------- job portal --

  static const applicationCooldownDays = 30;
  static const interviewQuestions = 3;
  static const interviewEnergy = 10.0;

  static int? lastApplicationDay(GameState s, String careerId) {
    final v = s.counters['applied:$careerId'];
    return v == null ? null : v - 1;
  }

  static bool qualified(GameState s, ContentBundle c, Career career) =>
      !career.needsQualification || career.requiredPrograms.any(s.education.completedPrograms.contains);

  /// Why the player cannot apply for [career] right now, or null.
  static String? applicationBlocker(GameState s, ContentBundle c, Career career) {
    if (!career.listed) return 'Not hiring through the portal';
    if (s.story.inEvent) return 'Finish the current story event first';
    if (s.career.careerId == career.id) return 'You already work in this field';
    if (s.education.isEnrolled) return 'Finish or leave your course first';
    if (!qualified(s, c, career)) {
      return 'Needs ${career.requiredPrograms.map((p) => c.programs[p]?.shortName ?? p).join(' or ')}';
    }
    if (!career.requires.evaluate(s, c)) return career.requirementNote ?? 'Requirements not met';
    if (s.skill(career.primarySkill) < career.minPrimarySkill) {
      return 'Needs ${SkillKeys.labels[career.primarySkill]} ${career.minPrimarySkill.round()}+';
    }
    final last = lastApplicationDay(s, career.id);
    if (last != null && s.day - last < applicationCooldownDays) {
      return 'You can reapply in ${applicationCooldownDays - (s.day - last)} days';
    }
    if (s.actionsToday >= GameState.maxActionsPerDay) return 'No time left today';
    if (s.stat(StatKeys.energy) < interviewEnergy) return 'Too tired for an interview';
    return null;
  }

  /// The interview round for [career] today. Deterministic and free of
  /// game randomness, so opening and closing the screen changes nothing.
  static List<Puzzle> interviewPuzzles(GameState s, ContentBundle c, Career career) {
    // A stable string hash: String.hashCode differs between platforms.
    final salt = career.id.codeUnits.fold(17, (h, u) => (h * 31 + u) & 0x7FFFFFFF);
    final rng = Rng(s.seed ^ (s.day * 2654435) ^ salt);
    return PuzzleSelector.stratified(c.pool(career.interviewPool), interviewQuestions, rng);
  }

  /// Scores a job-portal interview and hires on success. Returns whether an
  /// offer was made.
  static bool apply(EngineContext ctx, Career career, ChallengeResult result) {
    final s = ctx.s;
    final blocker = applicationBlocker(s, ctx.c, career);
    if (blocker != null) throw StateError(blocker);
    final expected = interviewPuzzles(s, ctx.c, career).map((p) => p.id).toSet();
    if (result.answers.isEmpty || result.answers.any((a) => !expected.contains(a.puzzleId))) {
      throw StateError('Answers do not match the interview');
    }
    ctx.addStat(StatKeys.energy, -interviewEnergy, record: false);
    s.actionsToday++;
    s.counters['applied:${career.id}'] = s.day + 1;
    s.counters['interviews'] = s.counter('interviews') + 1;
    for (final a in result.answers) {
      if (a.correct) s.solvedPuzzles.add(a.puzzleId);
    }
    final score = interviewScore(ctx, career, result);
    final passed = score >= interviewThreshold(career);
    ctx.outcomes.insert(0, 'Interview score ${(score * 100).round()} — ${passed ? 'offer' : 'no offer'}');
    final employer = career.employers.isEmpty ? null : career.employers[ctx.rng.nextInt(career.employers.length)];
    if (passed) {
      if (s.creator?.fullTime ?? false) s.creator!.fullTime = false;
      hire(ctx, career, employer: employer);
    } else {
      ctx.addStat(StatKeys.wellbeing, -1);
      ctx.journal('No offer', '${career.ladder.first.title}${employer == null ? '' : ' at $employer'}: not this time.',
          JournalKind.career);
    }
    return passed;
  }

  /// Resigns from the current full-time job.
  static void quit(EngineContext ctx) {
    final s = ctx.s;
    final c = s.career;
    final career = ctx.c.careers[c.careerId] ?? (throw StateError('You do not have a full-time job'));
    if (s.story.inEvent) throw StateError('Finish the current story event first');
    final title = career.ladder[c.level].title;
    c.history.add('Resigned: $title');
    c
      ..careerId = null
      ..level = 0
      ..monthsInRole = 0
      ..monthlySalary = 0
      ..performance = 50
      ..employer = null;
    s.flags.add('quit_job');
    ctx.outcomes.add('Resigned as $title');
    ctx.journal('Resigned', 'You left your job as $title.', JournalKind.career, important: true);
  }

  /// Ends the full-time job (and any part-time one) without the player
  /// choosing to: an arrest, a jail term, a scandal. Does nothing when
  /// unemployed.
  static void dismiss(EngineContext ctx, String reason) {
    final s = ctx.s;
    if (s.career.partTimeJobId != null) quitPartTime(ctx);
    final career = ctx.c.careers[s.career.careerId];
    if (career == null) return;
    final title = career.ladder[s.career.level].title;
    s.career.history.add('$reason: $title');
    s.career
      ..careerId = null
      ..level = 0
      ..monthsInRole = 0
      ..monthlySalary = 0
      ..performance = 50
      ..employer = null;
    s.flags.add('lost_job');
    ctx.outcomes.add('Lost your job as $title');
    ctx.journal('Lost the job', '$reason. You are no longer $title.', JournalKind.career, important: true);
  }

  static void adjustSalary(EngineContext ctx, double percent) {
    final c = ctx.s.career;
    if (!c.hasCareer) return;
    final before = c.monthlySalary;
    c.monthlySalary = (c.monthlySalary * (1 + percent / 100) / 100).round() * 100;
    ctx.outcomes.add('Salary ${formatRupees(before)} → ${formatRupees(c.monthlySalary)}');
  }

  static void settleMonth(EngineContext ctx, MonthLedger ledger, double efficiency) {
    final s = ctx.s;
    final c = s.career;
    final city = ctx.c.hometowns[s.profile.currentCityId];

    final ptId = c.partTimeJobId;
    if (ptId != null) {
      final job = ctx.c.partTimeJobs[ptId]!;
      final pay = (job.monthlyPay * (city?.wageMultiplier ?? 1)).round();
      ctx.credit(pay, 'salary', job.name, record: false);
      ledger.addIncome(pay, '${job.name} pay');
      job.skillGainsPerMonth.forEach((k, v) => ctx.addSkill(k, v * efficiency, record: false));
      job.statGainsPerMonth.forEach((k, v) => ctx.addStat(k, v, record: false));
    }

    final careerId = c.careerId;
    if (careerId == null) return;
    final career = ctx.c.careers[careerId]!;
    ctx.credit(c.monthlySalary, 'salary', 'Salary', record: false);
    ledger.addIncome(c.monthlySalary, 'Salary — ${career.ladder[c.level].title}');
    career.skillGainsPerMonth.forEach((k, v) =>
        ctx.addSkill(k, v * efficiency * (1 - s.skill(k) / 130) * ctx.modifier(ModifierKeys.skillGain), record: false));
    c.monthsInRole++;
    c.monthsInCareer++;

    final target = 25 +
        s.skill(career.primarySkill) * 0.4 +
        s.stat(StatKeys.discipline) * 0.2 +
        s.stat(StatKeys.energy) * 0.1 +
        s.stat(StatKeys.wellbeing) * 0.1 +
        ctx.rng.noise(6);
    c.performance = (c.performance + (target - c.performance) * 0.3).clamp(0, 100).toDouble();

    if (c.monthsInRole % 12 == 0) _annualReview(ctx, career, ledger);
  }

  /// Whether the player meets the next rung's time, skill and performance
  /// bar. Null when already at the top of the ladder.
  static bool? readyForPromotion(GameState s, Career career) {
    final c = s.career;
    if (c.level + 1 >= career.ladder.length) return null;
    final next = career.ladder[c.level + 1];
    return c.monthsInRole >= next.minMonths && s.skill(career.primarySkill) >= next.skillRequired && c.performance >= 60;
  }

  /// Moves one rung up the ladder. Without [force] the player must be ready
  /// (see [readyForPromotion]); `force` is for story beats such as a funding
  /// round that make someone CEO. Returns whether a promotion happened.
  static bool promote(EngineContext ctx, {bool force = false}) {
    final s = ctx.s;
    final c = s.career;
    final career = ctx.c.careers[c.careerId];
    if (career == null) return false;
    final ready = readyForPromotion(s, career);
    if (ready == null) {
      ctx.outcomes.add('Already at the top of the ladder');
      return false;
    }
    if (!ready && !force) {
      ctx.outcomes.add('Not ready for promotion yet');
      return false;
    }
    final next = career.ladder[c.level + 1];
    c.level++;
    c.monthsInRole = 0;
    c.monthlySalary = math.max(c.monthlySalary + 1000, (next.monthlySalary *
            (ctx.c.hometowns[s.profile.currentCityId]?.wageMultiplier ?? 1) / 100).round() * 100);
    c.history.add(next.title);
    s.flags.add('promoted');
    ctx.outcomes.add('Promoted to ${next.title} (${formatRupees(c.monthlySalary)}/month)');
    ctx.journal('Promoted!', 'Now ${next.title}. Salary ${formatRupees(c.monthlySalary)}.', JournalKind.career,
        important: true);
    ctx.emit(Notice('Promotion: you are now ${next.title}!'));
    return true;
  }

  static void adjustPerformance(EngineContext ctx, double delta) {
    final c = ctx.s.career;
    if (!c.hasCareer) return;
    final before = c.performance;
    c.performance = (c.performance + delta).clamp(0, 100).toDouble();
    final change = (c.performance - before).round();
    if (change != 0) ctx.outcomes.add('Job performance ${change > 0 ? '+' : ''}$change');
  }

  /// Same job, new company: keeps the rung, changes the salary by [percent]
  /// and restarts the clock in role. Picks a different employer when the
  /// career lists one.
  static void switchEmployer(EngineContext ctx, double percent) {
    final s = ctx.s;
    final c = s.career;
    final career = ctx.c.careers[c.careerId];
    if (career == null) return;
    final others = career.employers.where((e) => e != c.employer).toList();
    final before = c.employer;
    if (others.isNotEmpty) c.employer = others[ctx.rng.nextInt(others.length)];
    c.monthlySalary = (c.monthlySalary * (1 + percent / 100) / 100).round() * 100;
    c.monthsInRole = 0;
    c.performance = math.max(c.performance, 55);
    final title = career.ladder[c.level].title;
    c.history.add('$title — ${c.employer ?? career.name}');
    s.flags.add('switched_employer');
    ctx.outcomes.add('Joined ${c.employer ?? 'a new employer'} (${formatRupees(c.monthlySalary)}/month)');
    ctx.journal('Changed companies',
        '$title${before == null ? '' : ', from $before'} to ${c.employer ?? 'a new employer'}. Salary ${formatRupees(c.monthlySalary)}.',
        JournalKind.career,
        important: true);
  }

  static void _annualReview(EngineContext ctx, Career career, MonthLedger ledger) {
    final s = ctx.s;
    final c = s.career;
    if (readyForPromotion(s, career) == true && promote(ctx)) {
      ledger.lines.add('Promoted to ${career.ladder[c.level].title}');
    } else if (c.performance >= 50) {
      final raise = (c.monthlySalary * 0.05 / 100).round() * 100;
      c.monthlySalary += raise;
      ledger.lines.add('Annual raise ${formatRupees(raise, signed: true)}');
      ctx.journal('Annual review', 'Solid year. Raise of ${formatRupees(raise)}.', JournalKind.career);
    } else {
      ledger.lines.add('Annual review: no raise this year');
      ctx.journal('Annual review', 'A difficult review. No raise this year.', JournalKind.career);
    }
  }
}
