const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const OUT_DIR = path.join(__dirname, '..', 'assets', 'images', 'machine_slot_layers');
const W = 200;
const H = 300;

const REEL_INNER_X = 25;
const REEL_INNER_Y = 82;
const REEL_INNER_W = 150;
const REEL_INNER_H = 100;
const REEL_COL_W = 50;

const NEON = {
  hotPink: [255, 45, 170, 255],
  cyan: [33, 247, 255, 255],
  jackpotGold: [255, 210, 58, 255],
  white: [255, 255, 255, 255],
  purple: [122, 44, 255, 255],
  bodyDark: [36, 18, 54, 255],
  bodyMid: [73, 31, 103, 255],
  bodyLight: [126, 56, 165, 255],
  shadow: [10, 8, 18, 255],
  metalDark: [62, 56, 78, 255],
  metalMid: [122, 118, 145, 255],
  metalLight: [214, 225, 245, 255],
  reelVoid: [6, 7, 16, 255],
  reelDeep: [12, 16, 35, 255],
  scratch: [236, 216, 255, 150],
  glassBlue: [114, 232, 255, 72],
  glassWhite: [255, 255, 255, 105],
};

const DECAY = {
  sickPink: [138, 71, 105, 255],
  sickCyan: [76, 140, 145, 255],
  tarnishedGold: [154, 132, 64, 255],
  deadWhite: [184, 177, 167, 255],
  bruisedPurple: [70, 51, 110, 255],
  grimeDark: [22, 25, 26, 255],
  grimeMid: [58, 62, 55, 255],
  grimeLight: [91, 98, 82, 255],
  rust: [104, 66, 38, 255],
  deadBulb: [45, 45, 42, 255],
  crack: [202, 232, 225, 150],
  glitchPink: [255, 42, 123, 255],
  glitchCyan: [52, 235, 216, 255],
  blackRot: [5, 7, 6, 210],
};

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

function rectOutline(img, x, y, w, h, color) {
  rect(img, x, y, w, 1, color);
  rect(img, x, y + h - 1, w, 1, color);
  rect(img, x, y, 1, h, color);
  rect(img, x + w - 1, y, 1, h, color);
}

function chunkyLine(img, x1, y1, x2, y2, color) {
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

function diamond(img, cx, cy, r, color) {
  for (let y = -r; y <= r; y++) {
    const span = r - Math.abs(y);
    rect(img, cx - span, cy + y, span * 2 + 1, 1, color);
  }
}

function bulb(img, cx, cy, main, hi) {
  rect(img, cx - 1, cy - 2, 3, 1, main);
  rect(img, cx - 2, cy - 1, 5, 3, main);
  rect(img, cx - 1, cy + 2, 3, 1, main);
  px(img, cx - 1, cy - 1, hi);
  px(img, cx, cy - 1, hi);
}

function deadBulb(img, cx, cy) {
  rect(img, cx - 1, cy - 2, 3, 1, DECAY.deadBulb);
  rect(img, cx - 2, cy - 1, 5, 3, DECAY.deadBulb);
  rect(img, cx - 1, cy + 2, 3, 1, DECAY.deadBulb);
  px(img, cx + 1, cy + 1, DECAY.blackRot);
}

function rivet(img, cx, cy) {
  rect(img, cx - 1, cy - 1, 3, 3, NEON.metalMid);
  px(img, cx - 1, cy - 1, NEON.metalLight);
  px(img, cx + 1, cy + 1, NEON.metalDark);
}

function saveLayer(name, draw) {
  const img = makeImage();
  draw(img);
  const out = path.join(OUT_DIR, `${name}.png`);
  fs.writeFileSync(out, PNG.sync.write(img));
  return out;
}

fs.mkdirSync(OUT_DIR, { recursive: true });

const layers = [
  ['Cabinet', (img) => {
    rect(img, 54, 14, 92, 10, NEON.bodyLight);
    rect(img, 42, 24, 116, 18, NEON.bodyMid);
    rect(img, 34, 42, 132, 184, NEON.bodyDark);
    rect(img, 28, 226, 144, 42, NEON.bodyMid);
    rect(img, 38, 268, 124, 16, NEON.bodyDark);
    rect(img, 34, 42, 8, 184, NEON.shadow);
    rect(img, 158, 42, 8, 184, NEON.shadow);
    rect(img, 42, 44, 6, 178, NEON.bodyLight);
    rect(img, 152, 44, 6, 178, NEON.bodyMid);
    rect(img, 28, 254, 144, 14, NEON.shadow);
    rect(img, 38, 276, 124, 8, NEON.shadow);
    rect(img, 48, 56, 104, 14, NEON.purple);
    rect(img, 52, 58, 96, 4, NEON.hotPink);
    rect(img, 44, 194, 112, 20, NEON.bodyMid);
    rect(img, 50, 199, 100, 6, NEON.purple);
    rect(img, 62, 51, 2, 2, NEON.shadow);
    rect(img, 139, 217, 3, 1, NEON.shadow);
    rect(img, 79, 238, 2, 3, NEON.shadow);
    rect(img, 121, 35, 2, 1, NEON.shadow);
  }],
  ['Trim', (img) => {
    rectOutline(img, 32, 40, 136, 188, NEON.metalLight);
    rectOutline(img, 33, 41, 134, 186, NEON.metalMid);
    rectOutline(img, 27, 225, 146, 44, NEON.metalMid);
    rectOutline(img, 38, 267, 124, 18, NEON.metalDark);
    rectOutline(img, 41, 23, 118, 20, NEON.metalLight);
    rect(img, 44, 26, 112, 3, NEON.metalMid);
    rect(img, 44, 38, 112, 2, NEON.metalDark);
    rectOutline(img, REEL_INNER_X - 6, REEL_INNER_Y - 6, REEL_INNER_W + 12, REEL_INNER_H + 12, NEON.metalLight);
    rectOutline(img, REEL_INNER_X - 5, REEL_INNER_Y - 5, REEL_INNER_W + 10, REEL_INNER_H + 10, NEON.metalMid);
    rectOutline(img, REEL_INNER_X - 2, REEL_INNER_Y - 2, REEL_INNER_W + 4, REEL_INNER_H + 4, NEON.metalDark);
    rect(img, REEL_INNER_X + 50, REEL_INNER_Y, 1, REEL_INNER_H, NEON.metalDark);
    rect(img, REEL_INNER_X + 51, REEL_INNER_Y, 1, REEL_INNER_H, NEON.metalLight);
    rect(img, REEL_INNER_X + 100, REEL_INNER_Y, 1, REEL_INNER_H, NEON.metalDark);
    rect(img, REEL_INNER_X + 101, REEL_INNER_Y, 1, REEL_INNER_H, NEON.metalLight);
    rectOutline(img, 51, 198, 98, 18, NEON.metalMid);
    rect(img, 54, 201, 92, 3, NEON.metalLight);
    rect(img, 54, 210, 92, 3, NEON.metalDark);
    [[42,50],[158,50],[42,220],[158,220],[30,238],[170,238],[46,278],[154,278],[24,77],[176,77],[24,186],[176,186],[31,76],[169,76],[31,188],[169,188]].forEach(([x, y]) => rivet(img, x, y));
    chunkyLine(img, 59, 30, 69, 29, NEON.scratch);
    chunkyLine(img, 142, 48, 136, 53, NEON.scratch);
    chunkyLine(img, 35, 132, 40, 132, NEON.scratch);
    chunkyLine(img, 151, 113, 157, 116, NEON.scratch);
    chunkyLine(img, 72, 221, 83, 219, NEON.scratch);
    chunkyLine(img, 122, 257, 135, 255, NEON.scratch);
  }],
  ['ReelWindow', (img) => {
    rect(img, REEL_INNER_X, REEL_INNER_Y, REEL_INNER_W, REEL_INNER_H, NEON.reelVoid);
    rect(img, REEL_INNER_X, REEL_INNER_Y, REEL_INNER_W, 4, NEON.shadow);
    rect(img, REEL_INNER_X, REEL_INNER_Y, 4, REEL_INNER_H, NEON.shadow);
    rect(img, REEL_INNER_X + REEL_INNER_W - 4, REEL_INNER_Y, 4, REEL_INNER_H, NEON.reelDeep);
    rect(img, REEL_INNER_X, REEL_INNER_Y + REEL_INNER_H - 4, REEL_INNER_W, 4, NEON.reelDeep);
    rect(img, REEL_INNER_X + 50, REEL_INNER_Y, 1, REEL_INNER_H, NEON.reelDeep);
    rect(img, REEL_INNER_X + 100, REEL_INNER_Y, 1, REEL_INNER_H, NEON.reelDeep);
  }],
  ['Glass', (img) => {
    chunkyLine(img, 33, 87, 91, 82, NEON.glassWhite);
    chunkyLine(img, 35, 88, 93, 83, NEON.glassBlue);
    chunkyLine(img, 42, 96, 82, 92, NEON.glassWhite);
    chunkyLine(img, 125, 171, 166, 164, NEON.glassBlue);
    chunkyLine(img, 130, 175, 159, 170, NEON.glassWhite);
    rect(img, 46, 84, 3, 1, NEON.glassWhite);
    rect(img, 150, 91, 5, 1, NEON.glassBlue);
    rect(img, 92, 178, 4, 1, NEON.glassWhite);
  }],
  ['Neon_Trim', (img) => {
    rectOutline(img, 29, 37, 142, 194, NEON.hotPink);
    rectOutline(img, 31, 39, 138, 190, NEON.cyan);
    rectOutline(img, REEL_INNER_X - 8, REEL_INNER_Y - 8, REEL_INNER_W + 16, REEL_INNER_H + 16, NEON.hotPink);
    rectOutline(img, REEL_INNER_X - 9, REEL_INNER_Y - 9, REEL_INNER_W + 18, REEL_INNER_H + 18, NEON.cyan);
    rect(img, 48, 20, 104, 1, NEON.hotPink);
    rect(img, 50, 21, 100, 1, NEON.cyan);
    rect(img, 51, 63, 98, 1, NEON.jackpotGold);
    rect(img, 42, 271, 116, 1, NEON.cyan);
    rect(img, 45, 272, 110, 1, NEON.hotPink);
    diamond(img, 35, 58, 3, NEON.cyan);
    diamond(img, 165, 58, 3, NEON.hotPink);
    diamond(img, 35, 211, 3, NEON.hotPink);
    diamond(img, 165, 211, 3, NEON.cyan);
  }],
  ['Lights_Bright', (img) => {
    [54, 68, 82, 96, 110, 124, 138, 152].forEach((x, i) => bulb(img, x, 34, i % 2 ? NEON.cyan : NEON.hotPink, NEON.white));
    [68, 92, 116, 140, 164, 188, 212].forEach((y, i) => {
      bulb(img, 20, y, i % 2 ? NEON.hotPink : NEON.jackpotGold, NEON.white);
      bulb(img, 180, y, i % 2 ? NEON.cyan : NEON.hotPink, NEON.white);
    });
    [58, 76, 94, 112, 130, 148].forEach((x) => bulb(img, x, 245, NEON.jackpotGold, NEON.white));
  }],
  ['Jackpot_Flash', (img) => {
    rectOutline(img, REEL_INNER_X - 13, REEL_INNER_Y - 13, REEL_INNER_W + 26, REEL_INNER_H + 26, NEON.white);
    rectOutline(img, REEL_INNER_X - 12, REEL_INNER_Y - 12, REEL_INNER_W + 24, REEL_INNER_H + 24, NEON.jackpotGold);
    rectOutline(img, REEL_INNER_X - 10, REEL_INNER_Y - 10, REEL_INNER_W + 20, REEL_INNER_H + 20, NEON.white);
    rectOutline(img, REEL_INNER_X - 7, REEL_INNER_Y - 7, REEL_INNER_W + 14, REEL_INNER_H + 14, NEON.jackpotGold);
    chunkyLine(img, 100, 66, 100, 47, NEON.white);
    chunkyLine(img, 100, 198, 100, 221, NEON.jackpotGold);
    chunkyLine(img, 13, 132, 5, 132, NEON.white);
    chunkyLine(img, 187, 132, 195, 132, NEON.jackpotGold);
    chunkyLine(img, 36, 76, 19, 61, NEON.jackpotGold);
    chunkyLine(img, 164, 76, 181, 61, NEON.white);
    chunkyLine(img, 36, 190, 18, 207, NEON.white);
    chunkyLine(img, 164, 190, 183, 207, NEON.jackpotGold);
    rect(img, 15, 50, 8, 8, NEON.white);
    rect(img, 177, 50, 8, 8, NEON.jackpotGold);
    rect(img, 15, 207, 8, 8, NEON.jackpotGold);
    rect(img, 177, 207, 8, 8, NEON.white);
  }],
  ['Cabinet_Sickly', (img) => {
    rect(img, 54, 14, 92, 10, DECAY.grimeLight);
    rect(img, 42, 24, 116, 18, DECAY.bruisedPurple);
    rect(img, 34, 42, 132, 184, DECAY.grimeDark);
    rect(img, 28, 226, 144, 42, DECAY.grimeMid);
    rect(img, 38, 268, 124, 16, DECAY.grimeDark);
    rect(img, 42, 48, 5, 160, DECAY.blackRot);
    rect(img, 153, 70, 6, 145, DECAY.blackRot);
    rect(img, 61, 197, 12, 28, DECAY.rust);
    rect(img, 128, 221, 17, 36, DECAY.rust);
    rect(img, 48, 56, 104, 14, DECAY.bruisedPurple);
    rect(img, 52, 58, 96, 4, DECAY.sickPink);
    rect(img, 44, 194, 112, 20, DECAY.grimeMid);
    rect(img, 50, 199, 100, 6, DECAY.sickCyan);
    [[51,75],[63,79],[151,84],[146,103],[38,143],[159,151],[53,184],[144,188],[73,235],[92,229],[135,242],[116,263]].forEach(([x, y]) => rect(img, x, y, 2, 2, DECAY.blackRot));
  }],
  ['Glitch', (img) => {
    rect(img, 28, 37, 18, 2, DECAY.glitchPink);
    rect(img, 47, 40, 9, 2, DECAY.glitchCyan);
    rect(img, 149, 38, 21, 2, DECAY.glitchPink);
    rect(img, 164, 121, 7, 3, DECAY.glitchCyan);
    rect(img, 28, 171, 12, 2, DECAY.glitchPink);
    rect(img, 154, 229, 18, 3, DECAY.glitchCyan);
    rect(img, REEL_INNER_X - 11, REEL_INNER_Y - 10, 24, 3, DECAY.glitchPink);
    rect(img, REEL_INNER_X + 118, REEL_INNER_Y - 8, 39, 2, DECAY.glitchCyan);
    rect(img, REEL_INNER_X - 9, REEL_INNER_Y + 103, 33, 3, DECAY.glitchCyan);
    rect(img, REEL_INNER_X + 101, REEL_INNER_Y + 107, 58, 2, DECAY.glitchPink);
    rect(img, REEL_INNER_X + 49, REEL_INNER_Y + 17, 4, 13, DECAY.blackRot);
    rect(img, REEL_INNER_X + 98, REEL_INNER_Y + 56, 5, 19, DECAY.blackRot);
    rect(img, REEL_INNER_X + 52, REEL_INNER_Y + 62, 5, 5, DECAY.glitchCyan);
    rect(img, REEL_INNER_X + 96, REEL_INNER_Y + 28, 6, 4, DECAY.glitchPink);
  }],
  ['Flicker_Dead', (img) => {
    [[68,34],[110,34],[152,34],[20,92],[20,164],[180,116],[180,212],[76,245],[112,245],[148,245]].forEach(([x, y]) => deadBulb(img, x, y));
    bulb(img, 54, 34, DECAY.sickPink, DECAY.deadWhite);
    bulb(img, 124, 34, DECAY.sickCyan, DECAY.deadWhite);
    bulb(img, 94, 245, DECAY.tarnishedGold, DECAY.deadWhite);
  }],
  ['Crack', (img) => {
    chunkyLine(img, 62, 91, 74, 111, DECAY.crack);
    chunkyLine(img, 74, 111, 68, 127, DECAY.crack);
    chunkyLine(img, 73, 109, 86, 116, DECAY.crack);
    chunkyLine(img, 123, 101, 114, 126, DECAY.crack);
    chunkyLine(img, 114, 126, 132, 146, DECAY.crack);
    chunkyLine(img, 116, 124, 104, 132, DECAY.crack);
    chunkyLine(img, 151, 153, 161, 172, DECAY.crack);
    rect(img, 80, 116, 2, 1, DECAY.deadWhite);
    rect(img, 112, 129, 1, 2, DECAY.deadWhite);
    rect(img, 134, 147, 2, 1, DECAY.deadWhite);
  }],
];

const written = layers.map(([name, draw]) => ({ name, file: saveLayer(name, draw) }));
fs.writeFileSync(path.join(OUT_DIR, 'manifest.json'), JSON.stringify({
  width: W,
  height: H,
  layers: written,
  reel: {
    inner: { x: REEL_INNER_X, y: REEL_INNER_Y, width: REEL_INNER_W, height: REEL_INNER_H },
    columns: [
      { x: REEL_INNER_X, y: REEL_INNER_Y, width: REEL_COL_W, height: REEL_INNER_H },
      { x: REEL_INNER_X + REEL_COL_W, y: REEL_INNER_Y, width: REEL_COL_W, height: REEL_INNER_H },
      { x: REEL_INNER_X + REEL_COL_W * 2, y: REEL_INNER_Y, width: REEL_COL_W, height: REEL_INNER_H },
    ],
  },
}, null, 2));

console.log('Generated machine_slot layer PNGs:');
for (const layer of written) console.log(`${layer.name}: ${layer.file}`);
console.log(`INNER_REEL_AREA = { x = ${REEL_INNER_X}, y = ${REEL_INNER_Y}, width = ${REEL_INNER_W}, height = ${REEL_INNER_H} }`);
console.log(`REEL_COLUMN_1 = { x = ${REEL_INNER_X}, y = ${REEL_INNER_Y}, width = ${REEL_COL_W}, height = ${REEL_INNER_H} }`);
console.log(`REEL_COLUMN_2 = { x = ${REEL_INNER_X + REEL_COL_W}, y = ${REEL_INNER_Y}, width = ${REEL_COL_W}, height = ${REEL_INNER_H} }`);
console.log(`REEL_COLUMN_3 = { x = ${REEL_INNER_X + REEL_COL_W * 2}, y = ${REEL_INNER_Y}, width = ${REEL_COL_W}, height = ${REEL_INNER_H} }`);
