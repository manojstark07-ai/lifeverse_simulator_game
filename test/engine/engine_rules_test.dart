import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/character/stats.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_events.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/puzzles/puzzle.dart';
import 'package:lifeverse/engine/time/life_simulation.dart';
import 'package:lifeverse/engine/time/routine.dart';

import '../support/content.dart';
import '../support/play.dart';

void main() {
  final content = loadContent();
  final engine = GameEngine(content);

  test('a new game starts at 18, on results day, inside the first story event', () {
    final s = newGame(engine);
    expect(s.day, 0);
    expect(s.story.activeEventId, 'ev_results_day');
    expect(DateTime.utc(2026, 6, 1).difference(s.profile.birthDate).inDays ~/ 365, 18);
    for (final k in StatKeys.all) {
      expect(s.stat(k), inInclusiveRange(0, 100));
    }
  });

  test('character creation validates input', () {
    expect(() => engine.newGame(spec(background: 'nope')), throwsA(isA<RuleViolation>()));
    expect(() => engine.newGame(spec(traits: [])), throwsA(isA<RuleViolation>()));
    expect(() => engine.newGame(spec(traits: ['curious', 'steady', 'outgoing'])), throwsA(isA<RuleViolation>()));
  });

  test('backgrounds change resources but not knowledge', () {
    final rural = newGame(engine, background: 'rural_farming');
    final rich = newGame(engine, background: 'affluent_business');
    expect(rich.finance.cash, greaterThan(rural.finance.cash));
    expect(rich.stat(StatKeys.knowledge), rural.stat(StatKeys.knowledge));
  });

  test('operations are transactional: a rejected choice leaves state untouched', () {
    final s = newGame(engine);
    final before = jsonEncode(s.toJson());
    expect(() => engine.choose(s, 'does_not_exist'), throwsA(isA<RuleViolation>()));
    expect(() => engine.advance(s), throwsA(isA<RuleViolation>()), reason: 'cannot skip time mid-event');
    expect(jsonEncode(s.toJson()), before);
  });

  test('engine never mutates its input state', () {
    final s = newGame(engine);
    final before = jsonEncode(s.toJson());
    engine.choose(s, 'c_read');
    expect(jsonEncode(s.toJson()), before);
  });

  test('daily actions cost energy and are limited per day', () {
    var s = finishOpening(engine, newGame(engine));
    expect(s.story.inEvent, isFalse);
    final energy = s.stat(StatKeys.energy);
    s = engine.performAction(s, 'home_self_study').state;
    expect(s.stat(StatKeys.energy), lessThan(energy));
    s = engine.performAction(s, 'park_reflect').state;
    expect(() => engine.performAction(s, 'home_rest'), throwsA(isA<RuleViolation>()));
    s = engine.endDay(s).state;
    expect(s.actionsToday, 0);
  });

  test('exhaustion blocks demanding actions', () {
    var s = finishOpening(engine, newGame(engine));
    s.stats[StatKeys.energy] = 5;
    expect(engine.actionBlocker(s, content.actions['lib_study']!), 'Too tired');
    s = engine.performAction(s, 'home_rest').state;
    expect(s.stat(StatKeys.energy), greaterThan(5));
  });

  test('practice rewards are granted once per puzzle (no farming)', () {
    var s = finishOpening(engine, newGame(engine));
    final p = content.pool('utat').first;
    final right = ChallengeResult([PuzzleAnswer(puzzleId: p.id, response: p.answer.toInt(), correct: true, secondsTaken: 10)]);
    s = engine.recordPractice(s, right).state;
    final k1 = s.stat(StatKeys.knowledge);
    s = engine.endDay(s).state;
    s.stats[StatKeys.energy] = 90;
    s = engine.recordPractice(s, right).state;
    expect(s.stat(StatKeys.knowledge) - k1, lessThan(0.25), reason: 'only discipline/drift may change');
    expect(s.solvedPuzzles, contains(p.id));
  });

  test('routine is normalised to the hours actually available', () {
    var s = finishOpening(engine, newGame(engine));
    s = engine.setRoutine(s, Routine(study: 60, exercise: 20, social: 20, family: 20)).state;
    final b = RoutineBudget.of(s, content);
    expect(b.study + b.exercise + b.social + b.family, lessThanOrEqualTo(b.free + 1e-9));
    expect(() => engine.setRoutine(s, Routine(study: -1)), throwsA(isA<RuleViolation>()));
  });

  test('overwork lowers the energy target; rest raises it', () {
    var s = finishOpening(engine, newGame(engine));
    final relaxed = RoutineBudget.of(engine.setRoutine(s, Routine(study: 2)).state, content).energyTarget;
    final grinding = RoutineBudget.of(engine.setRoutine(s, Routine(study: 60)).state, content).energyTarget;
    expect(grinding, lessThan(relaxed));
  });

  test('advancing stops when a story event begins', () {
    final s = finishOpening(engine, newGame(engine));
    final r = engine.advance(s, days: 60);
    expect(r.state.story.inEvent, isTrue);
    expect(r.events.whereType<StoryEventStarted>(), isNotEmpty);
    expect(r.state.day, lessThan(60));
  });

  test('running out of money creates arrears and triggers the recovery event', () {
    var s = finishOpening(engine, newGame(engine, background: 'rural_farming'));
    s.finance.cash = 0;
    s.finance.familySupportMonthly = 0;
    var guard = 0;
    while (s.story.activeEventId != 'ev_money_crisis' && guard++ < 200) {
      if (s.story.inEvent) {
        s = finishOpening(engine, s, path: 'c_decline');
        s.finance.cash = 0;
        continue;
      }
      s = engine.advance(s, untilNextMonth: true).state;
      s.finance.cash = 0;
    }
    expect(s.story.activeEventId, 'ev_money_crisis');
    expect(s.finance.arrears, greaterThan(0));
    final view = engine.currentNode(s)!;
    expect(view.choices.where((c) => c.enabled).length, greaterThanOrEqualTo(2), reason: 'recovery options exist');
  });

  test('saving mid-challenge resumes the same generated puzzles', () {
    var s = finishOpening(engine, newGame(engine)); // engineering intent
    while (s.story.activeEventId != 'ev_entrance_exam') {
      s = s.story.inEvent ? finishOpening(engine, s, path: 'c_decline') : engine.advance(s, days: 30).state;
    }
    s = engine.choose(s, 'c_sit').state;
    final ids = s.story.pendingPuzzleIds;
    expect(ids.length, 6);
    final restored = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(restored.story.pendingPuzzleIds, ids);
    expect(engine.pendingChallengePuzzles(restored).map((p) => p.id), ids);
    expect(() => engine.choose(restored, 'c_sit'), throwsA(isA<RuleViolation>()), reason: 'no re-roll of the paper');
    final wrongIds = ChallengeResult([PuzzleAnswer(puzzleId: 'sw_logic_01', response: 8, correct: true, secondsTaken: 1)]);
    expect(() => engine.resolveChallenge(restored, wrongIds), throwsA(isA<RuleViolation>()));
  });

  test('delayed consequences land later and are journaled', () {
    var s = finishOpening(engine, newGame(engine));
    s = s.clone()
      ..scheduled.add(ScheduledEffects(dueDay: s.day + 3, note: 'A delayed test', effects: [
        {'type': 'stat', 'key': 'wellbeing', 'delta': -10}
      ]));
    final wb = s.stat(StatKeys.wellbeing);
    s = engine.advance(s, days: 2).state;
    expect(s.scheduled, isNotEmpty);
    s = engine.advance(s, days: 2).state;
    expect(s.scheduled, isEmpty);
    expect(s.journal.any((j) => j.title == 'A delayed test'), isTrue);
    expect(s.stat(StatKeys.wellbeing), lessThan(wb));
  });

  test('relationship memories persist and unlock story variants', () {
    var s = newGame(engine);
    s = engine.choose(s, 'c_read').state;
    s = engine.choose(s, 'c_engineering').state;
    final kavyaNode = engine.currentNode(s)!;
    expect(kavyaNode.text, contains('rivals'));
    s = engine.choose(s, 'c_promise').state;
    expect(s.relationships['kavya']!.affinity, greaterThan(content.npcs['kavya']!.startAffinity));
    expect(s.decisions.map((d) => d.choiceId), containsAllInOrder(['c_read', 'c_engineering', 'c_promise']));
  });

  test('living costs follow city, background habits and frugality', () {
    final s = newGame(engine, background: 'affluent_business');
    final base = LifeSimulation.livingCost(s, content);
    s.flags.add('frugal_mode');
    expect(LifeSimulation.livingCost(s, content), lessThan(base));
    final rural = newGame(engine, background: 'rural_farming');
    expect(LifeSimulation.livingCost(rural, content), lessThan(base));
  });
}
