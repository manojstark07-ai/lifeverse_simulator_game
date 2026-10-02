import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/character/stats.dart';
import '../../engine/core/game_calendar.dart';
import '../../engine/core/money.dart';
import '../../engine/game_state.dart';
import '../../app/theme.dart';
import '../../shared/avatar.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../finance/finance_view.dart';
import '../game/game_cubit.dart';
import '../game/selectors.dart';
import '../map/world_map_view.dart';
import '../people/people_view.dart';
import '../profile/profile_view.dart';
import 'action_tile.dart';

/// The home dashboard and the base of the in-game navigation stack.
///
/// It owns navigation *into* story events: whenever an event becomes active
/// it pushes the story screen on top of whatever is open.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key, this.initialTab = 0});

  /// Tab to open first (0 Today, 1 City, 2 Money, 3 People, 4 Me).
  final int initialTab;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  late int _tab = widget.initialTab.clamp(0, _destinations.length - 1);
  bool _storyOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeOpenStory(context.read<GameCubit>().state),
    );
  }

  Future<void> _maybeOpenStory(GameSession session) async {
    final game = session.game;
    if (!mounted || _storyOpen || game == null || !game.story.inEvent) return;
    _storyOpen = true;
    await context.push('/story');
    _storyOpen = false;
    if (mounted) _maybeOpenStory(context.read<GameCubit>().state);
  }

  static const _destinations = [
    (Icons.today_rounded, 'Today'),
    (Icons.map_rounded, 'City'),
    (Icons.account_balance_wallet_rounded, 'Money'),
    (Icons.people_alt_rounded, 'People'),
    (Icons.person_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(
      index: _tab,
      children: const [
        _TodayTab(),
        WorldMapView(),
        FinanceView(),
        PeopleView(),
        ProfileView(),
      ],
    );
    return BlocListener<GameCubit, GameSession>(
      listenWhen: (a, b) => b.game?.story.inEvent == true,
      listener: (context, session) => _maybeOpenStory(session),
      child: Scaffold(
        body: SafeArea(
          child: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      destinations: [
                        for (final (icon, label) in _destinations)
                          NavigationRailDestination(
                            icon: Icon(icon),
                            label: Text(label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  for (final (icon, label) in _destinations)
                    NavigationDestination(icon: Icon(icon), label: label),
                ],
              ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameSession>(
      builder: (context, session) {
        final s = session.game;
        if (s == null) return const SizedBox.shrink();
        final cubit = context.read<GameCubit>();
        final c = cubit.content;
        final objective = currentObjective(s, c);
        final t = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          children: [
            ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              child: AvatarView(
                                appearance: s.profile.appearance,
                                size: 62,
                                background: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.profile.name,
                                    style: const TextStyle(
                                      fontFamily: LvFonts.display,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${ageOf(s)} · ${weekdayOf(s.day)}, ${GameCalendar.formatDay(s.day)}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    c.hometowns[s.profile.currentCityId]!.name,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _HeroIcon(
                              icon: Icons.save_rounded,
                              tooltip: 'Save game',
                              onTap: () => context.push('/saves'),
                            ),
                            const SizedBox(width: 8),
                            _HeroIcon(
                              icon: Icons.settings_rounded,
                              tooltip: 'Settings',
                              onTap: () => context.push('/settings'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _HeroPill(
                              icon: Icons.account_balance_wallet_rounded,
                              label: formatRupees(s.finance.cash),
                            ),
                            if (s.finance.arrears > 0)
                              _HeroPill(
                                icon: Icons.warning_amber_rounded,
                                label:
                                    'Overdue ${formatRupees(s.finance.arrears)}',
                              ),
                            _HeroPill(
                              icon: Icons.bolt_rounded,
                              label:
                                  'Energy ${s.stat(StatKeys.energy).round()}',
                            ),
                            _HeroPill(
                              icon: Icons.spa_rounded,
                              label:
                                  'Well-being ${s.stat(StatKeys.wellbeing).round()}',
                            ),
                            _HeroPill(
                              icon: Icons.favorite_rounded,
                              label:
                                  'Health ${s.stat(StatKeys.health).round()}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: scheme.tertiary.withValues(alpha: 0.14),
                            ),
                            child: Icon(
                              Icons.flag_rounded,
                              color: scheme.tertiary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NOW',
                                  style: t.labelSmall?.copyWith(
                                    letterSpacing: 1.6,
                                    color: scheme.tertiary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(objective.title, style: t.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  objective.detail,
                                  style: t.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TimeCard(state: s),
                  const SizedBox(height: 16),
                  _AfterHoursCard(state: s),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'At home',
                    trailing: TextButton(
                      onPressed: () => context.push('/routine'),
                      child: const Text('Weekly routine'),
                    ),
                    child: Column(
                      children: [
                        for (final a in cubit.engine.actionsAt(s, 'home'))
                          ActionTile(action: a),
                        const EmptyNote(
                          'More activities — the library, café, gym, salon, mall and car showroom — are on the City map.',
                          icon: Icons.map_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LifeMenu(state: s),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AfterHoursCard extends StatelessWidget {
  const _AfterHoursCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final mature = state.flags.contains('mature_on');
    final heat = state.counter('heat');
    return SectionCard(
      title: 'After hours',
      trailing: InfoChip(
        icon: mature ? Icons.visibility_rounded : Icons.lock_outline_rounded,
        label: mature ? 'Open' : 'Off',
        color: mature ? scheme.error : scheme.onSurfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 280),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (mature ? scheme.error : scheme.primary).withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(LvRadii.control),
              border: Border.all(
                color: (mature ? scheme.error : scheme.primary).withValues(
                  alpha: 0.16,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  mature ? Icons.nightlife_rounded : Icons.shield_rounded,
                  color: mature ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mature
                        ? 'Old Town, Lucky Star and police choices are active on the City map.'
                        : 'Turn on mature life themes in Settings to unlock crime, gambling and tougher adult storylines.',
                    style: t.bodyMedium,
                  ),
                ),
                if (mature)
                  TextButton.icon(
                    onPressed: () => context.go('/hub?tab=1'),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('City'),
                  )
                else
                  TextButton.icon(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Settings'),
                  ),
              ],
            ),
          ),
          if (mature && heat > 0) ...[
            const SizedBox(height: 10),
            ThreatMeter(heat: heat),
          ],
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final left = GameState.maxActionsPerDay - state.actionsToday;
    return SectionCard(
      title: 'Time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$left of ${GameState.maxActionsPerDay} activities left today',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Days you skip follow your weekly routine. Time stops automatically when something important happens.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: cubit.endDay,
                icon: const Icon(Icons.bedtime_rounded),
                label: const Text('End day'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => cubit.skipDays(7),
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Skip a week'),
              ),
              OutlinedButton.icon(
                onPressed: cubit.skipToNextMonth,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('To next month'),
              ),
              OutlinedButton.icon(
                onPressed: cubit.skipOneYear,
                icon: const Icon(Icons.event_repeat_rounded),
                label: const Text('Advance up to 1 year'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LifeMenu extends StatelessWidget {
  const _LifeMenu({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.school_rounded, 'Education', '/education'),
      (Icons.quiz_rounded, 'Exam Centre', '/exams'),
      (Icons.work_rounded, 'Career & jobs', '/career'),
      (Icons.shopping_bag_rounded, 'Shop & lifestyle', '/shop'),
      (Icons.auto_graph_rounded, 'Stock market', '/investments'),
      (Icons.sports_soccer_rounded, 'Sports career', '/sports'),
      (Icons.sports_mma_rounded, 'Conflict simulator', '/fight'),
      (Icons.auto_awesome_rounded, 'Desires & direction', '/desires'),
      (Icons.videocam_rounded, 'Creator Studio', '/creator'),
      (Icons.self_improvement_rounded, 'Health & routine', '/routine'),
      (Icons.timeline_rounded, 'Life timeline', '/timeline'),
      (Icons.emoji_events_rounded, 'Achievements', '/achievements'),
    ];
    return SectionCard(
      title: 'Your life',
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth > 520 ? 3 : 2;
          final width = (box.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (icon, label, route) in items)
                SizedBox(
                  width: width,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => context.push(route),
                    icon: Icon(icon),
                    label: Text(label),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.18),
    ),
    icon: Icon(icon, color: Colors.white),
    onPressed: onTap,
  );
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
