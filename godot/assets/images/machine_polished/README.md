# Machine artwork and composition

The painted cabinet is registered to a native 160x320 canvas by
`painted_cabinet.gdshader`. `apertures.svg` defines independent reel holes at
x33/65/97, y169..202. Live symbols and targeting remain runtime elements.

`cabinet_controls.svg` is sampled by the cabinet material: it supplies the clean
metal power rail and one sloped shelf with counter, SPIN and two stash recesses.
The stash container has no texture; only its item icons and input are live.
Each 16x18 slot owns input around an inset 12x14 item image, leaving the cabinet
recess visible. Slot margins obey the same use locks as the item image.
The five `spin_*.svg` states retain a separate native face fitted to the shelf.
`tools/generate_spin_face.py` supplies evenly spaced pixel lettering and a two-pixel
depression. The count and SPINS legend share the left well side by side; their
bounds are reset after font assignment so default theme minima cannot push them
over SPIN. Power sockets have matching dark mounting rims in the cabinet surface.
SPIN keeps its 46x28 touch area at (57,210), keyboard activation and targeting pass-through.

The CRT dealer is inset at (36,51), size 30x43, with reactions above the approach
row at y95..98. Active items occupy y100..107. TARGET and its current value are
runtime labels with the same 6px font and y49 baseline. The muted progress strip
is at y59. Four warm paper drums begin at (74,64); digit sheets keep the original
11-frame ordering and carry timing. Multiplier and loss artwork occupies y82.
Payout/targeting callouts retain CRT priority; FREE SPIN replaces target text only.

Three separate lamps above the reels fill at 10/20/30 coins (6/12/18 with
Adrenaline). Coin pops and flights begin at the cash outlet (80,298). A restore
flashes the lamps and resets them; an ineligible restore leaves the bank full.
Power acquisition order and all gameplay locks are unchanged.

`jackpot_beacon.svg` mounts amber glass on a metal base above the CRT. Its three
native frames preserve the existing payout hold, lit state and alternating flash.

Augment stickers occupy the lower cabinet at x48/74/100, y260, with worn paper
edges, 14px icons and hold-for-details behavior. They remain visible during CRT
callouts. Learning's book and Tunnel Vision's shutter remain independent layers.

Generators: `tools/generate_composition_hardware.py` authors cabinet surfaces,
progress, wealth hardware and jackpot beacon; `tools/generate_crt_hardware.py` authors approach,
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
