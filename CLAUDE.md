# lobotomy-Casino — Claude Code Guidelines

## Branching workflow

**Always create a dedicated branch before making any changes.** Never push directly to `main` or the current session's base branch.

### Branch naming
- Bug fixes: `claude/fix-<short-description>`
- New features: `claude/feat-<short-description>`
- Tweaks / balance / polish: `claude/tweak-<short-description>`

### Rules
1. Create the branch at the start of the task. If the task grows, keep adding commits to the **same** branch — do not create a second branch mid-work.
2. Related fixes and tweaks can be batched onto one branch when they address the same area.
3. Push the branch and open a PR for review; do **not** merge to `main` unilaterally.
4. A new branch is only started once the previous one is merged or explicitly abandoned.

### GitHub workflow — mandatory
- **Never merge any branch** (locally or remotely) without explicit consent from the repository owner.
- **Never use `git merge` locally** to absorb another branch — all merges must go through a GitHub PR reviewed and approved by the owner.
- Session config may specify a development branch; this does **not** grant permission to merge other branches into it directly. Always create a new named branch off it and submit a PR.
- If a branch's changes are already present in another branch due to a local merge, flag it clearly instead of silently proceeding.

### Example
```
git checkout -b claude/fix-reel-animation-sync
# ... make changes ...
git push -u origin claude/fix-reel-animation-sync
# open PR — do not merge yourself
```

## Pixel-art rendering conventions

- The game screen is a **160×320 virtual canvas**. `PixelScene` (`src/components/PixelScene.tsx`) centers and aspect-fit-scales it to the device; treat it as **one full-canvas composition**, not fixed top/bottom UI bands. Only full-screen overlays/modals live outside `PixelScene`.
- `ASSET_SCALE` (in `src/content/layout.ts`) **must equal the authored scale of the runtime PNGs** (currently `8` — the `*_final_machine.png` art is 8× the 160×320 source). Changing it requires regenerating the art; it cancels out of the on-screen canvas size and only sets the intermediate render resolution.
- Position children with `vpx(n)` (= `n * ASSET_SCALE`). In-scene HUD/text is sized in **asset-space** (i.e. multiply px sizes by `ASSET_SCALE` / use `vpx`) so it renders large and downscales crisp with the rest of the canvas — see `MachineScreenMeters` and the HUD styles in `GameScreen`.
- All visible game text must go through the **`PixelText`** wrapper (`src/components/PixelText.tsx`, applies `PIXEL_FONT`). RN 0.81's `Text` is a function component, so there is no global font patch.

## Machine geometry (data-driven — re-measure on art swaps)

- The slot machine's layout lives as **source-pixel constants** in `src/content/machineAssets.ts` (`REEL_HOLES`, `REEL_CELL_CENTERS`, `TV_SCREEN`, `MULT_STRIP`/`MULT_BADGE_CENTERS`, `BAR_FILL`/`WEALTH_BAR`/`HEALTH_BAR`, `LEVER_HIT`, `POWER_HITS`). The full-canvas image layers self-align, but every **app-rendered overlay and tap target** (reel symbols, meter text, fill bars, reel/multiplier/lever/power touch zones) is positioned from these constants.
- **When the machine PNGs are replaced, these constants MUST be re-measured** or the machine silently misaligns (symbols/taps land in the wrong place) even though the art looks right.
- Measure with `pngjs` (already a dependency). **Source px = original px ÷ ASSET_SCALE.** Decode the PNG, find the bounding box of the relevant feature (opaque/colored pixels), and divide by `ASSET_SCALE`. Multi-frame sheets are horizontal strips of full-canvas frames (frame width = source width × ASSET_SCALE).

## Android toolchain constraint

- **Kotlin must stay below 2.1.0** (use `2.0.21`). React Native 0.81's Gradle plugin is compiled against Kotlin 1.9.x and calls `KotlinTopLevelExtension` as a class; it became an interface in Kotlin 2.1.0, so KGP ≥ 2.1 fails the Gradle config with *"Found interface … KotlinTopLevelExtension, but class was expected."*
- Set it in **`app.json`** (`expo-build-properties` → `android.kotlinVersion`) — the source of truth — **and** in `android/gradle.properties` (`android.kotlinVersion`) so the already-generated `android/` builds without a fresh prebuild. After changing it, stop the Gradle daemon (`android/gradlew.bat --stop`) before rebuilding.

## Skia / Reanimated performance (UI-thread rendering)

High-frequency rendering (reel spins, gestures, fast tracking loops) must stay on the UI thread and allocation-free. Follow these or animations stutter and GC pauses show up as frame drops on low/mid-tier devices.

- **Zero per-frame allocations.** Never create objects inside a render/frame callback or worklet that runs every frame — `Skia.Path.Make()`, `Skia.Paint()`, matrices, arrays, and object literals all churn the heap and trigger GC pauses. Pre-allocate them **once** (module scope or a `useMemo`/ref) and **mutate them in place** (`path.reset()` then re-add segments, `paint.setColor(...)`) instead of reallocating mid-render.
- **Pass `SharedValue` references directly to Skia props.** Hand a Reanimated `SharedValue` (or a derived value) straight into a Skia component prop rather than reading `.value` in React render. This bypasses React's tree diffing/reconciliation entirely and keeps the update path confined to the UI thread — no JS-thread re-render per frame.
- **Memory & texture optimization.** Watch for hardware-texture bloat and GPU VRAM clipping on low/mid-tier devices: keep offscreen/cached layers (e.g. `Picture`, image snapshots, large `Group` caches) bounded, reuse textures, and avoid allocating large surfaces per frame. Prefer sprite-sheet frames over many separate textures (see `SpriteSheetFrame`).
- **Pure worklet execution — no stray `runOnJS`.** High-frequency interactions (gesture handlers, tracking loops) must run as pure worklets on the UI thread. Misusing `runOnJS` inside them forces JNI serialization across the bridge every frame, creating a bottleneck. Reserve `runOnJS` for low-frequency, genuinely JS-side side effects (state commits at gesture end), never per-frame.

## Verification & dev loop

- Before considering work done: `npx tsc --noEmit -p tsconfig.json` (clean) and `npx jest` (all pass).
- Debug builds load JS from the Metro dev server, so **JS/TS-only changes just need a Metro reload (`r`)** — no native rebuild. A native rebuild is only required for native/config changes (new native modules, `app.json`/gradle, Kotlin version, etc.).
