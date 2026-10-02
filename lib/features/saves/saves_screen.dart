import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../data/save_repository.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

/// Autosave plus three manual slots. Saving to a different slot than you
/// loaded from creates a branch you can return to later.
class SavesScreen extends StatefulWidget {
  const SavesScreen({super.key});

  @override
  State<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends State<SavesScreen> {
  final _repo = getIt<SaveRepository>();
  late Future<List<SaveSlotMeta?>> _slots = _repo.listSlots();

  void _refresh() {
    final next = _repo.listSlots();
    setState(() {
      _slots = next;
    });
  }

  Future<bool> _confirm(String title, String body, {IconData icon = Icons.help_outline_rounded, bool destructive = false}) async =>
      await showLvDialog<bool>(
        context: context,
        icon: icon,
        accent: destructive ? Theme.of(context).colorScheme.error : null,
        title: title,
        message: body,
        actions: const [LvDialogAction('Confirm', true, primary: true), LvDialogAction('Cancel', false)],
      ) ??
      false;

  Future<void> _save(String slot, SaveSlotMeta? existing) async {
    final cubit = context.read<GameCubit>();
    if (existing != null && !await _confirm('Overwrite this slot?', 'The life saved here will be replaced.', icon: Icons.swap_horiz_rounded)) return;
    if (!mounted) return;
    final label = TextEditingController();
    final ok = await showLvDialog<bool>(
      context: context,
      icon: Icons.bookmark_add_rounded,
      title: 'Save this life',
      body: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: label,
          maxLength: 40,
          textAlign: TextAlign.start,
          decoration: const InputDecoration(hintText: 'Name it (optional), e.g. Before the interview'),
        ),
      ),
      actions: const [LvDialogAction('Save', true, primary: true), LvDialogAction('Cancel', false)],
    );
    if (ok != true) return;
    await cubit.saveTo(slot, label: label.text.trim().isEmpty ? null : label.text.trim());
    _refresh();
    scaffoldMessenger?.showSnackBar(const SnackBar(content: Text('Saved.')));
  }

  ScaffoldMessengerState? get scaffoldMessenger => mounted ? ScaffoldMessenger.maybeOf(context) : null;

  Future<void> _load(String slot) async {
    final cubit = context.read<GameCubit>();
    if (cubit.state.hasGame && !await _confirm('Load this life?', 'Unsaved progress since your last save will be lost (the autosave is kept).')) {
      return;
    }
    final ok = await cubit.loadFrom(slot);
    if (ok && mounted) context.go('/hub');
  }

  @override
  Widget build(BuildContext context) {
    final hasGame = context.watch<GameCubit>().state.hasGame;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved lives')),
      body: SafeArea(
        child: FutureBuilder<List<SaveSlotMeta?>>(
          future: _slots,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final metas = snap.data!;
            return ListView(children: [
              ResponsiveBody(
                child: Column(children: [
                  for (final (i, slot) in SaveRepository.allSlots.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SlotCard(
                        slot: slot,
                        meta: metas[i],
                        canSave: hasGame && slot != SaveRepository.autosaveSlot,
                        onSave: () => _save(slot, metas[i]),
                        onLoad: metas[i] == null || metas[i]!.corrupted ? null : () => _load(slot),
                        onDelete: metas[i] == null
                            ? null
                            : () async {
                                if (await _confirm('Delete this save?', 'This cannot be undone.', icon: Icons.delete_outline_rounded, destructive: true)) {
                                  await _repo.delete(slot);
                                  _refresh();
                                }
                              },
                      ),
                    ),
                  const EmptyNote('The game autosaves after every action. Use manual slots to keep branches of a life you might want to revisit.',
                      icon: Icons.alt_route_rounded),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.meta, required this.canSave, required this.onSave, this.onLoad, this.onDelete});

  final String slot;
  final SaveSlotMeta? meta;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback? onLoad;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = meta;
    final title = slot == SaveRepository.autosaveSlot ? 'Autosave' : 'Slot ${slot.substring(4)}';
    return SectionCard(
      title: title,
      trailing: onDelete == null ? null : IconButton(tooltip: 'Delete', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m == null)
          Text('Empty', style: t.bodyMedium)
        else if (m.corrupted)
          Text('This save could not be read.', style: TextStyle(color: Theme.of(context).colorScheme.error))
        else ...[
          if (m.label != null) Text(m.label!, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text('${m.characterName}, ${m.age} · ${m.gameDate} · Chapter ${m.chapter}'),
          Text('Saved ${MaterialLocalizations.of(context).formatShortDate(m.savedAt)} · ${m.summary}', style: t.bodySmall),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          if (canSave) FilledButton.tonal(onPressed: onSave, child: const Text('Save here')),
          OutlinedButton(onPressed: onLoad, child: const Text('Load')),
        ]),
      ]),
    );
  }
}
