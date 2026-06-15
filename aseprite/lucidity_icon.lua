-- lucidity_icon.lua
-- Generates a 24×24 pixel-art green coin icon for the Lucidity currency display.
--
-- Run via  File › Scripts › Run Script  in Aseprite.
-- Save output as  assets/images/ui/lucidity_icon.png
--
-- Design: classic coin shape, neon-green palette (matches ACC_POS #22c55e),
-- "L" letterform centred, specular gleam top-left.

local W, H = 24, 24
local spr = Sprite(W, H, ColorMode.RGB)
spr.layers[1].name = "LucidityIcon"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local CLEAR   = P.rgba(0, 0, 0, 0)
local OUTLINE = P.rgba(0x05, 0x2e, 0x16, 255)   -- very dark green ring
local DARK    = P.rgba(0x14, 0x53, 0x2d, 255)   -- bottom shadow zone
local MID     = P.rgba(0x22, 0xc5, 0x5e, 255)   -- main fill (matches game accent)
local LIGHT   = P.rgba(0x4a, 0xde, 0x80, 255)   -- top highlight zone
local BRIGHT  = P.rgba(0xd1, 0xfa, 0xe5, 255)   -- specular gleam
local LETTER  = P.rgba(0x05, 0x2e, 0x16, 255)   -- "L" stroke (very dark green)

img:clear(CLEAR)

local function px(x, y, c)
  if x>=0 and x<W and y>=0 and y<H then img:drawPixel(x, y, c) end
end
local function hline(x1, x2, y, c) for x = x1, x2 do px(x, y, c) end end
local function vline(x, y1, y2, c) for y = y1, y2 do px(x, y, c) end end

-- ── Coin circle ───────────────────────────────────────────────────────────────
-- Pixel (x,y) centre is at (x+0.5, y+0.5); coin centre is (11.5, 11.5).
-- d = sqrt((x-11)^2 + (y-11)^2)
local R_FILL = 9.8   -- fill boundary
local R_OUT  = 10.8  -- outer edge (anything beyond = transparent)

for y = 0, H-1 do
  for x = 0, W-1 do
    local dx = x - 11
    local dy = y - 11
    local d  = math.sqrt(dx*dx + dy*dy)
    if d <= R_FILL then
      -- gradient: lighter on top, darker on bottom
      if dy < -3 then
        px(x, y, LIGHT)
      elseif dy > 3 then
        px(x, y, DARK)
      else
        px(x, y, MID)
      end
    elseif d <= R_OUT then
      px(x, y, OUTLINE)
    end
    -- else: stays CLEAR (transparent)
  end
end

-- ── Specular gleam (top-left) ─────────────────────────────────────────────────
px(6, 5, BRIGHT)
px(7, 4, BRIGHT)
px(5, 6, BRIGHT)
px(7, 5, LIGHT)

-- ── "L" letterform (2-px stroke, centred in coin) ────────────────────────────
-- Vertical bar: x=8..9, y=7..15  (9 tall)
-- Horizontal bar: x=8..15, y=14..15  (2 tall, 8 wide)
vline(8,  7, 15, LETTER)
vline(9,  7, 15, LETTER)
hline(8, 15, 14, LETTER)
hline(8, 15, 15, LETTER)

spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr:saveCopyAs("lucidity_icon.png")
app.alert("Saved lucidity_icon.png — move to assets/images/ui/")
