import 'dart:math' as math;

import '../core/money.dart';
import '../engine_context.dart';
import '../journal/journal.dart';
import 'finance_models.dart';
import 'finance_service.dart';
import 'investment_models.dart';

class InvestmentService {
  const InvestmentService._();

  static int portfolioValue(FinanceState finance) => finance.holdings.fold(
    0,
    (total, holding) =>
        total +
        ((finance.quotes[holding.stockId]?.price ?? 0) * holding.shares)
            .round(),
  );

  static int costBasis(FinanceState finance) => finance.holdings.fold(
    0,
    (total, holding) => total + (holding.averageCost * holding.shares).round(),
  );

  static double returnPct(FinanceState finance) {
    final basis = costBasis(finance);
    if (basis == 0) return 0;
    return (portfolioValue(finance) - basis) / basis * 100;
  }

  static void buy(EngineContext ctx, String stockId, int shares) {
    if (shares <= 0) throw StateError('Choose at least one share');
    final quote = _quote(ctx.s.finance, stockId);
    final amount = (quote.price * shares).round();
    if (!ctx.trySpend(
      amount,
      'investing',
      'Bought $shares ${stockDefinition(stockId).symbol} shares',
    )) {
      throw StateError(
        'You need ${formatRupees(amount - ctx.s.finance.cash)} more cash',
      );
    }
    final existing = ctx.s.finance.holdings
        .where((x) => x.stockId == stockId)
        .firstOrNull;
    if (existing == null) {
      ctx.s.finance.holdings.add(
        StockHolding(
          stockId: stockId,
          shares: shares,
          averageCost: quote.price,
        ),
      );
    } else {
      final totalShares = existing.shares + shares;
      existing.averageCost =
          (existing.averageCost * existing.shares + quote.price * shares) /
          totalShares;
      existing.shares = totalShares;
    }
    ctx.s.flags.add('investor');
    ctx.outcomes.add(
      'Bought $shares ${stockDefinition(stockId).symbol} at ${formatRupees(amount)}',
    );
  }

  static void sell(EngineContext ctx, String stockId, int shares) {
    if (shares <= 0) throw StateError('Choose at least one share');
    final holding = ctx.s.finance.holdings
        .where((x) => x.stockId == stockId)
        .firstOrNull;
    if (holding == null || holding.shares < shares)
      throw StateError('You do not own that many shares');
    final quote = _quote(ctx.s.finance, stockId);
    final amount = (quote.price * shares).round();
    holding.shares -= shares;
    if (holding.shares == 0) ctx.s.finance.holdings.remove(holding);
    ctx.credit(
      amount,
      'investing',
      'Sold $shares ${stockDefinition(stockId).symbol} shares',
    );
    ctx.outcomes.add(
      'Sold $shares ${stockDefinition(stockId).symbol} for ${formatRupees(amount)}',
    );
  }

  /// One turn of the fictional market. Quotes are stored so every save has a
  /// stable history and the player can learn from the chart rather than chase
  /// a hidden reroll.
  static void settleMonth(EngineContext ctx, MonthLedger ledger) {
    final f = ctx.s.finance;
    for (final stock in fictionalStocks) {
      final quote = f.quotes.putIfAbsent(
        stock.id,
        () => StockQuote(stockId: stock.id, price: stock.initialPrice),
      );
      quote.previousPrice = quote.price;
      final move = ctx.rng.noise(stock.volatility);
      quote.price = math.max(1, quote.price * (1 + move));
      quote.history = [...quote.history, quote.price];
      if (quote.history.length > 36) quote.history.removeAt(0);
      final holding = f.holdings
          .where((x) => x.stockId == stock.id)
          .firstOrNull;
      if (holding != null && stock.dividendYield > 0) {
        final dividend =
            (quote.price * holding.shares * stock.dividendYield / 12).round();
        if (dividend > 0) {
          ctx.credit(
            dividend,
            'dividend',
            '${stock.symbol} dividend',
            record: false,
          );
          ledger.addIncome(dividend, '${stock.symbol} dividend');
        }
      }
    }
    if (f.holdings.isNotEmpty) {
      ctx.journal(
        'Market update',
        'Your fictional portfolio is now worth ${formatRupees(portfolioValue(f))}.',
        JournalKind.money,
      );
    }
  }

  static StockQuote _quote(FinanceState finance, String stockId) =>
      finance.quotes[stockId] ?? (throw StateError('Market quote unavailable'));
}
