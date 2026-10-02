import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/core/money.dart';
import '../../engine/education/education_models.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Education')),
      body: SafeArea(
        child: BlocBuilder<GameCubit, GameSession>(builder: (context, session) {
          final s = session.game;
          if (s == null) return const SizedBox.shrink();
          final c = context.read<GameCubit>().content;
          final e = s.education;
          final t = Theme.of(context).textTheme;
          final program = c.programs[e.programId];
          final tier = program?.tier(e.tierId ?? '');
          return ListView(children: [
            ResponsiveBody(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionCard(
                  title: 'Your studies',
                  child: program == null
                      ? const EmptyNote('Not enrolled yet. Admissions follow results day and the UTAT exam (for engineering).')
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(program.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${tier?.name ?? ''} · ${switch (e.status) {
                            EducationStatus.enrolled => 'Enrolled',
                            EducationStatus.graduated => 'Graduated',
                            EducationStatus.dropped => 'Left the course',
                            _ => e.status,
                          }}'),
                          const SizedBox(height: 12),
                          StatBar(
                            label: 'Progress',
                            value: e.monthsCompleted.toDouble(),
                            max: program.durationMonths.toDouble(),
                            valueText: '${e.monthsCompleted}/${program.durationMonths}',
                          ),
                          const SizedBox(height: 8),
                          if (e.semesterGpas.isNotEmpty) ...[
                            Text('CGPA ${e.cgpa.toStringAsFixed(2)}', style: t.titleSmall),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final (i, g) in e.semesterGpas.indexed)
                                Chip(
                                  label: Text('S${i + 1}: ${g.toStringAsFixed(1)}'),
                                  backgroundColor: g < 5 ? Theme.of(context).colorScheme.errorContainer : null,
                                ),
                            ]),
                          ] else
                            const Text('First semester results arrive after six months.'),
                          if (e.backlogs > 0) Text('Backlogs to clear: ${e.backlogs}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 8),
                          if (tier != null)
                            Text('Fees: ${formatRupees((tier.feesPerYear / 2 * (1 - e.scholarshipShare)).round())} per semester'
                                '${e.scholarshipName != null ? ' after the ${e.scholarshipName} (${(e.scholarshipShare * 100).round()}%)' : ''}'),
                          const SizedBox(height: 8),
                          Text('Grades depend on knowledge, your course skill, discipline and how rested you are — plus how you do in exam challenges.',
                              style: t.bodySmall),
                        ]),
                ),
                const SizedBox(height: 16),
                Text('Pathways', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final p in c.programs.values) ...[
                  SectionCard(
                    title: p.name,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.description),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        InfoChip(icon: Icons.schedule_rounded, label: '${p.durationMonths ~/ 12} years'),
                        InfoChip(icon: Icons.class_rounded, label: '${p.weeklyHours.round()} h/week'),
                        InfoChip(
                            icon: Icons.how_to_reg_rounded,
                            label: p.admissionType == 'exam' ? 'Entrance: ${c.exams[p.admissionExamId]!.shortName}' : 'Open admission'),
                        for (final tr in p.tiers) InfoChip(icon: Icons.payments_rounded, label: '${tr.name}: ${formatRupees(tr.feesPerYear)}/yr'),
                      ]),
                      const SizedBox(height: 8),
                      Text('Leads to: ${p.careerIds.map((x) => c.careers[x]!.name).join(', ')}', style: t.bodySmall),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
                Text('Fees are indicative figures for a fictional world.', style: t.bodySmall, textAlign: TextAlign.center),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}
