import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/actions/daily_action.dart';
import '../../engine/game_state.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../hub/action_tile.dart';
import 'city_map_game.dart';

/// Screens reachable from each map location.
const _shortcuts = {
  'home': [
    ('Weekly routine', Icons.self_improvement_rounded, '/routine'),
    ('Creator Studio', Icons.videocam_rounded, '/creator'),
    ('Direct action mode', Icons.directions_run_rounded, '/world'),
  ],
  'library': [('Exam Centre: practice & mocks', Icons.quiz_rounded, '/exams')],
  'exam_hall': [('Exam Centre', Icons.quiz_rounded, '/exams')],
  'campus': [('Education', Icons.school_rounded, '/education')],
  'office': [('Career', Icons.work_rounded, '/career')],
  'bank': [
    ('Accounts & loans', Icons.account_balance_rounded, '/finance'),
    ('Investing desk', Icons.auto_graph_rounded, '/investments'),
    (
      'Long-term life planning',
      Icons.account_balance_rounded,
      '/life-management',
    ),
    ('Property & home loans', Icons.apartment_rounded, '/shop?tab=property'),
  ],
  'cafe': <(String, IconData, String)>[],
  'park': [('Weekly routine', Icons.self_improvement_rounded, '/routine')],
  'hospital': <(String, IconData, String)>[],
  'bar': <(String, IconData, String)>[],
  'mall': [
    (
      'Shop phones, gadgets & fashion',
      Icons.shopping_bag_rounded,
      '/shop?tab=phone',
    ),
    ('Memberships', Icons.card_membership_rounded, '/shop?tab=subscription'),
  ],
  'salon': [('Book a makeover', Icons.content_cut_rounded, '/makeover')],
  'gym': [
    ('Gym membership', Icons.card_membership_rounded, '/shop?tab=subscription'),
  ],
  'showroom': [
    ('Browse cars & bikes', Icons.directions_car_rounded, '/shop?tab=vehicle'),
  ],
  'backstreets': [
    ('Career: underworld paths', Icons.work_history_rounded, '/career'),
  ],
  'police_station': [('Life timeline', Icons.timeline_rounded, '/timeline')],
  'dark_web_terminal': [
    ('Exam Centre: cyber forensics', Icons.quiz_rounded, '/exams'),
    ('Life timeline', Icons.timeline_rounded, '/timeline'),
  ],
  'bio_backroom': [
    ('Exam Centre: biomedical ethics', Icons.quiz_rounded, '/exams'),
    ('Health & routine', Icons.self_improvement_rounded, '/routine'),
  ],
};

class WorldMapView extends StatefulWidget {
  const WorldMapView({super.key});

  @override
  State<WorldMapView> createState() => _WorldMapViewState();
}

class _WorldMapViewState extends State<WorldMapView> {
  CityMapGame? _game;
  Brightness? _builtFor;
  bool? _builtReduced;
  String? _builtSites;

  /// Locations whose requirements currently hold (e.g. the bar is 21+).
  List<MapLocation> _visible(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final game = cubit.state.game;
    return cubit.content.locations.values
        .where((l) => game == null || l.requires.evaluate(game, cubit.content))
        .toList();
  }

  CityMapGame _buildGame(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.of(context).disableAnimations;
    final sites = _visible(context).map((l) => l.id).join(',');
    if (_game != null &&
        _builtFor == Theme.of(context).brightness &&
        _builtReduced == reduced &&
        _builtSites == sites) {
      return _game!;
    }
    _builtSites = sites;
    _builtFor = Theme.of(context).brightness;
    _builtReduced = reduced;
    return _game = CityMapGame(
      sites: [
        for (final l in _visible(context))
          MapSite(
            id: l.id,
            name: l.mapLabel,
            kind: l.kind,
            gx: l.gridX,
            gy: l.gridY,
          ),
      ],
      palette: MapPalette(
        background: dark ? const Color(0xFF1B1A26) : const Color(0xFFE8F1F2),
        groundA: dark ? const Color(0xFF2B3A33) : const Color(0xFFCFE6C9),
        groundB: dark ? const Color(0xFF26332D) : const Color(0xFFBFDDB8),
        label: scheme.onSurface,
        labelBackground: scheme.surface.withValues(alpha: 0.85),
      ),
      reducedMotion: reduced,
      onSiteTapped: _openLocation,
    );
  }

  void _openLocation(String id) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<GameCubit>(),
        child: _LocationSheet(locationId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GameCubit>();
    final visible = _visible(context);
    return LayoutBuilder(
      builder: (context, box) {
        final mapHeight = (box.maxHeight * 0.62).clamp(260.0, 560.0);
        return ListView(
          children: [
            SizedBox(
              height: mapHeight,
              child: Semantics(
                label: 'City map. Use the list below to choose a location.',
                child: GameWidget(game: _buildGame(context)),
              ),
            ),
            ResponsiveBody(
              child: SectionCard(
                title: 'Places',
                child: Column(
                  children: [
                    for (final l in visible)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.name),
                        subtitle: Text(l.description),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          _game?.moveMarker(l.id);
                          _openLocation(l.id);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameSession>(
      builder: (context, session) {
        final game = session.game;
        if (game == null) return const SizedBox.shrink();
        final cubit = context.read<GameCubit>();
        final loc = cubit.content.locations[locationId]!;
        final actions = cubit.engine.actionsAt(game, locationId);
        final t = Theme.of(context).textTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Text(
                      loc.name,
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(loc.description),
                    const SizedBox(height: 8),
                    Text(
                      '${GameState.maxActionsPerDay - game.actionsToday} activities left today · Energy ${game.stat('energy').round()}',
                      style: t.labelLarge,
                    ),
                    const Divider(height: 24),
                    if (actions.isEmpty)
                      const EmptyNote('Nothing to do here right now.'),
                    for (final a in actions) ActionTile(action: a),
                    for (final (label, icon, route)
                        in _shortcuts[locationId] ??
                            const <(String, IconData, String)>[])
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          icon: Icon(icon),
                          label: Text(label),
                          onPressed: () {
                            Navigator.pop(context);
                            context.push(route);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
