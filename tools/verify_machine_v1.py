"""Verify the selected machine's exported layer/geometry contracts."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import re
import subprocess
import sys

from house_identity.pixels import rgba, P, text_width
from house_identity.machine_production import LayerCanvas
from house_identity.console import machine

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'godot/assets/art_direction/house_remembers/machine_v1'


def verify():
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf8'))
    assert m['selected_variant']=='v1'
    assert json.loads((OUT/'geometry.json').read_text(encoding='utf8'))==m['geometry']
    for field in ('wealth','target'):
        assert m['geometry'][field]['source'][2]>=text_width('5000',3)*2,field
    palette={rgba(c) for c in P}|{(0,0,0,0)}
    for rel,digest in m['files'].items():
        path=OUT/rel
        assert hashlib.sha256(path.read_bytes()).hexdigest()==digest,rel
        with Image.open(path) as im:
            assert set(im.get_flattened_data())<=palette,rel
    for key,state in m['states'].items():
        p=machine(state['tier'],state['frame'],state['pending_loss'],2 if key.startswith('win_') else 0,canvas=LayerCanvas)
        p.cut_apertures()
        assembled=Image.new('RGBA',(640,1280))
        for part in state['layers']:
            assert '_example' not in part['role'] and part['role']!='live_text',part
            x,y,w,h=part['source_rect']
            with Image.open(OUT/part['file']) as im:
                assert im.size==(w,h),part
                assembled.alpha_composite(im,(x,y))
                if part['role'] in ('cabinet','reel_housing','reel_frame_0','reel_frame_1','reel_frame_2'):
                    canvas=Image.new('RGBA',(640,1280));canvas.alpha_composite(im,(x,y))
                    for reel in m['geometry']['reels']:
                        rx,ry,rw,rh=reel['aperture']['source']
                        assert canvas.crop((rx,ry,rx+rw,ry+rh)).getbbox() is None,(key,part['role'])
        assert assembled.tobytes()==p.compose(fixtures=False).tobytes(),key
        reference=machine(state['tier'],state['frame'],state['pending_loss'],2 if key.startswith('win_') else 0).im
        assert p.compose().tobytes()==reference.tobytes(),f'Artwork drift: {key}'
    components=m['components']
    for source,family in (('godot/rules/consumables.gd','items'),('godot/rules/in_run_items.gd','items')):
        ids=set(re.findall(r'"id":\s*"([^"]+)"',(ROOT/source).read_text(encoding='utf8')))
        assert ids<=set(components[family]),f'Missing {source}: {ids-set(components[family])}'
    pacte=(ROOT/'godot/rules/pacte_cards.gd').read_text(encoding='utf8')
    powers=set(re.findall(r'"power_id":\s*"([^"]+)"',pacte))
    assert set(components['powers']['x1'])==powers
    for tier,power_set in components['powers'].items():
        assert set(power_set)==powers
        for key,states in power_set.items():
            assert set(states)=={'ready','selected','pressed','spent','restored'},(tier,key)
            # A pressed cap can reuse the same pixels at a lower registration.
            # Compare its registered canvas, not just the trimmed PNG bytes.
            signatures=set()
            for entry in states.values():
                canvas=Image.new('RGBA',tuple(entry['canvas_source_size']))
                with Image.open(OUT/entry['file']) as im:
                    canvas.alpha_composite(im,tuple(entry['source_rect'][:2]))
                signatures.add(hashlib.sha256(canvas.tobytes()).hexdigest())
            assert len(signatures)==5,(tier,key)
    symbols_source=(ROOT/'godot/rules/symbols.gd').read_text(encoding='utf8')
    symbol_ids=set(json.loads(re.search(r'const IDS := (\[[^\]]+\])',symbols_source).group(1)))
    assert set(components['symbols'])==symbol_ids|{'heart_x1','heart_x2','heart_x3'}
    augments=set(re.findall(r'"id":\s*"(augment_[^"]+)"',pacte))
    assert set(components['augments'])==augments
    assert len(components['augments']['augment_pattern_recognition']['frames'])==5
    assert len(components['augments']['augment_how_to_cheat']['frames'])==4
    assert len({m['files'][f['file']] for f in components['augments']['augment_pattern_recognition']['frames']})==5
    assert len({m['files'][f['file']] for f in components['augments']['augment_how_to_cheat']['frames']})==3
    assert len({m['files'][f['file']] for f in components['items'].values()})==9
    assert components['augments']['augment_how_to_cheat']['frame_ms']==[1000,120,520,120]
    assert components['augments']['augment_pattern_recognition']['frame_ms']==[210]*5
    presets=(ROOT/'godot/export_presets.cfg').read_text(encoding='utf8')
    for line in presets.splitlines():
        if line.startswith('include_filter='):
            for name in ('manifest','geometry'):
                assert f'assets/art_direction/house_remembers/machine_v1/{name}.json' in line
    assert all('sample' not in slot for slot in m['text_slots'])
    def hitboxes(value):
        if isinstance(value,dict):
            for key,item in value.items():
                if key=='touch':
                    x,y,w,h=item['layout']
                    assert x>=0 and y>=0 and x+w<=160 and y+h<=320,item
                else:hitboxes(item)
        elif isinstance(value,list):
            for item in value:hitboxes(item)
    hitboxes(m['geometry'])
    before={str(f.relative_to(OUT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in OUT.rglob('*') if f.suffix in ('.png','.json')}
    subprocess.run([sys.executable,str(ROOT/'tools/generate_machine_v1.py')],check=True,capture_output=True)
    after={str(f.relative_to(OUT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in OUT.rglob('*') if f.suffix in ('.png','.json')}
    assert before==after,'Non-deterministic package rebuild'
    result={'status':'passed','selected':'v1','assembled_states':len(m['states']),
        'cropped_sprites_and_masks':len(m['files']),'apertures':'transparent in cabinet/housing/frame passes',
        'assembly':'all exported state stacks match direct recipe rendering; fixtures restore the exact approved v1',
        'components':{'powers':len(powers),'power_states_per_tier':5,'tiers':3,
            'symbols':len(components['symbols']),'items':len(components['items']),'augments':len(augments)},
        'pixel_grid':'640x1280 source / 160x320 safe layout; fixed palette, binary alpha',
        'touch_geometry':'within safe area','deterministic_rebuild':'byte-identical',
        'gameplay_or_live_scene_changes':False}
    (ROOT/'docs/visual-identity/machine_v1_validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':verify()
