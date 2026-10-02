import '../character/stats.dart';
import '../content/content_bundle.dart';
import '../core/game_calendar.dart';
import '../core/json_utils.dart';
import '../education/education_models.dart';
import '../game_state.dart';
import '../household/household_models.dart';
import '../lifestyle/lifestyle_models.dart';

/// Comparison operators allowed in condition JSON.
class Op {
  const Op._();
  static const all = ['>=', '<=', '>', '<', '==', '!='];

  static bool compare(num a, String op, num b) => switch (op) {
        '>=' => a >= b,
        '<=' => a <= b,
        '>' => a > b,
        '<' => a < b,
        '==' => a == b,
        '!=' => a != b,
        _ => throw ContentFormatException('Unknown operator "$op"'),
      };

  static String symbol(String op) => switch (op) {
        '>=' => '≥',
        '<=' => '≤',
        '!=' => '≠',
        _ => op,
      };
}

/// A declarative, serialisable predicate over the game state.
///
/// JSON form: `{"type": "<kind>", ...fields}`. Composite kinds are `all`,
/// `any` and `not`. Conditions are pure: evaluating them never mutates state
/// or consumes randomness, so they are safe to call from the UI.
class Condition {
  const Condition._(this.type, this.raw, [this.children = const []]);

  factory Condition.fromJson(Json json) {
    final type = json['type'];
    if (type is! String) {
      throw ContentFormatException('Condition is missing "type": $json');
    }
    if (!kinds.contains(type)) {
      throw ContentFormatException('Unknown condition type "$type"');
    }
    switch (type) {
      case 'all' || 'any':
        final children = jsonList(json['conditions']).map(Condition.fromJson).toList();
        return Condition._(type, json, children);
      case 'not':
        return Condition._(type, json, [Condition.fromJson((json['condition'] as Map).cast())]);
      default:
        final op = json['op'];
        if (op != null && !Op.all.contains(op)) {
          throw ContentFormatException('Unknown operator "$op" in $json');
        }
        return Condition._(type, json);
    }
  }

  static const always = Condition._('always', {});

  static const kinds = {
    'always', 'all', 'any', 'not', 'flag', 'stat', 'skill', 'cash', 'debt',
    'age', 'background', 'hometown', 'ambition', 'trait', 'educationStatus',
    'program', 'graduated', 'programProgress', 'cgpa', 'backlogs',
    'relationship', 'memory', 'eventDone', 'daysSinceEvent', 'examTier',
    'examAttempts', 'partTime', 'career', 'careerLevel', 'counter', 'month',
    'hasLoan', 'arrearsMonths', 'chapter', 'city', 'day', 'arrears',
    'monthsEnrolled', 'careerMonths', 'performance', 'monthsInRole',
    'owns', 'relationshipStatus', 'partner', 'children', 'creator', 'yearsMarried',
  };

  final String type;
  final Json raw;
  final List<Condition> children;

  String get _key => raw['key'] as String? ?? '';
  String get _op => raw['op'] as String? ?? '>=';
  num get _num => raw['value'] as num;
  Object? get _value => raw['value'];

  bool evaluate(GameState s, ContentBundle c) {
    switch (type) {
      case 'always':
        return true;
      case 'all':
        return children.every((ch) => ch.evaluate(s, c));
      case 'any':
        return children.any((ch) => ch.evaluate(s, c));
      case 'not':
        return !children.first.evaluate(s, c);
      case 'flag':
        return s.flags.contains(_key);
      case 'stat':
        return Op.compare(s.stat(_key), _op, _num);
      case 'skill':
        return Op.compare(s.skill(_key), _op, _num);
      case 'cash':
        return Op.compare(s.finance.cash, _op, _num);
      case 'debt':
        return Op.compare(s.finance.totalDebt, _op, _num);
      case 'age':
        return Op.compare(GameCalendar.ageOn(s.profile.birthDate, s.day), _op, _num);
      case 'background':
        return s.profile.backgroundId == _value;
      case 'hometown':
        return s.profile.hometownId == _value;
      case 'city':
        return s.profile.currentCityId == _value;
      case 'ambition':
        return s.profile.ambitionId == _value;
      case 'trait':
        return s.profile.traitIds.contains(_value);
      case 'educationStatus':
        return s.education.status == _value;
      case 'program':
        return s.education.programId == _value;
      case 'graduated':
        final v = _value;
        return v == null
            ? s.education.completedPrograms.isNotEmpty
            : s.education.completedPrograms.contains(v);
      case 'programProgress':
        final program = c.programs[s.education.programId];
        if (program == null || !s.education.isEnrolled) return false;
        return Op.compare(s.education.monthsCompleted / program.durationMonths, _op, _num);
      case 'cgpa':
        return Op.compare(s.education.cgpa, _op, _num);
      case 'backlogs':
        return Op.compare(s.education.backlogs, _op, _num);
      case 'relationship':
        final rel = s.relationships[raw['npc']];
        if (rel == null) return false;
        final field = raw['field'] as String? ?? 'affinity';
        final v = switch (field) {
          'trust' => rel.trust,
          'conflict' => rel.conflict,
          _ => rel.affinity,
        };
        return Op.compare(v, _op, _num);
      case 'memory':
        return s.relationships[raw['npc']]?.remembers(raw['tag'] as String) ?? false;
      case 'eventDone':
        return s.story.completed.contains(_value);
      case 'daysSinceEvent':
        final fired = s.story.lastFiredDay[raw['event']];
        if (fired == null) return false;
        return Op.compare(s.day - fired, _op, _num);
      case 'examTier':
        final exam = c.exams[raw['exam']];
        final record = s.exams[raw['exam']];
        if (exam == null || record == null || record.attempts.isEmpty) return false;
        final best = record.attempts.map((a) => exam.tierRank(a.tierId)).reduce((a, b) => a < b ? a : b);
        final wanted = exam.tierRank(_value as String);
        // `latest: true` looks only at the most recent attempt.
        final rank = raw['latest'] == true ? exam.tierRank(record.attempts.last.tierId) : best;
        return raw['exact'] == true ? rank == wanted : rank <= wanted;
      case 'examAttempts':
        final attempts = s.exams[raw['exam']]?.attempts.length ?? 0;
        return Op.compare(attempts, _op, _num);
      case 'partTime':
        final v = _value;
        if (v is bool) return (s.career.partTimeJobId != null) == v;
        return s.career.partTimeJobId == v;
      case 'career':
        final v = _value;
        if (v is bool) return s.career.hasCareer == v;
        return s.career.careerId == v;
      case 'careerLevel':
        return s.career.hasCareer && Op.compare(s.career.level, _op, _num);
      case 'counter':
        return Op.compare(s.counter(_key), _op, _num);
      case 'month':
        return Op.compare(GameCalendar.dateOf(s.day).month, _op, _num);
      case 'hasLoan':
        final v = _value;
        return s.finance.loans.any((l) => !l.closed && (v == null || l.kind == v || l.productId == v));
      case 'arrearsMonths':
        return Op.compare(s.finance.monthsInArrears, _op, _num);
      case 'chapter':
        return Op.compare(s.chapter, _op, _num);
      case 'day':
        return Op.compare(s.day, _op, _num);
      case 'arrears':
        return Op.compare(s.finance.arrears, _op, _num);
      case 'monthsEnrolled':
        return s.education.isEnrolled && Op.compare(s.education.monthsCompleted, _op, _num);
      case 'careerMonths':
        return s.career.hasCareer && Op.compare(s.career.monthsInCareer, _op, _num);
      case 'performance':
        return s.career.hasCareer && Op.compare(s.career.performance, _op, _num);
      case 'monthsInRole':
        return s.career.hasCareer && Op.compare(s.career.monthsInRole, _op, _num);
      case 'owns':
        // `value`: an item id; `category` or `slot`: any matching item.
        final category = raw['category'];
        final slot = raw['slot'];
        if (category == null && slot == null) return s.owns(_value as String);
        return s.possessions.any((o) {
          final item = c.shopItems[o.itemId];
          return item != null && (category == null || item.category == category) && (slot == null || item.slot == slot);
        });
      case 'relationshipStatus':
        return s.household.status == _value;
      case 'partner':
        // `npc`: the partner is this person; `field`: a bond threshold.
        final id = s.household.partnerId;
        if (id == null || !s.household.hasPartner) return false;
        if (raw['npc'] != null && raw['npc'] != id) return false;
        if (raw['field'] == null) return true;
        final rel = s.relationships[id];
        if (rel == null) return false;
        final v = switch (raw['field']) {
          'trust' => rel.trust,
          'conflict' => rel.conflict,
          _ => rel.affinity,
        };
        return Op.compare(v, _op, _num);
      case 'children':
        return Op.compare(s.household.children.length, _op, _num);
      case 'yearsMarried':
        final since = s.household.marriedDay;
        return since != null && s.household.isMarried && Op.compare((s.day - since) / 365, _op, _num);
      case 'creator':
        // No `field`: whether a channel exists (value true/false).
        final cr = s.creator;
        final field = raw['field'] as String?;
        if (field == null) return (cr != null) == (_value as bool? ?? true);
        if (cr == null) return false;
        return switch (field) {
          'subscribers' => Op.compare(cr.subscribers, _op, _num),
          'videos' => Op.compare(cr.videos, _op, _num),
          'monetized' => cr.monetized == _value,
          'fullTime' => cr.fullTime == _value,
          _ => false,
        };
    }
    return false;
  }

  /// Short player-facing description, used for locked choices.
  String describe(ContentBundle c) {
    String cmp(String label) => '$label ${Op.symbol(_op)} ${_fmt(_num)}';
    switch (type) {
      case 'always':
        return '';
      case 'all':
        return children.map((e) => e.describe(c)).where((e) => e.isNotEmpty).join(' and ');
      case 'any':
        return children.map((e) => e.describe(c)).where((e) => e.isNotEmpty).join(' or ');
      case 'not':
        return 'not (${children.first.describe(c)})';
      case 'stat':
        return cmp(StatKeys.labels[_key] ?? _key);
      case 'skill':
        return cmp(SkillKeys.labels[_key] ?? _key);
      case 'cash':
        return 'Cash ${Op.symbol(_op)} ₹${_fmt(_num)}';
      case 'age':
        return cmp('Age');
      case 'relationship':
        final npc = c.npcs[raw['npc']]?.name ?? raw['npc'];
        return cmp('$npc ${raw['field'] ?? 'affinity'}');
      case 'graduated':
        return _value == null ? 'A completed qualification' : 'Completed ${c.programs[_value]?.shortName ?? _value}';
      case 'educationStatus':
        return _value == EducationStatus.enrolled ? 'Currently enrolled' : 'Education: $_value';
      case 'partTime':
        return _value == false ? 'No part-time job' : 'A part-time job';
      case 'cgpa':
        return cmp('CGPA');
      case 'performance':
        return cmp('Job performance');
      case 'monthsInRole':
        return cmp('Months in role');
      case 'examTier':
        final exam = c.exams[raw['exam']];
        final tier = exam?.tiers.where((t) => t.id == _value).firstOrNull;
        return '${exam?.shortName ?? raw['exam']}: ${tier?.label ?? _value}';
      case 'owns':
        final category = raw['category'];
        final slot = raw['slot'];
        if (slot != null) return 'Your own ${slot.toString().replaceAll('_', '-')}';
        return category == null
            ? 'Owns ${c.shopItems[_value]?.name ?? _value}'
            : 'Owns ${ShopCategory.labels[category]?.toLowerCase() ?? category}';
      case 'flag' when _key == 'driving_licence':
        return 'A driving licence';
      case 'relationshipStatus':
        return PartnerStatus.labels[_value] ?? '$_value';
      case 'creator':
        return raw['field'] == 'subscribers' ? cmp('Subscribers') : 'A ViewTube channel';
      default:
        return 'Special circumstances';
    }
  }

  static String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

  /// Referential validation against content. Appends messages to [errors].
  void validate(ContentBundle c, List<String> errors, String ctx) {
    void need(bool ok, String msg) {
      if (!ok) errors.add('$ctx: $msg');
    }

    bool hasNum() => raw['value'] is num;
    switch (type) {
      case 'all' || 'any' || 'not':
        for (final ch in children) {
          ch.validate(c, errors, ctx);
        }
      case 'stat':
        need(StatKeys.all.contains(_key), 'unknown stat "$_key"');
        need(hasNum(), 'stat condition needs numeric value');
      case 'skill':
        need(SkillKeys.all.contains(_key), 'unknown skill "$_key"');
        need(hasNum(), 'skill condition needs numeric value');
      case 'flag' || 'counter':
        need(_key.isNotEmpty, '$type condition needs "key"');
      case 'background':
        need(c.backgrounds.containsKey(_value), 'unknown background "$_value"');
      case 'hometown' || 'city':
        need(c.hometowns.containsKey(_value), 'unknown hometown "$_value"');
      case 'ambition':
        need(c.ambitions.containsKey(_value), 'unknown ambition "$_value"');
      case 'trait':
        need(c.traits.containsKey(_value), 'unknown trait "$_value"');
      case 'program':
        need(c.programs.containsKey(_value), 'unknown program "$_value"');
      case 'graduated':
        need(_value == null || c.programs.containsKey(_value), 'unknown program "$_value"');
      case 'relationship' || 'memory':
        need(c.npcs.containsKey(raw['npc']), 'unknown npc "${raw['npc']}"');
      case 'eventDone':
        need(c.events.containsKey(_value), 'unknown event "$_value"');
      case 'daysSinceEvent':
        need(c.events.containsKey(raw['event']), 'unknown event "${raw['event']}"');
      case 'examTier':
        final exam = c.exams[raw['exam']];
        need(exam != null, 'unknown exam "${raw['exam']}"');
        need(exam == null || exam.tiers.any((t) => t.id == _value), 'unknown tier "$_value"');
      case 'examAttempts':
        need(c.exams.containsKey(raw['exam']), 'unknown exam "${raw['exam']}"');
      case 'career':
        need(_value is bool || c.careers.containsKey(_value), 'unknown career "$_value"');
      case 'partTime':
        need(_value is bool || c.partTimeJobs.containsKey(_value), 'unknown part-time job "$_value"');
      case 'owns':
        final category = raw['category'];
        final slot = raw['slot'];
        if (category == null && slot == null) need(c.shopItems.containsKey(_value), 'unknown item "$_value"');
        if (category != null) need(ShopCategory.all.contains(category), 'unknown category "$category"');
        if (slot != null) need(c.shopItems.values.any((i) => i.slot == slot), 'no item uses slot "$slot"');
      case 'relationshipStatus':
        need(PartnerStatus.all.contains(_value), 'unknown relationship status "$_value"');
      case 'partner':
        need(raw['npc'] == null || c.npcs.containsKey(raw['npc']), 'unknown npc "${raw['npc']}"');
        need(raw['field'] == null || hasNum(), 'partner field condition needs numeric value');
      case 'children' || 'yearsMarried' || 'performance' || 'monthsInRole':
        need(hasNum(), '$type condition needs numeric value');
      case 'creator':
        need(const [null, 'subscribers', 'videos', 'monetized', 'fullTime'].contains(raw['field']),
            'unknown creator field "${raw['field']}"');
      case 'educationStatus':
        need(const [EducationStatus.none, EducationStatus.enrolled, EducationStatus.graduated, EducationStatus.dropped]
            .contains(_value), 'unknown education status "$_value"');
      default:
        break;
    }
  }

  /// Flags this condition reads; used by the story graph linter.
  Iterable<String> get flagsRead sync* {
    if (type == 'flag') yield _key;
    for (final ch in children) {
      yield* ch.flagsRead;
    }
  }
}
