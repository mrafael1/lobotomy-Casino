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

composeMachine();
composeBackground();

console.log('Composited runtime assets:');
console.log('assets/images/machine_normal.png 600x900');
console.log('assets/images/machine_decay.png 600x900');
console.log('assets/images/machine_jackpot.png 600x900 transparent overlay');
console.log('assets/images/background_healthy.png 640x960');
console.log('assets/images/background_decay.png 640x960');
