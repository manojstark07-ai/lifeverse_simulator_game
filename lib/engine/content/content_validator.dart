import '../character/stats.dart';
import '../conditions/condition.dart';
import '../effects/effect.dart';
import '../lifestyle/lifestyle_models.dart';
import '../puzzles/puzzle.dart';
import '../story/story_models.dart';
import 'content_bundle.dart';

class ValidationReport {
  final List<String> errors = [];
  final List<String> warnings = [];

  bool get isValid => errors.isEmpty;

  @override
  String toString() => [
    if (errors.isNotEmpty) 'Errors:\n  ${errors.join('\n  ')}',
    if (warnings.isNotEmpty) 'Warnings:\n  ${warnings.join('\n  ')}',
  ].join('\n');
}

/// Rigorous static checks over all content: references, story-graph shape,
/// puzzle correctness metadata, exam configuration and progression rules.
///
/// Run at startup in debug builds and in the test suite, so broken branches
/// are caught before a player can ever reach them.
class ContentValidator {
  const ContentValidator._();

  /// Flags the engine itself sets (prefix match), so content may read them.
  static const engineFlagPrefixes = [
    'bg_',
    'home_',
    'enrolled_',
    'graduated_',
    'dropped_',
    'hired',
    'missed_emi',
    'loan_default',
    'loan_closed',
    'debt_free',
    'money_trouble',
    'scholarship',
    'promoted',
    'had_backlog',
    'living_independently',
    'chapter1_complete',
    'semester_boost',
    'semester_penalty',
    'remit_home',
    'frugal_mode',
    'mature_on',
    'has_partner',
    'engaged',
    'married',
    'divorced',
    'parent',
    'creator_',
    'quit_job',
    'lost_job',
    'switched_employer',
    'investor',
  ];

  static const speakers = {'player', 'narrator'};

  static ValidationReport validate(ContentBundle c) {
    final r = ValidationReport();
    final e = r.errors;

    void cond(Condition x, String ctx) => x.validate(c, e, ctx);
    void effects(List<Effect> xs, String ctx) {
      for (final x in xs) {
        x.validate(c, e, ctx);
      }
    }

    void keys(Iterable<String> ks, List<String> allowed, String ctx) {
      for (final k in ks) {
        if (!allowed.contains(k)) e.add('$ctx: unknown key "$k"');
      }
    }

    // --- character content
    for (final b in c.backgrounds.values) {
      keys(b.startStats.keys, StatKeys.all, 'background ${b.id}');
      keys(b.startSkills.keys, SkillKeys.all, 'background ${b.id}');
      if (b.startingCash < 0 || b.familySupportMonthly < 0)
        e.add('background ${b.id}: negative money');
    }
    for (final t in c.traits.values) {
      keys(t.startStats.keys, StatKeys.all, 'trait ${t.id}');
      keys(t.modifiers.keys, ModifierKeys.all, 'trait ${t.id}');
    }
    for (final i in c.interests.values) {
      keys(i.startSkills.keys, SkillKeys.all, 'interest ${i.id}');
    }
    if (c.backgrounds.isEmpty ||
        c.hometowns.isEmpty ||
        c.ambitions.isEmpty ||
        c.traits.isEmpty) {
      e.add('character creation content is incomplete');
    }

    // --- puzzles
    for (final p in c.puzzles.values) {
      final ctx = 'puzzle ${p.id}';
      if (!PuzzleCategory.all.containsKey(p.category))
        e.add('$ctx: unknown category "${p.category}"');
      if (!PuzzleType.all.contains(p.type))
        e.add('$ctx: unknown type "${p.type}"');
      if (p.difficulty < 1 || p.difficulty > 3)
        e.add('$ctx: difficulty must be 1..3');
      if (p.pools.isEmpty) e.add('$ctx: belongs to no pool');
      if (p.explanation.trim().length < 20)
        e.add('$ctx: explanation too short');
      if (p.timeLimitSec <= 0) e.add('$ctx: time limit must be positive');
      if (p.type == PuzzleType.mcq) {
        if (p.options.length < 2) e.add('$ctx: needs at least 2 options');
        if (p.answer is! int && p.answer != p.answer.toInt())
          e.add('$ctx: mcq answer must be an index');
        if (p.answer < 0 || p.answer >= p.options.length)
          e.add('$ctx: answer index out of range');
        if (p.options.toSet().length != p.options.length)
          e.add('$ctx: duplicate options');
      } else if (p.options.isNotEmpty) {
        e.add('$ctx: numeric puzzles must not have options');
      }
    }

    // --- exams
    for (final x in c.exams.values) {
      final ctx = 'exam ${x.id}';
      final pool = c.pool(x.pool);
      if (pool.length < x.questionCount)
        e.add(
          '$ctx: pool "${x.pool}" has ${pool.length} < ${x.questionCount} puzzles',
        );
      if ((x.performanceWeight + x.preparationWeight - 1).abs() > 1e-6)
        e.add('$ctx: weights must sum to 1');
      if (x.performanceWeight < 0.5)
        e.add('$ctx: player performance must carry at least half the weight');
      if (x.tiers.isEmpty || x.tiers.last.minComposite != 0)
        e.add('$ctx: lowest tier must start at 0');
      keys(x.prepStats.keys, StatKeys.all, ctx);
      keys(x.prepSkills.keys, SkillKeys.all, ctx);
      if (!x.fictional && (x.source == null || x.verifiedOn == null)) {
        e.add('$ctx: non-fictional exams need "source" and "verifiedOn"');
      }
      if (x.disclaimer.trim().isEmpty) e.add('$ctx: disclaimer required');
    }

    // --- programs
    for (final p in c.programs.values) {
      final ctx = 'program ${p.id}';
      if (!SkillKeys.all.contains(p.gradeSkill))
        e.add('$ctx: unknown grade skill');
      keys(p.skillGainsPerMonth.keys, SkillKeys.all, ctx);
      if (p.tiers.isEmpty) e.add('$ctx: no institution tiers');
      for (final id in p.careerIds) {
        if (!c.careers.containsKey(id)) e.add('$ctx: unknown career "$id"');
      }
      if (p.admissionType == 'exam') {
        final exam = c.exams[p.admissionExamId];
        if (exam == null) {
          e.add('$ctx: unknown admission exam "${p.admissionExamId}"');
        } else {
          for (final t in exam.tiers.take(exam.tiers.length - 1)) {
            if (p.tier(t.id) == null)
              e.add('$ctx: no institution tier for exam tier "${t.id}"');
          }
        }
      }
      if (p.durationMonths <= 0 || p.durationMonths % 6 != 0)
        e.add('$ctx: duration must be whole semesters');
      if (p.practicePool != null && c.pool(p.practicePool!).isEmpty)
        e.add('$ctx: practice pool is empty');
    }

    // --- careers & jobs
    for (final k in c.careers.values) {
      final ctx = 'career ${k.id}';
      if (k.ladder.isEmpty) e.add('$ctx: empty ladder');
      if (!SkillKeys.all.contains(k.primarySkill))
        e.add('$ctx: unknown primary skill');
      keys(k.skillGainsPerMonth.keys, SkillKeys.all, ctx);
      for (final p in k.requiredPrograms) {
        if (!c.programs.containsKey(p)) e.add('$ctx: unknown program "$p"');
      }
      if (c.pool(k.interviewPool).isEmpty)
        e.add('$ctx: interview pool "${k.interviewPool}" is empty');
      for (var i = 1; i < k.ladder.length; i++) {
        if (k.ladder[i].monthlySalary < k.ladder[i - 1].monthlySalary)
          e.add('$ctx: salary decreases at level $i');
      }
    }
    for (final k in c.careers.values) {
      cond(k.requires, 'career ${k.id}');
      if (k.requires.type != 'always' && k.requirementNote == null)
        e.add('career ${k.id}: requires needs a requirementNote');
    }
    for (final j in c.partTimeJobs.values) {
      keys(j.skillGainsPerMonth.keys, SkillKeys.all, 'job ${j.id}');
      keys(j.statGainsPerMonth.keys, StatKeys.all, 'job ${j.id}');
    }

    // --- shop
    for (final i in c.shopItems.values) {
      final ctx = 'item ${i.id}';
      if (!ShopCategory.all.contains(i.category))
        e.add('$ctx: unknown category "${i.category}"');
      if (i.price < 0 || i.monthlyUpkeep < 0) e.add('$ctx: negative money');
      if (i.isSubscription && i.monthlyUpkeep == 0)
        e.add('$ctx: memberships need a monthly fee');
      if (i.loanProductId != null &&
          !c.loanProducts.containsKey(i.loanProductId)) {
        e.add('$ctx: unknown loan product "${i.loanProductId}"');
      }
      if (i.downPaymentPct < 0 || i.downPaymentPct > 1)
        e.add('$ctx: downPaymentPct must be in [0,1]');
      if (i.creatorQuality < 0 || i.creatorQuality > 1)
        e.add('$ctx: creatorQuality must be in [0,1]');
      if (i.annualDepreciationPct >= 100)
        e.add('$ctx: depreciation must be < 100%');
      cond(i.requires, ctx);
      effects([...i.onBuy, ...i.onSell, ...i.monthlyEffects], ctx);
    }

    // --- creator
    for (final n in c.creatorNiches.values) {
      final ctx = 'niche ${n.id}';
      for (final k in n.skillWeights.keys) {
        if (!StatKeys.all.contains(k) && !SkillKeys.all.contains(k))
          e.add('$ctx: unknown stat/skill "$k"');
      }
      if ((n.skillWeights.values.fold<double>(0, (a, b) => a + b) - 1).abs() >
          0.01)
        e.add('$ctx: weights must sum to 1');
      if (n.rpm <= 0 || n.reach <= 0 || n.sponsorRate <= 0)
        e.add('$ctx: rates must be positive');
      if (n.titles.isEmpty) e.add('$ctx: needs video titles');
    }

    // --- world
    for (final l in c.locations.values) {
      cond(l.requires, 'location ${l.id}');
    }
    for (final a in c.actions.values) {
      final ctx = 'action ${a.id}';
      if (!c.locations.containsKey(a.location))
        e.add('$ctx: unknown location "${a.location}"');
      if (a.energyCost < 0 || a.moneyCost < 0) e.add('$ctx: negative cost');
      cond(a.requires, ctx);
      effects(a.effects, ctx);
    }

    // --- rules
    for (final m in c.monthlyRules.values) {
      cond(m.when, 'monthly rule ${m.id}');
      effects(m.effects, 'monthly rule ${m.id}');
      if (m.effects.isEmpty) e.add('monthly rule ${m.id}: no effects');
    }
    for (final m in c.interviewModifiers.values) {
      cond(m.when, 'interview modifier ${m.id}');
      if (m.delta.abs() > 0.3)
        e.add('interview modifier ${m.id}: |delta| must be <= 0.3');
    }

    // --- achievements & conclusions
    for (final a in c.achievements.values) {
      cond(a.condition, 'achievement ${a.id}');
    }
    final chapters = c.conclusions.values.map((x) => x.chapter).toSet();
    for (final ch in chapters) {
      final fallback = c.conclusions.values.any(
        (x) => x.chapter == ch && x.condition.type == 'always',
      );
      if (!fallback)
        e.add(
          'chapter $ch: needs a fallback conclusion with an "always" condition',
        );
    }
    for (final x in c.conclusions.values) {
      cond(x.condition, 'conclusion ${x.id}');
    }
    for (final l in c.epilogueLines) {
      cond(l.condition, 'epilogue line');
    }

    // --- story graph
    final scheduledTargets = <String>{};
    final flagsSet = <String>{};
    final flagsRead = <String, String>{};
    void collectEffects(List<Effect> xs) {
      for (final x in xs) {
        scheduledTargets.addAll(x.eventsScheduled);
        flagsSet.addAll(x.flagsSet);
        for (final f in x.flagsRead) {
          flagsRead.putIfAbsent(f, () => 'if-effect');
        }
      }
    }

    void readFlags(Condition x, String ctx) {
      for (final f in x.flagsRead) {
        flagsRead.putIfAbsent(f, () => ctx);
      }
    }

    for (final a in c.actions.values) {
      collectEffects(a.effects);
      readFlags(a.requires, 'action ${a.id}');
    }
    for (final ev in c.events.values) {
      _validateEvent(c, ev, r, cond, effects, collectEffects, readFlags);
    }
    for (final a in c.achievements.values) {
      readFlags(a.condition, 'achievement ${a.id}');
    }
    for (final x in c.conclusions.values) {
      readFlags(x.condition, 'conclusion ${x.id}');
    }
    for (final m in c.monthlyRules.values) {
      readFlags(m.when, 'monthly rule ${m.id}');
      collectEffects(m.effects);
    }
    for (final m in c.interviewModifiers.values) {
      readFlags(m.when, 'interview modifier ${m.id}');
    }
    for (final i in c.shopItems.values) {
      collectEffects([...i.onBuy, ...i.onSell, ...i.monthlyEffects]);
      readFlags(i.requires, 'item ${i.id}');
    }
    for (final k in c.careers.values) {
      readFlags(k.requires, 'career ${k.id}');
    }
    for (final l in c.epilogueLines) {
      readFlags(l.condition, 'epilogue line');
    }
    for (final l in c.locations.values) {
      readFlags(l.requires, 'location ${l.id}');
    }
    for (final ev in c.events.values) {
      if (ev.trigger.kind == TriggerKind.scheduled &&
          !scheduledTargets.contains(ev.id)) {
        e.add('event ${ev.id}: scheduled trigger but nothing schedules it');
      }
    }
    flagsRead.forEach((flag, ctx) {
      final engineSet =
          engineFlagPrefixes.any(flag.startsWith) ||
          c.backgrounds.values.any((b) => b.flags.contains(flag));
      if (!engineSet && !flagsSet.contains(flag)) {
        e.add('$ctx: reads flag "$flag" which nothing sets');
      }
    });
    return r;
  }

  static void _validateEvent(
    ContentBundle c,
    StoryEvent ev,
    ValidationReport r,
    void Function(Condition, String) cond,
    void Function(List<Effect>, String) effects,
    void Function(List<Effect>) collect,
    void Function(Condition, String) readFlags,
  ) {
    final e = r.errors;
    final ctx = 'event ${ev.id}';
    if (!TriggerKind.all.contains(ev.trigger.kind))
      e.add('$ctx: unknown trigger kind');
    if (ev.trigger.kind == TriggerKind.random &&
        (ev.trigger.chancePerMonth <= 0 || ev.trigger.chancePerMonth > 1)) {
      e.add('$ctx: random events need chancePerMonth in (0,1]');
    }
    if (!c.locations.containsKey(ev.location))
      e.add('$ctx: unknown location "${ev.location}"');
    cond(ev.trigger.condition, '$ctx trigger');
    readFlags(ev.trigger.condition, '$ctx trigger');
    if (!ev.nodes.containsKey(ev.start))
      e.add('$ctx: start node "${ev.start}" missing');

    final edges = <String, Set<String>>{};
    for (final node in ev.nodes.values) {
      final nctx = '$ctx/${node.id}';
      final targets = edges.putIfAbsent(node.id, () => {});
      if (node.speaker != null &&
          !speakers.contains(node.speaker) &&
          !c.npcs.containsKey(node.speaker)) {
        e.add('$nctx: unknown speaker "${node.speaker}"');
      }
      effects(node.onEnter, '$nctx onEnter');
      collect(node.onEnter);
      for (final v in node.variants) {
        cond(v.condition, '$nctx variant');
        readFlags(v.condition, '$nctx variant');
      }
      final ids = <String>{};
      var hasFallback = false;
      for (final ch in node.choices) {
        final cctx = '$nctx/${ch.id}';
        if (!ids.add(ch.id)) e.add('$cctx: duplicate choice id');
        if (ch.label.trim().isEmpty) e.add('$cctx: empty label');
        if (ch.cost.money < 0 || ch.cost.days < 0 || ch.cost.energy < 0)
          e.add('$cctx: negative cost');
        if (ch.requires.type == 'always' && ch.cost.money == 0)
          hasFallback = true;
        cond(ch.requires, cctx);
        readFlags(ch.requires, cctx);
        effects(ch.effects, cctx);
        collect(ch.effects);
        void target(String? t, String where) {
          if (t == null) return;
          if (!ev.nodes.containsKey(t)) {
            e.add('$cctx: $where points to missing node "$t"');
          } else {
            targets.add(t);
          }
        }

        void routes(List<Route> rs, String where) {
          for (final rt in rs) {
            cond(rt.condition, '$cctx $where');
            readFlags(rt.condition, '$cctx $where');
            target(rt.next, '$where route');
          }
        }

        target(ch.next, 'next');
        routes(ch.routes, 'routes');
        final chal = ch.challenge;
        if (chal != null) {
          if (!ChallengeKind.all.contains(chal.kind))
            e.add('$cctx: unknown challenge kind');
          switch (chal.kind) {
            case ChallengeKind.exam:
              if (!c.exams.containsKey(chal.examId))
                e.add('$cctx: unknown exam "${chal.examId}"');
            case ChallengeKind.interview:
              final career = c.careers[chal.careerId];
              if (career == null) {
                e.add('$cctx: unknown career "${chal.careerId}"');
              } else if (c.pool(career.interviewPool).length < chal.count) {
                e.add('$cctx: interview pool too small');
              }
            default:
              if (chal.pool == null || c.pool(chal.pool!).length < chal.count) {
                e.add(
                  '$cctx: puzzle pool "${chal.pool}" has fewer than ${chal.count} puzzles',
                );
              }
          }
          for (final (o, label) in [
            (chal.onPass, 'onPass'),
            (chal.onFail, 'onFail'),
          ]) {
            effects(o.effects, '$cctx $label');
            collect(o.effects);
            target(o.next, label);
            routes(o.routes, label);
          }
        }
      }
      if (!node.isTerminal && !hasFallback) {
        e.add(
          '$nctx: needs at least one choice with no requirements and no money cost (soft-lock guard)',
        );
      }
    }

    // Reachability from the start node.
    final seen = <String>{};
    final stack = [ev.start];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      if (!seen.add(n)) continue;
      stack.addAll(edges[n] ?? const {});
    }
    for (final id in ev.nodes.keys) {
      if (!seen.contains(id)) e.add('$ctx: node "$id" is unreachable');
    }
  }
}
