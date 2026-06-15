-- dealer_shop_scene.lua
-- Generates the bar/casino counter BACKGROUND for the Dealer shop screen.
-- Canvas: 320×480 (matches the runtime layout exactly).
--
-- IMPORTANT: do NOT draw the dealer here. The dealer is overlaid at runtime
-- using assets/images/ui/dealer_portrait.png, centered with its base on the
-- counter top (y=358). Leave the back-bar area (x≈70–250, y≈168–356) as a
-- backdrop (shelf of bottles, dark panel, etc.) for the dealer to stand against.
--
-- Run via  File › Scripts › Run Script  in Aseprite.
-- Save output as  assets/images/dealer_shop_bg.png  then run the app
-- (the screen reads this file directly — no compose step needed).
--
-- ─────────────────────────────────────────────────────────────────────────────
-- LAYOUT (source px, must stay in sync with DealerShopScreen.tsx)
--
--   POWERS    shelf : icon centre y=12,  shelf board y=56   accent #a855f7
--   POSITIVE  shelf : icon centre y=66,  shelf board y=110  accent #22c55e
--   CORRUPTED shelf : icon centre y=120, shelf board y=164  accent #ef4444
--     each shelf: icons 44×44, x = 18,66,114,162,210,258 (NO cell frames)
--
--   BACK BAR backdrop : x=70–250, y=168–358 (dealer portrait overlaid on top)
--
--   SUPPLIES on counter : icons 52×52, y=295, x = 22,90,158,226 (cyan)
--     (rendered AFTER the counter PNG so they appear to sit on the bar surface)
--
-- The counter is a SEPARATE FILE: dealer_shop_counter.png (transparent above
-- y=358 so the dealer shows through; counter face from y=358 downward).
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
local BOARD   = P.rgba(0x3a, 0x22, 0x0e, 255)
local LIP     = P.rgba(0x52, 0x30, 0x14, 255)
local BACKBAR = P.rgba(0x16, 0x10, 0x2c, 255)
local CTR_T   = P.rgba(0x1e, 0x36, 0x44, 255)
local CTR_F   = P.rgba(0x14, 0x24, 0x30, 255)
local CTR_H   = P.rgba(0x28, 0x50, 0x64, 255)
local SLOT    = P.rgba(0x08, 0x04, 0x14, 255)
local NEON    = P.rgba(0xff, 0x2d, 0x55, 180)
local ACC_POW  = P.rgba(0xa8, 0x55, 0xf7, 255)
local ACC_POS  = P.rgba(0x22, 0xc5, 0x5e, 255)
local ACC_CORR = P.rgba(0xef, 0x44, 0x44, 255)
local ACC_CONS = P.rgba(0x00, 0xe5, 0xff, 255)
local BOTTLE   = P.rgba(0x24, 0x18, 0x40, 255)

local function px(x, y, c) if x>=0 and x<W and y>=0 and y<H then img:drawPixel(x, y, c) end end
local function hline(x1, x2, y, c) for x = x1, x2 do px(x, y, c) end end
local function vline(x, y1, y2, c) for y = y1, y2 do px(x, y, c) end end
local function rect(x1, y1, x2, y2, c) for y = y1, y2 do hline(x1, x2, y, c) end end
local function slot(x, y, w, h, a)
  rect(x, y, x+w-1, y+h-1, SLOT)
  hline(x, x+w-1, y, a);   hline(x, x+w-1, y+h-1, a)
  vline(x, y, y+h-1, a);   vline(x+w-1, y, y+h-1, a)
end

-- Wall + ceiling
rect(0, 0, W-1, H-1, WALL)
rect(0, 0, W-1, 11, CEIL)
hline(0, W-1, 12, NEON)
hline(0, W-1, 13, P.rgba(0x60, 0x10, 0x20, 255))

-- Shelves
local shelves = {
  { slotY = 28,  boardY = 56,  acc = ACC_POW },
  { slotY = 82,  boardY = 110, acc = ACC_POS },
  { slotY = 136, boardY = 164, acc = ACC_CORR },
}
for _, s in ipairs(shelves) do
  hline(0, W-1, s.boardY-1, s.acc)
  rect(0, s.boardY, W-1, s.boardY+1, BOARD)
  hline(0, W-1, s.boardY+2, LIP)
  for i = 0, 5 do slot(18 + i*48, s.slotY, 44, 24, s.acc) end
end

-- Back-bar backdrop (dealer stands here at runtime)
rect(70, 168, 250, 356, BACKBAR)
for _, bx in ipairs({90, 130, 170, 210, 230}) do vline(bx, 176, 300, BOTTLE) end
hline(72, 248, 176, P.rgba(0x2a, 0x1c, 0x48, 255))
hline(72, 248, 240, P.rgba(0x2a, 0x1c, 0x48, 255))

-- Counter
local CTOP = 358
rect(0, CTOP-4, W-1, CTOP-1, P.rgba(0x10, 0x1c, 0x26, 255))
rect(0, CTOP, W-1, CTOP+11, CTR_T)
hline(0, W-1, CTOP+11, CTR_H)
rect(0, CTOP+12, W-1, H-1, CTR_F)
hline(0, W-1, CTOP+13, ACC_CONS)
hline(0, W-1, CTOP+14, P.rgba(0x00, 0x60, 0x80, 255))

-- Supplies slots on counter top
for i = 0, 3 do slot(18 + i*72, 318, 60, 38, ACC_CONS) end

spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr:saveCopyAs("dealer_shop_bg.png")
app.alert("Saved dealer_shop_bg.png — move to assets/images/ (overwrite the placeholder).")
