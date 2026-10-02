import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/content/content_validator.dart';
import 'package:lifeverse/engine/puzzles/puzzle.dart';
import 'package:lifeverse/engine/story/story_models.dart';

import '../support/content.dart';

void main() {
  final content = loadContent();

  test('all content passes validation (story graph, references, puzzles)', () {
    final report = ContentValidator.validate(content);
    expect(report.errors, isEmpty, reason: report.toString());
  });

  test('vertical slice content volume meets the milestone', () {
    expect(content.backgrounds.length, greaterThanOrEqualTo(3));
    expect(content.programs.length, greaterThanOrEqualTo(3));
    expect(content.pool('utat').length, greaterThanOrEqualTo(10));
    expect(content.careers.values.where((c) => c.listed).length, greaterThanOrEqualTo(3));
    expect(content.partTimeJobs, isNotEmpty);
    expect(content.npcs.length, greaterThanOrEqualTo(3));
    final storyEvents = content.events.values.where((e) => e.chapter == 1 && !e.isWorldEvent);
    expect(storyEvents.length, greaterThanOrEqualTo(20));
    expect(content.conclusions.values.where((c) => c.chapter == 1).length, greaterThanOrEqualTo(3));
  });

  test('every puzzle answer is consistent with its explanation metadata', () {
    for (final p in content.puzzles.values) {
      if (p.type == PuzzleType.mcq) {
        expect(p.check(p.answer.toInt()), isTrue, reason: p.id);
        final wrong = (p.answer.toInt() + 1) % p.options.length;
        expect(p.check(wrong), isFalse, reason: p.id);
      } else {
        expect(p.check(p.answer), isTrue, reason: p.id);
        expect(p.check('${p.answer}'), isTrue, reason: p.id);
        expect(p.check(p.answer + 1), isFalse, reason: p.id);
      }
    }
  });

  test('the fictional exam is clearly labelled', () {
    final utat = content.exams['utat']!;
    expect(utat.fictional, isTrue);
    expect(utat.disclaimer.toLowerCase(), contains('fictional'));
  });

  test('validator catches a broken branch', () {
    final event = content.events['ev_results_day']!;
    final broken = loadContent();
    final raw = broken.events['ev_results_day']!;
    expect(raw.nodes.keys, containsAll(event.nodes.keys));
    // Simulate an author typo by validating a hand-built event.
    final bad = StoryEvent.fromJson({
      'id': 'ev_bad', 'chapter': 1, 'title': 'Bad', 'location': 'home', 'summary': 's',
      'trigger': {'kind': 'auto'}, 'start': 'a',
      'nodes': {
        'a': {'text': 'x', 'choices': [
          {'id': 'c1', 'label': 'go', 'next': 'missing', 'requires': {'type': 'flag', 'key': 'never_set'}}
        ]},
        'orphan': {'text': 'unreachable'},
      },
    });
    broken.events['ev_bad'] = bad;
    final errors = ContentValidator.validate(broken).errors.join('\n');
    expect(errors, contains('missing node "missing"'));
    expect(errors, contains('"orphan" is unreachable'));
    expect(errors, contains('soft-lock guard'));
    expect(errors, contains('never_set'));
  });
}
