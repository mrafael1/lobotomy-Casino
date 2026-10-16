"""Pixel controls, card stock, odds ledger and suit silhouettes."""
from .core import Canvas, icon, scaled, sheet


def button(w=96,h=20,state=0):
    c=Canvas(w,h)
    c.bevel(0,0,w,h,'gold',2)
    c.box(3,3,w-6,h-6,'gold0')
    down=1 if state==2 else 0
    c.bevel(4,3+down,w-8,h-7,'bone' if state!=3 else 'steel',1)
    if state==1:c.line([(6,4),(w-7,4)],'white')
    c.box(w-5,5,1,h-10,'gold1')
    return c


def control(name):
    c=Canvas(16,16)
    c.bevel(1,1,14,14,'gold',2)
    c.box(3,3,10,10,'green0')
    if name=='settings':
        c.box(5,3,6,10,'steel2');c.box(3,5,10,6,'steel2');c.box(6,6,4,4,'ink');c.box(7,7,2,2,'gold3')
    elif name in ('left','right'):
        c.poly([(5,8),(10,4),(10,12)] if name=='left' else [(11,8),(6,4),(6,12)],'bone2')
    elif name=='close':
        c.line([(5,5),(10,10)],'bone2',2);c.line([(10,5),(5,10)],'bone2',2)
    elif name=='confirm':c.line([(4,8),(7,11),(12,5)],'cyan',2)
    return c


def card(power=False,back=False):
    c=Canvas(39,61)
    c.bevel(0,0,39,61,'gold',2)
    c.box(2,2,35,57,'bone0' if not back else 'red0' if power else 'green0')
    c.box(3,3,33,55,'bone2' if not back else 'red1' if power else 'green1')
    if back:
        c.line([(19,8),(31,30),(19,53),(7,30),(19,8)],'gold2')
        c.line([(19,11),(29,30),(19,50),(9,30),(19,11)],'red3' if power else 'green2')
        c.paste(icon('syringe' if power else 'brain',18),11,21)
    else:
        c.box(6,10,27,1,'bone1');c.box(6,50,27,1,'bone1')
        for x,y in ((3,3),(33,3),(3,55),(33,55)):c.box(x,y,3,3,'gold2')
        c.box(5,53,2,3,'bone0');c.box(32,6,2,4,'bone1')
    return c


def deck(power=False):
    c=Canvas(28,32)
    for x,y in ((4,4),(2,2),(0,0)):
        c.bevel(x,y,24,28,'gold',1)
        c.box(x+2,y+2,20,24,'red1' if power else 'green1')
        c.line([(x+4,y+3),(x+19,y+3)],'red3' if power else 'green3')
    c.paste(icon('syringe' if power else 'brain',16),4,5)
    return c


def suit(name,size=32):
    c=Canvas(32,32)
    if name=='heart':c.paste(icon('heart'),4,4)
    elif name=='diamond':
        c.poly([(16,2),(29,16),(16,30),(3,16)],'ink');c.poly([(16,4),(27,16),(16,28),(5,16)],'cyan')
        c.poly([(16,4),(16,28),(5,16)],'teal')
    elif name in ('spade','club'):
        if name=='spade':
            c.poly([(16,2),(28,16),(26,21),(21,24),(16,21),(11,24),(6,21),(4,16)],'steel3')
        else:
            for x,y in ((10,2),(2,12),(18,12)):c.ellipse(x,y,12,12,'green3')
        c.poly([(14,17),(18,17),(18,25),(23,29),(9,29),(14,25)],'green3' if name=='club' else 'steel3')
    elif name=='joker':c.paste(icon('joker'),4,4)
    else:
        c.ellipse(4,4,24,24,'gold2');c.ellipse(6,6,20,20,'ink');c.line([(8,23),(23,8)],'gold3',2)
    return scaled(c,(size,size))


def ledger():
    c=Canvas(160,320)
    c.bevel(5,25,150,283,'red',3);c.bevel(8,28,144,277,'gold',2)
    c.box(10,30,140,273,'green0')
    for x,y,w,h in [(14,72,132,69),(14,162,132,51),(14,219,132,70)]:
        c.bevel(x,y,w,h,'steel',1);c.box(x+2,y+2,w-4,h-4,'void')
    c.line([(20,63),(139,63)],'gold2')
    return c


def odds(kind='table',frame=0):
    c=Canvas(120,240)
    if kind=='table':
        c.bevel(0,0,120,240,'gold',2);c.box(3,3,114,234,'green0')
        c.box(8,30,104,1,'gold2')
        for y in range(50,207,22):
            c.box(7,y,106,19,'ink');c.box(9,y+18,102,1,'green1')
        c.box(8,214,104,1,'gold2')
    elif kind=='buttons':
        for y in range(48,207,22):c.paste(control('confirm' if frame<2 else 'close'),97,y)
    elif kind in ('levels','level'):
        for y in range(51,207,22):c.text(str(frame+1),72,y,'gold3')
    elif kind=='augment_level':
        for y in range(49,207,22):c.paste(icon('power_coin',9),84,y)
    elif kind=='tokens':
        for i in range(frame):c.paste(icon('coin',8),8+i*10,221)
    elif kind=='costs':
        for y in range(51,207,22):c.text('1',96,y,'gold3')
    return c


def graphic(name,size):
    w,h=size
    if name in ('normal','hover','pressed','disabled'):return button(96,20,('normal','hover','pressed','disabled').index(name))
    if name in ('settings','left','right','close','confirm'):return control(name)
    if name in ('coin','power_coin'):return icon(name,16)
    if name.startswith('audio_slider'):
        c=Canvas(9,13);c.bevel(0,0,9,13,'gold',1);c.box(3,3,2,7,'bone2' if 'hover' in name else 'bone1');return c
    if name.startswith('audio_mute'):
        c=Canvas(12,12);c.bevel(0,0,12,12,'steel',1);c.box(2,2,8,8,'ink')
        if name.endswith('on'):c.line([(2,6),(5,9),(10,3)],'cyan',2)
        return c
    if name.startswith('flag') or name in ('EN','FR'):
        fr=name.lower().endswith('fr');c=Canvas(16,10,'bone2' if fr else 'blue0')
        if fr:c.box(0,0,5,10,'blue');c.box(11,0,5,10,'red3')
        else:
            c.line([(0,0),(15,9)],'bone2',3);c.line([(15,0),(0,9)],'bone2',3)
            c.box(0,4,16,2,'red3');c.box(7,0,2,10,'red3')
        return c
    if name=='menu_title_plate':
        c=Canvas(148,66);c.bevel(0,0,148,66,'gold',3);c.box(3,3,142,60,'green0')
        for x in (9,133):c.box(x,11,5,1,'gold2');c.box(x,54,5,1,'gold2')
        return c
    if name=='menu_selector_brass':
        c=Canvas(144,41);c.bevel(0,0,144,41,'gold',2);c.box(3,3,138,35,'green0');return c
    if name=='menu_selector_arrow':
        c=Canvas(12,21);c.poly([(2,10),(9,3),(9,17)],'gold3');return c
    if name=='stash_tray':
        c=Canvas(48,26);c.bevel(0,0,48,26,'gold',1)
        for x in (2,25):c.bevel(x,2,21,22,'steel',1);c.box(x+2,4,17,18,'green0')
        return c
    if name in ('dealer_speech','speech_bubble_normal','standard_bubble_text'):
        c=Canvas(100,38);c.bevel(0,0,100,35,'gold',2);c.box(3,3,94,29,'green0');c.poly([(66,33),(73,37),(76,33)],'gold2');return c
    if name=='eye_reveal_frame':
        c=Canvas(32,32)
        for x,y,sx,sy in ((1,1,1,1),(30,1,-1,1),(1,30,1,-1),(30,30,-1,-1)):
            c.line([(x+sx*4,y),(x,y),(x,y+sy*4)],'cyan')
        return c
    if name=='symbol_picker_brass':
        c=Canvas(154,52);c.bevel(0,0,154,52,'gold',2);c.box(3,3,148,46,'green0')
        for x in (8,36,64,92,120):c.bevel(x,12,26,28,'steel',1);c.box(x+2,14,22,24,'ink')
        return c
    if name=='shop_reroll_brass':
        frames=[]
        for k in range(2):
            c=Canvas(31,27);c.paste(button(31,27,k),0,0);c.paste(icon('reroll',17),7,5);frames.append(c)
        return sheet(frames)
    if name=='route_reroll_brass':
        frames=[]
        for k in range(2):
            c=Canvas(160,320);c.paste(button(38,30,k),7,188);c.paste(icon('reroll',20),16,193);frames.append(c)
        return sheet(frames)
    if name=='sakura_petal':
        c=Canvas(8,8);c.poly([(2,0),(6,1),(7,4),(3,7),(0,4)],'flesh2');c.line([(1,3),(4,4),(5,2)],'flesh3');return c
    if name in ('vision','setting_icon'):return icon('eye' if name=='vision' else 'memory')
    raise ValueError(f'No UI recipe: {name}')
