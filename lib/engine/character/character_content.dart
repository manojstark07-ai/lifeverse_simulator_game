import '../core/json_utils.dart';

/// A starting family situation. Backgrounds change resources, obligations and
/// story opportunities — never innate ability.
class Background {
  Background({
    required this.id,
    required this.name,
    required this.summary,
    required this.description,
    required this.startingCash,
    required this.familySupportMonthly,
    required this.startStats,
    required this.startSkills,
    required this.flags,
    required this.obligations,
    required this.opportunities,
    required this.familyAffinity,
    required this.lifestyleCostMultiplier,
  });

  factory Background.fromJson(Json j) => Background(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        summary: req<String>(j, 'summary'),
        description: req<String>(j, 'description'),
        startingCash: req<num>(j, 'startingCash').toInt(),
        familySupportMonthly: req<num>(j, 'familySupportMonthly').toInt(),
        startStats: numMap(j['startStats']),
        startSkills: numMap(j['startSkills']),
        flags: stringList(j['flags']),
        obligations: stringList(j['obligations']),
        opportunities: stringList(j['opportunities']),
        familyAffinity: optNum(j, 'familyAffinity', 40),
        lifestyleCostMultiplier: optNum(j, 'lifestyleCostMultiplier', 1),
      );

  final String id;
  final String name;
  final String summary;
  final String description;
  final int startingCash;
  final int familySupportMonthly;
  final Map<String, double> startStats;
  final Map<String, double> startSkills;
  final List<String> flags;
  final List<String> obligations;
  final List<String> opportunities;
  final double familyAffinity;

  /// Habits formed growing up: comfortable families spend more by default.
  final double lifestyleCostMultiplier;
}

class Hometown {
  Hometown({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.livingCostMonthly,
    required this.rentMonthly,
    required this.wageMultiplier,
    required this.commuteHoursWeekly,
  });

  factory Hometown.fromJson(Json j) => Hometown(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        kind: req<String>(j, 'kind'),
        description: req<String>(j, 'description'),
        livingCostMonthly: req<num>(j, 'livingCostMonthly').toInt(),
        rentMonthly: req<num>(j, 'rentMonthly').toInt(),
        wageMultiplier: reqNum(j, 'wageMultiplier'),
        commuteHoursWeekly: reqNum(j, 'commuteHoursWeekly'),
      );

  final String id;
  final String name;

  /// `metro` or `rural`.
  final String kind;
  final String description;

  /// Indicative monthly personal spend for a student living with family.
  final int livingCostMonthly;

  /// Indicative rent for a shared flat when living independently.
  final int rentMonthly;
  final double wageMultiplier;
  final double commuteHoursWeekly;
}

class Trait {
  Trait({
    required this.id,
    required this.name,
    required this.description,
    required this.startStats,
    required this.modifiers,
  });

  factory Trait.fromJson(Json j) => Trait(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        description: req<String>(j, 'description'),
        startStats: numMap(j['startStats']),
        modifiers: numMap(j['modifiers']),
      );

  final String id;
  final String name;
  final String description;
  final Map<String, double> startStats;
  final Map<String, double> modifiers;
}

class Interest {
  Interest({required this.id, required this.name, required this.startSkills});

  factory Interest.fromJson(Json j) => Interest(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        startSkills: numMap(j['startSkills']),
      );

  final String id;
  final String name;
  final Map<String, double> startSkills;
}

class Ambition {
  Ambition({required this.id, required this.name, required this.description});

  factory Ambition.fromJson(Json j) => Ambition(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        description: req<String>(j, 'description'),
      );

  final String id;
  final String name;
  final String description;
}
