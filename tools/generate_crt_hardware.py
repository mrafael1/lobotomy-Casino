"""Author native-resolution CRT approach sheets; no gameplay values are baked in."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'godot/assets/images/machine_polished'


def rect(x, y, w, h, color):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'


def sheet(name, count, draw):
    frames = ''.join(f'<g transform="translate({160*i} 0)">{draw(i)}</g>' for i in range(count))
    (OUT / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{160*count}" height="320" shape-rendering="crispEdges">{frames}</svg>\n')


sheet('dealer_bar.svg', 13, lambda frame: ''.join(
    rect(36+3*i, 95, 2, 4, '#aacb9b' if i < frame else '#284237') for i in range(12)))
for light in range(1, 4):
    sheet(f'dealer_bar_overlay_{light}.svg', 13-light,
          lambda frame, light=light: rect(36+3*min(11, frame+light-1), 95, 2, 4, '#ef6556'))
sheet('dealer_tips.svg', 1, lambda _: rect(36, 95, 2, 4, '#d2b978') + rect(39, 95, 2, 4, '#d2b978'))
sheet('augments.svg', 3, lambda frame: ''.join(
    f'<g transform="translate({48+26*i} 260)"><path d="M1 1L20 0L21 18L18 21L0 20Z" fill="#502b27"/>'
    '<path d="M0 1L18 0L20 17L17 20L1 19Z" fill="#ae9c75"/>'
    '<path d="M1 2L17 1L19 17L16 19L2 18Z" fill="#c8b68c"/>'
    '<path d="M1 5h2v1H1zM14 1h2v1h-2zM3 17h3v1H3z" fill="#8e7a57"/></g>'
    for i in range(frame+1)))
GLYPHS = {'F': ['111','100','110','100','100'], 'R': ['110','101','110','101','101'],
          'E': ['111','100','110','100','111'], 'S': ['111','100','111','001','111'],
          'P': ['110','101','110','100','100'], 'I': ['111','010','010','010','111'],
          'N': ['101','111','111','111','101'], ' ': ['000']*5}
GLYPHS.update({
    'C': ['111','100','100','100','111'], 'O': ['111','101','101','101','111'],
    'M': ['101','111','111','101','101'], 'B': ['110','101','110','101','110'],
    'X': ['101','101','010','101','101'], '1': ['010','110','010','010','111'],
    '2': ['111','001','111','100','111'], '3': ['111','001','111','001','111'],
    '4': ['101','101','111','001','001'], '5': ['111','100','111','001','111'],
    '6': ['111','100','111','101','111'], '7': ['111','001','010','010','010'],
    '8': ['111','101','111','101','111'], '9': ['111','101','111','001','111'],
})


def lettering(text, left, top, color, scale=1):
    return ''.join(rect(left+scale*(4*i+x), top+scale*y, scale, scale, color)
                   for i, char in enumerate(text) for y, row in enumerate(GLYPHS[char])
                   for x, bit in enumerate(row) if bit == '1')


sheet('combo.svg', 9, lambda frame:
      rect(72, 60, 50, 36, '#081712') + rect(73, 60, 48, 1, '#536e58')
      + lettering('COMBO', 76, 64, '#bac9a2')
      + lettering('X'+str(frame+1), 103, 62, '#e8dfad', 2)
      + rect(76, 73, 42, 1, '#284237'))
sheet('free_spin.svg', 1, lambda _: ''.join(rect(78+4*i+x, 49+y, 1, 1, '#e7e6b8')
      for i, char in enumerate('FREE SPIN') for y, row in enumerate(GLYPHS[char])
      for x, bit in enumerate(row) if bit == '1'))
