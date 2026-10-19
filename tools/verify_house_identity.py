"""Verify meaningful phase-one art contracts; never invoke or mutate gameplay."""
from pathlib import Path
from PIL import Image
from html.parser import HTMLParser
import hashlib
import json
import re
import subprocess
import tempfile

from house_identity.pixels import P, rgba
from house_identity.cards import CARDS

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'godot/assets/art_direction/house_remembers'
DOC=ROOT/'docs/visual-identity'


class Resources(HTMLParser):
    def __init__(self):
        super().__init__();self.resources=[];self.ids=[];self.scene_buttons=[]

    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if 'id' in attrs:self.ids.append(attrs['id'])
        if 'data-scene' in attrs:self.scene_buttons.append(attrs['data-scene'])
        for key in ('src','href'):
            if key in attrs:self.resources.append(attrs[key])


def verify():
    m=json.loads((ART/'manifest.json').read_text(encoding='utf8'))
    palette={rgba(k) for k in P}
    binary=palette|{(0,0,0,0)}
    checked=0
    for rel,digest in m['files'].items():
        f=ART/rel
        assert hashlib.sha256(f.read_bytes()).hexdigest()==digest, f'Changed export: {rel}'
        im=Image.open(f)
        if f.suffix=='.png':
            colours=set(im.convert('RGBA').get_flattened_data())
            assert colours<=binary, f'Non-palette colour or fractional alpha: {rel}: {colours-binary}'
            checked+=1
        im.close()
    for s in m['scenes']:
        im=Image.open(ART/'scenes'/f'{s}.png').convert('RGBA')
        assert im.size==tuple(m['source_size']),s
        assert im.getextrema()[3]==(255,255),f'Incomplete scene: {s}'
        reduction=Image.open(ART/'scenes'/f'{s}_160.png').convert('RGBA')
        assert reduction.tobytes()==im.resize((160,320),Image.Resampling.NEAREST).tobytes(),s
    alternative=m['machine_alternative']
    from house_identity.console_v2 import machine as machine_v2
    for state in alternative['states']:
        with Image.open(ART/'machine_v2'/f'{state}.png') as im:
            assert im.size==tuple(alternative['source_size']),state
            assert im.convert('RGBA').getextrema()[3]==(255,255),state
            with Image.open(ART/'machine_v2'/f'{state}_160.png') as small:
                assert small.tobytes()==im.resize((160,320),Image.Resampling.NEAREST).tobytes(),state
    # V2 is rerasterised construction, not a nearest reduction of v1.
    with Image.open(ART/'scenes/04_machine_early.png') as fine:
        assert machine_v2().im.tobytes()!=fine.resize((320,640),Image.Resampling.NEAREST).tobytes()
    for tier in (1,2,3):
        frames=[machine_v2(tier=tier,frame=i).im for i in range(6)]
        for box in ((46,357,274,422),(52,217,266,327),(34,504,286,550)):
            assert all(f.crop(box).tobytes()==frames[0].crop(box).tobytes() for f in frames),f'V2 UI drift x{tier}'
    source=(ROOT/'godot/rules/pacte_cards.gd').read_text(encoding='utf8')
    authored=set(re.findall(r'"id":\s*"([^"]+)"\s*,\s*"name":',source))
    assert authored=={c[0] for c in CARDS},f'Card coverage differs: {authored ^ {c[0] for c in CARDS}}'
    assert len({hashlib.sha256(Image.open(ART/'cards'/f'{c[0]}.png').tobytes()).hexdigest() for c in CARDS})==len(CARDS),'Duplicate card faces'
    for c in CARDS:assert Image.open(ART/'cards'/f'{c[0]}.png').size==tuple(m['card_source_size']),c[0]
    # Higher resolution must contain native-grid construction, not repeated
    # blocks from the previous masters under a larger export size.
    for rel in ('scenes/02_pacte_augment.png','scenes/04_machine_early.png','cards/augment_book.png','dealer/welcome.png'):
        with Image.open(ART/rel) as im:
            coarse=im.resize((im.width//2,im.height//2),Image.Resampling.NEAREST)
            assert coarse.resize(im.size,Image.Resampling.NEAREST).tobytes()!=im.tobytes(),f'Only doubled pixels: {rel}'
    for key,meta in m['animations'].items():
        size=meta['size'];timing=meta['ms']
        assert Image.open(ART/'animation'/f'{key}.png').size==(size[0]*len(timing),size[1]),key
        im=Image.open(ART/'animation'/f'{key}.gif')
        assert im.n_frames==len(timing),key
        for i,t in enumerate(timing):
            im.seek(i);assert im.info['duration']==t,f'{key} frame {i}'
        im.close()
    # Decorative chase is presentation-only: no numerical, reel or control
    # region may shift or change contrast while perimeter lamps animate.
    for animation in ('healthy_idle','heat_x2','heat_x3'):
        with Image.open(ART/'animation'/f'{animation}.png') as im:
            for box in ((92,714,548,844),(104,434,532,654),(68,1008,572,1100)):
                expected=im.crop(box).tobytes()
                for i in range(1,6):
                    shifted=(box[0]+i*640,box[1],box[2]+i*640,box[3])
                    assert im.crop(shifted).tobytes()==expected,f'{animation} changes UI: {box}, frame {i}'
    html=(DOC/'review.html').read_text(encoding='utf8')
    parsed=Resources();parsed.feed(html)
    assert len(parsed.ids)==len(set(parsed.ids)),'Duplicate HTML IDs'
    assert set(parsed.scene_buttons)==set(m['scenes']),'Missing scene review'
    for ref in parsed.resources:
        if ref.startswith('#'):assert ref[1:] in parsed.ids,ref
        else:
            assert not ref.startswith(('http:','https:')),f'External dependency: {ref}'
            assert (DOC/ref).is_file(),f'Missing review resource: {ref}'
    # Syntax-check the actual generated JavaScript rather than a parallel copy.
    script=re.search(r'<script>(.*?)</script>',html,re.S).group(1)
    with tempfile.TemporaryDirectory(prefix='house-identity-') as tmp:
        js=Path(tmp)/'review.js';js.write_text(script,encoding='utf8')
        subprocess.run(['node','--check',str(js)],check=True,capture_output=True,text=True)
    # Rebuild and compare every image byte. This catches accidental nondeterminism.
    before=dict(m['files'])
    rebuilt=subprocess.run(['python',str(ROOT/'tools/generate_house_identity.py')],capture_output=True,text=True)
    assert rebuilt.returncode==0,rebuilt.stdout+rebuilt.stderr
    after=json.loads((ART/'manifest.json').read_text(encoding='utf8'))['files']
    assert before==after,'Rebuild is not deterministic'
    result={
        'status':'passed','palette_colours':len(P),'palette_and_alpha_pngs':checked,
        'full_scene_masters':len(m['scenes']),'layout_size_reductions':len(m['scenes']),
        'unique_card_faces':len(CARDS),'card_coverage':'exact match to current PacteCards IDs',
        'animation_atlases_and_gif_timing':len(m['animations']),
        'review_resources_checked':len(parsed.resources),'generated_javascript_syntax':'passed (node --check)',
        'deterministic_image_rebuild':'byte-identical',
        'source_size':m['source_size'],'native_fine_grid_construction':'verified; not repeated 2x raster blocks',
        'healthy_idle_ui_regions':'pixel-identical across all six chase frames',
        'heated_ui_regions':'pixel-identical within each x2/x3 six-frame loop',
        'machine_v2':'direct 320x640 construction; four opaque states, exact gameplay-size views; stable UI at every tier',
        'visual_review':['benchmark','multiplier heat benchmark','dealer states','card sheet','scene overview','phone study','dealer detail','reel detail','machine v2 comparison','machine v2 output ladder','machine v2 reel detail','machine v2 phone study'],
        'interactive_browser_review':'not run; browser inventory had no enabled browser',
        'runtime_godot_checks':'see godot_validation.json for current-workspace import/smoke; proposal images have no live bindings',
    }
    (DOC/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':verify()
