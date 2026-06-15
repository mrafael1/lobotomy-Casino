-- dealer_shop_counter.lua
-- Generates LAYER 3 of the dealer shop: the counter that renders IN FRONT of
-- the dealer to hide his lower body. Canvas 320×480, transparent above the bar.
--
-- Run via  File › Scripts › Run Script  in Aseprite.
-- Save output as  assets/images/dealer_shop_counter.png
--
-- See aseprite/dealer_shop_prompt.md for the full scene brief.
-- Must stay in sync with DealerShopScreen.tsx (counter top at y=358).

local W, H = 320, 480
local spr = Sprite(W, H, ColorMode.RGB)
spr.layers[1].name = "Counter"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local CLEAR = P.rgba(0, 0, 0, 0)
local SHADOW = P.rgba(0x10, 0x1c, 0x26, 200)  -- soft stripe under the icons
local CTR_T  = P.rgba(0x1e, 0x36, 0x44, 255)
local CTR_F  = P.rgba(0x14, 0x24, 0x30, 255)
local CTR_H  = P.rgba(0x28, 0x50, 0x64, 255)
local NEON   = P.rgba(0x00, 0xe5, 0xff, 255)
local NEON_D = P.rgba(0x00, 0x60, 0x80, 255)

local function hline(x1, x2, y, c) for x = x1, x2 do img:drawPixel(x, y, c) end end
local function rect(x1, y1, x2, y2, c) for y = y1, y2 do hline(x1, x2, y, c) end end

-- Transparent canvas
img:clear(CLEAR)

local CTOP = 358
-- Soft shadow stripe just above the bar so overlaid icons read against it
rect(0, CTOP-6, W-1, CTOP-1, SHADOW)
-- Counter top surface
rect(0, CTOP, W-1, CTOP+11, CTR_T)
-- Front-edge highlight
hline(0, W-1, CTOP+11, CTR_H)
-- Front face
rect(0, CTOP+12, W-1, H-1, CTR_F)
-- Neon strip
hline(0, W-1, CTOP+13, NEON)
hline(0, W-1, CTOP+14, NEON_D)

spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr:saveCopyAs("dealer_shop_counter.png")
app.alert("Saved dealer_shop_counter.png — move to assets/images/ (Layer 3, renders in front of the dealer).")
