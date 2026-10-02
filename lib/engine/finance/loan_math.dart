import 'dart:math' as math;

class AmortizationRow {
  const AmortizationRow({
    required this.month,
    required this.payment,
    required this.interest,
    required this.principal,
    required this.balance,
  });

  final int month;
  final int payment;
  final int interest;
  final int principal;
  final int balance;
}

/// Pure loan arithmetic. All amounts are whole rupees.
class LoanMath {
  const LoanMath._();

  /// Standard reducing-balance EMI: P·r·(1+r)^n / ((1+r)^n − 1), rounded up.
  static int emi(int principal, double annualRatePct, int months) {
    if (principal <= 0) return 0;
    if (months <= 0) return principal;
    final r = annualRatePct / 1200;
    if (r == 0) return (principal / months).ceil();
    final f = math.pow(1 + r, months).toDouble();
    return (principal * r * f / (f - 1)).ceil();
  }

  static int monthlyInterest(int balance, double annualRatePct) =>
      (balance * annualRatePct / 1200).round();

  static List<AmortizationRow> schedule(
      int principal, double annualRatePct, int months,
      {int? fixedEmi}) {
    final payment = fixedEmi ?? emi(principal, annualRatePct, months);
    final rows = <AmortizationRow>[];
    var balance = principal;
    var m = 0;
    while (balance > 0 && m < 1000) {
      m++;
      final interest = monthlyInterest(balance, annualRatePct);
      final due = math.min(payment, balance + interest);
      final principalPart = due - interest;
      if (principalPart <= 0) break; // payment can't cover interest
      balance -= principalPart;
      rows.add(AmortizationRow(
        month: m,
        payment: due,
        interest: interest,
        principal: principalPart,
        balance: balance,
      ));
    }
    return rows;
  }
}
