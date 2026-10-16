"""Generate the game's visual assets from integer drawing recipes.

Source artwork is NEVER read. Versioned contracts supply dimensions/atlas layout.
Outputs live in a separate tree so authored and uncommitted work is preserved.
Run `py tools/generate_pixel_art.py` for the complete set.
"""
from pathlib import Path
import argparse
import io
import json
from pixel_art.core import Canvas, icon, scaled, sheet
from pixel_art import machine, rooms, ui, legacy, font

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'godot/assets/images'
OUT=ART/'pixel'
MANIFEST=ROOT/'godot/art/generated_pixel_manifest.gd'


def write_text_if_changed(path, text):
    if not path.exists() or path.read_text(encoding='utf8') != text:
        path.write_text(text,encoding='utf8')


def machine_recipe(rel,size):
    p=Path(rel);n=p.stem.lower();w,h=size
    if 'machine_polished/' in rel:
        if n.startswith('cabinet') or n=='preview_shelf':return machine.cabinet('game-over' in n)
        if n.startswith('preview_spin_'):return machine.spin(n.replace('preview_spin_',''))
        if n=='dealer-painted':return machine.dealer(40,60,hands=False)
        if n.startswith('heat_'):return machine.heat(n[5:])
        if n in ('reroll','shift','memory','rewind','heart','cheat','swap'):
            return sheet([machine.power(n,s) for s in range(3)])
        if n=='reel_drums':return machine.reels('drums')
        if n=='reel_housing':return machine.reels('housing')
        if n=='reel_motion':return sheet([machine.reels('motion',k) for k in range(4)])
        if n=='power_lamps':return sheet([machine.lamps(k) for k in range(4)])
        if n=='power_restore_flash':return sheet([machine.lamps(3,True) for k in range(max(1,w//160))])
        if n=='jackpot_beacon':return sheet([machine.beacon(k) for k in range(3)])
        if n in ('multiplier','combo','loss_2','loss_3','free_spin'):
            count={'multiplier':6,'combo':9,'loss_2':1,'loss_3':9,'free_spin':1}[n]
            return sheet([machine.callout(n,k) for k in range(count)])
        if n.startswith('dealer_bar'):
            overlay=int(n[-1]) if n[-1].isdigit() else 0
            return sheet([machine.dealer_bar(k,overlay) for k in range(w//160)])
        if n in ('target_progress','target_shimmer'):
            frames=[]
            for k in range(w//160):
                c=Canvas(160,320)
                if n=='target_progress':
                    c.box(73,59,45,2,'green0');c.box(73,59,round(45*k/max(1,w//160-1)),1,'green3')
                else:c.box(73+k*7,59,4,1,'cyan')
                frames.append(c)
            return sheet(frames)
        if n=='reel_lock':
            c=Canvas(23,36)
            for x in (0,22):c.box(x,0,1,36,'gold2')
            for y in (0,35):c.box(0,y,23,1,'gold3')
            c.paste(icon('memory',10),7,13)
            return c
        if n=='tunnel_shutter':
            c=Canvas(21,34,'steel0')
            for y in range(1,34,5):c.box(1,y,19,1,'steel2');c.box(1,y+1,19,2,'steel1')
            c.bevel(7,15,8,6,'red',1)
            return c
        if n=='learning_attachment':
            c=Canvas(160,320)
            for x in (30,62,94):
                c.box(x,170,2,30,'gold1')
                for y in (174,182,190):c.box(x,y,2,1,'gold3')
            c.bevel(122,181,18,19,'steel',1);c.paste(icon('book',18),122,178)
            return c
        if n=='augments':
            frames=[]
            for k in range(3):
                c=Canvas(160,320)
                for x in (48,74,100)[:k+1]:c.bevel(x,260,21,21,'bone',1)
                frames.append(c)
            return sheet(frames)
        if n=='apertures':
            c=Canvas(160,320,'white')
            for x in (33,65,97):c.box(x,169,21,34,None)
            return c
        if n=='restore_ready':
            frames=[]
            for k in range(2):
                c=Canvas(160,320);c.box(98,162,19,1,'green3' if k==0 else 'steel0');frames.append(c)
            return sheet(frames)
        if n in ('stash','shelf_labels','dealer_tips'):
            c=Canvas(160,320)
            if n=='shelf_labels':c.text('SPINS',27,227,'green4')
            if n=='dealer_tips':c.paste(icon('tip',8),66,94)
            return c
        if n.startswith('wealth_'):
            if n=='wealth_digits_detail':
                frames=[]
                for digit in (0,9,7,8,6,5,4,3,2,1,0):
                    c=Canvas(10,14,'green0');c.box(1,1,8,12,'void');c.text(str(digit),2,2,'cyan',2);frames.append(c)
                return sheet(frames)
            c=Canvas(160,320)
            if n in ('wealth_crt_detail','wealth_crt','wealth_cases','wealth_cases_detail'):
                c.bevel(42,254,52,22,'steel',2);c.box(44,256,48,18,'green0')
                for x in (45,57,69,81):
                    c.bevel(x-1,257,12,16,'gold',1)
                    c.box(x,258,10,14,None if n in ('wealth_crt_detail','wealth_crt') else 'void')
            else:
                frames=[]
                for digit in (0,9,7,8,6,5,4,3,2,1,0):
                    f=Canvas(160,320);f.text(str(digit),46,260,'cyan',2);frames.append(f)
                return sheet(frames)
            return c
        if n.startswith('multiplier_'):
            frames=[]
            for k in range(max(1,w//160)):
                c=Canvas(160,320)
                for x in (78+k%4,92,107-k%4):
                    c.poly([(x+9,61),(x+7,58),(x+9,54),(x+11,59)],'red4')
                frames.append(c)
            return sheet(frames)
        raise ValueError(f'No machine recipe for {rel}')
    if rel.startswith('symbols/'):
        if n=='symbols_painted':
            c=Canvas(72,72)
            for i,symbol in enumerate(('brain','eye','pill','syringe','vial','flatline','heart x1','heart x2','heart x3')):c.paste(icon(symbol),i%3*24,i//3*24)
            return c
        return icon(n,16)
    if rel.startswith('powers/'):return icon(n,24)
    if rel.startswith('items/generated/') or rel.startswith('cards/painted/'):
        if n.endswith('_painted'):return None
        return icon(n,24)
    if rel.startswith('ui/premium/') and n in ('normal','hover','pressed','disabled','settings','left','right','close','confirm','coin'):
        return ui.graphic(n,size)
    return None


def export(rel,drawing,size,records):
    if drawing is None:return
    if isinstance(drawing,Canvas):drawing=drawing.image
    # Every export repeats each authored pixel by the SAME integer on both axes.
    # Fixed atlases retain their original 1x/2x/4x/8x contracts; loose paintings
    # become pixel-grid masters rather than inheriting arbitrary photo dimensions.
    factor=max(1,min(8,round(min(size[0]/drawing.width,size[1]/drawing.height))))
    size=(drawing.width*factor,drawing.height*factor)
    target=OUT/Path(rel).with_suffix('.png')
    target.parent.mkdir(parents=True,exist_ok=True)
    buffer=io.BytesIO()
    scaled(drawing,size).save(buffer,format='PNG',optimize=True)
    encoded=buffer.getvalue()
    if not target.exists() or target.read_bytes()!=encoded:
        target.write_bytes(encoded)
    key=str(Path(rel).as_posix())
    records[key]={'path':target.relative_to(ART).as_posix(),'source_grid':list(drawing.size),'export_size':list(size)}
    # Godot imports generated rasters losslessly, with no mipmap blending.
    sidecar=target.with_suffix('.png.import')
    if sidecar.exists():
        text=sidecar.read_text(encoding='utf8').replace('mipmaps/generate=true','mipmaps/generate=false')
        sidecar.write_text(text,encoding='utf8')


def all_recipe(rel,size):
    p=Path(rel);n=p.stem.lower();w,h=size
    drawn=machine_recipe(rel,size)
    if drawn is not None:return drawn
    family=p.parts[0]
    if family=='machine new view':return legacy.machine_legacy(n,size)
    if family=='upgrade_scene':
        split='split' in p.parts
        kind=n.replace('upgrades_scene_','')
        frame=0
        if split:kind,frame=kind.rsplit('_',1);frame=int(frame)
        return rooms.lab(kind,frame) if split else sheet([rooms.lab(kind,k) for k in range(w//1280)])
    if family in ('pacte_polished','pacte_scene'):
        if 'deck' in n:
            if n=='decks_painted':return sheet([ui.deck(),ui.deck(True)])
            return ui.deck('power' in n)
        if 'cards_' in n:
            return sheet([ui.card(),ui.card(False,True),ui.card(True),ui.card(True,True)])
        if n=='items_painted':
            c=Canvas(72,72)
            for k,name in enumerate(('tea','serum','tobacco','potion','white_powder','cocktail','water','red_pill','energy_drink')):c.paste(icon(name),k%3*24,k//3*24)
            return c
        if n in ('pacte_scene_native','pacte_scene_painted','pacte_scene','bg'):return rooms.pacte()
        if n=='dealer':
            c=Canvas(160,320);c.paste(machine.dealer(64,93),48,14);return c
        if n=='table':
            c=Canvas(160,320);rooms.felt(c,111,308);return c
        if n=='dealer_bubble':
            frames=[]
            for k in range(2):
                c=Canvas(160,320);c.text('CHOOSE',115,25,'red4',center=True);c.text('AUGMENT' if k==0 else 'POWER',115,32,'red4',center=True);frames.append(c)
            return sheet(frames)
        if n in ('augment_card','power_card','pacte_scene_augment_card','pacte_scene_power_card'):
            frames=[]
            for k in range(2):
                c=Canvas(160,320);x=25 if 'augment' in n else 110
                c.bevel(x,219,25,35,'gold' if k else 'steel',1);c.box(x+1,220,23,33,None);frames.append(c)
            return sheet(frames)
        if n=='proposition':
            c=Canvas(160,320)
            for x in (7,61,114):c.box(x,148,39,61,'green0')
            return c
        if n=='pacte_scene_selected_card':
            frames=[]
            for k in range(3):
                c=Canvas(160,320);c.bevel((7,61,114)[k]-1,147,41,63,'gold',1);c.box((7,61,114)[k],148,39,61,None);frames.append(c)
            return sheet(frames)
        raise ValueError(rel)
    if family=='cards':
        if n=='augment_cards':return legacy.card_atlas()
        if n=='power_cards':return legacy.card_atlas(True)
        if n in ('augments_painted','powers_painted'):
            names=('reward_1','smart_saving','hallucination','brain','joker','combo','tunnel_vision','adrenaline','passive_gain') if n.startswith('aug') else ('reroll','shift','memory','rewind','heart','cheat','swap','power_coin')
            c=Canvas(96,72)
            for k,name in enumerate(names):c.paste(icon(name),k%4*24,k//4*24)
            return c
        raise ValueError(rel)
    if family=='items':
        if n in ('chips_upgrade','chips_detail'):
            names=('discount','chip_discount','symbol_level','spins','offer','specialist','tip','reserve')
            if n=='chips_upgrade':names=names[:6]
            c=Canvas(32*len(names),32)
            for k,name in enumerate(names):c.paste(icon(name),k*32+4,4)
            return c
        if n=='consumable_placeholder':return icon('potion')
        return icon(n)
    if family in ('dealer_choice','dealer_choice_polished'):
        if n=='doors':
            c=Canvas(124,470)
            for y in range(5):
                for x in range(2):c.paste(legacy.route_door(y*2+x),x*62,y*94)
            return c
        if n=='dealer_choice_doors':
            frames=[]
            for k in range(5):
                c=Canvas(64,96);c.bevel(0,0,64,96,'red',2);c.bevel(4,4,56,88,'gold',1);c.box(6,6,52,84,'green0');c.paste(icon(('coin','brain','syringe','heart','memory')[k],20),22,20);frames.append(c)
            return sheet(frames)
        if n=='bubble_text':
            c=Canvas(160,320);c.bevel(101,170,47,29,'gold',2);c.box(104,173,41,23,'green0');return c
        if n=='reroll':return ui.graphic('route_reroll_brass',size)
        return rooms.route()
    if family in ('dealer_shop','dealer_shop_polished'):
        if n in ('pre_dealer_shop_native','pre_dealer_shop_painted'):return rooms.shop()
        if n in ('bg','dealer_shop_bg','dealer_shop_bg_x8'):
            c=Canvas(200,380,'void');room=rooms.architecture();rooms.bottles(room);c.paste(room,20,30);return c
        if 'counter' in n:
            c=Canvas(200,380);drawn=rooms.shop().image;c.paste(drawn.crop((0,173,160,320)),20,203)
            return sheet([c,c]) if w/h==1 else c
        if 'machine' in n or 'reroll' in n or 'lab' in n:
            frames=[]
            for k in range(2):
                c=Canvas(200,380);x,y=(140,35) if 'machine' in n else (20,94) if 'reroll' in n else (26,288)
                c.paste(ui.button(36,42,k),x,y)
                if 'machine' in n:
                    # Three reel windows identify the destination without reusing a lock.
                    c.bevel(x+7,y+9,22,27,'red',1);c.box(x+10,y+12,16,8,'green0')
                    for xx in (x+10,x+16,x+22):c.box(xx,y+23,4,6,'bone2')
                    c.box(x+15,y+31,7,2,'gold3')
                else:c.paste(icon('brain' if 'lab' in n else 'reroll',20),x+8,y+11)
                frames.append(c)
            return sheet(frames)
        raise ValueError(rel)
    if family=='dealer_offer_polished':
        if n=='portrait':return machine.dealer(64,96,hands=False)
        c=Canvas(96,48)
        for mirror in (0,1):
            x=4 if mirror==0 else 63
            c.poly([(x,44),(x+3,16),(x+10,5),(x+14,8),(x+11,20),(x+16,15),(x+20,16),(x+21,32),(x+27,43)],'green1')
            for xx in (x+6,x+11,x+17):c.line([(xx,36),(xx+1,19)],'green3')
        return c
    if family=='settings_polished':return rooms.audio_console()
    if family=='options_polished':return rooms.options()
    if family=='presentation':return rooms.backdrop()
    if family=='start_menu':return legacy.menu(n)
    if family=='scores_polished':
        if n=='ledger':return ui.ledger()
        if n=='suits':return suit_sheet(32)
        raise ValueError(rel)
    if family=='SCORES':
        if n=='scores':return ui.ledger()
        if n=='scores_symbols':
            frames=[]
            for k,name in enumerate(('none','heart','diamond','spade','club','joker')):
                c=Canvas(160,320);c.paste(ui.suit(name,16),72,151);frames.append(c)
            return sheet(frames)
        c=Canvas(160,320);c.paste(ui.control('left'),39,145);c.paste(ui.control('right'),104,145);return c
    if family=='odd_tab':
        kind=n.replace('odd-table_','').replace('_brass','')
        kind={'odd-table':'table','levels':'levels','buttons':'buttons','augment_level':'augment_level'}.get(kind,kind)
        frames={'table':1,'buttons':3,'augment_level':3,'level':9,'levels':10,'tokens':10,'costs':1}[kind]
        return sheet([ui.odds(kind,k) for k in range(frames)])
    if family=='TABLE':
        c=Canvas(160,280);c.bevel(0,0,160,280,'gold',2);c.box(3,3,154,274,'green0')
        c.text('PAYOUTS',80,12,'gold3',2,True)
        for k,(name,pair,triple) in enumerate((('brain',20,200),('eye',10,50),('pill',7,35),('syringe',5,25),('vial',3,15),('book',5,15),('flatline',0,0))):
            yy=37+k*29;c.paste(icon(name,22),9,yy);c.text(name,36,yy+3,'bone2');c.text(str(pair),99,yy+10,'cyan');c.text(str(triple),125,yy+10,'gold3')
        return c
    if family=='ui':
        original=p.stem
        if n in ('buttons_painted','icons_painted'):
            c=Canvas(96,60)
            for k,name in enumerate(('settings','left','right','close','confirm','coin')):c.paste(ui.control(name) if name!='coin' else icon('coin',16),k%6*16,0)
            c.paste(ui.button(),0,24);return c
        if n=='dealer_portrait':return machine.dealer(32,48,hands=False)
        if n in ('symbol_chosing','symbol_chosing_unsclaed'):return ui.graphic('symbol_picker_brass',size)
        if n in ('green_button','red_button'):return sheet([ui.button(32,12,k) for k in range(3)])
        if n in ('cancel_button','valid_button','settings') and len(p.parts)==2:
            width=w//2;return sheet([ui.button(width,h,k) for k in range(2)])
        if n=='arrow_button':
            return sheet([_arrow(k) for k in range(3)])
        if n.startswith('neon_small_'):return sheet([ui.button(15,22,k) for k in range(3)])
        if n in ('coin_cumulable','consumable_placeholder'):return icon('coin' if n.startswith('coin') else 'potion')
        return ui.graphic(original if original in ('EN','FR') else n,size)
    if len(p.parts)==1:
        if n in ('1st_neuron_death','2nd_neuron_death','3rd_neuron_death'):
            loss=int(n[0])-1;return sheet([legacy.neurons(loss=loss,death_frame=k) for k in range(3)])
        if n=='neurons_animation':return sheet([legacy.neurons(k) for k in range(34)])
        if n=='neurons_meter':return legacy.neurons()
        if n=='bg_black':return Canvas(160,240,'void')
        if n=='sacrifice_ritual':return rooms.sacrifice()
        if n=='dealer_portrait':
            frames=[]
            for k in range(2):
                c=Canvas(160,320);c.paste(machine.dealer(64,96,talk=k,hands=False),48,58);frames.append(c)
            return sheet(frames)
        if n=='dealer':
            frames=[]
            for k in range(2):
                c=Canvas(200,380);c.paste(machine.dealer(84,119,talk=k),58,86);frames.append(c)
            return sheet(frames)
        if n=='dealer_hands':
            c=Canvas(128,64);c.paste(machine.dealer(70,100).crop((0,75,70,100)),29,20);return c
        if n.startswith('dealer_scene_'):
            return all_recipe('dealer_shop/'+n.replace('dealer_scene_','dealer_shop_')+'.png',size)
        if n=='dealer_shop_bg':return rooms.shop()
        if n=='dealer_shop_counter':return all_recipe('dealer_shop/counter.png',size)
        if n=='machine_normal':return machine.cabinet()
        if n=='stash_tray':return ui.graphic('stash_tray',size)
    raise ValueError('Unassigned pixel asset: '+rel)


def _arrow(frame):
    c=Canvas(13,24);c.bevel(0,0,13,24,'gold' if frame else 'steel',1);c.poly([(3,12),(9,6),(9,18)],'bone2');return c


def suit_sheet(size):
    frames=[]
    for name in ('none','heart','diamond','spade','club','joker'):
        c=Canvas(size,size);c.paste(ui.suit(name,size),0,0);frames.append(c)
    return sheet(frames)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--family',choices=['machine','all'],default='all')
    args=parser.parse_args()
    records={}
    if args.family=='machine':
        manifest=OUT/'manifest.json'
        if not manifest.exists():
            parser.error('Generate the complete set once before rebuilding a single family')
        records=json.loads(manifest.read_text(encoding='utf8'))
    contracts=json.loads((ROOT/'tools/pixel_art/contracts.json').read_text())
    for rel,size in contracts.items():
        size=tuple(size)
        drawing=machine_recipe(rel,size) if args.family=='machine' else all_recipe(rel,size)
        if drawing is None:continue
        export(rel,drawing,size,records)
    MANIFEST.parent.mkdir(parents=True,exist_ok=True)
    lines=['extends RefCounted','', '## Generated by tools/generate_pixel_art.py. Source pixels are authored in code.', 'const TEXTURES: Dictionary = {']
    lines.extend('\t%s: %s,'%(json.dumps(key),json.dumps(value['path'])) for key,value in records.items())
    lines.append('}\n')
    write_text_if_changed(MANIFEST,'\n'.join(lines))
    write_text_if_changed(OUT/'manifest.json',json.dumps(records,indent=2)+'\n')
    if args.family=='all':font.generate(ROOT)
    print(f'Generated {len(records)} pixel assets from code; no source artwork sampled')


if __name__=='__main__':main()
