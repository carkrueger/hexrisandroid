import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/coordinates.dart';
import '../models/piece.dart';
import '../painters/square_grid_painter.dart';
import '../utils/board_metrics.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';

class SquareGridWidget extends StatefulWidget {
  const SquareGridWidget({super.key});

  @override
  State<SquareGridWidget> createState() => _SquareGridWidgetState();
}

class _SquareGridWidgetState extends State<SquareGridWidget>
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
        final gridDim = GameConstants.squareGridSize;
        final maxSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cellSize = boardCellSize(GameMode.square, maxSize);
        final totalSize = cellSize * gridDim;

        return Consumer<GameState>(
          builder: (context, state, _) {
            // Start animation when cellsToClear becomes non-empty
            if (state.cellsToClear.isNotEmpty && !_clearController.isAnimating) {
              _clearController.forward(from: 0.0);
            }

            return DragTarget<PieceDragData>(
              onWillAcceptWithDetails: (details) => true,
              onMove: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final local = renderBox.globalToLocal(details.offset);
                final adjusted = local + details.data.anchorOffset;
                _updateGhost(state, adjusted, details.data.piece, cellSize);
              },
              onLeave: (_) => state.clearGhost(),
              onAcceptWithDetails: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final local = renderBox.globalToLocal(details.offset);
                final adjusted = local + details.data.anchorOffset;
                final anchor = _pixelToCoord(adjusted, cellSize);
                if (anchor != null) {
                  state.placePiece(details.data.trayIndex, anchor);
                }
              },
              builder: (context, candidateData, rejectedData) {
                return AnimatedBuilder(
                  animation: _clearController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(totalSize, totalSize),
                      painter: SquareGridPainter(
                        grid: state.squareGrid,
                        ghostCells: state.ghostCells,
                        ghostValid: state.ghostValid,
                        cellSize: cellSize,
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

  void _updateGhost(
      GameState state, Offset local, TrayPiece piece, double cellSize) {
    final anchor = _pixelToCoord(local, cellSize);
    if (anchor == null) {
      state.clearGhost();
      return;
    }
    final cells = piece.cells.cast<SquareCoord>();
    final ghostCoords = <SquareCoord>{};
    bool allValid = true;
    for (final c in cells) {
      final pos = anchor + c;
      ghostCoords.add(pos);
      if (pos.row < 0 ||
          pos.row >= GameConstants.squareGridSize ||
          pos.col < 0 ||
          pos.col >= GameConstants.squareGridSize ||
          state.squareGrid[pos.row][pos.col] != null) {
        allValid = false;
      }
    }
    state.updateGhost(ghostCoords, allValid);
  }

  SquareCoord? _pixelToCoord(Offset local, double cellSize) {
    final row = (local.dy / cellSize).floor();
    final col = (local.dx / cellSize).floor();
    if (row < 0 ||
        row >= GameConstants.squareGridSize ||
        col < 0 ||
        col >= GameConstants.squareGridSize) {
      return null;
    }
    return SquareCoord(row, col);
  }
}
