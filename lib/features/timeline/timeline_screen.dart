import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/core/game_calendar.dart';
import '../../engine/game_state.dart';
import '../../engine/journal/journal.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../game/selectors.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  bool _importantOnly = true;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Life timeline'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Decisions'),
              Tab(text: 'Journal'),
            ],
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<GameCubit, GameSession>(
            builder: (context, session) {
              final s = session.game;
              if (s == null) return const SizedBox.shrink();
              final t = Theme.of(context).textTheme;
              final scheme = Theme.of(context).colorScheme;
              final journal = s.journal
                  .where((j) => !_importantOnly || j.important)
                  .toList()
                  .reversed
                  .toList();
              return TabBarView(
                children: [
                  ListView(
                    children: [
                      _JourneyHeader(state: s),
                      if (s.decisions.isEmpty)
                        const ResponsiveBody(
                          child: EmptyNote('Your decisions will appear here.'),
                        )
                      else
                        for (final d in s.decisions.reversed)
                          ResponsiveBody(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        margin: const EdgeInsets.only(top: 18),
                                        decoration: BoxDecoration(
                                          color: scheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: scheme.outlineVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${GameCalendar.formatDay(d.day)} · ${d.eventTitle}',
                                            style: t.labelMedium,
                                          ),
                                          Text(
                                            d.choiceLabel,
                                            style: t.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (d.outcomes.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  for (final o in d.outcomes)
                                                    Chip(
                                                      label: Text(o),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                  ListView(
                    children: [
                      ResponsiveBody(
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Important moments only'),
                              value: _importantOnly,
                              onChanged: (v) =>
                                  setState(() => _importantOnly = v),
                            ),
                            _JourneyHeader(state: s),
                            for (final j in journal)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(switch (j.kind) {
                                  JournalKind.money => Icons.payments_rounded,
                                  JournalKind.education => Icons.school_rounded,
                                  JournalKind.career => Icons.work_rounded,
                                  JournalKind.milestone => Icons.star_rounded,
                                  JournalKind.month =>
                                    Icons.calendar_month_rounded,
                                  _ => Icons.auto_stories_rounded,
                                }),
                                title: Text(j.title),
                                subtitle: Text(
                                  '${GameCalendar.formatDay(j.day)}\n${j.body}',
                                ),
                                isThreeLine: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final objective = currentObjective(state, cubit.content);
    final city =
        cubit.content.hometowns[state.profile.currentCityId]?.name ??
        state.profile.currentCityId;
    final t = Theme.of(context).textTheme;
    return ResponsiveBody(
      child: SectionCard(
        title: 'Where your life stands',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              objective.title,
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(objective.detail),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label:
                      '${ageOf(state)} · ${GameCalendar.formatDay(state.day)}',
                ),
                InfoChip(icon: Icons.location_on_rounded, label: city),
                InfoChip(
                  icon: Icons.auto_stories_rounded,
                  label: 'Chapter ${state.chapter}',
                ),
                InfoChip(
                  icon: Icons.history_rounded,
                  label: '${state.decisions.length} decisions',
                ),
                if (state.scheduled.isNotEmpty)
                  InfoChip(
                    icon: Icons.schedule_rounded,
                    label:
                        '${state.scheduled.length} delayed outcome${state.scheduled.length == 1 ? '' : 's'}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
