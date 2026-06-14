-- multiplier_buttons.lua
-- Generates Multiplier_Top_X1.png, X2.png, X3.png — the three bet-multiplier
-- overlay frames for the slot machine's top glass panel.
--
-- Run via  File › Scripts › Run Script  in Aseprite.
-- Output files are saved next to this script; move them to:
--   assets/images/machine_slot_layers/
-- then run  npm run assets:compose  to rebuild runtime PNGs.
--
-- === Tune these to match your source art (200×300 canvas) ===
local CANVAS_W   = 200
local CANVAS_H   = 300
-- Inner bounds of the top glass panel (0-indexed source pixels)
local GLASS_X    = 31    -- left edge of inner glass
local GLASS_Y    = 45    -- top edge of inner glass
local GLASS_W    = 139   -- glass inner width  (x=31 to x=170 = 139 px)
local GLASS_H    = 24    -- glass inner height (y=45 to y=68  = 24 px)
local BTN_GAP    = 2     -- pixels between buttons (border-to-border)
-- ============================================================

local P   = app.pixelColor
local T   = P.rgba(0, 0, 0, 0)   -- transparent

-- Active border colours per multiplier
local ACTIVE = {
  P.rgba(0xff, 0x2d, 0x55, 255),  -- x1 : neon pink
  P.rgba(0x00, 0xe5, 0xff, 255),  -- x2 : cyan
  P.rgba(0xff, 0xcc, 0x00, 255),  -- x3 : gold
}
local BORDER_DIM = P.rgba(0x3a, 0x1e, 0x52, 255)  -- inactive border

-- Body fills (semi-transparent so neon bar shows through lightly)
local BODY_ACTIVE   = P.rgba(0x18, 0x08, 0x2a, 220)
local BODY_INACTIVE = P.rgba(0x0e, 0x08, 0x1a, 130)

-- Pixel-font glyphs (5 rows tall, variable width)
local GLYPH_X = {
  {1,0,0,0,1},
  {0,1,0,1,0},
  {0,0,1,0,0},
  {0,1,0,1,0},
  {1,0,0,0,1},
}
local GLYPH_NUM = {
  -- 1 (3 wide)
  {{0,1,0},{1,1,0},{0,1,0},{0,1,0},{1,1,1}},
  -- 2 (3 wide)
  {{1,1,0},{0,0,1},{0,1,0},{1,0,0},{1,1,1}},
  -- 3 (3 wide)
  {{1,1,0},{0,0,1},{0,1,0},{0,0,1},{1,1,0}},
}

-- helpers --------------------------------------------------------
local function px(img, x, y, c) img:drawPixel(x, y, c) end

local function fillRect(img, x, y, w, h, c)
  for dy = 0, h-1 do
    for dx = 0, w-1 do
      px(img, x+dx, y+dy, c)
    end
  end
end

local function drawBorder(img, x, y, w, h, c, thickness)
  thickness = thickness or 1
  for t = 0, thickness-1 do
    for dx = 0, w-1 do
      px(img, x+dx, y+t,       c)
      px(img, x+dx, y+h-1-t,   c)
    end
    for dy = t, h-1-t do
      px(img, x+t,     y+dy, c)
      px(img, x+w-1-t, y+dy, c)
    end
  end
end

local function drawGlyph(img, glyph, ox, oy, c)
  for row, cols in ipairs(glyph) do
    for col, on in ipairs(cols) do
      if on == 1 then px(img, ox+col-1, oy+row-1, c) end
    end
  end
end
-- ----------------------------------------------------------------

-- Compute button width so all three fill GLASS_W exactly
local btnW = math.floor((GLASS_W - BTN_GAP * 2) / 3)
-- Distribute any leftover pixel to a wider right button
local btnW3 = GLASS_W - BTN_GAP * 2 - btnW * 2

local function btnLeft(idx)  -- 0-indexed idx
  return GLASS_X + idx * (btnW + BTN_GAP)
end

-- Generate one overlay file per active multiplier
for activeM = 1, 3 do
  local spr = Sprite(CANVAS_W, CANVAS_H, ColorMode.RGB)
  spr.layers[1].name = "Multiplier_X" .. activeM
  local img = Image(CANVAS_W, CANVAS_H, ColorMode.RGB)
  img:clear(T)

  for btnIdx = 0, 2 do
    local m      = btnIdx + 1
    local bx     = btnLeft(btnIdx)
    local by     = GLASS_Y
    local bw     = (btnIdx == 2) and btnW3 or btnW
    local bh     = GLASS_H
    local isAct  = (m == activeM)

    -- Body
    fillRect(img, bx+2, by+2, bw-4, bh-4,
      isAct and BODY_ACTIVE or BODY_INACTIVE)

    -- Border (2px active, 1px inactive)
    drawBorder(img, bx, by, bw, bh,
      isAct and ACTIVE[m] or BORDER_DIM,
      isAct and 2 or 1)

    -- Label  "x1" / "x2" / "x3"
    local gX  = GLYPH_X
    local gN  = GLYPH_NUM[m]
    local lw  = #gX[1] + 1 + #gN[1]   -- glyph widths + 1px space
    local lh  = #gX                    -- 5 rows
    local lx  = bx + math.floor((bw - lw) / 2)
    local ly  = by + math.floor((bh - lh) / 2)

    local textC = isAct and ACTIVE[m]
                         or P.rgba(0x88, 0x66, 0xaa, 255)
    drawGlyph(img, gX, lx, ly, textC)
    drawGlyph(img, gN, lx + #gX[1] + 1, ly, textC)
  end

  spr:newCel(spr.layers[1], 1, img, Point(0, 0))
  local outName = "Multiplier_Top_X" .. activeM .. ".png"
  spr:saveCopyAs(outName)
  spr:close()
end

app.alert("Saved Multiplier_Top_X1/X2/X3.png — move to assets/images/machine_slot_layers/ then run: npm run assets:compose")
