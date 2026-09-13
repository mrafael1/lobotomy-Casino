# Premium art rework

The game keeps its 160x320 canvas. Painted brass, aged enamel, scarlet cabinetry,
mint light and anatomical illustrations connect the rooms and interactive assets.
Runtime replacements live inside `godot/assets`; source masters are kept beside
their native exports. Use nearest filtering and inspect the native-size result.

## Integrated families

| Family | Runtime assets / integration |
| --- | --- |
| Buttons | `images/ui/premium/{normal,hover,pressed,disabled}.png`, shared ButtonKit nine-slices, independent focus outline |
| Typography | OFL-licensed Tiny5 at 8/16px for controls and selected headings; translated start labels measured before choosing size |
| Hardware | Painted settings, left/right arrows, close, confirm and Lucidity coin; settings checkmark and shared overlays |
| Reel symbols | Nine native 16px symbols in `images/symbols/premium`, shared by reels and symbol pickers; existing painted Book retained |
| Card illustrations | Seventeen static 24px emblems in `images/cards/painted`, used by shared card renderers and machine stickers |
| Power coin | Separate mint token for restoration flights, preserving existing flight geometry and timing |
| Menu surfaces | Start buttons, settings labels, options heading, Collection names, Shop rows and footer controls |
| Earlier room passes | Painted machine/room assets, Pacte table, route lobby, settings console and options plaque already integrated on this branch |

Dense descriptions still use the existing microfont. Collection truncation keeps
the full name in its detail view; Shop rows keep their full text in tooltips.
Static replacements do not change symbol IDs, card prices, unlocks, hitboxes,
animation sequencing or saved data. Original card atlas coordinates remain valid.

## Remaining art coverage

The entire asset inventory is not yet replaced. Further passes must cover the
animated Pattern Recognition and How to Cheat emblems, campaign-neuron animation,
dealer chip glyphs, payout/ending animation families, and the remaining Lab/scores
surfaces. These need native-frame review, not a static substitution that removes
their animation. The Shop campaign meter/header layout also needs a dedicated pass.

## Rebuild and review

From the repository root, regenerate native assets with Godot:

```powershell
godot --headless --path godot -s ../tools/prepare_premium_buttons.gd
godot --headless --path godot -s ../tools/prepare_premium_icons.gd
godot --headless --path godot -s ../tools/prepare_premium_symbols.gd
godot --headless --path godot -s ../tools/prepare_premium_card_icons.gd
godot --headless --path godot --editor --import --quit
```

The card slicer deliberately skips cells reserved for existing animated icons and
Book. Tiny5's license is in `godot/assets/font/Tiny5-OFL.txt`.

For a sandboxed English/French visual review, use a graphical renderer:

```powershell
New-Item -ItemType Directory -Force tmp/premium-review | Out-Null
$env:ART_REVIEW_DIR = Join-Path (Get-Location) 'tmp/premium-review'
godot --path godot -s res://test/debug_premium_ui_review.gd
```

This exports native and nearest-upscaled menu, options, settings, Collection and
Shop captures, plus button-state, hardware, symbol and card illustration boards.
Gameplay integration is covered by `scene_smoke.gd`; content metadata is checked
by `run_parity_headless.gd`.
