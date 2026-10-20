import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../utils/board_metrics.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import 'header_bar.dart';
import 'square_grid_widget.dart';
import 'hex_grid_widget.dart';
import 'piece_tray.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Consumer<GameState>(
          builder: (context, state, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                // Pick the layout from the space we actually get, not from the
                // device type, so split-screen and foldables work too.
                final isWide =
                    constraints.maxWidth >
                    constraints.maxHeight * LayoutConstants.wideAspectRatio;
                return Stack(
                  children: [
                    isWide
                        ? _buildWideLayout(state, constraints)
                        : _buildTallLayout(state, constraints),
                    if (state.isGameOver) _buildGameOverOverlay(context, state),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Phones and portrait tablets: header, board, then a horizontal tray, with
  /// the undo button in the bottom-left corner.
  Widget _buildTallLayout(GameState state, BoxConstraints constraints) {
    const pad = LayoutConstants.boardPadding;
    final boardSide = _boardSide(
      maxWidth: constraints.maxWidth - 2 * pad,
      maxHeight:
          constraints.maxHeight -
          (LayoutConstants.headerHeight +
              8 +
              8 +
              LayoutConstants.trayHeight +
              16),
    );
    final cellSize = boardCellSize(state.mode, boardSide);

    return Stack(
      children: [
        Column(
          children: [
            const HeaderBar(),
            const SizedBox(height: 8),
            Expanded(child: Center(child: _board(state, boardSide))),
            const SizedBox(height: 8),
            PieceTray(gridCellSize: cellSize),
            const SizedBox(height: 16),
          ],
        ),
        // Undo button - bottom left
        if (state.canUndo)
          Positioned(left: 16, bottom: 24, child: _undoButton(state)),
      ],
    );
  }

  /// Landscape tablets and wide windows: header on top, then the board on the
  /// left and a side panel with the vertical tray and the undo button.
  Widget _buildWideLayout(GameState state, BoxConstraints constraints) {
    const pad = LayoutConstants.boardPadding;
    final panelWidth = (constraints.maxWidth * 0.22).clamp(
      LayoutConstants.sidePanelMinWidth,
      LayoutConstants.sidePanelMaxWidth,
    );
    // Row: pad | board | pad | panel | pad
    final boardSide = _boardSide(
      maxWidth: constraints.maxWidth - 3 * pad - panelWidth,
      maxHeight:
          constraints.maxHeight - (LayoutConstants.headerHeight + 8 + pad),
    );
    final cellSize = boardCellSize(state.mode, boardSide);

    return Column(
      children: [
        const HeaderBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(pad, 0, pad, pad),
            child: Row(
              children: [
                Expanded(child: Center(child: _board(state, boardSide))),
                const SizedBox(width: pad),
                SizedBox(
                  width: panelWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: PieceTray(
                          gridCellSize: cellSize,
                          direction: Axis.vertical,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Keep the slot when hidden so the tray doesn't jump.
                      SizedBox(
                        height: LayoutConstants.undoButtonSize,
                        child: state.canUndo ? _undoButton(state) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Side of the square box the board is drawn in. The grid widgets size their
  /// cells from this same box, so the tray's [boardCellSize] matches them.
  static double _boardSide({
    required double maxWidth,
    required double maxHeight,
  }) {
    return math.max(0.0, math.min(maxWidth, maxHeight));
  }

  Widget _board(GameState state, double side) {
    return SizedBox.square(
      dimension: side,
      child: state.mode == GameMode.square
          ? const SquareGridWidget()
          : const HexGridWidget(),
    );
  }

  Widget _undoButton(GameState state) {
    return Semantics(
      button: true,
      label: 'Undo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => state.undo(),
        child: Container(
          width: LayoutConstants.undoButtonSize,
          height: LayoutConstants.undoButtonSize,
          decoration: BoxDecoration(
            color: GameColors.emptyCell,
            borderRadius: BorderRadius.circular(
              LayoutConstants.undoButtonSize / 2,
            ),
          ),
          child: const Icon(Icons.undo, color: Colors.white70, size: 26),
        ),
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) {
    return '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildGameOverOverlay(BuildContext context, GameState state) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: GameColors.emptyCell,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Over',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Score: ${state.score}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Best: ${state.highScore}',
                style: const TextStyle(color: Colors.amber, fontSize: 20),
              ),
              if (state.highScoreDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Set ${_formatDate(state.highScoreDate!)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => state.reset(),
                child: const Text(
                  'Play Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
