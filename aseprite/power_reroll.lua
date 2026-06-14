-- power_reroll.lua — 32×32 Reroll power icon chip
-- Run via File › Scripts › Run Script in Aseprite
-- Output: power_reroll.png  →  place in assets/images/ui/

local W, H = 32, 32
local s = Sprite(W, H, ColorMode.RGB)
s.filename = "power_reroll.aseprite"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local T   = P.rgba(0,   0,   0,   0)    -- transparent
local BG  = P.rgba(8,   8,  22, 220)    -- chip body
local BD  = P.rgba(0,  140, 170, 255)   -- chip border (dark cyan)
local DIE = P.rgba(0,  229, 255, 255)   -- die body (bright cyan)

-- helpers
local function px(x,y,c) img:drawPixel(x,y,c) end
local function hline(x1,x2,y,c) for x=x1,x2 do px(x,y,c) end end
local function vline(x,y1,y2,c) for y=y1,y2 do px(x,y,c) end end
local function rect(x1,y1,x2,y2,c)
  for y=y1,y2 do hline(x1,x2,y,c) end
end

-- transparent background
rect(0, 0, W-1, H-1, T)

-- chip body (2px margin, 2px corner cuts)
for y=2,H-3 do for x=2,W-3 do
  local cut = (x<=3 and y<=3) or (x>=W-4 and y<=3)
           or (x<=3 and y>=H-4) or (x>=W-4 and y>=H-4)
  if not cut then px(x,y,BG) end
end end
-- chip border
hline(4, W-5, 2, BD);  hline(4, W-5, H-3, BD)
vline(2, 4, H-5, BD);  vline(W-3, 4, H-5, BD)
px(3,3,BD); px(W-4,3,BD); px(3,H-4,BD); px(W-4,H-4,BD)

-- Die face (classic 6-sided die, face 3: three dots diagonal)
-- Body: solid cyan rectangle with 1px corner cuts
rect(7, 7, 24, 24, DIE)
px(7,7,BG); px(24,7,BG); px(7,24,BG); px(24,24,BG)  -- round corners

-- Three dots (dark cut-outs in the die body): top-left, center, bottom-right
rect(10, 10, 11, 11, BG)  -- top-left dot
rect(15, 15, 16, 16, BG)  -- center dot
rect(20, 20, 21, 21, BG)  -- bottom-right dot

s:newCel(s.layers[1], 1, img, Point(0,0))
s:saveCopyAs("power_reroll.png")
