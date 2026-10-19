"""Build the complete independent art-direction review, without modifying runtime bindings.

    python tools/generate_house_identity.py
    python tools/verify_house_identity.py
"""
from pathlib import Path
from PIL import Image
import hashlib
import json
import io

from house_identity.pixels import Pixel, P, rgba, write_image, write_bytes_atomic
from house_identity.dealer import portrait, dealer_sheet, STATES
from house_identity.cards import CARDS, card, card_sheet
from house_identity.scenes import SCENES, machine

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'godot/assets/art_direction/house_remembers'
DOC=ROOT/'docs/visual-identity'


def atlas(frames):
    w,h=frames[0].w,frames[0].h
    p=Pixel(w*len(frames),h)
    for i,f in enumerate(frames):p.paste(f,i*w,0)
    return p


def gif(frames, path, durations):
    # All frames were directly authored in the same fixed palette. This explicit
    # GIF palette only encodes those colours; no adaptive quantization/dithering.
    ref=Image.new('P',(1,1))
    values=[v for c in P for v in rgba(c)[:3]]
    ref.putpalette(values+[0]*(768-len(values)))
    images=[f.im.convert('RGB').quantize(palette=ref,dither=Image.Dither.NONE) for f in frames]
    encoded=io.BytesIO()
    images[0].save(encoded,format='GIF',save_all=True,append_images=images[1:],duration=durations,
                   loop=0,optimize=False,disposal=2)
    write_bytes_atomic(path,encoded.getvalue())


def main():
    OUT.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
    for name,draw in SCENES.items():
        p=draw();p.save(OUT/'scenes'/f'{name}.png')
        # Deliberate actual-layout-size review, not used as a production texture.
        write_image(p.im.resize((160,320),Image.Resampling.NEAREST),OUT/'scenes'/f'{name}_160.png')
    dealer_sheet().save(OUT/'dealer_states.png')
    for state in STATES:portrait(state).save(OUT/'dealer'/f'{state}.png')
    for key,name,family,effect in CARDS:card(key).save(OUT/'cards'/f'{key}.png')
    card('heart',back=True).save(OUT/'cards/power_back.png')
    card('augment_book',back=True).save(OUT/'cards/augment_back.png')
    card_sheet().save(OUT/'card_sheet.png')
    # Two useful texture/facial close-ups, exact repeated source pixels.
    face=portrait('late').crop((53,18,128,131));write_image(face.resize((300,452),Image.Resampling.NEAREST),OUT/'dealer_detail.png')
    scene=machine().crop((39,206,281,338));write_image(scene.resize((968,528),Image.Resampling.NEAREST),OUT/'reel_detail.png')
    # Full scene benchmark: a second-phase layout comparison is easy to read offline.
    board=Pixel(1032,708,'void',density=1);board.text('THE HOUSE REMEMBERS / THE HEALTHY MACHINE',20,16,'brass3',2)
    for i,(name,label) in enumerate((('02_pacte_augment','THE ROOM / QUIET'),('04_machine_early','THE MACHINE / INVITATION'),('26_machine_win','THE MACHINE / SMALL WIN'))):
        board.text(label,16+i*344,46,'paper2');board.paste(Image.open(OUT/'scenes'/f'{name}.png').resize((320,640),Image.Resampling.NEAREST),16+i*344,63)
    board.save(OUT/'benchmark.png')
    reward_board=Pixel(1032,708,'void',density=1)
    reward_board.text('HEALTHY MACHINE / INVITATION TO REWARD',20,16,'gold3',2)
    for i,(phase,label) in enumerate(((0,'READY / WARM TUNGSTEN CHASE'),(2,'PAIR / THE LIGHTS ANSWER'),(6,'SETTLE / SCORE AND CASH SEPARATE'))):
        reward_board.text(label,16+i*344,46,'paper2')
        reward_board.paste(machine(payout=phase).im.resize((320,640),Image.Resampling.NEAREST),16+i*344,63)
    reward_board.save(OUT/'machine_reward_benchmark.png')
    heat_board=Pixel(1032,708,'void',density=1)
    heat_board.text('THE MULTIPLIER IS THE MACHINE / OUTPUT LADDER',20,16,'gold3',2)
    for i,(tier,label) in enumerate(((1,'X1 / READY'),(2,'X2 / RUNNING HOT'),(3,'X3 / MAXIMUM OUTPUT'))):
        heat_board.text(label,16+i*344,46,'paper2')
        heat_board.paste(machine(tier=tier,frame=2).im.resize((320,640),Image.Resampling.NEAREST),16+i*344,63)
    heat_board.save(OUT/'multiplier_heat_benchmark.png')
    # Every remaining active presentation gets its own complete scene, not a label tile.
    names=[n for n in SCENES if n not in ('02_pacte_augment','04_machine_early','05_machine_advanced')]
    overview=Pixel(932,((len(names)+4)//5)*356+55,'void',density=1)
    overview.text('CASINO FLOOR / ACTIVE PRESENTATIONS AT 160 X 320',18,17,'brass3',2)
    for i,n in enumerate(names):
        x=18+i%5*184;y=58+i//5*356
        overview.text(n.replace('_',' ').upper()[:24],x,y-13,'paper1')
        overview.paste(Image.open(OUT/'scenes'/f'{n}_160.png'),x,y)
    overview.save(OUT/'scene_overview.png')
    # Physical display study with safe content centred inside a 390x844 phone.
    phones=Pixel(1198,910,'void',density=1)
    phones.text('PHONE STUDY / 390 X 844 / NEAREST DISPLAY / SAFE CONTENT CENTRED',12,16,'brass3',2)
    for i,name in enumerate(('04_machine_early','27_machine_hot','05_machine_advanced')):
        xx=3+i*399
        phones.box(xx,50,390,844,'slate');phones.box(xx+8,58,374,828,'ink')
        im=Image.open(OUT/'scenes'/f'{name}.png').resize((374,748),Image.Resampling.NEAREST)
        phones.paste(im,xx+8,98)
    phones.save(OUT/'phone_study.png')
    anim=OUT/'animation';anim.mkdir(exist_ok=True)
    blink=[portrait('welcome',f) for f in (0,1,2,4,5,0)]
    atlas(blink).save(anim/'vey_gaze.png');gif(blink,anim/'vey_gaze.gif',[1000,140,650,70,70,1300])
    advance=[portrait(s) for s in STATES]
    atlas(advance).save(anim/'vey_progression.png');gif(advance,anim/'vey_progression.gif',[1700,1700,1700,2200])
    pattern=[card('augment_pattern_recognition',i) for i in range(5)]
    atlas(pattern).save(anim/'pattern_recognition.png');gif(pattern,anim/'pattern_recognition.gif',[210]*5)
    cheating=[card('augment_how_to_cheat',i) for i in (0,2,4,2)]
    atlas(cheating).save(anim/'is_it_cheating.png');gif(cheating,anim/'is_it_cheating.gif',[1000,120,520,120])
    heat=[machine(),machine(tier=3),machine(tier=3,warning=True)]
    atlas(heat).save(anim/'machine_states.png');gif(heat,anim/'machine_states.gif',[2000,2000,1600])
    idle=[machine(frame=i) for i in range(6)]
    atlas(idle).save(anim/'healthy_idle.png');gif(idle,anim/'healthy_idle.gif',[180]*6)
    reward=[machine(payout=i,frame=i) for i in range(1,7)]
    atlas(reward).save(anim/'healthy_reward.png');gif(reward,anim/'healthy_reward.gif',[280,340,200,260,260,1300])
    for tier,name,ms in ((2,'heat_x2',140),(3,'heat_x3',110)):
        frames=[machine(tier=tier,frame=i) for i in range(6)]
        atlas(frames).save(anim/f'{name}.png');gif(frames,anim/f'{name}.gif',[ms]*6)
    ladder=[machine(tier=tier,frame=i) for tier in (1,2,3) for i in range(6)]
    ladder_ms=[180]*6+[140]*6+[110]*5+[1000]
    atlas(ladder).save(anim/'multiplier_heat.png');gif(ladder,anim/'multiplier_heat.gif',ladder_ms)
    manifest={
        'title':'The House Remembers','phase':'visual direction proposal; no runtime integration',
        'revision':4,'source_size':[640,1280],'layout_size':[160,320],'source_pixels_per_layout_unit':4,
        'card_source_size':[156,244],'recipe_unit_source_pixels':2,
        'palette':P,'cards':[dict(zip(('id','name','family','inspection'),c)) for c in CARDS],
        'scenes':list(SCENES),'animations':{
            'vey_gaze':{'size':[368,496],'ms':[1000,140,650,70,70,1300]},
            'vey_progression':{'size':[368,496],'ms':[1700,1700,1700,2200]},
            'pattern_recognition':{'size':[156,244],'ms':[210]*5},
            'is_it_cheating':{'size':[156,244],'ms':[1000,120,520,120]},
            'machine_states':{'size':[640,1280],'ms':[2000,2000,1600]},
            'healthy_idle':{'size':[640,1280],'ms':[180]*6},
            'healthy_reward':{'size':[640,1280],'ms':[280,340,200,260,260,1300]},
            'heat_x2':{'size':[640,1280],'ms':[140]*6},
            'heat_x3':{'size':[640,1280],'ms':[110]*6},
            'multiplier_heat':{'size':[640,1280],'ms':ladder_ms},
        },
    }
    manifest['files']={str(f.relative_to(OUT)).replace('\\','/'):hashlib.sha256(f.read_bytes()).hexdigest()
                       for f in sorted(OUT.rglob('*')) if f.suffix in ('.png','.gif')}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
    # Review HTML is generated from the same manifest, no asset copies to go stale.
    from house_identity.review import gallery
    (DOC/'review.html').write_text(gallery(manifest),encoding='utf8')
    print(f'Built {len(SCENES)} compositions, {len(CARDS)} card faces, 4 dealer states, 10 motion studies; multiplier output benchmark.')
    print(f'Review: {DOC / "review.html"}')


if __name__=='__main__':main()
