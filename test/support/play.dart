import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/puzzles/puzzle.dart';
import 'package:lifeverse/engine/story/story_engine.dart';

/// Plays the opening events with fixed choices until no event is active.
GameState finishOpening(GameEngine engine, GameState s, {String path = 'c_engineering'}) {
  var state = s;
  var guard = 0;
  while (state.story.inEvent && guard++ < 50) {
    final view = engine.currentNode(state)!;
    if (state.story.pendingChallengeChoiceId != null) {
      final answers = engine.pendingChallengePuzzles(state)
          .map((p) => PuzzleAnswer(puzzleId: p.id, response: null, correct: false, secondsTaken: 0))
          .toList();
      state = engine.resolveChallenge(state, ChallengeResult(answers)).state;
    } else if (view.node.isTerminal) {
      state = engine.choose(state, StoryEngine.continueId).state;
    } else {
      final ids = view.choices.where((c) => c.enabled).map((c) => c.choice.id).toList();
      state = engine.choose(state, ids.contains(path) ? path : ids.first).state;
    }
  }
  return state;
}

