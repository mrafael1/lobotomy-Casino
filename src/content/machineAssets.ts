import type { ImageSourcePropType } from 'react-native';

// ── Machine v3 art ──────────────────────────────────────────────────────────
// All v3 layers are authored on the same 96×144 canvas and stack on top of each
// other. The runtime PNGs referenced here are 5× nearest-neighbour upscales of
// the hand-authored sources ("machine v3.png", "reel.png", …) — 5× matches the
// on-screen scale (96 → 480), so the app draws them 1:1 with no runtime blur.
// Regenerate with the composeV3() step in scripts/compose-runtime-assets.js.
//
// Geometry below is expressed in SOURCE pixels (96×144). The renderer converts
// to display pixels with a single factor f = machineWidth / 96 (the aspect is
// preserved, so the same factor applies on both axes).

export const MACHINE_SRC_W = 96;
export const MACHINE_SRC_H = 144;
export const MACHINE_ASPECT = MACHINE_SRC_H / MACHINE_SRC_W; // 1.5

// The three transparent reel holes in machine_v3.png (symbols show through from
// behind; the cabinet body masks the neighbours above/below each hole).
export const REEL_WINDOW = { left: 21, top: 68, width: 45, height: 14 } as const; // x21..65, y68..81
export const REEL_CELL_CENTERS = [26, 43, 60] as const; // source x of each hole centre
export const REEL_CELL_WIDTH = 11; // source px — width of one hole

// Per-cell hole rects (source px). symbols.png is authored on this same canvas,
// so clipping a cell to its hole and showing frame i renders symbol i in place.
export const REEL_HOLES = [
  { left: 21, top: 68, width: 11, height: 14 },
  { left: 38, top: 68, width: 11, height: 14 },
  { left: 55, top: 68, width: 11, height: 14 },
] as const;

// The TV screen at the top of the cabinet — app-rendered meters go here.
export const TV_SCREEN = { left: 13, top: 16, width: 54, height: 29 } as const; // x13..66, y16..44

// The multiplier readout strip (three number badges) sits between TV and reels.
export const MULT_STRIP = { top: 44, height: 12 } as const; // y44..56
export const MULT_BADGE_CENTERS = [26, 43, 60] as const;    // aligned with the reel cells

// Lever knob lives in the right margin; tap region a little larger than the art.
export const LEVER_HIT = { left: 72, top: 56, width: 21, height: 54 } as const; // x72..93, y56..110

// ── Frame counts ────────────────────────────────────────────────────────────
export const LEVER_FRAME_COUNT = 6;      // idle (0) → pulled (5), horizontal strip
// Multiplier frames encode both the selected bet AND which bets are locked:
//   0:×1  1:×2  2:×3  3:×1 (×3 locked)  4:×1 (×2+×3 locked)  5:×2 (×3 locked)
export const MULTIPLIER_FRAME_COUNT = 6;
export const JACKPOT_FRAME_COUNT = 2;     // 2-frame flashing banner
export const SYMBOL_FRAME_COUNT = 4;      // spin-blur frames in symbols.png
// Health / Wealth are 36-frame fill bars drawn inside the TV screen.
// Wealth: frame 0 empty → 35 full. Health: frame 0 full → 35 empty (depletes).
export const BAR_FRAME_COUNT = 36;

// ── Runtime image sources ───────────────────────────────────────────────────
export const MACHINE_V3: ImageSourcePropType = require('../../assets/images/machine_v3.png');
export const REEL_BG_V3: ImageSourcePropType = require('../../assets/images/reel_bg_v3.png');
export const MULTIPLIER_V3: ImageSourcePropType = require('../../assets/images/multiplier_v3.png');
export const LEVER_V3: ImageSourcePropType = require('../../assets/images/lever_v3.png');
export const JACKPOT_V3: ImageSourcePropType = require('../../assets/images/jackpot_v3.png');
export const SYMBOLS_SHEET_V3: ImageSourcePropType = require('../../assets/images/symbols_v3.png');
// Bar sheets are 36×96=3456 wide; kept at source res (a 5× would exceed the GPU
// texture limit) and rendered scaled — the thin bar tolerates it fine.
export const HEALTH_BAR_V3: ImageSourcePropType = require('../../assets/images/Health.png');
export const WEALTH_BAR_V3: ImageSourcePropType = require('../../assets/images/Wealth.png');
