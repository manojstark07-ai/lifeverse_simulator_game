import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/puzzles/puzzle.dart';
import 'package:lifeverse/engine/story/story_engine.dart';

import '../support/content.dart';
import '../support/play.dart';

/// Answers every puzzle correctly.
ChallengeResult perfect(List<Puzzle> puzzles) => ChallengeResult(puzzles
    .map((p) => PuzzleAnswer(puzzleId: p.id, response: p.answer, correct: true, secondsTaken: 10))
    .toList());

void main() {
  final content = loadContent();
  final engine = GameEngine(content);

  /// Plays the active event to its end: challenges answered perfectly,
  /// otherwise the first enabled choice.
  GameState finishEvent(GameState s) {
    var state = s;
    var guard = 0;
    while (state.story.inEvent && guard++ < 30) {
      if (state.story.pendingChallengeChoiceId != null) {
        state = engine.resolveChallenge(state, perfect(engine.pendingChallengePuzzles(state))).state;
        continue;
      }
      final view = engine.currentNode(state)!;
      if (view.node.isTerminal) {
        state = engine.choose(state, StoryEngine.continueId).state;
      } else {
        state = engine.choose(state, view.choices.firstWhere((c) => c.enabled).choice.id).state;
      }
    }
    return state;
  }

  /// Advances day by day, playing through other events, until [eventId] starts.
  GameState advanceTo(GameState s, String eventId) {
    var state = s;
    for (var i = 0; i < 60; i++) {
      if (state.story.activeEventId == eventId) return state;
      state = state.story.inEvent ? finishEvent(state) : engine.endDay(state).state;
    }
    fail('$eventId never started');
  }

  GameState richAdult() {
    final s = finishOpening(engine, newGame(engine), path: 'c_commerce');
    s.flags.add('mature_on');
    s.finance
      ..cash = 5000000
      ..hasBankAccount = true;
    return s;
  }

  test('NEXT-Med: register, sit the paper, win a government MBBS seat', () {
    var s = richAdult();
    s.stats['knowledge'] = 70;
    s = engine.performAction(s, 'reg_next_med').state;
    expect(s.flags, contains('reg_next_med'));

    s = advanceTo(s, 'ev_x_next_med');
    s = engine.choose(s, 'c_sit').state;
    s = engine.resolveChallenge(s, perfect(engine.pendingChallengePuzzles(s))).state;
    expect(s.exams['next_med']!.latest!.tierId, 'government');
    s = finishEvent(s);

    s = advanceTo(s, 'ev_r_next_med');
    s = engine.choose(s, 'c_check').state;
    expect(s.story.activeNodeId, 'government');
    s = engine.choose(s, 'c_mbbs_government').state;
    expect(s.education.programId, 'mbbs');
    expect(s.education.tierId, 'government');
  });

  test('a government exam result hires straight into the service', () {
    var s = richAdult();
    s.education.completedPrograms.add('bcom');
    s.day = 365 * 4; // aged 22
    s.story.activeEventId = 'ev_r_use';
    s.story.activeNodeId = 'admin';
    s = engine.choose(s, 'c_ias_officer').state;
    expect(s.career.careerId, 'ias_officer');
    expect(s.flags, contains('govt_job'));
  });

  test('a police record locks government exams until rehabilitation', () {
    var s = richAdult();
    s.education.completedPrograms.add('bcom');
    s.day = 365 * 4;
    expect(engine.actionBlocker(s, content.actions['reg_use']!), isNull);
    s.flags.add('police_record');
    expect(engine.actionBlocker(s, content.actions['reg_use']!), 'Not available');
    for (var i = 0; i < 6; i++) {
      s = finishEvent(engine.performAction(s, 'police_rehab').state);
      s = finishEvent(engine.endDay(s).state);
    }
    expect(s.flags, isNot(contains('police_record')));
    expect(s.flags, contains('reformed'));
    expect(engine.actionBlocker(s, content.actions['reg_use']!), isNull);
  });

  test('serving a jail term costs the job and passes the time', () {
    var s = richAdult();
    s.career
      ..careerId = 'retail_associate'
      ..monthlySalary = 15000;
    final day = s.day;
    s.story.activeEventId = 'ev_arrest_serious';
    s.story.activeNodeId = 'start';
    s = engine.choose(s, 'c_accept').state;
    expect(s.career.careerId, isNull);
    expect(s.flags, containsAll(['police_record', 'served_time']));
    s = engine.choose(s, 'c_time').state;
    expect(s.day - day, greaterThanOrEqualTo(365));
  });

  test('crime and gambling can be played repeatedly without breaking the game', () {
    var s = richAdult();
    s.skills['streetwise'] = 50;
    for (var day = 0; day < 40; day++) {
      for (final id in ['crime_pickpocket', 'gamble_roulette']) {
        if (s.story.inEvent) s = finishEvent(s);
        if (engine.actionBlocker(s, content.actions[id]!) == null) s = engine.performAction(s, id).state;
      }
      s = s.story.inEvent ? finishEvent(s) : engine.endDay(s).state;
    }
    expect(s.counter('crimes'), greaterThan(0));
    expect(s.counter('gambles'), greaterThanOrEqualTo(20));
    expect(s.flags, contains('gambling_addict'));
  });

  test('every choice in every new event resolves cleanly', () {
    final base = richAdult();
    base.stats['wellbeing'] = 40;
    final prefixes = ['ev_x_', 'ev_r_', 'ev_arrest_', 'ev_crime_', 'ev_loan_shark', 'ev_p_'];
    final events = content.events.values.where((e) => prefixes.any(e.id.startsWith)).toList();
    expect(events.length, greaterThan(40));
    var resolved = 0;
    for (final event in events) {
      for (final node in event.nodes.values.where((n) => !n.isTerminal)) {
        final probe = base.clone()
          ..story.activeEventId = event.id
          ..story.activeNodeId = node.id;
        for (final view in engine.currentNode(probe)!.choices.where((c) => c.enabled)) {
          final s = base.clone()
            ..story.activeEventId = event.id
            ..story.activeNodeId = node.id;
          expect(() => finishEvent(engine.choose(s, view.choice.id).state), returnsNormally,
              reason: '${event.id}/${node.id}/${view.choice.id}');
          resolved++;
        }
      }
    }
    expect(resolved, greaterThan(150));
  });

  test('every new activity can be performed when available', () {
    final base = richAdult();
    base.skills['streetwise'] = 60;
    final prefixes = ['reg_', 'coach_', 'crime_', 'gamble_', 'police_', 'pt_ask_', 'hosp_', 'home_', 'park_', 'library_'];
    var performed = 0;
    for (final a in content.actions.values.where((a) => prefixes.any(a.id.startsWith))) {
      if (engine.actionBlocker(base, a) != null) continue;
      expect(() => engine.performAction(base, a.id), returnsNormally, reason: a.id);
      performed++;
    }
    expect(performed, greaterThan(40));
  });
}
