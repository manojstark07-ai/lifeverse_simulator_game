import '../conditions/condition.dart';
import '../core/json_utils.dart';
import '../effects/effect.dart';

/// A short activity the player can do during a day at a map location.
class DailyAction {
  DailyAction({
    required this.id,
    required this.label,
    required this.description,
    required this.location,
    required this.energyCost,
    required this.moneyCost,
    required this.requires,
    required this.effects,
    required this.consumesDailySlot,
  });

  factory DailyAction.fromJson(Json j) => DailyAction(
    id: req<String>(j, 'id'),
    label: req<String>(j, 'label'),
    description: req<String>(j, 'description'),
    location: req<String>(j, 'location'),
    energyCost: optNum(j, 'energyCost', 0),
    moneyCost: optInt(j, 'moneyCost', 0),
    requires: j['requires'] == null
        ? Condition.always
        : Condition.fromJson((j['requires'] as Map).cast()),
    effects: jsonList(j['effects']).map(Effect.fromJson).toList(),
    consumesDailySlot: j['consumesDailySlot'] as bool? ?? true,
  );

  final String id;
  final String label;
  final String description;
  final String location;
  final double energyCost;
  final int moneyCost;
  final Condition requires;
  final List<Effect> effects;
  final bool consumesDailySlot;
}

class MapLocation {
  MapLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.gridX,
    required this.gridY,
    required this.kind,
    required this.requires,
    required this.mapLabel,
  });

  factory MapLocation.fromJson(Json j) => MapLocation(
    id: req<String>(j, 'id'),
    name: req<String>(j, 'name'),
    description: req<String>(j, 'description'),
    gridX: req<num>(j, 'gridX').toInt(),
    gridY: req<num>(j, 'gridY').toInt(),
    kind: req<String>(j, 'kind'),
    mapLabel: j['mapLabel'] as String? ?? req<String>(j, 'name'),
    requires: j['requires'] == null
        ? Condition.always
        : Condition.fromJson((j['requires'] as Map).cast()),
  );

  final String id;
  final String name;
  final String description;
  final int gridX;
  final int gridY;

  /// Visual building style used by the map renderer.
  final String kind;
  final Condition requires;

  /// Short label drawn on the city map.
  final String mapLabel;
}
