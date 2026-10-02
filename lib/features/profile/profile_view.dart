import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../engine/character/stats.dart';
import '../../shared/avatar.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import '../game/selectors.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameSession>(builder: (context, session) {
      final s = session.game;
      if (s == null) return const SizedBox.shrink();
      final c = context.read<GameCubit>().content;
      final t = Theme.of(context).textTheme;
      final p = s.profile;
      return ListView(children: [
        ResponsiveBody(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: AvatarView(appearance: p.appearance, size: 120)),
            const SizedBox(height: 8),
            Text(p.name, textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('${p.pronouns} · ${ageOf(s)} · from ${c.hometowns[p.hometownId]!.name}', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Who you are',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Background: ${c.backgrounds[p.backgroundId]!.name}'),
                Text('Traits: ${p.traitIds.map((x) => c.traits[x]!.name).join(', ')}'),
                if (p.interestIds.isNotEmpty) Text('Interests: ${p.interestIds.map((x) => c.interests[x]!.name).join(', ')}'),
                Text('Life goal: ${c.ambitions[p.ambitionId]!.name}'),
                if (s.education.completedPrograms.isNotEmpty)
                  Text('Qualifications: ${s.education.completedPrograms.map((x) => c.programs[x]!.shortName).join(', ')}'),
                if (s.career.history.isNotEmpty) Text('Work history: ${s.career.history.join(' → ')}'),
                if (s.possessions.isNotEmpty)
                  Text('Owns: ${s.possessions.map((o) => c.shopItems[o.itemId]?.name ?? o.itemId).join(', ')}'),
                if (s.creator != null) Text('Channel: "${s.creator!.channelName}" on ViewTube'),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Attributes',
              child: Column(children: [
                for (final k in StatKeys.all)
                  StatBar(label: StatKeys.labels[k]!, value: s.stat(k), color: LvColors.stat[k], icon: statIcons[k]),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Skills',
              child: Column(children: [
                for (final k in SkillKeys.all) StatBar(label: SkillKeys.labels[k]!, value: s.skill(k)),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Knowledge is learned, not fixed: it grows with study, practice and rest.', style: t.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ]);
    });
  }
}
