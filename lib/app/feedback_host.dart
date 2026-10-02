import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../engine/core/game_calendar.dart';
import '../engine/core/money.dart';
import '../engine/game_events.dart';
import '../features/game/game_cubit.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Turns engine events into UI feedback in exactly one place: toasts for
/// notices and achievements, and a summary for each settled month.
/// (Navigation into story events is owned by the hub, and out of them by the
/// story screen, so the two can never race.)
class FeedbackHost extends StatelessWidget {
  const FeedbackHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameSession>(
      listener: (context, session) {
        final cubit = context.read<GameCubit>();
        final error = session.error;
        if (error != null) {
          _toast(error, warning: true);
          cubit.clearError();
        }
        if (session.feedback.isEmpty) return;
        final events = cubit.takeFeedback();
        for (final e in events) {
          switch (e) {
            case Notice(:final text, :final warning):
              _toast(text, warning: warning);
            case AchievementUnlocked(:final achievementId):
              final a = cubit.content.achievements[achievementId];
              _toast('Achievement unlocked: ${a?.title ?? achievementId}', icon: Icons.emoji_events_rounded);
            case MonthSettled():
              _toast(
                '${GameCalendar.formatMonthKey(e.monthKey)}: ${formatRupees(e.income, signed: true)} in, ${formatRupees(-e.expenses)} out',
                icon: Icons.calendar_month_rounded,
                action: SnackBarAction(label: 'Details', onPressed: () => _showMonth(e)),
              );
            case StoryEventStarted() || ChapterConcluded():
              break;
            case DecisionOutcome(:final title, :final outcomes, :final shownInline):
              // Story outcomes are rendered inline; activities get a toast.
              if (!shownInline && outcomes.isNotEmpty) {
                _toast('$title: ${outcomes.take(3).join(' · ')}', icon: Icons.check_circle_rounded);
              }
          }
        }
      },
      child: child,
    );
  }

  void _toast(String text, {bool warning = false, IconData? icon, SnackBarAction? action}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final ctx = scaffoldMessengerKey.currentContext!;
    final scheme = Theme.of(ctx).colorScheme;
    final fg = warning ? scheme.onErrorContainer : Theme.of(ctx).snackBarTheme.contentTextStyle!.color!;
    final accent = warning ? scheme.error : const Color(0xFFFFB199);
    messenger.showSnackBar(SnackBar(
      backgroundColor: warning ? scheme.errorContainer : null,
      action: action,
      // Flutter defaults `persist` to true when an action is set; toasts should always time out.
      persist: false,
      content: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.2)),
          child: Icon(icon ?? (warning ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded), color: accent, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: fg))),
      ]),
    ));
  }

  void _showMonth(MonthSettled e) {
    final ctx = scaffoldMessengerKey.currentContext;
    if (ctx == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('${GameCalendar.formatMonthKey(e.monthKey)} — month summary', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final line in e.lines) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(line)),
            const Divider(height: 24),
            Text('Net: ${formatRupees(e.income - e.expenses, signed: true)}',
                style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
