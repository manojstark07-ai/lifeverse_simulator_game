import 'package:lifeverse/engine/character/stats.dart';
import 'package:lifeverse/engine/core/rng.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/puzzles/puzzle.dart';
import 'package:lifeverse/engine/story/story_engine.dart';

typedef ChoicePicker = String? Function(NodeView view, GameState s);

/// Plays the game headlessly: answers puzzles with a given accuracy, picks
/// choices with a strategy, and fast-forwards time between events.
/// Used for long-running playthroughs and invariant checking.
class AutoPlayer {
  AutoPlayer(this.engine, {this.accuracy = 1.0, this.picker, int seed = 7, this.onStep})
      : rng = Rng(seed);

  final GameEngine engine;
  final double accuracy;
  final ChoicePicker? picker;
  final Rng rng;
  final void Function(GameState before, GameState after)? onStep;
  int steps = 0;

  GameState step(GameState s) {
    final GameState next;
    if (s.story.inEvent) {
      if (s.story.pendingChallengeChoiceId != null) {
        final answers = engine.pendingChallengePuzzles(s).map((p) {
          final right = rng.chance(accuracy);
          final response = p.type == PuzzleType.mcq
              ? (right ? p.answer.toInt() : (p.answer.toInt() + 1) % p.options.length)
              : (right ? p.answer : p.answer + 1);
          return PuzzleAnswer(puzzleId: p.id, response: response, correct: p.check(response), secondsTaken: 30);
        }).toList();
        next = engine.resolveChallenge(s, ChallengeResult(answers)).state;
      } else {
        final view = engine.currentNode(s)!;
        if (view.node.isTerminal) {
          next = engine.choose(s, StoryEngine.continueId).state;
        } else {
          final enabled = view.choices.where((c) => c.enabled).toList();
          final preferred = picker?.call(view, s);
          final id = enabled.any((c) => c.choice.id == preferred)
              ? preferred!
              : enabled[rng.nextInt(enabled.length)].choice.id;
          next = engine.choose(s, id).state;
        }
      }
    } else {
      next = engine.advance(s, untilNextMonth: true).state;
    }
    steps++;
    onStep?.call(s, next);
    return next;
  }

  /// Plays until chapter 1 concludes or [maxDays] pass.
  GameState playChapter(GameState s, {int maxDays = 365 * 7}) {
    var state = s;
    while (state.chapter == 1 && state.day < maxDays) {
      state = step(state);
    }
    return state;
  }
}

/// Invariants that must hold after every engine step.
List<String> invariantViolations(GameState before, GameState after) {
  final v = <String>[];
  if (after.day < before.day) v.add('time went backwards');
  if (after.finance.cash < 0) v.add('negative cash ${after.finance.cash}');
  if (after.finance.arrears < 0) v.add('negative arrears');
  for (final k in StatKeys.all) {
    final x = after.stat(k);
    if (x < 0 || x > 100 || x.isNaN) v.add('stat $k out of range: $x');
  }
  for (final e in after.skills.entries) {
    if (e.value < 0 || e.value > 100) v.add('skill ${e.key} out of range');
  }
  for (final r in after.relationships.values) {
    if (r.affinity < -100 || r.affinity > 100 || r.trust < 0 || r.trust > 100) v.add('relationship ${r.npcId} out of range');
  }
  for (final l in after.finance.loans) {
    if (l.outstanding < 0 || l.accruedInterest < 0) v.add('loan ${l.id} negative');
  }
  if (after.finance.creditScore < 300 || after.finance.creditScore > 900) v.add('credit score out of range');
  if (after.story.inEvent && after.story.activeNodeId == null) v.add('event without node');
  if (after.actionsToday > GameState.maxActionsPerDay) v.add('too many actions');
  if (after.lastSettledMonthKey < before.lastSettledMonthKey) v.add('settlement went backwards');
  final ids = after.journal.where((j) => j.title.startsWith('Achievement')).map((j) => j.title).toList();
  if (ids.toSet().length != ids.length) v.add('duplicate achievement unlock');
  return v;
}
