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
// intermediate-render pixels exactly. The machine fills the full canvas
// (MACHINE_W·ASSET_SCALE = 160·8 = 1280px), which PixelScene fit-scales to device.
//
// To change scale: regenerate the runtime art at the new V3_SCALE AND bump
// ASSET_SCALE to match — the two must stay in lockstep.
export const VIRTUAL_WIDTH = 160;
export const VIRTUAL_HEIGHT = 320;
// The machine/scene art is authored at ×8 (1280×2560). PixelScene fit-scales the
// 160×320 canvas to the screen; with the display scale equal to the art scale,
// the ×8 art is downscaled to fit (supersampled → crisp).
export const ASSET_SCALE = 8;

// ── One full-canvas composition (no reserved UI bands) ───────────────────────
// The 160×320 canvas is treated as a single pixel-art composition, NOT split into
// fixed top/middle/bottom UI bands. The machine art is the whole canvas (cabinet
// in the lower portion, empty space above); HUD chrome — win label, status
// badges, stash tray and power chips — composes into that empty upper region so
// nothing floats in screen-space letterbox margins. Only full-screen overlays
// (dealer / gift / run-over) remain outside the PixelScene.

// ── Machine — the sprite IS the full 160×320 scene, so it fills the whole canvas.
export const MACHINE_W = VIRTUAL_WIDTH;   // 160
export const MACHINE_H = VIRTUAL_HEIGHT;  // 320
export const MACHINE_X = 0;
export const MACHINE_Y = 0;

// ── HUD region — the empty space above the cabinet (the cabinet's TV starts at
// virtual y≈128). HUD elements are positioned within this band, in the scene.
export const HUD_HEIGHT = 124;

// Virtual px → asset-space px. Position PixelScene children with this.
export const vpx = (n: number) => n * ASSET_SCALE;
