import '../core/json_utils.dart';

class PuzzleType {
  const PuzzleType._();
  static const mcq = 'mcq';
  static const numeric = 'numeric';
  static const all = [mcq, numeric];
}

class PuzzleCategory {
  const PuzzleCategory._();
  static const all = {
    'math': 'Mathematical reasoning',
    'logic': 'Logical deduction',
    'pattern': 'Pattern recognition',
    'reading': 'Reading comprehension',
    'programming': 'Programming',
    'science': 'Scientific problem solving',
    'case': 'Case study',
    'general': 'General awareness',
    'interview': 'Interview',
    'time': 'Time management',
    'debugging': 'Debugging',
    'accounting': 'Accounting investigation',
    'electrical': 'Electrical troubleshooting',
  };
}

/// An original, validated practice question. None of these are taken from
/// any official examination.
class Puzzle {
  Puzzle({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.pools,
    required this.type,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.tolerance,
    required this.explanation,
    required this.timeLimitSec,
    this.passage,
    this.unit,
  });

  factory Puzzle.fromJson(Json j) => Puzzle(
        id: req<String>(j, 'id'),
        category: req<String>(j, 'category'),
        difficulty: req<num>(j, 'difficulty').toInt(),
        pools: stringList(j['pools']),
        type: req<String>(j, 'type'),
        prompt: req<String>(j, 'prompt'),
        passage: j['passage'] as String?,
        options: stringList(j['options']),
        answer: req<num>(j, 'answer'),
        tolerance: optNum(j, 'tolerance', 0),
        explanation: req<String>(j, 'explanation'),
        timeLimitSec: optInt(j, 'timeLimitSec', 90),
        unit: j['unit'] as String?,
      );

  final String id;
  final String category;

  /// 1 (warm-up) .. 3 (hard).
  final int difficulty;
  final List<String> pools;
  final String type;
  final String prompt;

  /// Optional reading passage shown above the prompt.
  final String? passage;
  final List<String> options;

  /// Option index for `mcq`, numeric value for `numeric`.
  final num answer;
  final double tolerance;
  final String explanation;
  final int timeLimitSec;
  final String? unit;

  bool check(Object? response) {
    if (response == null) return false;
    if (type == PuzzleType.mcq) return response == answer.toInt();
    final value = response is num ? response : num.tryParse('$response'.trim());
    if (value == null) return false;
    return (value - answer).abs() <= tolerance + 1e-9;
  }

  String get answerText => type == PuzzleType.mcq
      ? options[answer.toInt()]
      : '${_fmt(answer)}${unit == null ? '' : ' $unit'}';

  static String _fmt(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

/// The outcome of one answered (or skipped) puzzle.
class PuzzleAnswer {
  const PuzzleAnswer({
    required this.puzzleId,
    required this.response,
    required this.correct,
    required this.secondsTaken,
  });

  final String puzzleId;
  final Object? response;
  final bool correct;
  final int secondsTaken;

  bool get skipped => response == null;
}

class ChallengeResult {
  const ChallengeResult(this.answers);

  final List<PuzzleAnswer> answers;

  int get correct => answers.where((a) => a.correct).length;
  int get wrong => answers.where((a) => !a.correct && !a.skipped).length;
  int get skipped => answers.where((a) => a.skipped).length;
  double get fraction => answers.isEmpty ? 0 : correct / answers.length;
}
