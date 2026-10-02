import 'dart:math' as math;

import '../core/game_calendar.dart';
import '../core/money.dart';
import '../engine_context.dart';
import '../game_events.dart';
import '../journal/journal.dart';
import 'finance_models.dart';
import 'loan_math.dart';

/// Collects one month's income and expense lines for the settlement report.
class MonthLedger {
  int income = 0;
  int expenses = 0;
  final List<String> lines = [];

  void addIncome(int amount, String label) {
    if (amount <= 0) return;
    income += amount;
    lines.add('${formatRupees(amount, signed: true)}  $label');
  }

  void addExpense(int amount, String label) {
    if (amount <= 0) return;
    expenses += amount;
    lines.add('${formatRupees(-amount)}  $label');
  }
}

class FinanceService {
  const FinanceService._();

  static const savingsRatePct = 3.0;
  static const minCredit = 300;
  static const maxCredit = 900;

  static void openAccount(EngineContext ctx, String bank) {
    final f = ctx.s.finance;
    if (f.hasBankAccount) return;
    f.hasBankAccount = true;
    f.bankName = bank;
    ctx.outcomes.add('Opened a savings account at $bank');
    ctx.journal('Bank account opened', 'Opened a savings account at $bank.', JournalKind.money);
  }

  /// Disburses a loan into cash. Education loans repay only after the
  /// current course ends plus the product's grace period.
  static Loan takeLoan(EngineContext ctx, LoanProduct p, int requested, {int? courseEndMonthKey}) {
    final f = ctx.s.finance;
    if (!f.hasBankAccount) {
      throw StateError('A bank account is required before taking a loan');
    }
    final amount = math.min(requested, p.maxAmount);
    if (amount <= 0) throw StateError('Loan amount must be positive');
    final nowKey = GameCalendar.monthKeyOfDay(ctx.s.day);
    final baseKey = p.kind == 'education' && courseEndMonthKey != null ? courseEndMonthKey : nowKey + 1;
    final loan = Loan(
      id: '${p.id}_${f.nextLoanSeq++}',
      productId: p.id,
      name: p.name,
      lender: p.lender,
      kind: p.kind,
      annualRatePct: p.annualRatePct,
      termMonths: p.termMonths,
      principalDisbursed: amount,
      outstanding: amount,
      repaymentStartMonthKey: baseKey + p.graceMonths,
    );
    f.loans.add(loan);
    ctx.credit(amount, 'loan', '${p.name} disbursed');
    ctx.journal(
      'Took a loan',
      '${p.name} from ${p.lender}: ${formatRupees(amount)} at ${p.annualRatePct}% a year. '
          'Repayments start ${GameCalendar.formatMonthKey(loan.repaymentStartMonthKey)}.',
      JournalKind.money,
      important: true,
    );
    return loan;
  }

  /// Brings education-loan repayment forward when the student leaves the
  /// course early (the moratorium is tied to studying).
  static void endMoratoriumEarly(EngineContext ctx, int graceMonths) {
    final nowKey = GameCalendar.monthKeyOfDay(ctx.s.day);
    for (final l in ctx.s.finance.loans) {
      if (l.kind == 'education' && !l.closed) {
        l.repaymentStartMonthKey = math.min(l.repaymentStartMonthKey, nowKey + 1 + graceMonths);
      }
    }
  }

  /// Applies one month of interest and repayments to every open loan.
  static void settleLoans(EngineContext ctx, int monthKey, MonthLedger ledger) {
    final f = ctx.s.finance;
    for (final l in f.loans) {
      if (l.closed) continue;
      if (monthKey < l.repaymentStartMonthKey) {
        l.accruedInterest += LoanMath.monthlyInterest(l.outstanding, l.annualRatePct);
        continue;
      }
      if (l.emi == 0) {
        // Moratorium over: capitalise accrued interest and fix the EMI.
        l.outstanding += l.accruedInterest;
        l.accruedInterest = 0;
        l.emi = LoanMath.emi(l.outstanding, l.annualRatePct, l.termMonths);
        ctx.journal('Loan repayments begin',
            '${l.name}: EMI of ${formatRupees(l.emi)} a month for ${l.termMonths} months.', JournalKind.money,
            important: true);
        ctx.emit(Notice('${l.name} repayments have started: ${formatRupees(l.emi)}/month.'));
      }
      final interest = LoanMath.monthlyInterest(l.outstanding, l.annualRatePct);
      final due = math.min(l.emi, l.outstanding + interest);
      if (f.cash >= due) {
        f.cash -= due;
        ctx.s.finance.transactions.add(Txn(
            day: ctx.s.day, amount: -due, category: 'emi', label: '${l.name} EMI', balanceAfter: f.cash));
        l.outstanding -= due - interest;
        l.totalInterestPaid += interest;
        l.paymentsMade++;
        l.consecutiveMissed = 0;
        f.creditScore = math.min(maxCredit, f.creditScore + 4);
        ledger.addExpense(due, '${l.name} EMI');
      } else {
        // Missed payment: interest is capitalised and a fixed penalty added.
        const penalty = 500;
        l.outstanding += interest + penalty;
        l.missedPayments++;
        l.consecutiveMissed++;
        f.creditScore = math.max(minCredit, f.creditScore - 35);
        ctx.s.flags.add('missed_emi');
        if (l.consecutiveMissed >= 3) ctx.s.flags.add('loan_default');
        ctx.emit(Notice('Missed the ${l.name} EMI. A ₹500 penalty was added and your credit score fell.',
            warning: true));
        ctx.journal('Missed a loan payment', '${l.name}: could not pay ${formatRupees(due)}.', JournalKind.money);
        ledger.lines.add('Missed: ${l.name} EMI ${formatRupees(due)}');
      }
      if (l.outstanding <= 0) _close(ctx, l);
    }
  }

  /// Extra repayment. Keeps the EMI, so the loan simply finishes sooner.
  static int prepay(EngineContext ctx, String loanId, int amount) {
    final l = ctx.s.finance.loans.firstWhere((x) => x.id == loanId && !x.closed,
        orElse: () => throw StateError('No open loan $loanId'));
    final pay = math.min(amount, l.totalOwed);
    if (pay <= 0) throw StateError('Nothing to prepay');
    if (!ctx.trySpend(pay, 'loan', 'Prepayment: ${l.name}')) {
      throw StateError('Not enough cash to prepay ${formatRupees(pay)}');
    }
    final fromInterest = math.min(pay, l.accruedInterest);
    l.accruedInterest -= fromInterest;
    l.outstanding -= pay - fromInterest;
    if (l.totalOwed <= 0) _close(ctx, l);
    return pay;
  }

  static void _close(EngineContext ctx, Loan l) {
    l.outstanding = 0;
    l.accruedInterest = 0;
    l.closed = true;
    ctx.s.flags.add('loan_closed');
    ctx.journal('Loan closed', '${l.name} is fully repaid.', JournalKind.money, important: true);
    ctx.emit(Notice('${l.name} fully repaid!'));
    if (ctx.s.finance.loans.every((x) => x.closed)) ctx.s.flags.add('debt_free');
  }

  /// Arrears are repaid first from available cash each month.
  static void settleArrears(EngineContext ctx, MonthLedger ledger) {
    final f = ctx.s.finance;
    if (f.arrears <= 0) return;
    final pay = math.min(f.arrears, f.cash);
    if (pay > 0) {
      f.cash -= pay;
      f.arrears -= pay;
      f.transactions.add(
          Txn(day: ctx.s.day, amount: -pay, category: 'arrears', label: 'Overdue bills', balanceAfter: f.cash));
      ledger.addExpense(pay, 'Cleared overdue bills');
    }
  }

  static void savingsInterest(EngineContext ctx, MonthLedger ledger) {
    final f = ctx.s.finance;
    if (!f.hasBankAccount || f.cash <= 0) return;
    final interest = (f.cash * savingsRatePct / 1200).floor();
    if (interest > 0) {
      ctx.credit(interest, 'interest', 'Savings interest', record: false);
      ledger.addIncome(interest, 'Savings interest');
    }
  }
}
