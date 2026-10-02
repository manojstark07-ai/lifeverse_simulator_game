import '../engine_context.dart';

class RelationshipService {
  const RelationshipService._();

  /// Monthly drift: routine time keeps bonds warm; neglect cools them;
  /// unresolved tension slowly fades.
  static void settleMonth(EngineContext ctx, {required double familyHours, required double socialHours}) {
    final s = ctx.s;
    for (final r in s.relationships.values) {
      if (!r.met) continue;
      final npc = ctx.c.npcs[r.npcId];
      if (npc == null) continue;
      // A partner is kept close by social time; a fiancé(e) or spouse by
      // family time.
      final h = s.household;
      final bond = r.npcId == h.partnerId && h.hasPartner
          ? (h.status == 'dating' ? 'social' : 'family')
          : npc.routineBond;

      final weeklyHours = switch (bond) {
        'family' => familyHours,
        'social' => socialHours,
        _ => 0.0,
      };
      final isPartner = r.npcId == h.partnerId && h.hasPartner;
      if (weeklyHours >= 3) {
        // Time together deepens a romance faster than a friendship.
        final rate = isPartner ? 0.3 : (npc.isFamily ? 0.12 : 0.08);
        r.affinity = (r.affinity + weeklyHours * rate).clamp(-100, 100).toDouble();
        if (isPartner) r.trust = (r.trust + 0.5).clamp(0, 100).toDouble();
        r.lastInteractionDay = s.day;
      } else if (s.day - r.lastInteractionDay > 30 && r.affinity > 0) {
        r.affinity = (r.affinity - (npc.isFamily ? 0.6 : 1.5)).clamp(-100, 100).toDouble();
      }
      r.conflict = (r.conflict - 2).clamp(0, 100).toDouble();
    }
  }
}
