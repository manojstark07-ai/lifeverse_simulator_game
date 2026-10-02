import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/data/cloud_sync.dart';
import 'package:lifeverse/engine/content/content_bundle.dart';
import 'package:lifeverse/engine/engine_context.dart';
import 'package:lifeverse/engine/finance/finance_service.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/life/life_system_service.dart';

import '../support/content.dart';
import '../support/play.dart';

void main() {
  final content = loadContent();
  final engine = GameEngine(content);

  test(
    'businesses, assets and retirement use the same transactional state',
    () {
      var state = finishOpening(engine, newGame(engine));
      state.finance.cash = 1000000;
      state = engine.startBusiness(state, 'Signal House', 'Technology').state;
      final venture = state.life.businesses.single;
      state = engine
          .runBusinessProject(state, venture.id, 'Civic dashboard', 12000)
          .state;
      state = finishOpening(engine, engine.endDay(state).state);
      state = engine.hireBusiness(state, venture.id).state;
      state = finishOpening(engine, engine.endDay(state).state);
      state = engine
          .buyProperty(
            state,
            name: 'Harbour apartment',
            kind: 'home',
            value: 250000,
            rent: 12000,
          )
          .state;
      state = finishOpening(engine, engine.endDay(state).state);
      state = engine.addInsurance(state, 'health').state;
      state = finishOpening(engine, engine.endDay(state).state);
      state = engine.contributeRetirement(state, 10000).state;

      expect(state.life.businesses.single.productStage, greaterThan(1));
      expect(state.life.properties, hasLength(1));
      expect(state.life.insurance, hasLength(1));
      expect(state.life.retirementBalance, 10000);
      expect(state.finance.cash, lessThan(1000000));
    },
  );

  test('monthly long-term settlement grows ventures and records tax due', () {
    var state = finishOpening(engine, newGame(engine, seed: 77));
    state.finance.cash = 500000;
    state = engine.startBusiness(state, 'Cedar Works', 'Design').state;
    final context = EngineContextForTest(state, content);
    LifeSystemService.settleMonth(context.ctx, context.ledger);

    expect(state.life.businesses.single.cash, greaterThan(50000));
    expect(state.life.taxesDue, greaterThan(0));
  });

  test(
    'chapters 1 through 6 can be concluded without overwriting history markers',
    () {
      var state = finishOpening(engine, newGame(engine, seed: 91));
      for (var expectedChapter = 1; expectedChapter <= 6; expectedChapter++) {
        state = engine.concludeChapter(state).state;
        expect(state.flags, contains('chapter${expectedChapter}_complete'));
        expect(state.chapter, expectedChapter + 1);
      }
    },
  );

  test('offline cloud adapter keeps the newest revision', () async {
    final provider = OfflineCloudSyncProvider();
    final cloud = CloudSyncService(provider);
    final state = newGame(engine);
    await cloud.reconcile(state.playthroughId, state, 1);
    final remote = await cloud.reconcile(state.playthroughId, state.clone(), 2);
    expect(remote.revision, 2);
  });

  test('New Life+ carries a previous life into the legacy archive', () {
    final previous = finishOpening(engine, newGame(engine, seed: 111));
    previous.finance.cash = 200000;
    final next = engine.newLifePlus(previous, spec(seed: 112)).state;

    expect(next.life.generation, 2);
    expect(next.life.legacy.single.name, previous.profile.name);
    expect(next.flags, contains('new_life_plus'));
    expect(next.finance.cash, greaterThan(0));
  });

  test('world conversations update relationship memory transactionally', () {
    var state = finishOpening(engine, newGame(engine, seed: 113));
    final before = state.relationships['arjun']!.affinity;

    state = engine.talkToNpc(state, 'arjun').state;

    final relationship = state.relationships['arjun']!;
    expect(relationship.affinity, greaterThan(before));
    expect(relationship.remembers('world_conversation'), isTrue);
    expect(state.counter('world_conversations'), 1);
  });
}

/// Small test-only adapter around the existing engine context types. Keeping
/// it here avoids exposing ledger construction as public gameplay API.
class EngineContextForTest {
  EngineContextForTest(this.state, this.content)
    : ctx = EngineContext(state, content),
      ledger = MonthLedger();

  final GameState state;
  final ContentBundle content;
  final EngineContext ctx;
  final MonthLedger ledger;
}
