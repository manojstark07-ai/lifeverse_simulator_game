import '../conditions/condition.dart';
import '../core/json_utils.dart';

class EpilogueLine {
  EpilogueLine({required this.condition, required this.text});

  factory EpilogueLine.fromJson(Json j) => EpilogueLine(
        condition: Condition.fromJson((j['when'] as Map).cast()),
        text: req<String>(j, 'text'),
      );

  final Condition condition;
  final String text;
}

/// An authored conclusion for a life chapter. The first conclusion (by
/// [priority], highest first) whose condition holds is chosen; matching
/// epilogue lines then personalise it.
class ChapterConclusion {
  ChapterConclusion({
    required this.id,
    required this.chapter,
    required this.title,
    required this.text,
    required this.priority,
    required this.condition,
  });

  factory ChapterConclusion.fromJson(Json j) => ChapterConclusion(
        id: req<String>(j, 'id'),
        chapter: req<num>(j, 'chapter').toInt(),
        title: req<String>(j, 'title'),
        text: req<String>(j, 'text'),
        priority: req<num>(j, 'priority').toInt(),
        condition: Condition.fromJson((j['condition'] as Map).cast()),
      );

  final String id;
  final int chapter;
  final String title;
  final String text;
  final int priority;
  final Condition condition;
}
