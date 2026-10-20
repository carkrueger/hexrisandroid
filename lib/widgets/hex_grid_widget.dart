import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/coordinates.dart';
import '../models/piece.dart';
import '../logic/hex_grid_logic.dart';
import '../painters/hex_grid_painter.dart';
import '../utils/board_metrics.dart';
import '../utils/constants.dart';
import '../utils/hex_math.dart';
import '../utils/storage.dart';
import 'dart:math' as math;

class HexGridWidget extends StatefulWidget {
  const HexGridWidget({super.key});

  @override
  State<HexGridWidget> createState() => _HexGridWidgetState();
}

class _HexGridWidgetState extends State<HexGridWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _clearController;

  @override
  void initState() {
    super.initState();
    _clearController = AnimationController(
      vsync: this,
      duration: GameConstants.clearAnimationDuration,
    );
  }

  @override
  void dispose() {
    _clearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = math.min(constraints.maxWidth, constraints.maxHeight);
        final hexSize = boardCellSize(GameMode.hex, maxSize);
        final center = Offset(maxSize / 2, maxSize / 2);

        return Consumer<GameState>(
          builder: (context, state, _) {
            if (state.cellsToClear.isNotEmpty && !_clearController.isAnimating) {
              _clearController.forward(from: 0.0);
            }

            return DragTarget<PieceDragData>(
              onWillAcceptWithDetails: (details) => true,
              onMove: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final local = renderBox.globalToLocal(details.offset);
                final adjusted = local + details.data.anchorOffset;
                _updateGhost(
                    state, adjusted, details.data.piece, hexSize, center);
              },
              onLeave: (_) => state.clearGhost(),
              onAcceptWithDetails: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final local = renderBox.globalToLocal(details.offset);
                final adjusted = local + details.data.anchorOffset;
                final anchor = _pixelToHexCoord(adjusted, hexSize, center);
                // A drop doesn't trigger onLeave, and placePiece only clears
                // the preview when it succeeds.
                if (anchor == null ||
                    !state.placePiece(details.data.trayIndex, anchor)) {
                  state.clearGhost();
                }
              },
              builder: (context, candidateData, rejectedData) {
                return AnimatedBuilder(
                  animation: _clearController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(maxSize, maxSize),
                      painter: HexGridPainter(
                        boardCells: HexGridLogic.boardCells,
                        grid: state.hexGrid,
                        ghostCells: state.ghostCells,
                        ghostValid: state.ghostValid,
                        hexSize: hexSize,
                        center: center,
                        cellsToClear: state.cellsToClear,
                        clearProgress: _clearController.value,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _updateGhost(GameState state, Offset local, TrayPiece piece,
      double hexSize, Offset center) {
    final anchor = _pixelToHexCoord(local, hexSize, center);
    if (anchor == null) {
      state.clearGhost();
      return;
    }
    final cells = piece.cells.cast<HexCoord>();
    final ghostCoords = <HexCoord>{};
    bool allValid = true;
    for (final c in cells) {
      final pos = anchor + c;
      ghostCoords.add(pos);
      if (!HexGridLogic.boardCells.contains(pos) ||
          state.hexGrid.containsKey(pos)) {
        allValid = false;
      }
    }
    state.updateGhost(ghostCoords, allValid);
  }

  HexCoord? _pixelToHexCoord(Offset local, double hexSize, Offset center) {
    final relative = local - center;
    final hex = pixelToHex(relative, hexSize);
    if (!HexGridLogic.boardCells.contains(hex)) return null;
    return hex;
  }
}
