import '../content/content_bundle.dart';
import '../engine_context.dart';
import '../game_events.dart';
import '../game_state.dart';
import '../journal/journal.dart';
import 'chapter_conclusion.dart';

class ConclusionService {
  const ConclusionService._();

  static ChapterConclusion select(GameState s, ContentBundle c, int chapter) {
    final candidates =
        c.conclusions.values.where((x) => x.chapter == chapter).toList()..sort(
          (a, b) => b.priority != a.priority
              ? b.priority.compareTo(a.priority)
              : a.id.compareTo(b.id),
        );
    return candidates.firstWhere(
      (x) => x.condition.evaluate(s, c),
      orElse: () => throw StateError('No conclusion matches chapter $chapter'),
    );
  }

  static void conclude(EngineContext ctx) {
    final s = ctx.s;
    final marker = 'conclusion_chapter_${s.chapter}';
    if (s.counters[marker] == 1) return;
    final conclusion = select(s, ctx.c, s.chapter);
    s.conclusionId = conclusion.id;
    s.conclusionDay = s.day;
    s.counters[marker] = 1;
    s.chapter++;
    s.flags.add('chapter${conclusion.chapter}_complete');
    ctx.journal(
      'Chapter complete: ${conclusion.title}',
      conclusion.text,
      JournalKind.milestone,
      important: true,
    );
    ctx.emit(ChapterConcluded(conclusion.id));
  }

  /// Personalised closing lines for the conclusion screen.
  static List<String> epilogue(GameState s, ContentBundle c) => c.epilogueLines
      .where((l) => l.condition.evaluate(s, c))
      .map((l) => l.text)
      .toList();
}
