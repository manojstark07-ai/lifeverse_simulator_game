import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/time/life_simulation.dart';
import '../../engine/time/routine.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

/// Weekly routine (habits). Applies to every day you don't play individually.
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  late final Routine _draft = context.read<GameCubit>().game.routine.copy();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final preview = cubit.game.clone()..routine = _draft;
    final b = RoutineBudget.of(preview, cubit.content);
    final t = Theme.of(context).textTheme;
    final over = _draft.planned > b.free;
    Widget slider(String label, String help, double value, void Function(double) set, IconData icon) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label, style: t.titleSmall),
              const Spacer(),
              Text('${value.round()} h/week', style: t.labelLarge),
            ]),
            Slider(value: value, min: 0, max: 40, divisions: 40, label: '${value.round()} h', onChanged: (v) => setState(() => set(v))),
            Text(help, style: t.bodySmall),
            const SizedBox(height: 12),
          ],
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Health & routine')),
      body: SafeArea(
        child: ListView(children: [
          ResponsiveBody(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionCard(
                title: 'Your week',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('168 hours − ${Routine.sleepHours.round()} sleep − ${Routine.essentialHours.round()} meals, chores & errands'),
                  for (final e in b.commitmentLines.entries) Text('− ${e.value.round()} ${e.key}'),
                  const Divider(),
                  Text('${b.free.round()} free hours to plan', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Habits',
                child: Column(children: [
                  slider('Study', 'Builds knowledge and discipline. Too much, on top of commitments, drains energy.', _draft.study,
                      (v) => _draft.study = v, Icons.menu_book_rounded),
                  slider('Exercise', 'Lifts well-being and energy; a little discipline too.', _draft.exercise, (v) => _draft.exercise = v,
                      Icons.directions_run_rounded),
                  slider('Friends', 'Communication and well-being; keeps friendships warm.', _draft.social, (v) => _draft.social = v,
                      Icons.groups_rounded),
                  slider('Family', 'Keeps family bonds strong and steadies well-being.', _draft.family, (v) => _draft.family = v,
                      Icons.family_restroom_rounded),
                ]),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Projection',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (over)
                    Text('You planned ${_draft.planned.round()} hours but only have ${b.free.round()}. Everything will be scaled down to fit.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  Text('Leisure left: ${b.leisure.round()} h/week'),
                  StatBar(label: 'Energy settles at', value: b.energyTarget, color: const Color(0xFFF2A33A), icon: Icons.bolt_rounded),
                  Text(b.load > 0.75
                      ? 'This week is overloaded. Expect well-being to fall.'
                      : b.load > 0.55
                          ? 'A demanding week. Sustainable if you rest well.'
                          : 'A balanced week.'),
                ]),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  cubit.setRoutine(_draft);
                  Navigator.of(context).maybePop();
                },
                child: const Text('Save routine'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
