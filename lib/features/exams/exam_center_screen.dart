import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/core/game_calendar.dart';
import '../../engine/exams/exam_service.dart';
import '../../engine/game_engine.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../puzzles/puzzle_session_screen.dart';

class ExamCenterScreen extends StatelessWidget {
  const ExamCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Centre')),
      body: SafeArea(
        child: BlocBuilder<GameCubit, GameSession>(builder: (context, session) {
          final s = session.game;
          if (s == null) return const SizedBox.shrink();
          final cubit = context.read<GameCubit>();
          final c = cubit.content;
          final t = Theme.of(context).textTheme;
          final practiceBlock = cubit.engine.practiceBlocker(s);
          final mockBlock = cubit.engine.practiceBlocker(s, mock: true);
          final program = c.programs[s.education.programId];
          return ListView(children: [
            ResponsiveBody(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Practice costs one of your two daily activities and some energy. Each puzzle rewards learning the first time you solve it; every answer comes with an explanation.',
                    style: t.bodyMedium),
                const SizedBox(height: 12),
                for (final exam in c.exams.values) ...[
                  Builder(builder: (context) {
                    final record = s.exams[exam.id];
                    final prep = ExamService.preparationIndex(s, c, exam);
                    final solved = c.pool(exam.pool).where((p) => s.solvedPuzzles.contains(p.id)).length;
                    return SectionCard(
                      title: '${exam.name} (${exam.shortName})',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        EmptyNote(exam.disclaimer, icon: Icons.verified_user_outlined),
                        Text(exam.description),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final tier in exam.tiers.take(exam.tiers.length - 1))
                            InfoChip(icon: Icons.flag_rounded, label: '${tier.label}: ${tier.minComposite.round()}+'),
                        ]),
                        const SizedBox(height: 12),
                        StatBar(label: 'Preparation', value: prep, valueText: prep.round().toString(), icon: Icons.trending_up_rounded),
                        Text('Practice puzzles solved: $solved/${c.pool(exam.pool).length} · Mock tests: ${record?.mockCount ?? 0}'
                            '${(record?.mockCount ?? 0) > 0 ? ' (best ${record!.bestMockPct.round()}%)' : ''}',
                            style: t.bodySmall),
                        for (final a in record?.attempts ?? const [])
                          Text('Sat ${GameCalendar.formatDay(a.day)}: ${a.composite.toStringAsFixed(1)} — '
                              '${exam.tiers.firstWhere((x) => x.id == a.tierId).label}', style: t.bodyMedium),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          FilledButton.tonal(
                            onPressed: practiceBlock != null
                                ? null
                                : () => context.push('/puzzle',
                                    extra: PuzzleSessionArgs(
                                        mode: PuzzleMode.practice,
                                        title: '${exam.shortName} practice',
                                        puzzles: cubit.engine.practiceSet(s, exam.pool))),
                            child: const Text('Practice (3 questions)'),
                          ),
                          OutlinedButton(
                            onPressed: mockBlock != null
                                ? null
                                : () => context.push('/puzzle',
                                    extra: PuzzleSessionArgs(
                                      mode: PuzzleMode.mock,
                                      title: '${exam.shortName} mock test',
                                      puzzles: cubit.engine.mockPaper(s, exam.id),
                                      durationSec: exam.durationSec,
                                      disclaimer: exam.disclaimer,
                                      examId: exam.id,
                                    )),
                            child: const Text('Full mock test'),
                          ),
                        ]),
                        if (practiceBlock != null || mockBlock != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(practiceBlock ?? 'Mock tests need ${GameEngine.mockEnergy.round()} energy.',
                                style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                          ),
                      ]),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                if (program?.practicePool != null && s.education.isEnrolled)
                  SectionCard(
                    title: '${program!.shortName} coursework practice',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Questions in the style of your university papers.'),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: practiceBlock != null
                            ? null
                            : () => context.push('/puzzle',
                                extra: PuzzleSessionArgs(
                                    mode: PuzzleMode.practice,
                                    title: '${program.shortName} practice',
                                    puzzles: cubit.engine.practiceSet(s, program.practicePool!, count: 2))),
                        child: const Text('Practice (2 questions)'),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}
