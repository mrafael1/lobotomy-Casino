// ── Virtual game canvas ──────────────────────────────────────────────────────
// The whole phone game canvas is a 160×320 virtual space. Pixel-art elements are
// positioned in these virtual coordinates and scaled to the device by PixelScene
// (see src/components/PixelScene.tsx). The existing hand-authored scene art lives
// at 160×240; the extra vertical room (the taller 320 canvas) is used for top HUD
// and bottom controls.
//
// Runtime PNGs are nearest-neighbour upscales authored at ASSET_SCALE× the 1×
// source (compose-runtime-assets.js, V3_SCALE). The app displays them 1:1 at a
// FLAT INTEGER scale — never a fractional transform — because React Native
// resamples non-integer sizes and softens pixel art. So ASSET_SCALE is both the
// authored scale of the runtime art AND the on-screen scale: keep them equal.
//
// Children are positioned in asset-space via vpx() (= virtual × ASSET_SCALE) and
// drawn at their native pixel size, so every source pixel maps to ASSET_SCALE
// display pixels exactly. The machine ends up MACHINE_W·ASSET_SCALE = 96·4 = 384px.
//
// To change scale (e.g. ×4 → ×5 for larger screens): regenerate the runtime art
// at the new V3_SCALE AND bump ASSET_SCALE to match — the two must stay in lockstep.
export const VIRTUAL_WIDTH = 160;
export const VIRTUAL_HEIGHT = 320;
// The machine/scene art is authored at ×8 (1280×2560). PixelScene fit-scales the
// 160×320 canvas to the screen; with the display scale equal to the art scale,
// the ×8 art is downscaled to fit (supersampled → crisp).
export const ASSET_SCALE = 8;

// ── Vertical zones (machine-variant layout) ──────────────────────────────────
//   0–48    top HUD: win label + status badges
//  48–250   scene band: the slot machine
// 250–304   controls: stash tray + power chips
// 304–320   bottom safe margin / darkness
export const TOP_UI_Y = 0;
export const TOP_UI_HEIGHT = 48;
export const SCENE_Y = 48;
export const SCENE_HEIGHT = 202;
export const CONTROLS_Y = 250;
export const CONTROLS_HEIGHT = 54;
export const BOTTOM_SAFE_Y = 304;
export const BOTTOM_SAFE_HEIGHT = 16;

// ── Machine — the new-view sprite IS the full 160×320 scene (cabinet in the
// lower portion, empty space up top for the HUD), so it fills the whole canvas.
export const MACHINE_W = VIRTUAL_WIDTH;   // 160
export const MACHINE_H = VIRTUAL_HEIGHT;  // 320
export const MACHINE_X = 0;
export const MACHINE_Y = 0;

// Virtual px → asset-space px. Position PixelScene children with this.
export const vpx = (n: number) => n * ASSET_SCALE;
