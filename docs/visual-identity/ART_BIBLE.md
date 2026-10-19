# The House Remembers

Phase-one visual direction for **Lobotomy Casino**, revision 02, 19 October 2026. The house is an intimate, disreputable working casino. Its courtesy is the mechanism of its menace. You are a customer before you are a patient. [Revision notes](REVISION_02.md) explain the darker materials, finer raster construction and rebuilt living console.

## The visual promise

The player sits down at a baize table, accepts a house favour, and turns to an antique gaming console. The same employee keeps finding them. Every transaction feels professionally administered; only gradually does the precision become possessive. No haunted-hotel corridors, reception desk, scattered brain wallpaper, or decorative gore.

**Signature shapes:** a shallow horseshoe gaming rail; a bowed oxblood cabinet with a tensioned grille; tall, divided reel drums; a continuous recessed account window; a croupier's long, hooked dealing fingers; the small paired cuts of a registration mark. The casino's LC monogram is a printer's seal, not a medical logo. Restrained clinical motifs live in calibration ticks, pressure equipment, employee number 00, a collar seam, and the house's memory of each account.

## Grid and scale

- All scene masters are **640×1280 source pixels**, mapped to **160×320 layout units**, so one source pixel is 0.25 layout units. Card fronts are 156×244 source pixels, equivalent to 39×61 layout units. Character construction uses this same source grid. Stable recipe coordinates map to two source pixels; native one-pixel detail uses the finer grid directly.
- Every contour, ellipse raster, line, highlight and shade is rasterised directly onto integer source pixels. Cubic contours are sampled to that grid without antialiasing. No painted inputs, enlargement of old raster art, image quantization or noise fields generate the source illustrations. The 66-colour palette is defined in `tools/house_identity/pixels.py`.
- Enlarged inspection repeats the same original pixels with nearest sampling, an intentional magnification of a physical card. It never introduces a second illustration density. Close-ups in the review are also exact nearest magnifications.
- Keep Canvas Items, expanded aspect, fractional scaling and the existing centred safe area. The source grid is an **art convention**, not a new render resolution. Essential text and touch targets remain in the safe area; overscan is expendable casino floor and shadow.
- Inspect both 160×320 reductions and a phone presentation. Source pixels cannot stay integer-sized at every fractional display scale; use nearest texture filtering without mipmaps, and test shimmer at the actual viewport before integration acceptance.

## Palette and materials

| Material | Shadow → body → light | Use |
|---|---|---|
| Atmosphere | `#090c0e` → `#101719` → `#202b2c` | Quiet negative space, unlit floor, cavities |
| Walnut | `#171315` → `#432c27` → `#886342` | Carved cheeks, shoe, rail, gambling furniture |
| Oxblood leather | `#1d131a` → `#542833` → `#b06459` | Padded contact edges and sleeve garters |
| Baize | `#0d211f` → `#23483d` → `#68836b` | Real play surfaces and worn betting areas |
| Aged brass | `#2b2722` → `#81683e` → `#ddbf88` | Account apertures, lamp rims, useful machinery |
| Stock and bone | `#655e51` → `#b7ac91` → `#f4e3bf` | Cards, enamel controls, readable names |
| Skin | `#302328` → `#8d604e` → `#c9aa86` | Broad cheek/forehead planes, knuckles, nose |
| Clinical glass | `#263a3d` → `#78928d` → `#b2c1ab` | Recessed instruments and optical anomalies |
| Phosphor | `#234d46` → `#8edbb0` → `#d8f2c0` | Live score, beneficial duration, selected power |

Use connected shade clusters. Wood grain follows the length of a structural member. Leather stitching follows the padded curve. Metal highlights sit on chamfers. Paper damage lives at handled corners; baize fades inside repeated betting arcs. Reserve isolated pixels for screws, stitches, iris reflections and tiny calibration marks.

## Light and hierarchy

Warm pendant light makes the offer attractive and locates the table in the casino. Faces catch a narrow top-left key; eyes stay recessed. Brass reflects that key rather than emitting a universal outline. The console's phosphor provides a local cool counterlight. Advanced heat is emitted by lamps and reel apertures, leaving the deck readable. Roughly half a scene should remain low-value and quiet; never fill every recess with texture.

In Pacte: **three offered faces → selected card → dealer response → table apparatus**. In the machine: **reel result → score versus target → SPIN/resources → powers/items → dealer approach**. Wealth and target occupy one continuous window below the reels. The dealer no longer appears inside the console. The body feels alive through a tensioned diaphragm, bellows and restrained breathing reflections; UI and input geometry stay fixed. The background may lose contrast at phone size; the reels and control deck may not.

Large source titles use a deliberate 5×7 bitmap alphabet at integer scales. Offer names are smaller and gain readable live text in inspection. All production names, descriptions, prices and numbers must become live localized text. Raster labels in these compositions describe typesetting, not a replacement for data bindings.

## Mr. Vey

An older, stooped employee with a high receding crescent of silver hair, crooked long nose, unequal orbital shadows, green waistcoat, narrow oxblood tie and rolled sleeves caught with garters. A tiny watch chain and numbered tag are worn through years of service. His clean hands handle real cards and chips. He doesn't brandish props for the camera.

| State | Face and body | Behaviour | House response |
|---|---|---|---|
| Welcome | Small calculated smile; one recessed eye | Looks to the card, then to you; palm open | Amber table key, cool console glass |
| Doubt | Same smile survives a little too long | Gaze moves first; blink is delayed; hands remain exact | The table's brass catches a lingering reflection |
| Pressure | Collar relaxes; eyes catch the console light | Holds proximity after a transaction; no idle fidget | Light retreats from the room toward your account |
| Late | Old indexing cuts and a second seam under the collar; horizontal iris glint | His professional pose survives the visible anomaly | Apertures run hot; employee number stays 00 |

The late design preserves the nose, hair crescent, garters, chain and hands. Recognition is more disturbing than replacing him with a different monster. The reveal is concentrated in the face/collar, never a full-screen blood effect.

## Cards

Augments are engraved dark illustrations printed on worn pale stock with green rules. Powers use burgundy lacquered backs, brass rules and pale lettering. Both families use 156×244 source fronts and the same illustration window. The backs have woven registration diamonds and the LC seal.

Each of the 21 current card IDs has its own constructed scene. Reward I is a loupe, II an optical bench, III a crown press: related intent with three different silhouettes and compositions. Smart Saving is a deposit into a secured cash box; Passive Gain is a dripping brass tap; Combo is a ratcheting staircase of chip stacks. Powers depict an action performed on real gaming apparatus. Glitch retains **no central icon**: its illustration is failed registration and torn printing. Pattern Recognition has five moving registration frames; Is It Cheating has a sliding false shadow. Do not drop the existing animated identity during implementation.

## Motion

The recurring rhythm is **courteous action → precise settle → uncomfortable hold**. No universal bounce tween. A card glides, touches the felt, then stops. Vey's eyes move before his head; breathing stays nearly invisible. A power coin clicks into a fitted socket. Reel deceleration is mechanical, not gelatinous. Gains count with phosphor persistence; a target payment drains right-aligned digits before the route transition. Warnings pulse only their dedicated light and leave controls legible.

See the review gallery for constructed scene mockups, all card faces, dealer states and timing prototypes. These establish composition and material direction. They are proposal assets, **not integrated gameplay screens**; remaining production layering and acceptance checks are in [INTEGRATION.md](INTEGRATION.md).
