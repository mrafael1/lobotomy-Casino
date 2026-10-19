# Revision 02 — a darker house, a living cabinet

This pass follows the owner's feedback on the first visual review: keep the casino/table/card ideas; polish artefacts and placement; reduce the faceted appearance and brightness; replace the unsuccessful console with a clean interface and a machine that feels alive.

## Kept

Pacte, the single-deck build scenes, Collection's folio, House Records' tally receipt, the odds register and the two card families retain their compositions and identities. They receive the shared darker material ramps and finer raster construction. These remain phase-one design assets rather than an integrated game skin.

## Changed

- All source masters now use **640×1280 pixels for the same 160×320 safe area**; cards are 156×244 for 39×61 layout units. The recipe coordinate unit is two source pixels. Curves/ellipses/diagonals rasterise directly at the finer density, and native one-pixel engraving, seams, facial creases and material highlights use that grid. No previous raster is upscaled to produce source art.
- The palette has 66 fixed colours: darker walnut, oxblood, felt, paper and skin bodies, plus intermediate material tones. Text, live phosphor and small contact highlights keep their contrast. The pass is not a uniform black overlay.
- Mr. Vey's face and garment work use softer constructed contours and narrower details. His identity and four-stage progression remain. His portrait is **removed from the console**.
- The console is rebuilt as a bowed oxblood slot cabinet with a tensioned diaphragm behind a crown grille, side bellows, glass drums, a continuous account window and a separate control shelf. The machine's physical response supplies its presence.
- Wealth and target share an aligned account window beneath the reels. Approach/warning lamps, powers, SPIN/spins/stash, item durations and build tabs each have an allotted region. Stash silhouettes fit inside their cup wells.
- Six-frame breathing moves only the diaphragm/bellows and a small exhale reflection; the account text, reel apertures and controls stay fixed. Advanced strain is kept inside the body and lamps. It creates no mechanic, timer or seeded random draw.
- Corrected the card-shoe stack geometry; rebuilt frame-dependent crop/export calculations for the common density. Image replacement is atomic so the open editor cannot import half-written PNGs.

## Review

[Updated gallery](review.html), [phone-size study](../../godot/assets/art_direction/house_remembers/phone_study.png), [console source master](../../godot/assets/art_direction/house_remembers/scenes/04_machine_early.png), [breathing prototype](../../godot/assets/art_direction/house_remembers/animation/cabinet_breath.gif).

The finer source grid is a new art benchmark, not a claim that every illustration has received final production polish. Long localized text, full input behaviour, masking, actual mobile readability and all gameplay-state transitions still need the phase-two integration review. The existing mechanics/controllers have not been changed.
