-- dealer_shop_scene.lua
-- Generates the bar/casino counter BACKGROUND for the Dealer shop screen.
-- Canvas: 320×480 (matches the runtime layout exactly).
--
-- IMPORTANT: do NOT draw the dealer here. The dealer is overlaid at runtime
-- using assets/images/ui/dealer_portrait.png, centred with its base on the
-- counter top (y=358). Leave the back-bar area (x≈70–250, y≈168–356) as a
-- backdrop for the dealer to stand against.
--
-- Run via  File › Scripts › Run Script  in Aseprite.
-- Save output as  assets/images/dealer_shop_bg.png  then run the app.
-- Alternatively run:  node scripts/generate-dealer-shop-bg.js
--
-- ─────────────────────────────────────────────────────────────────────────────
-- LAYOUT (source px, must stay in sync with DealerShopScreen.tsx)
--
--   POWERS    shelf : icons y=12..55,  shelf board y=56   (depth y=56..65)
--   POSITIVE  shelf : icons y=66..109, shelf board y=110  (depth y=110..119)
--   CORRUPTED shelf : icons y=120..163, shelf board y=164 (depth y=164..173)
--     each shelf: icons 44×44, x = 18,66,114,162,210,258 (NO cell frames)
--
--   BACK BAR backdrop : x=70–250, y=168–356 (dealer portrait overlaid on top)
--
--   SUPPLIES on counter : icons 52×52, y=306, x = 22,90,158,226 (cyan)
--
-- The counter is a SEPARATE FILE: dealer_shop_counter.png.
-- Do NOT draw the counter in this file.
-- ─────────────────────────────────────────────────────────────────────────────

local W, H = 320, 480
local spr = Sprite(W, H, ColorMode.RGB)
spr.layers[1].name = "BG"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

-- Palette
local WALL    = P.rgba(0x0e, 0x08, 0x1c, 255)
local CEIL    = P.rgba(0x14, 0x0a, 0x24, 255)
local BOARD   = P.rgba(0x3a, 0x22, 0x0e, 255)   -- shelf top surface
local BOARD_D = P.rgba(0x1e, 0x10, 0x06, 255)   -- shelf front face (depth)
local LIP     = P.rgba(0x52, 0x30, 0x14, 255)   -- lit top edge of shelf
local BACKBAR = P.rgba(0x16, 0x10, 0x2c, 255)
local NEON    = P.rgba(0xff, 0x2d, 0x55, 255)
local BOTTLE  = P.rgba(0x24, 0x18, 0x40, 255)
local SHADOW  = P.rgba(0x06, 0x04, 0x10, 255)

local function px(x, y, c) if x>=0 and x<W and y>=0 and y<H then img:drawPixel(x, y, c) end end
local function hline(x1, x2, y, c) for x = x1, x2 do px(x, y, c) end end
local function vline(x, y1, y2, c) for y = y1, y2 do px(x, y, c) end end
local function rect(x1, y1, x2, y2, c) for y = y1, y2 do hline(x1, x2, y, c) end end

-- Wall + ceiling
rect(0, 0, W-1, H-1, WALL)
rect(0, 0, W-1, 11, CEIL)
hline(0, W-1, 12, NEON)
hline(0, W-1, 13, P.rgba(0x60, 0x10, 0x20, 255))

-- Shelves with front-face depth.
-- Each entry: boardY = top of the shelf surface, rgb = accent colour components.
-- Structure per shelf (all pixels below icon area which ends at boardY-1):
--   boardY-1 : accent neon line (visible in gaps between icons)
--   boardY   : LIP highlight (top edge of surface)
--   boardY+1..2: BOARD (shelf top, icons rest here)
--   boardY+3 : dim accent (colour stripe on top of front face)
--   boardY+4..8: BOARD_D (front face, gives 3-D depth illusion)
--   boardY+9 : shadow stripe below shelf
local shelves = {
  { boardY = 56,  ar=0xa8, ag=0x55, ab=0xf7 },  -- POWERS (purple)
  { boardY = 110, ar=0x22, ag=0xc5, ab=0x5e },  -- POSITIVE (green)
  { boardY = 164, ar=0xef, ag=0x44, ab=0x44 },  -- CORRUPTED (red)
}
for _, s in ipairs(shelves) do
  local b   = s.boardY
  local acc = P.rgba(s.ar, s.ag, s.ab, 255)
  local accDim = P.rgba(
    math.floor(s.ar * 0.6),
    math.floor(s.ag * 0.6),
    math.floor(s.ab * 0.6), 255)
  hline(0, W-1, b-1, acc)          -- accent glow above shelf
  hline(0, W-1, b,   LIP)          -- top-edge highlight
  hline(0, W-1, b+1, BOARD)        -- shelf surface
  hline(0, W-1, b+2, BOARD)
  hline(0, W-1, b+3, accDim)       -- coloured edge (top of front face)
  rect(0, b+4, W-1, b+8, BOARD_D)  -- front face (depth)
  hline(0, W-1, b+9, SHADOW)       -- shadow under shelf
end

-- Back-bar backdrop (dealer stands here at runtime)
rect(70, 168, 250, 356, BACKBAR)
for _, bx in ipairs({90, 130, 170, 210, 230}) do vline(bx, 176, 300, BOTTLE) end
hline(72, 248, 176, P.rgba(0x2a, 0x1c, 0x48, 255))
hline(72, 248, 240, P.rgba(0x2a, 0x1c, 0x48, 255))

spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr:saveCopyAs("dealer_shop_bg.png")
app.alert("Saved dealer_shop_bg.png — move to assets/images/ (overwrite the placeholder).")
