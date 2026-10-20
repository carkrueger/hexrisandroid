class GameConstants {
  static const int squareGridSize = 10;
  static const int hexRadius = 5;
  static const double cellGap = 3.0;
  static const double cornerRadius = 4.0;
  static const Duration clearAnimationDuration = Duration(milliseconds: 400);
  static const int piecesPerTray = 3;
}

/// Layout and screen-size thresholds shared by the game screen and the
/// orientation policy.
class LayoutConstants {
  /// Screens whose shortest side is at least this many logical pixels are
  /// treated as tablets (Android's sw600dp bucket): they may rotate freely.
  static const double tabletShortestSide = 600;

  /// The wide (side-panel) layout is used when the available width exceeds the
  /// available height by more than this factor.
  static const double wideAspectRatio = 1.1;

  /// Height of [HeaderBar]: 48 for its buttons plus 8 padding above and below.
  static const double headerHeight = 64;

  /// Height of the horizontal piece tray in the tall layout.
  static const double trayHeight = 160;

  /// Horizontal padding around the board.
  static const double boardPadding = 16;

  /// Width bounds of the side panel holding the tray in the wide layout.
  static const double sidePanelMinWidth = 180;
  static const double sidePanelMaxWidth = 220;

  /// Size of the round undo button.
  static const double undoButtonSize = 48;
}
