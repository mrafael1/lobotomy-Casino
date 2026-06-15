const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const ROOT = path.join(__dirname, '..');

function readPng(file) {
  return PNG.sync.read(fs.readFileSync(file));
}

function writePng(file, png) {
  fs.writeFileSync(file, PNG.sync.write(png));
}

function makePng(width, height) {
  const png = new PNG({ width, height });
  png.data.fill(0);
  return png;
}

function alphaOver(dst, src) {
  if (dst.width !== src.width || dst.height !== src.height) {
    throw new Error(`Mismatched PNG sizes: ${dst.width}x${dst.height} vs ${src.width}x${src.height}`);
  }

  for (let i = 0; i < dst.data.length; i += 4) {
    const sa = src.data[i + 3] / 255;
    if (sa <= 0) continue;

    const da = dst.data[i + 3] / 255;
    const outA = sa + da * (1 - sa);
    if (outA <= 0) continue;

    dst.data[i] = Math.round((src.data[i] * sa + dst.data[i] * da * (1 - sa)) / outA);
    dst.data[i + 1] = Math.round((src.data[i + 1] * sa + dst.data[i + 1] * da * (1 - sa)) / outA);
    dst.data[i + 2] = Math.round((src.data[i + 2] * sa + dst.data[i + 2] * da * (1 - sa)) / outA);
    dst.data[i + 3] = Math.round(outA * 255);
  }
}

function composite(layerDir, width, height, layerNames) {
  const out = makePng(width, height);
  for (const layerName of layerNames) {
    alphaOver(out, readPng(path.join(layerDir, `${layerName}.png`)));
  }
  return out;
}

function upscaleNearest(src, scale) {
  const out = makePng(src.width * scale, src.height * scale);
  for (let y = 0; y < out.height; y++) {
    for (let x = 0; x < out.width; x++) {
      const sx = Math.floor(x / scale);
      const sy = Math.floor(y / scale);
      const si = (sy * src.width + sx) * 4;
      const di = (y * out.width + x) * 4;
      out.data[di] = src.data[si];
      out.data[di + 1] = src.data[si + 1];
      out.data[di + 2] = src.data[si + 2];
      out.data[di + 3] = src.data[si + 3];
    }
  }
  return out;
}

function composeMachine() {
  const layerDir = path.join(ROOT, 'assets', 'images', 'machine_slot_layers');
  const healthy = composite(layerDir, 200, 300, [
    'Cabinet',
    'ReelWindow',
    'Trim',
    'Glass',
    'Neon_Trim',
    'Lights_Bright',
  ]);

  const decay = composite(layerDir, 200, 300, [
    'Cabinet',
    'ReelWindow',
    'Trim',
    'Glass',
    'Neon_Trim',
    'Lights_Bright',
    'Cabinet_Sickly',
    'Glitch',
    'Flicker_Dead',
    'Crack',
  ]);

  const jackpot = composite(layerDir, 200, 300, ['Jackpot_Flash']);

  writePng(path.join(ROOT, 'assets', 'images', 'machine_normal.png'), upscaleNearest(healthy, 3));
  writePng(path.join(ROOT, 'assets', 'images', 'machine_decay.png'), upscaleNearest(decay, 3));
  writePng(path.join(ROOT, 'assets', 'images', 'machine_jackpot.png'), upscaleNearest(jackpot, 3));
}

// Crop a (sx,sy,w,h) region from src into a new PNG.
function crop(src, sx, sy, w, h) {
  const out = makePng(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = ((sy + y) * src.width + (sx + x)) * 4;
      const di = (y * w + x) * 4;
      out.data[di] = src.data[si];
      out.data[di + 1] = src.data[si + 1];
      out.data[di + 2] = src.data[si + 2];
      out.data[di + 3] = src.data[si + 3];
    }
  }
  return out;
}

// Multiplier buttons: one transparent 200x300 overlay per bet state, swapped
// at runtime by betMultiplier. Just upscale each to the runtime resolution.
function composeMultiplier() {
  const layerDir = path.join(ROOT, 'assets', 'images', 'machine_slot_layers');
  for (const n of [1, 2, 3]) {
    const layer = readPng(path.join(layerDir, `Multiplier_Top_X${n}.png`));
    writePng(
      path.join(ROOT, 'assets', 'images', `machine_multiplier_x${n}.png`),
      upscaleNearest(layer, 3),
    );
  }
}

// Individual machine layers — each baked composite layer also emitted as its
// own 3x upscaled runtime PNG into machine_layers/. The current renderer uses
// the flat machine_normal/decay composites; these granular layers are raw
// material for phase-3 per-layer effects (independent flicker, glitch jitter,
// staged cracks) without re-running the source art. No runtime cost until used.
function composeLayers() {
  const layerDir = path.join(ROOT, 'assets', 'images', 'machine_slot_layers');
  const outDir = path.join(ROOT, 'assets', 'images', 'machine_layers');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const layers = [
    'Cabinet', 'ReelWindow', 'Trim', 'Glass',
    'Neon_Trim', 'Lights_Bright', 'Jackpot_Flash',
    'Cabinet_Sickly', 'Glitch', 'Flicker_Dead', 'Crack',
  ];
  for (const name of layers) {
    const src = path.join(layerDir, `${name}.png`);
    if (!fs.existsSync(src)) continue;
    writePng(path.join(outDir, `${name}.png`), upscaleNearest(readPng(src), 3));
  }
}

// Dealer shop scene background — a manually authored 320×480 PNG from Aseprite.
// 2× upscale to 640×960 for pixel-crisp display. When the source doesn't exist
// yet (artist hasn't run the Lua script), skip silently to keep the pipeline runnable.
function composeDealerShop() {
  const src = path.join(ROOT, 'assets', 'images', 'dealer_shop_bg.png');
  if (!fs.existsSync(src)) {
    console.log('(skipping dealer_shop_bg.png — source not found)');
    return;
  }
  // The source is already the "correct" size; just 2× upscale for crispness.
  writePng(src, upscaleNearest(readPng(src), 1)); // identity — file already runtime-ready
  console.log('assets/images/dealer_shop_bg.png 320x480');
}

// Shift all non-transparent pixels in src down by dy pixels (in-place-safe, returns new PNG).
function shiftDown(src, dy) {
  const out = makePng(src.width, src.height);
  for (let y = 0; y < src.height; y++) {
    for (let x = 0; x < src.width; x++) {
      const si = (y * src.width + x) * 4;
      if (src.data[si + 3] === 0) continue;
      const ny = y + dy;
      if (ny < 0 || ny >= src.height) continue;
      const di = (ny * src.width + x) * 4;
      out.data[di]     = src.data[si];
      out.data[di + 1] = src.data[si + 1];
      out.data[di + 2] = src.data[si + 2];
      out.data[di + 3] = src.data[si + 3];
    }
  }
  return out;
}

// Lever: lever_frames.png is a 600x300 sheet of three 200x300 frames
// (idle / mid / pulled). Split, shift down to cash-tray area, and upscale.
// Source art has lever at y≈110-154; +110 moves it to y≈220-264 (payout slot).
function composeLever() {
  const layerDir = path.join(ROOT, 'assets', 'images', 'machine_slot_layers');
  const sheet = readPng(path.join(layerDir, 'lever_frames.png'));
  for (let f = 0; f < 3; f++) {
    const frame = crop(sheet, f * 200, 0, 200, 300);
    writePng(
      path.join(ROOT, 'assets', 'images', `machine_lever_${f + 1}.png`),
      upscaleNearest(shiftDown(frame, 110), 3),
    );
  }
}

function composeBackground() {
  const layerDir = path.join(ROOT, 'assets', 'images', 'lobotomy_background_layers');
  const healthy = composite(layerDir, 320, 480, [
    'BG_Neon',
    'Glow_Pink',
    'Glow_Cyan',
    'Lights_Bright',
    'Sheen',
  ]);

  const decay = composite(layerDir, 320, 480, [
    'BG_Sickly',
    'Glitch',
    'BrainImagery',
    'Vignette_Dark',
  ]);

  writePng(path.join(ROOT, 'assets', 'images', 'background_healthy.png'), upscaleNearest(healthy, 2));
  writePng(path.join(ROOT, 'assets', 'images', 'background_decay.png'), upscaleNearest(decay, 2));
}

// UI sprites — power icon chips, stash tray, consumable placeholder, dealer art.
// Sources live wherever the artist saved them; each is nearest-neighbor
// upscaled into assets/images/ui/ so it stays crisp when scaled in the app.
// Silently skips any source not yet created so the pipeline stays runnable.
function composeUI() {
  const outDir = path.join(ROOT, 'assets', 'images', 'ui');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const items = [
    { src: 'powers/power_reroll.png',          name: 'power_reroll',           scale: 3 },
    { src: 'powers/power_shift.png',           name: 'power_shift',            scale: 3 },
    { src: 'powers/power_memory.png',          name: 'power_memory',           scale: 3 },
    { src: 'stash_tray.png',                   name: 'stash_tray',             scale: 3 },
    { src: 'items/consumable_placeholder.png', name: 'consumable_placeholder', scale: 3 },
    { src: 'dealer_portrait.png',              name: 'dealer_portrait',        scale: 3 },
    { src: 'dealer_hands.png',                 name: 'dealer_hands',           scale: 3 },
  ];
  for (const it of items) {
    const src = path.join(ROOT, 'assets', 'images', it.src);
    if (!fs.existsSync(src)) continue;
    writePng(path.join(outDir, `${it.name}.png`), upscaleNearest(readPng(src), it.scale));
    console.log(`assets/images/ui/${it.name}.png`);
  }
}

composeMachine();
composeLayers();
composeMultiplier();
composeLever();
composeBackground();
composeUI();
composeDealerShop();

console.log('Composited runtime assets:');
console.log('assets/images/machine_normal.png 600x900');
console.log('assets/images/machine_decay.png 600x900');
console.log('assets/images/machine_jackpot.png 600x900 transparent overlay');
console.log('assets/images/machine_layers/*.png 600x900 individual layers (phase-3 effects)');
console.log('assets/images/machine_multiplier_x1..3.png 600x900 transparent overlay');
console.log('assets/images/machine_lever_1..3.png 600x900 transparent overlay');
console.log('assets/images/background_healthy.png 640x960');
console.log('assets/images/background_decay.png 640x960');
