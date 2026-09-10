"""Native SPIN faces: shared pixel lettering and a two-pixel depression."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'godot/assets/images/machine_polished'
GLYPHS = [(3, '111100111001111'), (3, '110101110100100'), (3, '111010010010111'), (4, '10011101101110011001')]
for state in ['normal', 'pressed', 'disabled', 'hover', 'focus']:
    disabled = state == 'disabled'
    depression = 2 if state == 'pressed' else 0
    face = '#969383' if disabled else '#eed9a1'
    ink = '#535648' if disabled else '#252b23'
    rim = '#b4b391' if state in ['hover', 'focus'] else '#777060'
    art = f'<path d="M5 2H41L44 6V24H2V6Z" fill="#222620"/><path d="M6 3H40L43 6V23H3V6Z" fill="{rim}"/>'
    art += '<path d="M7 5H39L41 8V21H5V8Z" fill="#362e21"/>'
    art += f'<g transform="translate(0 {depression})"><path d="M8 4H38L40 7V18H6V7Z" fill="#947744"/>'
    art += f'<path d="M9 5H37L39 7V16H7V7Z" fill="{face}"/>'
    art += '<path d="M10 5H36V6H10Z" fill="#fff0c5"/>' if not disabled else ''
    for char, (width, glyph) in enumerate(GLYPHS):
        for i, bit in enumerate(glyph):
            if bit == '1':
                art += f'<rect x="{7+char*8+(i%width)*2}" y="{6+(i//width)*2}" width="2" height="2" fill="{ink}"/>'
    art += '</g>'
    if state == 'focus':
        art += '<path d="M4 9V5H8M38 5H42V9M4 18V22H8M38 22H42V18" fill="none" stroke="#d5eec0"/>'
    (OUT / f'spin_{state}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="46" height="28" shape-rendering="crispEdges">{art}</svg>\n')
