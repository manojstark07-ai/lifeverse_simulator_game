import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/character/stats.dart';
import '../../engine/core/game_calendar.dart';
import '../../engine/core/money.dart';
import '../../engine/creator/creator_models.dart';
import '../../engine/creator/creator_service.dart';
import '../../engine/game_state.dart';
import '../../engine/lifestyle/lifestyle_service.dart';
import '../../shared/design.dart';
import '../../shared/widgets.dart';
import '../game/game_cubit.dart';

/// Start and run a channel on ViewTube, a fictional video platform.
class CreatorScreen extends StatelessWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creator Studio')),
      body: SafeArea(
        child: BlocBuilder<GameCubit, GameSession>(builder: (context, session) {
          final s = session.game;
          if (s == null) return const SizedBox.shrink();
          return ListView(children: [
            ResponsiveBody(child: s.creator == null ? const _StartChannel() : _Channel(state: s, channel: s.creator!)),
          ]);
        }),
      ),
    );
  }
}

class _StartChannel extends StatefulWidget {
  const _StartChannel();

  @override
  State<_StartChannel> createState() => _StartChannelState();
}

class _StartChannelState extends State<_StartChannel> {
  final _name = TextEditingController();
  String? _niche;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final t = Theme.of(context).textTheme;
    final valid = _niche != null && _name.text.trim().length >= 3;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Become a creator', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(
        'Pick a niche and a name. Every upload takes energy and one of your daily activities. Quality comes from your '
        'skills, your looks and energy, and your gear — a better phone or camera helps. Hit 1,000 subscribers and '
        '40,000 views to earn from ads; past 10,000, sponsors come calling.',
        style: t.bodyMedium,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        maxLength: 30,
        decoration: const InputDecoration(labelText: 'Channel name', hintText: 'e.g. Chai & Chaos'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Text('Niche', style: t.labelLarge),
      const SizedBox(height: 8),
      for (final n in cubit.content.creatorNiches.values)
        SelectCard(
          selected: _niche == n.id,
          onTap: () => setState(() => _niche = n.id),
          title: n.name,
          subtitle: '${n.description}\nAds ~${formatRupees(n.rpm.round())} per 1,000 views · '
              'reach ${n.reach >= 1.2 ? 'huge' : (n.reach >= 0.95 ? 'broad' : 'niche')}',
        ),
      const SizedBox(height: 8),
      GradientButton(
        label: 'Launch channel',
        icon: Icons.videocam_rounded,
        onPressed: valid ? () => cubit.startChannel(_niche!, _name.text.trim()) : null,
      ),
    ]);
  }
}

class _Channel extends StatelessWidget {
  const _Channel({required this.state, required this.channel});

  final GameState state;
  final CreatorState channel;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final c = cubit.content;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final niche = c.creatorNiches[channel.nicheId]!;
    final quality = CreatorService.quality(state, c);
    final blocker = CreatorService.uploadBlocker(state);
    final gear = LifestyleService.creatorEquipment(state, c);
    final nextMilestone = CreatorService.milestones.where((m) => channel.subscribers < m.$1).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HeroPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(channel.channelName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('${niche.name} · since ${GameCalendar.formatDay(channel.startedDay)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 14),
          Wrap(spacing: 18, runSpacing: 8, children: [
            _Big(value: CreatorService.compact(channel.subscribers), label: 'subscribers'),
            _Big(value: CreatorService.compact(channel.totalViews), label: 'views'),
            _Big(value: '${channel.videos}', label: 'videos'),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Next upload',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StatBar(label: 'Production quality', value: quality * 100, icon: Icons.auto_awesome_rounded),
          StatBar(label: 'Gear', value: gear * 100, icon: Icons.photo_camera_rounded),
          StatBar(label: SkillKeys.labels[SkillKeys.content]!, value: state.skill(SkillKeys.content), icon: Icons.movie_edit),
          Text('This niche rewards: ${niche.skillWeights.keys.map((k) => StatKeys.labels[k] ?? SkillKeys.labels[k] ?? k).join(', ')}.',
              style: t.bodySmall),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: blocker == null ? cubit.uploadVideo : null,
            icon: const Icon(Icons.upload_rounded),
            label: Text('Film & upload  (−${CreatorService.uploadEnergy.round()} energy)'),
          ),
          if (blocker != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(blocker, style: t.bodySmall?.copyWith(color: scheme.error), textAlign: TextAlign.center),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Business',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            InfoChip(
                icon: channel.monetized ? Icons.monetization_on_rounded : Icons.lock_clock_rounded,
                label: channel.monetized ? 'Monetised' : 'Not monetised yet'),
            InfoChip(icon: Icons.payments_rounded, label: 'Earned ${formatRupees(channel.lifetimeEarnings)}'),
            InfoChip(icon: Icons.handshake_rounded, label: '${channel.sponsorships} sponsorships'),
            InfoChip(icon: Icons.star_rounded, label: 'Fame ${state.stat(StatKeys.fame).round()}'),
          ]),
          const SizedBox(height: 8),
          if (!channel.monetized)
            Text(
                'Ads unlock at ${CreatorService.monetizeSubscribers} subscribers and '
                '${CreatorService.compact(CreatorService.monetizeViews)} total views.',
                style: t.bodySmall),
          if (nextMilestone != null) Text('Next milestone: ${nextMilestone.$3}.', style: t.bodySmall),
          Text('Channels that go quiet for 45 days start losing subscribers.', style: t.bodySmall),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Full-time creator'),
            subtitle: Text(
                'Six uploads a month happen automatically, in exchange for ${CreatorService.fullTimeWeeklyHours.round()} '
                'working hours a week. No other full-time job.'),
            value: channel.fullTime,
            onChanged: (v) => cubit.setCreatorFullTime(v),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Recent uploads',
        child: channel.recent.isEmpty
            ? const EmptyNote('No videos yet. Your first upload is always the hardest.')
            : Column(children: [
                for (final v in channel.recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(v.viral ? Icons.local_fire_department_rounded : Icons.play_circle_outline_rounded,
                        color: v.viral ? const Color(0xFFE2683C) : null),
                    title: Text(v.title),
                    subtitle: Text('${CreatorService.compact(v.views)} views · ${GameCalendar.formatDay(v.day)}'),
                  ),
              ]),
      ),
      const SizedBox(height: 8),
      Text('ViewTube is fictional. Audience numbers are simulated.', style: t.bodySmall, textAlign: TextAlign.center),
    ]);
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
      ]);
}
