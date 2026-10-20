import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexris/logic/hex_grid_logic.dart';
import 'package:hexris/main.dart';
import 'package:hexris/models/coordinates.dart';
import 'package:hexris/models/game_state.dart';
import 'package:hexris/utils/storage.dart';
import 'package:hexris/widgets/draggable_piece.dart';
import 'package:hexris/widgets/game_screen.dart';
import 'package:hexris/widgets/hex_grid_widget.dart';
import 'package:hexris/widgets/square_grid_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameState gameState(WidgetTester tester) => Provider.of<GameState>(
  tester.element(find.byType(GameScreen)),
  listen: false,
);

/// Drags the first tray piece onto the centre of [board] and drops it there.
Future<void> dragFirstPieceOnto(WidgetTester tester, Finder board) async {
  final from = tester.getCenter(find.byType(DraggablePieceWidget).first);
  final to = tester.getCenter(board);
  final gesture = await tester.startGesture(from);
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(411, 891) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HexrisApp(initialHighScore: 0));
    await tester.pump();
  }

  testWidgets('a rejected drop on the hex board clears the preview', (
    tester,
  ) async {
    await pumpApp(tester);
    final state = gameState(tester);
    // Fill the board, so every drop is invalid.
    for (final cell in HexGridLogic.boardCells) {
      state.hexGrid[cell] = Colors.grey;
    }
    final placedBefore = state.tray.where((p) => p.isPlaced).length;

    await dragFirstPieceOnto(tester, find.byType(HexGridWidget));

    expect(state.tray.where((p) => p.isPlaced).length, placedBefore);
    expect(state.ghostCells, isEmpty);
  });

  testWidgets('a rejected drop on the square board clears the preview', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.square_rounded));
    await tester.pump();
    final state = gameState(tester);
    for (final row in state.squareGrid) {
      row.fillRange(0, row.length, Colors.grey);
    }

    await dragFirstPieceOnto(tester, find.byType(SquareGridWidget));

    expect(state.tray.every((p) => !p.isPlaced), isTrue);
    expect(state.ghostCells, isEmpty);
  });

  testWidgets('a valid drop places the piece and clears the preview', (
    tester,
  ) async {
    await pumpApp(tester);
    final state = gameState(tester);

    await dragFirstPieceOnto(tester, find.byType(HexGridWidget));
    await tester.pump(const Duration(seconds: 1));

    expect(state.hexGrid.keys.whereType<HexCoord>(), isNotEmpty);
    expect(state.ghostCells, isEmpty);
  });
}
