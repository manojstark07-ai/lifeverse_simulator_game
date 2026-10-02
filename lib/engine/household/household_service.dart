import '../character/stats.dart';
import '../engine_context.dart';
import '../finance/finance_service.dart';
import '../game_events.dart';
import '../journal/journal.dart';
import 'household_models.dart';

/// Partners, marriage and children.
class HouseholdService {
  const HouseholdService._();

  /// Monthly cost of raising a child, by age.
  static int childCost(int age) => age < 6 ? 5000 : (age < 18 ? 9000 : 0);

  /// Share of household living costs a working spouse covers.
  static const spouseShare = 0.4;

  /// Starts (or advances) a relationship with [npcId]. A different current
  /// partner becomes an ex.
  static void setPartner(EngineContext ctx, String npcId, String status) {
    final h = ctx.s.household;
    if (h.partnerId != null && h.partnerId != npcId) _endCurrent(ctx);
    h.partnerId = npcId;
    final name = ctx.c.npcs[npcId]?.name ?? npcId;
    ctx.rel(npcId).met = true;
    setStatus(ctx, status, quiet: true);
    ctx.outcomes.add('${PartnerStatus.labels[status]}: $name');
  }

  static void setStatus(EngineContext ctx, String status, {bool quiet = false}) {
    final s = ctx.s;
    final h = s.household;
    if (!PartnerStatus.all.contains(status)) throw StateError('Unknown relationship status $status');
    if (status == PartnerStatus.single) {
      _endCurrent(ctx);
      return;
    }
    if (h.partnerId == null) throw StateError('No partner to be $status with');
    final name = ctx.c.npcs[h.partnerId]?.name ?? h.partnerId!;
    h
      ..status = status
      ..sinceDay = s.day;
    s.flags.add('has_partner');
    if (status == PartnerStatus.engaged) {
      s.flags.add('engaged');
      ctx.journal('Engaged', 'You and $name are engaged.', JournalKind.people, important: true);
    }
    if (status == PartnerStatus.married) {
      s.flags
        ..remove('engaged')
        ..add('married');
      h.marriedDay = s.day;
      ctx.journal('Married', 'You married $name.', JournalKind.milestone, important: true);
    }
    if (!quiet) ctx.outcomes.add('$name: ${PartnerStatus.labels[status]!.toLowerCase()}');
  }

  static void _endCurrent(EngineContext ctx) {
    final s = ctx.s;
    final h = s.household;
    final id = h.partnerId;
    if (id == null) return;
    final wasMarried = h.isMarried;
    if (!h.exes.contains(id)) h.exes.add(id);
    h
      ..partnerId = null
      ..status = PartnerStatus.single
      ..sinceDay = s.day
      ..marriedDay = null;
    s.flags
      ..remove('has_partner')
      ..remove('engaged')
      ..remove('married');
    final name = ctx.c.npcs[id]?.name ?? id;
    if (wasMarried) {
      h.divorces++;
      s.flags.add('divorced');
      ctx.journal('Divorced', 'You and $name went separate ways.', JournalKind.people, important: true);
      ctx.outcomes.add('Divorced from $name');
    } else {
      ctx.journal('Broke up', 'You and $name are no longer together.', JournalKind.people);
      ctx.outcomes.add('Single again');
    }
  }

  /// Adds a child. `auto` picks an unused name from content.
  static void haveChild(EngineContext ctx, String name) {
    final s = ctx.s;
    var chosen = name;
    if (name == 'auto') {
      final used = s.household.children.map((c) => c.name).toSet();
      final options = ctx.c.childNames.where((n) => !used.contains(n)).toList();
      chosen = options.isEmpty ? 'Baby ${s.household.children.length + 1}' : options[ctx.rng.nextInt(options.length)];
    }
    s.household.children.add(Child(name: chosen, birthDay: s.day));
    s.flags.add('parent');
    ctx.outcomes.add('Welcome, $chosen!');
    ctx.journal('$chosen is born', 'Your family just got bigger.', JournalKind.milestone, important: true);
    ctx.emit(Notice('$chosen has arrived!'));
  }

  /// Child costs, a spouse's share of the bills, and the steady comfort (and
  /// tiredness) of family life.
  static void settleMonth(EngineContext ctx, MonthLedger ledger, {required int livingCost}) {
    final s = ctx.s;
    final h = s.household;
    for (final child in h.children) {
      final cost = childCost(child.ageOn(s.day));
      if (cost == 0) continue;
      ctx.payMandatory(cost, 'family', '${child.name}: ${cost >= 9000 ? 'school & care' : 'childcare'}', record: false);
      ledger.addExpense(cost, '${child.name}: ${cost >= 9000 ? 'school & care' : 'childcare'}');
    }
    if (h.children.isNotEmpty) {
      ctx.addStat(StatKeys.wellbeing, 0.8, record: false);
      ctx.addStat(StatKeys.discipline, 0.2, record: false);
    }
    if (h.isMarried) {
      final share = (livingCost * spouseShare).round();
      ctx.credit(share, 'family', "Spouse's share of bills", record: false);
      ledger.addIncome(share, "Spouse's share of household bills");
    }
  }
}
