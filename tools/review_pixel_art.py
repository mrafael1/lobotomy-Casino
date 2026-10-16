"""Build review boards from real window captures, without resizing gameplay shots.

Image reads here assemble documentation only. The asset generator never reads art.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def pair(before, after, output, label):
    before, after = Image.open(before).convert('RGB'), Image.open(after).convert('RGB')
    assert before.size == after.size
    w, h = before.size
    board = Image.new('RGB', (w * 2, h + 32), '#11151e')
    draw = ImageDraw.Draw(board)
    draw.text((12, 10), 'BEFORE / ' + label, fill='#e1d4a4')
    draw.text((w + 12, 10), 'AFTER / CODE-GENERATED PIXELS', fill='#73e6cb')
    board.paste(before, (0, 32))
    board.paste(after, (w, 32))
    board.save(output, optimize=True)


def animation_board(output):
    from pixel_art import legacy, machine
    from pixel_art.core import icon, P

    board = Image.new('RGB', (800, 600), '#11151e')
    draw = ImageDraw.Draw(board)
    rows = [
        ('PATTERN / FIVE FRAMES', [icon('pattern_recognition', 24, k) for k in range(5)]),
        ('NEURON SIGNAL / SAMPLED FROM 34 FRAMES', [legacy.neurons(k).image for k in range(0, 34, 4)]),
        ('NEURON DEATH / THREE SEPARATE OVERLAYS', [legacy.neurons(loss=k // 3, death_frame=k % 3).image for k in range(9)]),
        ('POWER / READY, SELECTED, SPENT', [machine.power('memory', k).image.crop((96, 114, 121, 140)) for k in range(3)]),
        ('SPIN / NORMAL, PRESSED, DISABLED, LATCHED', [machine.spin(k).image for k in ('normal', 'pressed', 'disabled', 'latched')]),
    ]
    for row, (title, frames) in enumerate(rows):
        y = 12 + row * 103
        draw.text((12, y), title, fill='#e1d4a4')
        for k, frame in enumerate(frames):
            # Source-grid inspection uses exact integer magnification.
            scale = 1 if frame.width > 50 else 2
            frame = frame.resize((frame.width * scale, frame.height * scale), Image.Resampling.NEAREST)
            board.paste(frame, (12 + k * 83, y + 23), frame)
    draw.text((12, 540), 'SHARED MATERIAL RAMPS', fill='#e1d4a4')
    for k, value in enumerate(P.values()):
        x = 12 + (k % 38) * 20
        y = 560 + (k // 38) * 20
        draw.rectangle((x, y, x + 18, y + 17), fill='#' + value)
    board.save(output, optimize=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--before', type=Path, required=True, help='Original debug_art_direction capture directory')
    parser.add_argument('--after', type=Path, required=True, help='Generated debug_art_direction capture directory')
    parser.add_argument('--before-scenes', type=Path)
    parser.add_argument('--after-scenes', type=Path)
    parser.add_argument('--out', type=Path, default=ROOT / 'docs/pixel-art')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for size in ('400x800', '540x960', '450x1000', '800x1000'):
        pair(args.before / f'idle-{size}.png', args.after / f'idle-{size}.png',
             args.out / f'machine-{size}.png', f'{size} ACTUAL WINDOW')
    if args.before_scenes and args.after_scenes:
        for scene in ('pacte_scene', 'dealer_choice_scene', 'settings_scene', 'collection_scene', 'upgrades_scene'):
            pair(args.before_scenes / f'{scene}-400x800.png', args.after_scenes / f'en-{scene}.png',
                 args.out / f'{scene}.png', '400x800 ACTUAL WINDOW')
    animation_board(args.out / 'animation-and-palette.png')
    print('Review boards saved to', args.out)


if __name__ == '__main__':
    main()
