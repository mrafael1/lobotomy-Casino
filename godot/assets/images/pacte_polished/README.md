# Painted Pacte scene asset

`pacte_scene_painted.png` is the full-resolution 887x1774 composition asset for
the augment/power table, generated with the built-in image-generation tool.
It follows the approved machine preview: cadaver-green dealer, worn crimson
enamel, dark green felt, brass trim and cyan/red casino lighting.

The 160x320 `pacte_scene_native.png` derivative is now the active base layer in
`pacte_scene.gd`. It supplies the room, dealer and felt as one crisp nearest
sampled composition. Live decks, cards, emplacement masks, descriptions and
prompts remain separate runtime nodes so the ritual can still animate and save
its state. The high-resolution file is retained as the editable source master;
the native derivative is the exported runtime asset.

References: `tmp/preview.jpg` (style) and
`godot/assets/images/pacte_scene/pacte_scene.png` (composition).

## Generation prompt

Create one finished updated game scene asset for Lobotomy Casino's Pacte augment/power selection screen. Portrait exact 1:2 aspect ratio, designed for a 160x320 virtual canvas, render at high resolution as a cohesive painted pixel-art illustration with crisp intentional pixel clusters. Reference 1 (machine preview) is the required visual style: worn crimson enamel, black-green shadows, muted cadaver green, tarnished brass, warm ivory, cyan/red neon, eerie elegant casino, tangible beveled construction, deliberate restrained textures. Reference 2 (old Pacte scene) is ONLY the composition/layout guide; completely replace its crude flat artwork with the craftsmanship of reference 1. This is a new table/dealer scene, NOT a slot machine. Use the same skeletal cadaver-green male dealer identity as the portrait in reference 1: hollow eyes, slick dark hair, dark suit, white shirt, small muted burgundy bow tie, knowing grin, long bony hands resting together at the far table edge. Dealer centered in upper third, head around canvas (80,47), shoulders and hands around y75-97; keep his silhouette readable, no gore. Dark casino wall behind him, subtle red vertical neon at edges and a small cyan OPEN sign upper left. Table far edge crosses at y100 with worn red enamel and brass trim; broad dark green felt playing surface fills y110-300, perspective gentle and symmetric, front padded crimson lip at y306. Reserve unobstructed live gameplay zones EXACTLY in native coordinates: deck footprints around (16,118,24,40) and (115,118,24,40); three offered-card footprints (10,174,39,61), (61,174,39,61), (112,174,39,61); two smaller placement recesses (28,256,25,36) and (107,256,25,36). In all those zones, show empty felt / subtle shallow placement outlines ONLY, no cards, icons, text, numbers or props. Keep y140-172 quiet for runtime descriptions and y238-250 quiet for drag instructions. Bottom two recesses may have thin worn brass contours, one subtly cool cyan and one subtly warm red accent, but NO labels. Top corners leave room for UI. All functional cards, decks, labels and prompts are runtime layers added later. No title, no AUGMENT or POWER text, no fake interface, no buttons, no watermark, no mockup border, no annotations. Deliver a single full bleed image, beautifully integrated physical geometry, clean corners, restrained pixel texture rather than random speckles. Preserve generous negative space on the table; the dealer and craftsmanship should provide atmosphere without crowding card content.
