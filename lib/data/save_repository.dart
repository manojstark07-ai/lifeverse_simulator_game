import 'dart:convert';
import 'dart:io';

import '../engine/core/game_calendar.dart';
import '../engine/core/json_utils.dart';
import '../engine/game_state.dart';
import 'save_migrations.dart';

class SaveSlotMeta {
  const SaveSlotMeta({
    required this.slotId,
    required this.characterName,
    required this.age,
    required this.gameDate,
    required this.chapter,
    required this.savedAt,
    required this.summary,
    this.label,
    this.corrupted = false,
  });

  factory SaveSlotMeta.fromJson(String slotId, Json j) => SaveSlotMeta(
        slotId: slotId,
        characterName: j['characterName'] as String,
        age: j['age'] as int,
        gameDate: j['gameDate'] as String,
        chapter: j['chapter'] as int,
        savedAt: DateTime.parse(j['savedAt'] as String),
        summary: j['summary'] as String? ?? '',
        label: j['label'] as String?,
      );

  factory SaveSlotMeta.corrupt(String slotId) => SaveSlotMeta(
      slotId: slotId, characterName: '', age: 0, gameDate: '', chapter: 0,
      savedAt: DateTime.fromMillisecondsSinceEpoch(0), summary: '', corrupted: true);

  factory SaveSlotMeta.describe(String slotId, GameState s, DateTime now, {String? label}) => SaveSlotMeta(
        slotId: slotId,
        characterName: s.profile.name,
        age: GameCalendar.ageOn(s.profile.birthDate, s.day),
        gameDate: GameCalendar.formatDay(s.day),
        chapter: s.chapter,
        savedAt: now,
        summary: s.story.inEvent ? 'Mid-event' : (s.career.hasCareer ? 'Working' : s.education.status),
        label: label,
      );

  final String slotId;
  final String characterName;
  final int age;
  final String gameDate;
  final int chapter;
  final DateTime savedAt;
  final String summary;
  final String? label;
  final bool corrupted;

  bool get isAutosave => slotId == SaveRepository.autosaveSlot;

  Json toJson() => {
        'characterName': characterName,
        'age': age,
        'gameDate': gameDate,
        'chapter': chapter,
        'savedAt': savedAt.toIso8601String(),
        'summary': summary,
        'label': label,
      };
}

/// Persistence for save slots. Implementations must be atomic per slot.
abstract class SaveRepository {
  static const autosaveSlot = 'autosave';
  static const manualSlots = ['slot1', 'slot2', 'slot3'];
  static const allSlots = [autosaveSlot, ...manualSlots];

  Future<List<SaveSlotMeta?>> listSlots();
  Future<GameState?> load(String slotId);
  Future<SaveSlotMeta> save(String slotId, GameState state, {String? label});
  Future<void> delete(String slotId);

  static void checkSlot(String slotId) {
    if (!allSlots.contains(slotId)) throw ArgumentError('Unknown save slot $slotId');
  }
}

/// Encodes a save file: metadata for the slot list plus the full state.
String encodeSave(SaveSlotMeta meta, GameState state) =>
    jsonEncode({'format': 'lifeverse-save', 'meta': meta.toJson(), 'state': state.toJson()});

GameState decodeSave(String text, SaveMigrator migrator) {
  final raw = (jsonDecode(text) as Map).cast<String, dynamic>();
  if (raw['format'] != 'lifeverse-save') throw const FormatException('Not a LIFEVERSE save');
  final state = migrator.migrate((raw['state'] as Map).cast<String, dynamic>());
  return GameState.fromJson(state);
}

/// One JSON file per slot, written atomically via a temp file + rename so a
/// crash mid-save can never leave a half-written slot.
class FileSaveRepository implements SaveRepository {
  FileSaveRepository(this.directory, {SaveMigrator? migrator, DateTime Function()? clock})
      : _migrator = migrator ?? SaveMigrator(),
        _clock = clock ?? DateTime.now;

  final Directory directory;
  final SaveMigrator _migrator;
  final DateTime Function() _clock;

  File _file(String slotId) => File('${directory.path}/$slotId.json');

  @override
  Future<List<SaveSlotMeta?>> listSlots() async {
    final out = <SaveSlotMeta?>[];
    for (final slot in SaveRepository.allSlots) {
      final f = _file(slot);
      if (!await f.exists()) {
        out.add(null);
        continue;
      }
      try {
        final raw = (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
        out.add(SaveSlotMeta.fromJson(slot, (raw['meta'] as Map).cast()));
      } catch (_) {
        out.add(SaveSlotMeta.corrupt(slot));
      }
    }
    return out;
  }

  @override
  Future<GameState?> load(String slotId) async {
    SaveRepository.checkSlot(slotId);
    final f = _file(slotId);
    if (!await f.exists()) return null;
    return decodeSave(await f.readAsString(), _migrator);
  }

  @override
  Future<SaveSlotMeta> save(String slotId, GameState state, {String? label}) async {
    SaveRepository.checkSlot(slotId);
    await directory.create(recursive: true);
    final meta = SaveSlotMeta.describe(slotId, state, _clock(), label: label);
    final tmp = File('${directory.path}/$slotId.json.tmp');
    await tmp.writeAsString(encodeSave(meta, state), flush: true);
    await tmp.rename(_file(slotId).path);
    return meta;
  }

  @override
  Future<void> delete(String slotId) async {
    SaveRepository.checkSlot(slotId);
    final f = _file(slotId);
    if (await f.exists()) await f.delete();
  }
}

/// Volatile repository used by tests and as a fallback.
class InMemorySaveRepository implements SaveRepository {
  InMemorySaveRepository({SaveMigrator? migrator}) : _migrator = migrator ?? SaveMigrator();

  final SaveMigrator _migrator;
  final Map<String, String> _files = {};

  @override
  Future<List<SaveSlotMeta?>> listSlots() async => [
        for (final slot in SaveRepository.allSlots)
          _files[slot] == null
              ? null
              : SaveSlotMeta.fromJson(slot, ((jsonDecode(_files[slot]!) as Map)['meta'] as Map).cast()),
      ];

  @override
  Future<GameState?> load(String slotId) async {
    SaveRepository.checkSlot(slotId);
    final text = _files[slotId];
    return text == null ? null : decodeSave(text, _migrator);
  }

  @override
  Future<SaveSlotMeta> save(String slotId, GameState state, {String? label}) async {
    SaveRepository.checkSlot(slotId);
    final meta = SaveSlotMeta.describe(slotId, state, DateTime.now(), label: label);
    _files[slotId] = encodeSave(meta, state);
    return meta;
  }

  @override
  Future<void> delete(String slotId) async => _files.remove(slotId);
}
