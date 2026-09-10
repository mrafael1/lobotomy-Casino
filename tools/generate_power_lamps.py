"""Native lamp layers registered to the three existing reel housings."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'godot/assets/images/machine_polished'


def rect(x, y, w, h, color):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'


def sheet(name, count, draw):
    frames = ''.join(f'<g transform="translate({160*i} 0)">{draw(i)}</g>' for i in range(count))
    (OUT / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{160*count}" height="320" shape-rendering="crispEdges">{frames}</svg>\n')


def lamps(count):
    art = ''
    for i, x in enumerate((33, 65, 97)):
        lit = i < count
        art += rect(x-1, 156, 23, 7, '#333e30')
        art += rect(x, 157, 21, 4, '#eddfac' if lit else '#354435')
        art += rect(x+1, 157, 19, 1, '#fff0c7' if lit else '#67725a')
        art += rect(x, 161, 21, 1, '#ac985f' if lit else '#233025')
    return art


sheet('power_lamps.svg', 4, lamps)
# A fine rim on the final lamp reads the restore budget without a separate gauge.
sheet('restore_ready.svg', 2, lambda spent: rect(98, 162, 19, 1, '#486450' if not spent else '#493930'))
sheet('power_restore_flash.svg', 1, lambda _: ''.join(
    rect(x, 157, 21, 4, '#e5ffba') for x in (33, 65, 97)))
