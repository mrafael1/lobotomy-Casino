// generate-machine-overlays.js
//
// Generates the pixel-art LAYER PNGs for the slot machine's lever and
// multiplier panel, at native 200x300 — the same source resolution as every
// other layer in assets/images/machine_slot_layers/. These feed the existing
// compose-runtime-assets.js pipeline (alpha-composite -> 3x nearest upscale).
//
// Run:  node scripts/generate-machine-overlays.js
// Then: npm run assets:compose   (regenerates the runtime PNGs)
//
// Outputs (200x300, transparent background):
//   machine_slot_layers/Lever.png         — side lever, knob at x2 rest
//   machine_slot_layers/Multiplier_X1.png — multiplier panel, x1 active
//   machine_slot_layers/Multiplier_X2.png — multiplier panel, x2 active
//   machine_slot_layers/Multiplier_X3.png — multiplier panel, x3 active
//
// Geometry is fitted to the real Cabinet.png bounds:
//   cabinet body x=28..171, right margin x=172..199 empty (trim reaches ~183),
//   lower cabinet face (y>=182) is solid — the panel mounts there.

const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const LAYER_DIR = path.join(__dirname, '..', 'assets', 'images', 'machine_slot_layers');
const W = 200, H = 300;

// ---------------------------------------------------------------------------
// Palette  [r, g, b, a]
// ---------------------------------------------------------------------------
const NEAR_BLACK = [2, 6, 23, 255];      // #020617
const PANEL      = [13, 13, 30, 255];    // #0d0d1e
const DEEP_BG    = [3, 3, 7, 255];       // #030307
const SLATE      = [148, 163, 184, 255]; // #94a3b8
const SLATE_D    = [71, 85, 105, 255];   // #475569
const DARK_GRAY  = [100, 116, 139, 255]; // #64748b
const STEEL      = [241, 245, 249, 255]; // #f1f5f9
const CYAN       = [0, 229, 255, 255];   // #00e5ff
const MAGENTA    = [255, 45, 120, 255];  // #ff2d78
const AMBER      = [251, 191, 36, 255];  // #fbbf24
const WHITE_HI   = [255, 255, 255, 200];

// ---------------------------------------------------------------------------
// Raster helpers
// ---------------------------------------------------------------------------
function newImg() {
  const p = new PNG({ width: W, height: H });
  p.data.fill(0);
  return p;
}

function px(img, x, y, c) {
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  const i = (y * W + x) * 4;
  img.data[i] = c[0]; img.data[i + 1] = c[1]; img.data[i + 2] = c[2]; img.data[i + 3] = c[3];
}

function hline(img, x1, x2, y, c) { for (let x = x1; x <= x2; x++) px(img, x, y, c); }
function vline(img, x, y1, y2, c) { for (let y = y1; y <= y2; y++) px(img, x, y, c); }
function fillRect(img, x1, y1, x2, y2, c) { for (let y = y1; y <= y2; y++) hline(img, x1, x2, y, c); }
function strokeRect(img, x1, y1, x2, y2, c) {
  hline(img, x1, x2, y1, c); hline(img, x1, x2, y2, c);
  vline(img, x1, y1 + 1, y2 - 1, c); vline(img, x2, y1 + 1, y2 - 1, c);
}

// Two-tone ball knob: upper half STEEL, lower SLATE, 1px NEAR_BLACK outline.
function knob(img, cx, cy, r) {
  for (let y = cy - r; y <= cy + r; y++) {
    for (let x = cx - r; x <= cx + r; x++) {
      const d = Math.hypot(x - cx, y - cy);
      if (d < r - 0.5) px(img, x, y, y < cy ? STEEL : SLATE);
      else if (d <= r + 0.5) px(img, x, y, NEAR_BLACK);
    }
  }
}

// ---------------------------------------------------------------------------
// Tiny pixel fonts
// ---------------------------------------------------------------------------
// 5x7 digits
const DIGIT = {
  '1': ['..X..', '.XX..', '..X..', '..X..', '..X..', '..X..', '.XXX.'],
  '2': ['.XXX.', 'X...X', '....X', '..XX.', '.X...', 'X....', 'XXXXX'],
  '3': ['XXXX.', '....X', '....X', '.XXX.', '....X', '....X', 'XXXX.'],
};
// 5x5 multiply sign
const CROSS5 = ['X...X', '.X.X.', '..X..', '.X.X.', 'X...X'];

function stamp(img, rows, ox, oy, c) {
  for (let r = 0; r < rows.length; r++) {
    for (let k = 0; k < rows[r].length; k++) {
      if (rows[r][k] === 'X') px(img, ox + k, oy + r, c);
    }
  }
}

// 3x5 micro digits for the lever notch labels
const MICRO = {
  '1': ['.X.', 'XX.', '.X.', '.X.', 'XXX'],
  '2': ['XXX', '..X', 'XXX', 'X..', 'XXX'],
  '3': ['XXX', '..X', 'XXX', '..X', 'XXX'],
};

// ---------------------------------------------------------------------------
// LEVER  (right margin, vertical slider with x1/x2/x3 notches, knob at x2 rest)
// Fitted to clear the cabinet body (ends x=171); sits against neon trim (~183).
// ---------------------------------------------------------------------------
function buildLever() {
  const img = newImg();

  // Bezel / recessed slot channel (x=181..197, y=98..282)
  fillRect(img, 182, 99, 196, 281, PANEL);
  strokeRect(img, 181, 98, 197, 282, NEAR_BLACK);
  hline(img, 182, 196, 99, SLATE);        // bevel highlight top
  vline(img, 182, 99, 281, SLATE);        // bevel highlight left
  hline(img, 182, 196, 281, NEAR_BLACK);  // bevel shadow bottom
  vline(img, 196, 99, 281, NEAR_BLACK);   // bevel shadow right

  // Mounting bracket connecting the bezel to the cabinet side (so it reads as
  // bolted on, not floating in the margin). Spans the gap x=172..181.
  fillRect(img, 172, 136, 181, 150, SLATE_D);
  strokeRect(img, 172, 135, 181, 151, NEAR_BLACK);
  px(img, 174, 138, STEEL); px(img, 179, 138, STEEL); // bolt heads
  px(img, 174, 148, STEEL); px(img, 179, 148, STEEL);

  // Rail groove (the track)
  vline(img, 189, 103, 278, NEAR_BLACK);
  vline(img, 190, 103, 278, SLATE);

  // Lever shaft at x2 / middle rest position (y=148..225)
  fillRect(img, 187, 148, 189, 225, DARK_GRAY);
  vline(img, 187, 148, 225, SLATE);       // left highlight
  vline(img, 189, 148, 225, NEAR_BLACK);  // right shadow

  // Knob (ball grip), centre (188,143), r=4
  knob(img, 188, 143, 4);
  px(img, 185, 139, WHITE_HI); px(img, 186, 139, WHITE_HI);
  px(img, 185, 140, WHITE_HI); px(img, 186, 140, WHITE_HI); // 2x2 specular

  // Position notches (cyan dashes) + micro labels
  hline(img, 192, 196, 110, CYAN); stamp(img, MICRO['1'], 193, 104, CYAN); // x1 top
  hline(img, 192, 196, 186, CYAN); stamp(img, MICRO['2'], 193, 180, CYAN); // x2 mid (rest)
  hline(img, 192, 196, 262, CYAN); stamp(img, MICRO['3'], 193, 256, CYAN); // x3 bottom

  // TODO (phase 2 animation): emit Lever_X1 / Lever_X3 variants with the knob
  // at y=105 / y=257 and the shaft re-anchored, then swap by betMultiplier the
  // same way the multiplier panel does below.

  return img;
}

// ---------------------------------------------------------------------------
// MULTIPLIER PANEL  (lower cabinet face, below the reel window y=182)
// Full self-contained panel per state; the active slot is lit, others dim.
// Rendered as a transparent runtime overlay swapped by betMultiplier.
// ---------------------------------------------------------------------------
function buildMultiplier(active /* 1 | 2 | 3 */) {
  const img = newImg();

  // Panel mounts on the solid lower cabinet face, centred under the reels.
  const PX1 = 33, PY1 = 190, PX2 = 167, PY2 = 246;
  fillRect(img, PX1 + 1, PY1 + 1, PX2 - 1, PY2 - 1, PANEL);
  strokeRect(img, PX1, PY1, PX2, PY2, NEAR_BLACK);
  hline(img, PX1 + 1, PX2 - 1, PY1 + 1, CYAN);     // inner bevel top
  vline(img, PX1 + 1, PY1 + 1, PY2 - 1, CYAN);     // inner bevel left
  hline(img, PX1 + 1, PX2 - 1, PY2 - 1, SLATE_D);  // inner bevel bottom
  vline(img, PX2 - 1, PY1 + 1, PY2 - 1, SLATE_D);  // inner bevel right

  // Three slots side by side.
  const slots = [1, 2, 3];
  const innerL = PX1 + 4, innerR = PX2 - 4;
  const gutter = 4;
  const slotW = Math.floor((innerR - innerL + 1 - gutter * 2) / 3);
  const slotTop = PY1 + 6, slotBot = PY2 - 6;

  const accentFor = { 1: MAGENTA, 2: CYAN, 3: AMBER };

  slots.forEach((n, idx) => {
    const sx1 = innerL + idx * (slotW + gutter);
    const sx2 = sx1 + slotW - 1;
    const isActive = n === active;
    const accent = accentFor[n];

    // Slot recess
    fillRect(img, sx1 + 1, slotTop + 1, sx2 - 1, slotBot - 1, DEEP_BG);
    strokeRect(img, sx1, slotTop, sx2, slotBot, NEAR_BLACK);

    if (isActive) {
      // Glow border just inside the slot frame, in the slot's accent colour.
      strokeRect(img, sx1 + 1, slotTop + 1, sx2 - 1, slotBot - 1, accent);
    }

    // "xN" label centred in the slot. CROSS5 (5px) + gap(1) + DIGIT (5px) = 11px.
    const labelW = 5 + 1 + 5;
    const lx = sx1 + Math.floor((slotW - labelW) / 2);
    const ly = slotTop + Math.floor((slotBot - slotTop - 7) / 2);
    const labelColor = isActive ? accent : SLATE_D;
    stamp(img, CROSS5, lx, ly + 1, labelColor); // cross sits 1px lower (5 tall vs 7)
    stamp(img, DIGIT[String(n)], lx + 6, ly, labelColor);
  });

  return img;
}

// ---------------------------------------------------------------------------
// Emit
// ---------------------------------------------------------------------------
function save(img, name) {
  const out = path.join(LAYER_DIR, name);
  fs.writeFileSync(out, PNG.sync.write(img));
  console.log('wrote', path.relative(path.join(__dirname, '..'), out));
}

save(buildLever(), 'Lever.png');
save(buildMultiplier(1), 'Multiplier_X1.png');
save(buildMultiplier(2), 'Multiplier_X2.png');
save(buildMultiplier(3), 'Multiplier_X3.png');
console.log('done. now run: npm run assets:compose');
