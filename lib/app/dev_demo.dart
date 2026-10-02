import 'package:flutter/foundation.dart';

import '../engine/character/player_profile.dart';
import '../engine/game_engine.dart';
import '../engine/game_state.dart';
import '../engine/puzzles/puzzle.dart';
import '../engine/story/story_engine.dart';

/// Debug-only demo launcher for screenshots and design review:
/// `flutter run --dart-define=LV_DEMO=/finance` seeds a life and opens that
/// route. `LV_DEMO=/story` opens results day; other routes first play the
/// life forward ~14 months (or to the chapter end for `/conclusion`).
const demoRoute = String.fromEnvironment('LV_DEMO');

GameState? buildDemoState(GameEngine engine) {
  if (!kDebugMode || demoRoute.isEmpty) return null;
  var s = engine
      .newGame(const CharacterSpec(
        name: 'Meera',
        pronouns: 'she/her',
        appearance: Appearance(skinTone: 3, hairStyle: 2, hairColor: 0, outfit: 0, accessory: 1),
        hometownId: 'chennai',
        backgroundId: 'urban_lower_middle',
        traitIds: ['curious', 'empathetic'],
        interestIds: ['technology', 'puzzles'],
        ambitionId: 'mastery',
        seed: 2026,
      ))
      .state;
  if (demoRoute == '/story') return s;
  final untilEnd = demoRoute == '/conclusion';
  const prefer = {'c_engineering', 'c_take', 'c_loan', 'c_try', 'c_there', 'c_invest', 'c_sit', 'c_accept_gov', 'c_accept_private', 'c_sw', 'c_accept'};
  var guard = 0;
  while (guard++ < 5000 && (untilEnd ? s.chapter == 1 : s.day < 420)) {
    if (s.story.pendingChallengeChoiceId != null) {
      // Answer every puzzle correctly so the demo life follows a strong path.
      final answers = engine.pendingChallengePuzzles(s).map((p) {
        final r = p.type == PuzzleType.mcq ? p.answer.toInt() : p.answer;
        return PuzzleAnswer(puzzleId: p.id, response: r, correct: true, secondsTaken: 20);
      }).toList();
      s = engine.resolveChallenge(s, ChallengeResult(answers)).state;
    } else if (s.story.inEvent) {
      final view = engine.currentNode(s)!;
      if (view.node.isTerminal) {
        s = engine.choose(s, StoryEngine.continueId).state;
      } else {
        final enabled = view.choices.where((c) => c.enabled).map((c) => c.choice.id).toList();
        s = engine.choose(s, enabled.firstWhere(prefer.contains, orElse: () => enabled.first)).state;
      }
    } else {
      s = engine.advance(s, days: 7).state;
    }
  }
  return s;
}
