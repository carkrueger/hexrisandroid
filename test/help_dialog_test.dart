import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexris/main.dart';
import 'package:hexris/utils/storage.dart';
import 'package:hexris/widgets/help_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openHelp(
  WidgetTester tester,
  Size logicalSize,
  GameRules rules,
) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = logicalSize * 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(HexrisApp(initialHighScore: 0, initialRules: rules));
  await tester.pump();
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  await tester.tap(find.text('How to Play'));
  await tester.pumpAndSettle();
}

/// The "current" badge next to the section titled [title], if any.
Finder currentBadgeIn(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
  matching: find.text('current'),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  testWidgets('explains the goal and both rulesets', (tester) async {
    await openHelp(tester, const Size(411, 891), GameRules.modern);

    expect(find.byType(HelpDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final title in ['Goal', 'Playing', 'Boards', 'Modern rules']) {
      expect(find.text(title), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('Switching rules'),
      200,
      scrollable: find.descendant(
        of: find.byType(HelpDialog),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Classic rules'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpDialog), findsNothing);
  });

  testWidgets('marks the modern ruleset as current', (tester) async {
    await openHelp(tester, const Size(800, 1280), GameRules.modern);
    expect(currentBadgeIn('Modern rules'), findsOneWidget);
    expect(find.text('current'), findsOneWidget);
  });

  testWidgets('marks the classic ruleset as current', (tester) async {
    await openHelp(tester, const Size(800, 1280), GameRules.classic);
    final classicTitle = find.descendant(
      of: find.byType(HelpDialog),
      matching: find.text('Classic rules'),
    );
    expect(
      find.descendant(
        of: find.ancestor(of: classicTitle, matching: find.byType(Row)).first,
        matching: find.text('current'),
      ),
      findsOneWidget,
    );
    expect(find.text('current'), findsOneWidget);
  });
}
