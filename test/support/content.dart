import 'dart:convert';
import 'dart:io';

import 'package:lifeverse/engine/character/player_profile.dart';
import 'package:lifeverse/engine/content/content_bundle.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';

/// Loads every content document straight from disk (no Flutter bindings).
ContentBundle loadContent() {
  final dir = Directory('assets/content');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return ContentBundle.fromDocuments(
      files.map((f) => (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>()).toList());
}

CharacterSpec spec({
  String background = 'urban_lower_middle',
  String hometown = 'chennai',
  int seed = 42,
  List<String> traits = const ['curious'],
}) =>
    CharacterSpec(
      name: 'Asha',
      pronouns: 'she/her',
      appearance: const Appearance(),
      hometownId: hometown,
      backgroundId: background,
      traitIds: traits,
      interestIds: const ['technology', 'puzzles'],
      ambitionId: 'mastery',
      seed: seed,
    );

GameState newGame(GameEngine engine, {String background = 'urban_lower_middle', int seed = 42}) =>
    engine.newGame(spec(background: background, seed: seed)).state;
