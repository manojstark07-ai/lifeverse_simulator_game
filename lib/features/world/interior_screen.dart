import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/actions/daily_action.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../hub/action_tile.dart';
import 'interior_game.dart';

class InteriorScreen extends StatefulWidget {
  const InteriorScreen({super.key, required this.locationId});

  final String locationId;

  @override
  State<InteriorScreen> createState() => _InteriorScreenState();
}

class _InteriorScreenState extends State<InteriorScreen> {
  late final InteriorGame _game;

  @override
  void initState() {
    super.initState();
    _game = InteriorGame(
      kind: widget.locationId,
      reducedMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
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
        title: Text(
          context
                  .read<GameCubit>()
                  .content
                  .locations[widget.locationId]
                  ?.name ??
              widget.locationId,
        ),
      ),
      body: BlocBuilder<GameCubit, GameSession>(
        builder: (context, session) {
          final state = session.game;
          if (state == null) return const SizedBox.shrink();
          final cubit = context.read<GameCubit>();
          final actions = cubit.engine.actionsAt(state, widget.locationId);
          return ListView(
            children: [
              SizedBox(height: 270, child: GameWidget(game: _game)),
              ResponsiveBody(
                child: SectionCard(
                  title: 'Activities',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (actions.isEmpty)
                        const EmptyNote(
                          'The room is open, but there is no scheduled activity here today.',
                        ),
                      for (final DailyAction action in actions)
                        ActionTile(action: action),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
