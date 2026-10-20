import 'dart:math' as math;

import 'constants.dart';
import 'storage.dart';

/// Cell size of a board drawn inside a square box of [side] logical pixels.
///
/// For [GameMode.square] this is the width of one grid cell. For
/// [GameMode.hex] it is the hex radius (centre to corner): the radius-4 board
/// is 9 hexes across, i.e. `sqrt(3) * 9` radii plus one radius of margin.
///
/// [HexGridWidget] and [SquareGridWidget] size their cells with this, and the
/// game screen uses it for the tray, so drag feedback always matches the board.
double boardCellSize(GameMode mode, double side) {
  return mode == GameMode.square
      ? side / GameConstants.squareGridSize
      : side / (math.sqrt(3) * 9 + 1);
}
