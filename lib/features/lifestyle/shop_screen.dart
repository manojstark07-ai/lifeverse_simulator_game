import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/content/content_bundle.dart';
import '../../engine/core/money.dart';
import '../../engine/game_state.dart';
import '../../engine/lifestyle/lifestyle_models.dart';
import '../../engine/lifestyle/lifestyle_service.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

const _categoryIcons = {
  ShopCategory.phone: Icons.smartphone_rounded,
  ShopCategory.gadget: Icons.devices_other_rounded,
  ShopCategory.vehicle: Icons.directions_car_rounded,
  ShopCategory.fashion: Icons.checkroom_rounded,
  ShopCategory.property: Icons.apartment_rounded,
  ShopCategory.subscription: Icons.card_membership_rounded,
};

/// Phones, cars, flats and memberships: buy, finance, own and sell.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, this.initialCategory});

  /// A [ShopCategory] to open first.
  final String? initialCategory;

  @override
  Widget build(BuildContext context) {
    final initial = ShopCategory.all.indexOf(initialCategory ?? '');
    return DefaultTabController(
      length: ShopCategory.all.length + 1,
      initialIndex: initial < 0 ? 0 : initial + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shop & lifestyle'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Yours'),
              for (final c in ShopCategory.all) Tab(icon: Icon(_categoryIcons[c]), text: ShopCategory.labels[c]),
            ],
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<GameCubit, GameSession>(builder: (context, session) {
            final s = session.game;
            if (s == null) return const SizedBox.shrink();
            final c = context.read<GameCubit>().content;
            return TabBarView(children: [
              _Owned(state: s, content: c),
              for (final cat in ShopCategory.all)
                ListView(children: [
                  ResponsiveBody(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _CashBar(state: s),
                      const SizedBox(height: 12),
                      for (final item in c.shopItems.values.where((i) => i.category == cat).toList()
                        ..sort((a, b) => a.price.compareTo(b.price))) ...[
                        _ItemCard(item: item, state: s, content: c),
                        const SizedBox(height: 12),
                      ],
                      Text('All brands, products and prices are fictional.',
                          style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                    ]),
                  ),
                ]),
            ]);
          }),
        ),
      ),
    );
  }
}

class _CashBar extends StatelessWidget {
  const _CashBar({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        InfoChip(icon: Icons.account_balance_wallet_rounded, label: 'Cash ${formatRupees(state.finance.cash)}'),
        InfoChip(icon: Icons.speed_rounded, label: 'Credit score ${state.finance.creditScore}'),
      ]);
}

class _Owned extends StatelessWidget {
  const _Owned({required this.state, required this.content});

  final GameState state;
  final ContentBundle content;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final assets = LifestyleService.assetValue(state, content);
    final upkeep = LifestyleService.monthlyUpkeep(state, content);
    return ListView(children: [
      ResponsiveBody(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionCard(
            title: 'What you own',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                InfoChip(icon: Icons.savings_rounded, label: 'Worth ${formatRupees(assets)}'),
                InfoChip(icon: Icons.receipt_long_rounded, label: 'Upkeep ${formatRupees(upkeep)}/month'),
                InfoChip(
                    icon: Icons.account_balance_rounded,
                    label: 'Net worth ${formatRupees(state.finance.netWorth + assets)}'),
              ]),
              const SizedBox(height: 8),
              Text('Most things lose value over time; gold and property usually gain it. Upkeep is charged every month.',
                  style: t.bodySmall),
            ]),
          ),
          const SizedBox(height: 12),
          if (state.possessions.isEmpty)
            const EmptyNote('Nothing yet. Browse the tabs above — or save your money. Both are choices.',
                icon: Icons.shopping_bag_outlined),
          for (final o in state.possessions) ...[
            Builder(builder: (context) {
              final item = content.shopItems[o.itemId];
              if (item == null) return const SizedBox.shrink();
              final value = LifestyleService.resaleValue(o, item, state.day);
              final loan = state.finance.loans.where((l) => l.id == o.loanId && !l.closed).firstOrNull;
              return SectionCard(
                title: item.name,
                trailing: Icon(_categoryIcons[item.category]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.description),
                  const SizedBox(height: 8),
                  Text([
                    if (!item.isSubscription) 'Resale value ${formatRupees(value)}',
                    if (item.monthlyUpkeep > 0) '${item.upkeepLabel} ${formatRupees(item.monthlyUpkeep)}/month',
                    if (loan != null) 'Loan outstanding ${formatRupees(loan.totalOwed)}',
                  ].join(' · '), style: t.bodySmall),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: Icon(item.isSubscription ? Icons.cancel_outlined : Icons.sell_rounded),
                      label: Text(item.isSubscription ? 'Cancel' : 'Sell for ${formatRupees(value)}'),
                      onPressed: () async {
                        final ok = await showLvDialog<bool>(
                          context: context,
                          icon: Icons.sell_rounded,
                          title: item.isSubscription ? 'Cancel ${item.name}?' : 'Sell ${item.name}?',
                          message: item.isSubscription
                              ? 'The membership ends now.'
                              : 'A dealer will pay ${formatRupees(value)}.'
                                  '${loan == null ? '' : ' The ${formatRupees(loan.totalOwed)} loan on it is repaid first.'}',
                          actions: const [LvDialogAction('Confirm', true, primary: true), LvDialogAction('Keep it', false)],
                        );
                        if (ok == true && context.mounted) context.read<GameCubit>().sellItem(o.uid);
                      },
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 12),
          ],
        ]),
      ),
    ]);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.state, required this.content});

  final ShopItem item;
  final GameState state;
  final ContentBundle content;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<GameCubit>();
    final owned = state.owns(item.id);
    final cashBlocker = LifestyleService.buyBlocker(state, content, item);
    final loanBlocker = item.financeable ? LifestyleService.buyBlocker(state, content, item, finance: true) : null;
    final traded = LifestyleService.inSlot(state, content, item.slot);
    final product = content.loanProducts[item.loanProductId];
    return SectionCard(
      title: item.name,
      trailing: owned ? const InfoChip(icon: Icons.check_circle_rounded, label: 'Owned') : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.brand.isNotEmpty) Text(item.brand, style: t.labelMedium?.copyWith(color: scheme.primary)),
        Text(item.description),
        const SizedBox(height: 8),
        Text(
          item.isSubscription
              ? '${item.price > 0 ? 'Joining fee ${formatRupees(item.price)} · ' : ''}${formatRupees(item.monthlyUpkeep)}/month'
              : '${formatRupees(item.price)}${item.monthlyUpkeep > 0 ? ' · ${item.upkeepLabel.toLowerCase()} ${formatRupees(item.monthlyUpkeep)}/month' : ''}',
          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        for (final perk in item.perks)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(perk, style: t.bodySmall)),
            ]),
          ),
        if (product != null && !owned) ...[
          const SizedBox(height: 6),
          Text(
            'EMI option: ${formatRupees(LifestyleService.upfrontCost(item, content, finance: true))} down, then '
            '${formatRupees(LifestyleService.financedEmi(item, content))}/month for ${product.termMonths} months '
            'at ${product.annualRatePct}% (${product.lender}).',
            style: t.bodySmall,
          ),
        ],
        if (traded != null && !owned) ...[
          const SizedBox(height: 6),
          Text(
              'Your ${content.shopItems[traded.itemId]!.name} will be traded in for '
              '${formatRupees(LifestyleService.resaleValue(traded, content.shopItems[traded.itemId]!, state.day))}.',
              style: t.bodySmall),
        ],
        if (!owned) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.tonal(
              onPressed: cashBlocker == null ? () => cubit.buyItem(item.id) : null,
              child: Text(item.isSubscription ? 'Join' : 'Buy'),
            ),
            if (item.financeable)
              OutlinedButton(
                onPressed: loanBlocker == null ? () => cubit.buyItem(item.id, finance: true) : null,
                child: const Text('Buy on EMI'),
              ),
          ]),
          if (cashBlocker != null || (item.financeable && loanBlocker != null && loanBlocker != cashBlocker))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [?cashBlocker, if (item.financeable && loanBlocker != cashBlocker) ?loanBlocker].join(' · '),
                style: t.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ]),
    );
  }
}
