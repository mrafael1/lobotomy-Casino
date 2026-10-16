"""Explicit recipes for old atlas contracts and authored animation families."""
import math
import re
from pathlib import Path
from .core import Canvas, icon, scaled, sheet
from . import machine, rooms, ui


def neurons(frame=0,loss=-1,death_frame=0):
    c=Canvas(64,64)
    for i,x in enumerate((11,31,51)):
        dead=i==loss
        if loss>=0 and not dead:continue
        col='steel1' if dead and death_frame==2 else 'green3'
        for dx,dy in [(-7,-9),(1,-12),(8,-8),(-10,1),(10,4),(-6,10),(3,11)]:
            c.line([(x,31),(x+dx,31+dy),(x+dx+(-2 if dx<0 else 2),32+dy)],'green1' if not dead else 'red1')
        c.ellipse(x-5,26,11,11,'ink');c.ellipse(x-4,27,9,9,col)
        c.ellipse(x-2,29,4,4,'green0' if not dead else 'red2')
        if not dead and abs(frame-(i*10+5))<3:c.box(x-1,28,2,2,'cyan')
        if dead:
            if death_frame==0:c.line([(x-5,25),(x+5,37)],'red4',2)
            elif death_frame==1:
                for dx,dy in [(-7,-4),(4,-7),(8,3),(-4,8)]:c.box(x+dx,31+dy,2,2,'red4')
            else:c.line([(x-4,29),(x+3,34)],'red0')
    if loss<0:
        # A signal walks the dendrite network without moving the three cells.
        x=8+round(frame*46/33)
        y=31+(0,1,1,0,-1,-1)[frame%6]
        c.box(x,y,2,1,'cyan')
    return c


def card_atlas(power=False):
    c=Canvas(351 if power else 273,61 if power else 915)
    if power:
        c.paste(ui.card(True,True),0,0);c.paste(ui.card(True),39,0)
        for i,name in enumerate(('reroll','shift','memory','rewind','heart','cheat','swap'),2):
            c.paste(ui.card(True),i*39,0);c.paste(icon(name,20),i*39+9,22)
    else:
        c.paste(ui.card(False,True),0,0);c.paste(ui.card(),0,61)
        names=['reward_1','reward_2','reward_3','smart_saving','hallucination','pattern_recognition','book','joker','combo','tunnel_vision','how_to_cheat','adrenaline','passive_gain']
        for row,name in enumerate(names,2):
            for col in range(7):
                c.paste(ui.card(),col*39,row*61)
        # Shared metadata is the authoritative crop contract, including animation.
        source=(Path(__file__).resolve().parents[2]/'godot/rules/pacte_cards.gd').read_text()
        for block in re.findall(r'\{\s*"id":.*?\n\t\},',source,re.S):
            ident=re.search(r'"id": "([^"]+)"',block)
            bounds=re.search(r'"icon_rect": Rect2\(([^)]+)\)',block)
            if not ident or not bounds or ident.group(1) in ('reroll','shift','memory','rewind','heart','cheat','swap'):continue
            x,y,w,h=[round(float(v.strip())) for v in bounds.group(1).split(',')]
            art=scaled(icon(ident.group(1)),(w,h));c.paste(art,x,y)
        # Five pattern frames and seven ascending solo-symbol frames are kept.
        for k in range(5):c.paste(scaled(icon('pattern_recognition',24,k),(30,18)),5+k*39,144)
        for k,(x,y) in enumerate(((10,744),(49,748),(88,751),(127,754),(166,758),(205,761),(244,763))):
            motion=Canvas(18,20)
            motion.paste(scaled(icon('how_to_cheat'),(16,17)),1,(0,1,2,3,2,1,0)[k])
            c.paste(motion,x,y)
    return c


def machine_legacy(n,size):
    w,h=size
    full_frames=max(1,round(w/h*2))
    if n=='power_bar':
        c=Canvas(480,640)
        for k in range(6):c.paste(machine.lamps(min(k,3)),k%3*160,k//3*320)
        return c
    if n=='shift_power':
        c=Canvas(480,960)
        for row,x in enumerate((33,65,97)):
            for state in range(3):
                frame=Canvas(160,320)
                col='cyan' if state==1 else 'gold3' if state==0 else 'steel1'
                frame.poly([(x+10,164),(x+6,168),(x+14,168)],col)
                frame.poly([(x+10,208),(x+6,204),(x+14,204)],col)
                c.paste(frame,state*160,row*320)
        return c
    if n in ('machine_neon','final_machine','machine_game_over','machine_normal'):
        return machine.cabinet(n in ('machine_game_over',))
    if n in ('reel_final_machine',):return machine.reels('drums')
    if n=='win_animation':return sheet([machine.callout('win',k) for k in range(2)])
    if n=='power_animation':return sheet([machine.callout('power',k) for k in range(7)])
    if n in ('2_losing_animation','3_losing_animation'):
        return sheet([machine.callout('loss_2' if n.startswith('2') else 'loss_3',k) for k in range(full_frames)])
    if 'dealer_bar' in n:
        overlay=int(n[-1]) if n[-1].isdigit() else 0
        return sheet([machine.dealer_bar(k,overlay) for k in range(full_frames)])
    if n in ('reroll','shift','lock','cheat_power','chip_power','rewind_power','move_power','reroll_final_machine','shift_final_machine','lock_final_machine','lock_power','shift_power'):
        name={'lock':'memory','lock_power':'memory','cheat_power':'cheat','chip_power':'heart','rewind_power':'rewind','move_power':'swap'}.get(n,n.split('_')[0])
        return sheet([machine.power(name,k%3) for k in range(full_frames)])
    if n in ('neon_machine_jackpot','jackpot_final_machine'):return sheet([machine.beacon(k) for k in range(full_frames)])
    if 'multiplier' in n:
        return sheet([machine.callout('multiplier',k) for k in range(full_frames)])
    if n in ('neon_machine_lever','lever_final_machine','spin_final_machine'):
        frames=[]
        for k in range(full_frames):
            c=Canvas(160,320);c.paste(machine.spin('pressed' if k%2 else 'normal'),53,213);frames.append(c)
        return sheet(frames)
    if n=='power coin animation':
        frames=[]
        for k in range(4):
            c=Canvas(160,320)
            ww,hh=((4,5),(6,7),(8,9),(8,9))[k]
            x=74-ww//2;y=(245,243,241,241)[k]
            c.ellipse(x,y,ww,hh,'green2');c.ellipse(x+1,y+1,ww-2,hh-2,'green3')
            c.box(73,y+2,2,max(1,hh-4),'cyan');frames.append(c)
        return sheet(frames)
    if n in ('health_chip_pile_prototype',):
        c=Canvas(64,16)
        for x in (2,14,26,38,50):c.paste(icon('heart',12),x,2)
        return c
    if n in ('health_bar','health_animation','health_fill_final_machine','health_track_final_machine'):
        frames=[]
        for k in range(full_frames):
            c=Canvas(160,320)
            c.bevel(22,213,30,19,'steel',1);c.box(24,215,26,15,'void')
            if 'track' not in n:c.text(str(k),30,218,'bone2',2)
            frames.append(c)
        return sheet(frames)
    if n=='water':
        frames=[]
        for k in range(3):
            c=Canvas(160,320);c.paste(icon('water',22),122-k*6,45+k*2)
            c.poly([(120-k*5,63),(118-k*5,89+k*6),(124-k*5,90+k*6)],'cyan');frames.append(c)
        return sheet(frames)
    if n=='cheat_selection':
        frames=[]
        for k in range(9):
            c=Canvas(160,320);x=(33,65,97)[k//3]
            c.bevel(x-1,168,23,36,'gold',1);c.box(x,169,21,34,None)
            if k%3:c.poly([(x+10,164 if k%3==1 else 208),(x+7,167 if k%3==1 else 205),(x+13,167 if k%3==1 else 205)],'cyan')
            frames.append(c)
        return sheet(frames)
    if n=='reel_selection':
        # Two columns by two rows of full-canvas targeting frames.
        out=Canvas(320,640)
        for k in range(4):
            c=Canvas(160,320)
            for x in (33,65,97):
                c.line([(x,170),(x,168),(x+4,168)],'cyan');c.line([(x+16,204),(x+21,204),(x+21,201)],'cyan')
            out.paste(c,k%2*160,k//2*320)
        return out
    if n in ('augments','combo_effect'):
        return sheet([machine.callout('combo',k) for k in range(full_frames)])
    if n in ('free_spin',):return machine.callout('free_spin')
    if n in ('neon_machine_power_bar','restore_cap'):
        return sheet([machine.lamps(k%4) for k in range(full_frames)])
    if n.startswith('wealth_'):
        frames=[]
        for k in range(full_frames):
            c=Canvas(160,320);c.bevel(73,64,45,15,'green',1)
            if 'track' not in n:c.text(str(k%10),78,67,'cyan',2)
            frames.append(c)
        return sheet(frames)
    if n.startswith('target_'):
        frames=[]
        for k in range(full_frames):
            c=Canvas(160,320)
            if n=='target_goals':c.text(str((100,200,500,800,1500,2500,3500,5000)[k%8]),96,49,'bone2',center=True)
            else:c.box(73,59,45,2,'green0');c.box(73,59,round(k/max(1,full_frames-1)*45),1,'green3')
            frames.append(c)
        return sheet(frames)
    if n=='dealer_tips':
        c=Canvas(160,320);c.paste(icon('tip',10),67,94);return c
    raise ValueError('Unknown legacy machine asset: '+n)


def route_door(frame=0):
    c=Canvas(62,94)
    # Hover art retains the 2-column × 5-row 62×94 frame contract.
    for x,y,w,h in [(0,0,1,94),(61,0,1,94),(0,0,62,1),(0,93,62,1)]:c.box(x,y,w,h,'gold3' if frame%2 else 'gold1')
    c.box(2,2,58,90,(0,0,0,0))
    if frame>1:c.line([(1,1),(60,1),(60,92)],'cyan')
    return c


def menu(n):
    c=Canvas(160,320)
    if n=='neon_casino_background':return rooms.backdrop()
    if n=='title':
        c.paste(ui.graphic('menu_title_plate',(148,66)),6,48);c.text('LOBOTOMY',80,67,'gold3',2,True);c.text('CASINO',80,83,'gold3',2,True)
        return c
    if n=='start_menu_start_button':c.paste(ui.button(140,25),10,143);return c
    if n in ('start_menu_score_button','start_menu_options_button'):
        frames=[]
        for k,y in enumerate((178,226) if 'score' in n else (213,262)):
            c=Canvas(160,320);c.paste(ui.button(103 if k else 101,25),29 if k else 30,y);frames.append(c)
        return sheet(frames)
    if n=='start_menu_augmented symbols':
        frames=[]
        for k,name in enumerate(('none','heart','diamond','spade','club','joker')):
            c=Canvas(160,320);c.paste(ui.suit(name,23),69,187);frames.append(c)
        return sheet(frames)
    if n=='start_menu_augmented_button':c.paste(ui.graphic('menu_selector_brass',(144,41)),8,176);return c
    if n=='start_menu_states_sheet':
        out=Canvas(160,640)
        for k in range(2):out.paste(rooms.backdrop(),0,k*320)
        return out
    raise ValueError(n)
