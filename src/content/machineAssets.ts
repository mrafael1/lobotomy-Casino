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
// body masks the neighbours above/below each hole). Measured from final_machine /
// reel_final_machine (the reel windows sit higher in the new cabinet).
export const REEL_WINDOW = { left: 33, top: 170, width: 85, height: 30 } as const; // x33..118, y170..200
export const REEL_CELL_CENTERS = [43.5, 75.5, 107.5] as const; // source x of each hole centre
export const REEL_CELL_WIDTH = 21; // source px — width of one hole

// Per-cell hole rects (source px). spin_final_machine.png is authored on this same
// canvas, so clipping a cell to its hole and showing frame i renders symbol i.
export const REEL_HOLES = [
  { left: 33, top: 170, width: 21, height: 30 },
  { left: 65, top: 170, width: 21, height: 30 },
  { left: 97, top: 170, width: 21, height: 30 },
] as const;

// The TV screen near the top of the cabinet — app-rendered meters go here.
export const TV_SCREEN = { left: 24, top: 42, width: 112, height: 66 } as const; // x24..136, y42..108

// The multiplier readout strip (three number badges) sits between TV and reels.
export const MULT_STRIP = { top: 119, height: 16 } as const; // y119..135
export const MULT_BADGE_CENTERS = [47, 78, 106] as const;    // measured badge centres

// Lever knob lives in the right margin; tap region a little larger than the art.
export const LEVER_HIT = { left: 133, top: 160, width: 20, height: 40 } as const; // x133..153, y160..200

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
export const BAR_FILL = { left: 43, width: 66 } as const;

// Full bar rects (source px) — BAR_FILL gives the horizontal fill region; these
// add the vertical position so the app-rendered readouts can sit just above each
// bar. Measured from wealth_fill / health_fill (money/wealth bar above the
// spins/health bar). In the new cabinet both bars sit in the top TV screen.
export const WEALTH_BAR = { left: 43, top: 73, width: 66, height: 4 } as const;
export const HEALTH_BAR = { left: 43, top: 94, width: 66, height: 5 } as const;

// ── Machine-mounted power buttons ────────────────────────────────────────────
// reroll/shift/lock_final_machine.png are full-canvas 3-frame sheets:
//   0: available (lit)   1: selected/pressed   2: unavailable (greyed)
// "lock" art drives the existing reel-lock "memory" ability. Hit rects are the
// measured on-canvas icon positions (source px), a touch larger than the art.
export const POWER_FRAME_COUNT = 3;
export const POWER_HITS = {
  reroll: { left: 21, top: 223, width: 15, height: 15 },
  shift:  { left: 36, top: 223, width: 13, height: 15 },
  lock:   { left: 49, top: 223, width: 13, height: 15 },
} as const;

// ── Runtime image sources ───────────────────────────────────────────────────
export const MACHINE_V3: ImageSourcePropType = require('../../assets/images/machine new view/final_machine.png');
export const REEL_BG_V3: ImageSourcePropType = require('../../assets/images/machine new view/reel_final_machine.png');
export const MULTIPLIER_V3: ImageSourcePropType = require('../../assets/images/machine new view/multiplier_final_machine.png');
export const LEVER_V3: ImageSourcePropType = require('../../assets/images/machine new view/lever_final_machine.png');
export const JACKPOT_V3: ImageSourcePropType = require('../../assets/images/machine new view/jackpot_final_machine.png');
export const SYMBOLS_SHEET_V3: ImageSourcePropType = require('../../assets/images/machine new view/spin_final_machine.png');
// Machine-mounted power button sheets (3 frames each — see POWER_FRAME_COUNT).
export const REROLL_V3: ImageSourcePropType = require('../../assets/images/machine new view/reroll_final_machine.png');
export const SHIFT_V3: ImageSourcePropType = require('../../assets/images/machine new view/shift_final_machine.png');
export const LOCK_V3: ImageSourcePropType = require('../../assets/images/machine new view/lock_final_machine.png');
// TV bars — track (empty) + fill (full), each a single 5× full-canvas frame
// cropped from the authored sheets. Small textures, crisp at the machine's scale.
export const WEALTH_TRACK_V3: ImageSourcePropType = require('../../assets/images/machine new view/wealth_track_final_machine.png');
export const WEALTH_FILL_V3: ImageSourcePropType = require('../../assets/images/machine new view/wealth_fill_final_machine.png');
export const HEALTH_TRACK_V3: ImageSourcePropType = require('../../assets/images/machine new view/health_track_final_machine.png');
export const HEALTH_FILL_V3: ImageSourcePropType = require('../../assets/images/machine new view/health_fill_final_machine.png');
