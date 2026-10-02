import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/story/story_engine.dart';

import '../support/autoplayer.dart';
import '../support/content.dart';

String? prefer(NodeView v, GameState s, Map<String, String> byEvent) => byEvent[v.event.id];

void main() {
  final content = loadContent();
  final engine = GameEngine(content);

  AutoPlayer player({double accuracy = 1, Map<String, String> picks = const {}, int seed = 7, List<String>? violations}) =>
      AutoPlayer(engine,
          accuracy: accuracy,
          seed: seed,
          picker: (v, s) => picks['${v.event.id}/${v.node.id}'] ?? picks[v.event.id],
          onStep: violations == null ? null : (a, b) => violations.addAll(invariantViolations(a, b)));

  test('engineering path: strong exam → government college → software developer', () {
    final violations = <String>[];
    final p = player(violations: violations, picks: {
      'ev_results_day/amma': 'c_engineering',
      'ev_exam_results/gov': 'c_accept_gov',
      'ev_exam_results/private': 'c_accept_private',
      'ev_bank_fees': 'c_loan',
      'ev_final_crossroads': 'c_home',
      'ev_job_interview': 'c_sw',
      'ev_interview_retry': 'c_sw',
      'ev_money_crisis': 'c_loan',
      'ev_fixlab_launch': 'c_jobs',
    });
    final end = p.playChapter(newGame(engine, seed: 101));
    expect(violations, isEmpty);
    expect(end.chapter, 2);
    expect(end.exams['utat']!.attempts.first.tierId, 'government');
    expect(end.education.completedPrograms, contains('btech_cs'));
    expect(end.career.careerId, 'software_developer');
    expect(end.conclusionId, 'c1_first_commit');
    expect(end.decisions.length, greaterThan(15));
  });

  test('commerce path ends as an accountant', () {
    final violations = <String>[];
    final end = player(violations: violations, picks: {
      'ev_results_day/amma': 'c_commerce',
      'ev_admissions': 'c_bcom',
      'ev_bank_fees': 'c_self',
      'ev_job_interview': 'c_acc',
      'ev_interview_retry': 'c_acc',
      'ev_final_crossroads': 'c_home',
      'ev_fixlab_launch': 'c_jobs',
    }).playChapter(newGame(engine, background: 'affluent_business', seed: 5));
    expect(violations, isEmpty);
    expect(end.career.careerId, 'accountant');
    expect(end.conclusionId, 'c1_balanced_books');
  });

  test('trade path ends as an electrician, in about two years', () {
    final violations = <String>[];
    final end = player(violations: violations, picks: {
      'ev_results_day/amma': 'c_trade',
      'ev_admissions': 'c_iti',
      'ev_job_interview': 'c_elec',
      'ev_interview_retry': 'c_elec',
      'ev_final_crossroads': 'c_home',
      'ev_fixlab_launch': 'c_jobs',
    }).playChapter(newGame(engine, background: 'rural_farming', seed: 9));
    expect(violations, isEmpty);
    expect(end.career.careerId, 'electrician');
    expect(end.conclusionId, 'c1_live_wire');
    expect(end.day, lessThan(365 * 3 + 60));
  });

  test('failing the entrance exam twice still leads to a complete chapter', () {
    final violations = <String>[];
    final end = player(accuracy: 0, violations: violations, picks: {
      'ev_results_day/amma': 'c_engineering',
      'ev_exam_results/none': 'c_retake',
      'ev_retake_results/none': 'c_trade',
      'ev_retake_results/private': 'c_trade',
      'ev_job_interview': 'c_elec',
      'ev_interview_retry': 'c_other',
      'ev_admissions': 'c_iti',
    }).playChapter(newGame(engine, seed: 77));
    expect(violations, isEmpty);
    expect(end.exams['utat']!.attempts.length, 2);
    expect(end.flags, contains('took_drop_year'));
    expect(end.chapter, 2);
    expect(end.achievements, contains('second_wind'));
  });

  test('random playthroughs across many seeds never break invariants or soft-lock', () {
    for (var seed = 1; seed <= 24; seed++) {
      final violations = <String>[];
      final bg = ['rural_farming', 'urban_lower_middle', 'affluent_business'][seed % 3];
      final p = player(accuracy: (seed % 5) / 4, seed: seed, violations: violations);
      final end = p.playChapter(newGame(engine, background: bg, seed: seed * 31), maxDays: 365 * 9);
      expect(violations, isEmpty, reason: 'seed $seed: $violations');
      expect(end.chapter, 2, reason: 'seed $seed stalled at day ${end.day} (${end.story.activeEventId}) '
          'edu=${end.education.status} career=${end.career.careerId} flags=${end.flags}');
      expect(content.conclusions.containsKey(end.conclusionId), isTrue);
    }
  });

  test('simulation is deterministic for a seed and choice sequence', () {
    String run() => jsonEncode(player(accuracy: 0.6, seed: 3).playChapter(newGame(engine, seed: 1234)).toJson());
    expect(run(), run());
  });

  test('a different seed produces a different life', () {
    final a = player(accuracy: 0.6, seed: 3).playChapter(newGame(engine, seed: 1));
    final b = player(accuracy: 0.6, seed: 3).playChapter(newGame(engine, seed: 2));
    expect(jsonEncode(a.toJson()), isNot(jsonEncode(b.toJson())));
  });

  test('the game continues after chapter 1 with salary and promotions', () {
    var s = player(picks: {
      'ev_results_day/amma': 'c_trade',
      'ev_admissions': 'c_iti',
      'ev_job_interview': 'c_elec',
      'ev_interview_retry': 'c_elec',
      'ev_fixlab_launch': 'c_jobs',
    }).playChapter(newGame(engine, background: 'urban_lower_middle', seed: 11));
    expect(s.chapter, 2);
    final cashAtStart = s.finance.cash;
    final p = player();
    for (var i = 0; i < 30 * 3; i++) {
      s = p.step(s);
    }
    expect(s.career.monthsInCareer, greaterThan(24));
    expect(s.finance.cash, greaterThan(cashAtStart));
  });
}
