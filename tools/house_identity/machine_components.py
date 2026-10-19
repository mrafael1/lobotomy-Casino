"""Individually authored v1 symbol, control, inventory and indicator sprites."""
from .pixels import Pixel, rgba, symbol, item_badge
from .console import reel_symbol, gem_socket
from .cards import CARDS
from .machine_geometry import REEL_W, REEL_H

POWERS={'reroll':'REROLL','shift':'SHIFT','memory':'LOCK','rewind':'REWIND',
        'heart':'HEART','cheat':'CHEAT','swap':'SWAP'}
ITEMS={'cons_cigarette':'T','cons_focus':'S','cons_white_powder':'powder',
       'cons_potion':'P','cons_tea':'tea','item_energy_drink':'E',
       'item_cocktail':'C','item_water':'water','item_pill':'pill'}
SYMBOLS=('brain','eye','pill','syringe','vial','flatline','book','heart_x1','heart_x2','heart_x3')


def production_symbol(kind):
    if kind in ('brain','eye'):return reel_symbol(kind)
    p=Pixel(58,66)
    if kind=='pill':
        p.contour((12,18),[((19,9),(27,11),(33,18)),((39,24),(45,30),(48,36)),
                            ((53,44),(44,56),(36,53)),((27,49),(18,39),(11,32)),
                            ((7,27),(8,22),(12,18))],'ruby0')
        p.contour((14,19),[((20,13),(26,14),(31,20)),((35,24),(40,29),(44,35)),
                            ((49,42),(43,51),(37,50)),((29,46),(20,36),(13,30)),
                            ((10,26),(10,23),(14,19))],'ruby2')
        p.contour((14,19),[((20,13),(26,14),(31,20)),((33,22),(35,24),(36,26)),
                            ((33,33),(28,37),(23,39)),((18,34),(13,29),(12,27)),
                            ((10,24),(11,22),(14,19))],'cream2')
        p.contour((16,19),[((22,15),(25,16),(29,20))],'cream3',stroke=3)
        p.contour((26,40),[((32,37),(36,32),(38,28))],'gold1',stroke=2)
        p.contour((31,42),[((35,45),(39,48),(42,46))],'ruby3',stroke=3)
        p.fine_line([(76,65),(83,75),(85,81)],'ruby4')
    elif kind=='syringe':
        p.line([(29,3),(29,13)],'cold2');p.fine_line([(59,6),(59,25)],'cream3')
        p.box(22,13,15,4,'gold1');p.box(24,14,11,3,'gold3')
        p.poly([(21,19),(37,19),(37,45),(34,48),(24,48),(21,45)],'cold0')
        p.box(23,20,12,25,'cold1');p.box(25,20,4,24,'cold3')
        p.box(29,29,5,14,'jade2');p.box(25,29,4,14,'jade3')
        p.fine_line([(47,43),(47,84)],'cream3')
        for y in (23,28,33,38):p.line([(31,y),(35,y)],'cold0')
        p.box(17,47,24,4,'gold0');p.box(18,47,22,2,'gold3')
        p.box(27,51,5,8,'cold2');p.box(22,59,15,4,'gold1');p.line([(22,59),(36,59)],'gold3')
    elif kind=='vial':
        p.box(20,7,19,9,'gold0');p.box(21,7,17,2,'gold3')
        p.box(21,10,17,3,'gold2');p.line([(21,14),(37,14)],'gold1')
        p.contour((21,16),[((23,24),(14,23),(13,31)),((13,39),(11,51),(17,55)),
                            ((24,59),(38,58),(43,54)),((47,48),(44,37),(44,31)),
                            ((43,24),(35,24),(37,16))],'cold0')
        p.contour((23,17),[((26,26),(17,26),(16,32)),((16,40),(14,49),(19,53)),
                            ((26,57),(37,55),(40,52)),((44,47),(41,36),(41,32)),
                            ((40,26),(32,25),(35,17))],'cold1')
        p.contour((18,38),[((24,40),(34,40),(41,37)),((41,43),(42,49),(38,52)),
                            ((31,55),(22,55),(18,51))],'jade2')
        p.line([(18,32),(17,45),(19,49)],'cold3',2)
        p.box(23,34,15,15,'cream1');p.box(25,36,11,11,'cream2')
        p.line([(28,39),(33,39),(33,42),(28,42),(28,39)],'gold1')
        p.fine_line([(75,57),(78,62),(80,80)],'cold2')
    elif kind=='book':
        p.poly([(5,17),(24,12),(30,16),(50,11),(52,51),(31,58),(26,54),(6,59)],'wood1')
        p.poly([(6,16),(24,13),(29,18),(48,13),(49,49),(30,55),(25,51),(7,55)],'paper0')
        p.contour((8,16),[((15,13),(22,12),(27,17)),((26,28),(26,42),(27,51)),
                           ((20,47),(14,52),(8,53))],'paper2')
        p.contour((29,18),[((34,16),(40,13),(47,14)),((47,25),(47,39),(47,48)),
                            ((41,49),(36,51),(29,53))],'paper1')
        for y in range(21,48,5):
            p.line([(11,y),(18,y-2),(23,y-2)],'paper0')
            p.line([(33,y+1),(43,y-2)],'paper0')
        p.fine_line([(18,34),(18,98)],'paper3')
        p.line([(27,18),(28,51)],'wood2')
        p.poly([(38,17),(41,16),(41,56),(39,54),(37,57)],'ruby2')
        p.line([(9,56),(24,53)],'gold1')
    elif kind=='flatline':
        p.line([(3,32),(16,32),(22,23),(31,45),(37,32),(55,32)],'jade0',4)
        p.line([(3,31),(16,31),(22,22),(31,44),(37,31),(55,31)],'jade3',2)
        p.fine_line([(8,60),(31,60),(44,42),(62,86),(74,60),(108,60)],'jade4')
    else:raise ValueError(kind)
    return p


def heart_symbol(tier):
    p=Pixel(58,66)
    # A complete heart silhouette at every tier; side jewels encode the tier
    # without depending on tiny text inside a moving symbol.
    p.contour((29,53),[((21,46),(5,36),(6,23)),((7,10),(22,9),(29,20)),
                        ((36,9),(51,10),(52,23)),((53,36),(37,46),(29,53))],'ruby0')
    p.contour((29,48),[((20,41),(10,33),(10,24)),((10,15),(23,14),(29,25)),
                        ((35,14),(48,15),(48,24)),((48,33),(38,41),(29,48))],'ruby3')
    p.contour((15,25),[((14,17),(22,17),(25,23))],'ruby4',stroke=3)
    p.line([(15,31),(23,31),(27,25),(32,37),(36,29),(43,29)],'cream3',2)
    for i in range(tier):
        x=29-(tier-1)*5+i*10
        p.poly([(x,55),(x+3,58),(x,61),(x-3,58)],'gold3')
        p.box(x,56,1,2,'cream3')
    return p


def item(kind):
    p=Pixel(16,16)
    if len(kind)==1:item_badge(p,kind,0,0)
    elif kind=='water':
        p.box(6,0,5,3,'gold2');p.box(6,3,5,3,'cold2')
        p.poly([(6,5),(11,5),(13,8),(13,14),(11,15),(4,15),(3,13),(3,8)],'cold1')
        p.box(5,9,7,5,'jade2');p.line([(4,8),(4,13)],'cream3');p.box(7,10,3,3,'paper2')
    elif kind=='pill':
        p.poly([(2,7),(7,2),(10,2),(14,6),(14,9),(9,14),(6,14),(2,10)],'ruby0')
        p.poly([(3,7),(7,3),(9,3),(12,6),(7,11),(3,9)],'ruby3')
        p.poly([(7,11),(12,6),(13,7),(13,9),(9,13),(7,13)],'ruby1')
        p.line([(4,7),(7,4),(9,4)],'ruby4')
    elif kind=='tea':
        p.arc((9,6,15,12),240,120,'gold3',2)
        p.poly([(2,6),(12,6),(11,12),(8,14),(5,13),(3,11)],'cream1')
        p.oval(2,5,11,4,'gold1');p.line([(4,6),(10,6)],'wood2')
        p.line([(1,15),(13,15)],'gold3');p.line([(6,4),(5,2),(6,0)],'cold2')
    elif kind=='powder':
        p.poly([(1,3),(11,1),(15,11),(5,15)],'paper0')
        p.poly([(2,3),(10,2),(12,7),(6,11)],'paper3')
        p.poly([(6,11),(12,7),(14,11),(5,14)],'paper1')
        p.line([(3,4),(6,11),(5,14)],'paper2');p.box(8,6,3,2,'cream3')
    else:raise ValueError(kind)
    return p


def sticker(key,frame=0):
    p=Pixel(21,15)
    p.poly([(0,0),(19,1),(20,14),(1,13)],'paper1')
    ink='ruby0';light='paper3'
    if key=='augment_book':
        p.line([(4,4),(10,3),(10,11),(4,12),(4,4),(10,6),(16,4),(16,11),(10,12)],ink)
    elif key=='augment_pattern_recognition':
        shifts=((0,0,0),(0,1,0),(1,0,1),(1,1,0),(0,1,1))[frame%5]
        for i,x in enumerate((4,10,16)):p.box(x,4+shifts[i],3,6,ink)
        p.line([(4,11),(17,11)],'gold1')
    elif key=='augment_hallucination':
        for x in (4,10):
            p.poly([(x,7),(x+4,4),(x+8,7),(x+4,10)],ink);p.box(x+4,6,1,3,light)
    elif key=='augment_smart_saving':
        p.box(4,3,13,9,ink);p.box(6,5,9,1,light);p.oval(11,7,4,4,'gold2')
    elif key.startswith('augment_reward_'):
        tier=int(key[-1])
        if tier==1:p.oval(4,3,8,8,ink);p.oval(6,5,4,4,light);p.line([(11,10),(16,13)],ink,2)
        elif tier==2:p.line([(3,11),(17,11),(14,4),(8,4),(8,9)],ink,2);p.box(5,6,3,3,'gold1')
        else:p.poly([(3,4),(7,7),(10,2),(13,7),(17,4),(15,12),(5,12)],ink)
    elif key=='augment_joker':
        p.poly([(3,9),(5,3),(10,7),(15,3),(17,9),(10,12)],ink)
        for x in (4,15):p.box(x,2,2,2,'gold2')
    elif key=='augment_win_boost':
        for i in range(3):p.box(3+i*5,10-i*3,4,3+i*3,ink)
    elif key=='augment_glitch_2':
        for x,y,w in ((3,3,7),(12,5,5),(5,8,8),(12,11,5)):p.box(x,y,w,1,ink)
    elif key=='augment_tunnel_vision':
        p.box(3,3,4,9,ink);p.box(14,3,4,9,ink);p.poly([(8,7),(10,5),(13,7),(10,10)],ink)
    elif key=='augment_how_to_cheat':
        dx=(0,2,4,2)[frame%4]
        p.box(3,3,8,8,ink);p.box(8+dx,5,8,8,'paper0')
        p.line([(10+dx,7),(14+dx,7),(14+dx,11)],ink)
    elif key=='augment_adrenaline':
        p.poly([(12,2),(5,8),(9,8),(7,13),(16,6),(11,6)],ink)
    elif key=='augment_passive_gain':
        p.line([(10,2),(10,7)],ink);p.oval(7,8,6,5,'gold1');p.line([(5,4),(15,4)],ink)
    else:raise ValueError(key)
    p.box(1,12,2,1,'paper0')
    return p


def build_components(package):
    result={'symbols':{},'powers':{},'items':{},'augments':{},'reel_overlays':{},'indicators':{}}
    for key in SYMBOLS:
        p=heart_symbol(int(key[-1])) if key.startswith('heart_') else production_symbol(key)
        result['symbols'][key]={'canvas_source_size':[116,132],**package.sprite(p.im,key,'symbols')}
    for tier in (1,2,3):
        controls={}
        for key,label in POWERS.items():
            states={}
            for state in ('ready','selected','pressed','spent','restored'):
                p=Pixel(64,48)
                gem_socket(p,32,4+(2 if state=='pressed' else 0),label,tier,label=False)
                if state=='spent':
                    # A cold unpowered lens, with its owned power still legible.
                    materials={'jade0':'glass0','jade1':'cold0','jade2':'cold1',
                        'jade3':'cold2','jade4':'cold3','cream3':'cold3',
                        'hot_glass0':'glass0','hot_glass1':'cold0','hot_glass2':'cold1',
                        'heat3':'cold2','heat5':'cold3'}
                    mapping={rgba(c):rgba(target) for c,target in materials.items()}
                    p.im.putdata([mapping.get(c,c) for c in p.im.getdata()])
                if state=='selected':
                    for x,d in ((3,1),(60,-1)):
                        for y,dy in ((1,1),(45,-1)):
                            p.line([(x,y+5*dy),(x,y),(x+5*d,y)],'cream3')
                if state=='restored':
                    p.arc((4,2,60,45),185,345,'heat_white',2)
                    p.line([(54,0),(54,8)],'cream3');p.line([(50,4),(58,4)],'cream3')
                states[state]={'canvas_source_size':[128,96],**package.sprite(p.im,f'{key}_{state}_x{tier}','powers')}
            controls[key]=states
        result['powers'][f'x{tier}']=controls
    for key,kind in ITEMS.items():
        p=item(kind)
        result['items'][key]={'canvas_source_size':[32,32],**package.sprite(p.im,key,'items')}
    for key,_,family,_ in CARDS:
        if family!='augment':continue
        count=5 if key=='augment_pattern_recognition' else 4 if key=='augment_how_to_cheat' else 1
        result['augments'][key]={'frame_ms':[210]*5 if count==5 else [1000,120,520,120] if count==4 else [0],
            'frames':[{'canvas_source_size':[42,30],**package.sprite(sticker(key,i).im,f'{key}_{i}','augments')} for i in range(count)]}
    for kind in ('selected','locked','swap_source','hidden'):
        p=Pixel(REEL_W,REEL_H)
        if kind=='hidden':
            p.box(0,0,REEL_W,REEL_H,'gold0')
            for y in range(0,REEL_H,7):
                p.box(1,y,56,5,'gold1');p.line([(1,y),(56,y)],'gold2')
            p.box(25,47,8,12,'ruby0');p.box(28,50,2,6,'gold3')
        elif kind=='locked':
            for y in (12,91):
                p.box(0,y,58,4,'gold0');p.line([(0,y),(57,y)],'gold3')
            p.arc((23,43,35,57),180,360,'gold3',2);p.box(21,51,17,13,'gold2');p.box(28,55,3,5,'ruby0')
        elif kind=='swap_source':
            p.line([(16,40),(42,66)],'ruby0',5);p.line([(42,40),(16,66)],'ruby0',5)
            p.line([(16,40),(42,66)],'red',2);p.line([(42,40),(16,66)],'red',2)
        else:
            for x,d in ((1,1),(56,-1)):
                for y,dy in ((1,1),(104,-1)):p.line([(x,y+9*dy),(x,y),(x+9*d,y)],'jade4',2)
        result['reel_overlays'][kind]={'canvas_source_size':[REEL_W*2,REEL_H*2],**package.sprite(p.im,kind,'reel_overlays')}
    for state in ('off','on','restored'):
        p=Pixel(12,5)
        p.oval(0,1,12,3,'membrane0' if state=='off' else 'jade3' if state=='on' else 'heat_white')
        result['indicators'][f'restore_{state}']=package.sprite(p.im,f'restore_{state}','indicators')
    for state in ('inactive','active','warning'):
        p=Pixel(9,5)
        p.box(0,1,9,3,'ruby1' if state=='inactive' else 'gold3' if state=='active' else 'red')
        result['indicators'][f'countdown_{state}']=package.sprite(p.im,f'countdown_{state}','indicators')
    for state in ('alive','lost_1','lost_2','lost_3'):
        p=Pixel(9,12);step=0 if state=='alive' else int(state[-1])
        p.oval(0,step,9,12-step*2,'paper1' if step==0 else 'wine1')
        p.fine_line([(5,4+step),(2,9),(6,15-step),(4,21-step*2)],'skin1')
        result['indicators'][f'neuron_{state}']=package.sprite(p.im,f'neuron_{state}','indicators')
    return result
