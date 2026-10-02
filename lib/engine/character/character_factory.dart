import '../career/career_models.dart';
import '../content/content_bundle.dart';
import '../core/game_calendar.dart';
import '../education/education_models.dart';
import '../finance/finance_models.dart';
import '../game_state.dart';
import '../journal/journal.dart';
import '../relationships/relationship_models.dart';
import '../time/routine.dart';
import 'player_profile.dart';
import 'stats.dart';

/// Builds the initial [GameState] from the player's character-creation spec.
class CharacterFactory {
  const CharacterFactory._();

  static const baseStats = {
    StatKeys.knowledge: 30.0,
    StatKeys.discipline: 35.0,
    StatKeys.communication: 35.0,
    StatKeys.wellbeing: 65.0,
    StatKeys.energy: 80.0,
    StatKeys.health: 80.0,
    StatKeys.looks: 45.0,
    StatKeys.fame: 0.0,
  };
  static const baseSkill = 5.0;
  static const maxTraits = 2;
  static const maxInterests = 3;

  static GameState create(CharacterSpec spec, ContentBundle c) {
    final name = spec.name.trim();
    if (name.isEmpty || name.length > 24) throw ArgumentError('Name must be 1–24 characters');
    final background = c.backgrounds[spec.backgroundId] ?? (throw ArgumentError('Unknown background'));
    final hometown = c.hometowns[spec.hometownId] ?? (throw ArgumentError('Unknown hometown'));
    if (!c.ambitions.containsKey(spec.ambitionId)) throw ArgumentError('Unknown ambition');
    if (spec.traitIds.isEmpty || spec.traitIds.length > maxTraits) {
      throw ArgumentError('Choose 1–$maxTraits traits');
    }
    if (spec.interestIds.length > maxInterests) throw ArgumentError('Choose up to $maxInterests interests');

    final stats = Map<String, double>.of(baseStats);
    void addAll(Map<String, double> into, Map<String, double> deltas) =>
        deltas.forEach((k, v) => into[k] = ((into[k] ?? 0) + v).clamp(0, 100).toDouble());
    addAll(stats, background.startStats);
    for (final id in spec.traitIds) {
      addAll(stats, (c.traits[id] ?? (throw ArgumentError('Unknown trait $id'))).startStats);
    }

    final skills = {for (final k in SkillKeys.all) k: baseSkill};
    addAll(skills, background.startSkills);
    for (final id in spec.interestIds) {
      addAll(skills, (c.interests[id] ?? (throw ArgumentError('Unknown interest $id'))).startSkills);
    }

    final relationships = <String, RelationshipState>{};
    for (final npc in c.npcs.values) {
      relationships[npc.id] = RelationshipState(
        npcId: npc.id,
        affinity: npc.isFamily ? background.familyAffinity : npc.startAffinity,
        trust: npc.startTrust,
        met: npc.isFamily || npc.routineBond == 'social',
      );
    }

    // Born January–May 2008, so the player is 18 on day 0 (1 June 2026).
    final seed = spec.seed & 0x7FFFFFFF;
    final birth = DateTime.utc(2008, 1 + seed % 5, 1 + seed % 28);

    final state = GameState(
      schemaVersion: GameState.currentSchemaVersion,
      playthroughId: 'life-${seed.toRadixString(16)}',
      seed: seed,
      rngState: seed,
      day: 0,
      profile: PlayerProfile(
        name: name,
        pronouns: spec.pronouns,
        appearance: spec.appearance,
        birthDate: birth,
        hometownId: hometown.id,
        currentCityId: hometown.id,
        backgroundId: background.id,
        traitIds: List.of(spec.traitIds),
        interestIds: List.of(spec.interestIds),
        ambitionId: spec.ambitionId,
      ),
      stats: stats,
      skills: skills,
      finance: FinanceState(cash: background.startingCash, familySupportMonthly: background.familySupportMonthly),
      education: EducationState(),
      career: CareerState(),
      relationships: relationships,
      routine: Routine(),
      story: StoryProgress(),
      flags: {'bg_${background.id}', 'home_${hometown.kind}', ...background.flags, if (spec.matureThemes) 'mature_on'},
      lastSettledMonthKey: GameCalendar.monthKeyOfDay(0) - 1,
    );
    state.journal.add(JournalEntry(
      day: 0,
      title: 'Eighteen',
      body: '$name, 18, from ${hometown.name}. School is over. Everything after this is a choice.',
      kind: JournalKind.milestone,
      important: true,
    ));
    return state;
  }
}
