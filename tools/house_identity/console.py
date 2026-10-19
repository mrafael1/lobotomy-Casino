"""Revision two: a breathing gaming cabinet, with a quiet, independent UI."""
from math import sin, cos, pi
from .pixels import Pixel, symbol, item_badge


def carving(p,x,y,mirror=False):
    sign=-1 if mirror else 1
    def q(a,b):return (x+sign*a,y+b)
    # Bent acanthus/reed forms turn around the shoulder, with a dark cut and
    # a single narrow reflected edge. Native hairlines avoid a chunky bevel.
    for i in range(4):
        pts=[q(2+i*3,35),q(1+i*2,22),q(5+i*2,12),q(13,6-i)]
        p.line(pts,'wood1')
        p.fine_line([(a*2+sign,b*2) for a,b in pts],'wood_edge')
    p.contour(q(3,39),[(q(18,28),q(19,17),q(13,13)),
                      (q(9,8),q(5,13),q(9,18))],'brass_dull',stroke=1)


def reel_symbol(kind):
    p=Pixel(58,66)
    if kind=='eye':
        p.contour((3,31),[((15,12),(40,11),(55,31)),((40,51),(15,51),(3,31))],'skin0')
        p.contour((5,30),[((19,17),(39,18),(52,31)),((37,42),(20,42),(5,30))],'paper2')
        p.oval(18,17,23,29,'felt0');p.oval(21,18,18,27,'felt2')
        for i in range(18):
            a=i*pi/9
            p.fine_line([(59+round(cos(a)*12),62+round(sin(a)*21)),
                         (59+round(cos(a)*17),62+round(sin(a)*24))],'felt4')
        p.oval(25,18,9,27,'ink');p.oval(31,21,4,5,'ivory');p.box(24,38,2,3,'mint1')
        p.contour((4,27),[((17,13),(38,14),(53,28))],'skin1',stroke=2)
        p.contour((7,38),[((18,48),(41,47),(51,37))],'skin_mid',stroke=1)
        for xx,yy in ((7,23),(12,19),(45,20),(50,24)):
            p.line([(xx,yy),(xx-1,yy-3)],'skin0')
    elif kind=='brain':
        # Two lobe masses, then connected folds shaped to their volume.
        p.contour((29,9),[((16,1),(3,13),(5,30)),((3,43),(15,52),(28,48)),
                           ((40,54),(55,43),(54,30)),((58,14),(43,2),(29,9))],'wine1')
        p.contour((28,11),[((16,5),(7,16),(8,29)),((7,41),(18,47),(27,43)),
                            ((37,49),(51,39),(50,27)),((51,15),(41,7),(28,11))],'skin2')
        for box,sa,ea in (((11,12,29,29),160,400),((8,24,26,41),75,315),
                          ((18,30,33,45),220,450),((29,12,46,29),140,400),
                          ((32,26,50,41),210,490)):
            p.arc(box,sa,ea,'wine1',2)
            p.arc((box[0]+1,box[1]-1,box[2],box[3]-1),sa+8,ea-8,'skin_light')
        p.contour((29,9),[((25,19),(31,23),(27,30)),((23,35),(30,40),(28,47))],'wine1',stroke=2)
        for start,segments in (
            ((13,20),[((10,16),(14,11),(18,14)),((21,16),(18,20),(23,22))]),
            ((35,13),[((40,10),(46,15),(43,19)),((40,21),(36,18),(35,23))]),
            ((12,34),[((13,30),(19,30),(20,34)),((20,37),(15,37),(18,41))]),
            ((36,36),[((33,32),(38,29),(42,32)),((46,35),(41,38),(44,40))]),
        ):p.contour(start,segments,'wine1',stroke=1)
        p.contour((31,44),[((33,49),(35,53),(38,57)),((39,60),(42,57),(41,53)),
                           ((39,50),(39,47),(39,45))],'skin1')
        p.fine_line([(65,95),(70,102),(74,108)],'skin_mid')
    else:
        # Secondary strip symbols retain the shared family's original geometry.
        p.paste(symbol_tile(kind),10,11)
    return p


def symbol_tile(kind):
    p=Pixel(38,44);symbol(p,kind,0,0);return p


def socket(p,x,y,kind,spent=False):
    p.oval(x-25,y,50,38,'void');p.oval(x-23,y,46,34,'brass0')
    p.oval(x-21,y+1,42,29,'brass1');p.arc((x-21,y+1,x+21,y+30),185,310,'brass_polish')
    p.oval(x-17,y+4,34,24,'wood0' if spent else 'paper1')
    p.arc((x-16,y+4,x+16,y+27),190,300,'paper2' if not spent else 'wood2')
    ink='brass1' if spent else 'wine0'
    if kind=='REROLL':
        p.arc((x-8,y+8,x+8,y+23),45,335,ink,2)
        p.poly([(x+4,y+7),(x+10,y+9),(x+5,y+13)],ink)
    elif kind=='SHIFT':
        p.line([(x,y+9),(x,y+22),(x-4,y+18)],ink,2);p.line([(x,y+22),(x+4,y+18)],ink,2)
    else:
        p.arc((x-5,y+7,x+5,y+19),180,360,ink,2);p.metal(x-7,y+15,15,10,'brass',2)
        p.box(x-1,y+18,2,4,'wine0')
    for i in range(17):
        a=(i*18+18)*pi/180
        xx=2*x+round(cos(a)*45);yy=2*y+34+round(sin(a)*29)
        p.fine_line([(xx,yy),(xx+1,yy-1)],'brass_dull')
    p.text(kind,x,y+43,'paper2',align='center')


def machine(late=False,frame=0,warning=False):
    p=Pixel(bg='void')
    breath=(0,1,2,3,2,1)[frame%6]
    # The room recedes: no repeated bright wallpaper behind the functional UI.
    for x in (8,305):
        p.box(x,103,6,401,'wood0');p.box(x+1,104,1,396,'wood1')
    p.oval(4,582,312,41,'ink')
    p.text('CAMPAIGN',23,18,'paper1')
    for i in range(3):
        p.oval(83+i*14,15,9,12,'paper1' if i<2 else 'wine1')
        p.fine_line([(171+i*28,34),(168+i*28,39),(172+i*28,44)],'skin1')
    p.text('MENU',296,18,'paper2',align='right')
    # The case curves around the play surface like a chest under a dinner jacket.
    p.contour((22,179),[((20,101),(62,62),(160,61)),((257,62),(301,101),(298,179)),
                          ((301,276),(301,400),(303,505)),((307,557),(293,601),(267,610)),
                          ((209,623),(97,623),(48,609)),((22,596),(12,553),(17,509)),
                          ((20,397),(18,275),(22,179))],'wood0')
    p.contour((26,181),[((26,108),(67,68),(160,68)),((251,68),(294,108),(294,181)),
                          ((296,300),(297,421),(298,509)),((300,548),(288,590),(264,601)),
                          ((207,614),(100,614),(52,600)),((28,587),(18,548),(22,510)),
                          ((25,405),(23,282),(26,181))],'wood2')
    p.contour((35,182),[((34,115),(71,78),(160,78)),((246,78),(287,115),(285,182)),
                          ((288,304),(289,413),(288,490)),((267,505),(52,505),(32,490)),
                          ((30,395),(32,284),(35,182))],'enamel0')
    # Fine reflected edges are not a glowing outline. Most of the case is dark.
    p.contour((25,466),[((25,313),(22,197),(34,145)),((46,96),(98,73),(153,71))],
              'wood_edge',stroke=1)
    p.contour((290,463),[((291,310),(294,205),(282,145)),((272,104),(234,81),(191,76))],
              'wood_warm',stroke=2)
    p.contour((31,188),[((28,125),(65,84),(125,77))],'wood_glaze',stroke=3)
    p.contour((284,197),[((287,133),(259,98),(218,87))],'enamel2',stroke=2)
    p.contour((39,176),[((39,139),(61,109),(91,97))],'enamel1',stroke=4)
    p.contour((283,436),[((280,347),(281,278),(279,218))],'enamel1',stroke=4)
    for x,mirror in ((39,False),(280,True)):carving(p,x,108,mirror)
    p.text('LOBOTOMY',160,97,'paper2',2,'center')
    p.text('THE HOUSE REMEMBERS',160,119,'brass2',align='center')
    # Under the crown, a tensioned fabric diaphragm rises a fraction before the
    # bellows. It is an organ-like mechanism, never a new character portrait.
    p.contour((80,153),[((103,139),(217,139),(240,153)),((217,179),(102,179),(80,153))],'ink')
    p.contour((92,154-breath),[((116,142-breath),(207,142-breath),(229,154-breath)),
                             ((209,166),(114,168),(92,154-breath))],
              'membrane1' if late else 'membrane0')
    for i in range(16):
        x=88+i*9
        yy=147+abs(x-160)//23
        p.line([(x,yy),(x+5,yy+18)],'wood0',3)
        p.fine_line([(x*2+1,yy*2),(x*2+8,(yy+17)*2)],'brass_dull')
    if late:
        # A stretched seam moves behind the grille. The cabinet's material
        # responds, while every piece of numerical UI remains stationary.
        p.contour((103,157-breath),[((137,146-breath),(190,162-breath),(219,151-breath))],
                  'membrane2',stroke=1)
    # Approach is still the existing ten steps. The three warning lamps are
    # physically distinct from breathing light and remain mechanically meaningful.
    p.text('HOUSE',44,186,'paper1')
    for i in range(10):
        xx=82+i*15;p.box(xx,186,10,3,'brass3' if i<(8 if late else 3) else 'brass0')
    for i in range(3):p.oval(244+i*9,185,5,5,'amber' if late or i==0 else 'brass0')
    # Three tall glass drums are the cabinet's focal point. Gentle shading locates
    # the cylinder; the paper has no single large flat ivory rectangle.
    p.metal(39,206,242,132,'brass',8);p.box(43,210,234,124,'ink')
    for i in range(3):
        x=49+i*77
        p.metal(x,214,66,116,'brass',4);p.box(x+3,217,60,110,'paper0')
        p.box(x+5,223,56,99,'paper1');p.box(x+5,236,56,74,'paper2')
        p.box(x+5,252,56,45,'paper3')
        p.box(x+5,218,56,5,'cold0');p.box(x+5,318,56,7,'cold0')
        p.fine_line([((x+7)*2,448),((x+7)*2,628)],'paper3')
        p.box(x+58,225,3,92,'paper0')
        p.contour((x+57,226),[((x+60,251),(x+60,293),(x+56,315))],'cold2',stroke=1)
        p.paste(reel_symbol(('eye','eye','brain')[i]),x+4,242)
        top=reel_symbol(('pill','vial','eye')[i]);bottom=reel_symbol(('brain','syringe','pill')[i])
        p.paste(top.crop((0,49,58,66)),x+4,224)
        p.paste(bottom.crop((0,0,58,14)),x+4,305)
        p.line([(x+5,241),(x+60,241)],'paper0');p.line([(x+5,304),(x+60,304)],'paper0')
        p.oval(x+28,208,10,3,'amber' if late else 'mint0')
        for yy in (218,324):p.screw(x+1,yy)
    for x,direction in ((33,1),(287,-1)):
        p.poly([(x,270),(x+direction*6,266),(x+direction*6,274)],'brass3')
    # Removable hinge knuckles attach the reel cradle to the cabinet sides.
    for x in (37,280):
        for yy in (229,298):
            p.box(x,yy,3,17,'brass0')
            p.fine_line([(x*2+1,yy*2+2),(x*2+1,yy*2+30)],'brass_dull')
            for dy in (5,11):p.line([(x,yy+dy),(x+2,yy+dy)],'ink')
    # The body's side bellows deform subtly. They sit outside reel input and do
    # not change apertures or any control's position.
    for x,side in ((22,1),(294,-1)):
        for i in range(11):
            y=237+i*13;dx=breath if i in range(2,9) else 0
            p.contour((x,y),[(((x+side*(5+dx)),y+1),((x+side*(7+dx)),y+8),(x,y+11))],
                      'wine1' if not late else 'enamel2',stroke=3)
            p.fine_line([(x*2,y*2+3),((x+side*(4+dx))*2,y*2+9)],'wine3' if late else 'wood2')
    # One continuous account glass: score and target read on the same baseline.
    p.metal(42,353,236,73,'brass',5);p.box(46,357,228,65,'glass0')
    p.fine_line([(96,718),(526,718)],'glass3')
    p.text('WEALTH',56,367,'mint1');p.text('TARGET',261,367,'paper1',align='right')
    if late:p.text('2780',55,382,'mint2',3)
    else:
        p.text('00',55,382,'mint0',3);p.text('40',91,382,'mint2',3)
    p.text('3500' if late else '100',261,382,'paper2',3,'right')
    p.box(56,411,166,3,'glass2');p.box(56,411,132 if late else 66,2,'mint1')
    p.text('X3' if late else 'X1',261,405,'amber' if late else 'paper1',2,align='right')
    if warning:
        p.box(49,361,222,59,'wine0')
        p.text('HOLD',71,370,'red',3)
        p.text('RESCUE OR SPIN',252,392,'paper2',align='right')
    # Dedicated powers: no active items, approach or account labels mixed in.
    for x,kind,spent in ((76,'REROLL',False),(160,'SHIFT',True),(244,'LOCK',False)):
        socket(p,x,441,kind,spent)
    # Sloped cabinet control shelf. Its lip has rounded joinery and a narrow
    # handled highlight rather than an oversized flat sheet of gold.
    p.contour((29,502),[((55,495),(265,495),(290,502)),((300,513),(302,543),(289,551)),
                           ((251,561),(70,561),(30,551)),((18,540),(19,515),(29,502))],'brass0')
    p.contour((32,504),[((66,500),(253,500),(287,504)),((294,516),(298,537),(285,543)),
                           ((247,551),(74,551),(33,543)),((25,536),(25,516),(32,504))],'wood1')
    p.contour((33,505),[((84,500),(240,500),(283,505))],'brass_dull',stroke=1)
    p.metal(34,510,51,32,'brass',4);p.box(38,514,43,24,'ink')
    p.text('08' if late else '15',59,517,'paper3',2,'center')
    p.text('SPINS',59,554,'paper1',align='center')
    p.oval(99,508,110,39,'ink');p.oval(101,507,106,35,'brass1');p.oval(105,507,98,29,'paper1')
    p.arc((105,507,203,535),190,325,'paper3')
    p.text('SPIN',154,515,'wine0',2,'center')
    for x,kind in ((229,'vial'),(267,'pill')):
        p.oval(x-15,510,32,34,'brass0');p.oval(x-12,511,26,28,'ink')
        # Dedicated miniature well drawings, not symbols protruding over a bezel.
        if kind=='vial':
            p.box(x-3,515,9,4,'brass1');p.box(x-4,519,11,16,'cold1')
            p.box(x-2,525,7,8,'felt2');p.box(x-3,520,1,9,'cold3')
        else:
            p.contour((x-6,522),[((x-10,526),(x-4,533),(x,533)),
                                ((x+6,531),(x+9,528),(x+5,524)),
                                ((x,518),(x-3,518),(x-6,522))],'paper2')
            p.poly([(x-6,526),(x,520),(x+6,525),(x+1,532)],'wine3')
    # Quiet status rail; each item owns a stable icon and its own phase duration.
    for i,(kind,n) in enumerate((('T',3),('P',2),('E',1),('S',2),('C',1))):
        x=48+i*45;item_badge(p,kind,x,573)
        p.text(str(n),x+21,576,'red' if kind=='E' else 'mint1')
    # Three worn build tabs remain inspectable, away from the power sockets.
    # Their silhouettes identify an optical boost, a book and a secured reserve.
    for xx in (49,74,99):
        p.poly([(xx,599),(xx+20,600),(xx+21,613),(xx+1,612)],'paper0')
        p.fine_line([(xx*2+3,1200),(xx*2+35,1202)],'paper1')
    p.oval(54,602,9,7,'wine0');p.oval(56,603,5,4,'brass2');p.line([(61,608),(65,611)],'wine0')
    p.line([(79,603),(84,605),(90,603),(90,610),(84,612),(79,610),(79,603)],'wine0')
    p.line([(84,605),(84,612)],'paper1')
    p.box(104,605,12,5,'wine0');p.box(108,603,4,3,'brass1')
    p.text('LUCIDITY',274,593,'paper1',align='right');p.text('045 G',274,606,'brass3',2,'right')
    p.metal(122,601,76,16,'brass',3);p.box(127,605,66,7,'void')
    # The slit catches the exhale. Small shifts are authored state, never result RNG.
    if frame in (2,3):p.line([(129,612),(192,612)],'membrane2' if late else 'brass1')
    if late:
        p.contour((35,197),[((29,164),(40,131),(57,115))],'wine3',stroke=1)
        p.line([(46,335),(273,335)],'wine2')
        for x in (82,159,236):p.oval(x-3,208,6,2,'brass4')
    return p
