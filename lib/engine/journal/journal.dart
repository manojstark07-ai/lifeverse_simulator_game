import '../core/json_utils.dart';

class JournalKind {
  const JournalKind._();
  static const story = 'story';
  static const money = 'money';
  static const education = 'education';
  static const career = 'career';
  static const people = 'people';
  static const milestone = 'milestone';
  static const month = 'month';
}

class JournalEntry {
  JournalEntry({
    required this.day,
    required this.title,
    required this.body,
    required this.kind,
    this.important = false,
  });

  factory JournalEntry.fromJson(Json j) => JournalEntry(
        day: j['day'] as int,
        title: j['title'] as String,
        body: j['body'] as String,
        kind: j['kind'] as String,
        important: j['important'] as bool? ?? false,
      );

  final int day;
  final String title;
  final String body;
  final String kind;
  final bool important;

  Json toJson() => {
        'day': day,
        'title': title,
        'body': body,
        'kind': kind,
        'important': important,
      };
}

/// One player decision, kept for the life timeline.
class DecisionRecord {
  DecisionRecord({
    required this.day,
    required this.eventId,
    required this.eventTitle,
    required this.choiceId,
    required this.choiceLabel,
    required this.outcomes,
  });

  factory DecisionRecord.fromJson(Json j) => DecisionRecord(
        day: j['day'] as int,
        eventId: j['eventId'] as String,
        eventTitle: j['eventTitle'] as String,
        choiceId: j['choiceId'] as String,
        choiceLabel: j['choiceLabel'] as String,
        outcomes: stringList(j['outcomes']),
      );

  final int day;
  final String eventId;
  final String eventTitle;
  final String choiceId;
  final String choiceLabel;

  /// Human readable consequence summaries ("Knowledge +3", "−₹2,000").
  final List<String> outcomes;

  Json toJson() => {
        'day': day,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'choiceId': choiceId,
        'choiceLabel': choiceLabel,
        'outcomes': outcomes,
      };
}
