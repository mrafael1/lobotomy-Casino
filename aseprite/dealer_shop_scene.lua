-- dealer_shop_scene.lua
-- Generates the bar/casino counter background for the Dealer shop screen.
-- Canvas: 320×480 source → 2× upscale → 640×960 runtime PNG.
--
-- Run via  File › Scripts › Run Script  in Aseprite.
-- Save output as  assets/images/dealer_shop_bg.png
-- then run  npm run assets:compose  (or manually copy).
--
-- ─────────────────────────────────────────────────────────────────────────────
-- SCENE LAYOUT (all coords in source pixels, 0-indexed)
--
--  y=0   ┌──────────────────────────────────────────┐  ceiling / top trim
--  y=16  │         ─── POWERS shelf ───              │  shelf label row
--  y=28  │  [slot][slot][slot][slot][slot][slot]      │  item area
--  y=50  │════════════════════════════════════════════│  shelf board (2px)
--  y=52  │                                            │
--  y=72  │         ─── POSITIVE shelf ───             │
--  y=84  │  [slot][slot][slot][slot][slot][slot]      │
--  y=106 │════════════════════════════════════════════│  shelf board
--  y=108 │                                            │
--  y=128 │         ─── CORRUPTED shelf ───            │
--  y=140 │  [slot][slot][slot][slot][slot][slot]      │
--  y=162 │════════════════════════════════════════════│  shelf board
--  y=164 │    wall above counter          [DEALER]    │
--  y=216 │════════════════════════════════════════════│  counter back panel
--  y=228 │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  counter TOP surface
--  y=236 │[cons][cons][cons][cons]                    │  consumables ON counter
--  y=252 │▓▓▓▓▓▓ counter front face ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
--  y=300 │                                            │
--  y=480 └──────────────────────────────────────────┘  player floor
--
-- SLOT POSITIONS (source px, used by DealerShopScreen.tsx for tap targets):
--   6-slot shelves: x = 8, 56, 104, 152, 200, 248   w=44, h=44
--   4-slot counter: x = 8, 56, 104, 152              w=44, h=44   y=176
-- ─────────────────────────────────────────────────────────────────────────────

local W, H = 320, 480
local spr = Sprite(W, H, ColorMode.RGB)
spr.layers[1].name = "BG"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

-- ── Palette ─────────────────────────────────────────────────────────────────
local BG_WALL    = P.rgba(0x0e, 0x08, 0x1c, 255)  -- deep purple-black wall
local BG_CEIL    = P.rgba(0x14, 0x0a, 0x24, 255)  -- ceiling slightly lighter
local SHELF_WOOD = P.rgba(0x3a, 0x22, 0x0e, 255)  -- dark wood shelf board
local SHELF_LIP  = P.rgba(0x52, 0x30, 0x14, 255)  -- wood front lip highlight
local COUNTER_T  = P.rgba(0x1e, 0x36, 0x44, 255)  -- counter top (dark teal)
local COUNTER_F  = P.rgba(0x14, 0x24, 0x30, 255)  -- counter face
local COUNTER_H  = P.rgba(0x28, 0x50, 0x64, 255)  -- counter top highlight strip
local SLOT_BG    = P.rgba(0x08, 0x04, 0x14, 255)  -- slot depression (very dark)
local SLOT_RIM   = P.rgba(0x2a, 0x18, 0x40, 255)  -- slot border
local NEON_H     = P.rgba(0xff, 0x2d, 0x55, 180)  -- neon pink ambient
local DEALER_SH  = P.rgba(0x1a, 0x10, 0x30, 255)  -- dealer silhouette dark
local DEALER_HL  = P.rgba(0x30, 0x1a, 0x50, 255)  -- dealer highlight edge
-- shelf accent rim colours
local ACC_POWER  = P.rgba(0xa8, 0x55, 0xf7, 255)  -- purple
local ACC_POS    = P.rgba(0x22, 0xc5, 0x5e, 255)  -- green
local ACC_CORR   = P.rgba(0xef, 0x44, 0x44, 255)  -- red
local ACC_CONS   = P.rgba(0x00, 0xe5, 0xff, 255)  -- cyan

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function px(x, y, c) img:drawPixel(x, y, c) end
local function hline(x1, x2, y, c) for x = x1, x2 do px(x, y, c) end end
local function vline(x, y1, y2, c) for y = y1, y2 do px(x, y, c) end end
local function rect(x1, y1, x2, y2, c)
  for y = y1, y2 do hline(x1, x2, y, c) end
end

-- draw a pixelated text label (5×5 uppercase pixel font, scale 1)
-- letters baked as bitmaps below — extend as needed
local FONT = {
  P = {{1,1,1,0},{1,0,0,1},{1,1,1,0},{1,0,0,0},{1,0,0,0}},
  O = {{0,1,1,0},{1,0,0,1},{1,0,0,1},{1,0,0,1},{0,1,1,0}},
  W = {{1,0,1,0,1},{1,0,1,0,1},{1,1,1,1,1},{0,1,0,1,0},{0,1,0,1,0}},
  E = {{1,1,1,1},{1,0,0,0},{1,1,1,0},{1,0,0,0},{1,1,1,1}},
  R = {{1,1,1,0},{1,0,0,1},{1,1,1,0},{1,0,1,0},{1,0,0,1}},
  S = {{0,1,1,1},{1,0,0,0},{0,1,1,0},{0,0,0,1},{1,1,1,0}},
  I = {{1,1,1},{0,1,0},{0,1,0},{0,1,0},{1,1,1}},
  T = {{1,1,1,1,1},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0}},
  V = {{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0}},
  A = {{0,1,1,0},{1,0,0,1},{1,1,1,1},{1,0,0,1},{1,0,0,1}},
  G = {{0,1,1,1},{1,0,0,0},{1,0,1,1},{1,0,0,1},{0,1,1,1}},
  N = {{1,0,0,1},{1,1,0,1},{1,0,1,1},{1,0,0,1},{1,0,0,1}},
  C = {{0,1,1,1},{1,0,0,0},{1,0,0,0},{1,0,0,0},{0,1,1,1}},
  U = {{1,0,1},{1,0,1},{1,0,1},{1,0,1},{0,1,0}},
  D = {{1,1,1,0},{1,0,0,1},{1,0,0,1},{1,0,0,1},{1,1,1,0}},
  L = {{1,0,0},{1,0,0},{1,0,0},{1,0,0},{1,1,1}},
  Y = {{1,0,1},{1,0,1},{0,1,0},{0,1,0},{0,1,0}},
  [" "] = {{0,0}},
}
local function drawWord(word, ox, oy, color)
  local x = ox
  for i = 1, #word do
    local ch = word:sub(i,i)
    local g = FONT[ch]
    if g then
      for row, cols in ipairs(g) do
        for col, on in ipairs(cols) do
          if on == 1 then px(x+col-1, oy+row-1, color) end
        end
      end
      x = x + #g[1] + 1
    end
  end
end

-- Draw a single item slot depression (icon placeholder)
local function drawSlot(x, y, w, h, accent)
  rect(x, y, x+w-1, y+h-1, SLOT_BG)
  -- inner rim (1px)
  hline(x,   x+w-1, y,     SLOT_RIM)
  hline(x,   x+w-1, y+h-1, SLOT_RIM)
  vline(x,   y,     y+h-1, SLOT_RIM)
  vline(x+w-1, y,   y+h-1, SLOT_RIM)
  -- accent corner marks (2px)
  hline(x, x+3, y,     accent)
  hline(x, x+3, y+h-1, accent)
  vline(x, y, y+3, accent)
  vline(x, y+h-4, y+h-1, accent)
  hline(x+w-4, x+w-1, y,     accent)
  hline(x+w-4, x+w-1, y+h-1, accent)
  vline(x+w-1, y, y+3, accent)
  vline(x+w-1, y+h-4, y+h-1, accent)
end

-- Draw a shelf board (2px tall) with lip shadow
local function drawShelfBoard(y, accent)
  rect(0, y, W-1, y+1, SHELF_WOOD)
  hline(0, W-1, y+2, SHELF_LIP)    -- lit top
  -- subtle accent neon under-glow line
  for x = 0, W-1 do
    local a = 60 + math.floor(40 * math.sin(x * 0.05))
    -- skip — just colour the bottom 1px of the shelf
  end
  hline(0, W-1, y-1, P.rgba(
    math.floor((acc_r or 0x3a) * 0.4),
    math.floor((acc_g or 0x1e) * 0.4),
    math.floor((acc_b or 0x52) * 0.4),
    255))
end

-- ── PAINT ────────────────────────────────────────────────────────────────────

-- Full background: wall
rect(0, 0, W-1, H-1, BG_WALL)
-- Ceiling strip
rect(0, 0, W-1, 12, BG_CEIL)
-- Top neon trim line
hline(0, W-1, 12, NEON_H)
hline(0, W-1, 13, P.rgba(0x60, 0x10, 0x20, 180))

-- ── SHELF 1: POWERS (y_slots=28..51, board=52..53) ──────────────────────────
local SH1_Y  = 28   -- top of item slots
local SH1_BRD = 52  -- shelf board top
rect(0, SH1_BRD, W-1, SH1_BRD+2, SHELF_WOOD)
hline(0, W-1, SH1_BRD+3, SHELF_LIP)
-- Accent rail above board
hline(0, W-1, SH1_BRD-1, ACC_POWER)
-- Label
drawWord("POWERS", 4, 17, ACC_POWER)
-- Slots: 6 × 44×22 with 4px gap  => total=6*44+5*4=284, margin=(320-284)/2=18
for i = 0, 5 do
  drawSlot(18 + i*48, SH1_Y, 44, 22, ACC_POWER)
end

-- ── SHELF 2: POSITIVE (y_slots=84..107, board=108..109) ──────────────────────
local SH2_Y   = 68
local SH2_BRD = 92
rect(0, SH2_BRD, W-1, SH2_BRD+2, SHELF_WOOD)
hline(0, W-1, SH2_BRD+3, SHELF_LIP)
hline(0, W-1, SH2_BRD-1, ACC_POS)
drawWord("POSITIVE", 4, 57, ACC_POS)
for i = 0, 5 do
  drawSlot(18 + i*48, SH2_Y, 44, 22, ACC_POS)
end

-- ── SHELF 3: CORRUPTED (y_slots=140..163, board=164..165) ────────────────────
local SH3_Y   = 108
local SH3_BRD = 132
rect(0, SH3_BRD, W-1, SH3_BRD+2, SHELF_WOOD)
hline(0, W-1, SH3_BRD+3, SHELF_LIP)
hline(0, W-1, SH3_BRD-1, ACC_CORR)
drawWord("CORRUPTED", 4, 97, ACC_CORR)
for i = 0, 5 do
  drawSlot(18 + i*48, SH3_Y, 44, 22, ACC_CORR)
end

-- ── DEALER SILHOUETTE (behind counter, y=135..215, x=118..200) ───────────────
local DX, DY, DW, DH = 118, 136, 84, 80
-- Body block
rect(DX+12, DY+20, DX+DW-13, DY+DH-1, DEALER_SH)
-- Head circle (approx)
rect(DX+26, DY, DX+58, DY+22, DEALER_SH)
-- Edge highlight (gives silhouette some depth)
vline(DX+12, DY+20, DY+DH-1, DEALER_HL)
vline(DX+DW-13, DY+20, DY+DH-1, DEALER_HL)
hline(DX+26, DX+58, DY, DEALER_HL)

-- ── COUNTER ──────────────────────────────────────────────────────────────────
local CTR_TOP  = 216  -- counter surface top
local CTR_FACE = 236  -- face starts here
-- Back panel strip (dark, above counter surface)
rect(0, CTR_TOP-4, W-1, CTR_TOP-1, P.rgba(0x10, 0x1c, 0x26, 255))
-- Counter top surface
rect(0, CTR_TOP, W-1, CTR_FACE-1, COUNTER_T)
-- Highlight strip on near edge
hline(0, W-1, CTR_FACE-1, COUNTER_H)
-- Counter face
rect(0, CTR_FACE, W-1, CTR_FACE+63, COUNTER_F)
-- Neon strip on counter front
hline(0, W-1, CTR_FACE+1, ACC_CONS)
hline(0, W-1, CTR_FACE+2, P.rgba(0x00, 0x60, 0x80, 200))

-- Consumable label above counter
drawWord("SUPPLIES", 4, CTR_TOP-14, ACC_CONS)

-- Consumable slots ON counter (4 slots)
local CONS_Y = CTR_TOP - 32
for i = 0, 3 do
  drawSlot(18 + i*72, CONS_Y, 60, 26, ACC_CONS)
end

-- ── FLOOR ────────────────────────────────────────────────────────────────────
rect(0, CTR_FACE+64, W-1, H-1, P.rgba(0x08, 0x04, 0x10, 255))
-- Floor neon reflection strips
for i = 0, 2 do
  hline(0, W-1, CTR_FACE+70+i*8, P.rgba(0x20, 0x08, 0x30, 120))
end

-- ── FINISH ───────────────────────────────────────────────────────────────────
spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr:saveCopyAs("dealer_shop_bg.png")
app.alert("Saved dealer_shop_bg.png\nMove to: assets/images/\nThen: npm run assets:compose (or add to composeUI list)")

--[[
SLOT POSITIONS FOR DealerShopScreen.tsx  (source 320×480, 2× upscale → 640×960)
Divide these by 320 (width) or 480 (height) for fractional coords in React Native.

POWERS shelf (ACC_POWER = purple #a855f7):
  6 slots at y=28, height=22
  x = 18, 66, 114, 162, 210, 258   (w=44 each)

POSITIVE shelf (ACC_POS = green #22c55e):
  6 slots at y=68, height=22
  x = 18, 66, 114, 162, 210, 258

CORRUPTED shelf (ACC_CORR = red #ef4444):
  6 slots at y=108, height=22
  x = 18, 66, 114, 162, 210, 258

SUPPLIES on counter (ACC_CONS = cyan #00e5ff):
  4 slots at y=184, height=26
  x = 18, 90, 162, 234   (w=60 each)

DEALER drag target (to confirm purchase):
  x=118, y=136, w=84, h=80
]]
