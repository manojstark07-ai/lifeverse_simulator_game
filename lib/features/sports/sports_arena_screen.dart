import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

class SportsArenaScreen extends StatefulWidget {
  const SportsArenaScreen({super.key});

  @override
  State<SportsArenaScreen> createState() => _SportsArenaScreenState();
}

class _SportsArenaScreenState extends State<SportsArenaScreen> {
  static const sports = ['Football', 'Cricket', 'Basketball'];
  Timer? _timer;
  int _round = 0;
  int _hits = 0;
  double _phase = 0;
  bool _playing = false;
  bool _finished = false;
  String _sport = sports.first;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _round = 0;
      _hits = 0;
      _phase = 0;
      _playing = true;
      _finished = false;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || !_playing) return;
      setState(() => _phase += 0.09);
    });
  }

  void _hit() {
    if (!_playing) return;
    final alignment = (math.sin(_phase) + 1) / 2;
    final sweetSpot = (math.sin(_phase * 1.9) + 1) / 2;
    if ((alignment - sweetSpot).abs() < 0.28) _hits++;
    _round++;
    if (_round >= 8) {
      _timer?.cancel();
      final score = (_hits / 8 * 100).round();
      setState(() {
        _playing = false;
        _finished = true;
      });
      context.read<GameCubit>().recordSportsSession(_sport, score);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = (_hits / 8 * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Sports career')),
      body: SafeArea(
        child: ListView(
          children: [
            ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EmptyNote(
                    'Build a sports path through timing, practice and repeat performances. Each session costs energy and can open a fictional athlete route.',
                    icon: Icons.sports_soccer_rounded,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: [
                      for (final sport in sports)
                        ButtonSegment(value: sport, label: Text(sport)),
                    ],
                    selected: {_sport},
                    onSelectionChanged: _playing
                        ? null
                        : (value) => setState(() => _sport = value.first),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: _playing
                        ? 'Round ${_round + 1} of 8'
                        : (_finished ? 'Session complete' : 'Timing drill'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _playing
                              ? 'Wait for the moving markers to line up, then use the control.'
                              : 'Tap through eight timing moments. Better rhythm means a better performance.',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    _sport == 'Cricket'
                                        ? Icons.sports_cricket_rounded
                                        : _sport == 'Basketball'
                                        ? Icons.sports_basketball_rounded
                                        : Icons.sports_soccer_rounded,
                                    size: 72,
                                    color: scheme.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment(
                                    -1 + 2 * ((math.sin(_phase) + 1) / 2),
                                    -0.25,
                                  ),
                                  child: _Marker(
                                    color: scheme.primary,
                                    label: 'BALL',
                                  ),
                                ),
                                Align(
                                  alignment: Alignment(
                                    -1 + 2 * ((math.sin(_phase * 1.9) + 1) / 2),
                                    0.35,
                                  ),
                                  child: _Marker(
                                    color: scheme.tertiary,
                                    label: 'WINDOW',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_finished) ...[
                          Text(
                            '$score/100 performance · $_hits clean timings',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                        ],
                        FilledButton.icon(
                          onPressed: _playing ? _hit : _start,
                          icon: Icon(
                            _playing
                                ? Icons.ads_click_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            _playing
                                ? 'Play move'
                                : (_finished ? 'Play again' : 'Start drill'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12),
      ],
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
