import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/app/app.dart';
import 'package:lifeverse/app/di.dart';
import 'package:lifeverse/app/feedback_host.dart';
import 'package:lifeverse/data/save_repository.dart';
import 'package:lifeverse/data/settings_repository.dart';
import 'package:lifeverse/engine/game_state.dart';

import '../support/content.dart';

final content = loadContent();

Future<InMemorySaveRepository> boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final saves = InMemorySaveRepository();
  await configureDependencies(content: content, saves: saves, settings: InMemorySettingsRepository());
  await tester.pumpWidget(const LifeverseApp(initialSettings: AppSettings(reducedMotion: true)));
  await tester.pump(const Duration(milliseconds: 300));
  return saves;
}

Future<void> tapText(WidgetTester tester, String text) async {
  // Floating toasts time out after a few seconds for players; clear them so
  // they don't cover buttons in fast-running tests.
  scaffoldMessengerKey.currentState?.clearSnackBars();
  await tester.pump(const Duration(milliseconds: 300));
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> confirmDialog(WidgetTester tester, String text) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(text).last);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> createCharacter(WidgetTester tester) async {
  await tapText(tester, 'Begin a new life');
  await tester.enterText(find.byType(TextField), 'Meera');
  await tester.pump();
  await tapText(tester, 'Next');
  await tapText(tester, 'Chennai');
  await tapText(tester, 'City lower-middle-class family');
  await tapText(tester, 'Next');
  await tapText(tester, 'Curious');
  await tapText(tester, 'Next');
  await tapText(tester, 'Mastery of a craft');
  await tapText(tester, 'Next');
  expect(find.text('Meera'), findsOneWidget);
  await tapText(tester, 'Begin life at 18');
}

void main() {
  testWidgets('title → character creation → first story event → hub', (tester) async {
    await boot(tester);
    expect(find.text('LIFEVERSE'), findsOneWidget);
    await createCharacter(tester);

    // The hub immediately opens the first story event.
    expect(find.text('Results Day'), findsOneWidget);
    await tapText(tester, 'Read your marks properly');
    expect(find.textContaining('Which door, kanna?'), findsOneWidget);
    await tapText(tester, "Engineering. I'll sit for the UTAT entrance exam in July.");
    expect(find.textContaining('rivals AND study partners'), findsOneWidget);
    await tapText(tester, "Promise you'll be there.");
    expect(find.text('What changed'), findsNothing); // event ended → back to hub

    expect(find.textContaining('Prepare for UTAT'), findsOneWidget);
    expect(find.text('2 of 2 activities left today'), findsOneWidget);
    await tapText(tester, 'Do');
    expect(find.text('1 of 2 activities left today'), findsOneWidget);
  });

  testWidgets('story puzzle challenge: solve, review the explanation, continue', (tester) async {
    await boot(tester);
    await createCharacter(tester);
    await tapText(tester, 'Read your marks properly');
    await tapText(tester, 'Commerce. A B.Com, and a path into accounting.');
    await tapText(tester, "Say you'll see how the week goes.");

    // Skip ahead: the household-notebook event fires on day 3.
    await tapText(tester, 'Skip a week');
    expect(find.text('The Household Notebook'), findsOneWidget);
    await tapText(tester, 'Thank her, and promise to make the money count.');

    // Back at the hub; the library event fires on day 7.
    await tapText(tester, 'Skip a week');
    expect(find.text('The Community Library'), findsOneWidget);
    await tapText(tester, 'Listen');
    await tapText(tester, 'Walk up to the board and try it.');

    // Puzzle session.
    expect(find.text('Question 1 of 1'), findsOneWidget);
    await tapText(tester, 'Submit');
    await confirmDialog(tester, 'Submit');
    expect(find.text('Result'), findsOneWidget);
    expect(find.textContaining('Your answer: Skipped'), findsOneWidget);
    await tapText(tester, 'Continue');

    expect(find.textContaining('Wrong, and wonderfully so'), findsOneWidget);
    expect(find.text('What changed'), findsOneWidget);
  });

  testWidgets('practice in the Exam Centre and save/load a manual slot', (tester) async {
    final saves = await boot(tester);
    await createCharacter(tester);
    await tapText(tester, 'Read your marks properly');
    await tapText(tester, "Engineering. I'll sit for the UTAT entrance exam in July.");
    await tapText(tester, "Say you'll see how the week goes.");

    await tapText(tester, 'Exam Centre');
    expect(find.textContaining('fictional exam'), findsWidgets);
    await tapText(tester, 'Practice (3 questions)');
    expect(find.text('Question 1 of 3'), findsOneWidget);
    await tapText(tester, 'Skip');
    await tapText(tester, 'Skip');
    await tapText(tester, 'Submit');
    await confirmDialog(tester, 'Submit');
    expect(find.textContaining('Learning rewards are given'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('Practice puzzles solved: 0/10 · Mock tests: 0'), findsWidgets);
    scaffoldMessengerKey.currentState?.clearSnackBars();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Back'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.ensureVisible(find.byTooltip('Save game'));
    await tester.pump();
    await tester.tap(find.byTooltip('Save game'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tapText(tester, 'Save here');
    await tester.enterText(find.byType(TextField), 'After practice');
    await confirmDialog(tester, 'Save');
    await tester.pump(const Duration(milliseconds: 500));
    final saved = await tester.runAsync<GameState?>(() => saves.load("slot1"));
    expect(saved, isNotNull);
    expect(saved!.counter('practiceSessions'), 1);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('After practice'), findsOneWidget);
  });
}
