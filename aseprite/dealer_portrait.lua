-- dealer_portrait.lua — 64×96 Dealer character (torso up)
-- Run via File › Scripts › Run Script in Aseprite
-- Output: dealer_portrait.png  →  place in assets/images/ui/
--
-- The script sets up the canvas with a base palette and rough color blocks.
-- FINISH the actual character details manually in Aseprite after running.
--
-- Character brief:
--   Overly happy dealer — huge grin, wide eyes, rosy cheeks.
--   Casino outfit: white dress shirt, black or dark-purple vest, bow tie (pink/neon).
--   Visible from just below the waist up to slightly above the head.
--   Background: transparent.
--   Style: same pixel art density as the machine cabinet art.
--
-- Rough pixel regions (64×96):
--   Head:  x=18..45, y=8..42    (28×35)
--   Neck:  x=27..36, y=42..50   (10×9)
--   Torso: x=10..53, y=50..88   (44×39)
--   Bow tie: x=27..36, y=50..55 (centered on neck/torso join)
--   Arms:  extend left x=4..10 and right x=53..59 from torso
--
-- Suggested palette:
--   Skin:   #d4a574  (warm tan pixel-art skin)
--   Shadow: #a0724a  (skin shadow)
--   Shirt:  #e8e8f0  (white shirt)
--   Vest:   #2a0a4a  (dark purple vest)
--   Tie:    #ff2d78  (neon pink bow tie)
--   Eye:    #1a0a2e  (dark eye)
--   Pupil:  #00e5ff  (neon cyan iris — unsettling)
--   Teeth:  #ffffff
--   Cheek:  #ff8888  (rosy blush)

local W, H = 64, 96
local s = Sprite(W, H, ColorMode.RGB)
s.filename = "dealer_portrait.aseprite"
local img = Image(W, H, ColorMode.RGB)
local P = app.pixelColor

local T     = P.rgba(0,   0,   0,   0)
local SKIN  = P.rgba(212, 165, 116, 255)
local VEST  = P.rgba(42,  10,  74, 255)
local SHIRT = P.rgba(232, 232, 240, 255)
local TIE   = P.rgba(255, 45, 120, 255)
local HAIR  = P.rgba(60,  35,  15, 255)

local function px(x,y,c) img:drawPixel(x,y,c) end
local function hline(x1,x2,y,c) for x=x1,x2 do px(x,y,c) end end
local function rect(x1,y1,x2,y2,c)
  for y=y1,y2 do hline(x1,x2,y,c) end
end

-- transparent background
rect(0, 0, W-1, H-1, T)

-- ── ROUGH PLACEHOLDER BLOCKS ── (replace with real pixel art in Aseprite)

-- Hair (top of head, flat cap style)
rect(18, 6, 45, 13, HAIR)

-- Head
rect(18, 13, 45, 42, SKIN)

-- Neck
rect(27, 42, 36, 50, SKIN)

-- Vest (torso body)
rect(10, 50, 53, 88, VEST)

-- Shirt collar / front panel (center strip)
rect(24, 50, 39, 88, SHIRT)

-- Bow tie (overlaid at neck join)
-- left wing
rect(24, 50, 28, 56, TIE)
-- right wing
rect(35, 50, 39, 56, TIE)
-- center knot
rect(29, 51, 34, 55, TIE)

-- Cuffed arms (shirt sleeves showing at side)
-- left arm
rect(4, 52, 10, 80, SHIRT)
-- right arm
rect(53, 52, 59, 80, SHIRT)
-- vest over arms
rect(10, 52, 20, 80, VEST)
rect(43, 52, 53, 80, VEST)

-- ──────────────────────────────────────────────────────────────
-- NOW DRAW MANUALLY IN ASEPRITE:
--
-- 1. FACE:
--    Eyes: two ~4×4 white squares at x=23..27,y=20..25 and x=36..40,y=20..25
--          Add cyan irises and dark pupils. Make them wide / slightly bulging.
--    Nose: 2-3 pixels, subtle, at x=31,y=29
--    Mouth: huge grin from x=22 to x=41, y=33..37
--          Top teeth row: white pixels x=23..41, y=33
--          Bottom of grin curves up at edges (like a Cheshire cat)
--    Cheeks: 3×2 blush patches at x=19..22,y=30..31 and x=42..45,y=30..31
--            Use soft pink: rgba(255,140,140,160)
--
-- 2. HAIR:
--    Refine the hair block to look like slicked-back or parted dealer hair.
--    Add a slight sheen highlight.
--
-- 3. VEST details:
--    Lapels: two triangular collar flaps folding out over the shirt.
--    A few shirt buttons down the center strip.
--    Pocket square on left chest: small neon pink rectangle.
--
-- 4. HANDS (optional, at bottom edge):
--    If space allows, show wrists/hands at y=84..95 with palms facing up
--    (as if presenting the two offer items). Otherwise leave transparent —
--    the app composites item cards in front of the portrait separately.
-- ──────────────────────────────────────────────────────────────

s:newCel(s.layers[1], 1, img, Point(0,0))
s:saveCopyAs("dealer_portrait.png")
