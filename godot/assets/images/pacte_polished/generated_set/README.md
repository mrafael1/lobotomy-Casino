# Painted deck, item and card source artwork

Generated with the built-in imagegen tool using `../pacte_scene_painted.png`
as the material, palette and perspective reference.

These are source sheets for the next integration pass, not active runtime
textures. Native-size slicing, edge cleanup and in-scene alignment must be
reviewed before replacing the current assets.

- `decks_painted.png`: augment stack on the left, power stack on the right.
  Target native footprint: 28x32 per stack, at (13,109) and (119,109).
- `items_painted.png`: 3x3 grid. Tobacco, Serum, White Powder; Potion, Tea,
  Energy Drink; Cocktail, Water, Red Pill. Target native icons: 16x16.
- `cards_painted.png`: augment front/back, power front/back, left to right.
  Target native card size: 39x61. Names, descriptions and gameplay symbols
  remain runtime elements.

The generation prompts are preserved in `prompts.json`.

Background extraction was performed with imagegen after the initial outputs
included painted checkerboards. All three saved PNGs have an RGBA channel and
transparent outer backgrounds. Decks and items needed a second extraction pass,
using the cleaned card sheet as an empty-background reference. Full-resolution
silhouettes were visually reviewed; native-canvas readability is still pending.
