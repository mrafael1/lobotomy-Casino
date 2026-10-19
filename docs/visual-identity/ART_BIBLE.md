# The House Remembers

Phase-one visual direction for **Lobotomy Casino**, revision 04, 19 October 2026. The house is an intimate, disreputable working casino. Its courtesy is the mechanism of its menace. The healthy machine is its brightest lure, and its existing multiplier drives a full-cabinet output ladder. [Current revision](REVISION_04.md) establishes x1 ready, x2 hot and x3 maximum output; [revision 03](REVISION_03.md) establishes the healthy reward focus.

## The visual promise

The player sits down at a baize table, accepts a house favour, and turns to an antique gaming console. The same employee keeps finding them. Every transaction feels professionally administered; only gradually does the precision become possessive. No haunted-hotel corridors, reception desk, scattered brain wallpaper, or decorative gore.

**Signature shapes:** a shallow horseshoe gaming rail; a stepped ruby-and-gold slot cabinet with a radiant crown; tall, divided reel drums; a continuous recessed account window; a croupier's long, hooked dealing fingers; the small paired cuts of a registration mark. The casino's LC monogram is a printer's seal, not a medical logo. Restrained clinical motifs live in calibration ticks, pressure equipment, employee number 00, a collar seam, and the house's memory of each account. The healthy cabinet itself sells delight before deterioration.

## Grid and scale

- All scene masters are **640×1280 source pixels**, mapped to **160×320 layout units**, so one source pixel is 0.25 layout units. Card fronts are 156×244 source pixels, equivalent to 39×61 layout units. Character construction uses this same source grid. Stable recipe coordinates map to two source pixels; native one-pixel detail uses the finer grid directly.
- Every contour, ellipse raster, line, highlight and shade is rasterised directly onto integer source pixels. Cubic contours are sampled to that grid without antialiasing. No painted inputs, enlargement of old raster art, image quantization or noise fields generate the source illustrations. The 106-colour palette is defined in `tools/house_identity/pixels.py`: subdued house materials, healthy-machine materials and controlled heat ramps.
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

**Healthy-machine exception:** keep the room, tables and meta interfaces dark, but make the machine an enticing object in good repair. Ruby lacquer (`#a8324b` → `#f58b80`), polished gold (`#c48b4a` → `#ffe2a1`), jade glass (`#176465` → `#b9f4ce`) and bright cream drum stock (`#d1ba8e` → `#fff0ce`) give it a separate reward hierarchy. Warm tungsten bulbs surround the marquee and drums. Do not apply the room's gloom to the primary play object. End-of-run decay is a later, separate treatment.

**Multiplier heat:** x2 shifts the enamel, trim, glass, control surrounds and floor light into active red-orange/amber output. x3 runs at maximum output: white-hot cores (`#ffffe7`), incandescent reel lips, radiant enamel, glowing metal, vent-fed exhaust and a thin stream of embers. This is the whole working machine under load. No cracks, missing parts or decay are used to explain the multiplier. Keep numerical and input regions fixed, and preserve green/red item-duration semantics through every heat state.

## Light and hierarchy

Warm pendant light makes the offer attractive and locates the table in the casino. Faces catch a narrow top-left key; eyes stay recessed. Brass reflects that key rather than emitting a universal outline. The healthy console is visibly brighter: its own tungsten lamps, cream drums and jade glass establish its attraction. Advanced engagement intensifies the lights while keeping the machine healthy. Quiet dark areas frame that focus rather than darkening the whole cabinet.

In Pacte: **three offered faces → selected card → dealer response → table apparatus**. In the machine: **reel result → score versus target → SPIN/resources → powers/items → dealer approach**. Wealth and target occupy one continuous window below the reels. The dealer does not appear inside the console. A warm lamp chase creates anticipation; a win synchronises the lamps, delivers the score pop and settles separate Lucidity coins in the tray. UI and input geometry stay fixed. The background may lose contrast at phone size; the reels and control deck may not.

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

The healthy machine has a more eager rhythm: **invitation → anticipation → reward → satisfying settle**. Keep the chase on decorative lamp banks, so it cannot be confused with the actual approach/countdown. A fixed pair study demonstrates +10 score travelling directly to wealth while distinct Lucidity coins remain at the tray. Production amounts always come from existing game events. Decay is deferred until this healthy reward benchmark is established.

Heat adds a second rhythm owned by the existing frenzy tier: x1's warm chase, x2's quicker hardware rhythm, and x3's sustained white-hot output with exhaust and embers. The x3 plateau should feel like the machine is giving everything. Avoid repeated full-screen on/off flashing; protect controls and symbols from particle cover. The output-ladder GIF is a comparison study, not a rule that tiers advance on a timer.

See the review gallery for constructed scene mockups, all card faces, dealer states and timing prototypes. These establish composition and material direction. They are proposal assets, **not integrated gameplay screens**; remaining production layering and acceptance checks are in [INTEGRATION.md](INTEGRATION.md).
