import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/core/money.dart';
import '../../engine/endings/conclusion_service.dart';
import '../../app/theme.dart';
import '../../shared/avatar.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../game/selectors.dart';

class ConclusionScreen extends StatelessWidget {
  const ConclusionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final s = cubit.game;
    final c = cubit.content;
    final conclusion = c.conclusions[s.conclusionId];
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (conclusion == null)
      return const Scaffold(
        body: Center(child: Text('No chapter has concluded yet.')),
      );
    final epilogue = ConclusionService.epilogue(s, c);
    final career = c.careers[s.career.careerId];
    final closest =
        (s.relationships.values.where((r) => r.met).toList()
              ..sort((a, b) => b.affinity.compareTo(a.affinity)))
            .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'CHAPTER ${s.chapter - 1} COMPLETE',
                    textAlign: TextAlign.center,
                    style: t.labelLarge?.copyWith(
                      letterSpacing: 3,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    conclusion.title,
                    textAlign: TextAlign.center,
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LvColors.primaryGradient,
                      ),
                      child: AvatarView(
                        appearance: s.profile.appearance,
                        size: 112,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conclusion.text,
                            style: TextStyle(
                              fontFamily: LvFonts.display,
                              fontSize: 18,
                              height: 1.6,
                              color: scheme.onSurface,
                            ),
                          ),
                          for (final line in epilogue) ...[
                            const SizedBox(height: 10),
                            Text(
                              line,
                              style: t.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Looking back',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s.profile.name}, age ${ageOf(s)}'),
                        if (s.education.completedPrograms.isNotEmpty)
                          Text(
                            'Studied: ${s.education.completedPrograms.map((p) => c.programs[p]!.shortName).join(', ')}'
                            '${s.education.semesterGpas.isEmpty ? '' : ' (CGPA ${s.education.cgpa.toStringAsFixed(2)})'}',
                          ),
                        if (career != null)
                          Text(
                            'Work: ${career.ladder[s.career.level].title}${s.career.employer == null ? '' : ' at ${s.career.employer}'}',
                          ),
                        Text(
                          'Savings ${formatRupees(s.finance.cash)} · debt ${formatRupees(s.finance.totalDebt)}',
                        ),
                        if (closest != null)
                          Text('Closest bond: ${c.npcs[closest.npcId]!.name}'),
                        Text(
                          '${s.decisions.length} decisions · ${s.achievements.length} achievements',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Keep living',
                    onPressed: () => context.go('/hub'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save this life'),
                    onPressed: () => context.push('/saves'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Begin a new life'),
                    onPressed: () async {
                      await cubit.flushSaves();
                      cubit.closeGame();
                      if (context.mounted) context.go('/create');
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Begin New Life+ with this legacy'),
                    onPressed: () => context.push('/create?plus=1'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your story continues in a sandbox: salary, promotions and loans keep running. New chapters arrive in future updates.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
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
