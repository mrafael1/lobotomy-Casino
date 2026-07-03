# Parity Vectors

`vectors/*.json` are frozen golden vectors from the original prototype. The Godot
rules use them as a regression contract so scoring, RNG, banking, endings, dealer
offers, and power behavior stay stable.

## Verify

From the repository root:

```sh
godot --headless --path godot -s res://test/run_parity_headless.gd
```

## Files

| file | pins |
| --- | --- |
| `rng.json` | Mulberry32 first-N uint32 per seed |
| `score_reels.json` | reel scoring and multiplier rounding |
| `rounding.json` | JavaScript half-up rounding truth table |
| `evaluate.json` | spin evaluation from a seeded RNG |
| `abilities.json` | reroll, shift, and copy-reel outcomes |
| `dealer_vectors.json` | dealer offers, triggers, and in-run item data |
| `bank.json` | banked run history and wallet output |
| `lucidity_restore.json` | power-restore planning from lucidity gain |
| `endings.json` | flatline, wealth, and exit ending checks |

If gameplay rules intentionally change, update the Godot implementation and these
vectors together, then rerun the parity headless test.
