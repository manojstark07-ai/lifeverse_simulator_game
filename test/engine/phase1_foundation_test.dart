import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/data/save_repository.dart';
import 'package:lifeverse/engine/core/game_calendar.dart';
import 'package:lifeverse/engine/engine_context.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/time/life_simulation.dart';

import '../support/content.dart';
import '../support/play.dart';

void main() {
  final content = loadContent();
  final engine = GameEngine(content);

  test('opening choices are deterministic for the same seed', () {
    final a = finishOpening(engine, newGame(engine, seed: 117));
    final b = finishOpening(engine, newGame(engine, seed: 117));
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    expect(GameCalendar.ageOn(a.profile.birthDate, a.day), 18);
  });

  test('delayed consequences apply once when their due day arrives', () {
    final s = finishOpening(engine, newGame(engine));
    s.scheduled.add(
      ScheduledEffects(
        dueDay: s.day + 2,
        note: 'Foundation test consequence',
        effects: [
          {'type': 'flag', 'key': 'phase1_delayed_test'},
        ],
      ),
    );
    final after = engine.advance(s, days: 2).state;
    expect(after.flags, contains('phase1_delayed_test'));
    expect(after.scheduled, isEmpty);
    expect(
      after.journal.where((j) => j.title == 'Foundation test consequence'),
      hasLength(1),
    );
  });

  test('month settlement is monotonic and idempotent', () {
    final s = finishOpening(engine, newGame(engine));
    s.chapter = 99;
    s.story.completed.addAll(content.events.keys);
    s.story.queue.clear();
    s.scheduled.clear();
    final ctx = EngineContext(s, content);
    final month = GameCalendar.monthKeyOfDay(s.day);
    LifeSimulation.settleMonth(ctx, month);
    final historyLength = s.finance.history.length;
    final cash = s.finance.cash;
    LifeSimulation.settleMonth(ctx, month);
    expect(s.finance.history.length, historyLength);
    expect(s.finance.cash, cash);
    expect(s.lastSettledMonthKey, month);
  });

  test('advance one year progresses toward the same calendar date', () {
    final s = finishOpening(engine, newGame(engine));
    s.chapter = 99;
    s.story.completed.addAll(content.events.keys);
    final current = GameCalendar.dateOf(s.day);
    final expected = GameCalendar.dayOf(
      DateTime.utc(current.year + 1, current.month, current.day),
    );

    final result = engine.advanceOneYear(s).state;

    expect(result.day, greaterThan(s.day));
    expect(result.day, lessThanOrEqualTo(expected));
  });

  test('a save round-trip preserves a mid-event foundation state', () async {
    final saves = InMemorySaveRepository();
    final state = engine.choose(newGame(engine), 'c_read').state;
    await saves.save(SaveRepository.autosaveSlot, state);
    final loaded = await saves.load(SaveRepository.autosaveSlot);
    expect(jsonEncode(loaded!.toJson()), jsonEncode(state.toJson()));
    expect(loaded.story.activeEventId, state.story.activeEventId);
    expect(loaded.story.activeNodeId, state.story.activeNodeId);
  });
}
