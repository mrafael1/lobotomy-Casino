// scripts/generate-dealer-shop-bg.js
// Regenerates assets/images/dealer_shop_bg.png (Layer 1 of the dealer shop scene).
// Run with: node scripts/generate-dealer-shop-bg.js
//
// This mirrors aseprite/dealer_shop_scene.lua — keep both in sync.
// Canvas: 320×480. Fully opaque. NO counter (handled by dealer_shop_counter.png).
//
// Layout (source px):
//   Ceiling neon  y=12
//   POWERS shelf  boardY=56  (icons above: y=12..55,  depth below: y=56..65)
//   POSITIVE shelf boardY=110 (icons above: y=66..109, depth below: y=110..119)
//   CORRUPTED shelf boardY=164 (icons above: y=120..163, depth below: y=164..173)
//   Back-bar backdrop x=70..250, y=168..356

const fs   = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const W = 320, H = 480;

const png = new PNG({ width: W, height: H });
png.data.fill(0xff);  // start opaque white; every pixel is overwritten below

function pxSet(x, y, r, g, b, a = 255) {
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  const i = (y * W + x) * 4;
  png.data[i]     = r;
  png.data[i + 1] = g;
  png.data[i + 2] = b;
  png.data[i + 3] = a;
}
function hline(x1, x2, y, r, g, b, a) {
  for (let x = x1; x <= x2; x++) pxSet(x, y, r, g, b, a);
}
function vline(x, y1, y2, r, g, b, a) {
  for (let y = y1; y <= y2; y++) pxSet(x, y, r, g, b, a);
}
function rect(x1, y1, x2, y2, r, g, b, a) {
  for (let y = y1; y <= y2; y++) hline(x1, x2, y, r, g, b, a);
}

// ── Palette ──────────────────────────────────────────────────────────────────
const WALL    = [0x0e, 0x08, 0x1c];
const CEIL    = [0x14, 0x0a, 0x24];
const BOARD   = [0x3a, 0x22, 0x0e];   // shelf top surface
const BOARD_D = [0x1e, 0x10, 0x06];   // shelf front face (darker, gives depth)
const LIP     = [0x52, 0x30, 0x14];   // lit top edge of shelf
const BACKBAR = [0x16, 0x10, 0x2c];
const BOTTLE  = [0x24, 0x18, 0x40];
const SHELF_L = [0x2a, 0x1c, 0x48];   // faint shelf lines in back-bar
const ACC_POW = [0xa8, 0x55, 0xf7];   // purple (ability upgrades)
const ACC_POS = [0x22, 0xc5, 0x5e];   // green  (positive upgrades)
const ACC_COR = [0xef, 0x44, 0x44];   // red    (corrupted upgrades)

// ── Wall + ceiling ────────────────────────────────────────────────────────────
rect(0, 0, W-1, H-1, ...WALL);
rect(0, 0, W-1, 11,  ...CEIL);
hline(0, W-1, 12, 0xff, 0x2d, 0x55);   // pink neon tube
hline(0, W-1, 13, 0x60, 0x10, 0x20);   // neon dark glow

// ── Three shelves (with front-face depth) ────────────────────────────────────
// Each shelf:
//   boardY-1  : accent neon line (visible in gaps between icons)
//   boardY    : LIP highlight (top edge of shelf surface)
//   boardY+1..2: BOARD (shelf top surface, icons rest here)
//   boardY+3  : BOARD_D (transition)
//   boardY+4..8: BOARD_D (front face — the "depth" the user sees below icons)
//   boardY+9  : shadow stripe below shelf
//
// Icon areas sit ABOVE boardY: POWERS y=12..55, POSITIVE y=66..109, CORRUPTED y=120..163.
// Everything below boardY is fully visible beneath the icons.
const shelves = [
  { boardY: 56,  acc: ACC_POW },
  { boardY: 110, acc: ACC_POS },
  { boardY: 164, acc: ACC_COR },
];
for (const { boardY: b, acc } of shelves) {
  const [ar, ag, ab] = acc;
  hline(0, W-1, b-1, ar, ag, ab);           // accent glow above shelf
  hline(0, W-1, b,   ...LIP);               // top-edge highlight
  hline(0, W-1, b+1, ...BOARD);             // shelf surface
  hline(0, W-1, b+2, ...BOARD);
  hline(0, W-1, b+3, ar, ag, ab, 160);      // coloured edge (top of front face)
  rect(0, b+4, W-1, b+8, ...BOARD_D);       // front face (depth)
  hline(0, W-1, b+9, 0x06, 0x04, 0x10);    // shadow under shelf
}

// ── Back-bar backdrop (dealer stands here at runtime) ────────────────────────
rect(70, 168, 250, 356, ...BACKBAR);
for (const bx of [90, 130, 170, 210, 230]) {
  vline(bx, 176, 300, ...BOTTLE);
}
hline(72, 248, 176, ...SHELF_L);
hline(72, 248, 240, ...SHELF_L);

// ── Write output ─────────────────────────────────────────────────────────────
const outPath = path.join(__dirname, '..', 'assets', 'images', 'dealer_shop_bg.png');
fs.writeFileSync(outPath, PNG.sync.write(png));
console.log(`✓  dealer_shop_bg.png → ${outPath}`);
