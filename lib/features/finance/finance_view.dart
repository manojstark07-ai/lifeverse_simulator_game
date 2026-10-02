import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/core/game_calendar.dart';
import '../../engine/core/money.dart';
import '../../engine/finance/finance_models.dart';
import '../../engine/finance/loan_math.dart';
import '../../engine/game_state.dart';
import '../../engine/lifestyle/lifestyle_service.dart';
import '../../engine/time/life_simulation.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

/// Validated categorical slots 1–2 (light / dark steps of the same hues).
const _cashLight = Color(0xFF2A78D6), _cashDark = Color(0xFF3987E5);
const _debtLight = Color(0xFFEB6834), _debtDark = Color(0xFFD95926);

String creditBand(int score) => score < 550
    ? 'Poor'
    : score < 650
    ? 'Fair'
    : score < 750
    ? 'Good'
    : 'Excellent';

class FinanceView extends StatelessWidget {
  const FinanceView({super.key, this.showHeading = true});

  /// Off when the view is hosted under an app bar that already names it.
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameSession>(
      builder: (context, session) {
        final s = session.game;
        if (s == null) return const SizedBox.shrink();
        final f = s.finance;
        final t = Theme.of(context).textTheme;
        return ListView(
          children: [
            ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeading) ...[
                    Text(
                      'Money',
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Summary(state: s),
                  const SizedBox(height: 16),
                  _Outlook(state: s),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Investing desk',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track fictional companies, place orders, and see your decisions move with the monthly market turn.',
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: () => context.push('/investments'),
                          icon: const Icon(Icons.auto_graph_rounded),
                          label: const Text('Open market'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HistoryChart(history: f.history),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Loans',
                    child: f.loans.isEmpty
                        ? const EmptyNote(
                            'No loans. Borrowing appears through life events — education, emergencies, purchases.',
                          )
                        : Column(
                            children: [
                              for (final l in f.loans.reversed)
                                _LoanTile(loan: l, cash: f.cash),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Recent transactions',
                    child: f.transactions.isEmpty
                        ? const EmptyNote('Nothing yet.')
                        : Column(
                            children: [
                              for (final tx in f.transactions.reversed.take(25))
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(tx.label),
                                  subtitle: Text(
                                    '${GameCalendar.formatDay(tx.day)} · ${tx.category}',
                                  ),
                                  trailing: Text(
                                    formatRupees(tx.amount, signed: true),
                                    style: t.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All money, banks and returns in LIFEVERSE are fictional simulations — not financial advice.',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final f = state.finance;
    final t = Theme.of(context).textTheme;
    final assets = LifestyleService.assetValue(
      state,
      context.read<GameCubit>().content,
    );
    Widget tile(String label, String value, {String? sub}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (sub != null) Text(sub, style: t.bodySmall),
        ],
      ),
    );
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              tile(
                'Cash',
                formatRupees(f.cash),
                sub: f.hasBankAccount ? f.bankName : 'No bank account yet',
              ),
              tile(
                'Debt',
                formatRupees(f.totalDebt),
                sub: f.arrears > 0
                    ? 'incl. ${formatRupees(f.arrears)} overdue'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile(
                'Net worth',
                formatRupees(f.netWorth + assets),
                sub: assets > 0
                    ? 'incl. ${formatRupees(assets)} in possessions'
                    : null,
              ),
              tile(
                'Credit score',
                '${f.creditScore}',
                sub: creditBand(f.creditScore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Expected recurring money for a typical month, derived from current state.
class _Outlook extends StatelessWidget {
  const _Outlook({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GameCubit>().content;
    final s = state;
    final city = c.hometowns[s.profile.currentCityId];
    final income = <(String, int)>[
      if (s.finance.familySupportMonthly > 0)
        ('Family support', s.finance.familySupportMonthly),
      if (s.career.partTimeJobId != null)
        (
          c.partTimeJobs[s.career.partTimeJobId]!.name,
          (c.partTimeJobs[s.career.partTimeJobId]!.monthlyPay *
                  (city?.wageMultiplier ?? 1))
              .round(),
        ),
      if (s.career.hasCareer) ('Salary', s.career.monthlySalary),
    ];
    final costs = <(String, int)>[
      ('Living expenses', LifeSimulation.livingCost(s, c)),
      for (final l in s.finance.loans.where((l) => !l.closed && l.emi > 0))
        ('Repayment: ${l.name}', l.emi),
      if (s.flags.contains('remit_home') && s.career.hasCareer)
        ('Sent home', (s.career.monthlySalary * 0.1).round()),
    ];
    final net =
        income.fold<int>(0, (a, x) => a + x.$2) -
        costs.fold<int>(0, (a, x) => a + x.$2);
    final t = Theme.of(context).textTheme;
    Widget row((String, int) x, {bool negative = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(x.$1)),
          Text(formatRupees(negative ? -x.$2 : x.$2, signed: !negative)),
        ],
      ),
    );
    return SectionCard(
      title: 'A typical month',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final x in income) row(x),
          for (final x in costs) row(x, negative: true),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Net',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatRupees(net, signed: true),
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (s.education.isEnrolled)
            Text('Plus semester fees every six months.', style: t.bodySmall),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.history});

  final List<MonthlySnapshot> history;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cashColor = dark ? _cashDark : _cashLight;
    final debtColor = dark ? _debtDark : _debtLight;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (history.length < 2) {
      return const SectionCard(
        title: 'Cash and debt over time',
        child: EmptyNote('The chart fills in as months pass.'),
      );
    }
    final points = history.length > 60
        ? history.sublist(history.length - 60)
        : history;
    // Round the axis up to a tidy step so tick labels never collide.
    final rawMax = points
        .map((h) => math.max(h.cash, h.debt))
        .fold<int>(1, math.max)
        .toDouble();
    final step = _niceStep(rawMax / 4);
    final maxY = (rawMax / step).ceil() * step;
    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: false),
    );
    String axis(double v) => v >= 100000
        ? '₹${(v / 100000).toStringAsFixed(v >= 1000000 ? 0 : 1)}L'
        : '₹${(v / 1000).round()}k';
    return SectionCard(
      title: 'Cash and debt over time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Legend(color: cashColor, label: 'Cash'),
              const SizedBox(width: 16),
              _Legend(color: debtColor, label: 'Debt'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Semantics(
              label:
                  'Line chart of cash and debt by month. A table follows below.',
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: step,
                        getTitlesWidget: (v, meta) =>
                            Text(axis(v), style: t.labelSmall),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: math.max(
                          1,
                          (points.length / 4).floorToDouble(),
                        ),
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= points.length)
                            return const SizedBox.shrink();
                          return Text(
                            GameCalendar.formatMonthKey(points[i].monthKey),
                            style: t.labelSmall,
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItems: (spots) => [
                        for (final sp in spots)
                          LineTooltipItem(
                            '${sp.barIndex == 0 ? 'Cash' : 'Debt'} ${formatRupees(sp.y.round())}'
                            '${sp.barIndex == 0 ? '\n${GameCalendar.formatMonthKey(points[sp.x.round()].monthKey)}' : ''}',
                            TextStyle(color: scheme.onInverseSurface),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    line([
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].cash.toDouble()),
                    ], cashColor),
                    line([
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].debt.toDouble()),
                    ], debtColor),
                  ],
                ),
              ),
            ),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Monthly table'),
            children: [
              for (final h in points.reversed.take(24))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(GameCalendar.formatMonthKey(h.monthKey)),
                      ),
                      Expanded(
                        child: Text(
                          'In ${formatRupees(h.income)}',
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Out ${formatRupees(h.expenses)}',
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatRupees(h.cash),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

double _niceStep(double raw) {
  if (raw <= 0) return 1000;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (raw <= m * magnitude) return m * magnitude;
  }
  return 10 * magnitude;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.loan, required this.cash});

  final Loan loan;
  final int cash;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = loan;
    final status = l.closed
        ? 'Closed — fully repaid'
        : l.emi == 0
        ? 'No payments until ${GameCalendar.formatMonthKey(l.repaymentStartMonthKey)} · interest accrued ${formatRupees(l.accruedInterest)}'
        : 'EMI ${formatRupees(l.emi)}/month · ${l.paymentsMade} paid${l.missedPayments > 0 ? ' · ${l.missedPayments} missed' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.name,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(formatRupees(l.totalOwed), style: t.titleSmall),
            ],
          ),
          Text('${l.lender} · ${l.annualRatePct}% a year', style: t.bodySmall),
          Text(status, style: t.bodySmall),
          if (!l.closed)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _schedule(context),
                  child: const Text('Repayment schedule'),
                ),
                TextButton(
                  onPressed: cash > 0 ? () => _prepay(context) : null,
                  child: const Text('Prepay'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _schedule(BuildContext context) {
    final emi = loan.emi > 0
        ? loan.emi
        : LoanMath.emi(loan.totalOwed, loan.annualRatePct, loan.termMonths);
    final rows = LoanMath.schedule(
      loan.totalOwed,
      loan.annualRatePct,
      loan.termMonths,
      fixedEmi: emi,
    );
    final totalInterest = rows.fold(0, (a, r) => a + r.interest);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(loan.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From today: ${rows.length} payments of about ${formatRupees(emi)}. '
                'Total interest ≈ ${formatRupees(totalInterest)}.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in rows.take(36))
                      Text(
                        '#${r.month}: pay ${formatRupees(r.payment)} = interest ${formatRupees(r.interest)} + principal ${formatRupees(r.principal)} → ${formatRupees(r.balance)}',
                        style: Theme.of(c).textTheme.bodySmall,
                      ),
                    if (rows.length > 36) const Text('…'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _prepay(BuildContext context) async {
    final max = math.min(cash, loan.totalOwed);
    var amount = (max / 2).roundToDouble();
    final cubit = context.read<GameCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Prepay loan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pay ${formatRupees(amount.round())} now. Your EMI stays the same, so the loan ends sooner and costs less interest.',
              ),
              Slider(
                value: amount,
                min: 0,
                max: max.toDouble(),
                divisions: math.max(1, max ~/ 500),
                label: formatRupees(amount.round()),
                onChanged: (v) => set(() => amount = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: amount >= 1 ? () => Navigator.pop(c, true) : null,
              child: const Text('Prepay'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) cubit.prepayLoan(loan.id, amount.round());
  }
}
