import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../utils/colors.dart';
import '../utils/storage.dart';
import 'help_dialog.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Mode toggle
              Semantics(
                button: true,
                label: state.mode == GameMode.square
                    ? 'Switch to hex board'
                    : 'Switch to square board',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    final newMode = state.mode == GameMode.square
                        ? GameMode.hex
                        : GameMode.square;
                    state.switchMode(newMode);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: GameColors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      state.mode == GameMode.square
                          ? Icons.hexagon
                          : Icons.square_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              // Score display
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${state.score}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tap the trophy / best score to view all saved high scores
                  GestureDetector(
                    onTap: () => _showHighScores(context, state),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 28,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${state.highScore}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Settings
              Semantics(
                button: true,
                label: 'Settings',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _showSettings(context, state),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: GameColors.yellow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Future<List<_HighScoreRow>> _loadHighScores(GameRules rules) async {
    final rows = <_HighScoreRow>[];
    for (final mode in GameMode.values) {
      final score = await Storage.loadHighScore(mode, rules: rules);
      final date = await Storage.loadHighScoreDate(mode, rules: rules);
      rows.add(_HighScoreRow(mode: mode, score: score, date: date));
    }
    // Show the highest score first.
    rows.sort((a, b) => b.score.compareTo(a.score));
    return rows;
  }

  void _showHighScores(BuildContext context, GameState state) {
    showDialog(
      context: context,
      builder: (context) {
        // Held outside FutureBuilder so a reset can re-trigger the load.
        Future<List<_HighScoreRow>> future = _loadHighScores(state.rules);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: GameColors.emptyCell,
              title: const Text(
                'High Scores',
                style: TextStyle(color: Colors.white),
              ),
              content: FutureBuilder<List<_HighScoreRow>>(
                future: future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final rows = snapshot.data!;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: rows.map((row) {
                      final isHex = row.mode == GameMode.hex;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isHex ? Icons.hexagon : Icons.square_rounded,
                          color: isHex ? GameColors.orange : GameColors.green,
                        ),
                        title: Text(
                          isHex ? 'Hex' : 'Square',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          row.date != null
                              ? 'Set ${_formatDate(row.date!)}'
                              : 'Not played yet',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Text(
                          '${row.score}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final confirmed = await _confirmReset(context);
                    if (confirmed) {
                      await state.resetAllHighScores();
                      setDialogState(
                        () => future = _loadHighScores(state.rules),
                      );
                    }
                  },
                  child: const Text(
                    'Reset All',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Returns true if the user confirms resetting all high scores.
  Future<bool> _confirmReset(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.emptyCell,
        title: const Text(
          'Reset all high scores?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently clear your saved high scores for every mode. '
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSettings(BuildContext context, GameState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.emptyCell,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up, color: Colors.white70),
                  title: const Text(
                    'Sound',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: Storage.soundEnabled,
                  activeTrackColor: GameColors.green,
                  onChanged: (val) {
                    setDialogState(() => Storage.soundEnabled = val);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: Colors.white70),
                  title: const Text(
                    'Haptics',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: Storage.hapticsEnabled,
                  activeTrackColor: GameColors.green,
                  onChanged: (val) {
                    setDialogState(() => Storage.hapticsEnabled = val);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.history, color: Colors.white70),
                  title: const Text(
                    'Classic rules',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Exact original pieces, odds, tray refill, and scoring',
                    style: TextStyle(color: Colors.white54),
                  ),
                  value: state.rules == GameRules.classic,
                  activeTrackColor: GameColors.green,
                  onChanged: (val) {
                    state.switchRules(
                      val ? GameRules.classic : GameRules.modern,
                    );
                    setDialogState(() {});
                  },
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.white70),
                  title: const Text(
                    'New Game',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    state.reset();
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.emoji_events,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'High Scores',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showHighScores(context, state);
                  },
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(
                    Icons.help_outline,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'How to Play',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    HelpDialog.show(context, state.rules);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HighScoreRow {
  final GameMode mode;
  final int score;
  final DateTime? date;

  _HighScoreRow({required this.mode, required this.score, this.date});
}
