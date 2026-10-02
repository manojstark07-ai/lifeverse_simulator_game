import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/character/player_profile.dart';
import 'package:lifeverse/engine/core/game_calendar.dart';
import 'package:lifeverse/engine/engine_context.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/time/life_simulation.dart';

import '../support/autoplayer.dart';
import '../support/content.dart';

void main() {
  final content = loadContent();
  final engine = GameEngine(content);
  final matureEvents = content.events.keys.where((id) => id.startsWith('ev_m_')).toSet();

  test('mature themes are on by default and can be switched off per life', () {
    final s = newGame(engine);
    expect(s.flags, contains('mature_on'));
    final off = engine.setMatureThemes(s, false).state;
    expect(off.flags, isNot(contains('mature_on')));
  });

  test('with mature themes off, no mature storyline ever fires', () {
    for (var seed = 1; seed <= 6; seed++) {
      final spec0 = spec(seed: seed * 13);
      final s = engine
          .newGame(CharacterSpec(
            name: spec0.name, pronouns: spec0.pronouns, appearance: spec0.appearance, hometownId: spec0.hometownId,
            backgroundId: spec0.backgroundId, traitIds: spec0.traitIds, interestIds: spec0.interestIds,
            ambitionId: spec0.ambitionId, seed: spec0.seed, matureThemes: false,
          ))
          .state;
      final end = AutoPlayer(engine, accuracy: 0.6, seed: seed).playChapter(s);
      expect(end.story.lastFiredDay.keys.toSet().intersection(matureEvents), isEmpty, reason: 'seed $seed');
    }
  });

  test('with mature themes on, random lives encounter mature storylines', () {
    final fired = <String>{};
    for (var seed = 1; seed <= 8; seed++) {
      final end = AutoPlayer(engine, accuracy: 0.6, seed: seed).playChapter(newGame(engine, seed: seed * 7));
      fired.addAll(end.story.lastFiredDay.keys.where(matureEvents.contains));
    }
    expect(fired.length, greaterThanOrEqualTo(5), reason: '$fired');
  });

  test('smoking costs money and well-being every month', () {
    final s = newGame(engine).clone()..flags.add('smoker');
    s.finance.familySupportMonthly = 0;
    final ctx = EngineContext(s, content);
    final cash = s.finance.cash;
    final wb = s.stat('wellbeing');
    LifeSimulation.settleMonth(ctx, GameCalendar.monthKeyOfDay(s.day));
    final living = LifeSimulation.livingCost(s, content);
    expect(cash - s.finance.cash, greaterThanOrEqualTo(living + 1500));
    expect(s.finance.transactions.any((t) => t.label == 'Cigarettes'), isTrue);
    expect(s.stat('wellbeing'), isNot(wb));
  });

  test('a police record lowers interview scores', () {
    final clean = newGame(engine);
    final record = newGame(engine).clone()..flags.add('police_record');
    double score(s) => content.interviewModifiers.values
        .where((m) => m.when.evaluate(s, content))
        .fold(0.0, (a, m) => a + m.delta);
    expect(score(record), lessThan(score(clean)));
  });

  test('the bar only appears for adults with mature themes on', () {
    final bar = content.locations['bar']!;
    final s = newGame(engine);
    expect(bar.requires.evaluate(s, content), isFalse, reason: 'player is 18');
    final older = s.clone()..day = 365 * 3 + 200;
    expect(bar.requires.evaluate(older, content), isTrue);
    older.flags.remove('mature_on');
    expect(bar.requires.evaluate(older, content), isFalse);
  });
}
