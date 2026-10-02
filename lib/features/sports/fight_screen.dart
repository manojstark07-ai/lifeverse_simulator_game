import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

class FightScreen extends StatefulWidget {
  const FightScreen({super.key});

  @override
  State<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends State<FightScreen> {
  int _round = 0;
  int _you = 100;
  int _other = 100;
  bool _over = false;
  String? _result;

  void _move(String action) {
    if (_over) return;
    final pressure = 8 + ((_round * 7) % 10);
    var you = _you;
    var other = _other;
    switch (action) {
      case 'deescalated':
        _finish('deescalated');
        return;
      case 'escaped':
        if ((_round + you) % 3 != 0) {
          _finish('escaped');
          return;
        }
        you -= 3;
        break;
      case 'counter':
        other -= 15;
        you -= pressure;
        break;
      case 'block':
        you -= (pressure / 3).round();
        break;
    }
    _round++;
    if (_round >= 4 || other <= 0 || you <= 0) {
      _finish(other <= 0 && you > 0 ? 'won' : 'lost');
      return;
    }
    setState(() {
      _you = math.max(0, you);
      _other = math.max(0, other);
    });
  }

  void _finish(String result) {
    setState(() {
      _over = true;
      _result = result;
    });
    context.read<GameCubit>().recordFight(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conflict simulator')),
      body: SafeArea(
        child: ListView(
          children: [
            ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EmptyNote(
                    'A non-graphic, fictional conflict drill. The strongest outcome is often leaving safely or cooling things down. No real-world fighting advice is intended.',
                    icon: Icons.shield_rounded,
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: _over
                        ? 'Conflict resolved'
                        : 'Round ${_round + 1} of 4',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatBar(
                          label: 'Your composure',
                          value: _you.toDouble(),
                          color: scheme.primary,
                          icon: Icons.favorite_rounded,
                        ),
                        StatBar(
                          label: 'Other person',
                          value: _other.toDouble(),
                          color: scheme.error,
                          icon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 10),
                        if (_over)
                          Text(
                            switch (_result) {
                              'deescalated' =>
                                'You lowered the temperature before anyone was hurt.',
                              'escaped' =>
                                'You found a safe exit and got away.',
                              'won' =>
                                'You gained the upper hand, but there was a cost.',
                              _ => 'You took a knock and the situation ended.',
                            },
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          )
                        else ...[
                          Text(
                            'Choose one response:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => _move('deescalated'),
                                icon: const Icon(Icons.forum_rounded),
                                label: const Text('Talk it down'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _move('escaped'),
                                icon: const Icon(Icons.exit_to_app_rounded),
                                label: const Text('Leave safely'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _move('block'),
                                icon: const Icon(Icons.shield_rounded),
                                label: const Text('Protect'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _move('counter'),
                                icon: const Icon(Icons.flash_on_rounded),
                                label: const Text('Counter'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
