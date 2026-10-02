import '../career/career_service.dart';
import '../content/content_bundle.dart';
import '../core/money.dart';
import '../effects/effect_resolver.dart';
import '../engine_context.dart';
import '../exams/exam_service.dart';
import '../game_events.dart';
import '../game_state.dart';
import '../journal/journal.dart';
import '../puzzles/puzzle.dart';
import '../puzzles/puzzle_selector.dart';
import '../time/life_simulation.dart';
import 'story_models.dart';

class ChoiceView {
  const ChoiceView({required this.choice, required this.enabled, this.lockReason});

  final StoryChoice choice;
  final bool enabled;
  final String? lockReason;
}

/// Everything the story screen needs to render the current node.
class NodeView {
  const NodeView({
    required this.event,
    required this.node,
    required this.text,
    required this.speakerId,
    required this.choices,
    required this.pendingChallenge,
    required this.lastOutcomes,
  });

  final StoryEvent event;
  final StoryNode node;
  final String text;
  final String? speakerId;
  final List<ChoiceView> choices;
  final StoryChoice? pendingChallenge;
  final List<String> lastOutcomes;
}

/// Runs the node-based narrative: triggering events, presenting nodes,
/// resolving choices and challenges, and routing between nodes.
class StoryEngine {
  const StoryEngine._();

  static const continueId = '__continue';

  // ------------------------------------------------------------ triggers --

  /// The event that should start now, if any: due scheduled events first,
  /// then the highest-priority auto event whose conditions hold.
  static StoryEvent? nextTriggered(GameState s, ContentBundle c) {
    if (s.story.inEvent) return null;
    final due = s.story.queue.where((q) => q.dueDay <= s.day).toList()
      ..sort((a, b) => a.dueDay != b.dueDay ? a.dueDay.compareTo(b.dueDay) : a.eventId.compareTo(b.eventId));
    for (final q in due) {
      final e = c.events[q.eventId];
      if (e == null) continue;
      if (!e.repeatable && s.story.completed.contains(e.id)) continue;
      if (e.trigger.condition.evaluate(s, c)) return e;
    }
    final autos = c.events.values
        .where((e) =>
            e.trigger.kind == TriggerKind.auto &&
            e.inChapter(s.chapter) &&
            _autoReady(s, e) &&
            e.trigger.condition.evaluate(s, c))
        .toList()
      ..sort((a, b) => b.trigger.priority != a.trigger.priority
          ? b.trigger.priority.compareTo(a.trigger.priority)
          : a.id.compareTo(b.id));
    return autos.isEmpty ? null : autos.first;
  }

  static const repeatCooldownDays = 90;

  static bool _autoReady(GameState s, StoryEvent e) {
    if (!s.story.completed.contains(e.id)) return true;
    if (!e.repeatable) return false;
    final last = s.story.lastFiredDay[e.id];
    return last == null || s.day - last >= repeatCooldownDays;
  }

  /// Drops queued events that can no longer fire (completed or stale).
  static void pruneQueue(EngineContext ctx) {
    final s = ctx.s;
    s.story.queue.removeWhere((q) {
      final e = ctx.c.events[q.eventId];
      if (e == null) return true;
      if (!e.repeatable && s.story.completed.contains(e.id)) return true;
      // Random events whose moment has passed without their conditions
      // holding are dropped after a grace week.
      return q.dueDay + 7 < s.day && !e.trigger.condition.evaluate(s, ctx.c);
    });
  }

  static void start(EngineContext ctx, StoryEvent event) {
    final s = ctx.s;
    s.story
      ..activeEventId = event.id
      ..lastOutcomes = [];
    s.story.lastFiredDay[event.id] = s.day;
    s.story.queue.removeWhere((q) => q.eventId == event.id);
    ctx.emit(StoryEventStarted(event.id));
    _enter(ctx, event, event.start);
  }

  static void _enter(EngineContext ctx, StoryEvent event, String nodeId) {
    final node = event.nodes[nodeId];
    if (node == null) throw StateError('Event ${event.id} has no node $nodeId');
    ctx.s.story.activeNodeId = nodeId;
    if (node.onEnter.isNotEmpty) {
      EffectResolver.applyAll(ctx, node.onEnter);
    }
  }

  static void _end(EngineContext ctx, StoryEvent event) {
    final s = ctx.s;
    s.story
      ..activeEventId = null
      ..activeNodeId = null
      ..pendingChallengeChoiceId = null
      ..pendingPuzzleIds = [];
    s.story.completed.add(event.id);
  }

  // ---------------------------------------------------------------- view --

  static NodeView? view(GameState s, ContentBundle c) {
    final event = c.events[s.story.activeEventId];
    final node = event?.nodes[s.story.activeNodeId];
    if (event == null || node == null) return null;
    var text = node.text;
    for (final v in node.variants) {
      if (v.condition.evaluate(s, c)) {
        text = '$text\n\n${v.text}';
        break;
      }
    }
    final choices = <ChoiceView>[];
    for (final ch in node.choices) {
      final meets = ch.requires.evaluate(s, c);
      if (!meets && ch.hideIfLocked) continue;
      String? reason;
      if (!meets) {
        final d = ch.requires.describe(c);
        reason = d.isEmpty ? 'Not available' : 'Requires: $d';
      } else if (ch.cost.money > s.finance.cash) {
        reason = 'Needs ${formatRupees(ch.cost.money)}';
      }
      choices.add(ChoiceView(choice: ch, enabled: reason == null, lockReason: reason));
    }
    final pendingId = s.story.pendingChallengeChoiceId;
    return NodeView(
      event: event,
      node: node,
      text: interpolate(text, s, c),
      speakerId: node.speaker,
      choices: choices,
      pendingChallenge: pendingId == null ? null : node.choices.where((x) => x.id == pendingId).firstOrNull,
      lastOutcomes: s.story.lastOutcomes,
    );
  }

  static String interpolate(String text, GameState s, ContentBundle c) => text
      .replaceAll('{name}', s.profile.name)
      .replaceAll('{hometown}', c.hometowns[s.profile.hometownId]?.name ?? '')
      .replaceAll('{city}', c.hometowns[s.profile.currentCityId]?.name ?? '')
      .replaceAll('{program}', c.programs[s.education.programId]?.shortName ?? 'your course');

  // ------------------------------------------------------------- choices --

  static void choose(EngineContext ctx, String choiceId) {
    final s = ctx.s;
    final event = ctx.c.events[s.story.activeEventId];
    final node = event?.nodes[s.story.activeNodeId];
    if (event == null || node == null) throw StateError('No active story node');
    if (s.story.pendingChallengeChoiceId != null) throw StateError('A challenge is pending');

    if (choiceId == continueId) {
      if (!node.isTerminal) throw StateError('Node ${node.id} is not terminal');
      s.story.lastOutcomes = [];
      _end(ctx, event);
      return;
    }

    final choice = node.choices.where((c) => c.id == choiceId).firstOrNull;
    if (choice == null) throw StateError('No choice $choiceId at ${event.id}/${node.id}');
    if (!choice.requires.evaluate(s, ctx.c)) throw StateError('Choice $choiceId is locked');

    ctx.outcomes.clear();
    if (choice.cost.money > 0 && !ctx.trySpend(choice.cost.money, 'story', choice.label)) {
      throw StateError('Cannot afford $choiceId');
    }
    if (choice.cost.energy != 0) ctx.addStat('energy', -choice.cost.energy);

    final challenge = choice.challenge;
    if (challenge != null) {
      s.story.pendingChallengeChoiceId = choice.id;
      s.story.pendingPuzzleIds = _generateChallenge(ctx, challenge).map((p) => p.id).toList();
      s.story.lastOutcomes = List.of(ctx.outcomes);
      return;
    }

    EffectResolver.applyAll(ctx, choice.effects);
    _record(ctx, event, choice, choice.label);
    _route(ctx, event, choice.routes, choice.next);
    _passTime(ctx, choice.cost.days);
  }

  static List<Puzzle> _generateChallenge(EngineContext ctx, ChallengeSpec spec) {
    final c = ctx.c;
    switch (spec.kind) {
      case ChallengeKind.exam:
        return ExamService.generatePaper(c, c.exams[spec.examId]!, ctx.rng);
      case ChallengeKind.interview:
        return PuzzleSelector.stratified(c.pool(c.careers[spec.careerId]!.interviewPool), spec.count, ctx.rng);
      default:
        return PuzzleSelector.stratified(c.pool(spec.pool!), spec.count, ctx.rng);
    }
  }

  /// Resolves the pending challenge with the player's answers.
  static void resolveChallenge(EngineContext ctx, ChallengeResult result) {
    final s = ctx.s;
    final event = ctx.c.events[s.story.activeEventId];
    final node = event?.nodes[s.story.activeNodeId];
    final choiceId = s.story.pendingChallengeChoiceId;
    if (event == null || node == null || choiceId == null) throw StateError('No pending challenge');
    final choice = node.choices.firstWhere((c) => c.id == choiceId);
    final spec = choice.challenge!;
    final expected = s.story.pendingPuzzleIds.toSet();
    if (result.answers.any((a) => !expected.contains(a.puzzleId))) {
      throw StateError('Answers do not match the generated challenge');
    }

    ctx.outcomes
      ..clear()
      ..addAll(s.story.lastOutcomes);
    for (final a in result.answers) {
      if (a.correct) s.solvedPuzzles.add(a.puzzleId);
    }

    final bool passed;
    String verdict;
    switch (spec.kind) {
      case ChallengeKind.exam:
        final exam = ctx.c.exams[spec.examId]!;
        final score = ExamService.score(s, ctx.c, exam, result);
        ExamService.record(s, exam, result, score);
        passed = score.tier.id != exam.tiers.last.id;
        verdict = '${exam.shortName}: ${score.composite.toStringAsFixed(1)} — ${score.tier.label}';
        ctx.journal('${exam.shortName} result', '$verdict (paper ${score.performancePct.toStringAsFixed(0)}%, '
            'preparation ${score.preparationIndex.toStringAsFixed(0)}).', JournalKind.education, important: true);
      case ChallengeKind.interview:
        final career = ctx.c.careers[spec.careerId]!;
        final score = CareerService.interviewScore(ctx, career, result);
        passed = score >= CareerService.interviewThreshold(career);
        verdict = 'Interview score ${(score * 100).round()} — ${passed ? 'offer' : 'no offer'}';
        s.counters['interviews'] = s.counter('interviews') + 1;
      default:
        passed = result.fraction >= spec.passFraction;
        verdict = 'Solved ${result.correct}/${result.answers.length} — ${passed ? 'success' : 'not this time'}';
    }
    ctx.outcomes.insert(0, verdict);

    final outcome = passed ? spec.onPass : spec.onFail;
    EffectResolver.applyAll(ctx, choice.effects);
    EffectResolver.applyAll(ctx, outcome.effects);
    s.story
      ..pendingChallengeChoiceId = null
      ..pendingPuzzleIds = [];
    _record(ctx, event, choice, '${choice.label} (${passed ? 'passed' : 'failed'})');
    _route(ctx, event, outcome.routes, outcome.next);
    _passTime(ctx, choice.cost.days);
  }

  static void _record(EngineContext ctx, StoryEvent event, StoryChoice choice, String label) {
    ctx.s.decisions.add(DecisionRecord(
      day: ctx.s.day,
      eventId: event.id,
      eventTitle: event.title,
      choiceId: choice.id,
      choiceLabel: label,
      outcomes: List.of(ctx.outcomes),
    ));
    ctx.s.story.lastOutcomes = List.of(ctx.outcomes);
    ctx.emit(DecisionOutcome(title: event.title, choice: label, outcomes: List.of(ctx.outcomes), shownInline: true));
  }

  static void _route(EngineContext ctx, StoryEvent event, List<Route> routes, String? next) {
    var target = next;
    for (final r in routes) {
      if (r.condition.evaluate(ctx.s, ctx.c)) {
        target = r.next;
        break;
      }
    }
    if (target == null) {
      _end(ctx, event);
    } else {
      _enter(ctx, event, target);
    }
  }

  static void _passTime(EngineContext ctx, int days) {
    for (var i = 0; i < days; i++) {
      LifeSimulation.advanceDay(ctx);
    }
  }
}
