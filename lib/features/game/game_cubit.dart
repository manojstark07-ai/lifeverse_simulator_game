import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/save_repository.dart';
import '../../data/analytics_service.dart';
import '../../engine/character/player_profile.dart';
import '../../engine/content/content_bundle.dart';
import '../../engine/game_engine.dart';
import '../../engine/game_events.dart';
import '../../engine/game_state.dart';
import '../../engine/puzzles/puzzle.dart';
import '../../engine/time/routine.dart';

class GameSession extends Equatable {
  const GameSession({
    this.game,
    this.feedback = const [],
    this.error,
    this.revision = 0,
  });

  final GameState? game;

  /// Engine events not yet shown by the UI (toasts, sheets, navigation).
  final List<GameEvent> feedback;
  final String? error;

  /// Bumped on every change so listeners fire even for equal-looking states.
  final int revision;

  bool get hasGame => game != null;

  @override
  List<Object?> get props => [revision, error, feedback.length];
}

/// Presentation-layer façade over the [GameEngine]: runs commands, keeps the
/// latest state, autosaves, and queues engine events for the UI.
class GameCubit extends Cubit<GameSession> {
  GameCubit({
    required this.engine,
    required this.saves,
    required this.autosaveEnabled,
    bool Function()? analyticsEnabled,
    GameState? initial,
  }) : analyticsEnabled = analyticsEnabled ?? (() => false),
       super(GameSession(game: initial));

  final GameEngine engine;
  final SaveRepository saves;
  bool Function() autosaveEnabled;
  final bool Function() analyticsEnabled;
  Future<void> _saveChain = Future.value();

  ContentBundle get content => engine.content;
  GameState get game => state.game!;

  void _apply(EngineResult Function() op, {bool autosave = true}) {
    try {
      final r = op();
      emit(
        GameSession(
          game: r.state,
          feedback: [...state.feedback, ...r.events],
          revision: state.revision + 1,
        ),
      );
      if (analyticsEnabled()) AnalyticsService.instance.track('game_action');
      if (autosave) _autosave(r.state);
    } on RuleViolation catch (e) {
      emit(
        GameSession(
          game: state.game,
          feedback: state.feedback,
          error: e.message,
          revision: state.revision + 1,
        ),
      );
    }
  }

  void _autosave(GameState s) {
    if (!autosaveEnabled()) return;
    _saveChain = _saveChain
        .then<void>((_) => saves.save(SaveRepository.autosaveSlot, s))
        .catchError((Object _) {});
  }

  /// Waits for pending autosaves (used by tests and before quitting).
  Future<void> flushSaves() => _saveChain;

  void startNewLife(CharacterSpec spec) => _apply(() => engine.newGame(spec));

  void startNewLifePlus(CharacterSpec spec) =>
      _apply(() => engine.newLifePlus(game, spec));

  void choose(String choiceId) => _apply(() => engine.choose(game, choiceId));

  List<Puzzle> pendingPuzzles() => engine.pendingChallengePuzzles(game);

  void resolveChallenge(ChallengeResult result) =>
      _apply(() => engine.resolveChallenge(game, result));

  void performAction(String id) => _apply(() => engine.performAction(game, id));

  void endDay() => _apply(() => engine.endDay(game));

  void skipDays(int days) => _apply(() => engine.advance(game, days: days));

  void skipOneYear() => _apply(() => engine.advanceOneYear(game));

  void skipToNextMonth() =>
      _apply(() => engine.advance(game, untilNextMonth: true));

  void setRoutine(Routine r) => _apply(() => engine.setRoutine(game, r));

  void setMatureThemes(bool on) =>
      _apply(() => engine.setMatureThemes(game, on));

  void prepayLoan(String loanId, int amount) =>
      _apply(() => engine.prepayLoan(game, loanId, amount));

  void buyStock(String stockId, int shares) =>
      _apply(() => engine.buyStock(game, stockId, shares));

  void sellStock(String stockId, int shares) =>
      _apply(() => engine.sellStock(game, stockId, shares));

  void recordSportsSession(String sport, int score) =>
      _apply(() => engine.recordSportsSession(game, sport, score));

  void recordFight(String outcome) =>
      _apply(() => engine.recordFight(game, outcome));

  void buyItem(String itemId, {bool finance = false}) =>
      _apply(() => engine.buyItem(game, itemId, finance: finance));

  void sellItem(String ownedUid) =>
      _apply(() => engine.sellItem(game, ownedUid));

  void makeover(Appearance look) => _apply(() => engine.makeover(game, look));

  void startChannel(String nicheId, String name) =>
      _apply(() => engine.startChannel(game, nicheId, name));

  void uploadVideo() => _apply(() => engine.uploadVideo(game));

  void setCreatorFullTime(bool on) =>
      _apply(() => engine.setCreatorFullTime(game, on));

  void applyForJob(String careerId, ChallengeResult result) =>
      _apply(() => engine.applyForJob(game, careerId, result));

  void quitJob() => _apply(() => engine.quitJob(game));

  void quitPartTime() => _apply(() => engine.quitPartTime(game));

  void switchEmployer() => _apply(() => engine.switchEmployer(game));

  void startStartup() => _apply(() => engine.startStartup(game));

  void startBusiness(String name, String sector) =>
      _apply(() => engine.startBusiness(game, name, sector));

  void runBusinessProject(String businessId, String title, int budget) =>
      _apply(() => engine.runBusinessProject(game, businessId, title, budget));

  void hireBusiness(String businessId) =>
      _apply(() => engine.hireBusiness(game, businessId));

  void fundBusiness(String businessId) =>
      _apply(() => engine.fundBusiness(game, businessId));

  void buyProperty({
    required String name,
    required String kind,
    required int value,
    required int rent,
  }) => _apply(
    () => engine.buyProperty(
      game,
      name: name,
      kind: kind,
      value: value,
      rent: rent,
    ),
  );

  void sellProperty(String propertyId) =>
      _apply(() => engine.sellProperty(game, propertyId));

  void addInsurance(String kind) =>
      _apply(() => engine.addInsurance(game, kind));

  void contributeRetirement(int amount) =>
      _apply(() => engine.contributeRetirement(game, amount));

  void payTaxes({int? amount}) =>
      _apply(() => engine.payTaxes(game, amount: amount));

  void retire() => _apply(() => engine.retire(game));

  void travelToCity(String cityId) =>
      _apply(() => engine.travelToCity(game, cityId));

  void talkToNpc(String npcId) => _apply(() => engine.talkToNpc(game, npcId));

  void endLife(String reason) => _apply(() => engine.endLife(game, reason));

  void concludeChapter() => _apply(() => engine.concludeChapter(game));

  void recordPractice(ChallengeResult result, {String? mockExamId}) =>
      _apply(() => engine.recordPractice(game, result, mockExamId: mockExamId));

  /// Removes and returns queued feedback events for display.
  List<GameEvent> takeFeedback() {
    final items = state.feedback;
    if (items.isEmpty) return const [];
    emit(GameSession(game: state.game, revision: state.revision + 1));
    return items;
  }

  void clearError() {
    if (state.error != null) {
      emit(
        GameSession(
          game: state.game,
          feedback: state.feedback,
          revision: state.revision + 1,
        ),
      );
    }
  }

  Future<SaveSlotMeta> saveTo(String slot, {String? label}) =>
      saves.save(slot, game, label: label);

  Future<bool> loadFrom(String slot) async {
    try {
      final s = await saves.load(slot);
      if (s == null) return false;
      emit(GameSession(game: s, revision: state.revision + 1));
      return true;
    } catch (e) {
      emit(
        GameSession(
          game: state.game,
          error: 'Could not load save: $e',
          revision: state.revision + 1,
        ),
      );
      return false;
    }
  }

  void closeGame() => emit(GameSession(revision: state.revision + 1));
}
