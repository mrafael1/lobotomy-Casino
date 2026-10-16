"""Transfer only quiet material planes into the registered machine painting.

The generated study is an editable paint source, never a runtime replacement.
All geometry, apertures, background, CRT, sockets, fasteners and control wells
come from the archived working-tree baseline. Coordinates are machine-local
layout units; both source images are sampled at 8 source pixels per unit.

Rebuild: py tools/refine_machine_materials.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/art_sources"
OUTPUT = ROOT / "godot/assets/images/machine_polished/cabinet_material_pass.png"
SCALE = 8
SIZE = (160 * SCALE, 320 * SCALE)


def polygon(draw, points, fill=255):
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=fill)


def box(draw, bounds, fill=0):
    draw.rectangle(tuple(round(v * SCALE) for v in bounds), fill=fill)


def disc(draw, x, y, radius, fill=0):
    draw.ellipse(tuple(round(v * SCALE) for v in
                       (x - radius, y - radius, x + radius, y + radius)), fill=fill)


def material_mask():
    mask = Image.new("L", SIZE)
    draw = ImageDraw.Draw(mask)
    # Satin steel face. Original return edges and bores retain their registration.
    polygon(draw, [(23, 115.5), (134, 115.5), (134, 137.7), (23, 137.7)])
    for x in (46, 77, 108):
        disc(draw, x, 126.5, 12.4)
    for x in (29.2, 58.5, 95.3, 127):
        for y in (118, 135.5):
            disc(draw, x, y, 1.8)
    # Steel control shelf: preserve the four actual wells, their lips and screws.
    polygon(draw, [(16, 211), (134.8, 211), (138, 232), (13, 232)])
    for bounds in [(19, 211.5, 54, 230), (55, 211, 94, 231),
                   (97, 211.5, 114, 230.5), (115.5, 211.5, 132.5, 230.5)]:
        box(draw, bounds)
    for x, y in [(18, 212), (15.5, 230.5), (136, 231), (133, 212)]:
        disc(draw, x, y, 2)
    # Broad enamel planes, bounded inside original seams and folded returns.
    polygon(draw, [(17.5, 250), (134.8, 250), (134.8, 286.7), (17.5, 286.7)])
    polygon(draw, [(15, 234.5), (137, 234.5), (137, 247.7), (15, 247.7)])
    box(draw, (119.5, 238, 132, 245))  # original service recess
    for x in (17, 134.5):
        for y in (237, 244.5):
            disc(draw, x, y, 1.9)
    polygon(draw, [(29, 141), (122, 141), (122, 149.5), (29, 149.5)])
    for x in (30.7, 121):
        disc(draw, x, 146, 2)
    # Keep the backing and every reel/lamp aperture completely intact.
    # Lower plinth enamel flanking the existing cash outlet.
    polygon(draw, [(21, 301), (43, 301), (43, 319), (21, 319)])
    polygon(draw, [(110, 301), (134, 301), (134, 319), (110, 319)])
    for x in (31.8, 123):
        disc(draw, x, 316, 2)
    # Subpixel feathering occurs inward only; no paint crosses a protected edge.
    feather = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32)
    hard = np.asarray(mask, dtype=np.float32) / 255.0
    return feather / 255.0 * hard


def main():
    baseline = Image.open(SOURCES / "machine-direction-baseline.png").convert("RGBA")
    assert baseline.size == SIZE, "Remeasure the masks if the registered export changes"
    study = Image.open(SOURCES / "machine-material-study.png").convert("RGB")
    study = study.resize(SIZE, Image.Resampling.LANCZOS)
    original = np.asarray(baseline).copy()
    painted = np.asarray(study, dtype=np.float32)
    mask = material_mask()[..., None]
    result = original.copy()
    result[..., :3] = np.rint(original[..., :3] * (1 - mask) + painted * mask).astype(np.uint8)
    # The original alpha is authoritative, including all three exact reel holes.
    assert np.array_equal(original[..., 3], result[..., 3])
    assert np.array_equal(original[mask[..., 0] == 0], result[mask[..., 0] == 0])
    Image.fromarray(result).save(OUTPUT, optimize=True)
    Image.fromarray(np.rint(mask[..., 0] * 255).astype(np.uint8)).save(
        ROOT / "docs/art-direction/material-transfer-mask.png", optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)}; alpha and all unmasked pixels unchanged")


if __name__ == "__main__":
    main()
