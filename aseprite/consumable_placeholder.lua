-- consumable_placeholder.lua — 24×24 generic consumable icon (vial)
-- Run via File › Scripts › Run Script in Aseprite
-- Output: consumable_placeholder.png  →  place in assets/images/ui/
--
-- Used for ALL consumables until each gets its own icon.
-- Fits exactly inside the 24×24 stash tray slot.

local W, H = 24, 24
local s = Sprite(W, H, ColorMode.RGB)
s.filename = "consumable_placeholder.aseprite"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local T    = P.rgba(0,   0,   0,   0)
local NECK = P.rgba(180, 170, 200, 255)  -- vial neck/stopper (light)
local BODY = P.rgba(90,  50, 160, 200)  -- vial glass body (purple, semi)
local LIQ  = P.rgba(168, 85, 247, 255)  -- liquid inside (bright purple)
local HI   = P.rgba(220, 210, 255, 180) -- glass highlight
local BDG  = P.rgba(120,  80, 200, 255) -- body outline

local function px(x,y,c) img:drawPixel(x,y,c) end
local function hline(x1,x2,y,c) for x=x1,x2 do px(x,y,c) end end
local function vline(x,y1,y2,c) for y=y1,y2 do px(x,y,c) end end
local function rect(x1,y1,x2,y2,c)
  for y=y1,y2 do hline(x1,x2,y,c) end
end

-- transparent background
rect(0, 0, W-1, H-1, T)

-- Stopper cap (top of vial): x=9..14, y=2..4
rect(9, 2, 14, 4, NECK)

-- Neck (narrow): x=10..13, y=5..6
rect(10, 5, 13, 6, BDG)

-- Body outline (rounded bottom vial):
-- outer shell x=7..16, y=7..21
rect(7, 7, 16, 21, BDG)
-- round bottom corners
px(7,21,T); px(16,21,T)
px(7,20,T); px(16,20,T)
px(8,21,T); px(15,21,T)
-- inner fill
rect(8, 7, 15, 20, BODY)

-- Liquid level (fills bottom half of body): y=13..20
rect(8, 13, 15, 19, LIQ)
-- liquid surface line
hline(8, 15, 13, HI)

-- Glass highlight (left edge inside)
vline(9, 8, 12, HI)
px(10, 8, HI)

-- Bubbles in liquid (2 small dots)
px(10, 16, HI)
px(13, 15, HI)

s:newCel(s.layers[1], 1, img, Point(0,0))
s:saveCopyAs("consumable_placeholder.png")
