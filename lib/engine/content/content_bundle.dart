import '../achievements/achievement.dart';
import '../actions/daily_action.dart';
import '../career/career_models.dart';
import '../character/character_content.dart';
import '../core/json_utils.dart';
import '../creator/creator_models.dart';
import '../education/education_models.dart';
import '../endings/chapter_conclusion.dart';
import '../exams/exam_models.dart';
import '../finance/finance_models.dart';
import '../lifestyle/lifestyle_models.dart';
import '../puzzles/puzzle.dart';
import '../relationships/relationship_models.dart';
import '../story/story_models.dart';
import 'rules.dart';

/// All authored, read-only game content, indexed by id.
///
/// Content is assembled from any number of JSON documents. Each top-level key
/// (`events`, `puzzles`, `careers`, …) is merged across documents, so content
/// packs (new careers, countries, story chapters) can be added as extra files
/// without touching the engine. Duplicate ids are rejected.
class ContentBundle {
  ContentBundle._();

  factory ContentBundle.fromDocuments(List<Json> documents) {
    final b = ContentBundle._();
    for (final doc in documents) {
      final version = doc['contentVersion'];
      if (version is String) b.versions.add(version);
      void each<T>(String key, Map<String, T> into, T Function(Json) parse, String Function(T) idOf) {
        for (final raw in jsonList(doc[key])) {
          final T item;
          try {
            item = parse(raw);
          } on ContentFormatException catch (e) {
            throw ContentFormatException('$key/${raw['id'] ?? '?'}: ${e.message}');
          }
          final id = idOf(item);
          if (into.containsKey(id)) {
            throw ContentFormatException('Duplicate $key id "$id"');
          }
          into[id] = item;
        }
      }

      each('backgrounds', b.backgrounds, Background.fromJson, (x) => x.id);
      each('hometowns', b.hometowns, Hometown.fromJson, (x) => x.id);
      each('traits', b.traits, Trait.fromJson, (x) => x.id);
      each('interests', b.interests, Interest.fromJson, (x) => x.id);
      each('ambitions', b.ambitions, Ambition.fromJson, (x) => x.id);
      each('programs', b.programs, EducationProgram.fromJson, (x) => x.id);
      each('exams', b.exams, ExamDefinition.fromJson, (x) => x.id);
      each('puzzles', b.puzzles, Puzzle.fromJson, (x) => x.id);
      each('careers', b.careers, Career.fromJson, (x) => x.id);
      each('partTimeJobs', b.partTimeJobs, PartTimeJob.fromJson, (x) => x.id);
      each('loanProducts', b.loanProducts, LoanProduct.fromJson, (x) => x.id);
      each('npcs', b.npcs, Npc.fromJson, (x) => x.id);
      each('locations', b.locations, MapLocation.fromJson, (x) => x.id);
      each('actions', b.actions, DailyAction.fromJson, (x) => x.id);
      each('events', b.events, StoryEvent.fromJson, (x) => x.id);
      each('achievements', b.achievements, Achievement.fromJson, (x) => x.id);
      each('conclusions', b.conclusions, ChapterConclusion.fromJson, (x) => x.id);
      each('monthlyRules', b.monthlyRules, MonthlyRule.fromJson, (x) => x.id);
      each('interviewModifiers', b.interviewModifiers, InterviewModifier.fromJson, (x) => x.id);
      each('shopItems', b.shopItems, ShopItem.fromJson, (x) => x.id);
      each('creatorNiches', b.creatorNiches, CreatorNiche.fromJson, (x) => x.id);
      for (final name in stringList(doc['childNames'])) {
        b.childNames.add(name);
      }
      for (final raw in jsonList(doc['epilogueLines'])) {
        b.epilogueLines.add(EpilogueLine.fromJson(raw));
      }
    }
    return b;
  }

  final List<String> versions = [];
  final Map<String, Background> backgrounds = {};
  final Map<String, Hometown> hometowns = {};
  final Map<String, Trait> traits = {};
  final Map<String, Interest> interests = {};
  final Map<String, Ambition> ambitions = {};
  final Map<String, EducationProgram> programs = {};
  final Map<String, ExamDefinition> exams = {};
  final Map<String, Puzzle> puzzles = {};
  final Map<String, Career> careers = {};
  final Map<String, PartTimeJob> partTimeJobs = {};
  final Map<String, LoanProduct> loanProducts = {};
  final Map<String, Npc> npcs = {};
  final Map<String, MapLocation> locations = {};
  final Map<String, DailyAction> actions = {};
  final Map<String, StoryEvent> events = {};
  final Map<String, Achievement> achievements = {};
  final Map<String, ChapterConclusion> conclusions = {};
  final List<EpilogueLine> epilogueLines = [];
  final Map<String, MonthlyRule> monthlyRules = {};
  final Map<String, InterviewModifier> interviewModifiers = {};
  final Map<String, ShopItem> shopItems = {};
  final Map<String, CreatorNiche> creatorNiches = {};

  /// Names offered when a child is born.
  final List<String> childNames = [];

  List<Puzzle> pool(String name) =>
      (puzzles.values.where((p) => p.pools.contains(name)).toList()
        ..sort((a, b) => a.id.compareTo(b.id)));
}
