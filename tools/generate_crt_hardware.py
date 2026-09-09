"""Author native-resolution CRT approach sheets; no gameplay values are baked in."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'godot/assets/images/machine_polished'


def rect(x, y, w, h, color):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'


def sheet(name, count, draw):
    frames = ''.join(f'<g transform="translate({160*i} 0)">{draw(i)}</g>' for i in range(count))
    (OUT / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{160*count}" height="320" shape-rendering="crispEdges">{frames}</svg>\n')


sheet('dealer_bar.svg', 13, lambda frame: ''.join(
    rect(34+3*i, 94, 2, 4, '#aacb9b' if i < frame else '#284237') for i in range(12)))
for light in range(1, 4):
    sheet(f'dealer_bar_overlay_{light}.svg', 13-light,
          lambda frame, light=light: rect(34+3*min(11, frame+light-1), 94, 2, 4, '#ef6556'))
sheet('dealer_tips.svg', 1, lambda _: rect(34, 94, 2, 4, '#d2b978') + rect(37, 94, 2, 4, '#d2b978'))
sheet('augments.svg', 3, lambda frame: ''.join(rect(76+14*i, 90, 10, 9, '#254a48') for i in range(frame+1)))
GLYPHS = {'F': ['111','100','110','100','100'], 'R': ['110','101','110','101','101'],
          'E': ['111','100','110','100','111'], 'S': ['111','100','111','001','111'],
          'P': ['110','101','110','100','100'], 'I': ['111','010','010','010','111'],
          'N': ['101','111','111','111','101'], ' ': ['000']*5}
sheet('free_spin.svg', 1, lambda _: ''.join(rect(78+4*i+x, 49+y, 1, 1, '#e7e6b8')
      for i, char in enumerate('FREE SPIN') for y, row in enumerate(GLYPHS[char])
      for x, bit in enumerate(row) if bit == '1'))
