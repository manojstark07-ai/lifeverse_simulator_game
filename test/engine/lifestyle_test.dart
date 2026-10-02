import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/core/game_calendar.dart';
import 'package:lifeverse/engine/creator/creator_service.dart';
import 'package:lifeverse/engine/effects/effect.dart';
import 'package:lifeverse/engine/effects/effect_resolver.dart';
import 'package:lifeverse/engine/engine_context.dart';
import 'package:lifeverse/engine/game_engine.dart';
import 'package:lifeverse/engine/game_state.dart';
import 'package:lifeverse/engine/lifestyle/lifestyle_service.dart';
import 'package:lifeverse/engine/puzzles/puzzle.dart';
import 'package:lifeverse/engine/time/life_simulation.dart';

import '../support/autoplayer.dart';
import '../support/content.dart';

void main() {
  final content = loadContent();
  final engine = GameEngine(content);

  /// A quiet life: no story event open or due, so menu commands are allowed
  /// back to back.
  GameState free({int cash = 50000, int salary = 0, int day = 400}) {
    final s = newGame(engine).clone()
      ..day = day
      ..chapter = 99
      ..story.activeEventId = null
      ..story.activeNodeId = null;
    s.story.completed.addAll(content.events.keys);
    s.finance.cash = cash;
    s.career.monthlySalary = salary;
    return s;
  }

  void apply(EngineContext ctx, List<Map<String, dynamic>> effects) =>
      EffectResolver.applyAll(ctx, effects.map(Effect.fromJson).toList());

  ChallengeResult answers(List<Puzzle> puzzles, {required bool correct}) => ChallengeResult([
        for (final p in puzzles) PuzzleAnswer(puzzleId: p.id, response: null, correct: correct, secondsTaken: 20),
      ]);

  group('shopping', () {
    test('buying a phone costs cash; upgrading trades in the old one', () {
      var s = engine.buyItem(free(cash: 200000), 'kiwi_note').state;
      expect(s.owns('kiwi_note'), isTrue);
      expect(s.finance.cash, 200000 - 11999);
      s = engine.buyItem(s, 'pearphone_17').state;
      expect(s.owns('pearphone_17'), isTrue);
      expect(s.owns('kiwi_note'), isFalse, reason: 'same slot is traded in');
      expect(s.finance.transactions.any((t) => t.label.startsWith('Trade-in')), isTrue);
    });

    test('vehicles need a driving licence, earned through four lessons', () {
      var s = free(cash: 200000);
      expect(() => engine.buyItem(s, 'zippy_scooter'), throwsA(isA<RuleViolation>()));
      for (var i = 0; i < 4; i++) {
        s = engine.performAction(s, 'motors_lessons').state;
      }
      expect(s.flags, contains('driving_licence'));
      s = engine.buyItem(s, 'zippy_scooter').state;
      expect(s.owns('zippy_scooter'), isTrue);
    });

    test('financing checks income, takes a loan and charges upkeep monthly', () {
      final poor = free(cash: 300000)..flags.add('driving_licence');
      expect(LifestyleService.buyBlocker(poor, content, content.shopItems['kestrel_hatch']!, finance: true),
          contains('more than half your income'));

      final s0 = free(cash: 300000, salary: 60000)..flags.add('driving_licence');
      final s = engine.buyItem(s0, 'kestrel_hatch', finance: true).state;
      final loan = s.finance.loans.single;
      expect(loan.productId, 'car_loan');
      expect(loan.principalDisbursed, LifestyleService.loanAmount(content.shopItems['kestrel_hatch']!, content));
      expect(s.finance.cash, 300000 - (690000 - loan.principalDisbursed));

      final ctx = EngineContext(s.clone(), content);
      final before = ctx.s.finance.cash;
      LifeSimulation.settleMonth(ctx, GameCalendar.monthKeyOfDay(ctx.s.day));
      expect(ctx.s.finance.transactions.any((t) => t.label.contains('Fuel, insurance & service')), isTrue);
      expect(ctx.s.finance.cash, lessThan(before));
    });

    test('a vehicle shortens the commute in the weekly budget', () {
      final s = free(cash: 200000, salary: 30000)
        ..flags.add('driving_licence')
        ..career.careerId = 'electrician';
      final before = RoutineBudget.of(s, content).commitments;
      final after = RoutineBudget.of(engine.buyItem(s, 'zippy_scooter').state, content).commitments;
      expect(after, lessThan(before));
    });

    test('selling a financed item repays its loan first', () {
      final s0 = free(cash: 300000, salary: 60000)..flags.add('driving_licence');
      final bought = engine.buyItem(s0, 'kestrel_hatch', finance: true).state;
      final sold = engine.sellItem(bought, bought.possessions.single.uid).state;
      expect(sold.possessions, isEmpty);
      expect(sold.finance.loans.single.closed, isTrue);
    });

    test('property removes rent and appreciates; cars depreciate', () {
      final flat = content.shopItems['flat_1bhk']!;
      final s = free(cash: 2000000, salary: 150000, day: 365 * 4);
      final owner = engine.buyItem(s, 'flat_1bhk', finance: true).state;
      expect(owner.flags, containsAll(['homeowner', 'living_independently']));
      final renter = s.clone()..flags.add('living_independently');
      expect(LifeSimulation.livingCost(owner, content), lessThan(LifeSimulation.livingCost(renter, content)));

      final o = owner.possessions.single;
      expect(LifestyleService.currentValue(o, flat, o.boughtDay + 365 * 3), greaterThan(flat.price));
      final car = content.shopItems['kestrel_hatch']!;
      expect(LifestyleService.currentValue(o, car, o.boughtDay + 365 * 3), lessThan(o.pricePaid));
    });

    test('memberships cost a monthly fee and unlock free workouts', () {
      var s = free();
      expect(engine.actionsAt(s, 'gym').map((a) => a.id), contains('gym_daypass'));
      s = engine.buyItem(s, 'gym_membership').state;
      expect(engine.actionsAt(s, 'gym').map((a) => a.id), allOf(contains('gym_workout'), isNot(contains('gym_daypass'))));
      expect(LifestyleService.monthlyUpkeep(s, content), 1500);
    });

    test('a salon makeover changes the avatar but not the skin tone', () {
      final s = free();
      final look = s.profile.appearance.copyWith(hairStyle: (s.profile.appearance.hairStyle + 1) % 5);
      final after = engine.makeover(s, look).state;
      expect(after.profile.appearance.hairStyle, look.hairStyle);
      expect(after.finance.cash, s.finance.cash - LifestyleService.makeoverCost);
      expect(after.stat('looks'), greaterThan(s.stat('looks')));
      expect(() => engine.makeover(s, s.profile.appearance.copyWith(skinTone: (s.profile.appearance.skinTone + 1) % 6)),
          throwsA(isA<RuleViolation>()));
      expect(() => engine.makeover(s, s.profile.appearance), throwsA(isA<RuleViolation>()), reason: 'nothing changed');
    });
  });

  group('habits and health', () {
    test('smoking and drinking erode health every month', () {
      final clean = free().clone();
      final habits = free().clone()..flags.addAll(['smoker', 'heavy_drinker']);
      for (final s in [clean, habits]) {
        final ctx = EngineContext(s, content);
        for (var m = 0; m < 6; m++) {
          LifeSimulation.settleMonth(ctx, s.lastSettledMonthKey + 1);
        }
      }
      expect(habits.stat('health'), lessThan(clean.stat('health') - 10));
    });

    test('a counselling programme ends a drinking habit', () {
      var s = free(cash: 20000)..flags.add('heavy_drinker');
      for (var i = 0; i < 4; i++) {
        s = engine.performAction(s, 'hosp_counselling').state;
      }
      expect(s.flags, isNot(contains('heavy_drinker')));
      expect(s.flags, contains('sober'));
    });
  });

  group('creator', () {
    test('uploads grow a channel; monetisation pays ad revenue', () {
      var s = engine.startChannel(free(), 'comedy', 'Chai & Chaos').state;
      expect(s.creator!.channelName, 'Chai & Chaos');
      expect(() => engine.startChannel(s, 'tech', 'Second'), throwsA(isA<RuleViolation>()));
      s = engine.uploadVideo(s).state;
      expect(s.creator!.videos, 1);
      expect(s.creator!.totalViews, greaterThan(0));
      expect(s.skill('content'), greaterThan(5));

      final big = s.clone()
        ..creator!.subscribers = 50000
        ..creator!.totalViews = 2000000
        ..creator!.lastUploadDay = s.day;
      final ctx = EngineContext(big, content);
      LifeSimulation.settleMonth(ctx, big.lastSettledMonthKey + 1);
      expect(big.creator!.monetized, isTrue);
      expect(big.flags, contains('creator_monetized'));
      big.creator!.monthViews = 300000;
      LifeSimulation.settleMonth(ctx, big.lastSettledMonthKey + 1);
      expect(big.finance.transactions.any((t) => t.label == 'ViewTube ad revenue'), isTrue);
      expect(big.stat('fame'), greaterThan(40));
    });

    test('going full-time needs no job, adds working hours and uploads automatically', () {
      var s = engine.startChannel(free(), 'cooking', 'Dal Diaries').state;
      final employed = s.clone()..career.careerId = 'electrician';
      expect(() => engine.setCreatorFullTime(employed, true), throwsA(isA<RuleViolation>()));
      s = engine.setCreatorFullTime(s, true).state;
      expect(RoutineBudget.of(s, content).commitmentLines.keys, contains('Filming & editing'));
      final ctx = EngineContext(s.clone(), content);
      LifeSimulation.settleMonth(ctx, ctx.s.lastSettledMonthKey + 1);
      expect(ctx.s.creator!.videos, CreatorService.fullTimeUploadsPerMonth);
    });
  });

  group('job portal', () {
    test('anyone with the skill can interview as a chef; success hires', () {
      var s = free()..skills['cooking'] = 40;
      expect(engine.applicationBlocker(s, 'chef'), isNull);
      final puzzles = engine.interviewPuzzles(s, 'chef');
      expect(puzzles, hasLength(3));
      s = engine.applyForJob(s, 'chef', answers(puzzles, correct: true)).state;
      expect(s.career.careerId, 'chef');
      expect(s.career.employer, isNotNull);
      s = engine.quitJob(s).state;
      expect(s.career.hasCareer, isFalse);
      expect(s.career.history.last, startsWith('Resigned'));
    });

    test('a failed interview starts a cooldown', () {
      var s = free()..skills['cooking'] = 21;
      s = engine.applyForJob(s, 'chef', answers(engine.interviewPuzzles(s, 'chef'), correct: false)).state;
      expect(s.career.hasCareer, isFalse);
      expect(engine.applicationBlocker(s, 'chef'), contains('reapply'));
    });

    test('requirements are enforced: degrees, vehicles, skills', () {
      final s = free();
      expect(engine.applicationBlocker(s, 'bank_po'), startsWith('Needs'));
      expect(engine.applicationBlocker(s, 'delivery_partner'), contains('scooter or motorcycle'));
      expect(engine.applicationBlocker(s, 'hair_stylist'), contains('Hair & styling'));
      final rider = s.clone()..flags.add('driving_licence');
      expect(engine.applicationBlocker(engine.buyItem(rider..finance.cash = 100000, 'zippy_scooter').state, 'delivery_partner'),
          isNull);
    });
  });

  group('household', () {
    test('dating → engaged → married, with a spouse sharing the bills', () {
      final s = free();
      final ctx = EngineContext(s, content);
      apply(ctx, [
        {'type': 'partner', 'npc': 'divya', 'status': 'dating'},
        {'type': 'relationship', 'npc': 'partner', 'affinity': 5},
      ]);
      expect(s.household.partnerId, 'divya');
      expect(s.relationships['divya']!.met, isTrue);
      apply(ctx, [{'type': 'partnerStatus', 'status': 'engaged'}]);
      expect(s.flags, contains('engaged'));
      apply(ctx, [{'type': 'partnerStatus', 'status': 'married'}]);
      expect(s.household.isMarried, isTrue);
      expect(s.flags, isNot(contains('engaged')));

      LifeSimulation.settleMonth(ctx, s.lastSettledMonthKey + 1);
      expect(s.finance.transactions.any((t) => t.label == "Spouse's share of bills"), isTrue);
    });

    test('children cost money every month; divorce ends a marriage', () {
      final s = free(cash: 100000);
      final ctx = EngineContext(s, content);
      apply(ctx, [
        {'type': 'partner', 'npc': 'rohan', 'status': 'married'},
        {'type': 'haveChild', 'name': 'auto'},
      ]);
      expect(s.household.children.single.name, isNotEmpty);
      expect(s.flags, contains('parent'));
      LifeSimulation.settleMonth(ctx, s.lastSettledMonthKey + 1);
      expect(s.finance.transactions.any((t) => t.label.contains('childcare')), isTrue);

      apply(ctx, [{'type': 'partnerStatus', 'status': 'single'}]);
      expect(s.household.partnerId, isNull);
      expect(s.household.divorces, 1);
      expect(s.household.exes, contains('rohan'));
      expect(s.flags, containsAll(['divorced']));
      expect(s.flags, isNot(contains('married')));
    });

    test('relationship effects aimed at a missing partner are skipped safely', () {
      final s = free();
      final ctx = EngineContext(s, content);
      apply(ctx, [{'type': 'relationship', 'npc': 'partner', 'affinity': 5}]);
      expect(ctx.outcomes, isEmpty);
    });
  });

  test('the arranged-marriage arc reaches an engagement, a wedding and children', () {
    const picks = {
      'ev_l_arranged': 'c_divya',
      'ev_l_arranged_answer': 'c_yes',
      'ev_l_wedding/start': 'c_temple',
      'ev_l_wedding/married': 'c_goa',
      'ev_l_kids': 'c_try',
      'ev_l_baby': 'c_a',
      'ev_l_second_child': 'c_yes',
    };
    final violations = <String>[];
    final p = AutoPlayer(engine,
        accuracy: 0.7,
        seed: 3,
        picker: (v, s) => picks['${v.event.id}/${v.node.id}'] ?? picks[v.event.id],
        onStep: (a, b) => violations.addAll(invariantViolations(a, b)));
    var s = p.playChapter(newGame(engine, seed: 51));
    final end = s.day + 365 * 12;
    while (s.day < end) {
      s = p.step(s);
    }
    expect(violations, isEmpty);
    expect(s.household.status, 'married');
    expect(s.household.partnerId, 'divya');
    expect(s.household.children, hasLength(2));
    expect(s.achievements.keys, containsAll(['just_married', 'parent', 'full_house']));
    expect(s.relationships['divya']!.memories.map((m) => m.tag), containsAll(['engaged', 'wedding']));
  });

  test('a decade of adult life keeps every invariant and never soft-locks', () {
    for (var seed = 1; seed <= 6; seed++) {
      final violations = <String>[];
      final p = AutoPlayer(engine, accuracy: 0.7, seed: seed, onStep: (a, b) => violations.addAll(invariantViolations(a, b)));
      var s = p.playChapter(newGame(engine, seed: seed * 17));
      expect(s.chapter, 2, reason: 'seed $seed');
      // Give each adult life some possessions so lifestyle events can fire.
      s = s.clone()
        ..flags.add('driving_licence')
        ..finance.cash += 1000000;
      for (final item in ['kestrel_hatch', 'pearphone_17']) {
        while (s.story.inEvent) {
          s = p.step(s);
        }
        s = engine.buyItem(s, item).state;
      }
      final end = s.day + 365 * 10;
      while (s.day < end) {
        s = p.step(s);
      }
      expect(violations, isEmpty, reason: 'seed $seed: $violations');
      expect(s.story.inEvent && s.story.activeNodeId == null, isFalse);
    }
  });
}
