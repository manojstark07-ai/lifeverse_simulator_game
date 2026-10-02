import 'career/career_models.dart';
import 'character/player_profile.dart';
import 'core/json_utils.dart';
import 'creator/creator_models.dart';
import 'education/education_models.dart';
import 'exams/exam_models.dart';
import 'finance/finance_models.dart';
import 'household/household_models.dart';
import 'journal/journal.dart';
import 'lifestyle/lifestyle_models.dart';
import 'life/life_systems.dart';
import 'relationships/relationship_models.dart';
import 'time/routine.dart';

class QueuedEvent {
  QueuedEvent({required this.eventId, required this.dueDay});

  factory QueuedEvent.fromJson(Json j) =>
      QueuedEvent(eventId: j['eventId'] as String, dueDay: j['dueDay'] as int);

  final String eventId;
  final int dueDay;

  Json toJson() => {'eventId': eventId, 'dueDay': dueDay};
}

/// Effects that land later ("delayed consequences"). Stored as raw JSON so
/// they serialise without needing the content bundle.
class ScheduledEffects {
  ScheduledEffects({
    required this.dueDay,
    required this.note,
    required this.effects,
  });

  factory ScheduledEffects.fromJson(Json j) => ScheduledEffects(
    dueDay: j['dueDay'] as int,
    note: j['note'] as String,
    effects: jsonList(j['effects']),
  );

  final int dueDay;
  final String note;
  final List<Json> effects;

  Json toJson() => {'dueDay': dueDay, 'note': note, 'effects': effects};
}

class StoryProgress {
  StoryProgress({
    this.activeEventId,
    this.activeNodeId,
    this.pendingChallengeChoiceId,
    List<String>? pendingPuzzleIds,
    List<String>? lastOutcomes,
    Set<String>? completed,
    Map<String, int>? lastFiredDay,
    List<QueuedEvent>? queue,
  }) : pendingPuzzleIds = pendingPuzzleIds ?? [],
       lastOutcomes = lastOutcomes ?? [],
       completed = completed ?? {},
       lastFiredDay = lastFiredDay ?? {},
       queue = queue ?? [];

  factory StoryProgress.fromJson(Json j) => StoryProgress(
    activeEventId: j['activeEventId'] as String?,
    activeNodeId: j['activeNodeId'] as String?,
    pendingChallengeChoiceId: j['pendingChallengeChoiceId'] as String?,
    pendingPuzzleIds: stringList(j['pendingPuzzleIds']),
    lastOutcomes: stringList(j['lastOutcomes']),
    completed: stringList(j['completed']).toSet(),
    lastFiredDay: (j['lastFiredDay'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
    queue: jsonList(j['queue']).map(QueuedEvent.fromJson).toList(),
  );

  String? activeEventId;
  String? activeNodeId;

  /// Set while the player is inside a puzzle/exam launched by a choice, so a
  /// save taken mid-challenge resumes at the same decision.
  String? pendingChallengeChoiceId;

  /// The exact puzzles generated for the pending challenge.
  List<String> pendingPuzzleIds;

  /// Consequences of the previous decision, shown on the next node.
  List<String> lastOutcomes;
  Set<String> completed;
  Map<String, int> lastFiredDay;
  List<QueuedEvent> queue;

  bool get inEvent => activeEventId != null;

  Json toJson() => {
    'activeEventId': activeEventId,
    'activeNodeId': activeNodeId,
    'pendingChallengeChoiceId': pendingChallengeChoiceId,
    'pendingPuzzleIds': pendingPuzzleIds,
    'lastOutcomes': lastOutcomes,
    'completed': completed.toList()..sort(),
    'lastFiredDay': lastFiredDay,
    'queue': queue.map((q) => q.toJson()).toList(),
  };
}

/// The complete, serialisable state of one playthrough.
///
/// The engine treats a [GameState] as a value: every operation clones it,
/// mutates the clone, and returns it only if the whole operation succeeded.
/// That gives multi-system decisions all-or-nothing (transactional) semantics.
class GameState {
  GameState({
    required this.schemaVersion,
    required this.playthroughId,
    required this.seed,
    required this.rngState,
    required this.day,
    required this.profile,
    required this.stats,
    required this.skills,
    required this.finance,
    required this.education,
    required this.career,
    required this.relationships,
    required this.routine,
    required this.story,
    Set<String>? flags,
    Map<String, int>? counters,
    List<ScheduledEffects>? scheduled,
    List<JournalEntry>? journal,
    List<DecisionRecord>? decisions,
    Map<String, int>? achievements,
    Map<String, ExamRecord>? exams,
    Set<String>? solvedPuzzles,
    List<OwnedItem>? possessions,
    HouseholdState? household,
    LifeSystemsState? life,
    this.creator,
    this.nextItemSeq = 1,
    this.actionsToday = 0,
    this.chapter = 1,
    this.conclusionId,
    this.conclusionDay,
    required this.lastSettledMonthKey,
  }) : flags = flags ?? {},
       counters = counters ?? {},
       scheduled = scheduled ?? [],
       journal = journal ?? [],
       decisions = decisions ?? [],
       achievements = achievements ?? {},
       exams = exams ?? {},
       solvedPuzzles = solvedPuzzles ?? {},
       possessions = possessions ?? [],
       household = household ?? HouseholdState(),
       life = life ?? LifeSystemsState();

  factory GameState.fromJson(Json j) => GameState(
    schemaVersion: j['schemaVersion'] as int,
    playthroughId: j['playthroughId'] as String,
    seed: j['seed'] as int,
    rngState: j['rngState'] as int,
    day: j['day'] as int,
    profile: PlayerProfile.fromJson((j['profile'] as Map).cast()),
    stats: numMap(j['stats']),
    skills: numMap(j['skills']),
    finance: FinanceState.fromJson((j['finance'] as Map).cast()),
    education: EducationState.fromJson((j['education'] as Map).cast()),
    career: CareerState.fromJson((j['career'] as Map).cast()),
    relationships: (j['relationships'] as Map).map(
      (k, v) =>
          MapEntry(k as String, RelationshipState.fromJson((v as Map).cast())),
    ),
    routine: Routine.fromJson((j['routine'] as Map).cast()),
    story: StoryProgress.fromJson((j['story'] as Map).cast()),
    flags: stringList(j['flags']).toSet(),
    counters: (j['counters'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
    scheduled: jsonList(j['scheduled']).map(ScheduledEffects.fromJson).toList(),
    journal: jsonList(j['journal']).map(JournalEntry.fromJson).toList(),
    decisions: jsonList(j['decisions']).map(DecisionRecord.fromJson).toList(),
    achievements: (j['achievements'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
    exams: (j['exams'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, ExamRecord.fromJson((v as Map).cast())),
    ),
    solvedPuzzles: stringList(j['solvedPuzzles']).toSet(),
    possessions: jsonList(j['possessions']).map(OwnedItem.fromJson).toList(),
    household: j['household'] == null
        ? null
        : HouseholdState.fromJson((j['household'] as Map).cast()),
    life: LifeSystemsState.fromJson((j['life'] as Map? ?? {}).cast()),
    creator: j['creator'] == null
        ? null
        : CreatorState.fromJson((j['creator'] as Map).cast()),
    nextItemSeq: optInt(j, 'nextItemSeq', 1),
    actionsToday: optInt(j, 'actionsToday', 0),
    chapter: optInt(j, 'chapter', 1),
    conclusionId: j['conclusionId'] as String?,
    conclusionDay: j['conclusionDay'] as int?,
    lastSettledMonthKey: j['lastSettledMonthKey'] as int,
  );

  static const currentSchemaVersion = 3;
  static const maxActionsPerDay = 2;

  final int schemaVersion;
  final String playthroughId;
  final int seed;
  int rngState;

  /// Days since the game started. Only ever increases.
  int day;
  PlayerProfile profile;
  Map<String, double> stats;
  Map<String, double> skills;
  FinanceState finance;
  EducationState education;
  CareerState career;
  Map<String, RelationshipState> relationships;
  Routine routine;
  StoryProgress story;
  Set<String> flags;
  Map<String, int> counters;
  List<ScheduledEffects> scheduled;
  List<JournalEntry> journal;
  List<DecisionRecord> decisions;

  /// Achievement id → day unlocked. A map makes duplicate unlocks impossible.
  Map<String, int> achievements;
  Map<String, ExamRecord> exams;
  Set<String> solvedPuzzles;

  /// Things the player owns: phones, vehicles, property, memberships.
  List<OwnedItem> possessions;
  HouseholdState household;

  /// Business, property, insurance, retirement, ageing and legacy systems.
  LifeSystemsState life;

  /// The player's video channel, once started.
  CreatorState? creator;
  int nextItemSeq;
  int actionsToday;
  int chapter;
  String? conclusionId;
  int? conclusionDay;

  /// Last calendar month whose income/expenses were settled; guards against
  /// settling (and paying out) the same month twice.
  int lastSettledMonthKey;

  double stat(String key) => stats[key] ?? 0;
  double skill(String key) => skills[key] ?? 0;
  int counter(String key) => counters[key] ?? 0;
  bool owns(String itemId) => possessions.any((p) => p.itemId == itemId);

  Json toJson() => {
    'schemaVersion': schemaVersion,
    'playthroughId': playthroughId,
    'seed': seed,
    'rngState': rngState,
    'day': day,
    'profile': profile.toJson(),
    'stats': stats,
    'skills': skills,
    'finance': finance.toJson(),
    'education': education.toJson(),
    'career': career.toJson(),
    'relationships': relationships.map((k, v) => MapEntry(k, v.toJson())),
    'routine': routine.toJson(),
    'story': story.toJson(),
    'flags': flags.toList()..sort(),
    'counters': counters,
    'scheduled': scheduled.map((s) => s.toJson()).toList(),
    'journal': journal.map((e) => e.toJson()).toList(),
    'decisions': decisions.map((d) => d.toJson()).toList(),
    'achievements': achievements,
    'exams': exams.map((k, v) => MapEntry(k, v.toJson())),
    'solvedPuzzles': solvedPuzzles.toList()..sort(),
    'possessions': possessions.map((p) => p.toJson()).toList(),
    'household': household.toJson(),
    'life': life.toJson(),
    'creator': creator?.toJson(),
    'nextItemSeq': nextItemSeq,
    'actionsToday': actionsToday,
    'chapter': chapter,
    'conclusionId': conclusionId,
    'conclusionDay': conclusionDay,
    'lastSettledMonthKey': lastSettledMonthKey,
  };

  /// Deep copy via the serialised form (also exercises save/load paths).
  GameState clone() => GameState.fromJson(toJson());
}
