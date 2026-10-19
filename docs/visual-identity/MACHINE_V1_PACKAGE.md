# V1 machine — first production increment

The selected machine now exports separate, registered assets from its drawing recipes. This is the asset-production step of [the v1 plan](V1_PLAN.md), with no live machine/controller bindings changed.

[Component and control-state sheet](../../godot/assets/art_direction/house_remembers/machine_v1/review/component_sheet.png) · [Registered x1/x2/x3 assemblies](../../godot/assets/art_direction/house_remembers/machine_v1/review/production_benchmark.png) · [Static cabinet without sample live content](../../godot/assets/art_direction/house_remembers/machine_v1/review/runtime_x1_0.png)

## Delivered

- 640 x 1280 source grid at four source pixels per layout unit; one geometry definition supplies native and layout measurements.
- Separate cabinet, rails, reel housing/frames, drums, glass, shelf, SPIN cap, empty stash wells, paper augment tabs and coin tray. Cabinet/housing/frame passes have actual transparent reel apertures.
- Independent decorative lamps, floor reflection, incandescence, vent hardware, exhaust, sparks and embers. Enamel, metal, glass, floor and lamp-core masks follow the authored shapes.
- 23 registered state stacks: six frames at each existing multiplier, x2/x3 rescue surfaces and three win-study states. These are presentation references; a runtime owner chooses the state and supplies real values.
- Ten independent reel illustrations, including Book and three Heart tiers; selected, locked, swap-source and hidden-reel overlays. Eye/brain retain the approved identity. Capsule, syringe, vial, flatline and Book gain dedicated production drawing rather than enlarged small icons.
- Seven distinct power faces in five states at each tier; four SPIN-cap states at each tier; nine item silhouettes; fourteen augment stickers, retaining five Pattern Recognition frames and four false-face frames. IDs match current authoritative data, including `memory` for Lock.
- Separate restore/countdown indicators and campaign-neuron loss frames. The live controller retains ownership of their timing, counts and visibility.

The reference fixtures remain separate from runtime assets: no sample wealth, target, spin count, item count, selected inventory, countdown progress or localized action text is baked into runtime layer textures. Fixed casino branding is artwork. Reference assemblies deliberately preserve the approved mockup, while refined component artwork is supplied separately for live binding.

## Asset contract

Runtime assets live under `godot/assets/art_direction/house_remembers/machine_v1`. `manifest.json` records ordered layer stacks, reusable components, text registration and sprite hashes. `geometry.json` is the shared coordinate contract. Every cropped sprite records its bounds in the full master; place it at `source_rect.xy * 0.25` with scale `0.25`. For component-local sprites, apply that registration relative to their declared local canvas at the destination slot. Do not center a trimmed sprite or infer position from its PNG dimensions.

Layer passes are contiguous and ordered. A role may occur more than once, with distinct pass IDs; preserve that order. Empty passes are omitted. Pixel-identical passes in the same role reuse content-addressed files. The generator removes only obsolete files recorded as its own previous sprite outputs. Decorative assets ignore input. Use the separate logical touch boxes for controls and do not shrink them to painted bounds.

Source-level recipes are `tools/house_identity/machine_geometry.py`, `machine_production.py` and `machine_components.py`, with separation markers in `console.py` and `heat.py`. The original `Pixel` renderer ignores those markers, preserving the approved masters. Production rasterization uses no input paintings, pixelation filters or antialiasing.

The former planning table used approximate reel content bounds. The measured v1 **apertures** are `(106,436,116,216)`, `(260,436,116,216)` and `(414,436,116,216)` in source pixels. Their center-symbol canvases are `(106,484,116,132)`, `(260,484,116,132)` and `(414,484,116,132)`. Use the generated geometry rather than the earlier approximation. Account and control geometry is exported alongside them.

All current export presets explicitly include the two runtime JSON manifests. No runtime path depends on root-level production scripts or review documents. The `review` subtree holds fixture images and sample text for inspection; it must never become gameplay truth or a full-screen replacement texture.

## Rebuild and verification

```powershell
python tools/generate_house_identity.py
python tools/verify_machine_v1.py
python tools/verify_house_identity.py
godot --headless --editor --quit --path godot
godot --headless --path godot -s res://test/check_machine_v1_assets.gd
godot --headless --path godot -s res://test/scene_smoke.gd
```

`generate_machine_v1.py` rebuilds only this package. The full generator also updates the central asset manifest and offline gallery; run it before repository-wide art verification. Checks cover exact registered assembly, aperture clearance, palette/alpha, component coverage, control-state differentiation, safe touch geometry and deterministic rebuild. Godot's independent consumer imports every runtime sprite and reconstructs six representative assemblies from the registration data. All checks passed: 345 reusable sprites/masks, 23 recipe-matching state stacks, six exact Godot assemblies and the existing 111 scene smoke checks. The same Godot assembly check also passes from an exported PCK, run outside the source project. This validates resource inclusion; it is not an APK/device test. Results are recorded in `machine_v1_validation.json` and `godot_validation.json`.

Next: bind the stable cabinet, reels, live account, controls and inventory in the existing machine components, then adapt heat/reward ownership. Remaining production work includes actual phone interaction, EN/FR label fitting, all playable-state coverage, transition timing and in-game polish. This increment does not claim those runtime gates are complete.
