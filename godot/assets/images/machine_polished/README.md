# Machine art: first playable pass

The cabinet and power chips are editable SVG artwork on an integer pixel grid.
Godot imports the cabinet at 160x320 and each power strip at 480x320; nearest
filtering keeps the artwork at the same pixel scale as the game. There are no
runtime dependencies outside `godot/assets`.

The cabinet keeps transparent apertures at x33, 65 and 97, y169, 21x34 pixels.
The existing scoring/hit rectangles remain x33/65/97, y170, 21x30. The surrounding
mask accommodates adjacent reel symbols and the existing reveal animations.

Each power has available, selected and disabled frames. Artwork occupies 11x11
pixels at y225, starting at x20 and advancing 14 pixels in canonical power order.
Runtime acquisition order moves these independent chips into the first three
slots, using the existing targeting buttons and restore animations.

Tunnel Vision mounts the separate 21x34 shutter over the third reel. An opaque
scoring cover remains underneath throughout the lowering animation. Removing
the augment removes the shutter; this presentation adds no save fields.

The material shader harmonizes the existing moving hardware with the new
cabinet. Reels, warning callouts and power-state glyphs retain their own colours.
The approved generated image is an art-direction reference, not a runtime texture.

Visual review (PowerShell, isolated saves):

```powershell
$env:APPDATA = "$PWD/tmp/machine-art-user"
New-Item -ItemType Directory -Force tmp/machine-art-review
$env:ART_REVIEW_DIR = "$PWD/tmp/machine-art-review"
godot --path godot --resolution 480x960 -s res://test/debug_machine_art_review.gd
```

The review captures the actual scene in idle, selected, spent, spinning, revealed
and Tunnel Vision states. The scene smoke suite checks existing power interactions
and the shutter's geometry, visibility and input transparency.
