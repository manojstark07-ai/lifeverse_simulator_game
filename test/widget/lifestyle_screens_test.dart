import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeverse/app/feedback_host.dart';

import 'app_flow_test.dart' show boot, createCharacter, tapText;

Future<void> back(WidgetTester tester) async {
  scaffoldMessengerKey.currentState?.clearSnackBars();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byTooltip('Back'));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('shop, creator studio, job portal, makeover and family card all work', (tester) async {
    await boot(tester);
    await createCharacter(tester);
    await tapText(tester, 'Read your marks properly');
    await tapText(tester, "Engineering. I'll sit for the UTAT entrance exam in July.");
    await tapText(tester, "Say you'll see how the week goes.");

    // Shop: buy a budget phone, then see it under "Yours".
    await tapText(tester, 'Shop & lifestyle');
    await tapText(tester, 'Phones');
    expect(find.text('PearPhone 17 Pro Max'), findsOneWidget);
    await tapText(tester, 'Buy');
    expect(find.text('Owned'), findsOneWidget);
    await tapText(tester, 'Vehicles');
    expect(find.textContaining('A driving licence'), findsWidgets);
    await tapText(tester, 'Yours');
    expect(find.text('Kiwi Note 13'), findsOneWidget);
    await back(tester);

    // Creator Studio: launch a channel and upload a video.
    await tapText(tester, 'Creator Studio');
    await tester.enterText(find.byType(TextField), 'Chai & Chaos');
    await tester.pump();
    await tapText(tester, 'Comedy sketches');
    await tapText(tester, 'Launch channel');
    expect(find.text('Chai & Chaos'), findsOneWidget);
    await tapText(tester, 'Film & upload  (−20 energy)');
    expect(find.textContaining('views ·'), findsOneWidget);
    await back(tester);

    // Job portal: no-degree careers are listed with their requirements.
    await tapText(tester, 'Career & jobs');
    expect(find.text('Chef'), findsOneWidget);
    expect(find.text('No degree needed'), findsWidgets);
    expect(find.textContaining('Finish or leave your course first'), findsNothing);
    await back(tester);

    // People: the family card.
    await tester.tap(find.text('People').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Family & love'), findsOneWidget);

    // City: the salon offers a makeover.
    await tester.tap(find.text('City').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tapText(tester, 'Glow & Go Salon');
    await tapText(tester, 'Book a makeover');
    expect(find.text('New look'), findsOneWidget);
    await tapText(tester, 'Curly');
    await tapText(tester, 'Book it — ₹1,500');
    expect(find.text('Salon makeover'), findsNothing);
  });
}
