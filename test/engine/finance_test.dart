import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/core/game_calendar.dart';
import 'package:lifeverse/engine/core/money.dart';
import 'package:lifeverse/engine/engine_context.dart';
import 'package:lifeverse/engine/finance/finance_service.dart';
import 'package:lifeverse/engine/finance/loan_math.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/time/life_simulation.dart';

import '../support/content.dart';

void main() {
  final content = loadContent();
  final engine = GameEngine(content);

  group('LoanMath', () {
    test('EMI matches the reducing-balance formula', () {
      // ₹1,00,000 at 9.5% for 84 months ≈ ₹1,634.4 → rounded up.
      expect(LoanMath.emi(100000, 9.5, 84), 1635);
      expect(LoanMath.emi(120000, 0, 12), 10000);
      expect(LoanMath.emi(0, 10, 12), 0);
    });

    test('amortization schedule repays exactly the principal', () {
      final rows = LoanMath.schedule(250000, 10.5, 60);
      expect(rows.length, inInclusiveRange(59, 61));
      expect(rows.fold<int>(0, (a, r) => a + r.principal), 250000);
      expect(rows.last.balance, 0);
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].interest, lessThanOrEqualTo(rows[i - 1].interest));
      }
    });
  });

  test('rupee formatting uses Indian digit grouping', () {
    expect(formatRupees(1234567), '₹12,34,567');
    expect(formatRupees(999), '₹999');
    expect(formatRupees(-45000), '−₹45,000');
    expect(formatRupees(500, signed: true), '+₹500');
  });

  group('loans in the simulation', () {
    test('education loan accrues during moratorium, then capitalises into an EMI', () {
      final s = newGame(engine).clone();
      final ctx = EngineContext(s, content);
      FinanceService.openAccount(ctx, 'Test Bank');
      final nowKey = GameCalendar.monthKeyOfDay(s.day);
      final loan = FinanceService.takeLoan(ctx, content.loanProducts['kaveri_education']!, 100000,
          courseEndMonthKey: nowKey + 2);
      expect(loan.repaymentStartMonthKey, nowKey + 2 + 6);
      expect(s.finance.cash, greaterThanOrEqualTo(100000));

      for (var m = nowKey; m < loan.repaymentStartMonthKey; m++) {
        LifeSimulation.settleMonth(ctx, m);
      }
      expect(loan.emi, 0);
      expect(loan.accruedInterest, greaterThan(0));
      final owedBefore = loan.totalOwed;

      LifeSimulation.settleMonth(ctx, loan.repaymentStartMonthKey);
      expect(loan.accruedInterest, 0);
      expect(loan.emi, LoanMath.emi(owedBefore, 9.5, 84));
      expect(loan.paymentsMade, 1);
      expect(loan.outstanding, lessThan(owedBefore));
    });

    test('a missed EMI adds a penalty and lowers the credit score; cash never goes negative', () {
      final s = newGame(engine).clone();
      final ctx = EngineContext(s, content);
      FinanceService.openAccount(ctx, 'Test Bank');
      final loan = FinanceService.takeLoan(ctx, content.loanProducts['kaveri_personal']!, 50000);
      s.finance.cash = 0;
      s.finance.familySupportMonthly = 0;
      final credit = s.finance.creditScore;
      final owed = loan.outstanding;
      LifeSimulation.settleMonth(ctx, loan.repaymentStartMonthKey);
      expect(loan.missedPayments, 1);
      expect(loan.outstanding, greaterThan(owed));
      expect(s.finance.creditScore, lessThan(credit));
      expect(s.finance.cash, 0);
      expect(s.finance.arrears, greaterThan(0)); // living costs unpaid
      expect(s.flags, contains('missed_emi'));
    });

    test('three consecutive missed EMIs mark a default', () {
      final s = newGame(engine).clone();
      final ctx = EngineContext(s, content);
      FinanceService.openAccount(ctx, 'Test Bank');
      final loan = FinanceService.takeLoan(ctx, content.loanProducts['kaveri_personal']!, 20000);
      s.finance.familySupportMonthly = 0;
      for (var i = 0; i < 3; i++) {
        s.finance.cash = 0;
        LifeSimulation.settleMonth(ctx, loan.repaymentStartMonthKey + i);
      }
      expect(s.flags, contains('loan_default'));
    });

    test('prepayment closes a loan and sets debt_free', () {
      final s = newGame(engine, background: 'affluent_business');
      final withLoan = engine.choose(s, 'c_read').state; // still in the opening event
      expect(withLoan.story.inEvent, isTrue);
      final ctx = EngineContext(s.clone(), content);
      FinanceService.openAccount(ctx, 'Test Bank');
      final loan = FinanceService.takeLoan(ctx, content.loanProducts['kaveri_personal']!, 10000);
      final paid = FinanceService.prepay(ctx, loan.id, 999999);
      expect(paid, 10000);
      expect(loan.closed, isTrue);
      expect(ctx.s.flags, contains('debt_free'));
    });

    test('loans require a bank account', () {
      final s = newGame(engine).clone();
      final ctx = EngineContext(s, content);
      expect(() => FinanceService.takeLoan(ctx, content.loanProducts['kaveri_personal']!, 1000), throwsStateError);
    });
  });

  test('monthly settlement is idempotent (no double pay-outs)', () {
    final s = newGame(engine).clone();
    final ctx = EngineContext(s, content);
    final key = GameCalendar.monthKeyOfDay(s.day);
    LifeSimulation.settleMonth(ctx, key);
    final cash = s.finance.cash;
    final history = s.finance.history.length;
    LifeSimulation.settleMonth(ctx, key);
    expect(s.finance.cash, cash);
    expect(s.finance.history.length, history);
  });
}
