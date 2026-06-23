import type { ImageSourcePropType } from 'react-native';

// ── Machine art (new view) ──────────────────────────────────────────────────
// The machine is now authored as the FULL 160×320 game canvas (cabinet drawn in
// the lower portion, empty space above). The runtime PNGs in "machine new view/"
// are 8× the 160×320 source (1280×2560). PixelScene fit-scales the whole canvas
// to the screen, so the ×8 art is downscaled (supersampled → crisp) and, because
// the display scale equals the art scale, every layer draws 1:1 internally.
//
// Geometry below is expressed in SOURCE pixels (160×320). The renderer converts
// to display pixels with a single factor f = machineWidth / 160 (the aspect is
// preserved, so the same factor applies on both axes). Values measured from
// machine_new_view.png / wealth_fill / health_fill / lever_new_view.
export const MACHINE_SRC_W = 160;
export const MACHINE_SRC_H = 320;
export const MACHINE_ASPECT = MACHINE_SRC_H / MACHINE_SRC_W; // 2.0

// The three transparent reel holes (symbols show through from behind; the cabinet
// body masks the neighbours above/below each hole).
export const REEL_WINDOW = { left: 35, top: 248, width: 86, height: 33 } as const; // x35..121, y248..281
export const REEL_CELL_CENTERS = [45.5, 78.5, 110.5] as const; // source x of each hole centre
export const REEL_CELL_WIDTH = 22; // source px — width of one hole

// Per-cell hole rects (source px). symbols_new_view.png is authored on this same
// canvas, so clipping a cell to its hole and showing frame i renders symbol i.
export const REEL_HOLES = [
  { left: 35, top: 248, width: 22, height: 33 },
  { left: 68, top: 248, width: 22, height: 33 },
  { left: 100, top: 248, width: 22, height: 33 },
] as const;

// The TV screen near the top of the cabinet — app-rendered meters go here.
export const TV_SCREEN = { left: 22, top: 128, width: 116, height: 58 } as const; // x22..138, y128..186

// The multiplier readout strip (three number badges) sits between TV and reels.
export const MULT_STRIP = { top: 196, height: 20 } as const; // y196..216
export const MULT_BADGE_CENTERS = [50, 79, 108] as const;    // measured badge centres

// Lever knob lives in the right margin; tap region a little larger than the art.
export const LEVER_HIT = { left: 131, top: 132, width: 22, height: 44 } as const; // x131..153, y132..176

// ── Frame counts ────────────────────────────────────────────────────────────
export const LEVER_FRAME_COUNT = 6;      // idle (0) → pulled (5), horizontal strip
// Multiplier frames encode both the selected bet AND which bets are locked:
//   0:×1  1:×2  2:×3  3:×1 (×3 locked)  4:×1 (×2+×3 locked)  5:×2 (×3 locked)
export const MULTIPLIER_FRAME_COUNT = 6;
export const JACKPOT_FRAME_COUNT = 2;     // 2-frame flashing banner
export const SYMBOL_FRAME_COUNT = 4;      // spin-blur frames in symbols.png

// TV fill bars are rendered as a track + a fill clipped left→right by the value.
// (The authored 36-frame sheets are 17280px wide — past the GPU texture limit —
// so we use a single track/fill frame each and reveal the fill ourselves.)
// Fill region within the 160×320 canvas (same for both bars):
export const BAR_FILL = { left: 47, width: 66 } as const;

// Full bar rects (source px) — BAR_FILL gives the horizontal fill region; these
// add the vertical position so the app-rendered readouts can sit just above each
// bar. Measured from wealth_fill / health_fill (money/wealth bar above the
// spins/health bar).
export const WEALTH_BAR = { left: 47, top: 152, width: 66, height: 4 } as const;
export const HEALTH_BAR = { left: 47, top: 173, width: 66, height: 5 } as const;

// ── Runtime image sources ───────────────────────────────────────────────────
export const MACHINE_V3: ImageSourcePropType = require('../../assets/images/machine new view/machine_new_view.png');
export const REEL_BG_V3: ImageSourcePropType = require('../../assets/images/machine new view/reel_new_view.png');
export const MULTIPLIER_V3: ImageSourcePropType = require('../../assets/images/machine new view/multiplier_new_view.png');
export const LEVER_V3: ImageSourcePropType = require('../../assets/images/machine new view/lever_new_view.png');
export const JACKPOT_V3: ImageSourcePropType = require('../../assets/images/machine new view/jackpot_new_view.png');
export const SYMBOLS_SHEET_V3: ImageSourcePropType = require('../../assets/images/machine new view/symbols_new_view.png');
// TV bars — track (empty) + fill (full), each a single 5× full-canvas frame
// cropped from the authored sheets. Small textures, crisp at the machine's scale.
export const WEALTH_TRACK_V3: ImageSourcePropType = require('../../assets/images/machine new view/wealth_track_new_view.png');
export const WEALTH_FILL_V3: ImageSourcePropType = require('../../assets/images/machine new view/wealth_fill_new_view.png');
export const HEALTH_TRACK_V3: ImageSourcePropType = require('../../assets/images/machine new view/health_track_new_view.png');
export const HEALTH_FILL_V3: ImageSourcePropType = require('../../assets/images/machine new view/health_fill_new_view.png');
