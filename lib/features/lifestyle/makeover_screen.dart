import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/character/player_profile.dart';
import '../../engine/core/money.dart';
import '../../engine/lifestyle/lifestyle_service.dart';
import '../../shared/avatar.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

/// The salon chair: restyle hair, colour, outfit and accessories.
class MakeoverScreen extends StatefulWidget {
  const MakeoverScreen({super.key});

  @override
  State<MakeoverScreen> createState() => _MakeoverScreenState();
}

class _MakeoverScreenState extends State<MakeoverScreen> {
  late Appearance _look = context.read<GameCubit>().game.profile.appearance;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final s = cubit.game;
    final t = Theme.of(context).textTheme;
    final changed = _look.toJson().toString() != s.profile.appearance.toJson().toString();
    final affordable = s.finance.cash >= LifestyleService.makeoverCost;
    return Scaffold(
      appBar: AppBar(title: const Text('Salon makeover')),
      body: SafeArea(
        child: ListView(children: [
          ResponsiveBody(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Column(children: [
                  AvatarView(appearance: s.profile.appearance, size: 84),
                  const SizedBox(height: 4),
                  Text('Now', style: t.labelMedium),
                ]),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.arrow_forward_rounded)),
                Column(children: [
                  AvatarView(appearance: _look, size: 120),
                  const SizedBox(height: 4),
                  Text('New look', style: t.labelMedium),
                ]),
              ]),
              const SizedBox(height: 20),
              _chips('Hair style', AvatarPalette.hairStyles, _look.hairStyle, (i) => _look = _look.copyWith(hairStyle: i)),
              _swatches('Hair colour', AvatarPalette.hair, _look.hairColor, (i) => _look = _look.copyWith(hairColor: i)),
              _swatches('Outfit', AvatarPalette.outfit, _look.outfit, (i) => _look = _look.copyWith(outfit: i)),
              _chips('Accessory', AvatarPalette.accessories, _look.accessory, (i) => _look = _look.copyWith(accessory: i)),
              const SizedBox(height: 8),
              GradientButton(
                label: 'Book it — ${formatRupees(LifestyleService.makeoverCost)}',
                icon: Icons.content_cut_rounded,
                onPressed: changed && affordable
                    ? () {
                        cubit.makeover(_look);
                        context.pop();
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                !affordable
                    ? 'You need ${formatRupees(LifestyleService.makeoverCost)}.'
                    : 'A makeover uses one activity and lifts your looks and mood.',
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _swatches(String label, List<Color> colors, int selected, void Function(int) pick) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: SwatchPicker(label: label, colors: colors, selected: selected, onPick: (i) => setState(() => pick(i))),
      );

  Widget _chips(String label, List<String> options, int selected, void Function(int) pick) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, o) in options.indexed)
              ChoiceChip(label: Text(o), selected: i == selected, onSelected: (_) => setState(() => pick(i))),
          ]),
        ]),
      );
}
