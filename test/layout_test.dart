import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexris/main.dart';
import 'package:hexris/painters/hex_grid_painter.dart';
import 'package:hexris/painters/square_grid_painter.dart';
import 'package:hexris/utils/storage.dart';
import 'package:hexris/widgets/draggable_piece.dart';
import 'package:hexris/widgets/hex_grid_widget.dart';
import 'package:hexris/widgets/piece_tray.dart';
import 'package:hexris/widgets/square_grid_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen sizes in logical pixels.
const phonePortrait = Size(411, 891);
const tabletPortrait = Size(800, 1280);
const tabletLandscape = Size(1280, 800);
const phoneLandscapeSplit = Size(891, 411);

Future<void> pumpAppAt(WidgetTester tester, Size logicalSize) async {
  const dpr = 2.625;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = logicalSize * dpr;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const HexrisApp(initialHighScore: 0));
  await tester.pump();
}

/// Cell size the board paints with, read from its painter.
double boardCellSize(WidgetTester tester) {
  final hex = find.descendant(
    of: find.byType(HexGridWidget),
    matching: find.byType(CustomPaint),
  );
  if (hex.evaluate().isNotEmpty) {
    final paint = tester.widget<CustomPaint>(hex.first);
    return (paint.painter! as HexGridPainter).hexSize;
  }
  final square = find.descendant(
    of: find.byType(SquareGridWidget),
    matching: find.byType(CustomPaint),
  );
  final paint = tester.widget<CustomPaint>(square.first);
  return (paint.painter! as SquareGridPainter).cellSize;
}

void expectBoardAndTray(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(
    find.byType(HexGridWidget).evaluate().length +
        find.byType(SquareGridWidget).evaluate().length,
    1,
    reason: 'exactly one board is shown',
  );
  expect(find.byType(PieceTray), findsOneWidget);
  expect(find.byType(DraggablePieceWidget), findsNWidgets(3));

  // The tray (and so the drag feedback) uses the board's own cell size.
  final tray = tester.widget<PieceTray>(find.byType(PieceTray));
  expect(tray.gridCellSize, moreOrLessEquals(boardCellSize(tester)));
  expect(tray.gridCellSize, greaterThan(0));

  // Board and tray pieces lie inside the screen.
  final screen = Offset.zero & tester.view.physicalSize /
      tester.view.devicePixelRatio;
  for (final finder in [
    find.byType(HexGridWidget),
    find.byType(SquareGridWidget),
    find.byType(DraggablePieceWidget),
  ]) {
    final count = finder.evaluate().length;
    for (var i = 0; i < count; i++) {
      final rect = tester.getRect(finder.at(i));
      expect(
        screen.inflate(0.5).contains(rect.topLeft) &&
            screen.inflate(0.5).contains(rect.bottomRight),
        isTrue,
        reason: '$finder #$i at $rect is off screen',
      );
    }
  }
}

List<Offset> trayPieceCentres(WidgetTester tester) {
  final pieces = find.byType(DraggablePieceWidget);
  return [
    for (var i = 0; i < pieces.evaluate().length; i++)
      tester.getCenter(pieces.at(i)),
  ];
}

void expectHorizontalTray(WidgetTester tester) {
  final tray = tester.widget<PieceTray>(find.byType(PieceTray));
  expect(tray.direction, Axis.horizontal);
  final centres = trayPieceCentres(tester);
  for (var i = 1; i < centres.length; i++) {
    expect(centres[i].dx, greaterThan(centres[i - 1].dx));
  }
}

void expectVerticalTray(WidgetTester tester) {
  final tray = tester.widget<PieceTray>(find.byType(PieceTray));
  expect(tray.direction, Axis.vertical);
  final centres = trayPieceCentres(tester);
  for (var i = 1; i < centres.length; i++) {
    expect(centres[i].dy, greaterThan(centres[i - 1].dy));
    expect(centres[i].dx, moreOrLessEquals(centres[0].dx, epsilon: 1));
  }
  // The side panel is to the right of the board.
  final board = find.byType(HexGridWidget).evaluate().isNotEmpty
      ? find.byType(HexGridWidget)
      : find.byType(SquareGridWidget);
  final boardRect = tester.getRect(board);
  for (final c in centres) {
    expect(c.dx, greaterThan(boardRect.right));
  }
}

Future<void> switchToSquareMode(WidgetTester tester) async {
  // The mode toggle in the header shows the icon of the other mode.
  await tester.tap(find.byIcon(Icons.square_rounded));
  await tester.pump();
  expect(find.byType(SquareGridWidget), findsOneWidget);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  for (final mode in ['hex', 'square']) {
    group('$mode mode', () {
      Future<void> pumpMode(WidgetTester tester, Size size) async {
        await pumpAppAt(tester, size);
        if (mode == 'square') await switchToSquareMode(tester);
      }

      testWidgets('phone portrait uses the tall layout', (tester) async {
        await pumpMode(tester, phonePortrait);
        expectBoardAndTray(tester);
        expectHorizontalTray(tester);
      });

      testWidgets('tablet portrait uses the tall layout', (tester) async {
        await pumpMode(tester, tabletPortrait);
        expectBoardAndTray(tester);
        expectHorizontalTray(tester);
      });

      testWidgets('tablet landscape uses the side panel', (tester) async {
        await pumpMode(tester, tabletLandscape);
        expectBoardAndTray(tester);
        expectVerticalTray(tester);
      });

      testWidgets('short wide window (split-screen) uses the side panel', (
        tester,
      ) async {
        await pumpMode(tester, phoneLandscapeSplit);
        expectBoardAndTray(tester);
        expectVerticalTray(tester);
      });
    });
  }

  testWidgets('layout switches when the window is resized', (tester) async {
    await pumpAppAt(tester, tabletPortrait);
    expectHorizontalTray(tester);

    tester.view.physicalSize = tabletLandscape * tester.view.devicePixelRatio;
    await tester.pump();
    expectBoardAndTray(tester);
    expectVerticalTray(tester);

    tester.view.physicalSize = tabletPortrait * tester.view.devicePixelRatio;
    await tester.pump();
    expectBoardAndTray(tester);
    expectHorizontalTray(tester);
  });
}
