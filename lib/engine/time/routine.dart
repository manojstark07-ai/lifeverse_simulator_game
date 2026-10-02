import '../core/json_utils.dart';

/// The player's default weekly routine, used to simulate days they do not
/// play individually. Hours are per week.
class Routine {
  Routine({
    this.study = 10,
    this.exercise = 3,
    this.social = 5,
    this.family = 5,
  });

  factory Routine.fromJson(Json j) => Routine(
        study: optNum(j, 'study', 10),
        exercise: optNum(j, 'exercise', 3),
        social: optNum(j, 'social', 5),
        family: optNum(j, 'family', 5),
      );

  /// Sleep (8h/day) and essentials (meals, chores, travel ~3h/day).
  static const sleepHours = 56.0;
  static const essentialHours = 21.0;
  static const weekHours = 168.0;
  static const freeHoursBeforeCommitments = weekHours - sleepHours - essentialHours;

  double study;
  double exercise;
  double social;
  double family;

  double get planned => study + exercise + social + family;

  Routine copy() => Routine(study: study, exercise: exercise, social: social, family: family);

  Json toJson() => {
        'study': study,
        'exercise': exercise,
        'social': social,
        'family': family,
      };
}
