import '../conditions/condition.dart';
import '../core/json_utils.dart';
import '../effects/effect.dart';

class TriggerKind {
  const TriggerKind._();

  /// Fires as soon as its conditions hold (checked every simulated day).
  static const auto = 'auto';

  /// Fires only when scheduled by an effect.
  static const scheduled = 'scheduled';

  /// Rolled once per month with [EventTrigger.chancePerMonth].
  static const random = 'random';

  static const all = [auto, scheduled, random];
}

class EventTrigger {
  EventTrigger({
    required this.kind,
    required this.condition,
    required this.priority,
    required this.chancePerMonth,
  });

  factory EventTrigger.fromJson(Json j) => EventTrigger(
        kind: req<String>(j, 'kind', 'trigger'),
        condition: j['when'] == null
            ? Condition.always
            : Condition.fromJson((j['when'] as Map).cast()),
        priority: optInt(j, 'priority', 0),
        chancePerMonth: optNum(j, 'chancePerMonth', 0),
      );

  final String kind;
  final Condition condition;
  final int priority;
  final double chancePerMonth;
}

class TextVariant {
  TextVariant({required this.condition, required this.text});

  factory TextVariant.fromJson(Json j) => TextVariant(
        condition: Condition.fromJson((j['when'] as Map).cast()),
        text: req<String>(j, 'text'),
      );

  final Condition condition;
  final String text;
}

class Route {
  Route({required this.condition, required this.next});

  factory Route.fromJson(Json j) => Route(
        condition: Condition.fromJson((j['when'] as Map).cast()),
        next: j['next'] as String?,
      );

  final Condition condition;
  final String? next;
}

/// Effects + destination applied after a challenge passes or fails.
class Outcome {
  Outcome({required this.effects, required this.next, required this.routes});

  factory Outcome.fromJson(Json j) => Outcome(
        effects: jsonList(j['effects']).map(Effect.fromJson).toList(),
        next: j['next'] as String?,
        routes: jsonList(j['routes']).map(Route.fromJson).toList(),
      );

  final List<Effect> effects;
  final String? next;
  final List<Route> routes;
}

class ChallengeKind {
  const ChallengeKind._();
  static const puzzle = 'puzzle';
  static const exam = 'exam';

  /// Puzzles from the career's interview pool, scored together with skills,
  /// communication and institution reputation.
  static const interview = 'interview';
  static const all = [puzzle, exam, interview];
}

/// An interactive challenge attached to a choice.
class ChallengeSpec {
  ChallengeSpec({
    required this.kind,
    required this.pool,
    required this.examId,
    required this.careerId,
    required this.count,
    required this.passFraction,
    required this.onPass,
    required this.onFail,
  });

  factory ChallengeSpec.fromJson(Json j) => ChallengeSpec(
        kind: req<String>(j, 'kind', 'challenge'),
        pool: j['pool'] as String?,
        examId: j['examId'] as String?,
        careerId: j['career'] as String?,
        count: optInt(j, 'count', 1),
        passFraction: optNum(j, 'passFraction', 0.5),
        onPass: Outcome.fromJson((j['onPass'] as Map).cast()),
        onFail: Outcome.fromJson((j['onFail'] as Map).cast()),
      );

  final String kind;

  /// Puzzle pool for `puzzle` challenges.
  final String? pool;

  /// For `exam` challenges. `onPass` is used for any tier except the last.
  final String? examId;

  /// For `interview` challenges.
  final String? careerId;
  final int count;
  final double passFraction;
  final Outcome onPass;
  final Outcome onFail;
}

class ChoiceCost {
  const ChoiceCost({this.energy = 0, this.money = 0, this.days = 0});

  factory ChoiceCost.fromJson(Json j) => ChoiceCost(
        energy: optNum(j, 'energy', 0),
        money: optInt(j, 'money', 0),
        days: optInt(j, 'days', 0),
      );

  final double energy;
  final int money;

  /// Time this choice takes; the clock advances after it resolves.
  final int days;

  bool get isFree => energy == 0 && money == 0 && days == 0;
}

class StoryChoice {
  StoryChoice({
    required this.id,
    required this.label,
    required this.hint,
    required this.requires,
    required this.hideIfLocked,
    required this.cost,
    required this.effects,
    required this.next,
    required this.routes,
    required this.challenge,
  });

  factory StoryChoice.fromJson(Json j) => StoryChoice(
        id: req<String>(j, 'id'),
        label: req<String>(j, 'label'),
        hint: j['hint'] as String?,
        requires: j['requires'] == null
            ? Condition.always
            : Condition.fromJson((j['requires'] as Map).cast()),
        hideIfLocked: j['hideIfLocked'] as bool? ?? false,
        cost: j['cost'] == null
            ? const ChoiceCost()
            : ChoiceCost.fromJson((j['cost'] as Map).cast()),
        effects: jsonList(j['effects']).map(Effect.fromJson).toList(),
        next: j['next'] as String?,
        routes: jsonList(j['routes']).map(Route.fromJson).toList(),
        challenge: j['challenge'] == null
            ? null
            : ChallengeSpec.fromJson((j['challenge'] as Map).cast()),
      );

  final String id;
  final String label;
  final String? hint;
  final Condition requires;
  final bool hideIfLocked;
  final ChoiceCost cost;
  final List<Effect> effects;

  /// Destination node; `null` ends the event.
  final String? next;

  /// Conditional destinations evaluated (after effects) before [next].
  final List<Route> routes;
  final ChallengeSpec? challenge;
}

class StoryNode {
  StoryNode({
    required this.id,
    required this.speaker,
    required this.text,
    required this.variants,
    required this.onEnter,
    required this.choices,
  });

  factory StoryNode.fromJson(String id, Json j) => StoryNode(
        id: id,
        speaker: j['speaker'] as String?,
        text: req<String>(j, 'text', 'node $id'),
        variants: jsonList(j['variants']).map(TextVariant.fromJson).toList(),
        onEnter: jsonList(j['onEnter']).map(Effect.fromJson).toList(),
        choices: jsonList(j['choices']).map(StoryChoice.fromJson).toList(),
      );

  final String id;

  /// NPC id, `player`, `narrator` or null.
  final String? speaker;
  final String text;

  /// The first matching variant is *appended* to [text], letting one node
  /// adapt to background, history and relationships.
  final List<TextVariant> variants;
  final List<Effect> onEnter;
  final List<StoryChoice> choices;

  bool get isTerminal => choices.isEmpty;
}

class StoryEvent {
  StoryEvent({
    required this.id,
    required this.chapter,
    required this.title,
    required this.location,
    required this.summary,
    required this.trigger,
    required this.repeatable,
    required this.start,
    required this.nodes,
    required this.isWorldEvent,
  });

  factory StoryEvent.fromJson(Json j) {
    final id = req<String>(j, 'id');
    final rawNodes = (j['nodes'] as Map).cast<String, dynamic>();
    return StoryEvent(
      id: id,
      chapter: req<num>(j, 'chapter', id).toInt(),
      title: req<String>(j, 'title', id),
      location: req<String>(j, 'location', id),
      summary: req<String>(j, 'summary', id),
      trigger: EventTrigger.fromJson((j['trigger'] as Map).cast()),
      repeatable: j['repeatable'] as bool? ?? false,
      start: req<String>(j, 'start', id),
      nodes: rawNodes.map((k, v) =>
          MapEntry(k, StoryNode.fromJson(k, (v as Map).cast()))),
      isWorldEvent: j['worldEvent'] as bool? ?? false,
    );
  }

  final String id;

  /// The chapter this event belongs to; 0 means it can happen in any chapter
  /// (everyday-life events such as a stolen phone or a viral video).
  final int chapter;
  final String title;
  final String location;
  final String summary;
  final EventTrigger trigger;
  final bool repeatable;
  final String start;
  final Map<String, StoryNode> nodes;
  final bool isWorldEvent;

  bool inChapter(int current) => chapter == 0 || chapter == current;
}
