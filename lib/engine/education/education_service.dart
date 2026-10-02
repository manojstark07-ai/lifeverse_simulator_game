import '../character/stats.dart';
import '../core/game_calendar.dart';
import '../core/money.dart';
import '../engine_context.dart';
import '../finance/finance_service.dart';
import '../game_events.dart';
import '../journal/journal.dart';
import 'education_models.dart';

class EducationService {
  const EducationService._();

  static const passGpa = 5.0;
  static const backlogClearGpa = 6.5;
  static const reExamFee = 2000;

  static int semesterFee(EngineContext ctx, EducationProgram p, InstitutionTier t) =>
      ((t.feesPerYear / 2) * (1 - ctx.s.education.scholarshipShare)).round();

  /// Total fees still to be paid for the current program.
  static int remainingFees(EngineContext ctx) {
    final e = ctx.s.education;
    final p = ctx.c.programs[e.programId];
    final t = p?.tier(e.tierId ?? '');
    if (p == null || t == null || !e.isEnrolled) return 0;
    final remaining = p.semesters - e.feesPaidSemesters;
    return remaining <= 0 ? 0 : remaining * semesterFee(ctx, p, t);
  }

  static int? courseEndMonthKey(EngineContext ctx) {
    final e = ctx.s.education;
    final p = ctx.c.programs[e.programId];
    if (p == null || !e.isEnrolled) return null;
    return GameCalendar.monthKeyOfDay(e.startDay) + p.durationMonths;
  }

  static void enroll(EngineContext ctx, EducationProgram p, String tierId) {
    final e = ctx.s.education;
    if (e.isEnrolled) throw StateError('Already enrolled in ${e.programId}');
    final tier = p.tier(tierId);
    if (tier == null) throw StateError('No tier $tierId for ${p.id}');
    e
      ..programId = p.id
      ..tierId = tier.id
      ..status = EducationStatus.enrolled
      ..startDay = ctx.s.day
      ..monthsCompleted = 0
      ..semesterGpas = []
      ..backlogs = 0
      ..feesPaidSemesters = 0;
    ctx.s.flags.add('enrolled_${p.id}');
    ctx.outcomes.add('Enrolled: ${p.shortName} at a ${tier.name}');
    ctx.journal('Enrolled in ${p.shortName}',
        'Joined ${p.name} (${tier.name}). Annual fees ${formatRupees(tier.feesPerYear)}.', JournalKind.education,
        important: true);
    _chargeSemester(ctx, p, tier);
  }

  static void _chargeSemester(EngineContext ctx, EducationProgram p, InstitutionTier tier, [MonthLedger? ledger]) {
    final fee = semesterFee(ctx, p, tier);
    ctx.payMandatory(fee, 'fees', '${p.shortName} semester fees', record: ledger == null);
    ledger?.addExpense(fee, '${p.shortName} semester fees');
    ctx.s.education.feesPaidSemesters++;
  }

  /// Applies a fee scholarship and refunds its share of semesters already
  /// paid, so the order of story events never changes the total cost.
  static void awardScholarship(EngineContext ctx, double share, String name) {
    final e = ctx.s.education;
    final p = ctx.c.programs[e.programId];
    final t = p?.tier(e.tierId ?? '');
    final before = e.scholarshipShare;
    e.scholarshipShare = share.clamp(0, 1).toDouble();
    e.scholarshipName = name;
    ctx.s.flags.add('scholarship');
    ctx.outcomes.add('$name covers ${(share * 100).round()}% of fees');
    if (p != null && t != null && e.feesPaidSemesters > 0 && share > before) {
      final refund = ((t.feesPerYear / 2) * (share - before) * e.feesPaidSemesters).round();
      ctx.credit(refund, 'scholarship', '$name refund');
    }
  }

  static void dropOut(EngineContext ctx) {
    final e = ctx.s.education;
    if (!e.isEnrolled) return;
    final p = ctx.c.programs[e.programId]!;
    e.status = EducationStatus.dropped;
    ctx.s.flags.add('dropped_${p.id}');
    final grace = ctx.c.loanProducts.values.where((l) => l.kind == 'education').map((l) => l.graceMonths).fold(6, (a, b) => a < b ? a : b);
    FinanceService.endMoratoriumEarly(ctx, grace);
    ctx.outcomes.add('Left ${p.shortName}');
    ctx.journal('Left ${p.shortName}', 'Stepped away from ${p.name} after ${e.monthsCompleted} months.',
        JournalKind.education, important: true);
  }

  /// Monthly academic progress, semester results and graduation.
  static void settleMonth(EngineContext ctx, MonthLedger ledger, double efficiency) {
    final s = ctx.s;
    final e = s.education;
    if (!e.isEnrolled) return;
    final p = ctx.c.programs[e.programId]!;
    final tier = p.tier(e.tierId!)!;

    // Coursework builds knowledge and the program's skills.
    final kGain = p.knowledgeGainPerMonth * efficiency * (1 - s.stat(StatKeys.knowledge) / 140) *
        ctx.modifier(ModifierKeys.knowledgeGain);
    ctx.addStat(StatKeys.knowledge, kGain, record: false);
    p.skillGainsPerMonth.forEach((skill, gain) {
      ctx.addSkill(skill, gain * efficiency * (1 - s.skill(skill) / 130) * ctx.modifier(ModifierKeys.skillGain),
          record: false);
    });

    e.monthsCompleted++;
    if (e.monthsCompleted % 6 != 0) return;

    // Semester examinations.
    final gpa = semesterGpa(ctx, p);
    final inExtension = e.monthsCompleted > p.durationMonths;
    if (!inExtension) e.semesterGpas.add(gpa);
    final sem = e.semesterGpas.length;
    if (inExtension) {
      if (gpa >= passGpa && e.backlogs > 0) e.backlogs--;
      ctx.payMandatory(reExamFee, 'fees', 'Backlog re-examination fee', record: false);
      ledger.addExpense(reExamFee, 'Backlog re-examination fee');
    } else if (gpa < passGpa) {
      e.backlogs++;
      s.flags.add('had_backlog');
      ctx.emit(Notice('Semester $sem: GPA ${gpa.toStringAsFixed(1)}. You have a backlog to clear.', warning: true));
    } else if (e.backlogs > 0 && gpa >= backlogClearGpa) {
      e.backlogs--;
    }
    if (!inExtension) {
      ctx.journal('Semester $sem results', '${p.shortName}: GPA ${gpa.toStringAsFixed(2)}'
          '${e.backlogs > 0 ? ' (backlogs: ${e.backlogs})' : ''}.', JournalKind.education);
      ledger.lines.add('Semester $sem GPA ${gpa.toStringAsFixed(2)}');
    }

    if (e.monthsCompleted >= p.durationMonths) {
      if (e.backlogs == 0) {
        _graduate(ctx, p);
      } else if (!inExtension) {
        ctx.emit(Notice('Graduation delayed: clear ${e.backlogs} backlog(s) in the next exam cycle.', warning: true));
      }
    } else {
      _chargeSemester(ctx, p, tier, ledger);
    }
  }

  static double semesterGpa(EngineContext ctx, EducationProgram p) {
    final s = ctx.s;
    var gpa = 2.6 +
        s.stat(StatKeys.knowledge) * 0.045 +
        s.skill(p.gradeSkill) * 0.03 +
        s.stat(StatKeys.discipline) * 0.015 +
        (s.stat(StatKeys.energy) - 50) * 0.01 +
        ctx.rng.noise(0.4);
    if (s.flags.remove('semester_boost')) gpa += 0.6;
    if (s.flags.remove('semester_penalty')) gpa -= 0.6;
    return gpa.clamp(0, 10).toDouble();
  }

  static void _graduate(EngineContext ctx, EducationProgram p) {
    final e = ctx.s.education;
    e.status = EducationStatus.graduated;
    e.completedPrograms.add(p.id);
    ctx.s.flags.add('graduated_${p.id}');
    ctx.journal('Graduated!', 'Completed ${p.name} with a CGPA of ${e.cgpa.toStringAsFixed(2)}.',
        JournalKind.milestone, important: true);
    ctx.emit(Notice('You graduated from ${p.shortName}! CGPA ${e.cgpa.toStringAsFixed(2)}.'));
  }
}
