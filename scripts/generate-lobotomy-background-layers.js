const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const OUT_DIR = path.join(__dirname, '..', 'assets', 'images', 'lobotomy_background_layers');
const W = 320;
const H = 480;
const HORIZON_Y = 288;
const FOCUS_ZONE = { x: 80, y: 92, width: 160, height: 260 };

// NEON palette: saturated, candy-like, exciting.
const NEON = {
  hotPink: '#FF2DAA',
  electricCyan: '#21F7FF',
  jackpotAmber: '#FFD23A',
  vibrantPurple: '#7A2CFF',
  brightWhite: '#FFFFFF',
};

// DECAY palette: same hues, desaturated and sickened.
const DECAY = {
  sickPink: '#8A4769',
  muddyTeal: '#3E7772',
  dimAmber: '#8F7A3E',
  bruisedPurple: '#43345F',
  deadGreen: '#57664A',
};

const C = {
  wallTop: [25, 7, 54, 255],
  wallMid: [62, 17, 104, 255],
  wallLow: [29, 17, 65, 255],
  floorNear: [18, 9, 38, 255],
  floorFar: [52, 19, 75, 255],
  pink: [255, 45, 170, 255],
  cyan: [33, 247, 255, 255],
  amber: [255, 210, 58, 255],
  purple: [122, 44, 255, 255],
  white: [255, 255, 255, 255],
  sheen: [255, 255, 255, 70],
  sickTop: [21, 31, 29, 255],
  sickMid: [47, 57, 48, 255],
  sickLow: [30, 34, 33, 255],
  sickFloorNear: [16, 22, 20, 255],
  sickFloorFar: [45, 52, 40, 255],
  sickPink: [138, 71, 105, 210],
  muddyTeal: [62, 119, 114, 220],
  dimAmber: [143, 122, 62, 190],
  bruisedPurple: [67, 52, 95, 210],
  deadGreen: [87, 102, 74, 220],
  rot: [5, 8, 7, 175],
  vein: [115, 68, 91, 86],
  brainFold: [151, 106, 125, 58],
  glitchPink: [255, 42, 123, 235],
  glitchCyan: [33, 247, 255, 225],
};

function hexToRgb(hex, alpha = 255) {
  const clean = hex.replace('#', '');
  return [
    parseInt(clean.slice(0, 2), 16),
    parseInt(clean.slice(2, 4), 16),
    parseInt(clean.slice(4, 6), 16),
    alpha,
  ];
}

function mix(a, b, t) {
  return [
    Math.round(a[0] + (b[0] - a[0]) * t),
    Math.round(a[1] + (b[1] - a[1]) * t),
    Math.round(a[2] + (b[2] - a[2]) * t),
    Math.round(a[3] + (b[3] - a[3]) * t),
  ];
}

function makeImage() {
  const png = new PNG({ width: W, height: H });
  png.data.fill(0);
  return png;
}

function px(img, x, y, color) {
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  const i = (y * W + x) * 4;
  img.data[i] = color[0];
  img.data[i + 1] = color[1];
  img.data[i + 2] = color[2];
  img.data[i + 3] = color[3];
}

function rect(img, x, y, w, h, color) {
  for (let yy = y; yy < y + h; yy++) {
    for (let xx = x; xx < x + w; xx++) px(img, xx, yy, color);
  }
}

function line(img, x1, y1, x2, y2, color) {
  let dx = Math.abs(x2 - x1);
  const sx = x1 < x2 ? 1 : -1;
  let dy = -Math.abs(y2 - y1);
  const sy = y1 < y2 ? 1 : -1;
  let err = dx + dy;
  while (true) {
    px(img, x1, y1, color);
    if (x1 === x2 && y1 === y2) break;
    const e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x1 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y1 += sy;
    }
  }
}

function ellipse(img, cx, cy, rx, ry, color) {
  for (let y = -ry; y <= ry; y++) {
    for (let x = -rx; x <= rx; x++) {
      if ((x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1) {
        px(img, cx + x, cy + y, color);
      }
    }
  }
}

function outlineRect(img, x, y, w, h, color) {
  rect(img, x, y, w, 1, color);
  rect(img, x, y + h - 1, w, 1, color);
  rect(img, x, y, 1, h, color);
  rect(img, x + w - 1, y, 1, h, color);
}

function saveLayer(name, draw) {
  const img = makeImage();
  draw(img);
  const out = path.join(OUT_DIR, `${name}.png`);
  fs.writeFileSync(out, PNG.sync.write(img));
  return out;
}

function drawPerspectiveRoom(img, palette) {
  const top = palette === 'neon' ? C.wallTop : C.sickTop;
  const mid = palette === 'neon' ? C.wallMid : C.sickMid;
  const low = palette === 'neon' ? C.wallLow : C.sickLow;
  const floorFar = palette === 'neon' ? C.floorFar : C.sickFloorFar;
  const floorNear = palette === 'neon' ? C.floorNear : C.sickFloorNear;

  for (let y = 0; y < HORIZON_Y; y++) {
    const t = y / HORIZON_Y;
    const base = t < 0.58 ? mix(top, mid, t / 0.58) : mix(mid, low, (t - 0.58) / 0.42);
    rect(img, 0, y, W, 1, base);
  }

  for (let y = HORIZON_Y; y < H; y++) {
    const t = (y - HORIZON_Y) / (H - HORIZON_Y);
    rect(img, 0, y, W, 1, mix(floorFar, floorNear, t));
  }

  const side = palette === 'neon' ? [17, 8, 40, 255] : [15, 22, 19, 255];
  const seam = palette === 'neon' ? [103, 35, 136, 255] : [59, 71, 56, 255];
  rect(img, 0, 0, 35, H, side);
  rect(img, W - 35, 0, 35, H, side);
  line(img, 35, 34, 96, HORIZON_Y, seam);
  line(img, W - 36, 34, W - 97, HORIZON_Y, seam);
  line(img, 0, HORIZON_Y, W, HORIZON_Y, seam);

  const floorLine = palette === 'neon' ? [77, 28, 107, 255] : [53, 62, 49, 255];
  for (let i = 0; i < 9; i++) {
    const y = HORIZON_Y + 18 + i * 20;
    line(img, 0, y, W, y + i * 3, floorLine);
  }
  [60, 100, 140, 180, 220, 260].forEach((x) => line(img, x, H, 160, HORIZON_Y, floorLine));
}

fs.mkdirSync(OUT_DIR, { recursive: true });

const layers = [
  ['BG_Neon', (img) => {
    drawPerspectiveRoom(img, 'neon');
    ellipse(img, 160, 336, 88, 40, [255, 198, 70, 155]);
    ellipse(img, 160, 336, 55, 22, [255, 231, 130, 110]);
    rect(img, 78, 72, 164, 8, [255, 45, 170, 210]);
    rect(img, 86, 80, 148, 3, [33, 247, 255, 190]);
    outlineRect(img, 48, 38, 224, 268, [101, 33, 150, 160]);
  }],
  ['Glow_Pink', (img) => {
    for (let r = 74; r > 0; r -= 4) ellipse(img, 92, 178, r, Math.floor(r * 1.45), [255, 45, 170, Math.max(8, 82 - r)]);
    for (let r = 64; r > 0; r -= 4) ellipse(img, 252, 104, r, Math.floor(r * 0.9), [255, 45, 170, Math.max(7, 70 - r)]);
    rect(img, 0, 126, 48, 5, [255, 45, 170, 180]);
    rect(img, 272, 206, 48, 5, [255, 45, 170, 165]);
    line(img, 41, 48, 78, 230, [255, 45, 170, 120]);
    line(img, 279, 50, 239, 232, [255, 45, 170, 120]);
  }],
  ['Glow_Cyan', (img) => {
    for (let r = 76; r > 0; r -= 4) ellipse(img, 228, 188, r, Math.floor(r * 1.25), [33, 247, 255, Math.max(8, 82 - r)]);
    for (let r = 62; r > 0; r -= 4) ellipse(img, 68, 94, r, Math.floor(r * 0.85), [33, 247, 255, Math.max(7, 68 - r)]);
    rect(img, 0, 184, 54, 4, [33, 247, 255, 175]);
    rect(img, 266, 132, 54, 4, [33, 247, 255, 175]);
    line(img, 36, 40, 95, HORIZON_Y, [33, 247, 255, 110]);
    line(img, 284, 40, 224, HORIZON_Y, [33, 247, 255, 110]);
  }],
  ['Lights_Bright', (img) => {
    const bulbs = [];
    for (let x = 44; x <= 276; x += 22) bulbs.push([x, 58]);
    for (let y = 88; y <= 258; y += 24) {
      bulbs.push([22, y]);
      bulbs.push([298, y]);
    }
    for (let x = 55; x <= 265; x += 30) bulbs.push([x, 310]);
    bulbs.forEach(([x, y], i) => {
      const color = i % 3 === 0 ? C.pink : i % 3 === 1 ? C.cyan : C.amber;
      rect(img, x - 2, y - 2, 5, 5, color);
      px(img, x - 1, y - 1, C.white);
      px(img, x, y - 1, C.white);
    });
  }],
  ['Sheen', (img) => {
    line(img, 58, 40, 205, 10, C.sheen);
    line(img, 64, 43, 211, 13, [33, 247, 255, 42]);
    line(img, 100, 102, 272, 72, [255, 255, 255, 52]);
    line(img, 42, 253, 143, 238, [255, 255, 255, 45]);
    line(img, 180, 350, 263, 338, [255, 210, 58, 38]);
    rect(img, FOCUS_ZONE.x, FOCUS_ZONE.y, FOCUS_ZONE.width, 1, [255, 255, 255, 18]);
    rect(img, FOCUS_ZONE.x, FOCUS_ZONE.y + FOCUS_ZONE.height - 1, FOCUS_ZONE.width, 1, [255, 255, 255, 14]);
  }],
  ['BG_Sickly', (img) => {
    drawPerspectiveRoom(img, 'decay');
    ellipse(img, 160, 336, 88, 40, [143, 122, 62, 105]);
    ellipse(img, 160, 336, 55, 22, [101, 106, 64, 80]);
    rect(img, 78, 72, 164, 8, [87, 102, 74, 205]);
    rect(img, 86, 80, 148, 3, [62, 119, 114, 175]);
    outlineRect(img, 48, 38, 224, 268, [67, 52, 95, 140]);
    rect(img, 0, 0, 320, 16, [5, 8, 7, 58]);
    rect(img, 0, 454, 320, 26, [5, 8, 7, 72]);
  }],
  ['Glitch', (img) => {
    const rows = [
      [8, 86, 42, C.glitchPink], [245, 91, 36, C.glitchCyan], [19, 151, 30, C.glitchCyan],
      [269, 181, 35, C.glitchPink], [4, 238, 52, C.glitchPink], [247, 266, 48, C.glitchCyan],
      [28, 374, 66, C.glitchCyan], [226, 414, 72, C.glitchPink],
    ];
    rows.forEach(([x, y, w, c]) => rect(img, x, y, w, 3, c));
    rect(img, 8, 112, 18, 12, [5, 8, 7, 210]);
    rect(img, 286, 218, 21, 15, [255, 42, 123, 185]);
    rect(img, 22, 421, 34, 8, [33, 247, 255, 160]);
    rect(img, 262, 43, 25, 7, [143, 122, 62, 190]);
  }],
  ['BrainImagery', (img) => {
    const folds = [
      [63, 116, 102, 104, 134, 118], [65, 133, 104, 148, 139, 130],
      [196, 111, 230, 100, 265, 125], [191, 138, 225, 154, 267, 138],
      [54, 228, 92, 206, 136, 226], [190, 226, 229, 204, 270, 226],
    ];
    folds.forEach(([x1, y1, x2, y2, x3, y3]) => {
      line(img, x1, y1, x2, y2, C.brainFold);
      line(img, x2, y2, x3, y3, C.brainFold);
    });
    [
      [38, 70, 72, 185], [282, 74, 248, 188], [52, 188, 90, 275],
      [268, 184, 232, 272], [118, 34, 101, 86], [206, 34, 218, 86],
    ].forEach(([x1, y1, x2, y2]) => line(img, x1, y1, x2, y2, C.vein));
    [72, 94, 226, 246].forEach((x, i) => ellipse(img, x, i < 2 ? 139 : 150, 13, 8, [151, 106, 125, 34]));
  }],
  ['Vignette_Dark', (img) => {
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const dx = Math.abs(x - W / 2) / (W / 2);
        const dy = Math.abs(y - H / 2) / (H / 2);
        const edge = Math.max(dx, dy);
        const radial = Math.sqrt(dx * dx + dy * dy) / 1.38;
        const a = Math.max(0, Math.min(185, Math.round((Math.max(edge, radial) - 0.45) * 245)));
        if (a > 0) px(img, x, y, [3, 5, 5, a]);
      }
    }
  }],
];

const written = layers.map(([name, draw]) => ({ name, file: saveLayer(name, draw) }));

const manifest = {
  width: W,
  height: H,
  horizonY: HORIZON_Y,
  focusZone: FOCUS_ZONE,
  palettes: { NEON, DECAY },
  layers: written,
  healthyLayers: ['BG_Neon', 'Glow_Pink', 'Glow_Cyan', 'Lights_Bright', 'Sheen'],
  decayLayers: ['BG_Sickly', 'Glitch', 'BrainImagery', 'Vignette_Dark'],
};

fs.writeFileSync(path.join(OUT_DIR, 'manifest.json'), JSON.stringify(manifest, null, 2));

console.log('Generated lobotomy background layers:');
for (const layer of written) console.log(`${layer.name}: ${layer.file}`);
console.log(`HORIZON_Y = ${HORIZON_Y}`);
console.log(`FOCUS_ZONE = { x = ${FOCUS_ZONE.x}, y = ${FOCUS_ZONE.y}, width = ${FOCUS_ZONE.width}, height = ${FOCUS_ZONE.height} }`);
