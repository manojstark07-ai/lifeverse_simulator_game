import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/core/game_calendar.dart';
import '../../engine/household/household_models.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

class PeopleView extends StatelessWidget {
  const PeopleView({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameSession>(builder: (context, session) {
      final s = session.game;
      if (s == null) return const SizedBox.shrink();
      final c = context.read<GameCubit>().content;
      final t = Theme.of(context).textTheme;
      final met = s.relationships.values.where((r) => r.met).toList();
      final unmet = s.relationships.values.where((r) => !r.met).length;
      return ListView(children: [
        ResponsiveBody(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (showHeading) ...[
              Text('People', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
            ],
            Text('Relationships grow through time, honesty and showing up — not gifts.', style: t.bodyMedium),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final h = s.household;
              final partner = c.npcs[h.partnerId];
              return SectionCard(
                title: 'Family & love',
                trailing: InfoChip(icon: Icons.favorite_rounded, label: PartnerStatus.labels[h.status] ?? h.status),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (partner != null && h.hasPartner)
                    Row(children: [
                      NpcPortrait(npc: partner, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          h.isMarried
                              ? 'Married to ${partner.name} since ${GameCalendar.formatDay(h.marriedDay ?? s.day)}.'
                              : '${PartnerStatus.labels[h.status]} ${partner.name} since ${GameCalendar.formatDay(h.sinceDay ?? s.day)}.',
                        ),
                      ),
                    ])
                  else
                    Text(h.divorces > 0 ? 'Single again.' : 'Single. Love, if you want it, finds its own time.'),
                  if (h.children.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Children', style: t.labelLarge),
                    for (final child in h.children)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.child_care_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text('${child.name}, ${child.ageOn(s.day) == 0 ? 'under a year' : '${child.ageOn(s.day)}'}'),
                        ]),
                      ),
                  ],
                  if (h.hasPartner) ...[
                    const SizedBox(height: 8),
                    Text('Date nights at the mall, road trips and family time in your routine keep the bond strong.',
                        style: t.bodySmall),
                  ],
                ]),
              );
            }),
            const SizedBox(height: 12),
            for (final r in met) ...[
              Builder(builder: (context) {
                final npc = c.npcs[r.npcId]!;
                return SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      NpcPortrait(npc: npc, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(npc.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(npc.role, style: t.bodySmall),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(npc.bio),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final p in npc.personality) Chip(label: Text(p), visualDensity: VisualDensity.compact),
                    ]),
                    const SizedBox(height: 8),
                    StatBar(label: 'Closeness', value: r.affinity, min: -100, color: const Color(0xFFD9546E), icon: Icons.favorite_rounded),
                    StatBar(label: 'Trust', value: r.trust, color: const Color(0xFF5B6CE0), icon: Icons.handshake_rounded),
                    StatBar(label: 'Tension', value: r.conflict, color: const Color(0xFF8A8A9A), icon: Icons.bolt_outlined),
                    Text('Last time together: ${GameCalendar.formatDay(r.lastInteractionDay)}', style: t.bodySmall),
                    if (r.memories.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('${npc.name.split(' ').first} remembers', style: t.labelLarge),
                      for (final m in r.memories.reversed)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(m.weight >= 0 ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text('${m.text} (${GameCalendar.formatDay(m.day)})', style: t.bodySmall)),
                          ]),
                        ),
                    ],
                  ]),
                );
              }),
              const SizedBox(height: 12),
            ],
            if (unmet > 0) EmptyNote('$unmet ${unmet == 1 ? 'person' : 'people'} you haven\'t met yet.', icon: Icons.person_search_rounded),
          ]),
        ),
      ]);
    });
  }
}
