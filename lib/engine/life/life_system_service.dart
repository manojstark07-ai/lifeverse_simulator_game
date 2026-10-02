import 'dart:math' as math;

import '../core/game_calendar.dart';
import '../core/money.dart';
import '../engine_context.dart';
import '../finance/finance_service.dart';
import '../game_state.dart';
import '../journal/journal.dart';
import 'life_systems.dart';

/// Long-horizon systems shared by the business, finance, world and legacy
/// phases. All numbers are fictional and deliberately legible to players.
class LifeSystemService {
  const LifeSystemService._();

  static const businessLaunchCost = 50000;
  static const propertySequence = 1;

  static BusinessVenture startBusiness(
    EngineContext ctx, {
    required String name,
    required String sector,
  }) {
    final s = ctx.s;
    if (name.trim().length < 2) throw StateError('Give your venture a name');
    if (!ctx.trySpend(businessLaunchCost, 'business', 'Venture launch')) {
      throw StateError(
        'You need ${formatRupees(businessLaunchCost)} to launch',
      );
    }
    final id = 'venture_${s.life.nextBusinessSeq++}';
    final venture = BusinessVenture(
      id: id,
      name: name.trim(),
      sector: sector,
      cityId: s.profile.currentCityId,
      foundedDay: s.day,
      cash: businessLaunchCost,
      monthlyRevenue: 8000,
      monthlyCosts: 6500,
      valuation: businessLaunchCost,
    );
    s.life.businesses.add(venture);
    s.flags.add('entrepreneur');
    ctx.addSkill('business', 3);
    ctx.journal(
      'Venture launched',
      '${venture.name} opened in ${venture.cityId}. The first challenge is making something people return for.',
      JournalKind.career,
      important: true,
    );
    ctx.outcomes.add('${venture.name} launched');
    return venture;
  }

  static BusinessVenture venture(EngineContext ctx, String id) =>
      ctx.s.life.businesses.firstWhere(
        (x) => x.id == id && x.active,
        orElse: () => throw StateError('No active venture $id'),
      );

  static void runProject(
    EngineContext ctx,
    String businessId, {
    required String title,
    required int budget,
  }) {
    final b = venture(ctx, businessId);
    if (!ctx.trySpend(budget, 'business', '$title project')) {
      throw StateError('You need ${formatRupees(budget)} for this project');
    }
    b.cash += budget;
    b.projects.add(title);
    b.productStage = math.min(5, b.productStage + 1);
    b.monthlyRevenue += 7000 + b.productStage * 1500;
    b.monthlyCosts += 1800;
    b.reputation = (b.reputation + 6).clamp(0, 100).toDouble();
    b.valuation = math.max(b.valuation, b.monthlyRevenue * 12 + b.cash);
    ctx.addSkill('business', 1.2);
    ctx.addStat('discipline', 0.8);
    ctx.outcomes.add(
      '$title shipped: ${b.name} is now at product stage ${b.productStage}',
    );
  }

  static void hire(EngineContext ctx, String businessId) {
    final b = venture(ctx, businessId);
    const cost = 18000;
    if (!ctx.trySpend(cost, 'business', 'First-year hiring budget')) {
      throw StateError('You need ${formatRupees(cost)} to hire');
    }
    b.cash += cost;
    b.employees++;
    b.monthlyRevenue += 9000;
    b.monthlyCosts += 12000;
    b.reputation = (b.reputation + 3).clamp(0, 100).toDouble();
    ctx.addSkill('leadership', 1.5);
    ctx.outcomes.add('Hired teammate ${b.employees}');
  }

  static void raiseFunding(EngineContext ctx, String businessId) {
    final b = venture(ctx, businessId);
    const funding = 150000;
    b.cash += funding;
    b.valuation += funding * 3;
    b.productStage = math.min(5, b.productStage + 1);
    ctx.s.flags.add('funded_venture');
    ctx.journal(
      'Funding round',
      '${b.name} raised ${formatRupees(funding)} from fictional Northstar Ventures.',
      JournalKind.money,
      important: true,
    );
    ctx.outcomes.add('${formatRupees(funding)} added to company cash');
  }

  static PropertyAsset buyProperty(
    EngineContext ctx, {
    required String name,
    required String kind,
    required int value,
    required int rent,
  }) {
    if (!ctx.trySpend(value, 'property', name)) {
      throw StateError('You need ${formatRupees(value)} to buy this property');
    }
    final s = ctx.s;
    final property = PropertyAsset(
      id: 'property_${s.life.nextPropertySeq++}',
      name: name,
      kind: kind,
      cityId: s.profile.currentCityId,
      purchasedDay: s.day,
      value: value,
      monthlyMaintenance: (value * 0.0015).round().clamp(500, 30000),
      monthlyRent: rent,
    );
    s.life.properties.add(property);
    s.flags.add('property_owner');
    ctx.journal(
      'Property purchased',
      '$name is now part of your long-term plan.',
      JournalKind.money,
      important: true,
    );
    ctx.outcomes.add('Bought $name');
    return property;
  }

  static void sellProperty(EngineContext ctx, String propertyId) {
    final property = ctx.s.life.properties.firstWhere(
      (x) => x.id == propertyId,
      orElse: () => throw StateError('Property not found'),
    );
    final proceeds = (property.value * 0.94).round() - property.mortgage;
    ctx.credit(math.max(0, proceeds), 'property', 'Sale of ${property.name}');
    ctx.s.life.properties.remove(property);
    ctx.outcomes.add(
      'Sold ${property.name} for ${formatRupees(math.max(0, proceeds))}',
    );
  }

  static void insure(EngineContext ctx, {required String kind}) {
    final s = ctx.s;
    if (s.life.insurance.any((p) => p.kind == kind && p.active)) {
      throw StateError('You already have active $kind cover');
    }
    final policy = InsurancePolicy(
      id: 'policy_${s.day}_${s.life.insurance.length + 1}',
      kind: kind,
      coverage: kind == 'health' ? 500000 : 250000,
      deductible: kind == 'health' ? 5000 : 10000,
      monthlyPremium: kind == 'health' ? 850 : 650,
      startedDay: s.day,
    );
    s.life.insurance.add(policy);
    ctx.journal(
      'Insurance added',
      '${kind[0].toUpperCase()}${kind.substring(1)} cover is active.',
      JournalKind.money,
    );
    ctx.outcomes.add('${policy.kind} insurance active');
  }

  static void contributeRetirement(EngineContext ctx, int amount) {
    if (amount <= 0) throw StateError('Contribution must be positive');
    if (!ctx.trySpend(amount, 'retirement', 'Retirement contribution')) {
      throw StateError('Not enough cash for that contribution');
    }
    ctx.s.life.retirementBalance += amount;
    ctx.s.life.retirementContributions += amount;
    ctx.s.flags.add('retirement_plan');
    ctx.outcomes.add('${formatRupees(amount)} invested for later life');
  }

  static void payTaxes(EngineContext ctx, {int? amount}) {
    final due = ctx.s.life.taxesDue;
    if (due <= 0) throw StateError('No taxes are due');
    final pay = math.min(amount ?? due, due);
    if (!ctx.trySpend(pay, 'tax', 'Annual tax payment')) {
      throw StateError('Not enough cash to pay ${formatRupees(pay)}');
    }
    ctx.s.life.taxesDue -= pay;
    ctx.s.life.taxesPaid += pay;
    ctx.s.life.lastTaxYear = GameCalendar.dateOf(ctx.s.day).year;
    ctx.outcomes.add('Paid ${formatRupees(pay)} in tax');
  }

  static void retire(EngineContext ctx) {
    final age = GameCalendar.ageOn(ctx.s.profile.birthDate, ctx.s.day);
    if (age < 55) throw StateError('Retirement unlocks at age 55');
    if (ctx.s.life.retired) return;
    ctx.s.life.retired = true;
    ctx.s.life.retirementDay = ctx.s.day;
    ctx.s.career.careerId = null;
    ctx.s.career.monthlySalary = 0;
    ctx.s.flags.add('retired');
    ctx.journal(
      'Retirement',
      'You chose time, health and the shape of your own mornings.',
      JournalKind.milestone,
      important: true,
    );
    ctx.outcomes.add(
      'Retirement begins with ${formatRupees(ctx.s.life.retirementBalance)} saved',
    );
  }

  static void travel(EngineContext ctx, String cityId) {
    if (cityId == ctx.s.profile.currentCityId) return;
    const fare = 2500;
    if (!ctx.trySpend(fare, 'travel', 'Intercity travel')) {
      throw StateError('You need ${formatRupees(fare)} to travel');
    }
    ctx.s.profile.currentCityId = cityId;
    ctx.s.life.visitedCities.add(cityId);
    ctx.s.flags.add('travelled');
    ctx.outcomes.add('Arrived in $cityId');
  }

  static void settleMonth(EngineContext ctx, MonthLedger ledger) {
    final s = ctx.s;
    final life = s.life;
    var taxableIncome = 0;

    for (final business in life.businesses.where((b) => b.active)) {
      final demand = 1 + (business.reputation / 200);
      final revenue = (business.monthlyRevenue * demand).round();
      final costs = business.monthlyCosts;
      business.cash += revenue - costs;
      business.valuation = math.max(
        10000,
        business.cash + business.monthlyRevenue * 12,
      );
      final draw = math.max(0, (revenue - costs) ~/ 5);
      if (draw > 0) {
        ctx.credit(
          draw,
          'business',
          '${business.name} owner draw',
          record: false,
        );
        ledger.addIncome(draw, '${business.name} owner draw');
        taxableIncome += draw;
      }
      ledger.lines.add(
        '${business.name}: ${formatRupees(revenue)} revenue, ${formatRupees(costs)} costs',
      );
      business.reputation =
          (business.reputation + (business.cash < 0 ? -1 : 0.4))
              .clamp(0, 100)
              .toDouble();
    }

    for (final property in life.properties) {
      if (property.occupied && property.monthlyRent > 0) {
        ctx.credit(
          property.monthlyRent,
          'rent',
          '${property.name} rent',
          record: false,
        );
        ledger.addIncome(property.monthlyRent, '${property.name} rent');
        taxableIncome += property.monthlyRent;
      }
      if (property.monthlyMaintenance > 0) {
        ctx.payMandatory(
          property.monthlyMaintenance,
          'property',
          '${property.name} maintenance',
          record: false,
        );
        ledger.addExpense(
          property.monthlyMaintenance,
          '${property.name} maintenance',
        );
      }
    }

    for (final policy in life.insurance.where((p) => p.active)) {
      ctx.payMandatory(
        policy.monthlyPremium,
        'insurance',
        '${policy.kind} insurance',
        record: false,
      );
      ledger.addExpense(policy.monthlyPremium, '${policy.kind} insurance');
    }

    if (life.retirementBalance > 0) {
      final growth = (life.retirementBalance * 0.004).round();
      life.retirementBalance += growth;
      if (growth > 0) ledger.addIncome(growth, 'Retirement growth');
    }

    final salary = s.career.hasCareer ? s.career.monthlySalary : 0;
    taxableIncome += salary;
    if (taxableIncome > 0) life.taxesDue += (taxableIncome * 0.08).round();
  }

  static void checkAge(EngineContext ctx) {
    final life = ctx.s.life;
    if (life.deceased) return;
    final age = GameCalendar.ageOn(ctx.s.profile.birthDate, ctx.s.day);
    if (age < 100) return;
    life.deceased = true;
    life.deathDay = ctx.s.day;
    life.deathReason = 'A full century of choices';
    ctx.s.flags.add('life_complete');
    life.legacy.add(createLegacy(ctx));
    ctx.journal(
      'The end of a life',
      'You reached 100 with a life shaped by thousands of small decisions.',
      JournalKind.milestone,
      important: true,
    );
  }

  static LegacyRecord createLegacy(EngineContext ctx) => LegacyRecord(
    name: ctx.s.profile.name,
    day: ctx.s.day,
    chapter: ctx.s.chapter,
    netWorth:
        ctx.s.finance.netWorth +
        ctx.s.life.propertyEquity +
        ctx.s.life.totalBusinessValue +
        ctx.s.life.retirementBalance,
    ending:
        ctx.s.life.deathReason ??
        (ctx.s.life.retired ? 'Retired life' : 'Life in progress'),
  );

  static LegacyRecord legacyFromState(GameState s) => LegacyRecord(
    name: s.profile.name,
    day: s.day,
    chapter: s.chapter,
    netWorth:
        s.finance.netWorth +
        s.life.propertyEquity +
        s.life.totalBusinessValue +
        s.life.retirementBalance,
    ending:
        s.life.deathReason ??
        (s.life.retired ? 'Retired life' : 'Life in progress'),
  );
}
