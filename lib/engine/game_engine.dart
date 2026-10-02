import 'achievements/achievement_service.dart';
import 'actions/daily_action.dart';
import 'career/career_service.dart';
import 'character/character_factory.dart';
import 'character/player_profile.dart';
import 'character/stats.dart';
import 'content/content_bundle.dart';
import 'core/game_calendar.dart';
import 'core/money.dart';
import 'core/rng.dart';
import 'creator/creator_service.dart';
import 'effects/effect_resolver.dart';
import 'endings/conclusion_service.dart';
import 'engine_context.dart';
import 'exams/exam_models.dart';
import 'exams/exam_service.dart';
import 'finance/finance_service.dart';
import 'finance/investment_service.dart';
import 'game_events.dart';
import 'game_state.dart';
import 'journal/journal.dart';
import 'lifestyle/lifestyle_service.dart';
import 'life/life_system_service.dart';
import 'puzzles/puzzle.dart';
import 'puzzles/puzzle_selector.dart';
import 'story/story_engine.dart';
import 'time/life_simulation.dart';
import 'time/routine.dart';

class EngineResult {
  const EngineResult(this.state, this.events);
  final GameState state;
  final List<GameEvent> events;
}

/// Thrown when the player attempts something the rules do not allow.
class RuleViolation implements Exception {
  RuleViolation(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The single entry point to the simulation.
///
/// Every operation clones the input state, applies all changes to the clone
/// and returns it with the events produced. If anything fails, the original
/// state is untouched (transactional). No Flutter imports: this whole engine
/// runs in plain Dart tests and headless simulations.
class GameEngine {
  GameEngine(this.content);

  final ContentBundle content;

  EngineResult newGame(CharacterSpec spec) {
    final GameState state;
    try {
      state = CharacterFactory.create(spec, content);
    } on ArgumentError catch (e) {
      throw RuleViolation('${e.message}');
    }
    return _run(state, (_) {});
  }

  EngineResult newLifePlus(GameState previous, CharacterSpec spec) {
    final result = newGame(spec);
    final next = result.state;
    next.life.legacy
      ..addAll(previous.life.legacy)
      ..add(LifeSystemService.legacyFromState(previous));
    next.life.generation = previous.life.generation + 1;
    next.flags.add('new_life_plus');
    final inheritance = (previous.finance.netWorth / 20).round().clamp(
      0,
      50000,
    );
    if (inheritance > 0) {
      next.finance.cash += inheritance;
      next.journal.add(
        JournalEntry(
          day: 0,
          title: 'A legacy carried forward',
          body:
              'A previous life left you ${formatRupees(inheritance)} of breathing room.',
          kind: JournalKind.milestone,
          important: true,
        ),
      );
    }
    return EngineResult(next, result.events);
  }

  EngineResult _run(GameState input, void Function(EngineContext ctx) op) {
    final ctx = EngineContext(input.clone(), content);
    try {
      op(ctx);
    } on StateError catch (e) {
      throw RuleViolation(e.message);
    } on ArgumentError catch (e) {
      throw RuleViolation('${e.message}');
    }
    _settle(ctx);
    ctx.commitRng();
    return EngineResult(ctx.s, ctx.events);
  }

  /// Post-operation housekeeping shared by every command.
  void _settle(EngineContext ctx) {
    StoryEngine.pruneQueue(ctx);
    _maybeStartEvent(ctx);
    AchievementService.evaluate(ctx);
  }

  bool _maybeStartEvent(EngineContext ctx) {
    if (ctx.s.story.inEvent || ctx.s.life.deceased) return true;
    final next = StoryEngine.nextTriggered(ctx.s, content);
    if (next == null) return false;
    StoryEngine.start(ctx, next);
    return true;
  }

  // --------------------------------------------------------------- story --

  NodeView? currentNode(GameState s) => StoryEngine.view(s, content);

  EngineResult choose(GameState s, String choiceId) =>
      _run(s, (ctx) => StoryEngine.choose(ctx, choiceId));

  List<Puzzle> pendingChallengePuzzles(GameState s) =>
      s.story.pendingPuzzleIds.map((id) => content.puzzles[id]!).toList();

  EngineResult resolveChallenge(GameState s, ChallengeResult result) =>
      _run(s, (ctx) => StoryEngine.resolveChallenge(ctx, result));

  // ---------------------------------------------------------------- time --

  EngineResult endDay(GameState s) => advance(s, days: 1);

  /// Advances toward the same calendar date in the following year.
  ///
  /// Calendar arithmetic keeps leap years correct instead of assuming every
  /// year is exactly 365 days. Important story events can interrupt the skip.
  EngineResult advanceOneYear(GameState s) {
    final current = GameCalendar.dateOf(s.day);
    final next = DateTime.utc(current.year + 1, current.month, current.day);
    return advance(s, days: GameCalendar.dayOf(next) - s.day);
  }

  /// Advances up to [days] days, stopping early when a story event begins.
  /// With [untilNextMonth] it stops on the 1st of the next month instead.
  EngineResult advance(
    GameState s, {
    int days = 1,
    bool untilNextMonth = false,
  }) => _run(s, (ctx) {
    _requireFreeTime(ctx.s);
    final target = untilNextMonth
        ? GameCalendar.startOfNextMonth(ctx.s.day)
        : ctx.s.day + days;
    while (ctx.s.day < target) {
      LifeSimulation.advanceDay(ctx);
      StoryEngine.pruneQueue(ctx);
      if (_maybeStartEvent(ctx)) break;
    }
  });

  void _requireFreeTime(GameState s) {
    if (s.life.deceased) throw StateError('This life has ended');
    if (s.story.inEvent) {
      throw StateError('Finish the current story event first');
    }
  }

  void _requireLifeAction(EngineContext ctx, {double energy = 8}) {
    _requireFreeTime(ctx.s);
    if (ctx.s.actionsToday >= GameState.maxActionsPerDay) {
      throw StateError('No time left today');
    }
    if (ctx.s.stat(StatKeys.energy) < energy) {
      throw StateError('Too tired for another major decision');
    }
    ctx.addStat(StatKeys.energy, -energy, record: false);
    ctx.s.actionsToday++;
  }

  // ------------------------------------------------------- daily actions --

  List<DailyAction> actionsAt(GameState s, String locationId) =>
      content.actions.values
          .where(
            (a) => a.location == locationId && a.requires.evaluate(s, content),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  /// Why [action] cannot be done right now, or null if it can.
  String? actionBlocker(GameState s, DailyAction action) {
    if (s.story.inEvent) return 'Finish the current story event first';
    if (action.consumesDailySlot &&
        s.actionsToday >= GameState.maxActionsPerDay) {
      return 'No time left today';
    }
    if (!action.requires.evaluate(s, content)) return 'Not available';
    if (s.stat(StatKeys.energy) < action.energyCost) return 'Too tired';
    if (s.finance.cash < action.moneyCost) return 'Not enough money';
    return null;
  }

  EngineResult performAction(GameState s, String actionId) => _run(s, (ctx) {
    final action =
        content.actions[actionId] ??
        (throw StateError('Unknown action $actionId'));
    final blocker = actionBlocker(ctx.s, action);
    if (blocker != null) throw StateError(blocker);
    ctx.addStat(StatKeys.energy, -action.energyCost, record: false);
    if (action.moneyCost > 0) {
      ctx.trySpend(action.moneyCost, 'leisure', action.label, record: false);
    }
    EffectResolver.applyAll(ctx, action.effects);
    if (action.consumesDailySlot) ctx.s.actionsToday++;
    ctx.s.counters['action:${action.id}'] =
        ctx.s.counter('action:${action.id}') + 1;
    ctx.emit(
      DecisionOutcome(
        title: action.label,
        choice: action.description,
        outcomes: List.of(ctx.outcomes),
      ),
    );
  });

  // ------------------------------------------------------------- routine --

  EngineResult setRoutine(GameState s, Routine routine) => _run(s, (ctx) {
    for (final v in [
      routine.study,
      routine.exercise,
      routine.social,
      routine.family,
    ]) {
      if (v < 0 || v > Routine.freeHoursBeforeCommitments) {
        throw StateError('Invalid routine hours');
      }
    }
    ctx.s.routine = routine.copy();
  });

  /// Turns mature storylines (alcohol, smoking, crime, dating) on or off for
  /// this life. Consequences already earned stay in place.
  EngineResult setMatureThemes(GameState s, bool on) => _run(s, (ctx) {
    if (on) {
      ctx.s.flags.add('mature_on');
    } else {
      ctx.s.flags.remove('mature_on');
    }
  });

  // ------------------------------------------------------------- finance --

  EngineResult prepayLoan(GameState s, String loanId, int amount) =>
      _run(s, (ctx) => FinanceService.prepay(ctx, loanId, amount));

  // ---------------------------------------------------------- market play --

  EngineResult buyStock(GameState s, String stockId, int shares) => _run(s, (
    ctx,
  ) {
    _requireFreeTime(ctx.s);
    if (ctx.s.actionsToday >= GameState.maxActionsPerDay) {
      throw StateError('No time left today');
    }
    if (ctx.s.stat(StatKeys.energy) < 2) throw StateError('Too tired to trade');
    ctx.addStat(StatKeys.energy, -2, record: false);
    InvestmentService.buy(ctx, stockId, shares);
    ctx.s.actionsToday++;
    ctx.emit(
      DecisionOutcome(
        title: 'Order filled',
        choice: 'Buy',
        outcomes: List.of(ctx.outcomes),
      ),
    );
  });

  EngineResult sellStock(GameState s, String stockId, int shares) => _run(s, (
    ctx,
  ) {
    _requireFreeTime(ctx.s);
    if (ctx.s.actionsToday >= GameState.maxActionsPerDay) {
      throw StateError('No time left today');
    }
    if (ctx.s.stat(StatKeys.energy) < 2) throw StateError('Too tired to trade');
    ctx.addStat(StatKeys.energy, -2, record: false);
    InvestmentService.sell(ctx, stockId, shares);
    ctx.s.actionsToday++;
    ctx.emit(
      DecisionOutcome(
        title: 'Order filled',
        choice: 'Sell',
        outcomes: List.of(ctx.outcomes),
      ),
    );
  });

  EngineResult recordSportsSession(GameState s, String sport, int score) =>
      _run(s, (ctx) {
        _requireFreeTime(ctx.s);
        final result = score.clamp(0, 100).toInt();
        if (ctx.s.actionsToday >= GameState.maxActionsPerDay)
          throw StateError('No time left today');
        if (ctx.s.stat(StatKeys.energy) < 12)
          throw StateError('Too tired to compete');
        ctx.addStat(StatKeys.energy, -12, record: false);
        ctx.addStat(StatKeys.health, result >= 65 ? 1.5 : 0.4);
        ctx.addStat(StatKeys.discipline, result / 80);
        ctx.addStat(StatKeys.wellbeing, result >= 60 ? 2.5 : 0.5);
        ctx.addStat(StatKeys.fame, result >= 80 ? 1.5 : 0.2);
        ctx.s.counters['sports_sessions'] =
            ctx.s.counter('sports_sessions') + 1;
        ctx.s.counters['sports_score'] = ctx.s.counter('sports_score') + result;
        ctx.s.flags.add('sports_${sport}');
        if (ctx.s.counter('sports_sessions') >= 5 && result >= 75)
          ctx.s.flags.add('athlete_path');
        if (result >= 80)
          ctx.credit(
            500 + result * 10,
            'sports',
            '$sport match prize',
            record: false,
          );
        ctx.s.actionsToday++;
        ctx.emit(
          DecisionOutcome(
            title: '$sport session',
            choice: '$result/100 performance',
            outcomes: List.of(ctx.outcomes),
            shownInline: true,
          ),
        );
      });

  EngineResult recordFight(GameState s, String outcome) => _run(s, (ctx) {
    _requireFreeTime(ctx.s);
    if (!{'deescalated', 'escaped', 'won', 'lost'}.contains(outcome)) {
      throw StateError('Unknown sparring result');
    }
    if (ctx.s.actionsToday >= GameState.maxActionsPerDay)
      throw StateError('No time left today');
    ctx.addStat(StatKeys.energy, -8, record: false);
    ctx.s.actionsToday++;
    ctx.s.counters['conflict_sessions'] =
        ctx.s.counter('conflict_sessions') + 1;
    switch (outcome) {
      case 'deescalated':
        ctx.addStat(StatKeys.wellbeing, 1.5);
        ctx.addStat(StatKeys.communication, 0.8);
        ctx.s.flags.add('conflict_deescalator');
        break;
      case 'escaped':
        ctx.addStat(StatKeys.health, -0.4);
        ctx.addSkill(SkillKeys.streetwise, 0.6);
        break;
      case 'won':
        ctx.addStat(StatKeys.health, -2);
        ctx.addStat(StatKeys.wellbeing, -1);
        ctx.addSkill(SkillKeys.streetwise, 0.8);
        ctx.s.counters['heat'] = (ctx.s.counter('heat') + 1)
            .clamp(0, 10)
            .toInt();
        break;
      case 'lost':
        ctx.addStat(StatKeys.health, -6);
        ctx.addStat(StatKeys.wellbeing, -4);
        ctx.s.counters['heat'] = (ctx.s.counter('heat') + 1)
            .clamp(0, 10)
            .toInt();
    }
    ctx.emit(
      DecisionOutcome(
        title: 'Conflict resolved',
        choice: outcome,
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  // ----------------------------------------------------------- lifestyle --

  /// Buys a shop item outright or, with [finance], on a loan after a down
  /// payment. An item in the same slot (your old phone) is traded in.
  EngineResult buyItem(GameState s, String itemId, {bool finance = false}) =>
      _run(s, (ctx) {
        final item =
            content.shopItems[itemId] ??
            (throw StateError('Unknown item $itemId'));
        LifestyleService.buy(ctx, item, finance: finance);
        ctx.emit(
          DecisionOutcome(
            title: item.name,
            choice: finance ? 'Bought on EMI' : 'Bought',
            outcomes: List.of(ctx.outcomes),
          ),
        );
      });

  EngineResult sellItem(GameState s, String ownedUid) => _run(s, (ctx) {
    LifestyleService.sell(ctx, ownedUid);
    ctx.emit(
      DecisionOutcome(
        title: 'Sold',
        choice: '',
        outcomes: List.of(ctx.outcomes),
      ),
    );
  });

  EngineResult makeover(GameState s, Appearance look) => _run(s, (ctx) {
    LifestyleService.makeover(ctx, look);
    ctx.emit(
      DecisionOutcome(
        title: 'Salon makeover',
        choice: 'A new look',
        outcomes: List.of(ctx.outcomes),
      ),
    );
  });

  // ------------------------------------------------------------- creator --

  EngineResult startChannel(GameState s, String nicheId, String name) =>
      _run(s, (ctx) {
        if (ctx.s.story.inEvent) {
          throw StateError('Finish the current story event first');
        }
        CreatorService.start(ctx, nicheId, name);
        ctx.emit(
          DecisionOutcome(
            title: 'Channel launched',
            choice: name,
            outcomes: List.of(ctx.outcomes),
          ),
        );
      });

  EngineResult uploadVideo(GameState s) => _run(s, (ctx) {
    CreatorService.upload(ctx);
    ctx.emit(
      DecisionOutcome(
        title: 'New upload',
        choice: '',
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  EngineResult setCreatorFullTime(GameState s, bool on) =>
      _run(s, (ctx) => CreatorService.setFullTime(ctx, on));

  // ---------------------------------------------------------- job portal --

  List<Puzzle> interviewPuzzles(GameState s, String careerId) =>
      CareerService.interviewPuzzles(s, content, content.careers[careerId]!);

  String? applicationBlocker(GameState s, String careerId) =>
      CareerService.applicationBlocker(s, content, content.careers[careerId]!);

  EngineResult applyForJob(
    GameState s,
    String careerId,
    ChallengeResult result,
  ) => _run(s, (ctx) {
    final career =
        content.careers[careerId] ??
        (throw StateError('Unknown career $careerId'));
    final hired = CareerService.apply(ctx, career, result);
    ctx.emit(
      DecisionOutcome(
        title: hired ? 'Job offer!' : 'No offer this time',
        choice: career.ladder.first.title,
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  EngineResult quitJob(GameState s) => _run(s, (ctx) {
    CareerService.quit(ctx);
    ctx.emit(
      DecisionOutcome(
        title: 'Resigned',
        choice: '',
        outcomes: List.of(ctx.outcomes),
      ),
    );
  });

  EngineResult quitPartTime(GameState s) => _run(s, (ctx) {
    if (ctx.s.career.partTimeJobId == null) {
      throw StateError('No part-time job');
    }
    CareerService.quitPartTime(ctx);
  });

  EngineResult switchEmployer(GameState s) => _run(s, (ctx) {
    _requireFreeTime(ctx.s);
    if (!ctx.s.career.hasCareer) {
      throw StateError('You need a full-time job first');
    }
    if (ctx.s.actionsToday >= GameState.maxActionsPerDay) {
      throw StateError('No time left today');
    }
    if (ctx.s.stat(StatKeys.energy) < 8) {
      throw StateError('Too tired to job hunt');
    }
    ctx.addStat(StatKeys.energy, -8, record: false);
    ctx.s.actionsToday++;
    CareerService.switchEmployer(ctx, 12);
    ctx.emit(
      DecisionOutcome(
        title: 'Changed jobs',
        choice: 'Negotiated a new offer',
        outcomes: List.of(ctx.outcomes),
      ),
    );
  });

  EngineResult startStartup(GameState s) => _run(s, (ctx) {
    _requireFreeTime(ctx.s);
    if (ctx.s.actionsToday >= GameState.maxActionsPerDay) {
      throw StateError('No time left today');
    }
    if (ctx.s.stat(StatKeys.energy) < 18) {
      throw StateError('Too tired to launch a venture');
    }
    const startupCost = 25000;
    if (ctx.s.finance.cash < startupCost) {
      throw StateError('You need ${formatRupees(startupCost)} to launch');
    }
    final career =
        content.careers['fixlab_founder'] ??
        (throw StateError('Startup path is unavailable'));
    ctx.addStat(StatKeys.energy, -18, record: false);
    ctx.trySpend(startupCost, 'startup', 'FixLab launch budget');
    if (ctx.s.creator?.fullTime ?? false) {
      ctx.s.creator!.fullTime = false;
    }
    CareerService.hire(ctx, career, employer: 'FixLab', salaryMultiplier: 1);
    ctx.addSkill(SkillKeys.business, 1.5);
    ctx.addStat(StatKeys.wellbeing, 2);
    ctx.s.actionsToday++;
    ctx.s.flags.add('startup_founder');
    ctx.journal(
      'Started FixLab',
      'You put savings into a repair-and-services startup. The founder life begins.',
      JournalKind.career,
      important: true,
    );
    ctx.emit(
      DecisionOutcome(
        title: 'Startup launched',
        choice: 'FixLab',
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  // ----------------------------------------------------- long-term life --

  EngineResult startBusiness(GameState s, String name, String sector) =>
      _run(s, (ctx) {
        _requireLifeAction(ctx, energy: 14);
        final venture = LifeSystemService.startBusiness(
          ctx,
          name: name,
          sector: sector,
        );
        ctx.emit(
          DecisionOutcome(
            title: 'Venture launched',
            choice: venture.name,
            outcomes: List.of(ctx.outcomes),
            shownInline: true,
          ),
        );
      });

  EngineResult runBusinessProject(
    GameState s,
    String businessId,
    String title,
    int budget,
  ) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 10);
    LifeSystemService.runProject(ctx, businessId, title: title, budget: budget);
    ctx.emit(
      DecisionOutcome(
        title: 'Project shipped',
        choice: title,
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  EngineResult hireBusiness(GameState s, String businessId) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 8);
    LifeSystemService.hire(ctx, businessId);
    ctx.emit(
      DecisionOutcome(
        title: 'Team expanded',
        choice: businessId,
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  EngineResult fundBusiness(GameState s, String businessId) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 6);
    LifeSystemService.raiseFunding(ctx, businessId);
    ctx.emit(
      DecisionOutcome(
        title: 'Funding round',
        choice: businessId,
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  EngineResult buyProperty(
    GameState s, {
    required String name,
    required String kind,
    required int value,
    required int rent,
  }) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 4);
    LifeSystemService.buyProperty(
      ctx,
      name: name,
      kind: kind,
      value: value,
      rent: rent,
    );
    ctx.emit(
      DecisionOutcome(
        title: 'Property purchased',
        choice: name,
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  EngineResult sellProperty(GameState s, String propertyId) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 2);
    LifeSystemService.sellProperty(ctx, propertyId);
  });

  EngineResult addInsurance(GameState s, String kind) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 2);
    LifeSystemService.insure(ctx, kind: kind);
  });

  EngineResult contributeRetirement(GameState s, int amount) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 2);
    LifeSystemService.contributeRetirement(ctx, amount);
  });

  EngineResult payTaxes(GameState s, {int? amount}) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 1);
    LifeSystemService.payTaxes(ctx, amount: amount);
  });

  EngineResult retire(GameState s) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 1);
    LifeSystemService.retire(ctx);
  });

  EngineResult travelToCity(GameState s, String cityId) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 6);
    if (!content.hometowns.containsKey(cityId)) {
      throw StateError('Unknown city');
    }
    LifeSystemService.travel(ctx, cityId);
  });

  EngineResult talkToNpc(GameState s, String npcId) => _run(s, (ctx) {
    _requireLifeAction(ctx, energy: 4);
    if (!content.npcs.containsKey(npcId)) {
      throw StateError('Unknown person');
    }
    ctx.adjustRelationship(npcId, affinity: 1.5, trust: 0.5);
    ctx.remember(
      npcId,
      'world_conversation',
      'You made time for a real conversation.',
      1,
    );
    ctx.s.counters['world_conversations'] =
        ctx.s.counter('world_conversations') + 1;
    ctx.emit(
      DecisionOutcome(
        title: 'Conversation remembered',
        choice: content.npcs[npcId]!.name,
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  EngineResult endLife(GameState s, String reason) => _run(s, (ctx) {
    _requireFreeTime(ctx.s);
    if (!ctx.s.life.retired &&
        GameCalendar.ageOn(ctx.s.profile.birthDate, ctx.s.day) < 70) {
      throw StateError('Retirement or age 70 is required to close a life');
    }
    ctx.s.life.deceased = true;
    ctx.s.life.deathDay = ctx.s.day;
    ctx.s.life.deathReason = reason;
    ctx.s.flags.add('life_complete');
    ctx.s.life.legacy.add(LifeSystemService.createLegacy(ctx));
    ctx.journal(
      'Life chapter closed',
      reason,
      JournalKind.milestone,
      important: true,
    );
    ctx.emit(
      Notice('This life has ended. Its choices are now part of your legacy.'),
    );
  });

  EngineResult concludeChapter(GameState s) => _run(s, (ctx) {
    _requireFreeTime(ctx.s);
    ConclusionService.conclude(ctx);
  });

  // --------------------------------------------------- practice & mocks --

  static const practiceEnergy = 8.0;
  static const mockEnergy = 15.0;

  /// A deterministic practice set that does not consume game randomness.
  List<Puzzle> practiceSet(GameState s, String pool, {int count = 3}) {
    final puzzles = content.pool(pool);
    final rng = Rng(
      s.seed ^ (s.day * 7919) ^ (s.counter('practiceSessions') * 104729),
    );
    final picked = <Puzzle>[];
    final solved = Set.of(s.solvedPuzzles);
    var attempts = s.counter('practiceAttempts');
    var correct = s.counter('practiceCorrect');
    while (picked.length < count && picked.length < puzzles.length) {
      final remaining = puzzles.where((p) => !picked.contains(p)).toList();
      final p = PuzzleSelector.adaptive(
        pool: remaining,
        solved: solved,
        attempts: attempts,
        correct: correct,
        rng: rng,
      );
      if (p == null) break;
      picked.add(p);
      solved.add(p.id);
      attempts++;
      correct++;
    }
    return picked;
  }

  List<Puzzle> mockPaper(GameState s, String examId) {
    final exam = content.exams[examId]!;
    final rng = Rng(
      s.seed ^ 0x5eed ^ ((s.exams[examId]?.mockCount ?? 0) * 65537) ^ s.day,
    );
    return ExamService.generatePaper(content, exam, rng);
  }

  String? practiceBlocker(GameState s, {bool mock = false}) {
    if (s.story.inEvent) return 'Finish the current story event first';
    if (s.actionsToday >= GameState.maxActionsPerDay) {
      return 'No time left today';
    }
    if (s.stat(StatKeys.energy) < (mock ? mockEnergy : practiceEnergy)) {
      return 'Too tired to concentrate';
    }
    return null;
  }

  /// Records a practice or mock session. Learning rewards are granted only
  /// the first time each puzzle is solved, preventing reward farming.
  EngineResult recordPractice(
    GameState s,
    ChallengeResult result, {
    String? mockExamId,
  }) => _run(s, (ctx) {
    final blocker = practiceBlocker(ctx.s, mock: mockExamId != null);
    if (blocker != null) throw StateError(blocker);
    final st = ctx.s;
    ctx.addStat(
      StatKeys.energy,
      -(mockExamId != null ? mockEnergy : practiceEnergy),
      record: false,
    );
    st.actionsToday++;
    st.counters['practiceSessions'] = st.counter('practiceSessions') + 1;
    for (final a in result.answers) {
      final puzzle =
          content.puzzles[a.puzzleId] ??
          (throw StateError('Unknown puzzle ${a.puzzleId}'));
      st.counters['practiceAttempts'] = st.counter('practiceAttempts') + 1;
      if (!a.correct) continue;
      st.counters['practiceCorrect'] = st.counter('practiceCorrect') + 1;
      if (st.solvedPuzzles.add(puzzle.id)) {
        ctx.addStat(
          StatKeys.knowledge,
          0.4 * puzzle.difficulty * ctx.modifier(ModifierKeys.knowledgeGain),
        );
        final skill = _skillFor(puzzle.category);
        if (skill != null) ctx.addSkill(skill, 0.5 * puzzle.difficulty);
      }
    }
    ctx.addStat(StatKeys.discipline, 0.2);
    if (mockExamId != null) {
      final exam = content.exams[mockExamId]!;
      final record = st.exams.putIfAbsent(
        mockExamId,
        () => ExamRecord(examId: mockExamId),
      );
      record.mockCount++;
      final pct = ExamService.performancePct(exam, result);
      if (pct > record.bestMockPct) record.bestMockPct = pct;
    }
    ctx.emit(
      DecisionOutcome(
        title: mockExamId != null ? 'Mock test' : 'Practice session',
        choice: '${result.correct}/${result.answers.length} correct',
        outcomes: List.of(ctx.outcomes),
        shownInline: true,
      ),
    );
  });

  static String? _skillFor(String category) => switch (category) {
    'math' || 'pattern' || 'time' => SkillKeys.mathematics,
    'programming' || 'debugging' => SkillKeys.programming,
    'accounting' => SkillKeys.accounting,
    'electrical' || 'science' => SkillKeys.electrical,
    'case' => SkillKeys.business,
    _ => null,
  };
}
