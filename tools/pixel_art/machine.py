"""The reference appliance and its independent electromechanical layers."""
import math
from .core import Canvas, icon, scaled, sheet, color


def room(w=160,h=320):
    c=Canvas(w,h,'void')
    # Structural pilasters and light fixtures, deliberately quiet behind controls.
    for x in (7,w-11):
        c.box(x,0,5,h,'red0');c.box(x,0,1,h,'red1')
        for y in (12,69,126):
            c.box(x+1,y,3,30,'red1');c.box(x+2,y+2,1,24,'red3')
            c.box(x+1,y+7,1,8,'red4')
    c.box(0,h-70,w,70,'ink')
    for y in (h-57,h-40,h-20,h-1):c.line([(0,y),(w-1,y)],'shadow')
    for x in range(-w,w*2,40):c.line([(w//2,h-80),(x,h-1)],'shadow')
    # Reflections are short broken shapes in the same ramp, not a blur/noise map.
    for x in (9,w-10):
        for k in range(7):
            c.box(x-k//3,h-58+k*9,3+k//3,1,'red2')
    return c


def dealer(w=40,h=58,blink=False,talk=0,hands=True):
    c=Canvas(40,58)
    # Suit silhouette, broken into lapels, a high collar and narrow shoulders.
    c.poly([(5,34),(14,29),(25,29),(35,34),(39,57),(0,57)],'ink')
    c.poly([(5,35),(13,32),(17,49),(10,45),(6,49)],'steel0')
    c.poly([(26,32),(34,35),(34,48),(29,45),(23,49)],'steel0')
    c.line([(5,37),(2,51),(1,56)],'steel1');c.line([(34,37),(37,52)],'steel1')
    c.poly([(14,30),(25,30),(23,45),(19,49),(16,40)],'bone1')
    c.box(18,28,5,9,'green1')
    c.poly([(12,6),(16,2),(24,2),(28,6),(30,16),(27,27),(23,31),(17,29),(12,24),(10,15)],'green0')
    c.poly([(14,7),(17,4),(23,4),(27,8),(28,18),(25,25),(21,28),(16,25),(13,19)],'green3')
    c.poly([(14,8),(15,5),(23,4),(25,6),(18,7),(17,11),(14,12)],'green4')
    # Slick hair follows the skull rather than a helmet of random strands.
    c.poly([(11,12),(12,5),(17,1),(25,2),(29,7),(29,13),(26,8),(19,6),(14,9),(14,13)],'steel0')
    c.line([(14,6),(18,3),(24,3),(27,6)],'steel2')
    c.line([(16,6),(20,4),(25,5)],'steel1')
    if blink:
        c.box(14,15,5,1,'green0');c.box(23,15,5,1,'green0')
    else:
        c.poly([(13,13),(18,12),(20,15),(18,18),(14,17)],'green0')
        c.poly([(23,12),(28,13),(27,17),(23,18),(21,15)],'green0')
        c.box(15,14,2,1,'cyan');c.box(24,14,2,1,'cyan')
    c.poly([(21,15),(19,21),(22,21)],'green1')
    c.line([(14,21),(17,23),(23,23),(26,20)],'green0')
    c.line([(17,24),(23,24)],'bone2')
    for x in (18,21,23):c.box(x,24,1,1,'green0')
    c.box(18,26,5,1,'green1')
    c.poly([(15,33),(19,35),(16,38),(14,37)],'red3');c.poly([(21,35),(25,33),(26,37),(23,38)],'red2')
    c.box(19,34,3,3,'red4')
    if hands:
        c.poly([(4,54),(7,50),(13,49),(18,44),(20,45),(19,49),(17,52),(22,49),(26,49),(35,54),(34,57),(5,57)],'green1')
        c.line([(6,53),(12,51),(17,47),(18,46)],'green4')
        c.line([(7,56),(13,53),(17,50)],'green3')
        c.line([(22,52),(25,51),(33,55)],'green4')
        c.line([(21,54),(27,53),(32,56)],'green3')
    if talk%2:c.box(19,24,4,2,'green0')
    return scaled(c,(w,h))


def cabinet(dead=False):
    c=room()
    # Upper CRT assembly. The stepped silhouette and existing apertures are fixed.
    c.bevel(20,39,113,75,'red',3)
    c.box(24,43,105,68,'red1')
    c.bevel(25,44,103,67,'steel',3)
    c.bevel(31,46,94,64,'green',4)
    c.box(34,49,88,57,'green0')
    c.box(36,51,84,53,'void')
    c.line([(35,103),(38,106),(117,106),(120,103)],'green1')
    for x,y in [(27,45),(126,45),(27,109),(126,109)]:c.screw(x,y)
    # Broken speculars identify a folded edge, not a glowing cartoon outline.
    c.box(25,40,24,1,'red5');c.box(22,44,1,18,'red4')
    c.box(126,48,1,47,'red2');c.box(24,108,1,3,'steel2')
    # Brushed-steel rail. Large quiet planes plus two construction seams.
    c.bevel(21,114,115,25,'steel',2)
    c.box(24,117,109,18,'steel1')
    c.line([(25,117),(132,117)],'steel2')
    for x in (46,77,108):
        c.ellipse(x-12,115,24,24,'ink');c.ellipse(x-11,116,22,22,'steel0')
        c.ellipse(x-10,117,20,20,'void')
    for x in (28,60,94,129):
        c.screw(x,117);c.screw(x,135)
    # Red shoulders step outward around the reel housing.
    side=[(26,139),(126,139),(133,145),(133,169),(137,171),(137,189),
          (141,192),(141,219),(145,224),(145,236),(8,236),(8,223),
          (12,218),(12,192),(16,189),(16,171),(20,169),(20,145)]
    c.poly(side,'red0')
    c.poly([(27,140),(125,140),(131,146),(131,170),(135,172),(135,190),
            (139,193),(139,220),(143,225),(143,234),(10,234),(10,224),
            (14,219),(14,193),(18,190),(18,172),(22,170),(22,146)],'red2')
    c.line([(27,140),(125,140),(131,146),(131,166)],'red3')
    c.line([(22,146),(22,168),(18,172),(18,189),(14,193),(14,216)],'red4')
    c.bevel(26,140,101,12,'red',2)
    c.screw(30,145);c.screw(123,145)
    c.bevel(29,152,95,58,'steel',2)
    c.box(31,154,91,54,'ink')
    # Live lamp seats and live reel holes; alpha measured in the generated output.
    for x in (33,65,97):
        c.box(x-2,154,25,11,'void')
        c.line([(x-2,164),(x+22,164)],'steel1')
        c.box(x,169,21,34,None)
    # The lower shelf and its four recesses are static; every cap/icon is live.
    c.bevel(11,210,131,26,'steel',2)
    c.box(14,213,125,20,'steel1')
    for x,y,w,h in [(21,213,31,17),(54,213,39,18),(98,213,16,17),(116,213,16,17)]:
        c.bevel(x,y,w,h,'steel',1);c.box(x+2,y+2,w-4,h-4,'void')
    for x in (15,137):c.screw(x,213);c.screw(x,232)
    c.bevel(5,236,143,13,'red',1)
    c.line([(9,237),(43,237)],'red4')
    for x in (9,143):c.screw(x,240)
    c.bevel(17,249,119,39,'red',1)
    c.box(20,251,112,34,'red1')
    c.box(21,252,109,30,'red2')
    c.box(22,252,23,1,'red3');c.box(130,254,1,28,'red0')
    c.box(25,257,12,1,'red1') # folded service-panel seam
    c.bevel(23,266,20,10,'steel',1);c.text('LC03',26,269,'steel3')
    for x in range(26,42,3):c.box(x,279,1,3,'red0')
    for x,y in [(19,285),(132,284),(20,251)]:
        c.box(x,y,3,1,'steel1');c.box(x,y-1,1,1,'bone0')
    c.bevel(121,240,10,5,'steel',1);c.box(123,242,6,1,'void')
    c.box(23,289,108,10,'steel0');c.box(28,291,98,6,'ink')
    c.box(53,291,47,7,'void')
    c.bevel(18,300,118,20,'red',2)
    c.bevel(46,301,62,19,'steel',2)
    c.box(50,305,54,12,'void');c.box(52,314,50,2,'steel0')
    c.box(69,302,14,1,'gold4');c.box(70,303,12,1,'gold2')
    for x in (49,105):c.screw(x,303);c.screw(x,317)
    if dead:
        c.line([(38,48),(59,68),(47,80),(66,103)],'steel2')
        c.line([(59,68),(96,53),(116,62)],'steel1')
    return c


def spin(state):
    c=Canvas(46,28)
    c.bevel(3,2,40,24,'steel',2)
    c.box(5,4,36,20,'void')
    down=2 if state in ('pressed','latched') else 0
    material='gold' if state in ('disabled','latched') else 'bone'
    c.bevel(7,5+down,32,15,material,2)
    c.box(10,7+down,26,10,'bone1' if material=='gold' else 'bone2')
    if state=='hover':c.line([(10,6),(34,6)],'white')
    if state=='focus':
        c.line([(1,6),(1,2),(5,2)],'cyan');c.line([(40,25),(44,25),(44,21)],'cyan')
    else:c.text('SPIN',23,10+down,'gold0',center=True)
    return c


def power(name,state=0):
    c=Canvas(160,320)
    x={'reroll':46,'shift':77,'memory':108}.get(name,46)
    c.ellipse(x-11,116,22,22,'ink');c.ellipse(x-10,116,20,20,'gold1')
    c.ellipse(x-9,117,18,18,'gold3');c.ellipse(x-8,118,16,16,'gold0')
    c.ellipse(x-7,118+(state==1),14,14,'bone2' if state==0 else 'green3' if state==1 else 'bone0')
    c.line([(x-4,119),(x+2,119)],'white' if state==0 else 'green4')
    glyph=Canvas(13,13);ink='green0' if state==1 else 'gold0'
    if name=='reroll':
        glyph.line([(10,3),(8,1),(4,1),(1,4),(1,8),(4,11),(9,11),(11,8)],ink)
        glyph.poly([(8,0),(12,4),(8,5)],ink)
    elif name=='shift':
        glyph.line([(1,4),(11,4)],ink);glyph.poly([(8,1),(12,4),(8,7)],ink)
        glyph.line([(1,9),(11,9)],ink);glyph.poly([(4,6),(0,9),(4,12)],ink)
    elif name=='memory':
        glyph.ellipse(3,0,7,9,ink);glyph.ellipse(4,1,5,7,None)
        glyph.box(2,6,9,6,ink);glyph.box(6,8,1,3,None);glyph.box(5,8,3,1,None)
    elif name=='rewind':
        glyph.poly([(6,1),(0,6),(6,11)],ink);glyph.poly([(12,1),(6,6),(12,11)],ink)
    elif name=='heart':
        glyph.poly([(1,3),(3,1),(5,2),(6,4),(8,2),(10,1),(12,3),(12,6),(6,12),(0,6)],ink)
    elif name=='cheat':
        glyph.box(2,0,9,13,ink);glyph.box(3,1,7,11,None)
        glyph.poly([(6,3),(4,7),(8,7)],ink);glyph.box(6,7,1,2,ink)
    elif name=='swap':
        glyph.line([(1,2),(11,10)],ink);glyph.line([(1,10),(11,2)],ink)
        glyph.line([(8,2),(11,2),(11,5)],ink);glyph.line([(8,10),(11,10),(11,7)],ink)
    c.paste(glyph,x-6,120+(state==1))
    return c


def reels(kind,phase=0):
    c=Canvas(160,320)
    for x in (33,65,97):
        if kind=='drums':
            c.box(x,169,21,34,'bone0')
            for y,h,col in [(171,4,'bone1'),(175,20,'bone2'),(195,4,'bone1'),(199,3,'bone0')]:c.box(x+1,y,19,h,col)
            c.box(x+2,177,1,16,'white')
        elif kind=='housing':
            c.bevel(x-1,168,23,36,'steel',1);c.box(x,169,21,34,None)
            c.box(x-1,170,1,10,'steel3');c.box(x+21,183,1,18,'steel0')
        elif kind=='motion':
            for k in range(4):c.paste(icon(['brain','eye','pill','vial'][(k+phase)%4],12),x+4,163+k*12)
    return c


def lamps(frame=0,flash=False):
    c=Canvas(160,320)
    for i,x in enumerate((32,64,96)):
        c.bevel(x,156,23,7,'steel',1)
        c.box(x+2,158,19,3,'gold4' if flash or i<frame else 'green1')
        c.box(x+3,158,16,1,'white' if flash or i<frame else 'green2')
    return c


def beacon(frame):
    c=Canvas(160,320)
    c.bevel(66,33,20,5,'gold',1)
    c.poly([(68,31),(68,26),(71,21),(76,20),(81,22),(84,27),(84,32)],'gold0')
    c.poly([(70,31),(70,27),(72,23),(76,22),(80,24),(82,27),(82,31)],'gold3' if frame else 'gold1')
    c.box(72,24,2,6,'gold4' if frame else 'gold2')
    for x in (70,75,81):c.line([(x,24),(x,32)],'steel0')
    c.box(68,31,17,2,'steel2')
    return c


def callout(word,frame=0):
    c=Canvas(160,320)
    if word=='combo':
        c.bevel(74,66,44,15,'gold',1);c.box(76,68,40,11,'green0')
        c.text('COMBO',96,69,'bone2',center=True);c.text('X'+str(frame+1),96,75,'cyan',center=True)
    elif word=='free_spin':
        c.text('FREE SPIN',95,50,'gold4',center=True)
    elif word.startswith('loss'):
        c.box(74,82,44,12,'red0');c.text('X'+('2' if word=='loss_2' else '3')+'!',95,84,'red5',2,True)
        if word=='loss_3':c.box(77+(frame%9)*4,93,3,1,'red3')
    elif word=='multiplier':
        # Existing frames: x1, x2, x3 and cap/disabled/selected variants.
        value=[1,2,3,2,3,2][frame%6]
        # The live multiplier sprite has a retained (-9,+30) authored offset.
        c.text('X'+str(value),105,52,'gold3' if frame<3 else 'red4',2,True)
    elif word=='power':
        names=['REROLL','SHIFT','LOCK','REWIND','HEART','CHEAT','SWAP']
        c.text(names[frame%7],77,65,'cyan',2,True)
    else:
        c.text('PAIR' if frame==0 else 'TRIPLE',77,62,'bone2',3,True)
    return c


def dealer_bar(frame,overlay=0):
    c=Canvas(160,320)
    for i in range(10):
        x=36+i*3
        if overlay:
            if i<overlay*3 and i<=frame:c.box(x,95,2,3,'red4')
        else:c.box(x,95,2,3,'green2' if i<frame else 'green0')
    return c


def heat(kind):
    if kind=='lamp':
        c=Canvas(35,19)
        for x,y,w,h,a in [(1,5,33,10,16),(4,6,27,8,40),(6,7,23,6,96),(8,8,19,3,220)]:
            c.box(x,y,w,h,(255,255,255,a))
        return c
    c=Canvas(160,320)
    # Deliberate broad clusters, preserving metal returns under the light.
    gain=75 if kind=='core' else 30
    for x,y,w,h in [(21,43,2,64),(130,43,2,64),(20,146,2,22),(132,147,2,20),
                    (16,174,2,16),(136,174,2,16),(12,195,2,23),(140,195,2,23),
                    (18,251,2,36),(134,251,2,36),(27,140,98,1),(7,237,138,1)]:
        c.box(x,y,w,h,(255,255,255,gain))
    if kind=='glow':
        for x,y,w,h in [(17,40,4,72),(133,40,4,72),(14,249,4,39),(136,249,4,39),
                        (21,307,15,3),(116,307,15,3)]:c.box(x,y,w,h,(255,255,255,28))
    return c
