import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/data/save_migrations.dart';
import 'package:lifeverse/data/save_repository.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';

import '../support/play.dart';
import '../support/content.dart';

void main() {
  final content = loadContent();
  final engine = GameEngine(content);
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('lifeverse_saves'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('save → load round-trips the full state, including a mid-event position', () async {
    final repo = FileSaveRepository(dir);
    final s = engine.choose(newGame(engine), 'c_read').state; // mid-event
    await repo.save('slot1', s, label: 'Before choosing a path');
    final loaded = await repo.load('slot1');
    expect(jsonEncode(loaded!.toJson()), jsonEncode(s.toJson()));
    expect(loaded.story.activeNodeId, 'amma');
    final metas = await repo.listSlots();
    expect(metas.length, SaveRepository.allSlots.length);
    final meta = metas[SaveRepository.allSlots.indexOf('slot1')]!;
    expect(meta.characterName, 'Asha');
    expect(meta.age, 18);
    expect(meta.label, 'Before choosing a path');
    expect(meta.summary, 'Mid-event');
  });

  test('a loaded save continues identically to the original (branching)', () async {
    final repo = FileSaveRepository(dir);
    final s = finishOpening(engine, newGame(engine));
    await repo.save('slot2', s);
    final a = engine.advance(s, days: 40).state;
    final b = engine.advance((await repo.load('slot2'))!, days: 40).state;
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
  });

  test('delete removes a slot; unknown slots are rejected', () async {
    final repo = FileSaveRepository(dir);
    await repo.save('autosave', newGame(engine));
    await repo.delete('autosave');
    expect(await repo.load('autosave'), isNull);
    expect(() => repo.save('../escape', newGame(engine)), throwsArgumentError);
  });

  test('corrupted slots are reported, not crashed on', () async {
    File('${dir.path}/slot3.json').writeAsStringSync('{not json');
    final metas = await FileSaveRepository(dir).listSlots();
    expect(metas[SaveRepository.allSlots.indexOf('slot3')]!.corrupted, isTrue);
  });

  test('no temp file is left behind after an atomic save', () async {
    await FileSaveRepository(dir).save('slot1', newGame(engine));
    expect(dir.listSync().map((e) => e.path).where((p) => p.endsWith('.tmp')), isEmpty);
  });

  group('migrations', () {
    test('v0 saves are upgraded to the current schema', () {
      final current = newGame(engine).toJson();
      final story = Map<String, dynamic>.of(current['story'] as Map<String, dynamic>)
        ..remove('lastOutcomes')
        ..remove('pendingPuzzleIds');
      final v0 = {...current, 'schemaVersion': 0, 'story': story};
      final migrated = SaveMigrator().migrate(v0);
      expect(migrated['schemaVersion'], GameState.currentSchemaVersion);
      expect((migrated['story'] as Map)['lastOutcomes'], isEmpty);
    });

    test('v1 saves gain lifestyle state; a smoker starts with lower health', () {
      final current = newGame(engine).toJson();
      final stats = Map<String, dynamic>.of(current['stats'] as Map<String, dynamic>)
        ..remove('health')
        ..remove('looks')
        ..remove('fame');
      final skills = Map<String, dynamic>.of(current['skills'] as Map<String, dynamic>)..remove('content');
      final v1 = {...current, 'schemaVersion': 1, 'stats': stats, 'skills': skills, 'flags': ['smoker', 'dating_nila']}
        ..remove('possessions')
        ..remove('household')
        ..remove('creator');
      final s = GameState.fromJson(SaveMigrator().migrate(v1));
      expect(s.stat('health'), 68);
      expect(s.skill('content'), 5);
      expect(s.possessions, isEmpty);
      expect(s.household.partnerId, 'nila');
      expect(s.household.status, 'dating');
      expect(s.creator, isNull);
    });

    test('saves from a newer game version are refused clearly', () {
      expect(() => SaveMigrator().migrate({'schemaVersion': 99}), throwsA(isA<SaveMigrationException>()));
    });
  });
}
