import '../engine/core/json_utils.dart';
import '../engine/game_state.dart';

class SaveMigrationException implements Exception {
  SaveMigrationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Upgrades older save files to [GameState.currentSchemaVersion].
///
/// Each step transforms version N into N+1 on the raw JSON, so save files
/// remain loadable as the data model evolves. Add a new step whenever the
/// schema version is bumped.
class SaveMigrator {
  SaveMigrator({Map<int, Json Function(Json)>? steps})
    : _steps = steps ?? defaultSteps;

  final Map<int, Json Function(Json)> _steps;

  static final Map<int, Json Function(Json)> defaultSteps = {
    // v0 → v1: pre-release saves had no per-story outcome cache or pending
    // puzzle list.
    0: (j) {
      final story = (j['story'] as Map? ?? {}).cast<String, dynamic>();
      story.putIfAbsent('lastOutcomes', () => <String>[]);
      story.putIfAbsent('pendingPuzzleIds', () => <String>[]);
      return {...j, 'story': story, 'schemaVersion': 1};
    },
    // v1 → v2: lifestyle update — health, looks and fame stats, three new
    // skills, possessions, household and the creator channel.
    1: (j) {
      final flags = (j['flags'] as List? ?? const []).cast<String>();
      final stats = (j['stats'] as Map? ?? {}).cast<String, dynamic>();
      final habits =
          (flags.contains('smoker') ? 12 : 0) +
          (flags.contains('heavy_drinker') ? 12 : 0);
      stats.putIfAbsent('health', () => 80 - habits);
      stats.putIfAbsent('looks', () => 45);
      stats.putIfAbsent('fame', () => 0);
      final skills = (j['skills'] as Map? ?? {}).cast<String, dynamic>();
      for (final k in const ['content', 'styling', 'cooking']) {
        skills.putIfAbsent(k, () => 5);
      }
      final household = <String, dynamic>{'status': 'single'};
      for (final npc in const ['arjun', 'nila']) {
        if (flags.contains('dating_$npc')) {
          household
            ..['partnerId'] = npc
            ..['status'] = 'dating'
            ..['sinceDay'] = j['day'];
        }
      }
      return {
        ...j,
        'stats': stats,
        'skills': skills,
        'possessions': j['possessions'] ?? <Object>[],
        'household': j['household'] ?? household,
        'schemaVersion': 2,
      };
    },
    // v2 -> v3: long-term life systems. Existing lives begin with no
    // business, property or retirement products and can opt into them.
    2: (j) => {
      ...j,
      'life': j['life'] ?? <String, Object>{},
      'schemaVersion': 3,
    },
  };

  Json migrate(Json raw, {int target = GameState.currentSchemaVersion}) {
    var json = raw;
    var version = json['schemaVersion'] as int? ?? 0;
    if (version > target) {
      throw SaveMigrationException(
        'Save was made by a newer version of the game (v$version).',
      );
    }
    while (version < target) {
      final step = _steps[version];
      if (step == null)
        throw SaveMigrationException('No migration from save v$version');
      json = step(json);
      final next = json['schemaVersion'] as int? ?? version;
      if (next != version + 1)
        throw SaveMigrationException(
          'Migration from v$version did not advance',
        );
      version = next;
    }
    return json;
  }
}
