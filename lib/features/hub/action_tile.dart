import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/actions/daily_action.dart';
import '../../engine/core/money.dart';
import '../../app/theme.dart';
import '../game/game_cubit.dart';

/// A daily activity with its costs and, if unavailable, the reason why.
class ActionTile extends StatefulWidget {
  const ActionTile({super.key, required this.action});

  final DailyAction action;

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final cubit = context.read<GameCubit>();
    final blocker = cubit.engine.actionBlocker(cubit.game, action);
    final costs = [
      if (action.energyCost > 0) '−${action.energyCost.round()} energy',
      if (action.moneyCost > 0) formatRupees(-action.moneyCost),
    ].join(' · ');
    final scheme = Theme.of(context).colorScheme;
    final dangerous =
        action.id.startsWith('crime_') || action.location == 'backstreets';
    final color = dangerous ? scheme.error : scheme.primary;
    final reduced = MediaQuery.of(context).disableAnimations;
    return AnimatedScale(
      scale: _down && !reduced ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dangerous ? 0.08 : 0.045),
          borderRadius: BorderRadius.circular(LvRadii.control),
          border: Border.all(
            color: color.withValues(alpha: dangerous ? 0.22 : 0.12),
          ),
        ),
        child: Listener(
          onPointerDown: (_) => setState(() => _down = true),
          onPointerCancel: (_) => setState(() => _down = false),
          onPointerUp: (_) => setState(() => _down = false),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(_iconFor(action), size: 19, color: color),
            ),
            title: Text(action.label),
            subtitle: Text(
              [
                action.description,
                if (costs.isNotEmpty) costs,
                ?blocker,
              ].join('\n'),
            ),
            isThreeLine: costs.isNotEmpty || blocker != null,
            trailing: FilledButton.tonal(
              onPressed: blocker == null
                  ? () => cubit.performAction(action.id)
                  : null,
              child: const Text('Do'),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(DailyAction action) {
    if (action.id.contains('heist') || action.id.contains('robbery')) {
      return Icons.account_balance_rounded;
    }
    if (action.id.startsWith('cyber_') || action.id.startsWith('darkweb_')) {
      return Icons.terminal_rounded;
    }
    if (action.id.startsWith('bio_')) {
      return Icons.biotech_rounded;
    }
    if (action.id.contains('kidnap') || action.id.contains('abduction')) {
      return Icons.warning_rounded;
    }
    if (action.id.contains('shooting')) return Icons.crisis_alert_rounded;
    if (action.id.startsWith('crime_')) return Icons.gpp_maybe_rounded;
    if (action.location == 'police_station') return Icons.local_police_rounded;
    return Icons.flash_on_rounded;
  }
}
