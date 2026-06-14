-- dealer_hands.lua — 128×64 dealer's two open hands (offer pose)
-- Run via File › Scripts › Run Script in Aseprite
-- Output: dealer_hands.png  →  place in assets/images/ui/
--
-- Used in the mid-game dealer offer modal: two hands rising from the bottom
-- of the screen, each holding (or presenting) one of the 2 offer items.
-- The app composites the item icon in the center of each hand region.
--
-- Layout (source px, 128×64 total):
--   Left hand:  x=2..60,  y=4..63
--   Gap/body:   x=61..66
--   Right hand: x=67..125, y=4..63
--
-- Each hand:
--   Palm region (where item icon sits): x=14..44 / x=83..113, y=20..52
--   Fingers point upward from top of palm.
--   Wrist/cuff enters from bottom edge.
--
-- Suggested palette:
--   Skin:    #d4a574
--   Shadow:  #a0724a
--   Outline: #3a1a08
--   Shirt:   #e8e8f0 (cuff)
--   Vest:    #2a0a4a (sleeve edge)

local W, H = 128, 64
local s = Sprite(W, H, ColorMode.RGB)
s.filename = "dealer_hands.aseprite"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local T     = P.rgba(0,   0,   0,   0)
local SKIN  = P.rgba(212, 165, 116, 255)
local SHAD  = P.rgba(160, 114,  74, 255)
local OUT   = P.rgba( 58,  26,   8, 255)
local CUFF  = P.rgba(232, 232, 240, 255)

local function px(x,y,c) img:drawPixel(x,y,c) end
local function hline(x1,x2,y,c) for x=x1,x2 do px(x,y,c) end end
local function rect(x1,y1,x2,y2,c)
  for y=y1,y2 do hline(x1,x2,y,c) end
end

rect(0, 0, W-1, H-1, T)

-- ── ROUGH PLACEHOLDER BLOCKS ── (refine in Aseprite)

-- LEFT HAND: palm faces up, fingers pointing up-ish
-- Cuff / wrist (bottom of left hand)
rect(8, 54, 52, 63, CUFF)
-- Palm (skin)
rect(8, 24, 52, 54, SKIN)
-- Palm shadow on right side
rect(44, 24, 52, 54, SHAD)
-- Finger stubs (5 upward rectangles from top of palm)
-- Pinky (leftmost)
rect(10, 5, 16, 24, SKIN)
-- Ring
rect(18, 4, 24, 24, SKIN)
-- Middle
rect(26, 3, 32, 24, SKIN)
-- Index
rect(34, 4, 40, 24, SKIN)
-- Thumb (slightly to the right side at an angle)
rect(44, 16, 50, 32, SKIN)

-- RIGHT HAND: mirror of left hand
-- Cuff / wrist
rect(76, 54, 120, 63, CUFF)
-- Palm
rect(76, 24, 120, 54, SKIN)
-- Palm shadow (left side this time)
rect(76, 24, 84, 54, SHAD)
-- Fingers (mirrored)
-- Pinky (rightmost)
rect(112, 5, 118, 24, SKIN)
-- Ring
rect(104, 4, 110, 24, SKIN)
-- Middle
rect(96, 3, 102, 24, SKIN)
-- Index
rect(88, 4, 94, 24, SKIN)
-- Thumb (left side at angle)
rect(78, 16, 84, 32, SKIN)

-- ──────────────────────────────────────────────────────────────
-- MANUALLY REFINE IN ASEPRITE:
--
-- 1. Add outline pixels (OUT color) around each hand shape for definition.
-- 2. Refine fingers: add slight gaps between them, curve the tips.
-- 3. Add knuckle crease lines (1px darker lines across finger width).
-- 4. Left palm center hollow: x=14..44, y=24..50 is where item icon overlays.
--    Right palm center hollow: x=83..113, y=24..50.
-- 5. Cuff detail: 2px border with a small button on each side.
-- 6. Optionally add a ring on one finger for extra character.
-- ──────────────────────────────────────────────────────────────

s:newCel(s.layers[1], 1, img, Point(0,0))
s:saveCopyAs("dealer_hands.png")
