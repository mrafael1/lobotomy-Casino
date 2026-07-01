# Parity vectors — the Godot port contract

`vectors/*.json` are **golden vectors generated from the canonical Expo
implementation**. They are the single source of truth the Godot port is asserted
against, so a rebuild that scores/decays/banks differently fails loudly instead of
drifting silently.

## Regenerate / verify (Expo side)

```sh
npm run vectors:export   # regenerate vectors/*.json from the real implementation
npm run vectors:check    # re-export to a temp dir and diff — proves determinism
npx jest                 # __tests__/parity-vectors.test.ts re-derives every vector;
                         # __tests__/rng-gdscript-mirror.test.ts proves the GDScript RNG spec
```

If a gameplay rule changes on the Expo side, `vectors:check` / the jest guard will
fail until you regenerate **and** re-run the Godot parity pass. Treat a vector change
as a deliberate act, never an accident.

## Files

| file | pins |
|------|------|
| `rng.json` | Mulberry32 first-N uint32 per seed (`float = u32 / 4294967296`) |
| `score_reels.json` | `scoreReels(...)` incl. half-value rounding multipliers |
| `rounding.json` | `Math.round(value * multiplier)` truth table (JS half-up) |
| `evaluate.json` | `evaluate(SpinInput)` (rng rebuilt from `seed`) |
| `abilities.json` | `applyReroll/applyMoveColumn/applyCopyReel` → outcomes |
| `dealer_vectors.json` | `pickDealerItems(seed)`, `evaluateDealerTrigger(...)`, in-run item effect table |
| `bank.json` | `bankRunToMeta(...)` with `Date.now()` frozen to `now` |
| `lucidity_restore.json` | `planLucidityGain(...)` (50-coin power restores) |
| `endings.json` | `checkEnding` / `checkExitEligibility` truth tables |

## Determinism notes

- RNG values are pinned as exact uint32 (stronger than float equality, engine-neutral).
- `bankRunToMeta` reads `Date.now()` for ending timestamps; the exporter freezes it and
  records `now` so the Godot `bank_run_to_meta(run, meta, ending, now)` can inject the same.
- The dealer was made deterministic on the Expo side (`src/game/dealer.ts`): the old
  `[...].sort(() => rng() - 0.5)` shuffle (engine-dependent, unportable) was replaced with
  a portable Fisher-Yates. Observable behavior (a random pair of distinct offers) is
  unchanged.
