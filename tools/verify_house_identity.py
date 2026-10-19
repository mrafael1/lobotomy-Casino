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
        assert im.size==(320,640),s
        assert im.getextrema()[3]==(255,255),f'Incomplete scene: {s}'
        reduction=Image.open(ART/'scenes'/f'{s}_160.png').convert('RGBA')
        assert reduction.tobytes()==im.resize((160,320),Image.Resampling.NEAREST).tobytes(),s
    source=(ROOT/'godot/rules/pacte_cards.gd').read_text(encoding='utf8')
    authored=set(re.findall(r'"id":\s*"([^"]+)"\s*,\s*"name":',source))
    assert authored=={c[0] for c in CARDS},f'Card coverage differs: {authored ^ {c[0] for c in CARDS}}'
    assert len({hashlib.sha256(Image.open(ART/'cards'/f'{c[0]}.png').tobytes()).hexdigest() for c in CARDS})==len(CARDS),'Duplicate card faces'
    for c in CARDS:assert Image.open(ART/'cards'/f'{c[0]}.png').size==(78,122),c[0]
    for key,meta in m['animations'].items():
        size=meta['size'];timing=meta['ms']
        assert Image.open(ART/'animation'/f'{key}.png').size==(size[0]*len(timing),size[1]),key
        im=Image.open(ART/'animation'/f'{key}.gif')
        assert im.n_frames==len(timing),key
        for i,t in enumerate(timing):
            im.seek(i);assert im.info['duration']==t,f'{key} frame {i}'
        im.close()
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
        'visual_review':['benchmark','dealer states','card sheet','scene overview','phone study','dealer detail','reel detail'],
        'interactive_browser_review':'not run; browser inventory had no enabled browser',
        'runtime_godot_checks':'see godot_validation.json for current-workspace import/smoke; proposal images have no live bindings',
    }
    (DOC/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':verify()
