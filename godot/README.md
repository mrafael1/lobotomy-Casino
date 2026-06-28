# lobotomy-Casino — Godot 4 port

Godot 4 (GDScript) rebuild of the slot machine, targeting portrait Android first.
The Expo / React Native project remains canonical until this port reaches verified
parity. **The strategy is rules → data → save → loop, gated by a parity harness, then
visuals.** Nothing downstream is trusted until the rules match the Expo reference.

## Layout

```
godot/
  project.godot            # autoloads, portrait, 160x320 virtual canvas, nearest filter
  rules/                   # pure rules/content port (mirrors src/game + src/content)
    rng.gd                 #   Mulberry32 — bit-exact, proven (see Day-1 gate below)
    symbols.gd payouts.gd economy_const.gd economy.gd
    evaluate.gd abilities.gd endings.gd dealer.gd lucidity.gd
    consumables.gd in_run_items.gd upgrades.gd
  autoload/                # state singletons exposing the Expo action API
    run_state_store.gd     #   RunStateStore (spin/reroll/move/lock/copy/dealer/…)
    meta_state_store.gd    #   MetaStateStore (bank/buy/… + user:// save, Step 4)
  test/                    # parity + sacred-rule harness
    parity_checks.gd       #   loads ../parity/vectors/*.json, asserts the core matches
    sacred_rules.gd        #   native re-statement of the 7 sacred rules
    run_parity_headless.gd #   no-dependency runner (canonical Milestone-1 gate)
    test_parity.gd test_sacred_rules.gd  # GUT wrappers (editor/CI)
    fixed_rng.gd           #   constant-RNG stub for sacred tests
```

## Verifying the port (Milestone 1 gate)

The golden vectors are generated from the canonical Expo implementation and live in
`../parity/vectors/` (regenerate with `npm run vectors:export` at the repo root). The
GDScript core must reproduce every one exactly.

**No-dependency run (recommended):**

```sh
# from the repo root
godot --headless --path godot -s res://test/run_parity_headless.gd
```

Exit code `0` means the rules/content port matches the Expo reference (RNG, scoring,
rounding, evaluate, abilities, dealer, banking, lucidity-restore, endings) and the
sacred-rule invariants hold. Any divergence is printed with `got` vs `expect`.

**GUT run (optional, editor/CI):** install the [GUT](https://github.com/bitwes/Gut)
addon under `res://addons/gut`, then run the `test/` directory. `test_parity.gd` and
`test_sacred_rules.gd` wrap the same checks.

### The Day-1 gate — Mulberry32 bit-exactness

`rules/rng.gd` is a bit-exact port of the JS `createRNG`. GDScript `int` is 64-bit with
no native uint32 / `Math.imul`, so every step is masked to 32 bits and `imul` is
reimplemented; the intermediate product overflows int64 and wraps — keeping the low 32
bits recovers the correct value. This logic is proven against the JS reference in
`__tests__/rng-gdscript-mirror.test.ts` (a BigInt model of Godot's int64). **Do not
"simplify" `rng.gd`.** If RNG parity breaks, nothing downstream is trustworthy.

## Asset import settings (Step 2)

`project.godot` sets `default_texture_filter = 0` (Nearest) project-wide. When importing
the pixel-art PNGs from `../assets` / `../aseprite`, also set per-texture:

- **Filter:** Nearest (inherited from the project default)
- **Mipmaps:** Off
- **Fix Alpha Border / Premult:** as needed for the source art

Mirror the 160×320 virtual-canvas convention; position app-rendered overlays/tap zones
from re-measured source-pixel constants (see the Expo `machineAssets.ts` discipline).

## Status

- ✅ Rules/content port + parity harness (this milestone — run the harness to confirm).
- ✅ `user://` save with v2-canonical schema + empty migration seam (Step 4).
- ⏳ Scenes (Step 5) — built only after the core is green against the harness.

> This GDScript was authored against the frozen Expo reference but **not executed in the
> authoring environment** (no Godot binary there). The headless harness is the gate:
> run it before trusting the port.
