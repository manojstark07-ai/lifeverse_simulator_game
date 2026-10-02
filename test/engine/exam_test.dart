import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/core/rng.dart';
import 'package:lifeverse/engine/exams/exam_service.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/puzzles/puzzle.dart';
import 'package:lifeverse/engine/puzzles/puzzle_selector.dart';

import '../support/content.dart';

ChallengeResult answer(List<Puzzle> paper, {required int right, int skip = 0}) {
  var i = 0;
  return ChallengeResult(paper.map((p) {
    final index = i++;
    if (index >= paper.length - skip) {
      return PuzzleAnswer(puzzleId: p.id, response: null, correct: false, secondsTaken: 0);
    }
    final ok = index < right;
    final response = p.type == PuzzleType.mcq ? (ok ? p.answer.toInt() : (p.answer.toInt() + 1) % p.options.length) : (ok ? p.answer : p.answer + 7);
    return PuzzleAnswer(puzzleId: p.id, response: response, correct: p.check(response), secondsTaken: 20);
  }).toList());
}

void main() {
  final content = loadContent();
  final engine = GameEngine(content);
  final exam = content.exams['utat']!;
  final paper = ExamService.generatePaper(content, exam, Rng(1));

  test('papers are stratified across categories and reproducible', () {
    expect(paper.length, exam.questionCount);
    expect(paper.map((p) => p.category).toSet().length, greaterThanOrEqualTo(5));
    expect(ExamService.generatePaper(content, exam, Rng(1)).map((p) => p.id), paper.map((p) => p.id));
    final other = ExamService.generatePaper(content, exam, Rng(2)).map((p) => p.id).toList();
    expect(other, isNot(equals(paper.map((p) => p.id).toList())));
  });

  test('negative marking: +4 / −1 / 0', () {
    expect(ExamService.performancePct(exam, answer(paper, right: 6)), 100);
    expect(ExamService.performancePct(exam, answer(paper, right: 0, skip: 6)), 0);
    // 4 right, 2 wrong = 16 − 2 = 14 of 24.
    expect(ExamService.performancePct(exam, answer(paper, right: 4)), closeTo(14 / 24 * 100, 1e-9));
    // All wrong clamps at zero rather than going negative.
    expect(ExamService.performancePct(exam, answer(paper, right: 0)), 0);
  });

  test('performance dominates: maximum preparation cannot carry a blank paper', () {
    final s = newGame(engine);
    for (final k in ['knowledge', 'discipline']) {
      s.stats[k] = 100;
    }
    s.skills['mathematics'] = 100;
    s.solvedPuzzles.addAll(content.pool('utat').map((p) => p.id));
    final blank = ExamService.score(s, content, exam, answer(paper, right: 0, skip: 6));
    expect(blank.preparationIndex, 100);
    expect(blank.tier.id, 'none');
  });

  test('a perfect paper earns a government seat even with modest preparation', () {
    final s = newGame(engine);
    final perfect = ExamService.score(s, content, exam, answer(paper, right: 6));
    expect(perfect.tier.id, 'government');
  });

  test('preparation shifts borderline results', () {
    final low = newGame(engine);
    final high = newGame(engine);
    high.stats['knowledge'] = 80;
    high.skills['mathematics'] = 60;
    high.solvedPuzzles.addAll(content.pool('utat').take(6).map((p) => p.id));
    final r = answer(paper, right: 4, skip: 1);
    final a = ExamService.score(low, content, exam, r);
    final b = ExamService.score(high, content, exam, r);
    expect(b.composite, greaterThan(a.composite));
    expect(exam.tierRank(b.tier.id), lessThanOrEqualTo(exam.tierRank(a.tier.id)));
  });

  test('adaptive practice prefers unsolved puzzles and harder ones when accurate', () {
    final pool = content.pool('utat');
    final easy = PuzzleSelector.adaptive(pool: pool, solved: {}, attempts: 0, correct: 0, rng: Rng(3))!;
    expect(easy.difficulty, 1);
    final hard = PuzzleSelector.adaptive(pool: pool, solved: {}, attempts: 10, correct: 9, rng: Rng(3))!;
    expect(hard.difficulty, 3);
    final solvedAllButOne = pool.skip(1).map((p) => p.id).toSet();
    final pick = PuzzleSelector.adaptive(pool: pool, solved: solvedAllButOne, attempts: 10, correct: 9, rng: Rng(3))!;
    expect(pick.id, pool.first.id);
  });

  test('numeric answers accept equivalent input and tolerance', () {
    final p = content.puzzles['iti_sem_01']!;
    expect(p.check('2.36'), isTrue);
    expect(p.check(' 2.365 '), isTrue);
    expect(p.check('2.4'), isFalse);
    expect(p.check('abc'), isFalse);
    expect(p.check(null), isFalse);
  });
}
