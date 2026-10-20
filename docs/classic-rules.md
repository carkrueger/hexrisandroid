# Classic rules

Hexris includes an optional Classic ruleset. Modern Hexris remains the default.
Changing rulesets starts a new board and keeps high scores separate.

The in-game help (Settings → How to Play, `lib/widgets/help_dialog.dart`)
summarises both rulesets for players; this page has the details.

## Boards

- Square uses a 10 by 10 board and clears complete rows and columns.
- Hex uses a 61-cell radius-four board and clears complete lines along all
  three hex axes.
- The game ends when none of the available pieces has a legal placement.

## Square pieces

Classic square pieces come from the original game's 31-entry catalog
(`classicSquarePieceCatalog` in `lib/models/piece.dart`). Every orientation is
a separate entry, and pieces cannot be rotated.

Each piece is chosen uniformly from the first `min(8 + level, 31)` entries of
the catalog, so a game starts with 9 shapes and unlocks one more per level.
The level is not shown on screen.

| Entries | Unlocked at | Shapes |
|---|---|---|
| 1–9 | level 1 | dot, line 3 (horizontal), line 4 (vertical), small corner, 2 by 2 square, large corner, line 5 (horizontal), 3 by 3 square, L |
| 10–18 | levels 2–10 | line 2 (vertical), T, line 2 (horizontal), line 3 (vertical), S, small corner, S (vertical), line 4 (horizontal), line 5 (vertical) |
| 19–31 | levels 11–23 | large corner, L, T, two small corners, two large corners, Z, Z (vertical), two L, two T |

Square pieces are dealt in batches of three; a new batch appears after all
three pieces have been used. The level in effect when the batch is dealt
decides which shapes it can contain.

`classicSquareFamilies` in the same file holds the original weighted family
table (line 5, line 4, line 3, line 2, large corner, small corner, 2 by 2
square, 3 by 3 square, dot; weights 2, 2, 3, 3, 2, 3, 3, 1, 1). It is kept for
reference and covered by tests, but the game does not deal pieces from it.

## Levels

The level starts at 1. After a clear, if the score is above the threshold of
the current level, the level goes up by one (at most one level per clear). The
cumulative thresholds are:

```text
threshold(1) = 80
threshold(L) = threshold(L - 1) + (L ~/ 10) × 40 + 70 + 30 × (L - 1)
```

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 15 | 20 | 22 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Threshold | 80 | 180 | 310 | 470 | 660 | 880 | 1130 | 1410 | 1720 | 2100 | 4450 | 7590 | 9120 |

The full catalog (level 23) is reached once the score passes 9120. Levels only
affect square pieces.

## Hex pieces

The Classic hex catalog contains 22 uniformly selected entries: one dot and 21
distinct four-cell pieces/orientations. Every entry has probability `1/22`
(approximately 4.545%). A consumed slot is replaced immediately.

## Scoring

Placement itself awards no points. A clear awards:

```text
distinct cells removed + lineCount × (10 + 5 × (lineCount - 1))
```

That is a line bonus of 10 for one line, 30 for two, 60 for three and 100 for
four. A cell where two cleared lines cross counts once.

For comparison, Modern rules award 1 point per placed cell, 1 per cleared
cell, and 10 per line when two or more lines clear at once; every used piece
is replaced immediately.

Undo remains available in both rulesets.
