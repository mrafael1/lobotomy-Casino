# Painted card icons

`book.png` is the 22x27 runtime Book icon. It replaces the original atlas icon
through card metadata in Pacte, route build choices, Collection and unlock popups.
Generated with the built-in image generation tool, then cropped to alpha bounds
and reduced for native display. The original icon atlas remains for other cards.

Prompt: Create one production game sprite: a sinister antique medical book,
closed, three-quarter view, worn dark oxblood leather cover, small embossed ivory
brain emblem with no text, brass corner guards, warm yellowed page edges.
Centered isolated object, genuinely transparent background, no ground plane,
no cast shadow beyond object, no lettering. Premium hand-painted pixel-art
matching a gothic red enamel casino and ivory parchment cards. Strong clear
silhouette, restrained highlights, chunky intentional pixels, extremely readable
when displayed at 22 by 27 pixels. Portrait sprite. Single book only.

Seventeen additional static icons and the power coin export at 128x128 from
the painted masters using tools/prepare_premium_card_icons.gd. Static card
icons keep 24x24 layout footprints with linear mipmap filtering. Book and the
authored animated icons retain their existing presentation in this pass.

## High-resolution Book replacement

`augment_book.png` replaces the reduced `book.png` in all live card views.
Generated with the built-in image tool on 2026-09-22; the transparent master is
kept at its generated resolution and uses mipmaps at the shared 24x24 layout size.
The original tiny file remains for older references.

Prompt: One closed sinister antique medical book, three-quarter view, worn
oxblood leather, embossed ivory brain emblem, brass corners and clasp, yellowed
page edges. Chunky hand-painted pixel-art matching the Hallucination icon, dark
outlines and restrained highlights. Transparent background, no text, no card,
no ground shadow. High-resolution export; do not reduce to 22x27 pixels.
