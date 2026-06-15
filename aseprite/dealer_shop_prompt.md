# Dealer Shop — Aseprite / Lua Generation Prompt

A self-contained brief for generating the **dealer shop ("bar") scene** as
pixel art via Aseprite Lua scripts. Hand this whole document to an art/codegen
pass. Everything here is authoritative — coordinates must match
`src/screens/DealerShopScreen.tsx` exactly or the tap targets and overlays will
drift.

---

## 1. Concept

A seedy neon **casino bar**. The player walks up to the counter; a **dealer
(bartender)** stands behind it. Behind the dealer, three **wall shelves** display
permanent upgrades. On the **counter** in front of him sit single-use supplies.
A **stash tray** in the bottom-left corner holds whatever the player buys.

The player browses by tapping an item (shows its description), and buys it. The
intended buy gesture is **drag the item onto the dealer** (tap-to-buy is the
current stand-in). Purchased **supplies drop straight into the stash tray**.

---

## 2. Canvas & output

- **Source canvas:** `320 × 480` (portrait). RGB, transparent where noted.
- Pixel-art, 1px detail, neon-on-dark palette.
- The background **stretches to fill the whole screen** at runtime, so keep
  important detail away from the extreme top/bottom edges (they may crop/stretch).
- Three separate output files (three render layers, see §3).

---

## 3. Layers (render order, back → front)

The scene is composited at runtime in **three layers**. Generate each as its own
file. **Do not merge them.**

| # | File | Contents | Alpha |
|---|------|----------|-------|
| 1 | `assets/images/dealer_shop_bg.png`      | Wall, ceiling neon, 3 shelf boards + accent rails, back-bar backdrop panel | opaque |
| 2 | `assets/images/ui/dealer_portrait.png`  | The dealer (bartender), **already exists** — do not regenerate here | transparent surround |
| 3 | `assets/images/dealer_shop_counter.png` | Counter top + front face. **Fully transparent above y=358** so the dealer shows through; opaque counter from y=358 down. Hides the dealer's lower body ("his non-legal" parts). | transparent top |

> Why split: the counter must render **in front of** the dealer to occlude his
> legs, while the shelves render **behind** him. A single baked image can't do
> both.

---

## 4. Palette

```
WALL      #0e081c   deep purple-black wall
CEIL      #140a24   ceiling band (slightly lighter)
BOARD     #3a220e   shelf wood
LIP       #523014   shelf wood lit edge
BACKBAR   #16102c   panel behind the dealer
BOTTLE    #241840   faint bottle/shelf lines on the back-bar
CTR_TOP   #1e3644   counter top surface (dark teal)
CTR_FACE  #142430   counter front face
CTR_HI    #285064   counter front-edge highlight
NEON_PINK #ff2d55   ceiling neon trim
NEON_CYAN #00e5ff   counter neon strip / supplies accent

Shelf accents:
  POWERS    #a855f7  (purple)
  POSITIVE  #22c55e  (green)
  CORRUPTED #ef4444  (red)
```

---

## 5. Layout (source px — must match the screen)

### Layer 1 — `dealer_shop_bg.png`

- **Wall:** fill `#0e081c`. Ceiling band `y=0..11` `#140a24`.
- **Ceiling neon:** `y=12` pink `#ff2d55`, `y=13` `#601020`.
- **Three shelves** — each = accent rail at `boardY-1`, 2px wood board at
  `boardY..boardY+1`, lit lip at `boardY+2`. No item cells (icons are overlaid).
  | Shelf | accent | boardY |
  |-------|--------|--------|
  | POWERS    | `#a855f7` | 56  |
  | POSITIVE  | `#22c55e` | 110 |
  | CORRUPTED | `#ef4444` | 164 |
- **Back-bar backdrop:** filled panel `#16102c` at `x=70..250, y=168..390`.
  Vertical bottle lines `#241840` at `x = 90,130,170,210,230`, `y=176..330`.
  Two faint horizontal shelf lines `#2a1c48` at `y=176` and `y=280` (`x=72..248`).
- **No counter here.**

### Layer 3 — `dealer_shop_counter.png`

- Transparent everywhere **above y=358**, except a soft shadow stripe
  `#101c26` (~80% alpha) at `y=352..357` so overlaid icons read against it.
- Counter top surface `#1e3644` at `y=358..369`.
- Front-edge highlight `#285064` at `y=369`.
- Counter front face `#142430` at `y=370..479`.
- Neon strip: `y=371` cyan `#00e5ff`, `y=372` `#006080`.

### Layer 2 — dealer (overlaid by the app, listed for reference)

- `dealer_portrait.png` is 192×288 (aspect 2:3).
- Rendered centered, aspect-preserved, **base at y=358** (counter top),
  visible height ≈ 190px in source space.

---

## 6. Item icons (overlaid by the app — NOT drawn in these files)

Icons float directly on the shelves/counter — **no cell frames**. A 2px accent
ring appears only on the selected icon. Tap target = the icon box below.

- **Shelf icons:** 44×44, `x = 18, 66, 114, 162, 210, 258` (6 per shelf).
  Icon-row top-Y: POWERS `y=12`, POSITIVE `y=66`, CORRUPTED `y=120`.
- **Supply icons (on counter):** 52×52, `y=295`, `x = 22, 90, 158, 226` (4).
  Rendered after the counter layer so they read as resting on the bar.

Content mapping:
- POWERS row → `ABILITY_UPGRADES` (Shift, Memory)
- POSITIVE row → `POSITIVE_UPGRADES`
- CORRUPTED row → `CORRUPTED_UPGRADES`
- Counter supplies → `CONSUMABLES`

Until bespoke art exists, every icon uses the placeholder vial
(`assets/images/ui/consumable_placeholder.png`).

---

## 7. Stash tray (NEW)

- Reuses the existing `assets/images/ui/stash_tray.png` (66×34, two 24×24 slots).
- **Pinned to the bottom-left corner** of the screen (overlay, not baked into the
  scene). Width ≈ 104px, label "STASH" above it.
- Holds the player's queued **supplies** (the 2-slot supply cap maps 1:1 to the
  tray). **Buying a supply drops it directly into the tray** with a `×N` charge
  badge. Upgrades are permanent and do not appear in the tray.
- Read-only in the shop (display only; not tappable to "use").

---

## 8. Interaction (for reference — implemented in the screen, not the Lua)

1. Tap an icon → description panel (name, text, cost, TAKE IT button) appears at
   the bottom, to the **right of the stash tray**.
2. Buy → upgrade goes to `ownedPermanents`; supply increments
   `pendingConsumables` and appears in the stash tray.
3. Intended future gesture: **drag the icon onto the dealer** to buy (the dealer
   is the drop target, centered behind the counter).

---

## 9. Deliverables

Generate two Lua scripts (run via `File › Scripts › Run Script`):

1. `aseprite/dealer_shop_scene.lua` → writes `dealer_shop_bg.png` (Layer 1).
   *(already exists — keep it in sync with §5.)*
2. `aseprite/dealer_shop_counter.lua` → writes `dealer_shop_counter.png` (Layer 3).

Each script: build a 320×480 sprite, paint per §4–§5, then
`spr:saveCopyAs("<file>.png")`. The dealer (Layer 2) and all item/stash icons are
separate assets and are **not** drawn by these scripts.
