-- power_shift.lua — 32×32 Shift power icon chip
-- Run via File › Scripts › Run Script in Aseprite
-- Output: power_shift.png  →  place in assets/images/ui/
-- Icon: two vertical arrows (↕) — shift moves a reel's symbol up or down.

local W, H = 32, 32
local s = Sprite(W, H, ColorMode.RGB)
s.filename = "power_shift.aseprite"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local T   = P.rgba(0,   0,   0,   0)
local BG  = P.rgba(8,   8,  22, 220)
local BD  = P.rgba(0,  140, 170, 255)
local ICO = P.rgba(0,  229, 255, 255)

local function px(x,y,c) img:drawPixel(x,y,c) end
local function hline(x1,x2,y,c) for x=x1,x2 do px(x,y,c) end end
local function vline(x,y1,y2,c) for y=y1,y2 do px(x,y,c) end end
local function rect(x1,y1,x2,y2,c)
  for y=y1,y2 do hline(x1,x2,y,c) end
end

rect(0, 0, W-1, H-1, T)

for y=2,H-3 do for x=2,W-3 do
  local cut = (x<=3 and y<=3) or (x>=W-4 and y<=3)
           or (x<=3 and y>=H-4) or (x>=W-4 and y>=H-4)
  if not cut then px(x,y,BG) end
end end
hline(4, W-5, 2, BD);  hline(4, W-5, H-3, BD)
vline(2, 4, H-5, BD);  vline(W-3, 4, H-5, BD)
px(3,3,BD); px(W-4,3,BD); px(3,H-4,BD); px(W-4,H-4,BD)

-- UP arrow (tip at y=7, pointing up)
-- tip
px(15,7,ICO); px(16,7,ICO)
-- arrowhead spreads down
hline(14,17,8,ICO)
hline(13,18,9,ICO)
-- shaft (2px wide, y=9 to y=14)
vline(15,9,14,ICO); vline(16,9,14,ICO)

-- DOWN arrow (tip at y=24, pointing down)
px(15,24,ICO); px(16,24,ICO)
hline(14,17,23,ICO)
hline(13,18,22,ICO)
vline(15,17,22,ICO); vline(16,17,22,ICO)

s:newCel(s.layers[1], 1, img, Point(0,0))
s:saveCopyAs("power_shift.png")
