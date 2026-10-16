# Code-generated pixel art

All 429 image contracts now resolve to raster art drawn from code. This replaces
the painted direction, including its animation sheets. The rebuild uses integer
shapes and a shared material palette; it never samples, downsizes or quantizes the
old paintings. A code-authored bitmap font includes French accents.

## Machine reference at gameplay size

[400×800 before/after](machine-400x800.png) ·
[540×960](machine-540x960.png) · [450×1000](machine-450x1000.png) ·
[800×1000](machine-800x1000.png) · [motion comparison](machine-motion.mp4)
· [reel motion filmstrip](reel-motion-strip.png)

Each half is an unscaled capture from a real Godot window. The 32-pixel heading
is outside the gameplay image. The eight-second motion comparison uses 240
captured frames per side, played at 30 fps: a paid spin, staggered stops, heat
states, and the diminished warning. It is a frame comparison, not a benchmark
of real-time playback duration.

The machine was reviewed as one object before the treatment was applied to the
other families. Specific weaknesses in the starting art:

| Weakness at gameplay size | Replacement decision |
| --- | --- |
| Red panels mix glossy plastic, wet paint and grainy metal; the steel rail has a different light direction. | Broad enamel planes, stepped folded edges, and a separate cool steel ramp share an upper-left key light. |
| Random scratches and granular shading compete with symbols and digits. | Wear is confined to screw seats, exposed corners, service seams and the coin mouth. Large planes remain quiet. |
| Painted room reflections are much softer than the live buttons and text. | Room architecture, floor reflections, controls and glyphs share explicit pixel clusters and hard edges. |
| Baked panel perspective and overlaid controls do not always agree. | Frontal faceplates, inset wells, folded returns and repeated fasteners explain how parts attach. |
| Fine anatomical strokes disappear into the reel paper. | Symbols use a dark silhouette, one dominant material, and a few interior landmarks. |
| Smooth fonts and vector edges mix with simulated pixel textures. | Bitmap glyphs, nearest sampling, no mipmaps, and integer spans for runtime geometry. |

The silhouette, red shoulders, CRT, three sockets, reel row, control shelf and
coin tray remain recognizable. The result is intentionally quieter: construction,
contrast and character carry the image, rather than extra surface detail.

## Other families and animations

Actual 400×800 comparisons:
[Pacte](pacte_scene.png), [route lobby](dealer_choice_scene.png),
[audio console](settings_scene.png), [Collection](collection_scene.png),
[Lab](upgrades_scene.png).

[Animation and palette board](animation-and-palette.png) shows independent state
layers, sampled neuron motion, three death overlays, and control travel. Pattern
Recognition retains five frames; How to Cheat retains seven; the neuron signal
retains 34 frames and each death overlay three. Lab eye/memory boot and selection
frames, reel strips, warnings, cards, route doors, consumables, symbols, coins,
suits, odds-table layers and endings all have code recipes. Existing animation
drivers still control frame timing and gameplay handoffs.

## Rebuild

```powershell
py -m pip install -r tools/pixel_art/requirements.txt
py tools/generate_pixel_art.py
py tools/wire_pixel_art.py
godot --headless --editor --quit --path godot
py tools/verify_pixel_art.py
```

`tools/pixel_art/` is the editable source: `core.py` owns palette and integer
primitives; `machine.py`, `rooms.py`, `ui.py` and `legacy.py` own family recipes;
`font.py` draws the bitmap font. `contracts.json` versions the old logical names
and atlas dimensions, so a rebuild does not need preserved paintings or any
untracked source files. Repeated rebuilds produce identical image bytes.

Generated output lives under `godot/assets/images/pixel` and
`godot/assets/font/pixel`. The generated GDScript manifest redirects logical IDs
in `Assets`; explicit scene/atlas references use the generated resources too.
Original sources remain on disk, excluded from all export profiles. Runtime
lighting uses stepped pixel shapes; animations may tint or fade these shapes.

The 160×320 area remains a layout safe area, with display-resolution rendering,
fractional viewport scaling and decorative overscan. Nearest sampling preserves
the authored clusters. Fractional display scales can produce unequal screen-pixel
widths; this change does not impose a fixed 160×320 framebuffer or letterboxing.

## Geometry and integration

The cabinet draws on a 160×320 source grid and exports at 8× (1280×2560).
Source-grid positions, before the existing cabinet offset, are:

| Feature | Source-grid measurement |
| --- | --- |
| Transparent reel apertures | x33 / 65 / 97, y169, 21×34 |
| Runtime reel clips | x33 / 65 / 97, y170, 21×30; centers 43.5 / 75.5 / 107.5 |
| Power socket centers | x46 / 77 / 108, y127 |
| SPIN hit area | x57, y213, 46×28; independent cap states |
| Power coin final frame | alpha center (74, 245.5), plus retained (2, 52.5) pop offset = (76, 298) |
| Multiplier sheet | inverse of retained (-9, +30) sprite offset; lands in the CRT |
| Dealer native sheets | 200×380 including 20/30-unit bleed; 2-frame controls remain separate |
| Dealer bar | 11 frames; warning sheets 10 / 9 / 8; normalized across the existing countdown cycle |

The frame-scaling helper now derives scale from the loaded sheet on authored
nodes as well as dynamically created ones. The older wealth trim has transparent
digit apertures, so its upper layer cannot obscure the moving digits. Lab source
crop rectangles and card atlas coordinates are retained. Changes to source
resolution do not alter control hitboxes.

## Verification and preserved work

The local working tree already contained separate reel-motion, heat and CRT
readout work. Those changes remain present. The main comparison uses that exact
working-tree context on both sides. The PR integration is also tested in an
isolated checkout without sweeping in that work:
[committed-branch before/after](branch-machine-400x800.png). That version retains
the pre-existing mechanical digit implementation with newly generated pixels.

Validation includes the full scene gate in both contexts, rules parity, native
machine input/state review, four display shapes, and 13 scenes in EN/FR. The
export-pack check verifies all 429 generated image resources exist and every old
logical source image is absent. The visual audit checks live sprite, atlas,
button-style and cached image bindings. The source verifier checks all 429
integer repeat grids, palette membership, alpha and cabinet aperture clearance.

Final results: 111 working-tree scene checks and 106 isolated PR checks passed
with no unexpected engine errors. All 429 repeat-grid checks passed; an isolated
rebuild produced identical image bytes. The packaged bilingual audit passed
1,081 image bindings across 13 scenes. [Recorded results](validation.json).

Capture with a graphical renderer and sandboxed review stores:

```powershell
$env:ART_REVIEW_DIR = "$PWD/tmp/pixel-review"
godot --path godot -s res://test/debug_pixel_art_review.gd
godot --path godot -s res://test/debug_art_direction.gd
```

`debug_pixel_art_review.gd` captures 13 scenes in both languages and audits their
texture paths. `debug_art_direction.gd` captures the machine at four viewport
sizes plus motion and state frames. Use different output directories when
retaining multiple runs. `tools/review_pixel_art.py` assembles comparison boards
from those captures; it is documentation tooling, separate from asset generation.
