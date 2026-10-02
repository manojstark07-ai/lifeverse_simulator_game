import 'dart:math' as math;

import '../character/stats.dart';
import '../content/content_bundle.dart';
import '../core/json_utils.dart';
import '../core/money.dart';
import '../engine_context.dart';
import '../finance/finance_service.dart';
import '../game_events.dart';
import '../game_state.dart';
import '../journal/journal.dart';
import '../lifestyle/lifestyle_service.dart';
import 'creator_models.dart';

/// Running a channel on ViewTube, a fictional video platform: uploads,
/// audience growth, monetisation, sponsorships and fame.
class CreatorService {
  const CreatorService._();

  static const uploadEnergy = 20.0;
  static const fullTimeWeeklyHours = 30.0;
  static const fullTimeUploadsPerMonth = 6;
  static const monetizeSubscribers = 1000;
  static const monetizeViews = 40000;
  static const sponsorMinSubscribers = 10000;

  /// Subscriber milestones → (flag, label).
  static const milestones = [
    (1000, 'creator_1k', '1,000 subscribers'),
    (10000, 'creator_10k', '10,000 subscribers'),
    (100000, 'creator_100k', '100,000 subscribers — the Silver Plaque'),
    (1000000, 'creator_1m', 'one million subscribers — the Gold Plaque'),
  ];

  static void start(EngineContext ctx, String nicheId, String channelName) {
    final s = ctx.s;
    if (s.creator != null) throw StateError('You already run a channel');
    final niche = ctx.c.creatorNiches[nicheId] ?? (throw StateError('Unknown niche $nicheId'));
    final name = channelName.trim();
    if (name.length < 3 || name.length > 30) throw StateError('Channel name must be 3–30 characters');
    s.creator = CreatorState(channelName: name, nicheId: niche.id, startedDay: s.day);
    s.flags.add('creator_started');
    ctx.outcomes.add('Started "$name" (${niche.name})');
    ctx.journal('Channel launched', '"$name" — ${niche.name} on ViewTube.', JournalKind.career, important: true);
  }

  /// 0..1 production quality from skills, stats and equipment.
  static double quality(GameState s, ContentBundle c) {
    final cr = s.creator;
    if (cr == null) return 0;
    final niche = c.creatorNiches[cr.nicheId]!;
    var weighted = 0.0;
    niche.skillWeights.forEach((k, w) {
      final v = StatKeys.all.contains(k) ? s.stat(k) : s.skill(k);
      weighted += w * v / 100;
    });
    final q = weighted * 0.45 +
        s.skill(SkillKeys.content) / 100 * 0.25 +
        LifestyleService.creatorEquipment(s, c) * 0.2 +
        s.stat(StatKeys.energy) / 100 * 0.1;
    return clampDouble(q, 0, 1);
  }

  static String? uploadBlocker(GameState s) {
    if (s.creator == null) return 'Start a channel first';
    if (s.story.inEvent) return 'Finish the current story event first';
    if (s.actionsToday >= GameState.maxActionsPerDay) return 'No time left today';
    if (s.stat(StatKeys.energy) < uploadEnergy) return 'Too tired to film';
    return null;
  }

  /// Films, edits and publishes one video by hand.
  static VideoRecord upload(EngineContext ctx) {
    final blocker = uploadBlocker(ctx.s);
    if (blocker != null) throw StateError(blocker);
    ctx.addStat(StatKeys.energy, -uploadEnergy, record: false);
    ctx.s.actionsToday++;
    final video = _publish(ctx);
    ctx.outcomes.add('"${video.title}": ${compact(video.views)} views${video.viral ? ' — it went viral!' : ''}');
    return video;
  }

  static VideoRecord _publish(EngineContext ctx) {
    final s = ctx.s;
    final cr = s.creator!;
    final niche = ctx.c.creatorNiches[cr.nicheId]!;
    final q = quality(s, ctx.c);
    final expected = (40 + cr.subscribers * 0.25) * (0.3 + 1.7 * q) * niche.reach;
    var views = expected * (0.6 + ctx.rng.nextDouble() * 0.8);
    final viral = ctx.rng.chance(0.015 + 0.06 * q * q);
    if (viral) views *= 10 + ctx.rng.nextDouble() * 30;
    final v = views.round();
    final newSubs = (v * (0.004 + 0.02 * q) * (cr.subscribers < 1000 ? 1.5 : 1)).round();

    cr
      ..videos += 1
      ..lastUploadDay = s.day
      ..totalViews += v
      ..monthViews += v;
    _addSubscribers(ctx, newSubs);
    final template = niche.titles.isEmpty ? 'Video #{n}' : niche.titles[ctx.rng.nextInt(niche.titles.length)];
    final video = VideoRecord(
        day: s.day, title: template.replaceAll('{n}', '${cr.videos}'), views: v, viral: viral);
    cr.recent.insert(0, video);
    if (cr.recent.length > CreatorState.maxRecent) cr.recent.removeLast();
    ctx.addSkill(SkillKeys.content, 0.8 * (1 - s.skill(SkillKeys.content) / 130) * ctx.modifier(ModifierKeys.skillGain),
        record: false);
    ctx.addStat(StatKeys.communication, 0.1, record: false);
    if (viral) {
      s.counters['viralVideos'] = s.counter('viralVideos') + 1;
      ctx.journal('Gone viral', '"${video.title}" reached ${compact(v)} views.', JournalKind.career, important: true);
    }
    return video;
  }

  static void _addSubscribers(EngineContext ctx, int delta) {
    final cr = ctx.s.creator!;
    final before = cr.subscribers;
    cr.subscribers = math.max(0, cr.subscribers + delta);
    for (final (threshold, flag, label) in milestones) {
      if (before < threshold && cr.subscribers >= threshold && ctx.s.flags.add(flag)) {
        ctx.journal('Milestone: $label', '"${cr.channelName}" reached $label.', JournalKind.milestone, important: true);
        ctx.emit(Notice('"${cr.channelName}" just hit $label!'));
      }
    }
    _updateFame(ctx);
  }

  /// Applied by story effects: a collab, a controversy, a takedown.
  static void adjust(EngineContext ctx, {double subsPercent = 0, int views = 0}) {
    final cr = ctx.s.creator;
    if (cr == null) return;
    final delta = (cr.subscribers * subsPercent / 100).round();
    _addSubscribers(ctx, delta);
    cr
      ..totalViews += views
      ..monthViews += views;
    if (delta != 0) ctx.outcomes.add('Subscribers ${delta > 0 ? '+' : ''}${compact(delta)}');
  }

  static void _updateFame(EngineContext ctx) {
    final subs = ctx.s.creator?.subscribers ?? 0;
    final target = subs < 10 ? 0.0 : clampDouble(math.log(subs) / math.ln10 * 16 - 16, 0, 100);
    final s = ctx.s;
    s.stats[StatKeys.fame] = math.max(target, s.stat(StatKeys.fame) * 0.98);
  }

  static void setFullTime(EngineContext ctx, bool on) {
    final s = ctx.s;
    final cr = s.creator ?? (throw StateError('Start a channel first'));
    if (on && s.career.hasCareer) throw StateError('Quit your job before going full-time');
    if (on && s.education.isEnrolled) throw StateError('Finish your course before going full-time');
    if (cr.fullTime == on) return;
    cr.fullTime = on;
    if (on) {
      s.flags.add('creator_fulltime');
      s.finance.familySupportMonthly = 0;
    }
    ctx.outcomes.add(on ? 'Now a full-time creator' : 'Creating part-time again');
    ctx.journal(on ? 'Full-time creator' : 'Back to part-time creating',
        on ? 'You made "${cr.channelName}" your job.' : 'The channel is a side project again.', JournalKind.career,
        important: on);
  }

  static void settleMonth(EngineContext ctx, MonthLedger ledger) {
    final s = ctx.s;
    final cr = s.creator;
    if (cr == null) return;
    if (cr.fullTime) {
      for (var i = 0; i < fullTimeUploadsPerMonth; i++) {
        _publish(ctx);
      }
    }
    // The back catalogue keeps earning views.
    final catalogue = (cr.totalViews * 0.02).round();
    cr
      ..totalViews += catalogue
      ..monthViews += catalogue;
    final idle = cr.lastUploadDay == null || s.day - cr.lastUploadDay! > 45;
    if (idle && cr.subscribers > 0) _addSubscribers(ctx, -(cr.subscribers * 0.03).ceil());

    final niche = ctx.c.creatorNiches[cr.nicheId]!;
    var earned = 0;
    if (!cr.monetized && cr.subscribers >= monetizeSubscribers && cr.totalViews >= monetizeViews) {
      cr.monetized = true;
      s.flags.add('creator_monetized');
      ctx.journal('Monetised!', 'ViewTube approved "${cr.channelName}" for ads.', JournalKind.career, important: true);
      ctx.emit(Notice('"${cr.channelName}" is now monetised — ads will pay from next month.'));
    } else if (cr.monetized) {
      earned += _earn(ctx, ledger, (cr.monthViews / 1000 * niche.rpm).round(), 'ViewTube ad revenue');
    }
    if (cr.subscribers >= sponsorMinSubscribers && !idle &&
        ctx.rng.chance(math.min(0.6, 0.15 + cr.subscribers / 500000))) {
      final deal = (cr.subscribers * niche.sponsorRate / 500).round() * 500;
      cr.sponsorships++;
      earned += _earn(ctx, ledger, deal, 'Brand sponsorship');
      ctx.journal('Brand deal', 'A sponsor paid ${formatRupees(deal)} for a video.', JournalKind.career);
    }
    // Lenders count creator income too.
    s.counters['creatorLastMonth'] = earned;
    cr.monthViews = 0;
    _updateFame(ctx);
  }

  static int _earn(EngineContext ctx, MonthLedger ledger, int amount, String label) {
    if (amount <= 0) return 0;
    ctx.credit(amount, 'creator', label, record: false);
    ledger.addIncome(amount, label);
    ctx.s.creator!.lifetimeEarnings += amount;
    return amount;
  }

  static String compact(int n) {
    final a = n.abs();
    final sign = n < 0 ? '−' : '';
    if (a >= 1000000) return '$sign${(a / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return '$sign${(a / 1000).toStringAsFixed(1)}K';
    return '$sign$a';
  }
}
