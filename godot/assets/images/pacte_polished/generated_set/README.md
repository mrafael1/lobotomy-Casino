# Painted deck, item and card source artwork

Generated with the built-in imagegen tool using `../pacte_scene_painted.png`
as the material, palette and perspective reference.

The three large sheets remain source artwork. The sliced 32x32 PNGs in
`godot/assets/images/items/generated` are the active runtime item textures;
they are nearest-sampled to the shared 16px stash/offer size.

- `decks_painted.png`: augment stack on the left, power stack on the right.
  Target native footprint: 28x32 per stack, at (13,109) and (119,109).
- `items_painted.png`: 3x3 grid. Tobacco, Serum, White Powder; Potion, Tea,
  Energy Drink; Cocktail, Water, Red Pill. Target native icons: 16x16.
- `cards_painted.png`: augment front/back, power front/back, left to right.
  Target native card size: 39x61. Names, descriptions and gameplay symbols
  remain runtime elements.

The generated card and deck crops are now active in Pacte:
`cards_detail.png`, `augment_deck_detail.png`, and `power_deck_detail.png`.
These export at four source pixels per layout unit and use linear mipmaps.
Card faces occupy 156x244 source pixels; deck stacks occupy 112x128.
The previous native exports remain compatibility assets.
The legacy SVG deck placeholders are no longer referenced by the scene.

The generated item sheet is sliced by `tools/slice_item_sheet.gd` into
`tobacco.png`, `serum.png`, `white_powder.png`, `potion.png`, `tea.png`,
`energy_drink.png`, `cocktail.png`, `water.png`, and `red_pill.png`.

The generation prompts are preserved in `prompts.json`.

Background extraction was performed with imagegen after the initial outputs
included painted checkerboards. All three saved PNGs have an RGBA channel and
transparent outer backgrounds. Decks and items needed a second extraction pass,
using the cleaned card sheet as an empty-background reference. Full-resolution
silhouettes were visually reviewed; native-canvas readability is still pending.
