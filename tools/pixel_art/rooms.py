"""Shared architectural construction; each room is a deliberately composed set."""
from .core import Canvas, icon, scaled, sheet
from .machine import dealer, room


def lamp(c,x,y):
    c.bevel(x-3,y-3,7,24,'gold',1)
    c.box(x-1,y,3,17,'bone2');c.box(x,y,1,14,'white')
    c.box(x-2,y+18,5,2,'gold1')


def architecture(w=160,h=320):
    c=room(w,h)
    c.box(14,0,w-28,h-90,'red0')
    c.box(18,0,w-36,h-90,'ink')
    for x in (17,w-24):
        c.bevel(x,0,7,h-75,'gold',1)
        c.box(x+2,7,3,h-90,'gold0')
    # Coffered wall panels and a single luminous fixture on each side.
    for x in (26,w-50):
        for y in (23,91,159):
            c.bevel(x,y,24,57,'red',1);c.box(x+2,y+2,20,52,'red0')
            c.line([(x+3,y+3),(x+20,y+3)],'gold1')
    lamp(c,29,76);lamp(c,w-30,76)
    c.box(14,h-91,w-28,3,'gold0');c.box(16,h-89,w-32,1,'gold2')
    return c


def drapes(c):
    for mirror in (False,True):
        points=[(0,0),(79,0),(63,8),(41,15),(18,16),(0,9)]
        c.poly([(160-x if mirror else x,y) for x,y in points],'red1')
        c.line([(160-x if mirror else x,y) for x,y in [(1,1),(20,12),(40,12),(64,5)]],'red3')
        for i in range(3):
            x=18+i*15
            c.line([(160-x if mirror else x,2),(160-(x+13) if mirror else x+13,10-i*2)],'red0')
    c.bevel(77,0,6,18,'gold',1)


def backdrop():
    c=architecture()
    drapes(c)
    c.bevel(33,25,95,180,'gold',3);c.box(36,28,89,174,'void')
    c.line([(38,198),(38,44),(80,25),(122,44),(122,198)],'steel0')
    c.box(30,213,101,3,'gold1')
    # Checkered marble planes without procedural speckle.
    for y in (244,261,285):
        c.line([(0,y),(159,y)],'steel0')
    for x in (0,32,64,96,128,159):c.line([(80,224),(x,319)],'steel0')
    return c


def felt(c,y=109,bottom=307):
    c.bevel(1,y-7,158,bottom-y+12,'red',4)
    c.bevel(5,y-3,150,bottom-y+4,'gold',3)
    c.poly([(10,y),(150,y),(156,y+14),(156,bottom-12),(146,bottom),(14,bottom),(4,bottom-12),(4,y+14)],'green0')
    c.poly([(12,y+2),(148,y+2),(153,y+15),(153,bottom-14),(145,bottom-4),(15,bottom-4),(7,bottom-14),(7,y+15)],'green1')
    c.line([(13,y+5),(147,y+5)],'green2')
    c.line([(14,bottom-8),(146,bottom-8)],'gold1')
    # A stitched front rail, not a cloudy felt noise field.
    for x in range(17,147,9):c.box(x,bottom+2,5,1,'red3')


def pacte():
    c=architecture()
    c.paste(dealer(64,93),48,14)
    c.bevel(2,101,156,9,'red',2)
    c.bevel(65,102,30,7,'gold',1)
    felt(c,111,308)
    # Empty recesses remain beneath the independent, live cards/decks.
    for x in (13,119):
        c.bevel(x-1,108,30,35,'gold',1);c.box(x+1,110,26,31,'green0')
    for x in (7,61,114):
        c.box(x-1,147,41,63,'green0')
    for x,col in ((25,'green3'),(110,'red3')):
        c.line([(x+2,219),(x+23,219),(x+25,221),(x+25,252),(x+23,254),(x+2,254),(x,252),(x,221),(x+2,219)],col)
    c.bevel(63,309,34,8,'gold',1)
    return c


def bottles(c):
    for x in (7,133):
        for row,y in enumerate((34,70,106)):
            c.bevel(x,y+22,22,3,'gold',1)
            for i in range(3):
                xx=x+2+i*7
                c.box(xx+2,y+3+i%2*3,2,6,'gold1')
                c.bevel(xx,y+9+i%2*3,6,13-i%2*3,'green' if (i+row)%2 else 'red',1)
                c.box(xx+1,y+11,1,6,'green3' if (i+row)%2 else 'red3')
    c.bevel(3,10,32,12,'steel',1);c.box(5,12,28,8,'green0');c.text('OPEN',19,14,'cyan',center=True)


def shop():
    c=architecture()
    bottles(c)
    c.paste(dealer(64,90),48,52)
    felt(c,143,202)
    for x in (7,60,113):
        c.bevel(x,151,40,34,'green',1);c.box(x+2,153,36,30,'green0')
    c.bevel(1,204,158,74,'red',2)
    for x in (8,58,108):
        c.bevel(x,210,44,61,'gold',1);c.box(x+2,212,40,57,'red0')
    c.box(4,279,151,5,'ink')
    for x in (25,128):c.bevel(x,284,8,12,'steel',1)
    return c


def route():
    c=architecture()
    c.bevel(13,20,134,9,'red',1)
    for x in (19,88):
        c.bevel(x,31,54,151,'gold',2)
        c.bevel(x+3,34,48,145,'red',2)
        c.bevel(x+5,36,44,141,'green',1)
        c.box(x+8,39,38,134,'green0')
        c.bevel(x+15,49,25,32,'gold',1);c.box(x+17,51,21,28,'void')
        c.screw(x+44,126,True)
    c.paste(dealer(60,85),50,168)
    c.bevel(12,245,136,55,'red',2)
    for x in (17,61,105):
        c.bevel(x,253,38,39,'gold',1);c.box(x+2,255,34,35,'red0')
    c.bevel(52,245,56,7,'gold',1)
    return c


def audio_console():
    c=architecture()
    c.bevel(21,25,118,268,'red',5)
    c.bevel(26,30,108,46,'gold',2)
    c.box(29,33,102,40,'ink')
    for y in range(38,70,5):c.box(33,y,94,2,'steel0')
    c.box(125,65,3,3,'cyan')
    c.bevel(28,82,104,162,'gold',2);c.box(31,85,98,156,'void')
    for x in (31,128):
        for y in (85,240):c.screw(x,y,True)
    c.bevel(42,252,76,24,'steel',2)
    c.bevel(57,287,47,5,'steel',1)
    return c


def options():
    c=Canvas(144,252)
    c.bevel(0,0,144,252,'red',3)
    c.bevel(3,3,138,246,'gold',2)
    c.box(6,6,132,240,'green0')
    for x,y in ((5,5),(138,5),(5,246),(138,246)):c.screw(x,y,True)
    c.box(12,32,120,1,'gold1')
    return c


def sacrifice():
    c=architecture()
    c.bevel(10,72,140,208,'red',3)
    c.bevel(16,79,128,189,'gold',2);c.box(19,82,122,181,'green0')
    # Brass scales: both pans are separate from live resource cards.
    c.bevel(74,88,12,93,'gold',1)
    c.box(37,101,88,3,'gold2');c.box(42,99,79,1,'gold4')
    for x in (47,115):
        c.line([(x-11,104),(x-11,150),(x+11,150),(x+11,104)],'gold2')
        c.poly([(x-16,151),(x+16,151),(x+10,159),(x-10,159)],'gold1')
        c.line([(x-15,151),(x+15,151)],'gold4')
    c.bevel(60,180,40,8,'gold',1)
    c.paste(icon('brain',22),37,130);c.paste(icon('coin',22),105,130)
    c.bevel(11,280,138,14,'red',2)
    return c


def lab(kind='bg',frame=0):
    c=Canvas(160,240)
    if kind=='bg':
        c=room(160,240)
        c.box(13,0,134,188,'green0')
        for x in (15,141):c.bevel(x,0,5,190,'steel',1)
        for y in (13,72,132):c.box(20,y,121,1,'green1')
        for x in (37,123):c.bevel(x,0,5,69,'steel',1)
        c.poly([(49,26),(111,26),(111,181),(101,195),(59,195),(49,181)],'steel0')
        c.box(54,33,52,148,'green0')
        c.box(57,37,45,137,'green1');c.box(59,40,2,126,'green3')
        c.line([(62,42),(62,118)],'green2')
        c.ellipse(54,168,52,19,'steel1');c.ellipse(58,169,44,12,'green2')
        for x in range(55,107,6):c.box(x,183,3,9,'steel2')
        # Foreground floor is perspective construction, free of generic noise.
        for y in (201,218,239):c.line([(0,y),(159,y)],'steel1')
        for x in (-30,20,70,120,170):c.line([(80,188),(x,239)],'steel1')
        if frame<3:c.box(56,40,47,128,('green1','green2','green0')[frame])
    elif kind=='brain':
        dy=(0,-1,-1,0,1,1,0)[frame%7]
        c.paste(icon('brain',42),59,90+dy)
        c.line([(75,132+dy),(75,145),(82,151),(82,167)],'flesh1',2)
        c.line([(83,131+dy),(85,140),(88,143)],'green2')
    elif kind=='bubbles':
        if frame!=12:
            for i in range(4):
                y=160-(frame*6+i*29)%116
                x=66+(i*11)%29
                c.ellipse(x,y,3+i%2,3+i%2,'green3');c.box(x,y,1,1,'green4')
    elif kind=='cables':
        for x in (29,130):
            c.line([(x,18),(x,55),(x+(-9 if x<80 else 9),70),(x+(-9 if x<80 else 9),161),(x,176)],'ink',4)
            c.line([(x-1,18),(x-1,55),(x+(-10 if x<80 else 8),70),(x+(-10 if x<80 else 8),161),(x-1,176)],'steel1')
        if frame>0:c.box(128,65+frame%4,3,2,'cyan')
    elif kind=='layer':
        c.bevel(0,169,43,26,'steel',2);c.bevel(117,169,43,26,'steel',2)
        for x in (5,12,19,26,33,124,131,138,145,152):c.box(x,175,3,11,'ink')
    elif kind in ('eye_upgrades','memory_upgrades'):
        eye=kind.startswith('eye');x=74 if eye else 8;y=12 if eye else 20
        if frame==0:
            ww,hh=(34,29) if eye else (23,22)
            c.bevel(x,y,ww,hh,'steel',2);c.bevel(x+2,y+2,ww-4,hh-8,'gold',1)
            c.box(x+4,y+4,ww-8,hh-12,'green0');c.paste(icon('eye' if eye else 'memory',12),x+ww//2-6,y+5)
            c.box(x+ww//2-1,y+hh-4,3,1,'cyan')
        else:
            # Preserve terminal footprint and the 13/11 semantic state order.
            if eye:
                boxes=[(86,21,11,11),(82,17,19,19),(78,13,27,27),(62,7,58,39)]
                xx,yy,ww,hh=boxes[min(frame-1,3)]
            else:
                boxes=[(15,27,9,9),(7,20,25,25),(5,11,29,41)]
                xx,yy,ww,hh=boxes[min(frame-1,2)]
            c.bevel(xx,yy,ww,hh,'steel',1);c.box(xx+2,yy+2,ww-4,hh-4,'green0')
            name='pattern_recognition' if eye else 'memory'
            if eye and frame==10:name='book'
            if eye and frame==11:name='hallucination'
            if eye and frame==12:name='memory'
            if not eye and 5<=frame<=8:name='reward_'+str(max(1,frame-5))
            if not eye and frame==9:name='smart_saving'
            size=min(24,ww-6,hh-6)
            c.paste(icon(name,size,frame),xx+(ww-size)//2,yy+(hh-size)//2)
            if not eye and 5<=frame<=8:
                # Existing local pip centres (87/151/215,304) / source scale 8.
                for pip in (11,19,27):c.box(pip-1,37,3,2,'gold3')
    elif kind in ('eye_buttons','memory_buttons'):
        if kind.startswith('eye'):
            for xx,direction in ((55,-1),(120,1)):
                c.bevel(xx,21,8,11,'gold' if frame else 'steel',1)
                c.poly([(xx+2,26),(xx+5,23),(xx+5,29)] if direction<0 else [(xx+6,26),(xx+3,23),(xx+3,29)],'bone2')
        else:
            for yy,direction in ((5,-1),(51,1)):
                c.bevel(14,yy,11,8,'gold' if frame else 'steel',1)
                c.poly([(19,yy+2),(16,yy+5),(22,yy+5)] if direction<0 else [(19,yy+6),(16,yy+3),(22,yy+3)],'bone2')
    elif kind=='lab_sign':
        c.bevel(116,8,44,21,'gold',1);c.box(119,11,39,15,'green0');c.text('LAB',139,15,'cyan' if frame else 'green3',2,True)
    elif kind=='leak':
        if frame>0:
            c.line([(106,162),(111,174),(111,189)],'green2')
            c.ellipse(105,197,12+frame%3,3,'green2')
    elif kind=='buy_stele':
        c.bevel(68,193,24,37,'steel',2);c.box(71,195,18,6,'green3');c.box(73,203,15,24,'steel0')
    elif kind in ('eye_brain_overlay','memory_brain_overlay'):
        if frame>0:
            c.paste(icon('eye' if kind.startswith('eye') else 'memory',16),72,104)
    else:raise ValueError(kind)
    return c
