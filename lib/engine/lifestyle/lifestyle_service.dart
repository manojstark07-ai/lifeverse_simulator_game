import 'dart:math' as math;

import '../character/player_profile.dart';
import '../character/stats.dart';
import '../content/content_bundle.dart';
import '../core/money.dart';
import '../effects/effect_resolver.dart';
import '../engine_context.dart';
import '../finance/finance_models.dart';
import '../finance/finance_service.dart';
import '../finance/loan_math.dart';
import '../game_state.dart';
import '../journal/journal.dart';
import 'lifestyle_models.dart';

/// Buying, financing, owning and selling things.
class LifestyleService {
  const LifestyleService._();

  /// Dealers pay this share of an item's current value.
  static const resaleShare = 0.85;

  /// Lenders cap EMIs at this share of monthly income.
  static const maxEmiShareOfIncome = 0.5;
  static const minCreditForLoans = 600;
  static const makeoverCost = 1500;

  // ------------------------------------------------------------ valuation --

  static int currentValue(OwnedItem o, ShopItem item, int day) {
    if (item.isSubscription) return 0;
    final years = math.max(0, day - o.boughtDay) / 365;
    final factor = math.pow(1 - item.annualDepreciationPct / 100, years).toDouble();
    // Depreciating goods bottom out at scrap value rather than zero.
    final floor = item.annualDepreciationPct > 0 ? 0.1 : 0.0;
    return (o.pricePaid * math.max(floor, factor)).round();
  }

  static int resaleValue(OwnedItem o, ShopItem item, int day) =>
      (currentValue(o, item, day) * resaleShare / 100).round() * 100;

  /// Total current value of everything the player owns.
  static int assetValue(GameState s, ContentBundle c) => s.possessions.fold(0, (sum, o) {
        final item = c.shopItems[o.itemId];
        return item == null ? sum : sum + currentValue(o, item, s.day);
      });

  static double commuteHoursSaved(GameState s, ContentBundle c) =>
      s.possessions.map((o) => c.shopItems[o.itemId]?.commuteHoursSaved ?? 0).fold(0.0, math.max);

  /// Best camera/phone quality available for videos (an old phone is 0.15).
  static double creatorEquipment(GameState s, ContentBundle c) =>
      s.possessions.map((o) => c.shopItems[o.itemId]?.creatorQuality ?? 0).fold(0.15, math.max);

  /// Regular monthly income lenders will count.
  static int monthlyIncome(GameState s, ContentBundle c) {
    var income = s.career.monthlySalary;
    final pt = c.partTimeJobs[s.career.partTimeJobId];
    if (pt != null) income += (pt.monthlyPay * (c.hometowns[s.profile.currentCityId]?.wageMultiplier ?? 1)).round();
    return income + s.counter('creatorLastMonth');
  }

  static int monthlyUpkeep(GameState s, ContentBundle c) =>
      s.possessions.fold(0, (sum, o) => sum + (c.shopItems[o.itemId]?.monthlyUpkeep ?? 0));

  // ------------------------------------------------------------- financing --

  /// The loan a financed purchase needs, after the down payment.
  static int loanAmount(ShopItem item, ContentBundle c) {
    final product = c.loanProducts[item.loanProductId];
    if (product == null) return 0;
    return math.min(product.maxAmount, (item.price * (1 - item.downPaymentPct) / 100).round() * 100);
  }

  static int upfrontCost(ShopItem item, ContentBundle c, {required bool finance}) =>
      finance ? item.price - loanAmount(item, c) : item.price;

  static int financedEmi(ShopItem item, ContentBundle c) {
    final product = c.loanProducts[item.loanProductId];
    if (product == null) return 0;
    return LoanMath.emi(loanAmount(item, c), product.annualRatePct, product.termMonths);
  }

  static OwnedItem? inSlot(GameState s, ContentBundle c, String? slot) =>
      slot == null ? null : s.possessions.where((o) => c.shopItems[o.itemId]?.slot == slot).firstOrNull;

  static Loan? _openLoan(GameState s, String? loanId) =>
      loanId == null ? null : s.finance.loans.where((l) => l.id == loanId && !l.closed).firstOrNull;

  /// Why [item] cannot be bought right now, or null.
  static String? buyBlocker(GameState s, ContentBundle c, ShopItem item, {bool finance = false}) {
    if (s.story.inEvent) return 'Finish the current story event first';
    if (!item.requires.evaluate(s, c)) {
      final d = item.requires.describe(c);
      return d.isEmpty ? 'Not available yet' : 'Requires: $d';
    }
    if (s.owns(item.id)) return item.isSubscription ? 'Already a member' : 'Already owned';
    final traded = inSlot(s, c, item.slot);
    if (traded != null && _openLoan(s, traded.loanId) != null) {
      return 'Pay off the loan on your ${c.shopItems[traded.itemId]!.name} before trading it in';
    }
    final tradeIn = traded == null ? 0 : resaleValue(traded, c.shopItems[traded.itemId]!, s.day);
    if (finance) {
      if (!item.financeable) return 'Financing is not offered';
      if (s.finance.creditScore < minCreditForLoans) return 'Credit score too low for a loan';
      final emi = financedEmi(item, c);
      final income = monthlyIncome(s, c);
      if (emi > income * maxEmiShareOfIncome) {
        return 'EMI ${formatRupees(emi)} is more than half your income (${formatRupees(income)}/month)';
      }
    }
    final upfront = upfrontCost(item, c, finance: finance) - tradeIn;
    if (s.finance.cash < upfront) return 'Needs ${formatRupees(upfront)} in cash';
    return null;
  }

  // --------------------------------------------------------------- buying --

  static void buy(EngineContext ctx, ShopItem item, {bool finance = false}) {
    final s = ctx.s;
    final blocker = buyBlocker(s, ctx.c, item, finance: finance);
    if (blocker != null) throw StateError(blocker);

    final traded = inSlot(s, ctx.c, item.slot);
    if (traded != null) {
      final old = ctx.c.shopItems[traded.itemId]!;
      final value = resaleValue(traded, old, s.day);
      s.possessions.remove(traded);
      ctx.credit(value, 'sale', 'Trade-in: ${old.name}');
      EffectResolver.applyAll(ctx, old.onSell);
    }

    String? loanId;
    if (finance) {
      FinanceService.openAccount(ctx, 'Kaveri Co-operative Bank');
      final loan = FinanceService.takeLoan(ctx, ctx.c.loanProducts[item.loanProductId]!, loanAmount(item, ctx.c));
      loanId = loan.id;
    }
    if (item.price > 0 && !ctx.trySpend(item.price, 'shopping', item.name)) {
      throw StateError('Not enough cash for ${item.name}');
    }
    s.possessions.add(OwnedItem(
      uid: 'item_${s.nextItemSeq++}',
      itemId: item.id,
      boughtDay: s.day,
      pricePaid: item.price,
      loanId: loanId,
    ));
    EffectResolver.applyAll(ctx, item.onBuy);
    s.counters['purchases'] = s.counter('purchases') + 1;
    final verb = item.isSubscription ? 'Joined' : 'Bought';
    ctx.outcomes.add('$verb: ${item.name}');
    ctx.journal('$verb ${item.name}',
        '${item.brand.isEmpty ? '' : '${item.brand} · '}${formatRupees(item.price)}${finance ? ', financed' : ''}.',
        JournalKind.money,
        important: item.price >= 100000);
  }

  /// Sells (or cancels) an owned item. Any loan on it is settled first from
  /// the sale proceeds, topped up from cash if needed.
  static void sell(EngineContext ctx, String uid) {
    final s = ctx.s;
    if (s.story.inEvent) throw StateError('Finish the current story event first');
    final owned = s.possessions.where((o) => o.uid == uid).firstOrNull ?? (throw StateError('You do not own that'));
    final item = ctx.c.shopItems[owned.itemId]!;
    final value = resaleValue(owned, item, s.day);
    final loan = _openLoan(s, owned.loanId);
    if (loan != null && s.finance.cash + value < loan.totalOwed) {
      throw StateError('Selling would not cover the ${formatRupees(loan.totalOwed)} still owed on it');
    }
    s.possessions.remove(owned);
    ctx.credit(value, 'sale', 'Sold ${item.name}');
    if (loan != null) FinanceService.prepay(ctx, loan.id, loan.totalOwed);
    EffectResolver.applyAll(ctx, item.onSell);
    ctx.outcomes.add(item.isSubscription ? 'Cancelled ${item.name}' : 'Sold ${item.name}');
    ctx.journal(item.isSubscription ? 'Cancelled ${item.name}' : 'Sold ${item.name}',
        item.isSubscription ? 'Membership ended.' : 'Sold for ${formatRupees(value)}.', JournalKind.money);
  }

  /// A gift or story reward: owned outright, no money changes hands.
  static void give(EngineContext ctx, ShopItem item) {
    final s = ctx.s;
    if (s.owns(item.id)) return;
    final traded = inSlot(s, ctx.c, item.slot);
    if (traded != null) s.possessions.remove(traded);
    s.possessions.add(OwnedItem(uid: 'item_${s.nextItemSeq++}', itemId: item.id, boughtDay: s.day, pricePaid: item.price));
    EffectResolver.applyAll(ctx, item.onBuy);
    ctx.outcomes.add('New: ${item.name}');
  }

  /// Theft, accidents, a flood. Any loan on the item is still owed.
  static void lose(EngineContext ctx, {String? itemId, String? category}) {
    final s = ctx.s;
    final lost = s.possessions.where((o) {
      final item = ctx.c.shopItems[o.itemId];
      return item != null && (o.itemId == itemId || (category != null && item.category == category));
    }).toList();
    for (final o in lost) {
      final item = ctx.c.shopItems[o.itemId]!;
      s.possessions.remove(o);
      EffectResolver.applyAll(ctx, item.onSell);
      ctx.outcomes.add('Lost: ${item.name}');
      if (_openLoan(s, o.loanId) != null) ctx.outcomes.add('The loan on it is still due');
    }
  }

  /// A new look at the salon. Changes the avatar and costs [makeoverCost].
  static void makeover(EngineContext ctx, Appearance look) {
    final s = ctx.s;
    if (s.story.inEvent) throw StateError('Finish the current story event first');
    if (s.actionsToday >= GameState.maxActionsPerDay) throw StateError('No time left today');
    final old = s.profile.appearance;
    if (look.skinTone != old.skinTone) throw StateError('A salon cannot change your skin tone');
    if (look.toJson().toString() == old.toJson().toString()) throw StateError('Pick something different');
    if (!ctx.trySpend(makeoverCost, 'grooming', 'Salon makeover')) throw StateError('Not enough money');
    s.profile.appearance = look;
    s.actionsToday++;
    ctx.addStat(StatKeys.looks, 6);
    ctx.addStat(StatKeys.wellbeing, 2);
    ctx.addSkill(SkillKeys.styling, 0.3, record: false);
    ctx.journal('New look', 'A fresh style from the salon.', JournalKind.story, important: false);
  }

  // ---------------------------------------------------------- settlement --

  static void settleMonth(EngineContext ctx, MonthLedger ledger) {
    final s = ctx.s;
    for (final o in List.of(s.possessions)) {
      final item = ctx.c.shopItems[o.itemId];
      if (item == null) continue;
      if (item.monthlyUpkeep > 0) {
        ctx.payMandatory(item.monthlyUpkeep, 'upkeep', '${item.upkeepLabel}: ${item.name}', record: false);
        ledger.addExpense(item.monthlyUpkeep, '${item.upkeepLabel}: ${item.name}');
      }
      if (item.monthlyEffects.isNotEmpty) {
        final saved = List.of(ctx.outcomes);
        EffectResolver.applyAll(ctx, item.monthlyEffects);
        ctx.outcomes
          ..clear()
          ..addAll(saved);
      }
    }
  }
}
