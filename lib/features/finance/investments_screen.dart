import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/core/money.dart';
import '../../engine/finance/investment_models.dart';
import '../../engine/finance/investment_service.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fictional market')),
    body: SafeArea(
      child: BlocBuilder<GameCubit, GameSession>(
        builder: (context, session) {
          final state = session.game;
          if (state == null) return const SizedBox.shrink();
          final f = state.finance;
          final value = InvestmentService.portfolioValue(f);
          final basis = InvestmentService.costBasis(f);
          final t = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            children: [
              ResponsiveBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EmptyNote(
                      'These companies and prices are fictional. Learn the risk and reward loop inside the game; this is not financial advice.',
                      icon: Icons.auto_graph_rounded,
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _Metric('Portfolio', formatRupees(value)),
                          ),
                          Expanded(
                            child: _Metric(
                              'Return',
                              '${InvestmentService.returnPct(f).toStringAsFixed(1)}%',
                              color: value >= basis
                                  ? scheme.primary
                                  : scheme.error,
                            ),
                          ),
                          Expanded(
                            child: _Metric('Cash', formatRupees(f.cash)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Your holdings',
                      child: f.holdings.isEmpty
                          ? const EmptyNote(
                              'No shares yet. Start small and watch the monthly turns.',
                            )
                          : Column(
                              children: [
                                for (final x in f.holdings)
                                  _HoldingRow(holding: x),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Market board',
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final stock in fictionalStocks) ...[
                      _StockTile(stock: stock),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding});
  final StockHolding holding;

  @override
  Widget build(BuildContext context) {
    final f = context.read<GameCubit>().game.finance;
    final quote = f.quotes[holding.stockId]!;
    final stock = stockDefinition(holding.stockId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(stock.symbol.substring(0, 1))),
      title: Text('${stock.symbol} · ${holding.shares} shares'),
      subtitle: Text(
        'Average ${formatRupees(holding.averageCost.round())} · Now ${formatRupees(quote.price.round())}',
      ),
      trailing: Text(
        formatRupees((quote.price * holding.shares).round()),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _StockTile extends StatefulWidget {
  const _StockTile({required this.stock});
  final StockDefinition stock;

  @override
  State<_StockTile> createState() => _StockTileState();
}

class _StockTileState extends State<_StockTile> {
  late final TextEditingController _quantity = TextEditingController(text: '1');

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final quote = cubit.game.finance.quotes[widget.stock.id]!;
    final scheme = Theme.of(context).colorScheme;
    final points = quote.history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = quote.history.reduce((a, b) => a < b ? a : b) * 0.94;
    final maxY = quote.history.reduce((a, b) => a > b ? a : b) * 1.06;
    final input = int.tryParse(_quantity.text) ?? 0;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.stock.symbol} · ${widget.stock.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatRupees(quote.price.round()),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Text(
            '${widget.stock.sector} · ${widget.stock.description}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                quote.changePct >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 18,
                color: quote.changePct >= 0 ? scheme.primary : scheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                '${quote.changePct >= 0 ? '+' : ''}${quote.changePct.toStringAsFixed(1)}% last turn',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Shares',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    isCurved: true,
                    color: scheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: scheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: input > 0
                    ? () => cubit.buyStock(widget.stock.id, input)
                    : null,
                icon: const Icon(Icons.add_chart_rounded),
                label: const Text('Buy'),
              ),
              OutlinedButton.icon(
                onPressed: input > 0
                    ? () => cubit.sellStock(widget.stock.id, input)
                    : null,
                icon: const Icon(Icons.sell_rounded),
                label: const Text('Sell'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
