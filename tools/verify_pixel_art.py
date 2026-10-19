"""Verify coverage, literal pixel colours, alpha and exact repeat blocks."""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image
from pixel_art.core import P, color

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'godot/assets/images'


def main():
    records=json.loads((ART/'pixel/manifest.json').read_text())
    source_paths=json.loads((ROOT/'tools/pixel_art/contracts.json').read_text()).keys()
    assert records.keys()==source_paths, sorted(source_paths-records.keys())
    allowed={color(key)[:3] for key in P}|{(0,0,0),(255,255,255)}
    strict=0
    fingerprint=hashlib.sha256()
    for source,record in records.items():
        path=ART/record['path']
        image=Image.open(path).convert('RGBA')
        assert list(image.size)==record['export_size'], source
        rgba=np.asarray(image)
        histogram=image.getcolors(maxcolors=256)
        assert histogram is not None, source
        colors=[c for _,c in histogram]
        assert all(tuple(c[:3]) in allowed for c in colors), source
        if '/heat_' not in source:
            assert all(c[3] in (0,255) for c in colors), source
        nw,nh=record['source_grid']
        assert image.width % nw == 0 and image.height % nh == 0, source
        assert image.width // nw == image.height // nh, source
        if image.width%nw==0 and image.height%nh==0:
            # Every exported block is a literal repeated source pixel.
            reduced=image.resize((nw,nh),Image.Resampling.NEAREST)
            restored=reduced.resize(image.size,Image.Resampling.NEAREST)
            assert np.array_equal(rgba,np.asarray(restored)), source
            strict+=1
        sidecar=path.with_suffix('.png.import')
        if sidecar.exists():assert 'mipmaps/generate=false' in sidecar.read_text(), source
        fingerprint.update(source.encode()+path.read_bytes())
    machine=Image.open(ART/records['machine_polished/cabinet_material_pass.png']['path'])
    a=np.asarray(machine)[...,3]
    sx=machine.width//160;sy=machine.height//320
    for x in (33,65,97):assert not a[169*sy:203*sy,x*sx:(x+21)*sx].any()
    font=Image.open(ROOT/'godot/assets/font/pixel/casino.png').convert('RGBA')
    assert set(np.unique(np.asarray(font)[...,3]))<={0,255}
    print(f'PASS: {len(records)} / {len(source_paths)} image contracts generated; {strict} integer-scale block checks; palette and alpha valid')
    print('Visual-set SHA256: '+fingerprint.hexdigest())


if __name__=='__main__':main()
