import '../core/json_utils.dart';
import 'investment_models.dart';

/// A fictional lending product the story can offer.
class LoanProduct {
  LoanProduct({
    required this.id,
    required this.name,
    required this.lender,
    required this.kind,
    required this.annualRatePct,
    required this.maxAmount,
    required this.termMonths,
    required this.graceMonths,
    required this.description,
  });

  factory LoanProduct.fromJson(Json j) => LoanProduct(
    id: req<String>(j, 'id'),
    name: req<String>(j, 'name'),
    lender: req<String>(j, 'lender'),
    kind: req<String>(j, 'kind'),
    annualRatePct: reqNum(j, 'annualRatePct'),
    maxAmount: req<num>(j, 'maxAmount').toInt(),
    termMonths: req<num>(j, 'termMonths').toInt(),
    graceMonths: req<num>(j, 'graceMonths').toInt(),
    description: req<String>(j, 'description'),
  );

  final String id;
  final String name;
  final String lender;

  /// `education` loans have a moratorium until the course ends + grace.
  final String kind;
  final double annualRatePct;
  final int maxAmount;
  final int termMonths;
  final int graceMonths;
  final String description;
}

class Loan {
  Loan({
    required this.id,
    required this.productId,
    required this.name,
    required this.lender,
    required this.kind,
    required this.annualRatePct,
    required this.termMonths,
    required this.principalDisbursed,
    required this.outstanding,
    required this.repaymentStartMonthKey,
    this.accruedInterest = 0,
    this.emi = 0,
    this.paymentsMade = 0,
    this.missedPayments = 0,
    this.consecutiveMissed = 0,
    this.totalInterestPaid = 0,
    this.closed = false,
  });

  factory Loan.fromJson(Json j) => Loan(
    id: j['id'] as String,
    productId: j['productId'] as String,
    name: j['name'] as String,
    lender: j['lender'] as String,
    kind: j['kind'] as String,
    annualRatePct: (j['annualRatePct'] as num).toDouble(),
    termMonths: j['termMonths'] as int,
    principalDisbursed: j['principalDisbursed'] as int,
    outstanding: j['outstanding'] as int,
    repaymentStartMonthKey: j['repaymentStartMonthKey'] as int,
    accruedInterest: optInt(j, 'accruedInterest', 0),
    emi: optInt(j, 'emi', 0),
    paymentsMade: optInt(j, 'paymentsMade', 0),
    missedPayments: optInt(j, 'missedPayments', 0),
    consecutiveMissed: optInt(j, 'consecutiveMissed', 0),
    totalInterestPaid: optInt(j, 'totalInterestPaid', 0),
    closed: j['closed'] as bool? ?? false,
  );

  final String id;
  final String productId;
  final String name;
  final String lender;
  final String kind;
  final double annualRatePct;
  final int termMonths;
  int principalDisbursed;

  /// Principal still owed (excludes interest accrued during moratorium).
  int outstanding;

  /// Simple interest accrued during the moratorium, capitalised when
  /// repayment begins.
  int accruedInterest;
  int repaymentStartMonthKey;
  int emi;
  int paymentsMade;
  int missedPayments;
  int consecutiveMissed;
  int totalInterestPaid;
  bool closed;

  int get totalOwed => outstanding + accruedInterest;

  Json toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'lender': lender,
    'kind': kind,
    'annualRatePct': annualRatePct,
    'termMonths': termMonths,
    'principalDisbursed': principalDisbursed,
    'outstanding': outstanding,
    'repaymentStartMonthKey': repaymentStartMonthKey,
    'accruedInterest': accruedInterest,
    'emi': emi,
    'paymentsMade': paymentsMade,
    'missedPayments': missedPayments,
    'consecutiveMissed': consecutiveMissed,
    'totalInterestPaid': totalInterestPaid,
    'closed': closed,
  };
}

class Txn {
  Txn({
    required this.day,
    required this.amount,
    required this.category,
    required this.label,
    required this.balanceAfter,
  });

  factory Txn.fromJson(Json j) => Txn(
    day: j['day'] as int,
    amount: j['amount'] as int,
    category: j['category'] as String,
    label: j['label'] as String,
    balanceAfter: j['balanceAfter'] as int,
  );

  final int day;

  /// Signed rupees: positive is money in.
  final int amount;
  final String category;
  final String label;
  final int balanceAfter;

  Json toJson() => {
    'day': day,
    'amount': amount,
    'category': category,
    'label': label,
    'balanceAfter': balanceAfter,
  };
}

class MonthlySnapshot {
  MonthlySnapshot({
    required this.monthKey,
    required this.cash,
    required this.debt,
    required this.income,
    required this.expenses,
  });

  factory MonthlySnapshot.fromJson(Json j) => MonthlySnapshot(
    monthKey: j['monthKey'] as int,
    cash: j['cash'] as int,
    debt: j['debt'] as int,
    income: j['income'] as int,
    expenses: j['expenses'] as int,
  );

  final int monthKey;
  final int cash;
  final int debt;
  final int income;
  final int expenses;

  int get netWorth => cash - debt;

  Json toJson() => {
    'monthKey': monthKey,
    'cash': cash,
    'debt': debt,
    'income': income,
    'expenses': expenses,
  };
}

class FinanceState {
  FinanceState({
    required this.cash,
    this.hasBankAccount = false,
    this.bankName,
    List<Txn>? transactions,
    List<Loan>? loans,
    this.creditScore = 650,
    this.arrears = 0,
    this.monthsInArrears = 0,
    required this.familySupportMonthly,
    List<MonthlySnapshot>? history,
    this.nextLoanSeq = 1,
    Map<String, StockQuote>? quotes,
    List<StockHolding>? holdings,
  }) : transactions = transactions ?? [],
       loans = loans ?? [],
       history = history ?? [],
       quotes =
           quotes ??
           {
             for (final stock in fictionalStocks)
               stock.id: StockQuote(
                 stockId: stock.id,
                 price: stock.initialPrice,
               ),
           },
       holdings = holdings ?? [];

  factory FinanceState.fromJson(Json j) => FinanceState(
    cash: j['cash'] as int,
    hasBankAccount: j['hasBankAccount'] as bool? ?? false,
    bankName: j['bankName'] as String?,
    transactions: jsonList(j['transactions']).map(Txn.fromJson).toList(),
    loans: jsonList(j['loans']).map(Loan.fromJson).toList(),
    creditScore: optInt(j, 'creditScore', 650),
    arrears: optInt(j, 'arrears', 0),
    monthsInArrears: optInt(j, 'monthsInArrears', 0),
    familySupportMonthly: optInt(j, 'familySupportMonthly', 0),
    history: jsonList(j['history']).map(MonthlySnapshot.fromJson).toList(),
    nextLoanSeq: optInt(j, 'nextLoanSeq', 1),
    quotes: j['quotes'] == null
        ? null
        : (j['quotes'] as Map).map(
            (k, v) =>
                MapEntry(k as String, StockQuote.fromJson((v as Map).cast())),
          ),
    holdings: jsonList(j['holdings']).map(StockHolding.fromJson).toList(),
  );

  /// Liquid money in rupees. The engine never lets this go below zero:
  /// unpaid mandatory costs become [arrears] instead.
  int cash;
  bool hasBankAccount;
  String? bankName;
  List<Txn> transactions;
  List<Loan> loans;

  /// Fictional 300..900 credit health score.
  int creditScore;

  /// Mandatory bills that could not be paid.
  int arrears;
  int monthsInArrears;
  int familySupportMonthly;
  List<MonthlySnapshot> history;
  int nextLoanSeq;
  Map<String, StockQuote> quotes;
  List<StockHolding> holdings;

  int get totalDebt =>
      loans.where((l) => !l.closed).fold(0, (s, l) => s + l.totalOwed) +
      arrears;

  int get netWorth => cash - totalDebt;

  static const maxTransactions = 400;

  Json toJson() => {
    'cash': cash,
    'hasBankAccount': hasBankAccount,
    'bankName': bankName,
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'loans': loans.map((l) => l.toJson()).toList(),
    'creditScore': creditScore,
    'arrears': arrears,
    'monthsInArrears': monthsInArrears,
    'familySupportMonthly': familySupportMonthly,
    'history': history.map((h) => h.toJson()).toList(),
    'nextLoanSeq': nextLoanSeq,
    'quotes': quotes.map((k, v) => MapEntry(k, v.toJson())),
    'holdings': holdings.map((x) => x.toJson()).toList(),
  };
}
