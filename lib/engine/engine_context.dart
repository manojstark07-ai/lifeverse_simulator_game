import 'character/stats.dart';
import 'content/content_bundle.dart';
import 'core/json_utils.dart';
import 'core/money.dart';
import 'core/rng.dart';
import 'finance/finance_models.dart';
import 'game_events.dart';
import 'game_state.dart';
import 'journal/journal.dart';
import 'relationships/relationship_models.dart';

/// A draft of the game state being changed by one engine operation, plus the
/// shared services every module needs (content, randomness, event output).
///
/// The draft is discarded if the operation throws, so modules never need to
/// undo partial work themselves.
class EngineContext {
  EngineContext(this.s, this.c) : rng = Rng(s.rngState);

  final GameState s;
  final ContentBundle c;
  final Rng rng;
  final List<GameEvent> events = [];

  /// Human readable consequences collected while resolving one decision.
  final List<String> outcomes = [];

  void emit(GameEvent e) => events.add(e);

  /// Writes the RNG position back into the state; called once per operation.
  void commitRng() => s.rngState = rng.state;

  // ---------------------------------------------------------------- stats --

  double modifier(String key) {
    var m = 1.0;
    for (final id in s.profile.traitIds) {
      m *= c.traits[id]?.modifiers[key] ?? 1.0;
    }
    return m;
  }

  void addStat(String key, double delta, {bool record = true}) {
    if (delta == 0) return;
    final before = s.stat(key);
    final after = clampDouble(before + delta, 0, 100);
    s.stats[key] = after;
    if (record && (after - before).abs() >= 0.05) {
      outcomes.add('${StatKeys.labels[key] ?? key} ${_signed(after - before)}');
    }
  }

  void addSkill(String key, double delta, {bool record = true}) {
    if (delta == 0) return;
    final before = s.skill(key);
    final after = clampDouble(before + delta, 0, 100);
    s.skills[key] = after;
    if (record && (after - before).abs() >= 0.05) {
      outcomes.add('${SkillKeys.labels[key] ?? key} ${_signed(after - before)}');
    }
  }

  // -------------------------------------------------------------- finance --

  void credit(int amount, String category, String label, {bool record = true}) {
    if (amount <= 0) return;
    s.finance.cash += amount;
    _txn(amount, category, label);
    if (record) outcomes.add('${formatRupees(amount, signed: true)} ($label)');
  }

  /// Optional spending: fails (returns false) without changing anything when
  /// the player cannot afford it.
  bool trySpend(int amount, String category, String label, {bool record = true}) {
    if (amount <= 0) return true;
    if (s.finance.cash < amount) return false;
    s.finance.cash -= amount;
    _txn(-amount, category, label);
    if (record) outcomes.add('${formatRupees(-amount)} ($label)');
    return true;
  }

  /// Mandatory spending (bills, fees, emergencies). Whatever cannot be paid
  /// becomes arrears, so cash never goes negative. Returns the unpaid part.
  int payMandatory(int amount, String category, String label, {bool record = true}) {
    if (amount <= 0) return 0;
    final paid = amount <= s.finance.cash ? amount : s.finance.cash;
    if (paid > 0) {
      s.finance.cash -= paid;
      _txn(-paid, category, label);
    }
    final unpaid = amount - paid;
    if (unpaid > 0) {
      s.finance.arrears += unpaid;
      emit(Notice('Could not fully pay "$label": ${formatRupees(unpaid)} is now overdue.', warning: true));
    }
    if (record) outcomes.add('${formatRupees(-amount)} ($label)');
    return unpaid;
  }

  void _txn(int amount, String category, String label) {
    final f = s.finance;
    f.transactions.add(Txn(day: s.day, amount: amount, category: category, label: label, balanceAfter: f.cash));
    if (f.transactions.length > FinanceState.maxTransactions) {
      f.transactions.removeRange(0, f.transactions.length - FinanceState.maxTransactions);
    }
  }

  // -------------------------------------------------------- relationships --

  RelationshipState rel(String npcId) => s.relationships.putIfAbsent(npcId, () {
        final npc = c.npcs[npcId]!;
        return RelationshipState(npcId: npcId, affinity: npc.startAffinity, trust: npc.startTrust);
      });

  void adjustRelationship(String npcId, {double affinity = 0, double trust = 0, double conflict = 0}) {
    final r = rel(npcId);
    final name = c.npcs[npcId]?.name ?? npcId;
    r.met = true;
    r.lastInteractionDay = s.day;
    if (affinity != 0) {
      final scaled = affinity > 0 ? affinity * modifier(ModifierKeys.relationshipGain) : affinity;
      final before = r.affinity;
      r.affinity = clampDouble(r.affinity + scaled, -100, 100);
      outcomes.add('$name: closeness ${_signed(r.affinity - before)}');
    }
    if (trust != 0) {
      final before = r.trust;
      r.trust = clampDouble(r.trust + trust, 0, 100);
      outcomes.add('$name: trust ${_signed(r.trust - before)}');
    }
    if (conflict != 0) {
      final before = r.conflict;
      r.conflict = clampDouble(r.conflict + conflict, 0, 100);
      outcomes.add('$name: tension ${_signed(r.conflict - before)}');
    }
  }

  void remember(String npcId, String tag, String text, double weight) {
    final r = rel(npcId);
    r.met = true;
    if (r.remembers(tag)) return; // memories are unique per tag
    r.memories.add(Memory(day: s.day, tag: tag, text: text, weight: weight));
    outcomes.add('${c.npcs[npcId]?.name ?? npcId} will remember this');
  }

  // -------------------------------------------------------------- journal --

  void journal(String title, String body, String kind, {bool important = false}) {
    s.journal.add(JournalEntry(day: s.day, title: title, body: body, kind: kind, important: important));
  }

  static String _signed(double v) {
    final r = (v * 10).round() / 10;
    final text = r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
    return r >= 0 ? '+$text' : text;
  }
}
