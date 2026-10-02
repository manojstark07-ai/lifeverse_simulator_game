import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/finance/investment_service.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

class DesiresScreen extends StatelessWidget {
  const DesiresScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Desires & direction')),
    body: SafeArea(
      child: BlocBuilder<GameCubit, GameSession>(
        builder: (context, session) {
          final s = session.game;
          if (s == null) return const SizedBox.shrink();
          final c = context.read<GameCubit>().content;
          final ambition = c.ambitions[s.profile.ambitionId];
          final athlete = (s.counter('sports_sessions') / 5).clamp(0.0, 1.0);
          final scholar =
              s.education.completedPrograms.isNotEmpty || s.education.isEnrolled
              ? 0.6
              : 0.15;
          final wealth =
              ((s.finance.cash + InvestmentService.portfolioValue(s.finance)) /
                      100000)
                  .clamp(0.0, 1.0);
          final goals = [
            _Goal(
              'Your chosen ambition',
              '${ambition?.name ?? 'Write your own story'} · ${ambition?.description ?? 'Keep making choices that feel like yours.'}',
              0.35,
              Icons.flag_rounded,
            ),
            _Goal(
              'Build financial breathing room',
              'Cash and portfolio reach ₹1,00,000',
              wealth,
              Icons.account_balance_wallet_rounded,
            ),
            _Goal(
              'Earn through sport',
              '${s.counter('sports_sessions')} timing sessions · athlete path ${s.flags.contains('athlete_path') ? 'open' : 'in progress'}',
              athlete,
              Icons.emoji_events_rounded,
            ),
            _Goal(
              'Keep learning',
              s.education.isEnrolled
                  ? 'Studying ${c.programs[s.education.programId]?.shortName ?? 'a programme'}'
                  : 'Choose a course or exam to begin',
              scholar,
              Icons.school_rounded,
            ),
            _Goal(
              'Make something of your own',
              s.flags.contains('startup_founder')
                  ? 'FixLab is running'
                  : 'Launch a startup when ready',
              s.flags.contains('startup_founder') ? 1 : 0,
              Icons.rocket_launch_rounded,
            ),
            _Goal(
              'Protect your peace',
              'Health ${s.stat('health').round()} · well-being ${s.stat('wellbeing').round()}',
              ((s.stat('health') + s.stat('wellbeing')) / 200).clamp(0.0, 1.0),
              Icons.spa_rounded,
            ),
          ];
          return ListView(
            children: [
              ResponsiveBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EmptyNote(
                      'Desires are directions, not a checklist. A life can change its mind.',
                      icon: Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(height: 16),
                    for (final goal in goals) ...[
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  goal.icon,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    goal.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(goal.detail),
                            const SizedBox(height: 10),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: goal.progress),
                              duration: MediaQuery.of(context).disableAnimations
                                  ? Duration.zero
                                  : const Duration(milliseconds: 500),
                              builder: (_, value, __) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                            ),
                          ],
                        ),
                      ),
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

class _Goal {
  const _Goal(this.title, this.detail, this.progress, this.icon);
  final String title;
  final String detail;
  final double progress;
  final IconData icon;
}
