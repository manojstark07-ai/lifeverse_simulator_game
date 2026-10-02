import 'package:flutter/material.dart';

import '../app/theme.dart';

bool _reduced(BuildContext context) => MediaQuery.of(context).disableAnimations;

/// The primary call-to-action: a gradient pill that gently compresses when
/// pressed. Use at most one per screen region.
class GradientButton extends StatefulWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[Icon(widget.icon, color: Colors.white, size: 20), const SizedBox(width: 10)],
        Flexible(
          child: Text(widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: LvFonts.ui, fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.white)),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _down && !_reduced(context) ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LvColors.primaryGradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: enabled
                  ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: widget.onPressed,
                onHighlightChanged: (v) => setState(() => _down = v),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 54),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LvDialogAction<T> {
  const LvDialogAction(this.label, this.value, {this.primary = false, this.destructive = false});

  final String label;
  final T value;
  final bool primary;
  final bool destructive;
}

/// A branded dialog: icon medallion, serif title, body and stacked actions.
Future<T?> showLvDialog<T>({
  required BuildContext context,
  required String title,
  Widget? body,
  String? message,
  IconData icon = Icons.auto_awesome_rounded,
  Color? accent,
  List<LvDialogAction<T>> actions = const [],
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: _reduced(context) ? Duration.zero : const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => _LvDialog<T>(
      title: title,
      body: body ?? (message == null ? null : Text(message, textAlign: TextAlign.center)),
      icon: icon,
      accent: accent,
      actions: actions,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _LvDialog<T> extends StatelessWidget {
  const _LvDialog({required this.title, this.body, required this.icon, this.accent, required this.actions});

  final String title;
  final Widget? body;
  final IconData icon;
  final Color? accent;
  final List<LvDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final color = accent ?? scheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Theme.of(context).dialogTheme.backgroundColor,
            borderRadius: BorderRadius.circular(LvRadii.sheet),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.08)]),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: Theme.of(context).dialogTheme.titleTextStyle),
                if (body != null) ...[
                  const SizedBox(height: 10),
                  DefaultTextStyle(style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center, child: body!),
                ],
                const SizedBox(height: 22),
                for (final a in actions)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: a.primary
                        ? GradientButton(label: a.label, onPressed: () => Navigator.of(context).pop(a.value))
                        : TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: a.destructive ? scheme.error : scheme.onSurfaceVariant,
                            ),
                            onPressed: () => Navigator.of(context).pop(a.value),
                            child: Text(a.label),
                          ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large selectable card with an animated gradient ring and check badge.
class SelectCard extends StatelessWidget {
  const SelectCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.footer,
    this.leading,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final String? footer;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final light = Theme.of(context).brightness == Brightness.light;
    final duration = _reduced(context) ? Duration.zero : const Duration(milliseconds: 200);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LvRadii.card),
            gradient: selected ? LvColors.primaryGradient : null,
            color: selected ? null : scheme.outlineVariant.withValues(alpha: 0.5),
            boxShadow: selected ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 6))] : null,
          ),
          child: Material(
            color: selected
                ? Color.alphaBlend(scheme.primary.withValues(alpha: light ? 0.06 : 0.14), Theme.of(context).cardTheme.color!)
                : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(LvRadii.card - 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(LvRadii.card - 2),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 14)],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: t.titleMedium),
                      if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: t.bodyMedium)],
                      if (footer != null) ...[const SizedBox(height: 10), Text(footer!, style: t.bodySmall)],
                    ]),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: duration,
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: selected
                        ? Container(
                            key: const ValueKey(true),
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LvColors.primaryGradient),
                            child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          )
                        : Container(
                            key: const ValueKey(false),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.outline, width: 1.6)),
                          ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round colour swatches with an animated check on the selected one.
class SwatchPicker extends StatelessWidget {
  const SwatchPicker({super.key, required this.label, required this.colors, required this.selected, required this.onPick});

  final String label;
  final List<Color> colors;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (var i = 0; i < colors.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            label: '$label option ${i + 1}',
            child: GestureDetector(
              onTap: () => onPick(i),
              child: AnimatedContainer(
                duration: _reduced(context) ? Duration.zero : const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: i == selected ? scheme.primary : Colors.transparent, width: 2.5),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: i == selected
                      ? Icon(Icons.check_rounded,
                          size: 18, color: colors[i].computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                      : null,
                ),
              ),
            ),
          ),
      ]),
    ]);
  }
}

/// A soft gradient panel for hero moments (headers, objectives, endings).
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LvColors.primaryGradient,
        borderRadius: BorderRadius.circular(LvRadii.card + 4),
        boxShadow: [
          BoxShadow(color: LvColors.violet.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
      ),
    );
  }
}
