# Painting provenance

Both PNGs were generated with the built-in image-generation tool. The source
paintings are preserved here; Godot imports them at the native runtime size.
No API/CLI fallback was used.

## Cabinet prompt

Create a production BACKGROUND/CABINET TEXTURE for a modular pixel-art slot-machine game. Image 1 is the APPROVED quality/material reference: capture its beautifully shaded blood-red enamel, beveled gunmetal, worn corners, convincing inset glass and restrained illumination. Image 2 is the EXACT layout template to repaint. Preserve Image 2's framing, proportions and every opening position, but achieve Image 1's artistic quality. Portrait exactly 1:2. Work as a 160x320 pixel-art canvas enlarged uniformly; strong pixel clusters and shaded forms, no photographic noise or blur. IMPORTANT: this is the EMPTY HARDWARE layer, no baked gameplay: remove ALL words, numbers, dealer portrait, icons, symbols, buttons glyphs, currency, health tube and side lever from image 2. Keep the SCREEN empty near-black green, reel apertures empty black. Coordinates on 160x320 canvas: cabinet upper red CRT frame x20..132 y40..114; black screen x35..116 y57..107. Silver multiplier panel x20..130 y116..137 with THREE empty black round sockets centered x47,78,106 y127. Red header y139..151. Reel housing x28..124 y153..209: three empty black apertures x33..53,65..85,97..117 y169..202. Warm ivory inset lamps above reels y157..160. Metal lower control shelf y211..221. Narrow red power rail x8..141 y223..239, EMPTY dark power mounting recess x18..59 y225..236, rest of rail clear red. Lower red panel x16..135 y242..287, NO odometer / numbers / dial drawn here: uninterrupted rich red enamel with enough plain area around x40..110 y250..277 to receive live odometer. Bottom payout tray below y300. Outside cabinet mostly black with faint atmospheric dark crimson vertical casino reflections, never UI or text. Keep the same overall cabinet silhouette as image2, not the taller layout of image1. Make its large surfaces sculpted, subtly curved enamel via careful banded shading; highlights strongest near upper left; dark seams, fine brushed metal, sparse scratches and exposed screw heads. Professionally authored indie horror pixel art, a real beautiful appliance with depth not a flat diagram. Output ONE full-frame cabinet texture without any captions, interface overlays, characters, text, symbols, numbers, or extra objects.

## Dealer portrait prompt

Create a SINGLE tiny pixel-art dealer portrait sprite for the CRT in the reference game. Reference image supplies character identity: sinister hollow-eyed medical casino dealer, slick dark hair, pale cadaver-green face, deep eye sockets, knowing thin smile, dark suit, small oxblood tie. ONLY a tight bust portrait, head occupies top two thirds, shoulders bottom third; no hands, no cabinet, no text. Exactly 2:3 aspect ratio. CRITICAL pixel design constraint: design as just 14 pixels wide by 21 pixels high, displayed greatly enlarged in exact square blocks, maximum about 12 colors. Bold low-resolution readable clusters, facial eye sockets are two dark 2x2 clusters; avoid fine lines, realistic detail or dithering. Dark near-black green background filling rectangle, no transparency needed. Authored premium horror-game pixel sprite, strong readable face even when thumbnail-sized. Flat orthographic face forward. No glow, no blur, no decorative frame. Deliver only the portrait.

## Registration

The generated cabinet did not exactly follow the requested coordinates. The
registration shader fits each assembly to the existing game layout. The
aperture mask is independently authored and tested to keep the reels visible.
