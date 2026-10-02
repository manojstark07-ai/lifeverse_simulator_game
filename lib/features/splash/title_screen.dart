import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../app/theme.dart';
import '../../data/save_repository.dart';
import '../game/game_cubit.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  late Future<SaveSlotMeta?> _autosave = _loadAutosave();

  Future<SaveSlotMeta?> _loadAutosave() async {
    final slots = await getIt<SaveRepository>().listSlots();
    return slots.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1235), Color(0xFF3B2183), Color(0xFF8E3F8F), Color(0xFFFF7A59)],
            stops: [0, 0.45, 0.78, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(28),
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: white.withValues(alpha: 0.12),
                        border: Border.all(color: white.withValues(alpha: 0.35), width: 1.5),
                      ),
                      child: const Icon(Icons.all_inclusive_rounded, size: 50, color: white),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('LIFEVERSE',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: LvFonts.display, fontSize: 46, fontWeight: FontWeight.w700, color: white, letterSpacing: 4)),
                  const SizedBox(height: 6),
                  Text('A story-driven life simulation',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: LvFonts.ui, fontSize: 15, fontWeight: FontWeight.w600, color: white.withValues(alpha: 0.8))),
                  const SizedBox(height: 28),
                  Text(
                    '“Every choice creates a future, but no single choice should define an entire life.”',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: LvFonts.display, fontSize: 17, fontStyle: FontStyle.italic, height: 1.45, color: white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 44),
                  FutureBuilder<SaveSlotMeta?>(
                    future: _autosave,
                    builder: (context, snap) {
                      final meta = snap.data;
                      if (meta == null || meta.corrupted) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _GlassButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Continue',
                          detail: '${meta.characterName}, ${meta.age} · ${meta.gameDate}',
                          highlighted: true,
                          onTap: () async {
                            final ok = await context.read<GameCubit>().loadFrom(SaveRepository.autosaveSlot);
                            if (ok && context.mounted) context.go('/hub');
                          },
                        ),
                      );
                    },
                  ),
                  _GlassButton(icon: Icons.add_rounded, label: 'Begin a new life', onTap: () => context.push('/create')),
                  const SizedBox(height: 14),
                  _GlassButton(
                    icon: Icons.folder_open_rounded,
                    label: 'Load a saved life',
                    onTap: () async {
                      await context.push('/saves');
                      final next = _loadAutosave();
                      setState(() {
                        _autosave = next;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: white),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Settings & accessibility'),
                    onPressed: () => context.push('/settings'),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'All money in LIFEVERSE is fictional. Exams, banks and companies are invented for the game.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Frosted pill used on the gradient title screen.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.label, required this.onTap, this.detail, this.highlighted = false});

  final IconData icon;
  final String label;
  final String? detail;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? Colors.white : Colors.white.withValues(alpha: 0.14);
    final fg = highlighted ? LvColors.violet : Colors.white;
    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: highlighted ? 0 : 0.35))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(children: [
            Icon(icon, color: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontFamily: LvFonts.ui, fontWeight: FontWeight.w800, fontSize: 16, color: fg)),
                if (detail != null)
                  Text(detail!, style: TextStyle(fontFamily: LvFonts.ui, fontSize: 12.5, color: fg.withValues(alpha: 0.75))),
              ]),
            ),
            Icon(Icons.arrow_forward_rounded, color: fg.withValues(alpha: 0.8)),
          ]),
        ),
      ),
    );
  }
}
