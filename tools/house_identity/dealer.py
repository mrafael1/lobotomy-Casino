"""Mr. Vey: deliberately asymmetric planes and hands, four persistent identities."""
from .pixels import Pixel, eye, chip

STATES = ('welcome','doubt','pressure','late')


def portrait(state='welcome', frame=0):
    p=Pixel(184,248)
    stage=STATES.index(state)
    # Stooped shoulders: one rolled sleeve higher than the other. No floating bust.
    p.poly([(44,124),(63,117),(74,109),(106,110),(120,123),(141,128),(160,151),
            (170,210),(153,230),(28,226),(13,209),(20,154)],'ink')
    p.poly([(43,128),(63,121),(79,128),(83,199),(40,198),(24,210),(17,203),(26,151)],'paper0')
    p.poly([(32,143),(45,132),(58,130),(55,181),(40,197),(24,201)],'paper2')
    p.poly([(33,148),(40,141),(47,140),(43,179),(33,186),(27,187)],'paper3')
    p.poly([(121,128),(140,135),(151,153),(165,202),(157,215),(143,201),(129,178)],'paper1')
    p.poly([(135,143),(143,150),(156,192),(147,194),(136,173)],'paper2')
    # Fabric folds radiate from the elbow, never randomly distributed texture.
    for pts in [[(28,182),(36,175),(40,153)],[(29,190),(42,181),(48,164)],
                [(145,178),(155,196),(151,201)],[(132,147),(138,168),(143,177)]]:
        p.line(pts,'paper0')
    p.poly([(30,169),(49,175),(48,181),(27,175)],'wine1')
    p.line([(29,170),(48,176)],'wine3');p.box(37,173,5,4,'brass2')
    p.poly([(141,169),(152,166),(154,173),(144,177)],'wine2')
    p.box(146,168,3,5,'brass3')
    # Waistcoat: piped revers, misaligned hand-wound watch chain, precise seams.
    p.poly([(63,122),(76,126),(87,153),(103,127),(118,122),(135,185),(144,221),(106,238),(86,225),(64,234),(41,218),(52,162)],'felt0')
    p.poly([(62,129),(75,133),(85,160),(82,222),(63,225),(47,216),(57,163)],'felt1')
    p.poly([(108,133),(117,130),(129,173),(137,214),(106,229),(89,221),(90,160)],'felt2')
    p.line([(63,126),(58,150),(72,147),(82,165),(82,218)],'felt3')
    p.line([(115,125),(123,150),(110,149),(92,166),(90,219)],'brass1')
    p.line([(57,208),(75,211)],'felt4');p.line([(105,208),(126,203)],'felt0',3)
    for yy in (176,190,204,218):
        p.oval(85,yy,4,4,'ink');p.box(85,yy,2,1,'brass3')
    p.arc((99,174,131,213),12,169,'brass2')
    p.arc((101,174,129,209),20,160,'brass3')
    # A membership tag reads 00: employee becomes an accounting entry.
    p.metal(108,158,15,8,'brass',1);p.text('00',110,159,'ink')
    # Neck and high collar. Late state exposes an old incised index, not gore.
    p.poly([(76,94),(105,93),(109,119),(99,137),(82,132),(70,116)],'skin1')
    p.poly([(82,100),(102,99),(102,117),(93,127),(80,118)],'skin3')
    p.poly([(70,111),(87,125),(83,144),(67,125)],'paper3')
    p.poly([(107,111),(94,125),(97,143),(114,125)],'paper2')
    p.poly([(87,126),(94,126),(98,133),(93,143),(96,164),(87,173),(83,162),(87,142),(83,134)],'wine0')
    p.line([(90,137),(90,159)],'wine2')
    if stage>=2:
        p.line([(99,106),(100,116),(104,118)],'skin0')
        for yy in (108,112,116):p.line([(97,yy),(102,yy-1)],'paper0')
    if stage==3:
        p.poly([(78,111),(84,118),(94,120),(100,117),(99,124),(90,129),(81,122)],'ink')
        for xx in range(82,97,3):p.line([(xx,120),(xx+1,123)],'paper1')
    # Head silhouette: high receding crescent, long broken nose, blunt left ear.
    p.contour((65,32),[((74,17),(101,15),(115,31)),((125,45),(125,70),(117,89)),
                        ((112,104),(100,115),(92,115)),((80,112),(68,99),(64,83)),
                        ((58,69),(57,46),(65,32))],'skin0')
    p.contour((70,32),[((82,23),(101,23),(111,33)),((119,48),(119,72),(112,89)),
                        ((107,103),(96,111),(90,109)),((78,105),(70,93),(67,77)),
                        ((63,59),(63,42),(70,32))],'skin2')
    p.contour((71,39),[((80,28),(98,28),(108,36)),((110,49),(104,56),(101,61)),
                        ((98,71),(98,79),(103,85)),((102,95),(96,104),(91,104)),
                        ((80,100),(76,86),(73,73)),((70,61),(68,48),(71,39))],'skin3')
    p.poly([(78,37),(86,32),(99,33),(105,39),(104,48),(90,46),(78,50)],'skin4')
    p.poly([(106,42),(115,47),(114,68),(109,74),(104,69)],'skin1')
    p.poly([(65,60),(59,57),(55,62),(58,76),(64,82),(68,76)],'skin2')
    p.line([(61,63),(59,65),(61,72),(64,73)],'skin0')
    p.poly([(119,59),(123,58),(126,62),(123,75),(118,79),(117,69)],'skin1')
    p.line([(122,63),(121,71)],'skin3')
    # Hair comb grooves follow the cranial volume; one silver crescent is constant.
    p.poly([(61,54),(61,39),(67,26),(77,20),(96,18),(109,22),(119,33),(122,48),
            (116,58),(112,44),(109,33),(98,27),(83,28),(72,37),(68,57)],'wood0')
    p.poly([(62,45),(67,32),(73,29),(70,45),(66,64),(62,61)],'cold1')
    p.line([(65,45),(68,34),(72,30)],'cold3')
    p.line([(70,28),(81,23),(96,22),(108,26)],'smoke')
    p.line([(74,30),(85,26),(97,25),(107,29)],'wood2')
    p.line([(111,33),(116,41),(117,49)],'smoke')
    # Forehead, sagging orbital plane, uneven lids. Gaze shifts before the head.
    p.line([(80,41),(95,40),(102,42)],'skin2')
    p.line([(78,45),(90,43),(100,44)],'skin2')
    p.poly([(70,56),(76,52),(86,54),(87,59),(77,59)],'skin1')
    p.poly([(100,53),(110,53),(115,58),(111,61),(101,59)],'skin0')
    blink=frame in (4,5)
    if blink:
        p.line([(74,62),(84,63)],'skin0',2)
        p.line([(102,62),(112,63)],'skin0',2)
    else:
        p.line([(73,61),(78,59),(85,61)],'skin0')
        p.box(75,61,10,3,'paper2');p.box(79+(1 if stage else 0),60,3,5,'cold0')
        p.box(80+(1 if stage else 0),60,1,2,'paper3')
        p.box(103,60,10,3,'paper1');p.box(107-(1 if frame==2 else 0),59,3,5,'ink')
        if stage>=2:p.box(108,60,1,2,'mint2')
        if stage==3:
            p.box(75,62,10,1,'mint2');p.box(106,60,1,5,'mint2')
    p.line([(75,66),(83,67),(86,65)],'skin1')
    p.line([(101,66),(109,68),(114,65)],'skin0')
    # Nose: crooked bridge catches light; its shadow is deliberately connected.
    p.poly([(91,54),(96,55),(96,69),(102,77),(100,81),(90,82),(87,79),(91,72)],'skin1')
    p.line([(92,57),(92,71),(90,77),(96,78)],'skin4',2)
    p.box(98,79,3,2,'skin0')
    p.poly([(72,73),(79,73),(83,80),(79,87),(74,82)],'skin2')
    p.line([(79,80),(82,86),(81,92)],'skin1')
    # Smile starts small; late corners extend without changing his identity.
    p.line([(84,89),(91,91),(99,90),(105,86)],'skin0')
    p.line([(87,93),(95,95),(101,92)],'skin4')
    p.box(99,88,3,1,'paper2')
    if stage>=1:
        p.line([(103,86),(108,82)],'skin0')
        p.line([(105,88),(109,85)],'skin2')
    if stage>=2:
        p.line([(82,89),(80,85)],'skin0')
        p.line([(85,90),(93,92),(104,88)],'paper1')
    if stage==3:
        p.line([(79,84),(78,80)],'skin0')
        p.line([(108,83),(111,78),(112,71)],'skin0')
        p.line([(80,100),(85,105),(95,108)],'cold1')
        # The face opens like an old printing plate. Baize and calibrated pins
        # occupy the seam, not blood; the crooked nose remains his recognisable anchor.
        p.poly([(113,44),(118,49),(117,73),(112,90),(105,101),(102,100),
                (108,85),(111,67)],'ink')
        p.poly([(115,52),(116,54),(114,72),(109,85),(108,80),(112,65)],'felt2')
        p.line([(113,45),(114,58),(111,76),(105,94)],'paper0')
        for xx,yy in ((114,54),(113,62),(112,70),(109,79),(106,89)):
            p.line([(xx-1,yy),(xx+2,yy)],'brass3')
        p.line([(102,72),(106,74),(109,72)],'cold1')
    # Elbows rest on the baize; hands do actual dealer work.
    p.poly([(24,202),(37,194),(52,201),(64,209),(70,221),(61,228),(45,222),(35,214),(22,213)],'skin1')
    p.poly([(29,201),(37,198),(49,204),(61,212),(64,218),(59,220),(47,213),(35,209),(28,209)],'skin3')
    p.line([(34,201),(45,205),(56,213)],'skin4')
    # Four individual tapered fingers, short clean nails and hard knuckle creases.
    for i in range(4):
        x=43+i*5;y=213+i
        p.poly([(x,y),(x+3,y-2),(x+13,y+8),(x+13,y+12),(x+10,y+12)],'skin2')
        p.line([(x+3,y),(x+10,y+7)],'skin4')
        p.box(x+9,y+7,3,2,'paper1')
    p.poly([(157,201),(148,196),(138,199),(128,207),(114,214),(106,225),(112,230),
            (127,223),(137,218),(152,218),(164,211)],'skin1')
    p.poly([(151,200),(144,200),(135,207),(122,213),(116,222),(125,219),(140,213),(155,211)],'skin3')
    for i in range(4):
        xx=121+i*7;yy=212+i*2
        p.line([(xx+6,yy-3),(xx,yy+8),(xx-3,yy+9)],'skin4',2)
        p.line([(xx+6,yy),(xx+2,yy+7)],'skin0')
    p.metal(137,207,6,5,'brass',1)
    # Bridge-sized card slides under his forefinger, not held like a magician.
    dx={0:0,1:2,2:4,3:6,4:6,5:0}.get(frame,0)
    p.poly([(x+dx,y) for x,y in [(76,215),(101,211),(111,233),(84,238)]],'ink')
    p.poly([(x+dx,y) for x,y in [(78,216),(100,213),(108,232),(85,235)]],'paper2')
    p.line([(x+dx,y) for x,y in [(81,218),(98,216),(105,231),(87,233),(81,218)]],'wine1')
    p.line([(x+dx,y) for x,y in [(88,222),(96,221),(100,228),(91,230),(88,222)]],'wine2')
    # Native-grid refinements: narrow satin edges, sewn buttonholes, folds and
    # knuckle creases. They follow anatomy and garment construction, not noise.
    for pts in (
        [(58,306),(68,288),(72,277)],[(61,355),(70,344),(75,324)],
        [(284,308),(295,333),(301,352)],[(282,361),(290,377),(297,384)],
    ):p.fine_line(pts,'cloth_mid')
    for yy in (176,190,204,218):
        p.fine_line([(177,yy*2+1),(184,yy*2+1)],'felt0')
        p.fine_line([(170,yy*2-2),(176,yy*2-2)],'felt3')
    for pts in (
        [(156,81),(168,78),(188,79),(198,82)],
        [(145,141),(149,151),(154,157)],[(204,147),(211,150),(215,149)],
        [(168,196),(180,203),(193,202)],
    ):p.fine_line(pts,'skin_mid')
    p.fine_line([(156,77),(169,72),(187,73),(199,77)],'skin_light')
    p.fine_line([(143,115),(148,111),(157,111)],'skin_light')
    p.fine_line([(205,114),(213,114),(219,118)],'skin1')
    for i in range(4):
        xx=91+i*10;yy=429+i*2
        p.fine_line([(xx,yy),(xx+5,yy+5)],'skin1')
        p.fine_line([(xx+2,yy-1),(xx+7,yy+4)],'skin_mid')
    for x,y in ((66,57),(68,51),(71,44)):
        p.fine_line([(x*2,y*2),(x*2+3,y*2-13)],'cold2')
    return p


def dealer_sheet():
    p=Pixel(824,380,'void')
    p.text('MR. VEY / THE HOUSE REMEMBERS',24,20,'brass3',2)
    for i,state in enumerate(STATES):
        x=18+i*202
        p.box(x,52,190,262,'ink')
        p.paste(portrait(state),x+3,57)
        p.text(f'0{i+1} / {state}',x+3,326,'paper3')
        cues=[['AN OPEN PALM.','THE SMILE ARRIVES FIRST.'],['THE EYES HOLD.','HIS HANDS NEVER FUMBLE.'],
              ['THE COLLAR OPENS.','A REFLECTION LOOKS BACK.'],['THE NAME TAG STILL READS 00.','THE HOUSE WEARS ITS EMPLOYEE.']][i]
        for j,line in enumerate(cues):p.text(line,x+3,345+j*12,'paper1')
    return p
