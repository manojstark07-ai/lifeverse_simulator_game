import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/core/money.dart';
import '../../engine/game_state.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../game/selectors.dart';

class LifeManagementScreen extends StatelessWidget {
  const LifeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Long-term life')),
      body: BlocBuilder<GameCubit, GameSession>(
        builder: (context, session) {
          final state = session.game;
          if (state == null) return const SizedBox.shrink();
          final cubit = context.read<GameCubit>();
          return ListView(
            children: [
              ResponsiveBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LifeSummary(state: state),
                    const SizedBox(height: 16),
                    _BusinessSection(state: state, cubit: cubit),
                    const SizedBox(height: 16),
                    _AssetsSection(state: state, cubit: cubit),
                    const SizedBox(height: 16),
                    _LegacySection(state: state),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LifeSummary extends StatelessWidget {
  const _LifeSummary({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final life = state.life;
    final total =
        state.finance.netWorth +
        life.propertyEquity +
        life.totalBusinessValue +
        life.retirementBalance;
    return SectionCard(
      title: 'Your long game',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Cash ${formatRupees(state.finance.cash)}',
              ),
              InfoChip(
                icon: Icons.paid_rounded,
                label: 'Net worth ${formatRupees(total)}',
              ),
              InfoChip(
                icon: Icons.savings_rounded,
                label: 'Retirement ${formatRupees(life.retirementBalance)}',
              ),
              InfoChip(
                icon: Icons.receipt_long_rounded,
                label: 'Tax due ${formatRupees(life.taxesDue)}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            life.deceased
                ? 'This life is complete. Your choices are preserved in the legacy archive.'
                : life.retired
                ? 'Retired · the next chapter is yours to design.'
                : 'Build something durable: a company, a home, a safety net, or a life with more time.',
          ),
        ],
      ),
    );
  }
}

class _BusinessSection extends StatelessWidget {
  const _BusinessSection({required this.state, required this.cubit});

  final GameState state;
  final GameCubit cubit;

  Future<void> _newBusiness(BuildContext context) async {
    final name = TextEditingController();
    final sector = TextEditingController(text: 'Technology');
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a venture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: sector,
              decoration: const InputDecoration(labelText: 'Sector'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Launch budget: ₹50,000. Revenue and costs settle monthly.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Launch'),
          ),
        ],
      ),
    );
    if (submit == true && name.text.trim().isNotEmpty)
      cubit.startBusiness(name.text, sector.text);
    name.dispose();
    sector.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businesses = state.life.businesses.where((x) => x.active).toList();
    return SectionCard(
      title: 'Businesses',
      trailing: IconButton(
        tooltip: 'Start a venture',
        icon: const Icon(Icons.add_business_rounded),
        onPressed: state.life.deceased ? null : () => _newBusiness(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (businesses.isEmpty)
            const EmptyNote(
              'No venture yet. A business is a monthly system, not a single lucky decision.',
            ),
          for (final business in businesses) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_rounded),
              title: Text(business.name),
              subtitle: Text(
                '${business.sector} · ${business.employees} employees · stage ${business.productStage}',
              ),
              trailing: Text(formatRupees(business.valuation)),
            ),
            Text(
              '${formatRupees(business.monthlyRevenue)} revenue · ${formatRupees(business.monthlyCosts)} costs · ${formatRupees(business.cash)} company cash',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Ship project'),
                  onPressed: state.life.deceased
                      ? null
                      : () => cubit.runBusinessProject(
                          business.id,
                          'Customer project',
                          12000,
                        ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: const Text('Hire'),
                  onPressed: state.life.deceased
                      ? null
                      : () => cubit.hireBusiness(business.id),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.trending_up_rounded),
                  label: const Text('Raise funding'),
                  onPressed: state.life.deceased
                      ? null
                      : () => cubit.fundBusiness(business.id),
                ),
              ],
            ),
            if (business != businesses.last) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _AssetsSection extends StatelessWidget {
  const _AssetsSection({required this.state, required this.cubit});

  final GameState state;
  final GameCubit cubit;

  @override
  Widget build(BuildContext context) {
    final life = state.life;
    return SectionCard(
      title: 'Assets & protection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (life.properties.isEmpty)
            const EmptyNote('No property owned yet.'),
          for (final property in life.properties)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.home_work_rounded),
              title: Text(property.name),
              subtitle: Text(
                '${property.kind} · ${property.cityId} · equity ${formatRupees(property.equity)}',
              ),
              trailing: IconButton(
                tooltip: 'Sell property',
                icon: const Icon(Icons.sell_rounded),
                onPressed: state.life.deceased
                    ? null
                    : () => cubit.sellProperty(property.id),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.apartment_rounded),
                label: const Text('Buy apartment ₹8L'),
                onPressed: state.life.deceased
                    ? null
                    : () => cubit.buyProperty(
                        name: 'Harbour apartment',
                        kind: 'home',
                        value: 800000,
                        rent: 18000,
                      ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.health_and_safety_rounded),
                label: const Text('Health cover'),
                onPressed: state.life.deceased
                    ? null
                    : () => cubit.addInsurance('health'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.directions_car_rounded),
                label: const Text('Vehicle cover'),
                onPressed: state.life.deceased
                    ? null
                    : () => cubit.addInsurance('vehicle'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.savings_rounded),
                label: const Text('Invest ₹10K for retirement'),
                onPressed: state.life.deceased
                    ? null
                    : () => cubit.contributeRetirement(10000),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text(
                  life.taxesDue > 0
                      ? 'Pay taxes ${formatRupees(life.taxesDue)}'
                      : 'No tax due',
                ),
                onPressed: life.taxesDue > 0 && !state.life.deceased
                    ? () => cubit.payTaxes()
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Insurance: ${life.insurance.where((p) => p.active).map((p) => p.kind).isEmpty ? 'none' : life.insurance.where((p) => p.active).map((p) => p.kind).join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.beach_access_rounded),
            label: const Text('Retire'),
            onPressed: state.life.deceased || life.retired
                ? null
                : () => cubit.retire(),
          ),
          if (!life.deceased && (life.retired || ageOf(state) >= 70)) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.flag_rounded),
              label: const Text('Close this life and archive its legacy'),
              onPressed: () => cubit.endLife(
                'You chose to close this life and carry its lessons forward.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegacySection extends StatelessWidget {
  const _LegacySection({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    return SectionCard(
      title: 'Legacy archive',
      child: state.life.legacy.isEmpty
          ? const EmptyNote(
              'Completed lives will appear here for New Life+ comparisons.',
            )
          : Column(
              children: [
                for (final record in state.life.legacy.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_stories_rounded),
                    title: Text(record.name),
                    subtitle: Text(
                      '${record.ending} · chapter ${record.chapter}',
                    ),
                    trailing: Text(formatRupees(record.netWorth)),
                  ),
              ],
            ),
      trailing: state.life.deceased
          ? null
          : IconButton(
              tooltip: 'Advance chapter',
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: () => cubit.concludeChapter(),
            ),
    );
  }
}
