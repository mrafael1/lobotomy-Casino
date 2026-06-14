-- stash_tray.lua — 66×34 consumable stash tray with 2 empty slots
-- Run via File › Scripts › Run Script in Aseprite
-- Output: stash_tray.png  →  place in assets/images/ui/
--
-- Layout (source px):
--   Outer tray: full canvas with border
--   Slot 1: x=4..27, y=5..28  (24×24, receives consumable icon overlay in app)
--   Slot 2: x=38..61, y=5..28 (24×24, same)
--   Gap between slots: x=28..37 (10px)
-- The compose pipeline 2×-upscales this to 132×68 at runtime.

local W, H = 66, 34
local s = Sprite(W, H, ColorMode.RGB)
s.filename = "stash_tray.aseprite"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local T    = P.rgba(0,   0,   0,   0)    -- transparent
local TRAY = P.rgba(12,  10,  28, 255)   -- tray surface (dark purple)
local BDO  = P.rgba(100, 60, 180, 255)   -- outer border (purple)
local BDI  = P.rgba(30,  20,  60, 255)   -- slot depression (darker)
local SLB  = P.rgba(60,  40, 100, 180)   -- slot border (muted)
local HI   = P.rgba(160,120, 255, 120)   -- highlight (top-left edges of tray)

local function px(x,y,c) img:drawPixel(x,y,c) end
local function hline(x1,x2,y,c) for x=x1,x2 do px(x,y,c) end end
local function vline(x,y1,y2,c) for y=y1,y2 do px(x,y,c) end end
local function rect(x1,y1,x2,y2,c)
  for y=y1,y2 do hline(x1,x2,y,c) end
end
local function border(x1,y1,x2,y2,c)
  hline(x1,x2,y1,c); hline(x1,x2,y2,c)
  vline(x1,y1+1,y2-1,c); vline(x2,y1+1,y2-1,c)
end

-- Tray body (fill whole canvas)
rect(0, 0, W-1, H-1, TRAY)

-- Outer border
border(0, 0, W-1, H-1, BDO)
-- top-left highlight (gives slight bevel feel)
hline(1, W-2, 1, HI)
vline(1, 1, H-2, HI)

-- Slot 1 depression: x=4..27, y=5..28
rect(4, 5, 27, 28, BDI)
border(4, 5, 27, 28, SLB)

-- Slot 2 depression: x=38..61, y=5..28
rect(38, 5, 61, 28, BDI)
border(38, 5, 61, 28, SLB)

-- Small "STASH" label pixels between slots (optional decorative dash lines)
-- Three tiny dashes at the gap center, y=16
hline(30, 34, 16, SLB)

s:newCel(s.layers[1], 1, img, Point(0,0))
s:saveCopyAs("stash_tray.png")
