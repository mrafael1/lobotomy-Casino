"""Build the selected machine's runtime-ready layer package, without scene rebinding."""
from pathlib import Path
from house_identity.machine_production import build

if __name__=='__main__':
    build(Path(__file__).resolve().parents[1]/'godot/assets/art_direction/house_remembers/machine_v1')
