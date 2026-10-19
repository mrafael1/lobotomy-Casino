"""V1 production extraction from drawing commands, never from flattened mockups."""
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import json

from .pixels import Pixel, rgba, write_image, write_bytes_atomic
from .console import machine
from .machine_geometry import geometry
from . import heat
from .machine_components import build_components, POWERS


class LayerCanvas(Pixel):
    """Capture contiguous authored passes, including review-only live fixtures."""
    def __init__(self,w=320,h=640,bg=None):
        super().__init__(w,h,bg)
        self.passes=[]
        self.current={'name':'background','live':False,'image':self.im}
        self.passes.append(self.current)

    def layer(self,name,live=False):
        if self.current['name']==name and self.current['live']==live:return
        self.im=Image.new('RGBA',(self.w*2,self.h*2))
        self.d=ImageDraw.Draw(self.im)
        self.current={'name':name,'live':live,'image':self.im}
        self.passes.append(self.current)

    def text(self,s,x,y,c='paper3',scale=1,align='left',tracking=1):
        if s in ('LOBOTOMY','C A S I N O'):
            super().text(s,x,y,c,scale,align,tracking);return
        prior=self.current
        self.layer('live_text',True)
        self.current['text']={'sample':s,'position_source':[x*2,y*2],
            'colour':c,'scale_source':scale*2,'align':align,'tracking_source':tracking*2,'owner':prior['name']}
        super().text(s,x,y,c,scale,align,tracking)
        self.layer(prior['name'],prior['live'])

    def compose(self,fixtures=True):
        result=Image.new('RGBA',(self.w*2,self.h*2))
        for part in self.passes:
            if fixtures or not part['live']:result.alpha_composite(part['image'])
        return result

    def cut_apertures(self):
        for part in self.passes:
            if part['name'] not in ('cabinet','reel_housing',*(f'reel_frame_{i}' for i in range(3))):continue
            d=ImageDraw.Draw(part['image'])
            for reel in geometry()['reels']:
                x,y,w,h=reel['aperture']['source']
                d.rectangle((x,y,x+w-1,y+h-1),fill=(0,0,0,0))


class Package:
    def __init__(self,out):
        self.out=Path(out);self.files={}

    def sprite(self,im,name,folder='layers'):
        box=im.getbbox()
        if box is None:return None
        tile=im.crop(box)
        digest=hashlib.sha256(tile.tobytes()+str(tile.size).encode()).hexdigest()[:16]
        rel=f'{folder}/{name}_{digest}.png'
        write_image(tile,self.out/rel)
        self.files[rel]=hashlib.sha256((self.out/rel).read_bytes()).hexdigest()
        x,y,right,bottom=box
        return {'file':rel,'source_rect':[x,y,right-x,bottom-y],
                'layout_rect':[v*.25 for v in (x,y,right-x,bottom-y)]}

    def passes(self,p):
        records=[];counts=Counter()
        for part in p.passes:
            if part['live']:continue
            saved=self.sprite(part['image'],part['name'])
            if saved:
                name=part['name'];counts[name]+=1
                records.append({'id':f'{name}_{counts[name]}','role':name,**saved})
        return records

    def masks(self,p,tier):
        coat,metal,glass=heat.ramps(tier)
        roles={'enamel':coat,'metal':metal,'glass':glass}
        flat=p.compose(fixtures=False)
        records={}
        for role,colours in roles.items():
            members={rgba(c) for c in colours}
            im=Image.new('RGBA',flat.size)
            im.putdata([rgba('heat_white') if c in members else (0,0,0,0) for c in flat.getdata()])
            records[role]=self.sprite(im,f'x{tier}_{role}',folder='masks')
        for role,names,colours in (
                ('floor',('floor','floor_reflection'),None),
                ('lamp_cores',('marquee_lamps','reel_lamps'),{rgba(c) for c in ('bulb2','bulb3','heat5','heat_white')})):
            im=Image.new('RGBA',flat.size)
            for part in p.passes:
                if part['name'] in names:im.alpha_composite(part['image'])
            im.putdata([rgba('heat_white') if c[3] and (colours is None or c in colours) else (0,0,0,0) for c in im.getdata()])
            records[role]=self.sprite(im,f'x{tier}_{role}',folder='masks')
        return records


def build(out):
    package=Package(out)
    prior_manifest=Path(out)/'manifest.json'
    prior_files=set(json.loads(prior_manifest.read_text(encoding='utf8'))['files']) if prior_manifest.exists() else set()
    states={};fixtures={};text_slots=[]
    conditions=[(f'x{tier}_{frame}',tier,frame,False,0) for tier in (1,2,3) for frame in range(6)]
    conditions += [(f'rescue_x{tier}',tier,0,True,0) for tier in (2,3)]
    conditions += [(f'win_x{tier}',tier,2,False,2) for tier in (1,2,3)]
    for key,tier,frame,warning,payout in conditions:
        p=machine(tier,frame,warning,payout,canvas=LayerCanvas)
        reference=machine(tier,frame,warning,payout).im
        p.cut_apertures()
        assert p.compose().tobytes()==reference.tobytes(),f'Layer assembly differs: {key}'
        states[key]={'tier':tier,'frame':frame,'pending_loss':warning,'layers':package.passes(p)}
        if frame==0 and not warning and not payout:
            states[key]['material_masks']=package.masks(p,tier)
            # These are separate physical caps; their localized SPIN label is
            # supplied by the live owner. Registration stays in master space.
            caps={}
            base=Image.new('RGBA',(640,1280))
            for part in p.passes:
                if part['name']=='spin_cap' and not part['live']:base.alpha_composite(part['image'])
            for state in ('ready','selected','pressed','disabled'):
                cap=base.copy()
                if state=='pressed':
                    cap=Image.new('RGBA',base.size);cap.alpha_composite(base,(0,4))
                elif state=='selected':
                    d=ImageDraw.Draw(cap)
                    for x,dx in ((190,1),(426,-1)):
                        for y,dy in ((1006,1),(1102,-1)):
                            d.line([(x,y+10*dy),(x,y),(x+10*dx,y)],fill=rgba('cream3'),width=2)
                elif state=='disabled':
                    members={rgba(c) for c in heat.ramps(tier)[0]}
                    cap.putdata([rgba('wine1') if c in members else c for c in cap.getdata()])
                caps[state]=package.sprite(cap,f'spin_{state}_x{tier}','controls')
            states[key]['spin_states']=caps
        if key in ('x1_0','x2_0','x3_0','rescue_x2','rescue_x3','win_x1'):
            write_image(p.compose(),Path(out)/'review'/f'{key}.png')
            write_image(p.compose(fixtures=False),Path(out)/'review'/f'runtime_{key}.png')
            write_image(p.compose().resize((160,320),Image.Resampling.NEAREST),Path(out)/'review'/f'{key}_160.png')
            fixtures[key]=[part['text'] for part in p.passes if 'text' in part]
        if key=='x1_0':
            for index,part in enumerate(p.passes):
                if 'text' in part:
                    slot={k:v for k,v in part['text'].items() if k!='sample'}
                    text_slots.append({'id':f'text_{index}',**slot})
    components=build_components(package)
    previews(package,states,components)
    manifest={'version':1,'selected_variant':'v1','status':'asset package; no live scene bindings',
        'geometry':geometry(),'states':states,'text_slots':text_slots,
        'components':components,
        'composition':'Ordered cropped layers; source_rect is registration in the 640x1280 master. All decorative layers ignore input.',
        'live_content':'Game supplies numerals, localized labels, symbols, countdown, restore lamps, inventory, powers and augment glyphs.',
        'files':package.files}
    Path(out).mkdir(parents=True,exist_ok=True)
    for relative,data in (('geometry.json',geometry()),('manifest.json',manifest),('review/fixtures.json',fixtures)):
        write_bytes_atomic(Path(out)/relative,(json.dumps(data,indent=2)+'\n').encode('utf8'))
    # Retire only exact former generated sprites, never recursively delete a
    # directory or remove files outside this package's recorded ownership.
    root=Path(out).resolve()
    for rel in sorted(prior_files-set(package.files)):
        path=(root/rel).resolve()
        assert path.is_relative_to(root) and path.suffix=='.png',rel
        if path.exists():path.unlink()
    print(f'V1 package: {len(states)} assembled states; {len(package.files)} reusable layer/mask sprites. No live bindings.')
    return manifest


def previews(package,states,components):
    out=package.out
    board=Pixel(1032,708,'void',density=1)
    board.text('V1 / PRODUCTION LAYERS / REGISTERED ASSEMBLY',20,16,'gold3',2)
    for i,(key,label) in enumerate((('x1_0','X1 / READY'),('x2_0','X2 / HOT'),('x3_0','X3 / MAXIMUM OUTPUT'))):
        board.text(label,16+i*344,46,'paper2')
        with Image.open(out/'review'/f'{key}.png') as im:
            board.paste(im.resize((320,640),Image.Resampling.NEAREST),16+i*344,63)
    board.save(out/'review/production_benchmark.png')
    sheet=Pixel(1200,1116,'void',density=1)
    sheet.text('V1 / INDIVIDUAL PRODUCTION COMPONENTS',20,16,'gold3',2)
    sheet.text('SYMBOLS / 10 INDEPENDENT SPRITES',20,52,'paper2')
    def paste_sprite(entry,x,y):
        with Image.open(out/entry['file']) as im:
            sheet.paste(im,x+entry['source_rect'][0],y+entry['source_rect'][1])
    for i,(key,entry) in enumerate(components['symbols'].items()):
        x=20+i*116
        with Image.open(out/entry['file']) as im:
            sheet.paste(im,x,80)
        sheet.text(key.replace('_',' ').upper(),x,215,'paper2')
    sheet.text('POWERS / SEVEN FACES / READY THEN SPENT',20,252,'paper2')
    for i,(key,entries) in enumerate(components['powers']['x1'].items()):
        x=12+i*145
        paste_sprite(entries['ready'],x,276);paste_sprite(entries['spent'],x,378)
        sheet.text(POWERS[key],x+10,486,'paper2')
    sheet.text('ITEMS / EACH ID HAS ITS OWN SILHOUETTE',20,524,'paper2')
    for i,(key,entry) in enumerate(components['items'].items()):
        paste_sprite(entry,24+i*110,551)
        sheet.text(key.removeprefix('cons_').removeprefix('item_').replace('_',' ').upper()[:15],20+i*110,596,'paper2')
    sheet.text('AUGMENT STICKERS / ANIMATED FAMILIES RETAIN FRAMES',20,636,'paper2')
    for i,entry in enumerate(components['augments'].values()):paste_sprite(entry['frames'][0],22+i*72,668)
    sheet.text('POWER STATES / READY / SELECTED / PRESSED / SPENT / RESTORED',20,728,'paper2')
    for i,entry in enumerate(components['powers']['x1']['reroll'].values()):paste_sprite(entry,22+i*185,759)
    sheet.text('SPIN CAP / READY / SELECTED / PRESSED / DISABLED / LABEL IS LIVE',20,891,'paper2')
    for i,entry in enumerate(states['x1_0']['spin_states'].values()):
        with Image.open(out/entry['file']) as im:sheet.paste(im,22+i*280,929)
    sheet.text('LOCAL PIXEL GRID / LIVE TEXT AND VALUES OMITTED FROM SPRITES',20,1088,'gold2')
    sheet.save(out/'review/component_sheet.png')
