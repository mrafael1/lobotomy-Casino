// gen-multiplier-overlays.js
// Generates the three Multiplier_Top_Xn.png source overlays (200x300) that the
// compose pipeline upscales to runtime. Each overlay draws a single solid-color
// background strip across the top-panel row, with three evenly-spread buttons
// (x1 / x2 / x3); the one matching the file's N is highlighted as active.
//
// Run:  node scripts/gen-multiplier-overlays.js   (then npm run assets:compose)
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'assets', 'images', 'machine_slot_layers');

const W = 200, H = 300;

// Row strip — fits between the two purple panel pillars (interior x≈56..147).
const STRIP = { x0: 56, x1: 147, y0: 42, y1: 66 };
const PAD = 3;
const GAP = 3;
const N = 3;
const innerX0 = STRIP.x0 + PAD;
const innerX1 = STRIP.x1 - PAD;
const BW = Math.floor((innerX1 - innerX0 + 1 - GAP * (N - 1)) / N); // button width
const BTN_Y0 = STRIP.y0 + PAD;
const BTN_Y1 = STRIP.y1 - PAD;

function buttonLeft(i) { return innerX0 + i * (BW + GAP); }

// Export the geometry so the app's tap targets can mirror it exactly.
const GEOMETRY = {
  top: BTN_Y0,
  height: BTN_Y1 - BTN_Y0 + 1,
  width: BW,
  lefts: [0, 1, 2].map(buttonLeft),
};

// ── colors ──
const C = {
  strip:       [12, 10, 30, 255],     // one solid background color
  btnFill:     [20, 16, 42, 255],     // inactive button
  btnBorder:   [74, 58, 106, 255],
  btnLabel:    [154, 138, 192, 255],
  actFill:     [8, 32, 58, 255],      // active button
  actBorder:   [0, 229, 255, 255],
  actLabel:    [0, 229, 255, 255],
};

// 3x5 pixel font for the digits we need, plus a 3x3 'x'.
const GLYPH = {
  x: ['x.x', '.x.', 'x.x'],
  1: ['.x.', 'xx.', '.x.', '.x.', 'xxx'],
  2: ['xxx', '..x', 'xxx', 'x..', 'xxx'],
  3: ['xxx', '..x', 'xxx', '..x', 'xxx'],
};

function makePng() {
  const p = new PNG({ width: W, height: H });
  p.data.fill(0);
  return p;
}
function set(p, x, y, [r, g, b, a]) {
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  const i = (y * W + x) * 4;
  p.data[i] = r; p.data[i + 1] = g; p.data[i + 2] = b; p.data[i + 3] = a;
}
function rect(p, x0, y0, x1, y1, col) {
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set(p, x, y, col);
}
function border(p, x0, y0, x1, y1, col) {
  for (let x = x0; x <= x1; x++) { set(p, x, y0, col); set(p, x, y1, col); }
  for (let y = y0; y <= y1; y++) { set(p, x0, y, col); set(p, x1, y, col); }
}

// Draw a scaled glyph grid at (ox,oy); returns drawn width in px.
function drawGlyph(p, rows, ox, oy, scale, col) {
  const wCells = rows[0].length;
  for (let r = 0; r < rows.length; r++) {
    for (let c = 0; c < wCells; c++) {
      if (rows[r][c] !== 'x') continue;
      rect(p, ox + c * scale, oy + r * scale, ox + c * scale + scale - 1, oy + r * scale + scale - 1, col);
    }
  }
  return wCells * scale;
}

// Draw "x{n}" centered in the button rect.
function drawLabel(p, bx0, by0, bx1, by1, n, col) {
  const scale = 2;
  const xW = GLYPH.x[0].length * scale;       // 3*2 = 6
  const dW = GLYPH[n][0].length * scale;       // 3*2 = 6
  const space = 2;
  const totalW = xW + space + dW;
  const totalH = GLYPH[n].length * scale;      // 5*2 = 10
  const ox = Math.round((bx0 + bx1 + 1 - totalW) / 2);
  const oy = Math.round((by0 + by1 + 1 - totalH) / 2);
  // 'x' is 3 rows tall — vertically center it against the 5-row digit
  drawGlyph(p, GLYPH.x, ox, oy + scale, scale, col);
  drawGlyph(p, GLYPH[n], ox + xW + space, oy, scale, col);
}

function buildOverlay(activeN) {
  const p = makePng();
  // solid background strip
  rect(p, STRIP.x0, STRIP.y0, STRIP.x1, STRIP.y1, C.strip);
  // buttons
  for (let i = 0; i < N; i++) {
    const m = i + 1;
    const x0 = buttonLeft(i);
    const x1 = x0 + BW - 1;
    const active = m === activeN;
    rect(p, x0, BTN_Y0, x1, BTN_Y1, active ? C.actFill : C.btnFill);
    border(p, x0, BTN_Y0, x1, BTN_Y1, active ? C.actBorder : C.btnBorder);
    if (active) border(p, x0 + 1, BTN_Y0 + 1, x1 - 1, BTN_Y1 - 1, C.actBorder); // 2px ring
    drawLabel(p, x0, BTN_Y0, x1, BTN_Y1, m, active ? C.actLabel : C.btnLabel);
  }
  return p;
}

for (const n of [1, 2, 3]) {
  const file = path.join(OUT_DIR, `Multiplier_Top_X${n}.png`);
  fs.writeFileSync(file, PNG.sync.write(buildOverlay(n)));
  console.log(`wrote ${path.relative(ROOT, file)}`);
}
console.log('geometry (src 200x300):', JSON.stringify(GEOMETRY));
