/// Notifications emitted by the engine for the presentation layer (toasts,
/// navigation) and for cross-module listeners. They describe what happened;
/// state changes themselves are already applied when they are emitted.
sealed class GameEvent {
  const GameEvent();
}

class MonthSettled extends GameEvent {
  const MonthSettled({
    required this.monthKey,
    required this.income,
    required this.expenses,
    required this.lines,
  });

  final int monthKey;
  final int income;
  final int expenses;
  final List<String> lines;
}

class AchievementUnlocked extends GameEvent {
  const AchievementUnlocked(this.achievementId);
  final String achievementId;
}

class StoryEventStarted extends GameEvent {
  const StoryEventStarted(this.eventId);
  final String eventId;
}

class ChapterConcluded extends GameEvent {
  const ChapterConcluded(this.conclusionId);
  final String conclusionId;
}

class Notice extends GameEvent {
  const Notice(this.text, {this.warning = false});
  final String text;
  final bool warning;
}

/// The consequences of a resolved story decision.
class DecisionOutcome extends GameEvent {
  const DecisionOutcome({required this.title, required this.choice, required this.outcomes, this.shownInline = false});
  final String title;

  /// Outcomes already shown on screen (story nodes, puzzle reviews) are not
  /// repeated as toasts.
  final bool shownInline;
  final String choice;
  final List<String> outcomes;
}
