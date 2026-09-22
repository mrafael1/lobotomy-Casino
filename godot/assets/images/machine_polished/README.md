# Machine artwork and composition

The full-resolution painted cabinet is registered to 160x320 layout units by
`painted_cabinet.gdshader`. `apertures.svg` defines independent reel holes at
x33/65/97, y169..202. Live symbols and targeting remain runtime elements.
The machine origin is offset (4,0), centering the upper hardware and its input
with the fixed shelf. Geometry above is machine-local. Shelf controls and
viewport overlays ignore that transform; the shelf shader samples canvas pixels.
Shake/heartbeat resets retain the offset, and cash flights use local (76,298)
to preserve the world outlet at (80,298).

The shader retains continuous UV sampling and the import has no size cap.
The original painted rail supplies the three sockets, registered to x46/77/108;
the old flat `cabinet_controls.svg` overlay is no longer sampled. The lower
shelf is `preview_shelf.png`, extracted directly from the approved preview, not
redrawn. `tools/extract_preview_shelf.gd` samples the archived source once at
640x1280 with Lanczos, copies logical rows 199..237 to
y210..248, leaving a four-unit dark gap beneath the reel frames, and clears only the baked-in count,
item contents and independently animated cap. Bevels, slots, wear, red fascia
retain source detail. The SPINS engraving is cleared for a runtime label;
the cap retains the painting's SPIN lettering.
The five `preview_spin_*.png` states use the original cap with a
two-layout-unit depression, dimmed disabled state, brighter hover and a separate focus
mark that does not cover the depressed cap. The obsolete procedural shelf drawing,
SPIN SVG states and their generator have been removed after reference checks.
The live counter occupies (28,213,14,16). Item images are 12x14 at (103,214)
and (121,214), within the original recesses; their 16x18 touch slots retain
margin activation and gameplay locks. The stash container has no tray texture.
Rebuild with `godot --headless --path godot -s ../tools/extract_preview_shelf.gd`.
The source archive is tooling only; exported builds use PNGs under `godot/assets`.
SPIN keeps its 46x28 touch area at (57,213), keyboard activation and targeting pass-through.

The CRT dealer is inset at (36,51), size 30x43, with reactions above the approach
row at y95..98. Active items occupy y100..107. TARGET and its current value are
runtime labels with the same 6px font and y49 baseline. The muted progress strip
is at y59. Four shaded enamel drums begin at (74,64). Their cases/trim render at
4x detail, and all four reels share `wealth_digits_detail.svg`, a compact 440x56
strip with the original 11-frame ordering. Glyph placement is local to each clip;
carry, reverse drains and snapshot alignment keep the same layout geometry.
Multiplier and loss artwork occupies y82.
Payout/targeting callouts retain CRT priority; FREE SPIN replaces target text only.

Three separate lamps above the reels fill at 10/20/30 coins (6/12/18 with
Adrenaline). Coin pops and flights begin at the cash outlet (80,298). A restore
flashes the lamps and resets them; an ineligible restore leaves the bank full.
Power acquisition order and all gameplay locks are unchanged.
The seven power SVGs supply smooth engraved glyphs on shaded caps, with separate
normal, selected and spent frames at 2x source detail. `reel_housing.svg` supplies
4x beveled frames; their apertures remain completely transparent.

`jackpot_beacon.svg` mounts amber glass on a metal base above the CRT. Its three
native frames preserve the existing payout hold, lit state and alternating flash.

Augment stickers occupy the lower cabinet at x48/74/100, y260, with worn paper
edges, 14px icons and hold-for-details behavior. They remain visible during CRT
callouts. Learning's book and Tunnel Vision's shutter remain independent layers.

Generators: `tools/generate_composition_hardware.py` authors legacy cabinet/wealth
surfaces, progress and the jackpot beacon. The detailed power, reel-frame and
`wealth_*_detail.svg` assets are maintained directly as vectors and are not outputs
of that legacy generator. `tools/generate_crt_hardware.py` authors approach,
sticker and callout sheets; `tools/generate_power_lamps.py` authors restore lamps.
Unused older art remains until a separate reference audit permits deletion.

Visual review (PowerShell, isolated saves):

```powershell
$env:APPDATA = "$PWD/tmp/composition-review-user"
New-Item -ItemType Directory -Force tmp/composition-review
$env:ART_REVIEW_DIR = "$PWD/tmp/composition-review"
godot --path godot -s res://test/debug_machine_art_review.gd
```

The review exercises SPIN mouse/keyboard input, targeting, disabled controls,
coin charging, rolling digits, dealer interruption/reactions, payout, multiplier
warnings, Learning/Tunnel Vision and stickers. Scene smoke additionally checks
wealth carry, power behavior, geometry, item durations and persistence.

`reel_lock.svg` is a compact 92x144 shared brass frame, rendered at 23x36
layout units over each reel. It replaces the three full-canvas lock overlays
without changing their positions or remaining-spin labels.
