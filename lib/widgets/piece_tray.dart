import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../utils/constants.dart';
import 'draggable_piece.dart';

/// The three pieces the player can drag onto the board.
///
/// [direction] is [Axis.horizontal] for the tall (phone) layout, where the
/// tray is a [LayoutConstants.trayHeight]-high strip below the board, and
/// [Axis.vertical] for the wide layout, where it fills a side panel and each
/// piece gets an equal share of the panel's height.
///
/// Pieces are shown with [FittedBox.fit] `scaleDown`, so a large piece shrinks
/// to fit its slot instead of overflowing. The drag feedback is unaffected: it
/// is always drawn at the board's cell size.
class PieceTray extends StatelessWidget {
  final double gridCellSize;
  final Axis direction;

  const PieceTray({
    super.key,
    required this.gridCellSize,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final pieces = List<Widget>.generate(GameConstants.piecesPerTray, (
          index,
        ) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: DraggablePieceWidget(
              trayIndex: index,
              piece: state.tray[index],
              mode: state.mode,
              gridCellSize: gridCellSize,
            ),
          );
        });

        if (direction == Axis.horizontal) {
          return SizedBox(
            height: LayoutConstants.trayHeight,
            child: Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: pieces,
            ),
          );
        }

        return Flex(
          direction: Axis.vertical,
          children: [
            for (final piece in pieces) Expanded(child: Center(child: piece)),
          ],
        );
      },
    );
  }
}
