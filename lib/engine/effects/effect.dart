import '../character/stats.dart';
import '../conditions/condition.dart';
import '../content/content_bundle.dart';
import '../core/json_utils.dart';
import '../household/household_models.dart';
import '../lifestyle/lifestyle_models.dart';
import '../story/story_models.dart';

/// A declarative state change. JSON form: `{"type": "<kind>", ...fields}`.
///
/// Effects are only ever applied by [EffectResolver] to a cloned draft state,
/// never directly to the state the UI is showing.
class Effect {
  const Effect._(this.type, this.raw, [this.nested = const [], this.otherwise = const [], this.when]);

  factory Effect.fromJson(Json json) {
    final type = json['type'];
    if (type is! String) {
      throw ContentFormatException('Effect is missing "type": $json');
    }
    if (!kinds.contains(type)) {
      throw ContentFormatException('Unknown effect type "$type"');
    }
    if (type == 'if') {
      return Effect._(
        type,
        json,
        jsonList(json['then']).map(Effect.fromJson).toList(),
        jsonList(json['else']).map(Effect.fromJson).toList(),
        Condition.fromJson((json['when'] as Map).cast()),
      );
    }
    final nested = type == 'delayed'
        ? jsonList(json['effects']).map(Effect.fromJson).toList()
        : const <Effect>[];
    return Effect._(type, json, nested);
  }

  static const kinds = {
    'stat', 'skill', 'money', 'flag', 'clearFlag', 'counter', 'relationship',
    'memory', 'meet', 'journal', 'openBankAccount', 'enroll', 'dropOut',
    'startPartTime', 'quitPartTime', 'hire', 'salary', 'takeLoan',
    'familySupport', 'scholarship', 'schedule', 'delayed', 'relocate',
    'endChapter', 'achievement', 'roll', 'if', 'programSkill',
    'giveItem', 'loseItem', 'partner', 'partnerStatus', 'haveChild', 'creator', 'loseJob',
    'performance', 'promote', 'switchEmployer',
  };

  /// Stands for the player's current partner in relationship effects.
  static const partnerAlias = 'partner';

  final String type;
  final Json raw;

  /// Effects wrapped by `delayed`, or the `then` branch of `if`.
  final List<Effect> nested;

  /// The `else` branch of an `if` effect.
  final List<Effect> otherwise;

  /// The condition of an `if` effect.
  final Condition? when;

  void validate(ContentBundle c, List<String> errors, String ctx) {
    void need(bool ok, String msg) {
      if (!ok) errors.add('$ctx: effect "$type" $msg');
    }

    final key = raw['key'];
    switch (type) {
      case 'stat':
        need(StatKeys.all.contains(key), 'unknown stat "$key"');
        need(raw['delta'] is num, 'needs numeric "delta"');
      case 'skill':
        need(SkillKeys.all.contains(key), 'unknown skill "$key"');
        need(raw['delta'] is num, 'needs numeric "delta"');
      case 'money':
        need(raw['amount'] is num, 'needs numeric "amount"');
        need(raw['label'] is String, 'needs "label"');
      case 'flag' || 'clearFlag':
        need(key is String && key.isNotEmpty, 'needs "key"');
      case 'counter':
        need(key is String && (raw['delta'] is num || raw['set'] is num), 'needs "key" and "delta" or "set"');
      case 'performance':
        need(raw['delta'] is num, 'needs numeric "delta"');
      case 'switchEmployer':
        need(raw['percent'] is num, 'needs numeric "percent"');
      case 'relationship' || 'memory' || 'meet':
        need(c.npcs.containsKey(raw['npc']) || raw['npc'] == partnerAlias, 'unknown npc "${raw['npc']}"');
        if (type == 'memory') need(raw['tag'] is String && raw['text'] is String, 'needs "tag" and "text"');
      case 'journal':
        need(raw['title'] is String && raw['text'] is String, 'needs "title" and "text"');
      case 'enroll':
        final p = c.programs[raw['program']];
        need(p != null, 'unknown program "${raw['program']}"');
        final tier = raw['tier'];
        if (p != null && tier != 'fromExam') need(p.tier(tier as String? ?? '') != null, 'unknown tier "$tier"');
        if (p != null && tier == 'fromExam') need(p.admissionExamId != null, 'program has no admission exam');
      case 'startPartTime':
        need(c.partTimeJobs.containsKey(raw['job']), 'unknown job "${raw['job']}"');
      case 'hire':
        need(c.careers.containsKey(raw['career']), 'unknown career "${raw['career']}"');
      case 'salary':
        need(raw['percent'] is num, 'needs numeric "percent"');
      case 'takeLoan':
        need(c.loanProducts.containsKey(raw['product']), 'unknown loan product "${raw['product']}"');
        need(raw['amount'] is num || raw['amount'] == 'remainingFees', 'needs amount');
      case 'familySupport':
        need(raw['delta'] is num || raw['set'] is num, 'needs "delta" or "set"');
      case 'scholarship':
        final share = raw['share'];
        need(share is num && share > 0 && share <= 1, 'share must be in (0,1]');
      case 'schedule':
        need(c.events.containsKey(raw['event']), 'unknown event "${raw['event']}"');
        need(c.events[raw['event']]?.trigger.kind == TriggerKind.scheduled,
            'target "${raw['event']}" must have a scheduled trigger');
        need((raw['inDays'] as num? ?? 0) >= 0, 'inDays must be >= 0');
      case 'delayed':
        need((raw['inDays'] as num? ?? 0) > 0, 'needs positive "inDays"');
        need(raw['note'] is String, 'needs "note"');
        for (final e in nested) {
          e.validate(c, errors, '$ctx(delayed)');
        }
      case 'relocate':
        need(c.hometowns.containsKey(raw['city']), 'unknown city "${raw['city']}"');
      case 'achievement':
        need(c.achievements.containsKey(raw['id']), 'unknown achievement "${raw['id']}"');
      case 'roll':
        final chance = raw['chance'];
        need(key is String && key.isNotEmpty, 'needs "key"');
        need(chance is num && chance >= 0 && chance <= 1, 'chance must be in [0,1]');
      case 'programSkill':
        need(raw['delta'] is num, 'needs numeric "delta"');
      case 'giveItem':
        need(c.shopItems.containsKey(raw['item']), 'unknown item "${raw['item']}"');
      case 'loseItem':
        need(c.shopItems.containsKey(raw['item']) || ShopCategory.all.contains(raw['category']),
            'needs a known "item" or "category"');
      case 'partner':
        need(c.npcs.containsKey(raw['npc']), 'unknown npc "${raw['npc']}"');
        need(PartnerStatus.all.contains(raw['status']) && raw['status'] != PartnerStatus.single,
            'needs status dating/engaged/married');
      case 'partnerStatus':
        need(PartnerStatus.all.contains(raw['status']), 'unknown status "${raw['status']}"');
      case 'haveChild':
        need(raw['name'] is String, 'needs "name" (or "auto")');
      case 'creator':
        need(raw['subsPercent'] is num || raw['views'] is num, 'needs "subsPercent" or "views"');
      case 'if':
        when!.validate(c, errors, '$ctx(if)');
        for (final e in [...nested, ...otherwise]) {
          e.validate(c, errors, '$ctx(if)');
        }
      default:
        break;
    }
  }

  Iterable<String> get flagsSet sync* {
    if (type == 'flag' || type == 'roll') yield raw['key'] as String;
    for (final e in [...nested, ...otherwise]) {
      yield* e.flagsSet;
    }
  }

  Iterable<String> get eventsScheduled sync* {
    if (type == 'schedule') yield raw['event'] as String;
    for (final e in [...nested, ...otherwise]) {
      yield* e.eventsScheduled;
    }
  }

  /// Flags read by `if` conditions (for the story linter).
  Iterable<String> get flagsRead sync* {
    if (when != null) yield* when!.flagsRead;
    for (final e in [...nested, ...otherwise]) {
      yield* e.flagsRead;
    }
  }
}
