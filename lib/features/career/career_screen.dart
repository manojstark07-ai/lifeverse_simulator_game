import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/character/stats.dart';
import '../../engine/career/career_service.dart';
import '../../engine/core/money.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../puzzles/puzzle_session_screen.dart';

class CareerScreen extends StatelessWidget {
  const CareerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Career')),
      body: SafeArea(
        child: BlocBuilder<GameCubit, GameSession>(
          builder: (context, session) {
            final s = session.game;
            if (s == null) return const SizedBox.shrink();
            final c = context.read<GameCubit>().content;
            final t = Theme.of(context).textTheme;
            final scheme = Theme.of(context).colorScheme;
            final career = c.careers[s.career.careerId];
            final pt = c.partTimeJobs[s.career.partTimeJobId];
            return ListView(
              children: [
                ResponsiveBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (career != null)
                        SectionCard(
                          title: 'Current role',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                career.ladder[s.career.level].title,
                                style: t.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (s.career.employer != null)
                                Text(s.career.employer!),
                              const SizedBox(height: 8),
                              Text(
                                'Salary ${formatRupees(s.career.monthlySalary)}/month · ${s.career.monthsInRole} months in role',
                              ),
                              StatBar(
                                label: 'Performance',
                                value: s.career.performance,
                                icon: Icons.insights_rounded,
                              ),
                              Text(
                                'Annual reviews happen every 12 months in a role. Promotions need time, skill and performance ≥ 60.',
                                style: t.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Text('Career ladder', style: t.labelLarge),
                              for (final (i, level) in career.ladder.indexed)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    i < s.career.level
                                        ? Icons.check_circle_rounded
                                        : (i == s.career.level
                                              ? Icons
                                                    .radio_button_checked_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded),
                                    color: i <= s.career.level
                                        ? scheme.primary
                                        : scheme.outline,
                                  ),
                                  title: Text(level.title),
                                  subtitle: Text(
                                    i == 0
                                        ? 'Entry level · ~${formatRupees(level.monthlySalary)}'
                                        : '~${formatRupees(level.monthlySalary)} · ${level.minMonths}+ months · ${SkillKeys.labels[career.primarySkill]} ${level.skillRequired.round()}+',
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    FilledButton.tonalIcon(
                                      icon: const Icon(
                                        Icons.swap_horiz_rounded,
                                      ),
                                      label: const Text('Change company'),
                                      onPressed: () => context
                                          .read<GameCubit>()
                                          .switchEmployer(),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.logout_rounded),
                                      label: const Text('Resign'),
                                      onPressed: () async {
                                        final ok = await showLvDialog<bool>(
                                          context: context,
                                          icon: Icons.logout_rounded,
                                          title: 'Resign from your job?',
                                          message:
                                              'Your salary stops immediately. Your experience stays on your record.',
                                          actions: const [
                                            LvDialogAction(
                                              'Resign',
                                              true,
                                              destructive: true,
                                            ),
                                            LvDialogAction('Stay', false),
                                          ],
                                        );
                                        if (ok == true && context.mounted) {
                                          context.read<GameCubit>().quitJob();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SectionCard(
                          title: 'Current role',
                          child: EmptyNote(
                            'No full-time job yet. Apply to any profession below that you qualify for — or wait for '
                            'your story to bring an opportunity.',
                          ),
                        ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: 'Projects & startups',
                        trailing: InfoChip(
                          icon: Icons.rocket_launch_rounded,
                          label: 'Founder path',
                          color: scheme.tertiary,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Launch FixLab, a small repair-and-services startup. It starts lean, but business skill and annual reviews can grow it.',
                            ),
                            const SizedBox(height: 8),
                            StatBar(
                              label: SkillKeys.labels[SkillKeys.business]!,
                              value: s.skill(SkillKeys.business),
                              icon: Icons.storefront_rounded,
                            ),
                            Text(
                              'Requires ${formatRupees(25000)} launch cash and 18 energy. Replaces your current full-time job.',
                              style: t.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilledButton.icon(
                                  icon: const Icon(Icons.rocket_launch_rounded),
                                  label: Text(
                                    s.career.careerId == 'fixlab_founder'
                                        ? 'Running FixLab'
                                        : 'Launch FixLab',
                                  ),
                                  onPressed:
                                      s.career.careerId == 'fixlab_founder'
                                      ? null
                                      : () => context
                                            .read<GameCubit>()
                                            .startStartup(),
                                ),
                                if (s.finance.cash < 25000)
                                  Text(
                                    'Need ${formatRupees(25000 - s.finance.cash)} more cash',
                                    style: t.bodySmall?.copyWith(
                                      color: scheme.error,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: 'Part-time work',
                        child: pt == null
                            ? const EmptyNote(
                                'No part-time job. Try the café, the salon or the mall food court on the city map.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${pt.name} at ${pt.employer}: ${pt.weeklyHours.round()} h/week, about ${formatRupees(pt.monthlyPay)}/month '
                                    '(adjusted for your city).',
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: context
                                          .read<GameCubit>()
                                          .quitPartTime,
                                      child: const Text('Quit'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Professions',
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final k in c.careers.values.where(
                        (k) => k.listed,
                      )) ...[
                        Builder(
                          builder: (context) {
                            final qualified = CareerService.qualified(s, c, k);
                            final skill = s.skill(k.primarySkill);
                            final blocker = CareerService.applicationBlocker(
                              s,
                              c,
                              k,
                            );
                            final cubit = context.read<GameCubit>();
                            return SectionCard(
                              title: k.name,
                              trailing: InfoChip(
                                icon: qualified
                                    ? Icons.verified_rounded
                                    : Icons.lock_outline_rounded,
                                label: !k.needsQualification
                                    ? 'No degree needed'
                                    : (qualified
                                          ? 'Qualified'
                                          : 'Needs ${k.requiredPrograms.map((p) => c.programs[p]!.shortName).join(' / ')}'),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(k.description),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${k.sector} · demand ${(k.demand * 100).round()}% · ${k.weeklyHours.round()} h/week',
                                    style: t.bodySmall,
                                  ),
                                  Text(
                                    'Starts around ${formatRupees(k.ladder.first.monthlySalary)}/month; top level ~${formatRupees(k.ladder.last.monthlySalary)}.',
                                    style: t.bodySmall,
                                  ),
                                  StatBar(
                                    label: SkillKeys.labels[k.primarySkill]!,
                                    value: skill,
                                  ),
                                  Text(
                                    'Needs ${SkillKeys.labels[k.primarySkill]} ${k.minPrimarySkill.round()}+'
                                    '${k.requirementNote == null ? '' : ' · ${k.requirementNote}'}. Interviews weigh a puzzle round, '
                                    'skills, communication and your institution.',
                                    style: t.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      FilledButton.tonalIcon(
                                        icon: const Icon(
                                          Icons.work_outline_rounded,
                                        ),
                                        label: Text(
                                          s.career.careerId == k.id
                                              ? 'Your field'
                                              : 'Apply',
                                        ),
                                        onPressed: blocker != null
                                            ? null
                                            : () => context.push(
                                                '/puzzle',
                                                extra: PuzzleSessionArgs(
                                                  mode: PuzzleMode.interview,
                                                  title:
                                                      '${k.ladder.first.title} interview',
                                                  puzzles: cubit.engine
                                                      .interviewPuzzles(
                                                        s,
                                                        k.id,
                                                      ),
                                                  careerId: k.id,
                                                ),
                                              ),
                                      ),
                                      if (blocker != null &&
                                          s.career.careerId != k.id)
                                        Text(
                                          blocker,
                                          style: t.bodySmall?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        'Salaries are indicative figures for a fictional world.',
                        style: t.bodySmall,
                        textAlign: TextAlign.center,
                      ),
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
}
