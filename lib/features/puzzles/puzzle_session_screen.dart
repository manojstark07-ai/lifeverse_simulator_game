import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../engine/puzzles/puzzle.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

enum PuzzleMode { story, practice, mock, interview }

class PuzzleSessionArgs {
  const PuzzleSessionArgs({
    required this.mode,
    required this.title,
    required this.puzzles,
    this.durationSec,
    this.disclaimer,
    this.examId,
    this.careerId,
  });

  final PuzzleMode mode;
  final String title;
  final List<Puzzle> puzzles;

  /// Whole-session time limit; defaults to the sum of per-puzzle limits.
  final int? durationSec;
  final String? disclaimer;
  final String? examId;

  /// For job-portal interviews.
  final String? careerId;
}

/// Runs a timed set of puzzles, submits the result to the engine once, then
/// shows a review with an explanation for every question.
class PuzzleSessionScreen extends StatefulWidget {
  const PuzzleSessionScreen({super.key, required this.args});

  final PuzzleSessionArgs args;

  @override
  State<PuzzleSessionScreen> createState() => _PuzzleSessionScreenState();
}

class _PuzzleSessionScreenState extends State<PuzzleSessionScreen> {
  late final List<Puzzle> _puzzles = widget.args.puzzles;
  late final Map<String, TextEditingController> _numeric = {
    for (final p in _puzzles.where((p) => p.type == PuzzleType.numeric)) p.id: TextEditingController(),
  };
  final Map<String, int> _choice = {};
  final Map<String, int> _seconds = {};
  late int _remaining = widget.args.durationSec ?? _puzzles.fold(0, (a, p) => a + p.timeLimitSec);
  int _index = 0;
  Timer? _timer;
  ChallengeResult? _result;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _result != null) return;
      setState(() {
        _remaining--;
        _seconds[_puzzles[_index].id] = (_seconds[_puzzles[_index].id] ?? 0) + 1;
      });
      if (_remaining <= 0) _submit();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _numeric.values) {
      c.dispose();
    }
    super.dispose();
  }

  Object? _response(Puzzle p) {
    if (p.type == PuzzleType.mcq) return _choice[p.id];
    final text = _numeric[p.id]!.text.trim();
    return text.isEmpty ? null : text;
  }

  int get _answered => _puzzles.where((p) => _response(p) != null).length;

  void _submit() {
    if (_result != null) return;
    _timer?.cancel();
    final result = ChallengeResult([
      for (final p in _puzzles)
        PuzzleAnswer(puzzleId: p.id, response: _response(p), correct: p.check(_response(p)), secondsTaken: _seconds[p.id] ?? 0),
    ]);
    final cubit = context.read<GameCubit>();
    switch (widget.args.mode) {
      case PuzzleMode.story:
        cubit.resolveChallenge(result);
      case PuzzleMode.practice:
        cubit.recordPractice(result);
      case PuzzleMode.mock:
        cubit.recordPractice(result, mockExamId: widget.args.examId);
      case PuzzleMode.interview:
        cubit.applyForJob(widget.args.careerId!, result);
    }
    setState(() => _result = result);
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _puzzles.length - _answered;
    final ok = await showLvDialog<bool>(
      context: context,
      icon: Icons.task_alt_rounded,
      title: 'Submit your answers?',
      message: unanswered == 0
          ? 'You have answered every question.'
          : '$unanswered question${unanswered == 1 ? ' is' : 's are'} unanswered and will count as skipped.',
      actions: const [LvDialogAction('Submit', true, primary: true), LvDialogAction('Keep working', false)],
    );
    if (ok == true) _submit();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _result != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmSubmit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.args.title),
          automaticallyImplyLeading: _result != null,
          actions: [
            if (_result == null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: InfoChip(
                    icon: Icons.timer_rounded,
                    label: '${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}',
                    color: _remaining < 30 ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(child: _result == null ? _session() : _review(_result!)),
      ),
    );
  }

  Widget _session() {
    final p = _puzzles[_index];
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final parts = p.prompt.split('\n\n');
    return Column(children: [
      LinearProgressIndicator(value: (_index + 1) / _puzzles.length),
      Expanded(
        child: ListView(children: [
          ResponsiveBody(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.args.disclaimer != null && _index == 0) ...[
                EmptyNote(widget.args.disclaimer!, icon: Icons.verified_user_outlined),
                const SizedBox(height: 8),
              ],
              Text('Question ${_index + 1} of ${_puzzles.length}', style: t.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                InfoChip(icon: Icons.category_rounded, label: PuzzleCategory.all[p.category] ?? p.category),
                InfoChip(icon: Icons.signal_cellular_alt_rounded, label: ['Warm-up', 'Standard', 'Hard'][p.difficulty - 1]),
              ]),
              const SizedBox(height: 16),
              if (p.passage != null)
                Card(
                  color: scheme.secondaryContainer.withValues(alpha: 0.5),
                  child: Padding(padding: const EdgeInsets.all(16), child: Text(p.passage!, style: t.bodyLarge?.copyWith(height: 1.5))),
                ),
              if (p.passage != null) const SizedBox(height: 12),
              Text(parts.first, style: t.titleMedium?.copyWith(height: 1.4)),
              for (final code in parts.skip(1)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.4)),
                ),
              ],
              const SizedBox(height: 20),
              if (p.type == PuzzleType.mcq)
                for (var i = 0; i < p.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      selected: _choice[p.id] == i,
                      button: true,
                      child: Material(
                        color: _choice[p.id] == i ? scheme.primary.withValues(alpha: 0.1) : Theme.of(context).cardTheme.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _choice[p.id] == i ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6),
                            width: _choice[p.id] == i ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _choice[p.id] = i),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: _choice[p.id] == i ? scheme.primary : scheme.surfaceContainerHighest,
                                child: Text(String.fromCharCode(65 + i),
                                    style: TextStyle(color: _choice[p.id] == i ? scheme.onPrimary : scheme.onSurface)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(p.options[i], style: t.bodyLarge)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  )
              else
                TextField(
                  controller: _numeric[p.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                  decoration: InputDecoration(
                    labelText: 'Your answer',
                    suffixText: p.unit,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
            ]),
          ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            if (_index > 0) OutlinedButton(onPressed: () => setState(() => _index--), child: const Text('Previous')),
            const Spacer(),
            if (_index < _puzzles.length - 1)
              FilledButton(
                onPressed: () => setState(() => _index++),
                child: Text(_response(p) == null ? 'Skip' : 'Next'),
              )
            else
              GradientButton(onPressed: _confirmSubmit, label: 'Submit', expand: false, icon: Icons.task_alt_rounded),
          ]),
        ),
      ),
    ]);
  }

  Widget _review(ChallengeResult r) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<GameCubit>();
    final attempt = widget.args.examId == null || widget.args.mode != PuzzleMode.story
        ? null
        : cubit.state.game?.exams[widget.args.examId]?.latest;
    final exam = widget.args.examId == null ? null : cubit.content.exams[widget.args.examId];
    return ListView(children: [
      ResponsiveBody(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionCard(
            title: 'Result',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.correct} correct · ${r.wrong} wrong · ${r.skipped} skipped', style: t.titleMedium),
              if (attempt != null && exam != null) ...[
                const SizedBox(height: 8),
                Text('Paper: ${attempt.performancePct.toStringAsFixed(0)}% · Preparation: ${attempt.preparationIndex.toStringAsFixed(0)}'),
                Text('Final score: ${attempt.composite.toStringAsFixed(1)} — ${exam.tiers.firstWhere((x) => x.id == attempt.tierId).label}',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
              if (widget.args.mode == PuzzleMode.practice)
                const Text('Learning rewards are given the first time you solve each puzzle.'),
              if (widget.args.mode == PuzzleMode.interview) ...[
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final game = cubit.state.game;
                  final hired = game?.career.careerId == widget.args.careerId;
                  final career = cubit.content.careers[widget.args.careerId];
                  return Text(
                    hired
                        ? 'Offer accepted: ${career?.ladder.first.title}${game?.career.employer == null ? '' : ' at ${game!.career.employer}'}.'
                        : 'No offer this time. Practise, build your skills and reapply in a month.',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  );
                }),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          for (final (i, a) in r.answers.indexed) ...[
            _ReviewCard(index: i, puzzle: _puzzles[i], answer: a, scheme: scheme),
            const SizedBox(height: 10),
          ],
          GradientButton(onPressed: () => context.pop(), label: 'Continue', icon: Icons.arrow_forward_rounded),
        ]),
      ),
    ]);
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.index, required this.puzzle, required this.answer, required this.scheme});

  final int index;
  final Puzzle puzzle;
  final PuzzleAnswer answer;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final given = answer.response == null
        ? 'Skipped'
        : (puzzle.type == PuzzleType.mcq ? puzzle.options[answer.response! as int] : '${answer.response}');
    final color = answer.correct ? const Color(0xFF3C8F55) : (answer.skipped ? scheme.outline : scheme.error);
    return SectionCard(
      title: 'Q${index + 1}. ${puzzle.prompt.split('\n').first}',
      trailing: Icon(answer.correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your answer: $given', style: t.bodyMedium?.copyWith(color: color)),
        if (!answer.correct) Text('Correct answer: ${puzzle.answerText}', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(puzzle.explanation, style: t.bodyMedium?.copyWith(height: 1.45)),
      ]),
    );
  }
}
