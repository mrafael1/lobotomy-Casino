-- power_memory.lua — 32×32 Memory power icon chip
-- Run via File › Scripts › Run Script in Aseprite
-- Output: power_memory.png  →  place in assets/images/ui/
-- Icon: padlock — Memory locks a reel's symbol for the next spin.

local W, H = 32, 32
local s = Sprite(W, H, ColorMode.RGB)
s.filename = "power_memory.aseprite"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local T   = P.rgba(0,   0,   0,   0)
local BG  = P.rgba(8,   8,  22, 220)
local BD  = P.rgba(0,  140, 170, 255)
local ICO = P.rgba(0,  229, 255, 255)   -- lock body / shackle
local KH  = P.rgba(255, 45, 120, 255)   -- keyhole: neon pink accent

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

-- Shackle (U-arch above the body)
-- outer U: x=11..20, top at y=9
hline(12, 19, 9, ICO)      -- top bar
vline(11, 9, 16, ICO)      -- left side
vline(20, 9, 16, ICO)      -- right side
-- inner hollow (U interior)
hline(13, 18, 10, BG)
vline(12, 10, 16, BG)
vline(19, 10, 16, BG)

-- Lock body (solid rectangle)
rect(8, 16, 23, 26, ICO)
-- body border slightly lighter top (inset look)
-- keyhole: circle + slot cut-out in pink
px(15,19,KH); px(16,19,KH)
px(14,20,KH); px(15,20,KH); px(16,20,KH); px(17,20,KH)
px(15,21,KH); px(16,21,KH)
-- keyhole slot going down
px(15,22,KH); px(16,22,KH)
px(15,23,KH); px(16,23,KH)

s:newCel(s.layers[1], 1, img, Point(0,0))
s:saveCopyAs("power_memory.png")
