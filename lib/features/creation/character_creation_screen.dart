import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/character/character_factory.dart';
import '../../engine/character/player_profile.dart';
import '../../app/theme.dart';
import '../../engine/core/money.dart';
import '../../shared/avatar.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../settings/settings_cubit.dart';

/// Five steps: identity & look → roots → personality → life goal → review.
class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({super.key, this.newLifePlus = false});

  final bool newLifePlus;

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  static const _titles = [
    'Who are you?',
    'Where are you from?',
    'What are you like?',
    'What matters most?',
    'Ready?',
  ];

  int _step = 0;
  final _name = TextEditingController();
  String _pronouns = 'they/them';
  Appearance _look = const Appearance();
  String? _hometown;
  String? _background;
  final Set<String> _traits = {};
  final Set<String> _interests = {};
  String? _ambition;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => switch (_step) {
    0 => _name.text.trim().isNotEmpty,
    1 => _hometown != null && _background != null,
    2 => _traits.isNotEmpty,
    3 => _ambition != null,
    _ => true,
  };

  void _begin() {
    final cubit = context.read<GameCubit>();
    final spec = CharacterSpec(
      name: _name.text.trim(),
      pronouns: _pronouns,
      appearance: _look,
      hometownId: _hometown!,
      backgroundId: _background!,
      traitIds: _traits.toList(),
      interestIds: _interests.toList(),
      ambitionId: _ambition!,
      seed: math.Random().nextInt(0x7FFFFFFF),
      matureThemes: context.read<SettingsCubit>().state.matureThemes,
    );
    if (widget.newLifePlus && cubit.state.hasGame) {
      cubit.startNewLifePlus(spec);
    } else {
      cubit.startNewLife(spec);
    }
    if (cubit.state.hasGame) context.go('/hub');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_step]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                for (var i = 0; i < _titles.length; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: i <= _step ? LvColors.primaryGradient : null,
                        color: i <= _step
                            ? null
                            : Theme.of(context).colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveBody(
            child: switch (_step) {
              0 => _identity(),
              1 => _roots(),
              2 => _personality(),
              3 => _goal(),
              _ => _review(),
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GradientButton(
                  onPressed: !_valid
                      ? null
                      : (_step == _titles.length - 1
                            ? _begin
                            : () => setState(() => _step++)),
                  label: _step == _titles.length - 1
                      ? (widget.newLifePlus
                            ? 'Begin New Life+'
                            : 'Begin life at 18')
                      : 'Next',
                  icon: _step == _titles.length - 1
                      ? Icons.auto_awesome_rounded
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ steps --

  Widget _identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LvColors.primaryGradient,
            ),
            child: AvatarView(appearance: _look, size: 148),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text('Pronouns', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'she/her', label: Text('she/her')),
            ButtonSegment(value: 'he/him', label: Text('he/him')),
            ButtonSegment(value: 'they/them', label: Text('they/them')),
          ],
          selected: {_pronouns},
          onSelectionChanged: (v) => setState(() => _pronouns = v.first),
        ),
        const SizedBox(height: 20),
        _swatches(
          'Skin tone',
          AvatarPalette.skin,
          _look.skinTone,
          (i) => _look = _look.copyWith(skinTone: i),
        ),
        _chips(
          'Hair style',
          AvatarPalette.hairStyles,
          _look.hairStyle,
          (i) => _look = _look.copyWith(hairStyle: i),
        ),
        _swatches(
          'Hair colour',
          AvatarPalette.hair,
          _look.hairColor,
          (i) => _look = _look.copyWith(hairColor: i),
        ),
        _swatches(
          'Outfit',
          AvatarPalette.outfit,
          _look.outfit,
          (i) => _look = _look.copyWith(outfit: i),
        ),
        _chips(
          'Expression',
          AvatarPalette.expressions,
          _look.expression,
          (i) => _look = _look.copyWith(expression: i),
        ),
        _chips(
          'Accessory',
          AvatarPalette.accessories,
          _look.accessory,
          (i) => _look = _look.copyWith(accessory: i),
        ),
      ],
    );
  }

  Widget _swatches(
    String label,
    List<Color> colors,
    int selected,
    void Function(int) pick,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: SwatchPicker(
      label: label,
      colors: colors,
      selected: selected,
      onPick: (i) => setState(() => pick(i)),
    ),
  );

  Widget _chips(
    String label,
    List<String> options,
    int selected,
    void Function(int) pick,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                ChoiceChip(
                  label: Text(options[i]),
                  selected: i == selected,
                  onSelected: (_) => setState(() => pick(i)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roots() {
    final c = context.read<GameCubit>().content;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hometown',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final h in c.hometowns.values)
          SelectCard(
            selected: _hometown == h.id,
            onTap: () => setState(() => _hometown = h.id),
            title: h.name,
            subtitle: h.description,
            footer:
                'Living costs from ${formatRupees(h.livingCostMonthly)}/month · wages ×${h.wageMultiplier}',
          ),
        const SizedBox(height: 16),
        Text(
          'Family background',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Background shapes your resources, obligations and opportunities — never your ability.',
          style: t.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final b in c.backgrounds.values)
          SelectCard(
            selected: _background == b.id,
            onTap: () => setState(() => _background = b.id),
            title: b.name,
            subtitle: b.description,
            footer:
                'Savings ${formatRupees(b.startingCash)} · family support ${formatRupees(b.familySupportMonthly)}/month\n'
                '+ ${b.opportunities.join(' · ')}\n− ${b.obligations.join(' · ')}',
          ),
      ],
    );
  }

  Widget _personality() {
    final c = context.read<GameCubit>().content;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Traits (choose up to ${CharacterFactory.maxTraits})',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final tr in c.traits.values)
          SelectCard(
            selected: _traits.contains(tr.id),
            onTap: () => setState(() {
              if (!_traits.remove(tr.id) &&
                  _traits.length < CharacterFactory.maxTraits)
                _traits.add(tr.id);
            }),
            title: tr.name,
            subtitle: tr.description,
          ),
        const SizedBox(height: 16),
        Text(
          'Interests (up to ${CharacterFactory.maxInterests})',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in c.interests.values)
              FilterChip(
                label: Text(i.name),
                selected: _interests.contains(i.id),
                onSelected: (on) => setState(() {
                  if (!on) {
                    _interests.remove(i.id);
                  } else if (_interests.length <
                      CharacterFactory.maxInterests) {
                    _interests.add(i.id);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _goal() {
    final c = context.read<GameCubit>().content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'There is no single way to win. Your life goal colours your story and how you will judge it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final a in c.ambitions.values)
          SelectCard(
            selected: _ambition == a.id,
            onTap: () => setState(() => _ambition = a.id),
            title: a.name,
            subtitle: a.description,
          ),
      ],
    );
  }

  Widget _review() {
    final c = context.read<GameCubit>().content;
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        AvatarView(appearance: _look, size: 128),
        const SizedBox(height: 12),
        Text(
          _name.text.trim(),
          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          '$_pronouns · 18 · ${c.hometowns[_hometown]!.name}',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Your starting point',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.backgrounds[_background]!.name, style: t.titleSmall),
              const SizedBox(height: 4),
              Text(c.backgrounds[_background]!.description),
              const SizedBox(height: 12),
              Text(
                'Traits: ${_traits.map((x) => c.traits[x]!.name).join(', ')}',
              ),
              if (_interests.isNotEmpty)
                Text(
                  'Interests: ${_interests.map((x) => c.interests[x]!.name).join(', ')}',
                ),
              Text('Life goal: ${c.ambitions[_ambition]!.name}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'It is June 2026. School results are out today.',
          style: t.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
