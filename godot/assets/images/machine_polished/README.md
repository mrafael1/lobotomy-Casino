# Machine art: painted playable pass

The cabinet and dealer portrait are generated paintings based on the approved
concept, produced with the built-in image-generation tool. Godot imports the
cabinet at 160x320 (size limit 320) and the portrait at 14x21 (size limit 21).
The original paintings remain in the PNG source files. Nearest filtering and
pixel-quantized registration keep the scene on its virtual pixel grid.
Power chips remain separate editable 480x320 SVG state strips.
The five `spin_*.svg` files are separate native 46x28 pixel-grid button assets:
normal, pressed (face depressed three pixels), disabled, hover and focus.
They use an ivory face, brass bezel and dark pixel lettering; no cabinet edit
or image-generation dependency is needed to adjust these vector controls.
There are no runtime dependencies outside `godot/assets`.

`painted_cabinet.gdshader` fits the painting's horizontal assemblies to the live
scene's measured geometry. `apertures.svg` supplies the exact transparent reel
holes. The texture includes the casino backdrop and empty cabinet hardware;
dealer, counters, symbols and interaction states are rendered independently.
`reel_drums.svg` supplies native paper drums with curved warm shading. Settled
covers sample this same 160x320 texture, without a shader substitute.
`reel_motion.svg` supplies four 160x320 motion frames with matching paper and
indistinct symbol streaks. Each reel advances/stops independently; its crop and
scale are derived from the actual sheet dimensions. `reel_housing.svg` supplies
separate worn-metal bezels and ivory lamps, leaving every aperture pixel clear.
The odometer material still fits a steel surround around the animated digits.

The cabinet keeps transparent apertures at x33, 65 and 97, y169, 21x34 pixels.
The existing scoring/hit rectangles remain x33/65/97, y170, 21x30. The surrounding
mask accommodates adjacent reel symbols and the existing reveal animations.

The layout follows `tmp/preview.jpg`: large powers under the CRT, a small screen
multiplier, then the reels and a deeper physical shelf. Cabinet registration now
opens the CRT header and stretches the metal shelf over y203..241; gameplay
apertures stay independent and unchanged.

SPIN's touch area is (57,210,46,28), centered at x80. The count uses the left
well (26,211,29,19), while the two 16px stash icons sit inside the right-hand
tray (103,213,36,24). All three are separate runtime controls. Lower Shift
arrows share the shelf only while targeting: SPIN yields mouse/touch events.
The lever and coin-insert source files remain for the later asset cleanup.

Power faces are 22px circles at y116, centered at x46/77/108. Their touch boxes
are 26x26 at y114. All seven powers have available, selected and spent frames,
with ivory glyphs, a green selected rim and muted spent faces. Acquisition order
moves the first three owned powers into these sockets; other owned IDs stay
hidden under the existing three-slot rule.

The multiplier and loss sheets render in the CRT header (83,47,41,12), retaining
the existing six multiplier states, Energy Drink cap, x2 warning pulse and nine
x3 warning frames. Augment badges sit at (32,45) on a 14px pitch. Both normal
multiplier and augment badges yield to TV callouts; the large power controls
remain visible. New warning/effect SVGs use the existing presentation cadence.

Tunnel Vision mounts the separate 21x34 shutter over the third reel. An opaque
scoring cover remains underneath throughout the lowering animation. Removing
the augment removes the shutter; this presentation adds no save fields.

The material shader harmonizes the existing moving hardware with the new
cabinet. Reels, warning callouts and power-state glyphs retain their own colours.
The approved generated concept remains a reference. The two new paintings in
this directory are the runtime source assets. `cabinet.svg` is the earlier
geometric prototype and is no longer used by the machine.

Visual review (PowerShell, isolated saves):

```powershell
$env:APPDATA = "$PWD/tmp/machine-art-user"
New-Item -ItemType Directory -Force tmp/machine-art-review
$env:ART_REVIEW_DIR = "$PWD/tmp/machine-art-review"
godot --path godot --resolution 480x960 -s res://test/debug_machine_art_review.gd
```

The review captures idle, SPIN pressed/disabled, Lock/Shift targeting, spent
chips, spinning, reveal, Tunnel Vision, payout and dealer interruption, x2/x3 warnings and a full augment row. It
exercises actual viewport mouse events and focused Enter activation, including
the lower Shift arrow over the SPIN area. The scene smoke suite checks existing power interactions
and the shutter's geometry, visibility and input transparency.

The reel geometry checks verify native texture sizes, full drum coverage, transparent
frame apertures, matching landing covers and horizontal motion-frame crops. The
previous reel/backing PNGs and paper shader are retained as source material, but
the active machine no longer references them.
