import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import '../data/content_repository.dart';
import '../data/save_repository.dart';
import '../data/settings_repository.dart';
import '../engine/content/content_bundle.dart';
import '../engine/game_engine.dart';

final getIt = GetIt.instance;

/// Registers app-wide services. Tests call [configureDependencies] with
/// in-memory overrides instead.
Future<void> configureDependencies({
  ContentBundle? content,
  SaveRepository? saves,
  SettingsRepository? settings,
}) async {
  await getIt.reset();
  final bundle = content ?? await ContentRepository().load();
  Directory? docs;
  if (saves == null || settings == null) {
    docs = Directory('${(await getApplicationDocumentsDirectory()).path}/lifeverse');
  }
  getIt
    ..registerSingleton<ContentBundle>(bundle)
    ..registerSingleton<GameEngine>(GameEngine(bundle))
    ..registerSingleton<SaveRepository>(saves ?? FileSaveRepository(Directory('${docs!.path}/saves')))
    ..registerSingleton<SettingsRepository>(settings ?? FileSettingsRepository(docs!));
}
