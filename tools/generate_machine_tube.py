"""Native glass-and-metal spin cartridge, one full-canvas frame per fill count."""
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / 'godot/assets/images/machine_polished/spin_tube.svg'
CAPACITY = 19


def rect(x, y, width, height, color):
    return f'<rect x="{x}" y="{y}" width="{width}" height="{height}" fill="{color}"/>'


def cartridge(count):
    art = rect(3, 47, 16, 73, '#090e0d')
    art += rect(4, 49, 14, 68, '#39453d')
    art += rect(5, 53, 12, 61, '#101e19')
    art += rect(6, 54, 10, 59, '#192c24')
    art += rect(7, 54, 7, 59, '#13221c')
    # Empty slots remain visible; fill grows from the base.
    for index in range(CAPACITY):
        top = 110 - 3 * index
        lit = index < count
        face = '#bc7772' if lit else '#2e3b32'
        shade = '#744c49' if lit else '#1a2a22'
        if lit and count <= 3:
            face, shade = '#e16858', '#873c36'
        art += rect(7, top, 7, 1, face) + rect(7, top + 1, 7, 1, shade)
        art += rect(15, top, 1, 1, '#667660' if index % 5 == 0 else '#354d3f')
    # Reflections and worn steel end caps remain fixed through the fill animation.
    art += rect(5, 54, 1, 58, '#7b9780') + rect(6, 54, 1, 58, '#344e3d')
    art += rect(16, 55, 1, 57, '#253a2e')
    for top in (47, 114):
        art += rect(5, top, 12, 6, '#777b6e')
        art += rect(6, top, 10, 1, '#b6b59a')
        art += rect(5, top + 1, 1, 3, '#999e89')
        art += rect(5, top + 5, 12, 1, '#343d36')
        art += rect(16, top + 1, 1, 4, '#4a5147')
        art += rect(8, top + 2, 6, 1, '#5c6558')
        art += rect(6, top + 3, 1, 1, '#232e26')
        art += rect(15, top + 2, 1, 1, '#232e26')
    return art


frames = ''.join(f'<g transform="translate({160*count} 0)">{cartridge(count)}</g>'
                 for count in range(CAPACITY + 1))
OUTPUT.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{160*(CAPACITY+1)}" '
                  f'height="320" shape-rendering="crispEdges">{frames}</svg>\n')
