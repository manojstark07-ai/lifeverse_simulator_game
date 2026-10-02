import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/core/game_calendar.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import 'life_world_game.dart';

class LifeWorldScreen extends StatefulWidget {
  const LifeWorldScreen({super.key});

  @override
  State<LifeWorldScreen> createState() => _LifeWorldScreenState();
}

class _LifeWorldScreenState extends State<LifeWorldScreen> {
  late final LifeWorldGame _game;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<GameCubit>();
    final locations = cubit.content.locations.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final people = cubit.content.npcs.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    _game = LifeWorldGame(
      reducedMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
      spots: [
        for (final location in locations.take(14))
          WorldSpot(
            id: location.id,
            kind: location.kind,
            x: 0.12 + (location.gridX % 5) * 0.18,
            y: 0.18 + (location.gridY % 5) * 0.14,
          ),
      ],
      npcs: [
        for (final (index, npc) in people.take(8).indexed)
          WorldNpc(
            id: npc.id,
            name: npc.name,
            x: 0.14 + (index % 4) * 0.23,
            y: 0.28 + (index ~/ 4) * 0.2,
            color: const [
              Color(0xFFE5486F),
              Color(0xFF5B6CE0),
              Color(0xFF14A394),
              Color(0xFFD9772B),
              Color(0xFF7B4FD6),
              Color(0xFF52A65A),
              Color(0xFFB85C9E),
              Color(0xFF8D6E4F),
            ][index % 8],
          ),
      ],
      onInteract: _openLocation,
      onNpcInteract: _openNpc,
    );
  }

  void _openLocation(String id) {
    if (!mounted) return;
    context.push('/interior/${Uri.encodeComponent(id)}');
  }

  void _openNpc(String npcId) {
    if (!mounted) return;
    final cubit = context.read<GameCubit>();
    final npc = cubit.content.npcs[npcId];
    if (npc == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(npc.name),
        content: Text('${npc.role}\n\n${npc.bio}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.forum_rounded),
            label: const Text('Talk'),
            onPressed: () {
              Navigator.pop(context);
              cubit.talkToNpc(npcId);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _game.pauseEngine();
    _game.onRemove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore the city'),
        actions: [
          IconButton(
            tooltip: 'Interact',
            icon: const Icon(Icons.touch_app_rounded),
            onPressed: _game.interact,
          ),
        ],
      ),
      body: BlocBuilder<GameCubit, GameSession>(
        builder: (context, session) {
          final game = session.game;
          if (game == null) return const SizedBox.shrink();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(
                      icon: Icons.calendar_month_rounded,
                      label:
                          'Age ${GameCalendar.ageOn(game.profile.birthDate, game.day)}',
                    ),
                    InfoChip(
                      icon: Icons.location_on_rounded,
                      label: game.profile.currentCityId,
                    ),
                    InfoChip(
                      icon: Icons.bolt_rounded,
                      label: 'Energy ${game.stat('energy').round()}',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: GameWidget(game: _game)),
                    Positioned(
                      left: 18,
                      bottom: 22,
                      child: _MovePad(onMove: _game.nudge),
                    ),
                    Positioned(
                      right: 18,
                      bottom: 28,
                      child: FloatingActionButton.extended(
                        heroTag: 'world-interact',
                        icon: const Icon(Icons.touch_app_rounded),
                        label: const Text('Interact'),
                        onPressed: _game.interact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MovePad extends StatelessWidget {
  const _MovePad({required this.onMove});

  final void Function(Vector2 direction) onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Move up',
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          onPressed: () => onMove(Vector2(0, -1)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: 'Move left',
              icon: const Icon(Icons.keyboard_arrow_left_rounded),
              onPressed: () => onMove(Vector2(-1, 0)),
            ),
            IconButton.filledTonal(
              tooltip: 'Move down',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: () => onMove(Vector2(0, 1)),
            ),
            IconButton.filledTonal(
              tooltip: 'Move right',
              icon: const Icon(Icons.keyboard_arrow_right_rounded),
              onPressed: () => onMove(Vector2(1, 0)),
            ),
          ],
        ),
      ],
    );
  }
}
