import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../engine/character/stats.dart';
import '../engine/relationships/relationship_models.dart';

/// Centers content and caps its width so tablets get a readable column.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final light = Theme.of(context).brightness == Brightness.light;
    final reduced = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.98, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LvRadii.card),
          boxShadow: light
              ? [
                  BoxShadow(
                    color: const Color(0xFF151719).withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Card(
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (trailing != null)
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: trailing,
                            ),
                          ),
                      ],
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ThreatMeter extends StatelessWidget {
  const ThreatMeter({super.key, required this.heat});

  final int heat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = (heat / 10).clamp(0.0, 1.0);
    final color = heat >= 7
        ? scheme.error
        : (heat >= 3 ? LvColors.amber : scheme.primary);
    return Semantics(
      label: 'Heat level $heat',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(LvRadii.control),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_police_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  'Heat',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: color),
                ),
                const Spacer(),
                Text(
                  '$heat/10',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Container(height: 9, color: color.withValues(alpha: 0.16)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 9,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.7), color],
                          ),
                        ),
                      ),
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

/// A labelled 0..max bar, used for stats, skills and relationships.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 100,
    this.min = 0,
    this.color,
    this.icon,
    this.valueText,
  });

  final String label;
  final double value;
  final double max;
  final double min;
  final Color? color;
  final IconData? icon;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Semantics(
      label: '$label ${valueText ?? value.round()}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 112,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(height: 10, color: c.withValues(alpha: 0.14)),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [c.withValues(alpha: 0.75), c],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 40,
              child: Text(
                valueText ?? value.round().toString(),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const statIcons = {
  StatKeys.knowledge: Icons.menu_book_rounded,
  StatKeys.discipline: Icons.fitness_center_rounded,
  StatKeys.communication: Icons.forum_rounded,
  StatKeys.wellbeing: Icons.spa_rounded,
  StatKeys.energy: Icons.bolt_rounded,
  StatKeys.health: Icons.favorite_rounded,
  StatKeys.looks: Icons.content_cut_rounded,
  StatKeys.fame: Icons.star_rounded,
};

/// Circular portrait for story characters (initials on their accent colour).
class NpcPortrait extends StatelessWidget {
  const NpcPortrait({super.key, required this.npc, this.size = 48});

  final Npc npc;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = LvColors.npc[npc.colorIndex % LvColors.npc.length];
    final initials = npc.name
        .replaceAll(RegExp(r'\(.*\)|Mr\. '), '')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join();
    return Semantics(
      label: npc.name,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: color,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
