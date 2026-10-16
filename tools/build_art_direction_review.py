"""Assemble native-resolution comparisons from the real Godot framebuffer.

Run after debug_art_direction.gd before/after captures. This never renders game
art or upscales a layout-sized image. Pillow only arranges captured screenshots.
"""
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BEFORE = ROOT / "tmp/art-direction/before-motion"
AFTER = ROOT / "tmp/art-direction/after-final"
OUT = ROOT / "docs/art-direction"


def pair(label, filename):
    left = Image.open(BEFORE / f"{label}.png").convert("RGB")
    right = Image.open(AFTER / f"{label}.png").convert("RGB")
    assert left.size == right.size
    board = Image.new("RGB", (left.width * 2, left.height))
    board.paste(left, (0, 0))
    board.paste(right, (left.width, 0))
    board.save(OUT / filename, optimize=True)


def main():
    OUT.mkdir(exist_ok=True)
    for size in ("400x800", "540x960", "450x1000", "800x1000"):
        pair(f"idle-{size}", f"machine-before-after-{size}.png")
    for state in ("heat-x2", "heat-x3", "loss-x3", "targeting"):
        pair(state, f"machine-{state}.png")
    # Full-size motion frames at six points: motor travel, sequential stops,
    # settled reveal, heat and warning. No enlarged fake gameplay pixels.
    frames = [18, 36, 54, 90, 167, 221]
    board = Image.new("RGB", (2400, 830), "#111518")
    draw = ImageDraw.Draw(board)
    for column, frame in enumerate(frames):
        draw.text((column * 400 + 12, 8), f"Frame {frame} / 30 fps", fill="#e8dbc3")
        board.paste(Image.open(BEFORE / f"motion-{frame:04d}.png"), (column * 400, 30))
    board.save(OUT / "motion-sequence-before.png", optimize=True)
    shutil.copyfile(ROOT / "tmp/art-direction/families-board.png", OUT / "family-audit-overview.png")
    print("Native framebuffer comparisons written to docs/art-direction")


if __name__ == "__main__":
    main()
