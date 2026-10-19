"""Independent scene staging for phase one. All positions are 320x640 source pixels."""
from math import cos, sin, pi
from .pixels import Pixel, chip, button, eye, symbol, text_width, item_badge
from .dealer import portrait
from .cards import card, CARDS
from .console import machine


def filigree(p,x,y,w,h,c='brass1'):
    # Stepped reed-and-fan corner carving, not a generic repeating border.
    for sx in (-1,1):
        xx=x if sx==1 else x+w-1
        p.line([(xx,y+12),(xx,y+3),(xx+sx*3,y),(xx+sx*15,y)],c)
        p.line([(xx+sx*4,y+14),(xx+sx*4,y+7),(xx+sx*7,y+4),(xx+sx*14,y+4)],c)
        p.line([(xx,y+h-13),(xx,y+h-4),(xx+sx*3,y+h-1),(xx+sx*15,y+h-1)],c)
        p.poly([(xx+sx*8,y+9),(xx+sx*11,y+6),(xx+sx*13,y+9),(xx+sx*11,y+13)],c)


def pendant(p,x,y,r=40):
    p.line([(x,0),(x,y-14)],'brass0',2)
    p.line([(x+1,0),(x+1,y-14)],'wood2')
    p.poly([(x-9,y-14),(x+9,y-14),(x+r,y+9),(x+r,y+14),(x-r,y+14),(x-r,y+9)],'brass0')
    p.poly([(x-8,y-12),(x+7,y-12),(x+r-4,y+8),(x-r+4,y+8)],'felt1')
    p.line([(x-r+2,y+10),(x+r-2,y+10)],'brass2',2)
    p.line([(x-r+7,y+13),(x+r-7,y+13)],'brass4',2)
    p.oval(x-3,y+13,7,4,'ivory')


def wall(p):
    p.box(0,0,320,640,'void')
    # Raised burgundy brocade remains mostly quiet, with slivers of carved pilaster.
    p.box(16,28,288,280,'wine0')
    for x in (14,298):
        p.box(x,0,8,332,'wood1');p.box(x+1,0,2,330,'wood3');p.box(x+6,0,1,330,'brass0')
        for y in (81,227,296):p.metal(x-3,y,14,5,'brass',1)
    for yy in range(48,280,31):
        for xx in range(35+(15 if yy%2 else 0),294,31):
            p.line([(xx,yy-5),(xx+4,yy),(xx,yy+6),(xx-4,yy),(xx,yy-5)],'wine1')
            p.box(xx,yy+7,1,3,'wine1')
    # Distant slots and a real roulette table: the environment is an active gaming floor.
    for x in (-16,266):
        p.poly([(x+3,147),(x+42,147),(x+48,264),(x-3,264)],'wood0')
        p.metal(x+7,156,31,17,'brass',2);p.box(x+10,159,25,11,'felt0')
        for j in range(3):
            p.box(x+8+j*10,187,8,22,'paper0');p.box(x+10+j*10,195,4,7,'wine1')
        p.line([(x+5,214),(x+39,214)],'brass1');p.box(x+13,232,18,5,'wine2')
        p.oval(x+2,273,36,10,'wood1');p.box(x+10,280,5,35,'wood0')
    p.box(0,310,320,9,'wood1');p.box(0,310,320,2,'wood3')
    p.box(0,319,320,321,'wood0')
    for x in (-140,-40,60,160,260,360,460):p.line([(160,305),(x,640)],'wood2')
    for y in (345,389,452,541,639):p.line([(0,y),(320,y)],'wood2')


def roulette(p,x,y):
    p.oval(x,y,152,52,'wood0');p.oval(x+3,y+1,146,43,'wood3')
    p.oval(x+8,y+3,136,35,'brass1');p.oval(x+13,y+6,126,27,'felt0')
    for i in range(18):
        a=i*pi/9
        p.line([(x+76+int(cos(a)*46),y+19+int(sin(a)*8)),
                (x+76+int(cos(a)*61),y+19+int(sin(a)*12))], 'wine2' if i%2 else 'paper1',2)
    p.oval(x+41,y+11,70,17,'wood1');p.line([(x+76,y+1),(x+76,y+20)],'brass2',3)
    p.oval(x+70,y-2,13,5,'brass3')
    p.box(x+31,y+43,9,35,'wood1');p.box(x+114,y+40,9,38,'wood1')


def table(p,top=300):
    # The foreground is a curved, padded gaming rail, cut off at the player's seat.
    p.oval(-76,top,472,373,'wood0');p.oval(-70,top+3,460,353,'wood3')
    p.oval(-67,top+5,454,342,'brass1');p.oval(-63,top+8,446,333,'wine0')
    p.oval(-57,top+10,434,315,'wine2');p.oval(-51,top+12,422,301,'wine1')
    p.oval(-41,top+19,402,273,'brass2');p.oval(-38,top+21,396,268,'felt0')
    p.oval(-34,top+23,388,260,'felt1')
    p.arc((-46,top+15,365,top+298),192,346,'wine3',2)
    p.arc((-35,top+25,354,top+279),197,342,'felt3')
    # Baize seams and betting arcs, not random speckle.
    p.arc((10,top+56,310,top+245),195,345,'brass1')
    for x in (36,91,146,201,256):p.line([(x,top+95),(x+5,top+92)],'felt2')
    # Leather stitches follow the actual ellipsoidal rail.
    for i in range(12,169,7):
        a=i*pi/180
        xx=160+int(cos(a)*212);yy=top+157+int(sin(a)*147)
        if 0<=xx<320:p.line([(xx,yy),(xx-1,yy+3)],'wine3')
    p.box(0,top+298,320,640-top-298,'wood0')
    for x in (16,72,248,304):
        p.box(x,top+306,2,30,'wood2')
    p.line([(0,top+302),(319,top+302)],'wood3')
    # An embroidered house mark and dealer-side felt ruling make this a
    # purpose-built gambling surface. Contact polish stays at the near rail.
    p.arc((94,top+17,226,top+65),185,355,'felt3')
    p.text('LC',160,top+28,'felt3',align='center')
    for xx in (24,286):
        p.line([(xx,top+122),(xx+5,top+153),(xx+3,top+181)],'felt2')
    for xx in (14,78,242,306):
        p.arc((xx-3,top+279,xx+6,top+290),190,290,'wine4')


def shoe(p,x,y):
    p.poly([(x,y+13),(x+16,y),(x+40,y+7),(x+40,y+35),(x+20,y+48),(x,y+38)],'ink')
    p.poly([(x+3,y+15),(x+17,y+4),(x+36,y+10),(x+21,y+24)],'wood2')
    p.poly([(x+4,y+19),(x+19,y+28),(x+19,y+42),(x+4,y+35)],'wood1')
    p.poly([(x+22,y+27),(x+36,y+15),(x+36,y+33),(x+22,y+43)],'wood3')
    for yy in range(4,16,2):p.line([(x+12,y+yy),(x+27,y+yy-5)],'paper1')
    p.poly([(x+15,y+28),(x+30,y+24),(x+39,y+40),(x+22,y+44)],'paper2')
    p.line([(x+20,y+31),(x+29,y+29),(x+34,y+38),(x+24,y+40),(x+20,y+31)],'wine2')


def chip_rack(p,x,y):
    p.poly([(x,y+5),(x+10,y),(x+81,y),(x+91,y+11),(x+86,y+33),(x+3,y+29)],'wood0')
    p.poly([(x+4,y+6),(x+13,y+3),(x+78,y+3),(x+86,y+11),(x+82,y+27),(x+7,y+24)],'brass1')
    for i in range(5):
        xx=x+13+i*14
        p.oval(xx-7,y+6,14,19,'ink')
        for yy in range(9,22,3):p.line([(xx-5,y+yy),(xx+4,y+yy+1)],('wine3','felt3','paper2','brass2','cold2')[i],2)
    p.line([(x+7,y+27),(x+82,y+30)],'brass3')


def heading(p,title,subtitle=None):
    p.text(title,160,22,'brass3',2,'center')
    if subtitle:p.text(subtitle,160,46,'paper1',align='center')
    p.line([(32,61),(123,61)],'brass0');p.line([(197,61),(288,61)],'brass0')
    p.poly([(154,61),(160,57),(166,61),(160,65)],'brass1')


def caption(p,line,y=280):
    p.text(line,160,y,'paper3',align='center')


def pacte(power=False,late=False):
    p=Pixel();wall(p);pendant(p,160,84,59)
    heading(p,'PACTE','THE HOUSE REMEMBERS WHAT YOU CHOOSE')
    table(p,305)
    p.paste(portrait('late' if late else 'welcome'),68,95)
    # These props have actual job positions: shoe on dealer right, discard on left.
    shoe(p,263,288);chip_rack(p,11,308)
    p.poly([(21,294),(61,294),(67,310),(17,310)],'wood1')
    for i in range(4):p.line([(25,296+i*2),(58,296+i*2)],'paper1')
    caption(p,'ONE POWER. USE IT WISELY.' if power else 'ONE AUGMENT. ON THE HOUSE.',342)
    ids=['reroll','shift','memory'] if power else ['augment_reward_1','augment_smart_saving','augment_book']
    for i,k in enumerate(ids):
        x=24+i*97
        p.oval(x-4,483,88,9,'felt0')
        p.paste(card(k),x,365)
        if i==1:
            p.line([(x-3,364),(x-3,487),(x+80,487),(x+80,364)],'brass3')
            p.poly([(x+34,497),(x+39,492),(x+44,497)],'paper3')
    p.text('HOLD TO INSPECT / DRAG TO YOUR PLACE',160,511,'paper2',align='center')
    for x,label in ((32,'AUGMENT'),(172,'POWER')):
        p.arc((x,531,x+116,574),0,360,'brass1')
        p.text(label,x+58,546,'paper2',align='center')
    p.text('01 / 02' if not power else '02 / 02',160,601,'brass2',align='center')
    return p



def start():
    p=Pixel();wall(p);roulette(p,-59,271);roulette(p,221,300)
    pendant(p,160,105,62)
    # Long central aisle ending at the gaming table; no reception desk.
    p.poly([(122,290),(197,290),(300,640),(19,640)],'wine0')
    p.line([(124,292),(28,639)],'brass1');p.line([(195,292),(292,639)],'brass1')
    for y,w in ((367,28),(439,48),(535,72)):
        p.line([(160-w,y),(160,y-18),(160+w,y),(160,y+18),(160-w,y)],'wine1')
    p.text('LOBOTOMY',160,150,'paper3',3,'center')
    p.text('C A S I N O',160,181,'brass3',2,'center')
    p.text('THE HOUSE REMEMBERS',160,215,'paper1',align='center')
    # Croupier's welcome is part of the floor, not an oversized menu portrait.
    face=portrait().crop((44,16,138,153));p.paste(face,113,246)
    chip_rack(p,114,371)
    button(p,58,420,204,'TAKE A SEAT')
    p.text('AUGMENTED RUN',160,477,'brass2',align='center')
    p.text('<     STANDARD     >',160,497,'paper2',align='center')
    button(p,36,538,118,'RECORDS');button(p,166,538,118,'OPTIONS')
    p.text('3 CAMPAIGN NEURONS',160,603,'paper1',align='center')
    return p


def routes():
    p=Pixel();wall(p);heading(p,'NEXT TABLE','CHOOSE ONE / OR CONTINUE FOR FREE')
    # Twin gaming bays visible across a pit, not mysterious hotel doors.
    for x,kind,title,price in ((21,'shop','SHOP','8 G'),(176,'power','POWER','5 G')):
        p.poly([(x,140),(x+123,140),(x+123,376),(x,376)],'wood1')
        p.line([(x+3,144),(x+3,371),(x+119,371),(x+119,144)],'brass1',2)
        p.box(x+8,150,107,212,'void')
        pendant(p,x+62,182,31)
        if kind=='shop':
            for xx,k in ((x+17,'vial'),(x+58,'syringe')):symbol(p,k,xx,245)
            p.line([(x+12,291),(x+110,291)],'wood3',4)
            for xx in range(x+20,x+100,19):p.line([(xx,303),(xx+9,303),(xx+9,318)],'brass1',2)
        else:
            p.paste(card('reroll',back=True),x+24,233)
        p.oval(x+2,345,121,29,'wine1');p.oval(x+6,345,113,21,'felt1')
        p.text(title,x+62,391,'paper3',2,'center');p.text(price,x+62,417,'brass3',2,'center')
    # His extended arm invites the route, but commits nothing by itself.
    p.text('RUN LUCIDITY 045 G',160,91,'brass3',align='center')
    p.text('PAY ENTRY ON CONFIRMATION',160,452,'paper1',align='center')
    chip_rack(p,113,480)
    button(p,51,532,218,'RESHUFFLE 5 G')
    button(p,51,582,218,'CONTINUE')
    return p


def dealer_visit(shop=False):
    p=Pixel();wall(p);heading(p,'HOUSE SERVICES' if shop else 'A PRIVATE OFFER',
                               'RUN LUCIDITY / MACHINE INVESTMENT' if shop else 'TAKING AN ITEM DOES NOT USE IT')
    pendant(p,151,90,47);table(p,314);p.paste(portrait('pressure'),64,100)
    chip_rack(p,13,322);shoe(p,267,306)
    if shop:
        # A service board lies diagonally beside displayed machine components.
        p.poly([(24,364),(151,357),(157,527),(29,536)],'wood0')
        p.poly([(29,369),(147,363),(151,522),(34,530)],'paper1')
        p.text('MACHINE WORK',88,381,'wine0',align='center')
        for i,(name,price) in enumerate((('BRAIN FEED','20 G'),('PAIR GUARD','28 G'),('STASIS','22 G'))):
            y=402+i*38;p.text(name,39,y,'wood0');p.line([(40,y+25),(136,y+25)],'paper0')
            p.text(price,139,y+12,'wine1',align='right')
        p.metal(177,381,94,67,'brass',4)
        for x in (184,210,236):p.oval(x,395,24,35,'cold0');p.oval(x+3,398,18,26,'cold2')
        symbol(p,'vial',175,477);symbol(p,'syringe',226,472)
        caption(p,'BASE PRICES / MARKUPS STAY LIVE',557)
        button(p,46,585,228,'CONTINUE')
    else:
        # Two displayed items plus the dedicated campaign chip augment.
        for x,k,title in ((29,'vial','WATER'),(124,'pill','RED PILL')):
            p.oval(x,427,62,18,'felt0');symbol(p,k,x+12,380)
            p.text(title,x+31,456,'paper2',align='center')
        chip(p,249,422,28,'brass2',7);p.text('CHIP',249,455,'paper2',align='center')
        p.text('CAMPAIGN',249,469,'brass2',align='center')
        caption(p,'SELECT AN OFFER TO SEE ITS PRICE',499)
        button(p,27,539,126,'TAKE');button(p,167,539,126,'REFUSE')
        p.text('STASH',31,599,'paper1');symbol(p,'vial',113,582)
        p.oval(187,589,33,30,'wood1');p.text('EMPTY',205,600,'paper0',align='center')
    return p


def build(power=False):
    p=Pixel();wall(p);heading(p,'POWER' if power else 'AUGMENT','ONE BUILD CHOICE / CARD PRICE IS SEPARATE')
    pendant(p,160,108,64);table(p,280)
    p.paste(card('shift' if power else 'augment_reward_1',back=True),122,164)
    chip_rack(p,25,302);shoe(p,262,279)
    for i,k in enumerate(('rewind','heart','swap') if power else ('augment_adrenaline','augment_hallucination','augment_passive_gain')):
        p.paste(card(k),24+i*97,362)
        p.text('INSPECT',63+i*97,502,'paper2',align='center')
    p.text('CONFIRM ONE CARD',160,541,'paper3',2,'center')
    p.text('LIVE PRICE / LIVE UNLOCKS / EXISTING POOL',160,570,'paper1',align='center')
    p.text('NO SECOND DECK',160,611,'brass1',align='center')
    return p


def bonus():
    p=Pixel();wall(p);heading(p,'FORTUNE','ONE CLAIM / FOUR EXISTING REWARD TYPES')
    pendant(p,160,115,57)
    # Vertical wheel in a baize alcove, with an engraved selector and weighty feet.
    p.poly([(96,442),(124,422),(196,422),(224,442),(231,503),(91,503)],'wood2')
    p.metal(105,463,109,31,'brass',4)
    p.oval(36,177,249,249,'wood0');p.oval(39,178,243,242,'wood3')
    p.oval(45,184,231,230,'brass2');p.oval(52,191,217,216,'ink')
    for i in range(8):
        a=i*pi/4;b=(i+1)*pi/4
        pts=[(160,299)]+[(160+int(cos(t*pi/64)*103),299+int(sin(t*pi/64)*103)) for t in range(i*16,(i+1)*16+1)]
        p.poly(pts,'felt1' if i%2 else 'wine1')
        p.line([(160,299),(160+int(cos(a)*104),299+int(sin(a)*104))],'brass2',2)
        xx=160+int(cos((a+b)/2)*83);yy=299+int(sin((a+b)/2)*83)
        p.oval(xx-2,yy-2,5,5,'paper2')
    for x,y,s in ((160,218,'50 G'),(229,299,'X1.25'),(160,374,'8 / 4'),(91,299,'JACKPOT')):
        p.text(s,x,y,'paper3',align='center')
    p.oval(133,272,55,55,'brass0');p.oval(137,275,47,47,'brass3')
    p.oval(146,284,29,29,'wood1');p.text('LC',160,295,'paper2',align='center')
    for i in range(24):
        a=i*pi/12;p.oval(158+int(cos(a)*118),297+int(sin(a)*118),4,4,'paper2')
    p.poly([(146,169),(174,169),(160,196)],'brass3')
    caption(p,'THE POINTER SETTLES. THE HOUSE WAITS.',535)
    button(p,57,579,206,'SPIN THE WHEEL')
    return p


def sacrifice():
    p=Pixel();wall(p);heading(p,'SACRIFICE','TRADE ONE ELIGIBLE RESOURCE FOR +5 SPINS')
    pendant(p,160,114,51);table(p,330)
    # Assay balance on a gaming table: clinical accounting inside casino practice.
    p.metal(119,431,82,24,'brass',3);p.poly([(142,433),(154,228),(167,228),(179,433)],'brass1')
    p.line([(159,232),(159,424)],'brass3',3)
    p.oval(151,219,18,18,'brass3');p.line([(77,260),(242,245)],'brass2',5)
    for x,y in ((81,260),(236,246)):
        p.line([(x,y),(x-30,y+85)],'brass1');p.line([(x,y),(x+30,y+85)],'brass1')
        p.arc((x-34,y+70,x+34,y+99),0,180,'brass3',3)
    p.paste(card('augment_book'),40,287)
    for i in range(5):chip(p,217+i*8,322+i*2,9,'paper1',i*2)
    p.text('GIVE',81,428,'paper2',align='center');p.text('+5 SPINS',239,418,'paper3',align='center')
    p.text('SELECT AN ELIGIBLE OFFER',160,489,'paper2',align='center')
    p.text('0 / 3 SACRIFICES',160,513,'brass2',align='center')
    button(p,32,550,122,'TRADE');button(p,166,550,122,'REFUSE')
    return p


def lab():
    p=Pixel();wall(p);heading(p,'THE LAB','PERMANENT HOUSE IMPROVEMENTS / WALLET')
    pendant(p,160,118,56)
    # Back-of-house workbench with a disconnected machine, banknote clips and tools.
    p.poly([(42,226),(69,198),(257,198),(280,228),(280,412),(42,412)],'wood1')
    p.metal(52,217,218,164,'brass',6);p.box(59,225,204,147,'cold0')
    for x in (83,143,203):
        p.oval(x-12,243,36,45,'brass1');p.oval(x-9,245,30,38,'cold2')
        p.line([(x+5,248),(x+5,281)],'mint1',3)
        p.line([(x+5,289),(x+5,326),(x+28,326)],'cold1',2)
    p.line([(70,348),(97,348),(101,335),(108,358),(116,343),(147,343),(152,334),(159,354),(167,348),(248,348)],'mint2')
    # Disconnected machine test jig: ceramic terminals, wound coils and a
    # removable glass memory cell explain where permanent work is performed.
    for x in (69,122,181,248):
        p.screw(x,232);p.screw(x,363)
    for x in (87,147,207):
        p.metal(x-14,289,32,9,'brass',2)
        for yy in range(303,333,4):
            p.line([(x-8,yy),(x+13,yy)],'brass2',2)
            p.line([(x-5,yy-1),(x+10,yy-1)],'brass3')
    for xx in range(68,253,12):p.box(xx,370,5,2,'brass1')
    p.line([(72,299),(68,320),(72,337),(88,338)],'wine2',3)
    p.line([(231,299),(245,318),(240,338),(218,338)],'cold1',3)
    for xx in (111,172,231):
        p.oval(xx,256,12,12,'brass0');p.line([(xx+5,258),(xx+5,263)],'paper2')
    p.poly([(16,390),(298,390),(320,472),(0,472)],'wood2');p.line([(5,459),(314,459)],'wood4',2)
    symbol(p,'book',33,398);symbol(p,'syringe',241,403)
    p.line([(198,408),(226,437)],'cold2',4);p.oval(195,402,10,10,'cold0')
    p.metal(110,400,69,43,'brass',3);p.box(115,405,59,32,'cold0')
    p.line([(122,421),(128,413),(136,413),(140,421),(148,414),(156,414),(165,425)],'cold2',2)
    p.line([(120,436),(165,436)],'brass2')
    for xx in (43,270):
        p.line([(xx,445),(xx+6,451),(xx+17,451)],'paper0')
    for i,name in enumerate(('SHIFT','MEMORY','HYDRATION')):
        y=486+i*31;p.text(name,37,y,'paper2');p.text('INSPECT >',280,y,'brass3',align='right')
        p.line([(36,y+18),(283,y+18)],'wood2')
    button(p,83,589,154,'BACK')
    return p


def odds():
    p=Pixel();wall(p);heading(p,'ODDS TABLE','STAGE ONE LEVEL / DONE COMMITS THE PICK')
    table(p,235);pendant(p,160,114,54)
    p.poly([(31,170),(279,170),(291,548),(24,548)],'wood0')
    p.poly([(37,176),(273,176),(283,542),(31,542)],'paper1')
    p.text('HOUSE REGISTER / 07',160,193,'wine1',align='center')
    p.text('SYMBOL     LV     -   +',160,222,'wood1',align='center')
    for i,k in enumerate(('brain','eye','pill','syringe','vial','book')):
        y=250+i*44
        # All art stays on its original source pixels; no mixed-resolution thumbnails.
        symbol(p,k,47,y-4);p.text(k,97,y+12,'wood0')
        p.text(str(3 if i==1 else 2),197,y+12,'wine1')
        p.text('-',231,y+12,'wine1' if i==1 else 'paper0')
        p.text('+',263,y+12,'paper0')
        p.line([(43,y+37),(276,y+37)],'paper0')
    chip(p,65,568,15,'brass2',2);p.text('TOKENS 0',90,565,'paper2')
    p.text('EYE STAGED / MINUS RETURNS THE TOKEN',160,529,'wine1',align='center')
    button(p,178,557,108,'DONE');button(p,94,601,132,'BACK')
    return p


def collection():
    p=Pixel();wall(p);heading(p,'COLLECTION','AUGMENTS / POWERS / ACQUIRED ACROSS CAMPAIGNS')
    # A casino card folio laid on baize, not a room full of generic UI tiles.
    p.poly([(10,117),(153,110),(165,110),(310,117),(305,555),(165,547),(154,547),(15,555)],'wood1')
    p.poly([(16,123),(152,117),(156,540),(21,547)],'paper1')
    p.poly([(165,117),(303,124),(298,547),(164,540)],'paper2')
    p.line([(159,119),(160,539)],'wood0',4)
    for x,y,k in ((41,160,'augment_book'),(200,160,'augment_reward_1'),(41,346,'augment_smart_saving'),(200,346,'heart')):
        p.box(x-3,y+2,84,123,'paper0');p.paste(card(k,back=k=='heart'),x,y)
        p.text('LOCKED' if k=='heart' else 'INSPECT',x+39,y+137,'wine1',align='center')
    p.text('AUGMENTS',86,136,'wine1',align='center');p.text('POWERS',240,136,'wine1',align='center')
    p.text('LOCKED CARDS REVEAL NO IDENTITY',160,573,'paper1',align='center')
    button(p,81,595,158,'BACK')
    return p


def statistics():
    p=Pixel();wall(p);heading(p,'HOUSE RECORDS','YOUR ACCOUNT / EVERY VISIT REMAINS')
    pendant(p,160,103,48);table(p,295)
    # Fan-fold paper emerging from an actual mechanical tally printer.
    p.metal(41,148,237,109,'brass',7);p.box(49,157,221,76,'wood0')
    for i in range(8):
        x=64+i*24;p.metal(x,174,19,30,'paper',1);p.text(str(i%3),x+6,185,'wine1')
    p.box(55,222,209,16,'ink')
    p.poly([(72,234),(249,234),(256,345),(245,380),(254,501),(239,537),(68,537),(78,500),(68,381),(77,346)],'paper2')
    for y in (346,381,501):
        p.line([(77,y),(246,y)],'paper0')
        for x in range(82,243,7):p.box(x,y+2,2,1,'paper1')
    for i,(s,v) in enumerate((('RUNS','12'),('WEALTH','01'),('BEST SCORE','5000'),('PAIRS','134'),('TRIPLES','28'),('LUCIDITY','824'))):
        y=267+i*39;p.text(s,88,y,'wood1');p.text(v,232,y,'wine1',align='right')
    p.text('ILLUSTRATIVE ACCOUNT',160,556,'paper1',align='center')
    button(p,83,590,154,'BACK')
    return p


def settings(options=False):
    p=Pixel();wall(p);heading(p,'OPTIONS' if options else 'SOUND & SETTINGS','HOUSE CONTROL / PERSONAL PREFERENCES')
    pendant(p,160,112,58)
    # An actual house audio desk, with speaker grille and Bakelite knobs.
    p.poly([(27,215),(49,190),(270,190),(293,215),(300,512),(19,512)],'wood2')
    p.metal(35,214,250,280,'brass',5);p.box(41,220,238,268,'wood0')
    for y in range(236,279,4):
        for x in range(58,263,5):p.box(x+(2 if y%8 else 0),y,2,2,'brass1')
    p.line([(54,290),(267,290)],'brass0')
    if options:
        for i,s in enumerate(('RECORDS','SETTINGS','COLLECTION','TUTORIAL','LANGUAGE','MAIN MENU')):
            y=307+i*28;p.text(s,160,y,'paper2',align='center')
            p.line([(78,y+17),(242,y+17)],'wood2')
    else:
        for i,s in enumerate(('MASTER','MUSIC','EFFECTS')):
            y=316+i*49;p.text(s,57,y+6,'paper2')
            p.line([(122,y+10),(236,y+10)],'brass1',3)
            p.oval(185-i*17,y,24,24,'ink');p.oval(186-i*17,y,21,19,'wood3')
            p.line([(196-i*17,y+2),(196-i*17,y+7)],'paper3',2)
        p.text('MUTE',83,470,'paper2');p.metal(228,459,24,23,'brass',2)
    button(p,80,559,160,'CLOSE' if options else 'BACK')
    return p


def tutorial():
    p=pacte()
    # Translucent overlays are prohibited in source sprites: this is an opaque paper guide.
    p.poly([(28,112),(283,112),(291,264),(37,264)],'wood0')
    p.poly([(33,116),(279,116),(285,257),(41,258)],'paper2')
    filigree(p,44,125,229,123,'wine1')
    p.text('YOUR FIRST PACTE',160,135,'wine1',2,'center')
    p.wrap('Choose one augment from three. Then choose one power. Both are free at run start.',52,168,218,'wood0',13)
    p.text('HOLD A CARD TO READ IT.',52,224,'wine1')
    p.line([(69,259),(69,336),(61,353)],'paper3',2)
    p.poly([(54,345),(61,357),(66,343)],'paper3')
    return p


def ending(kind):
    p=Pixel();wall(p);table(p,344)
    if kind=='wealth':
        pendant(p,160,101,75);p.paste(portrait('late'),68,121)
        heading(p,'WEALTH','YOUR ACCOUNT IS READY TO CLOSE')
        for i in range(14):chip(p,53+(i%7)*36,423+(i//7)*42,16,'brass2',9+(i%3)*6)
        p.text('5000',160,522,'paper3',4,'center')
        button(p,29,586,128,'BANK');button(p,169,586,122,'CONTINUE')
    elif kind=='flatline':
        pendant(p,127,116,44);p.paste(portrait('doubt'),62,131)
        heading(p,'FLATLINE','THE HOUSE RETURNS YOUR SHARE')
        p.poly([(77,375),(246,385),(230,529),(67,518)],'paper2')
        p.text('ACCOUNT SETTLED',156,403,'wine1',align='center')
        p.line([(88,428),(226,438)],'paper0');p.text('KEPT LUCIDITY',151,458,'wood0',align='center')
        chip(p,160,492,18,'brass2',5)
        button(p,42,581,236,'CONTINUE')
    else:
        heading(p,'GAME OVER','NO CAMPAIGN NEURONS REMAIN')
        pendant(p,160,107,53)
        # Empty dealer place: more unsettling than a new monster illustration.
        p.poly([(109,208),(208,208),(215,338),(102,338)],'wood1')
        for x in (118,140,162,184,204):p.line([(x,217),(x,326)],'wood2',2)
        p.line([(104,338),(216,338)],'brass1',3)
        p.paste(card('memory',back=True),121,369)
        p.text('00',160,522,'paper0',3,'center');button(p,54,584,212,'MAIN MENU')
    return p


def unlock():
    p=Pixel();wall(p);table(p,318);heading(p,'CARD UNLOCKED','THE HOUSE HAS KEPT A PLACE FOR YOU')
    pendant(p,160,121,62)
    # Enlarged inspection is a nearest-neighbour display of the same 2x source card.
    face=card('heart').im
    p.paste(face.resize((312,488),resample=0),82,208)
    p.text('HEART',160,480,'paper3',2,'center')
    p.wrap('Guaranteed heart triple. Recover 1, 2 or 3 spins. Advances the gauge.',40,510,240,'paper2',13)
    button(p,24,583,142,'COLLECTION');button(p,177,583,119,'CONTINUE')
    return p


def inspection():
    p=Pixel();wall(p);heading(p,'CARD INSPECTION','SAME ART IN THE OFFER, INSPECTION AND COLLECTION')
    p.paste(card('augment_hallucination').im.resize((312,488),resample=0),82,112)
    p.text('HALLUCINATION',160,393,'paper3',2,'center')
    p.wrap('A visible pair becomes a triple at 30% of that payout. Natural triples and Book wins pay in full.',34,437,252,'paper2',16)
    button(p,65,576,190,'RETURN TO HAND')
    return p


SCENES = {
    '01_start':start,
    '02_pacte_augment':pacte,
    '03_pacte_power':lambda:pacte(True),
    '04_machine_early':machine,
    '05_machine_advanced':lambda:machine(True),
    '06_dealer_visit':dealer_visit,
    '07_routes':routes,
    '08_augment_selection':build,
    '09_power_selection':lambda:build(True),
    '10_shop':lambda:dealer_visit(True),
    '11_bonus':bonus,
    '12_sacrifice':sacrifice,
    '13_lab':lab,
    '14_odds':odds,
    '15_collection':collection,
    '16_statistics':statistics,
    '17_tutorial':tutorial,
    '18_settings':settings,
    '19_options':lambda:settings(True),
    '20_wealth':lambda:ending('wealth'),
    '21_flatline':lambda:ending('flatline'),
    '22_game_over':lambda:ending('game_over'),
    '23_unlock':unlock,
    '24_inspection':inspection,
    '25_machine_rescue':lambda:machine(True,warning=True),
    '26_machine_win':lambda:machine(payout=2),
}
