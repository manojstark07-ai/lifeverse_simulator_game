import '../core/json_utils.dart';

/// Visual customisation for the procedurally drawn avatar.
class Appearance {
  const Appearance({
    this.skinTone = 2,
    this.hairStyle = 0,
    this.hairColor = 0,
    this.outfit = 0,
    this.expression = 0,
    this.accessory = 0,
  });

  factory Appearance.fromJson(Json j) => Appearance(
        skinTone: optInt(j, 'skinTone', 2),
        hairStyle: optInt(j, 'hairStyle', 0),
        hairColor: optInt(j, 'hairColor', 0),
        outfit: optInt(j, 'outfit', 0),
        expression: optInt(j, 'expression', 0),
        accessory: optInt(j, 'accessory', 0),
      );

  static const skinToneCount = 6;
  static const hairStyleCount = 5;
  static const hairColorCount = 5;
  static const outfitCount = 6;
  static const expressionCount = 3;
  static const accessoryCount = 4;

  final int skinTone;
  final int hairStyle;
  final int hairColor;
  final int outfit;
  final int expression;
  final int accessory;

  Appearance copyWith({
    int? skinTone,
    int? hairStyle,
    int? hairColor,
    int? outfit,
    int? expression,
    int? accessory,
  }) =>
      Appearance(
        skinTone: skinTone ?? this.skinTone,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
        outfit: outfit ?? this.outfit,
        expression: expression ?? this.expression,
        accessory: accessory ?? this.accessory,
      );

  Json toJson() => {
        'skinTone': skinTone,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'outfit': outfit,
        'expression': expression,
        'accessory': accessory,
      };
}

/// Everything the player chose at character creation.
class CharacterSpec {
  const CharacterSpec({
    required this.name,
    required this.pronouns,
    required this.appearance,
    required this.hometownId,
    required this.backgroundId,
    required this.traitIds,
    required this.interestIds,
    required this.ambitionId,
    required this.seed,
    this.matureThemes = true,
  });

  final String name;
  final String pronouns;
  final Appearance appearance;
  final String hometownId;
  final String backgroundId;
  final List<String> traitIds;
  final List<String> interestIds;
  final String ambitionId;
  final int seed;

  /// Enables alcohol, smoking, crime and dating storylines (flag `mature_on`).
  final bool matureThemes;
}

class PlayerProfile {
  PlayerProfile({
    required this.name,
    required this.pronouns,
    required this.appearance,
    required this.birthDate,
    required this.hometownId,
    required this.currentCityId,
    required this.backgroundId,
    required this.traitIds,
    required this.interestIds,
    required this.ambitionId,
  });

  factory PlayerProfile.fromJson(Json j) => PlayerProfile(
        name: j['name'] as String,
        pronouns: j['pronouns'] as String? ?? 'they/them',
        appearance: Appearance.fromJson((j['appearance'] as Map).cast()),
        birthDate: DateTime.parse(j['birthDate'] as String),
        hometownId: j['hometownId'] as String,
        currentCityId: j['currentCityId'] as String,
        backgroundId: j['backgroundId'] as String,
        traitIds: stringList(j['traitIds']),
        interestIds: stringList(j['interestIds']),
        ambitionId: j['ambitionId'] as String,
      );

  String name;
  String pronouns;
  Appearance appearance;
  DateTime birthDate;
  String hometownId;

  /// Where the player currently lives; drives living costs.
  String currentCityId;
  String backgroundId;
  List<String> traitIds;
  List<String> interestIds;
  String ambitionId;

  Json toJson() => {
        'name': name,
        'pronouns': pronouns,
        'appearance': appearance.toJson(),
        'birthDate': birthDate.toIso8601String(),
        'hometownId': hometownId,
        'currentCityId': currentCityId,
        'backgroundId': backgroundId,
        'traitIds': traitIds,
        'interestIds': interestIds,
        'ambitionId': ambitionId,
      };
}
