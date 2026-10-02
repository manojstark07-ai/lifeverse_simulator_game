import '../conditions/condition.dart';
import '../core/json_utils.dart';

class Achievement {
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.condition,
    this.hidden = false,
  });

  factory Achievement.fromJson(Json j) => Achievement(
        id: req<String>(j, 'id'),
        title: req<String>(j, 'title'),
        description: req<String>(j, 'description'),
        condition: Condition.fromJson((j['condition'] as Map).cast()),
        hidden: j['hidden'] as bool? ?? false,
      );

  final String id;
  final String title;
  final String description;
  final Condition condition;
  final bool hidden;
}
