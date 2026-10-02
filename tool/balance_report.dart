// Headless balance report: plays many randomised lives through chapter 1
// and prints outcome distributions. Run: flutter test tool/balance_report.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/engine/core/game_calendar.dart';
import 'package:lifeverse/engine/game_engine.dart';

import '../test/support/autoplayer.dart';
import '../test/support/content.dart';

void main() {
  test('balance report', () {
    final content = loadContent();
    final engine = GameEngine(content);
    final endings = <String, int>{};
    final rows = <String>[];
    for (var seed = 1; seed <= 60; seed++) {
      final bg = ['rural_farming', 'urban_lower_middle', 'affluent_business'][seed % 3];
      final accuracy = [0.3, 0.6, 0.9][seed % 3 == 0 ? 2 : (seed % 2)];
      final s = AutoPlayer(engine, accuracy: accuracy, seed: seed)
          .playChapter(engine.newGame(spec(background: bg, seed: seed * 17)).state);
      endings[s.conclusionId!] = (endings[s.conclusionId!] ?? 0) + 1;
      rows.add('${bg.padRight(19)} acc=$accuracy age=${GameCalendar.ageOn(s.profile.birthDate, s.day)} '
          'end=${s.conclusionId!.padRight(18)} cash=${s.finance.cash.toString().padLeft(7)} '
          'debt=${s.finance.totalDebt.toString().padLeft(7)} cgpa=${s.education.cgpa.toStringAsFixed(1)} '
          'K=${s.stat('knowledge').round()} WB=${s.stat('wellbeing').round()} credit=${s.finance.creditScore} '
          'arrearsMo=${s.finance.monthsInArrears} ach=${s.achievements.length}');
    }
    // ignore: avoid_print
    print(rows.join('\n'));
    // ignore: avoid_print
    print(endings);
  });
}
