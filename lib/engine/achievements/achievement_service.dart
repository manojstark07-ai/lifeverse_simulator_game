import '../engine_context.dart';
import '../game_events.dart';
import '../journal/journal.dart';

class AchievementService {
  const AchievementService._();

  /// Unlocks an achievement once; repeated unlocks are no-ops.
  static void unlock(EngineContext ctx, String id) {
    if (ctx.s.achievements.containsKey(id)) return;
    final a = ctx.c.achievements[id];
    if (a == null) return;
    ctx.s.achievements[id] = ctx.s.day;
    ctx.journal('Achievement: ${a.title}', a.description, JournalKind.milestone);
    ctx.emit(AchievementUnlocked(id));
  }

  /// Evaluates every condition-based achievement against the draft state.
  static void evaluate(EngineContext ctx) {
    final ids = ctx.c.achievements.keys.toList()..sort();
    for (final id in ids) {
      if (ctx.s.achievements.containsKey(id)) continue;
      if (ctx.c.achievements[id]!.condition.evaluate(ctx.s, ctx.c)) unlock(ctx, id);
    }
  }
}
