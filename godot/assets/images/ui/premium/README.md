# Compact premium UI artwork

These SVGs are authored UI geometry using brass, cream and dark-green colors.
Their source dimensions are four times the gameplay layout size where detailed
borders benefit from it. They are code-native artwork, not generated bitmaps.

- `menu_title_plate.svg`: 148x66 layout units at (6,48).
- `menu_selector_brass.svg`: 144x41 layout units at (8,176).
- `menu_selector_arrow.svg`: transparent 12x21 arrow, mirrored for the right side.
  The arrow stays separate so disabled tint and press scaling affect only its glyph.
- `shop_reroll_brass.svg`: two 31x27 frames at (1,77), including border padding.

Keep these exports cropped to their decorative bounds. Full-screen transparent
padding adds texture memory without improving resolution or overscan coverage.
The scene scripts retain their original safe-area coordinates and live hitboxes.
