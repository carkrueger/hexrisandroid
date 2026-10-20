import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/storage.dart';

/// Explains the goal, the controls and both rulesets. Opened from Settings.
///
/// The rule texts follow the scoring in `GameState` and the piece generation
/// in `lib/models/piece.dart`; keep them in sync when the rules change.
class HelpDialog extends StatelessWidget {
  /// The ruleset currently in play, marked as such in the dialog.
  final GameRules rules;

  const HelpDialog({super.key, required this.rules});

  static Future<void> show(BuildContext context, GameRules rules) {
    return showDialog(
      context: context,
      builder: (context) => HelpDialog(rules: rules),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GameColors.emptyCell,
      title: const Text('How to Play', style: TextStyle(color: Colors.white)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Section(
                icon: Icons.flag,
                title: 'Goal',
                lines: [
                  'Score as many points as you can. Place pieces on the board '
                      'and fill complete lines to clear them and make room.',
                  'The game ends when none of the pieces in the tray fits on '
                      'the board anymore.',
                ],
              ),
              const _Section(
                icon: Icons.touch_app,
                title: 'Playing',
                lines: [
                  'Drag a piece from the tray onto the board. A preview shows '
                      'where it will land. Pieces cannot be rotated.',
                  'Undo takes back your moves one at a time.',
                  'The button at the top left switches between the hex and the '
                      'square board. Tap the trophy to see your high scores.',
                ],
              ),
              const _Section(
                icon: Icons.grid_on,
                title: 'Boards',
                lines: [
                  'Square: a 10 × 10 board. Complete rows and columns clear.',
                  'Hex: a board of 61 hexagons. Complete lines in any of the '
                      'three directions clear.',
                  'Lines completed by the same move clear together, and a cell '
                      'where two of them cross counts once.',
                ],
              ),
              _Section(
                icon: Icons.auto_awesome,
                title: 'Modern rules',
                current: rules == GameRules.modern,
                lines: const [
                  '1 point for every cell you place.',
                  '1 point for every cell you clear.',
                  'Combo: clearing 2 or more lines at once adds 10 points per '
                      'line.',
                  'Every piece you use is replaced right away.',
                ],
              ),
              _Section(
                icon: Icons.history,
                title: 'Classic rules',
                current: rules == GameRules.classic,
                lines: const [
                  'The pieces, odds and scoring of the original game.',
                  'Placing a piece scores nothing; only clears score.',
                  'A clear scores 1 point per cleared cell, plus a line bonus: '
                      '10 for one line, 30 for two, 60 for three, and so on '
                      '(lines × (10 + 5 × (lines − 1))).',
                  'Square: pieces come in sets of three, and a new set only '
                      'arrives after all three are used. More shapes unlock '
                      'as your score rises.',
                  'Hex: 22 pieces, a single cell or four cells, each equally '
                      'likely. Every piece you use is replaced right away.',
                ],
              ),
              const _Section(
                icon: Icons.settings,
                title: 'Switching rules',
                lines: [
                  'Turn on Classic rules in Settings. Switching starts a new '
                      'game. Each ruleset and board keeps its own high score.',
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Got it',
            style: TextStyle(color: Colors.greenAccent),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final bool current;

  const _Section({
    required this.icon,
    required this.title,
    required this.lines,
    this.current = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: GameColors.yellow, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (current) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: GameColors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'current',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Text(
                line,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
