import '../conditions/condition.dart';
import '../core/json_utils.dart';
import '../effects/effect.dart';

/// A recurring monthly consequence of an ongoing habit or situation
/// (smoking, a relationship, a heavy drinking habit…), applied during
/// monthly settlement while [when] holds.
class MonthlyRule {
  MonthlyRule({required this.id, required this.label, required this.when, required this.effects});

  factory MonthlyRule.fromJson(Json j) => MonthlyRule(
        id: req<String>(j, 'id'),
        label: req<String>(j, 'label'),
        when: Condition.fromJson((j['when'] as Map).cast()),
        effects: jsonList(j['effects']).map(Effect.fromJson).toList(),
      );

  final String id;
  final String label;
  final Condition when;
  final List<Effect> effects;
}

/// Adjusts every job-interview score while [when] holds — e.g. a police
/// record surfacing in a background check.
class InterviewModifier {
  InterviewModifier({required this.id, required this.when, required this.delta, required this.reason});

  factory InterviewModifier.fromJson(Json j) => InterviewModifier(
        id: req<String>(j, 'id'),
        when: Condition.fromJson((j['when'] as Map).cast()),
        delta: reqNum(j, 'delta'),
        reason: req<String>(j, 'reason'),
      );

  final String id;
  final Condition when;
  final double delta;
  final String reason;
}
