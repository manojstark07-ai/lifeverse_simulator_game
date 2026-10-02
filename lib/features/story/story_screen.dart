import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/core/money.dart';
import '../../engine/story/story_engine.dart';
import '../../engine/story/story_models.dart';
import '../../app/theme.dart';
import '../../shared/avatar.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../puzzles/puzzle_session_screen.dart';

/// Presents the active story node. Owns navigation *out of* events: back to
/// the hub when an event ends, or to the conclusion when a chapter closes.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late final int _startChapter = context.read<GameCubit>().game.chapter;
  bool _leaving = false;

  void _checkEnded() {
    if (_leaving || !mounted) return;
    final game = context.read<GameCubit>().state.game;
    if (game == null || game.story.inEvent) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _leaving = true;
    if (game.chapter > _startChapter) {
      context.go('/conclusion');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/hub');
    }
  }

  Future<void> _launchChallenge() async {
    final cubit = context.read<GameCubit>();
    final view = cubit.engine.currentNode(cubit.game);
    final choice = view?.pendingChallenge;
    if (choice == null) return;
    final spec = choice.challenge!;
    final exam = spec.kind == ChallengeKind.exam ? cubit.content.exams[spec.examId] : null;
    await context.push('/puzzle',
        extra: PuzzleSessionArgs(
          mode: PuzzleMode.story,
          title: exam?.name ?? (spec.kind == ChallengeKind.interview ? 'Interview' : choice.label),
          puzzles: cubit.pendingPuzzles(),
          durationSec: exam?.durationSec,
          disclaimer: exam?.disclaimer,
          examId: exam?.id,
        ));
    _checkEnded();
  }

  Future<void> _choose(String id) async {
    final cubit = context.read<GameCubit>();
    cubit.choose(id);
    if (cubit.state.game?.story.pendingChallengeChoiceId != null) await _launchChallenge();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<GameCubit, GameSession>(
        listener: (context, _) => _checkEnded(),
        builder: (context, session) {
          final cubit = context.read<GameCubit>();
          final game = session.game;
          final view = game == null ? null : cubit.engine.currentNode(game);
          if (view == null) return const Scaffold(body: SizedBox.shrink());
          final c = cubit.content;
          final t = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;
          final npc = c.npcs[view.speakerId];
          final location = c.locations[view.event.location];
          final reduceMotion = MediaQuery.of(context).disableAnimations;
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(view.event.title),
              actions: [
                IconButton(tooltip: 'Save', icon: const Icon(Icons.save_rounded), onPressed: () => context.push('/saves')),
              ],
            ),
            body: SafeArea(
              child: ListView(children: [
                ResponsiveBody(
                  child: AnimatedSwitcher(
                    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
                    child: Column(
                      key: ValueKey('${view.event.id}/${view.node.id}/${game!.story.pendingChallengeChoiceId}'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (location != null) InfoChip(icon: Icons.place_rounded, label: location.name),
                          InfoChip(icon: Icons.menu_book_rounded, label: 'Chapter ${view.event.chapter}'),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          if (npc != null)
                            NpcPortrait(npc: npc, size: 52)
                          else if (view.speakerId == 'player')
                            AvatarView(appearance: game.profile.appearance, size: 52)
                          else
                            CircleAvatar(radius: 26, backgroundColor: scheme.secondaryContainer, child: const Icon(Icons.auto_stories_rounded)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(npc?.name ?? (view.speakerId == 'player' ? game.profile.name : 'Narrator'),
                                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              if (npc != null) Text(npc.role, style: t.bodySmall),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Card(
                          child: Stack(children: [
                            Positioned(
                              right: 14,
                              top: -6,
                              child: Text('”',
                                  style: TextStyle(
                                      fontFamily: LvFonts.display, fontSize: 96, height: 1, color: scheme.primary.withValues(alpha: 0.12))),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                              child: Text(view.text,
                                  style: TextStyle(fontFamily: LvFonts.display, fontSize: 18.5, height: 1.6, color: scheme.onSurface)),
                            ),
                          ]),
                        ),
                        if (view.lastOutcomes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _Outcomes(outcomes: view.lastOutcomes),
                        ],
                        const SizedBox(height: 16),
                        if (view.pendingChallenge != null)
                          GradientButton(
                            onPressed: _launchChallenge,
                            icon: Icons.extension_rounded,
                            label: 'Resume the challenge',
                          )
                        else if (view.node.isTerminal)
                          GradientButton(
                              label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: () => _choose(StoryEngine.continueId))
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10),
                            child: Text('WHAT DO YOU DO?',
                                style: t.labelSmall?.copyWith(letterSpacing: 1.6, fontWeight: FontWeight.w800, color: scheme.primary)),
                          ),
                          for (final (i, cv) in view.choices.indexed) _ChoiceCard(index: i, view: cv, onTap: () => _choose(cv.choice.id)),
                        ],
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Outcomes extends StatelessWidget {
  const _Outcomes({required this.outcomes});

  final List<String> outcomes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color tone(String o) {
      if (o.contains('+')) return const Color(0xFF2FA866);
      if (o.contains('−') || RegExp(r' -\d').hasMatch(o)) return scheme.error;
      return scheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text('What changed', style: Theme.of(context).textTheme.labelLarge),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final o in outcomes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: tone(o).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(o, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: tone(o))),
            ),
        ]),
      ]),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.index, required this.view, required this.onTap});

  final int index;
  final ChoiceView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ch = view.choice;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final costs = <(IconData, String)>[
      if (ch.cost.money > 0) (Icons.payments_rounded, formatRupees(-ch.cost.money)),
      if (ch.cost.energy > 0) (Icons.bolt_rounded, '−${ch.cost.energy.round()} energy'),
      if (ch.cost.days > 0) (Icons.schedule_rounded, '${ch.cost.days} day${ch.cost.days == 1 ? '' : 's'}'),
      if (ch.challenge != null)
        switch (ch.challenge!.kind) {
          ChallengeKind.exam => (Icons.edit_note_rounded, 'Exam'),
          ChallengeKind.interview => (Icons.record_voice_over_rounded, 'Interview'),
          _ => (Icons.extension_rounded, 'Puzzle'),
        },
    ];
    final enabled = view.enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: Theme.of(context).cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: enabled ? scheme.primary.withValues(alpha: 0.28) : scheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: enabled ? LvColors.primaryGradient : null,
                    color: enabled ? null : scheme.outlineVariant,
                  ),
                  child: enabled
                      ? Text(String.fromCharCode(65 + index),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
                      : const Icon(Icons.lock_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ch.label, style: t.titleSmall?.copyWith(fontSize: 15.5, height: 1.35)),
                    if (ch.hint != null) ...[const SizedBox(height: 4), Text(ch.hint!, style: t.bodySmall)],
                    if (view.lockReason != null) ...[
                      const SizedBox(height: 6),
                      Text(view.lockReason!, style: t.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600)),
                    ],
                    if (costs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final (icon, label) in costs)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(icon, size: 14, color: scheme.primary),
                              const SizedBox(width: 4),
                              Text(label, style: t.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                      ]),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
