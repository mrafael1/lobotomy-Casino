"""Healthy-machine benchmark: lacquer, jewel glass, tungsten chase and tangible payouts."""
from math import sin, cos, pi
from .pixels import Pixel, symbol, item_badge, chip


def reel_symbol(kind):
    p=Pixel(58,66)
    if kind=='eye':
        p.contour((3,31),[((15,12),(40,11),(55,31)),((40,51),(15,51),(3,31))],'ruby0')
        p.contour((5,30),[((19,17),(39,18),(52,31)),((37,42),(20,42),(5,30))],'cream2')
        p.oval(18,17,23,29,'jade0');p.oval(21,18,18,27,'jade2')
        for i in range(18):
            a=i*pi/9
            p.fine_line([(59+round(cos(a)*12),62+round(sin(a)*21)),
                         (59+round(cos(a)*17),62+round(sin(a)*24))],'jade4')
        p.oval(25,18,9,27,'ink');p.oval(31,21,4,5,'ivory');p.box(24,38,2,3,'mint1')
        p.contour((4,27),[((17,13),(38,14),(53,28))],'ruby1',stroke=2)
        p.contour((7,38),[((18,48),(41,47),(51,37))],'ruby4',stroke=1)
        for xx,yy in ((7,23),(12,19),(45,20),(50,24)):
            p.line([(xx,yy),(xx-1,yy-3)],'ruby0')
    elif kind=='brain':
        # Two lobe masses, then connected folds shaped to their volume.
        p.contour((29,9),[((16,1),(3,13),(5,30)),((3,43),(15,52),(28,48)),
                           ((40,54),(55,43),(54,30)),((58,14),(43,2),(29,9))],'wine1')
        p.contour((28,11),[((16,5),(7,16),(8,29)),((7,41),(18,47),(27,43)),
                            ((37,49),(51,39),(50,27)),((51,15),(41,7),(28,11))],'ruby3')
        for box,sa,ea in (((11,12,29,29),160,400),((8,24,26,41),75,315),
                          ((18,30,33,45),220,450),((29,12,46,29),140,400),
                          ((32,26,50,41),210,490)):
            p.arc(box,sa,ea,'wine1',2)
            p.arc((box[0]+1,box[1]-1,box[2],box[3]-1),sa+8,ea-8,'ruby4')
        p.contour((29,9),[((25,19),(31,23),(27,30)),((23,35),(30,40),(28,47))],'wine1',stroke=2)
        for start,segments in (
            ((13,20),[((10,16),(14,11),(18,14)),((21,16),(18,20),(23,22))]),
            ((35,13),[((40,10),(46,15),(43,19)),((40,21),(36,18),(35,23))]),
            ((12,34),[((13,30),(19,30),(20,34)),((20,37),(15,37),(18,41))]),
            ((36,36),[((33,32),(38,29),(42,32)),((46,35),(41,38),(44,40))]),
        ):p.contour(start,segments,'wine1',stroke=1)
        p.contour((31,44),[((33,49),(35,53),(38,57)),((39,60),(42,57),(41,53)),
                           ((39,50),(39,47),(39,45))],'ruby1')
        p.fine_line([(65,95),(70,102),(74,108)],'ruby4')
    else:
        # Secondary strip symbols retain the shared family's original geometry.
        p.paste(symbol_tile(kind),10,11)
    return p

def symbol_tile(kind):
    p=Pixel(38,44);symbol(p,kind,0,0);return p


def gold_frame(p,x,y,w,h,cut=4):
    p.poly([(x+cut,y),(x+w-cut,y),(x+w,y+cut),(x+w,y+h-cut),
            (x+w-cut,y+h),(x+cut,y+h),(x,y+h-cut),(x,y+cut)],'gold0')
    p.line([(x+1,y+h-cut),(x+1,y+cut),(x+cut,y+1),(x+w-cut,y+1)],'gold3',2)
    p.line([(x+cut,y+h-1),(x+w-cut,y+h-1),(x+w-1,y+h-cut)],'gold1',2)
    p.fine_line([((x+cut)*2,y*2+1),((x+w-cut)*2,y*2+1)],'gold4')


def bulb(p,x,y,on=True,peak=False):
    p.oval(x-4,y-4,9,9,'gold0')
    if on:
        p.oval(x-3,y-3,7,7,'bulb1');p.oval(x-2,y-2,5,5,'bulb2')
        p.oval(x-1,y-2,3,3,'bulb3')
        if peak:
            p.fine_line([(x*2-11,y*2),(x*2-9,y*2)],'gold2')
            p.fine_line([(x*2+9,y*2),(x*2+11,y*2)],'gold2')
    else:
        p.oval(x-3,y-3,7,7,'bulb0');p.oval(x-2,y-2,5,5,'gold2')
        p.fine_line([(x*2-2,y*2-3),(x*2+1,y*2-3)],'gold3')


def gem_socket(p,x,y,kind):
    p.oval(x-26,y,52,39,'ruby0');p.oval(x-24,y,48,35,'gold1')
    p.oval(x-22,y,44,31,'gold3');p.oval(x-19,y+2,38,27,'jade0')
    p.oval(x-17,y+3,34,23,'jade1');p.oval(x-15,y+4,30,19,'jade2')
    p.arc((x-17,y+3,x+17,y+26),195,310,'jade4')
    p.arc((x-14,y+7,x+14,y+23),20,155,'jade0',2)
    p.contour((x-11,y+7),[((x-5,y+4),(x+4,y+4),(x+10,y+7))],'jade3',stroke=2)
    ink='cream3'
    if kind=='REROLL':
        p.arc((x-8,y+8,x+8,y+23),50,325,ink,2)
        p.poly([(x+3,y+7),(x+10,y+8),(x+5,y+13)],ink)
    elif kind=='SHIFT':
        p.line([(x,y+8),(x,y+22),(x-5,y+17)],ink,2);p.line([(x,y+22),(x+5,y+17)],ink,2)
    else:
        p.arc((x-5,y+7,x+5,y+19),180,360,ink,2);p.box(x-7,y+15,15,10,ink)
        p.box(x-1,y+18,2,4,'jade0')
    for i in range(15):
        a=(i*20+20)*pi/180
        xx=x*2+round(cos(a)*47);yy=y*2+35+round(sin(a)*31)
        p.fine_line([(xx,yy),(xx+1,yy-2)],'gold4')
    p.text(kind,x,y+43,'cream2',align='center')


def machine(late=False,frame=0,warning=False,payout=0):
    """Healthy idle/engaged art. `late` means the existing x3 example, never decay.

    Payout is a fixed visual study, not a game result or a rule implementation.
    All UI geometry is fixed through the six-frame decorative lamp chase.
    """
    p=Pixel(bg='void');peak=payout in (2,3,4)
    p.text('CAMPAIGN',21,17,'paper1')
    for i in range(3):
        p.oval(83+i*14,14,9,12,'paper1' if i<2 else 'wine1')
        p.fine_line([(171+i*28,32),(168+i*28,37),(172+i*28,42)],'skin1')
    p.text('MENU',299,17,'paper2',align='right')
    # The casino stays dark. Small physical pools of reflected gold and jade
    # surround the machine, which is deliberately the room's most tempting object.
    p.oval(7,581,306,43,'glass1');p.oval(27,587,266,31,'jade0')
    p.oval(54,592,211,20,'gold0')
    # A stepped, broad-shouldered silhouette with marquetry wings, fluted brass
    # uprights and lacquered sides. This is working casino luxury in good repair.
    p.poly([(22,155),(22,87),(42,87),(42,67),(78,67),(78,55),(242,55),(242,67),
            (278,67),(278,87),(298,87),(298,155),(307,179),(307,534),(297,593),
            (281,615),(39,615),(23,593),(13,534),(13,179)],'gold0')
    p.poly([(26,155),(26,91),(46,91),(46,71),(82,71),(82,59),(238,59),(238,71),
            (274,71),(274,91),(294,91),(294,155),(301,180),(301,534),(292,588),
            (278,608),(42,608),(28,588),(19,534),(19,180)],'gold2')
    p.poly([(33,160),(33,99),(54,99),(54,79),(89,79),(89,67),(231,67),(231,79),
            (266,79),(266,99),(287,99),(287,160),(294,181),(294,531),(284,582),
            (272,596),(48,596),(36,582),(26,531),(26,181)],'ruby1')
    p.poly([(38,162),(38,103),(59,103),(59,84),(94,84),(94,73),(225,73),(225,84),
            (261,84),(261,103),(282,103),(282,162),(287,181),(287,492),(33,492),(33,181)],'ruby2')
    p.contour((39,177),[((36,145),(37,121),(40,110))],'ruby4',stroke=2)
    p.contour((282,187),[((280,150),(281,121),(279,111))],'ruby3',stroke=2)
    # Long, narrow reflected planes give lacquer its curved volume; bright
    # facets gather at the handled edge instead of covering the whole cabinet.
    p.contour((35,478),[((33,401),(34,310),(34,206))],'ruby3',stroke=3)
    p.contour((284,479),[((284,394),(285,298),(284,207))],'ruby1',stroke=5)
    p.fine_line([(78,704),(78,970)],'ruby4')
    # Crown fan: inlaid rays and a central jewel, not a vent or a sickly mouth.
    for side in (-1,1):
        for i in range(5):
            x=160+side*(29+i*16)
            y=71+max(0,i-1)*7
            p.line([(160+side*8,105),(x,y)],'gold0',3)
            p.fine_line([((160+side*8)*2+side,210),(x*2+side,y*2)],'gold3')
    p.poly([(160,57),(169,68),(160,80),(151,68)],'gold3')
    p.poly([(160,60),(166,68),(160,75),(154,68)],'jade2')
    p.fine_line([(319,124),(313,135),(319,147)],'jade4')
    # Backlit marquee is a promise above the game; the lettering keeps clear
    # of every bulb and the perimeter is carried by actual lamp sockets.
    gold_frame(p,51,106,218,61,8);p.box(55,110,210,53,'ruby0')
    p.text('LOBOTOMY',161,120,'gold1',3,'center')
    p.text('LOBOTOMY',160,119,'cream3',3,'center')
    p.text('C A S I N O',160,146,'gold3',align='center')
    lamps=[(x,95) for x in range(44,281,15)]+[(x,176) for x in range(44,281,15)]
    for i,(x,y) in enumerate(lamps):bulb(p,x,y,on=peak or (i+frame)%6!=0,peak=peak)
    # Fluted side rails are bright beside the glass and darker toward the room.
    for x,side in ((20,1),(300,-1)):
        p.box(x-3,188,7,301,'gold1')
        p.line([(x,190),(x,483)],'gold3',2)
        p.fine_line([(x*2+side*3,386),(x*2+side*3,958)],'gold4')
        for yy in (195,330,482):
            p.oval(x-5,yy-3,11,7,'gold0');p.arc((x-4,yy-3,x+5,yy+3),185,330,'gold3')
    # Countdown remains the same ten-step house approach, separated from the
    # decorative lamps by position, rectangular shape and an explicit label.
    p.box(39,185,242,16,'ruby0');p.text('HOUSE',46,190,'cream1')
    for i in range(10):p.box(86+i*14,191,9,3,'gold3' if i<(8 if late else 3) else 'ruby1')
    for i in range(3):p.oval(244+i*9,190,5,5,'amber' if late or i==0 else 'gold0')
    # Jewel-like reel cradle. The bright parchment is graduated over a cylinder,
    # with a clean payline and small curved-glass reflections at the edges.
    p.box(34,205,252,137,'gold0');gold_frame(p,37,207,246,133,6)
    p.box(42,212,236,123,'jade0')
    for i in range(3):
        x=49+i*77
        p.box(x,214,66,116,'gold2');p.box(x+2,216,62,112,'gold4')
        p.box(x+4,218,58,108,'cream0');p.box(x+5,223,56,99,'cream1')
        p.box(x+5,237,56,69,'cream2');p.box(x+5,250,56,46,'cream3')
        p.box(x+5,218,56,5,'gold1');p.box(x+5,319,56,5,'gold1')
        p.fine_line([((x+7)*2,448),((x+7)*2,628)],'cream3')
        p.box(x+58,225,3,91,'cream0')
        p.contour((x+57,226),[((x+60,250),(x+60,292),(x+56,315))],'cream3',stroke=1)
        p.paste(reel_symbol(('eye','eye','brain')[i]),x+4,242)
        top=reel_symbol(('pill','vial','eye')[i]);bottom=reel_symbol(('brain','syringe','pill')[i])
        p.paste(top.crop((0,49,58,66)),x+4,224);p.paste(bottom.crop((0,0,58,14)),x+4,305)
        p.line([(x+5,241),(x+60,241)],'cream0');p.line([(x+5,304),(x+60,304)],'cream0')
        p.oval(x+27,208,12,3,'jade3' if not late else 'bulb3')
        # Payline catches, without drawing a stripe across the symbol artwork.
        for yy in (261,277):p.box(x+2,yy,2,3,'gold4')
    for x,d in ((31,1),(289,-1)):
        p.poly([(x,270),(x+d*7,265),(x+d*7,275)],'bulb3')
    # Extra lamp banks flank the drums. Their chasing reflection is where the
    # healthy machine's restless energy lives, leaving the gameplay art stable.
    for i,yy in enumerate(range(223,333,18)):
        for x in (29,291):bulb(p,x,yy,on=peak or (i+frame)%6!=0,peak=peak)
    # One account glass: clean typography and a continuous progress line.
    gold_frame(p,42,353,236,73,5);p.box(46,357,228,65,'jade0')
    p.box(48,359,224,2,'jade1')
    p.text('WEALTH',56,367,'jade3');p.text('TARGET',261,367,'cream1',align='right')
    amount='2780' if late else ('0050' if payout>=4 else '0040')
    if late:p.text(amount,55,382,'jade4',3)
    else:
        p.text(amount[:2],55,382,'jade1',3);p.text(amount[2:],91,382,'jade4',3)
    p.text('3500' if late else '100',261,382,'cream3',3,'right')
    p.box(56,411,166,3,'jade1');p.box(56,411,132 if late else (83 if payout>=4 else 66),2,'jade3')
    p.text('X3' if late else 'X1',261,405,'gold4',2,'right')
    if warning:
        p.box(49,361,222,59,'ruby0');p.text('HOLD',71,370,'red',3)
        p.text('RESCUE OR SPIN',252,392,'cream3',align='right')
    for x,kind in ((76,'REROLL'),(160,'SHIFT'),(244,'LOCK')):gem_socket(p,x,441,kind)
    # The large cherry-red SPIN cap is the single strongest action. A raised,
    # polished enamel dome sits in a deep fitted ring, rather than a paper oval.
    p.contour((29,502),[((67,491),(255,491),(290,502)),((300,514),(300,543),(286,553)),
                           ((249,564),(70,564),(32,553)),((20,543),(20,516),(29,502))],'gold1')
    p.contour((32,504),[((73,496),(248,496),(287,504)),((293,516),(295,538),(282,545)),
                           ((246,554),(76,554),(36,545)),((27,537),(25,517),(32,504))],'ruby0')
    p.contour((33,504),[((84,496),(240,496),(284,504))],'gold4',stroke=1)
    gold_frame(p,34,510,51,32,4);p.box(38,514,43,24,'jade0')
    p.text('08' if late else '15',59,517,'jade4',2,'center');p.text('SPINS',59,555,'cream1',align='center')
    p.oval(97,506,114,43,'gold0');p.oval(100,506,108,37,'gold3')
    p.oval(104,506,100,31,'ruby1');p.oval(107,506,94,25,'ruby3')
    p.arc((108,506,200,530),190,335,'ruby4',2)
    p.contour((119,510),[((139,506),(173,507),(188,511))],'cream2',stroke=1)
    p.text('SPIN',154,514,'cream3',2,'center')
    for x,kind in ((229,'vial'),(267,'pill')):
        p.oval(x-15,510,32,34,'gold2');p.oval(x-12,511,26,28,'jade0')
        if kind=='vial':
            p.box(x-3,515,9,4,'gold2');p.box(x-4,519,11,16,'cold1')
            p.box(x-2,525,7,8,'jade2');p.box(x-3,520,1,9,'jade4')
        else:
            p.contour((x-6,522),[((x-10,526),(x-4,533),(x,533)),
                                ((x+6,531),(x+9,528),(x+5,524)),
                                ((x,518),(x-3,518),(x-6,522))],'cream3')
            p.poly([(x-6,526),(x,520),(x+6,525),(x+1,532)],'ruby3')
    for i,(kind,n) in enumerate((('T',3),('P',2),('E',1),('S',2),('C',1))):
        x=48+i*45;item_badge(p,kind,x,573);p.text(str(n),x+21,576,'red' if kind=='E' else 'jade3')
    # The coin return is a real polished tray, with a highlight on the rolled lip.
    gold_frame(p,117,596,86,23,3);p.box(122,600,76,11,'gold0')
    p.line([(123,615),(197,615)],'gold4',2)
    p.text('LUCIDITY',277,594,'cream1',align='right');p.text('045 G',277,606,'gold4',2,'right')
    for xx in (47,72,97):
        p.poly([(xx,598),(xx+19,599),(xx+20,612),(xx+1,611)],'paper1')
    p.oval(52,601,9,7,'ruby0');p.oval(54,602,5,4,'gold2');p.line([(59,607),(63,610)],'ruby0')
    p.line([(77,602),(82,604),(88,602),(88,609),(82,611),(77,609),(77,602)],'ruby0')
    p.line([(82,604),(82,611)],'paper2');p.box(102,604,12,5,'ruby0');p.box(106,602,4,3,'gold1')
    if late:
        # This is a healthy engaged machine. Decay is intentionally deferred.
        for x in (44,276):p.line([(x,215),(x,331)],'gold3')
    if payout:
        # Authored reward choreography: pair → tangible coins → wealth tick.
        # It does not award a result or consume any gameplay random stream.
        if payout<6:
            p.box(56,113,208,48,'ruby0')
            p.text('PAIR',160,116,'cream3',3,'center')
            p.text('+10',160,143,'jade4',2,'center')
        if payout in (2,3):
            for xx,yy,r in ((57,346,4),(264,345,3),(39,432,3),(281,431,4)):
                p.line([(xx-r,yy),(xx+r,yy)],'gold4');p.line([(xx,yy-r),(xx,yy+r)],'gold4')
        if payout in (3,4,5):
            step=payout-3
            for i in range(3):
                xx=145+14*i;yy=578+step*11-4*i
                chip(p,xx,yy,8,'gold3',2)
            # Score travels directly from result toward the account. The
            # separate Lucidity coins stay down at the cash tray.
            if payout in (3,4):p.text('+10',121-step*22,342+step*19,'jade4',2,'center')
        if payout>=6:
            for i in range(3):chip(p,143+i*14,607,8,'gold3',i*2)
    return p
