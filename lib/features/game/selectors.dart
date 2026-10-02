import '../../engine/content/content_bundle.dart';
import '../../engine/core/game_calendar.dart';
import '../../engine/education/education_models.dart';
import '../../engine/game_state.dart';

int ageOf(GameState s) => GameCalendar.ageOn(s.profile.birthDate, s.day);

String weekdayOf(int day) =>
    const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][GameCalendar.dateOf(day).weekday - 1];

/// A one-line "what matters now" objective for the home dashboard.
({String title, String detail}) currentObjective(GameState s, ContentBundle c) {
  final e = s.education;
  final program = c.programs[e.programId];
  if (s.chapter > 1 && s.career.hasCareer) {
    final career = c.careers[s.career.careerId]!;
    return (
      title: '${career.ladder[s.career.level].title}${s.career.employer == null ? '' : ' · ${s.career.employer}'}',
      detail: 'Chapter 1 is complete. Keep building: skills, savings and relationships carry into what comes next.',
    );
  }
  if (s.flags.contains('intent_engineering') && e.status == EducationStatus.none) {
    final attempts = s.exams['utat']?.attempts.length ?? 0;
    final examDay = attempts == 0 ? 50 : 415;
    if (s.day < examDay) {
      return (
        title: 'Prepare for UTAT — ${GameCalendar.formatDay(examDay)}',
        detail: 'Practise in the Exam Centre and study at the library. The paper counts for 70%; your preparation for 30%.',
      );
    }
    return (title: 'UTAT results are on the way', detail: 'Keep your options open while you wait.');
  }
  if (e.status == EducationStatus.none) {
    return (
      title: 'Admissions open around ${GameCalendar.formatDay(60)}',
      detail: 'Use the weeks before college to build habits, savings and friendships.',
    );
  }
  if (e.isEnrolled && program != null) {
    final sem = (e.monthsCompleted ~/ 6 + 1).clamp(1, program.semesters);
    return (
      title: '${program.shortName} · semester $sem of ${program.semesters}',
      detail: e.semesterGpas.isEmpty
          ? 'Exams come every six months. Study, rest and relationships all affect your grades.'
          : 'CGPA ${e.cgpa.toStringAsFixed(2)}${e.backlogs > 0 ? ' · ${e.backlogs} backlog(s) to clear' : ''}',
    );
  }
  if (e.status == EducationStatus.graduated && !s.career.hasCareer) {
    return (title: 'Find your first job', detail: 'Interviews combine a puzzle round with your skills and communication.');
  }
  if (s.career.hasCareer) {
    final career = c.careers[s.career.careerId]!;
    return (title: career.ladder[s.career.level].title, detail: 'Performance ${s.career.performance.round()} / 100');
  }
  return (title: 'Find your footing', detail: 'Every chapter begins exactly where you are.');
}
