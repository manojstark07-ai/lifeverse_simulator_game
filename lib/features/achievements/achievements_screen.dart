import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/core/game_calendar.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final s = cubit.game;
    final all = cubit.content.achievements.values.toList();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Achievements · ${s.achievements.length}/${all.length}')),
      body: SafeArea(
        child: ListView(children: [
          ResponsiveBody(
            child: Column(children: [
              for (final a in all)
                Builder(builder: (context) {
                  final day = s.achievements[a.id];
                  final secret = a.hidden && day == null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(day != null ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                          color: day != null ? const Color(0xFFE0A21B) : scheme.outline),
                      title: Text(secret ? 'Hidden achievement' : a.title),
                      subtitle: Text(secret ? 'Keep living to discover it.' : (day == null ? a.description : '${a.description}\nUnlocked ${GameCalendar.formatDay(day)}')),
                    ),
                  );
                }),
            ]),
          ),
        ]),
      ),
    );
  }
}
