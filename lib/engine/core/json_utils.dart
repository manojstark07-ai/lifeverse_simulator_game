/// Small helpers for reading loosely typed JSON into strongly typed models.
library;

typedef Json = Map<String, dynamic>;

class ContentFormatException implements Exception {
  ContentFormatException(this.message);
  final String message;
  @override
  String toString() => 'ContentFormatException: $message';
}

T req<T>(Json json, String key, [String context = '']) {
  final value = json[key];
  if (value is! T) {
    throw ContentFormatException(
        '${context.isEmpty ? '' : '$context: '}"$key" must be $T but was ${value.runtimeType}');
  }
  return value;
}

double reqNum(Json json, String key, [String context = '']) =>
    req<num>(json, key, context).toDouble();

double optNum(Json json, String key, double fallback) =>
    (json[key] as num?)?.toDouble() ?? fallback;

int optInt(Json json, String key, int fallback) =>
    (json[key] as num?)?.toInt() ?? fallback;

List<Json> jsonList(Object? value) =>
    value == null ? const [] : (value as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();

Map<String, double> numMap(Object? value) => value == null
    ? <String, double>{}
    : (value as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));

List<String> stringList(Object? value) =>
    value == null ? const [] : (value as List).cast<String>().toList();

double clampDouble(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
