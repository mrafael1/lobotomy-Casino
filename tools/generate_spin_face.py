"""Native SPIN faces: shared pixel lettering and a two-pixel depression."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'godot/assets/images/machine_polished'
GLYPHS = ['01111100001000001110000010000111110', '11110100011000111110100001000010000', '11111001000010000100001000010011111', '10001110011100110101100111001110001']
for state in ['normal', 'pressed', 'disabled', 'hover', 'focus']:
    disabled = state == 'disabled'
    depression = 2 if state == 'pressed' else 0
    face = '#969383' if disabled else ('#fff0bb' if state == 'hover' else '#eed9a1')
    ink = '#535648' if disabled else '#252b23'
    # The mounting frame belongs to the cabinet. Only the moving cap is drawn here.
    art = ''
    art += f'<g transform="translate(0 {depression})"><path d="M8 4H37L39 18L37 20H7L6 18Z" fill="#896840"/>'
    art += f'<path d="M9 5H36L38 17L36 18H8L7 17Z" fill="{face}"/>'
    art += '<path d="M10 5H35V6H10L9 15H8Z" fill="#fff0c5"/><path d="M9 17H36V18H9Z" fill="#c8aa70"/>' if not disabled else ''
    for char, glyph in enumerate(GLYPHS):
        for i, bit in enumerate(glyph):
            if bit == '1':
                art += f'<rect x="{11+char*6+i%5}" y="{8+i//5}" width="1" height="1" fill="{ink}"/>'
    art += '</g>'
    if state == 'focus':
        art += '<path d="M4 9V5H8M38 5H42V9M4 18V22H8M38 22H42V18" fill="none" stroke="#d5eec0"/>'
    (OUT / f'spin_{state}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="46" height="28" shape-rendering="crispEdges">{art}</svg>\n')
