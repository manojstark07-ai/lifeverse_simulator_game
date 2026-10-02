import '../content/content_bundle.dart';
import '../core/rng.dart';
import '../game_state.dart';
import '../puzzles/puzzle.dart';
import '../puzzles/puzzle_selector.dart';
import 'exam_models.dart';

class ExamScore {
  const ExamScore({
    required this.performancePct,
    required this.preparationIndex,
    required this.composite,
    required this.tier,
  });

  final double performancePct;
  final double preparationIndex;
  final double composite;
  final ExamTier tier;
}

/// Scores examinations from *both* the player's live puzzle performance and
/// their accumulated preparation. Neither alone decides the result.
class ExamService {
  const ExamService._();

  static List<Puzzle> generatePaper(ContentBundle c, ExamDefinition exam, Rng rng) =>
      PuzzleSelector.stratified(c.pool(exam.pool), exam.questionCount, rng);

  static double performancePct(ExamDefinition exam, ChallengeResult r) {
    final max = r.answers.length * exam.markCorrect;
    if (max <= 0) return 0;
    final raw = r.correct * exam.markCorrect + r.wrong * exam.markWrong;
    return (raw / max * 100).clamp(0, 100).toDouble();
  }

  static double preparationIndex(GameState s, ContentBundle c, ExamDefinition exam) {
    var prep = 0.0;
    exam.prepStats.forEach((k, w) => prep += s.stat(k) * w);
    exam.prepSkills.forEach((k, w) => prep += s.skill(k) * w);
    final solvedInPool = c.pool(exam.pool).where((p) => s.solvedPuzzles.contains(p.id)).length;
    final practice = solvedInPool * exam.practicePerSolve;
    prep += practice > exam.practiceCap ? exam.practiceCap : practice;
    return prep.clamp(0, 100).toDouble();
  }

  static ExamScore score(GameState s, ContentBundle c, ExamDefinition exam, ChallengeResult r) {
    final perf = performancePct(exam, r);
    final prep = preparationIndex(s, c, exam);
    final composite = perf * exam.performanceWeight + prep * exam.preparationWeight;
    return ExamScore(
      performancePct: perf,
      preparationIndex: prep,
      composite: composite,
      tier: exam.tierFor(composite),
    );
  }

  static ExamAttempt record(GameState s, ExamDefinition exam, ChallengeResult r, ExamScore score) {
    final attempt = ExamAttempt(
      day: s.day,
      correct: r.correct,
      wrong: r.wrong,
      skipped: r.skipped,
      performancePct: score.performancePct,
      preparationIndex: score.preparationIndex,
      composite: score.composite,
      tierId: score.tier.id,
    );
    s.exams.putIfAbsent(exam.id, () => ExamRecord(examId: exam.id)).attempts.add(attempt);
    return attempt;
  }
}
