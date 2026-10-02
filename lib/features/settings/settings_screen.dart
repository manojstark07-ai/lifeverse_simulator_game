import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/settings_repository.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';
import 'settings_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & accessibility')),
      body: SafeArea(
        child: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, s) {
            final cubit = context.read<SettingsCubit>();
            final hasGame = context.watch<GameCubit>().state.hasGame;
            final t = Theme.of(context).textTheme;
            return ListView(
              children: [
                ResponsiveBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        title: 'Display',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Theme', style: t.labelLarge),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'system',
                                  label: Text('System'),
                                ),
                                ButtonSegment(
                                  value: 'light',
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: 'dark',
                                  label: Text('Dark'),
                                ),
                              ],
                              selected: {s.themeMode},
                              onSelectionChanged: (v) =>
                                  cubit.update(s.copyWith(themeMode: v.first)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Text size: ${(s.textScale * 100).round()}%',
                              style: t.labelLarge,
                            ),
                            Slider(
                              value: s.textScale,
                              min: 0.85,
                              max: 1.5,
                              divisions: 13,
                              label: '${(s.textScale * 100).round()}%',
                              onChanged: (v) =>
                                  cubit.update(s.copyWith(textScale: v)),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Reduce motion'),
                              subtitle: const Text(
                                'Turns off transitions and map animation.',
                              ),
                              value: s.reducedMotion,
                              onChanged: (v) =>
                                  cubit.update(s.copyWith(reducedMotion: v)),
                            ),
                            DropdownButtonFormField<String>(
                              value: s.locale,
                              decoration: const InputDecoration(
                                labelText: 'Language',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text('English'),
                                ),
                                DropdownMenuItem(
                                  value: 'hi',
                                  child: Text('Hindi'),
                                ),
                                DropdownMenuItem(
                                  value: 'ta',
                                  child: Text('Tamil'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null)
                                  cubit.update(s.copyWith(locale: v));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: 'Content',
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mature life themes'),
                          subtitle: const Text(
                            'Alcohol, smoking, crime and dating storylines — each with real consequences. '
                            'Romance always involves adults and mutual consent, and is never explicit.',
                          ),
                          value: s.matureThemes,
                          onChanged: (v) {
                            cubit.update(s.copyWith(matureThemes: v));
                            final game = context.read<GameCubit>();
                            if (game.state.hasGame) game.setMatureThemes(v);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: 'Game',
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Autosave'),
                              subtitle: const Text(
                                'Saves to the autosave slot after every action.',
                              ),
                              value: s.autosave,
                              onChanged: (v) =>
                                  cubit.update(s.copyWith(autosave: v)),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Anonymous analytics'),
                              subtitle: const Text(
                                'Off by default. Stores only anonymous action names until a provider is configured.',
                              ),
                              value: s.analyticsOptIn,
                              onChanged: (v) =>
                                  cubit.update(s.copyWith(analyticsOptIn: v)),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cloud sync readiness'),
                              subtitle: const Text(
                                'Keeps your save eligible for the offline-first sync adapter.',
                              ),
                              value: s.cloudSyncEnabled,
                              onChanged: (v) =>
                                  cubit.update(s.copyWith(cloudSyncEnabled: v)),
                            ),
                            if (hasGame)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.logout_rounded),
                                title: const Text('Return to title'),
                                onTap: () async {
                                  final game = context.read<GameCubit>();
                                  await game.flushSaves();
                                  game.closeGame();
                                  if (context.mounted) context.go('/');
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionCard(
                        title: 'About this game',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LIFEVERSE is a work of fiction and an educational simulation.',
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• All money is fictional and can never be exchanged for real money.\n'
                              '• UTAT and every bank, company and college named in the game are invented.\n'
                              '• Practice questions are original and are not official exam questions.\n'
                              '• Costs and salaries are indicative, simplified figures — not financial advice.\n'
                              '• Health is abstracted; nothing here is medical advice.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
