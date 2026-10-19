"""Twenty-one individual intaglio-like card illustrations on the shared 2x grid."""
from .pixels import Pixel, chip, eye, symbol

CARDS = [
('augment_pattern_recognition','PATTERN RECOGNITION','augment','Separated matching symbols count as a pair.'),
('augment_book','BOOK','augment','Adds the Book joker to the reels; the existing Book payout cut remains.'),
('augment_hallucination','HALLUCINATION','augment','Promotes visible pairs to triples at 30% of that payout. Natural triples and Book wins keep their existing payouts.'),
('augment_smart_saving','SMART SAVING','augment','Keeps the existing increased share of run Lucidity on flatline.'),
('augment_reward_1','REWARD + I','augment','Choose one symbol for the existing tier I reward amplification.'),
('augment_reward_2','REWARD + II','augment','Choose one symbol for the existing tier II reward amplification.'),
('augment_reward_3','REWARD + III','augment','Choose one symbol for the existing tier III reward amplification.'),
('augment_joker','JOKER','augment','After the first three-flatline strike, the dealer can provide the existing helpful power assists.'),
('augment_win_boost','COMBO','augment','Successive paying results add 5% per streak step, up to 45%. A miss opens the existing rescue window.'),
('augment_glitch_2','GLITCH','augment','Dealer countdown advances three steps per spin at every gauge tier.'),
('augment_tunnel_vision','TUNNEL VISION','augment','Hides the third reel and increases rewards by 50%.'),
('augment_how_to_cheat','IS IT CHEATING?','augment','A solo visible symbol counts as a pair; all pair payouts use x0.6.'),
('augment_adrenaline','ADRENALINE','augment','Power restore threshold is 18 Lucidity, with lamps at 6, 12, and 18.'),
('augment_passive_gain','PASSIVE GAIN','augment','Gains 10 run Lucidity on every spin, including misses.'),
('reroll','REROLL','power','Reroll one revealed reel.'),
('shift','SHIFT','power','Step one revealed reel along the symbol cycle.'),
('memory','LOCK','power','Lock one reel through upcoming spins.'),
('rewind','REWIND','power','Restore the previous spin state and recover 1-3 eligible other power chips. Earned score and Lucidity remain.'),
('heart','HEART','power','A free matching heart triple restores 1, 2, or 3 spins with equal odds and advances the gauge.'),
('cheat','CHEAT','power','Replace one selected revealed reel with a symbol from the existing chooser.'),
('swap','SWAP','power','Drag a visible symbol to another reel and swap it with that reel centre.'),
]


def hand(p,x,y,pose='pinch'):
    p.poly([(x,y+29),(x+4,y+15),(x+7,y+5),(x+11,y+3),(x+15,y+6),(x+14,y+15),
            (x+22,y+10),(x+27,y+12),(x+29,y+18),(x+24,y+27),(x+19,y+34),(x+3,y+36)],'skin0')
    p.poly([(x+3,y+28),(x+7,y+15),(x+9,y+6),(x+12,y+6),(x+11,y+20),(x+22,y+14),
            (x+25,y+16),(x+21,y+22),(x+17,y+23),(x+18,y+31),(x+8,y+33)],'skin3')
    p.line([(x+8,y+28),(x+12,y+23),(x+17,y+24)],'skin1')
    p.line([(x+10,y+8),(x+9,y+15)],'paper2')
    for i in range(3):p.line([(x+20+i*2,y+17+i*3),(x+16+i*2,y+21+i*3)],'skin1')
    p.poly([(x,y+31),(x+18,y+34),(x+17,y+39),(x-2,y+36)],'paper2')
    p.line([(x+1,y+34),(x+15,y+37)],'paper0')


def drawing(key,frame=0):
    p=Pixel(64,67,'ink')
    # Fine engraved corner rays: shared printing language, different subject staging.
    for i in range(4):
        p.line([(2+i*3,4),(2,4+i*3)],'brass0')
        p.line([(61-i*3,62),(61,62-i*3)],'brass0')
    if key=='augment_pattern_recognition':
        # Three specimen windows connected by a seeking line. Five-frame eye travel.
        for i,x in enumerate((4,24,44)):
            p.metal(x,19,17,29,'brass',1);p.box(x+2,21,13,25,'felt0')
            if i!=1:
                p.oval(x+4,27,9,11,'paper2');p.box(x+7,29,3,7,'ink')
            else:p.line([(x+3,35),(x+13,35)],'wine2')
        p.line([(12,18),(12,10),(52,10),(52,18)],'mint1')
        p.box(10+frame*10,9,5,3,'mint3')
        p.line([(12,49),(12,56),(52,56),(52,49)],'brass2')
    elif key=='augment_book':
        p.oval(7,52,51,10,'wood0');symbol(p,'book',12,10)
        p.line([(41,12),(46,4),(48,6),(43,15),(41,12)],'brass3')
        p.poly([(46,5),(51,5),(49,15),(43,22),(43,14)],'paper2')
        p.line([(37,32),(55,30),(55,47),(39,49)],'wine2')
        for y in range(34,46,3):p.box(41,y,10,1,'paper0')
    elif key=='augment_hallucination':
        p.poly([(9,14),(32,5),(54,17),(54,49),(33,60),(9,48)],'cold0')
        p.poly([(12,17),(31,10),(31,55),(12,46)],'cold1')
        p.poly([(34,11),(51,19),(51,46),(34,55)],'wine1')
        eye(p,14,25,19);eye(p,34,24,17,True)
        p.line([(31,10),(33,21),(30,29),(35,38),(32,54)],'paper2')
        p.line([(14,44),(26,47)],'paper1');p.line([(38,44),(48,40)],'wine3')
    elif key=='augment_smart_saving':
        p.poly([(8,24),(32,14),(56,25),(56,48),(32,60),(8,48)],'wood1')
        p.poly([(10,26),(31,18),(53,27),(32,36)],'wood3')
        p.poly([(12,30),(30,38),(30,55),(12,46)],'wood2')
        p.poly([(33,38),(53,29),(53,46),(33,55)],'wood0')
        p.line([(17,28),(29,33),(43,28)],'ink',2)
        chip(p,31,16,9,'brass2',3);hand(p,35,1)
        p.metal(29,40,8,10,'brass',1);p.box(32,43,2,4,'ink')
    elif key=='augment_reward_1':
        # Tier I is a jeweller's loupe focused on one chosen chip.
        chip(p,26,41,17,'felt2',2)
        p.oval(16,10,32,32,'brass0');p.oval(18,11,28,28,'brass2');p.oval(21,14,22,22,'cold0')
        eye(p,22,20,20);p.line([(41,37),(55,54)],'wood3',5)
        p.line([(44,38),(56,52)],'brass3',2)
    elif key=='augment_reward_2':
        # Tier II is an optical bench with two lenses, not the same loupe recoloured.
        p.poly([(5,49),(48,42),(59,49),(16,58)],'wood2')
        p.line([(10,50),(49,45)],'brass3',2)
        for x,y in ((16,20),(37,12)):
            p.line([(x+6,y+10),(x+6,47)],'brass1',3)
            p.oval(x,y,16,25,'brass2');p.oval(x+3,y+2,10,19,'cold1')
            p.line([(x+5,y+5),(x+5,y+13)],'mint2')
        p.line([(6,37),(50,18)],'paper2')
        chip(p,8,40,6,'wine2')
    elif key=='augment_reward_3':
        # Tier III is a crown press: a different silhouette and a physical amplification.
        p.poly([(7,55),(7,48),(12,46),(12,19),(6,19),(6,12),(56,12),(56,19),(50,19),(50,46),(57,49),(57,55)],'brass1')
        p.box(15,20,5,26,'brass3');p.box(45,20,3,26,'brass2')
        p.line([(32,8),(32,31)],'cold2',4)
        for y in range(10,29,4):p.line([(29,y),(35,y+2)],'cold0')
        p.metal(23,30,19,7,'brass',1);chip(p,32,44,12,'wine2',4)
        p.poly([(23,11),(21,3),(28,7),(32,1),(36,7),(43,3),(41,11)],'paper2')
    elif key=='augment_joker':
        # The house's spare hand; an empty cuff shelters three tiny gaming pieces.
        p.poly([(7,16),(19,10),(31,23),(25,41),(14,45),(3,33)],'wine2')
        p.poly([(14,20),(23,19),(27,24),(23,36),(17,37),(12,31)],'paper2')
        p.line([(19,23),(23,25),(19,30)],'ink')
        hand(p,30,15)
        for x,y in ((13,52),(29,55),(46,55)):chip(p,x,y,7,'brass2')
        p.line([(5,15),(10,6),(17,9),(21,4),(29,13)],'brass3')
    elif key=='augment_win_boost':
        # Ratcheted staircase of chips, with each level physically held by the next.
        for i in range(5):
            x=9+i*10;y=54-i*8
            p.line([(x-4,60),(x-4,y+4)],'brass1',3)
            chip(p,x,y,8,'wine2' if i%2 else 'felt2',i*2)
        p.line([(8,33),(18,33),(18,24),(28,24),(28,15),(38,15),(38,6),(52,6)],'paper2')
        p.poly([(51,3),(57,6),(51,9)],'brass3')
    elif key=='augment_glitch_2':
        # No emblem: interrupted letterpress registration and missing paper centre.
        for y in (9,16,23,43,50,57):
            p.line([(7,y),(26,y),(29,y+2),(54,y+2)],'paper0')
        p.box(3,28,58,11,'wine0');p.box(0,31,22,2,'paper2');p.box(41,37,23,2,'mint1')
        p.line([(29,1),(32,16),(28,26),(35,39),(31,52),(33,65)],'ink',3)
        p.text('3',42,12,'paper2',2)
    elif key=='augment_tunnel_vision':
        # Telescoping black shutters converge on two surviving apertures.
        for i in range(6):
            x=3+i*4;y=5+i*4
            p.line([(x,61-i*4),(x,y),(61-i*4,y),(61-i*4,61-i*4)],'brass1' if i%2 else 'cold0')
        eye(p,23,27,19)
        p.poly([(48,7),(60,4),(60,62),(48,56)],'wood1')
        for y in range(9,58,5):p.line([(49,y),(59,y-2)],'wood3')
    elif key=='augment_how_to_cheat':
        # One card casting a second impossible card shadow. The thumb supplies motion.
        p.poly([(24,12),(47,7),(56,45),(33,50)],'cold0')
        p.poly([(13+frame,17),(35+frame,12),(44+frame,50),(22+frame,55)],'paper2')
        p.line([(17+frame,20),(32+frame,17),(39+frame,46),(25+frame,50),(17+frame,20)],'wine2')
        eye(p,23+frame,29,13);hand(p,-3,29)
    elif key=='augment_adrenaline':
        # A pressure bulb and needle, not a generic lightning bolt.
        p.oval(7,6,37,37,'brass1');p.oval(10,8,31,31,'paper2')
        p.arc((14,12,36,34),180,350,'ink')
        for x,y in ((15,23),(18,16),(26,14),(33,19)):p.box(x,y,2,3,'wine1')
        p.line([(26,26),(34,16)],'wine2',2);p.oval(24,24,5,5,'brass0')
        p.line([(25,42),(25,53),(48,53),(51,42)],'cold1',3)
        p.oval(43,32,16,24,'wine2');p.line([(46,37),(46,46)],'wine4',2)
    elif key=='augment_passive_gain':
        # A coin drips from a calibrated brass tap into an abandoned betting circle.
        p.line([(11,6),(11,21),(36,21),(36,29)],'brass1',7)
        p.line([(10,7),(10,19),(37,19)],'brass3',2)
        p.metal(6,5,16,5,'brass',1);p.box(8,1,3,4,'brass2');p.box(17,1,3,4,'brass2')
        chip(p,35,37,6,'brass3');chip(p,29,54,17,'felt2',4)
        p.text('10',22,52,'paper2')
    elif key=='reroll':
        # A hand turns a numbered drum; spiral registration indicates a full revolution.
        p.oval(8,8,43,44,'brass0');p.oval(10,9,39,40,'paper2')
        p.box(11,27,38,5,'paper0');p.box(13,29,34,2,'paper3')
        p.text('7',26,15,'wine1',2);p.text('1',28,37,'wood1')
        p.arc((3,2,56,58),195,105,'mint1',2);p.poly([(52,11),(59,17),(50,19)],'mint2')
        hand(p,36,28)
    elif key=='shift':
        # A toothed escapement advances a vertical strip one cell only.
        p.metal(16,3,28,56,'brass',2);p.box(20,6,20,50,'paper2')
        for yy in (8,27,46):
            p.box(18,yy,3,5,'ink');p.box(40,yy,3,5,'ink')
        p.text('1',27,8,'wood1');p.text('2',25,27,'wine1');p.text('3',25,46,'wood1')
        p.line([(7,46),(7,26),(12,26)],'mint2',2);p.poly([(8,21),(15,26),(8,31)],'mint2')
        p.line([(48,25),(55,25),(55,39)],'brass2',3)
    elif key=='memory':
        # A real hasp clamps the perforated reel strip.
        p.box(12,4,35,58,'paper1')
        for yy in range(7,59,7):p.box(14,yy,3,3,'wood1');p.box(42,yy,3,3,'wood1')
        p.oval(19,15,24,27,'brass2');p.oval(23,19,16,20,'ink');p.box(18,29,26,24,'wine1')
        p.metal(20,30,22,20,'brass',2);p.oval(28,36,7,7,'ink');p.box(30,41,3,5,'ink')
        p.line([(23,32),(37,32)],'paper2')
    elif key=='rewind':
        # Spool and loose memory ribbon form a backwards S, with physical sprockets.
        p.oval(5,6,36,36,'brass1');p.oval(9,9,28,28,'cold0');p.oval(17,17,12,12,'brass2')
        for xx,yy in ((19,11),(29,20),(17,30),(11,20)):p.oval(xx,yy,5,5,'ink')
        p.line([(35,28),(52,35),(50,49),(18,54),(10,48)],'wine2',7)
        p.line([(34,27),(52,34),(50,47),(19,52)],'paper1')
        for xx in (22,29,36,43):p.box(xx,49,2,2,'ink')
        p.poly([(16,43),(6,48),(16,54)],'paper2')
    elif key=='heart':
        # Suspended anatomical heart held in a croupier's chip rack.
        symbol(p,'heart',11,6)
        p.line([(12,46),(12,57),(53,57),(53,46)],'brass2',3)
        for x in (19,31,43):chip(p,x,51,7,'brass2')
        p.line([(7,28),(12,28),(15,24)],'mint1')
    elif key=='cheat':
        # Sliding the false face over a legitimate one. Cuff and thumb tell the act.
        p.poly([(7,10),(31,6),(39,48),(15,52)],'paper1')
        p.text('7',17,15,'wood1',2)
        p.poly([(27,13),(50,16),(46,56),(22,53)],'wine2')
        p.line([(30,18),(46,20),(43,51),(27,49),(30,18)],'brass2')
        eye(p,29,31,14);hand(p,37,3)
    elif key=='swap':
        # Crossed dealing arms exchange different pieces across a baize seam.
        p.line([(5,43),(23,21),(38,45),(57,23)],'paper1',5)
        p.line([(5,44),(23,22),(38,46),(57,24)],'skin2',3)
        chip(p,14,20,11,'wine2',2);chip(p,48,47,11,'felt2',2)
        p.line([(9,8),(43,8),(51,16)],'mint1',2)
        p.poly([(48,11),(55,18),(46,19)],'mint2')
        p.line([(55,59),(21,59),(13,51)],'brass2',2)
        p.poly([(16,56),(9,49),(18,48)],'brass3')
    else:
        raise ValueError(key)
    return p


def card(key,frame=0,back=False):
    meta=next(c for c in CARDS if c[0]==key)
    p=Pixel(78,122)
    family=meta[2]
    p.metal(0,0,78,122,'paper' if family=='augment' else 'brass',4)
    p.box(3,3,72,116,'paper2' if family=='augment' else 'wine0')
    border='felt1' if family=='augment' else 'brass2'
    p.line([(5,7),(5,114),(72,114),(72,7),(5,7)],border)
    for x,y in ((7,9),(69,9),(7,110),(69,110)):
        p.poly([(x,y-2),(x+2,y),(x,y+2),(x-2,y)],border)
    if back:
        p.box(9,14,60,93,'felt0' if family=='augment' else 'wine1')
        for y in range(18,103,8):
            for x in range(13,65,8):
                p.line([(x,y),(x+3,y+3),(x,y+6),(x-3,y+3),(x,y)],'felt2' if family=='augment' else 'wine2')
        p.oval(18,37,42,45,'brass1');p.oval(21,40,36,39,'ink')
        p.text('LC',39,54,'brass3',2,'center');p.text('THE HOUSE',39,91,'paper2',align='center')
        return p
    p.box(7,16,64,67,'ink');p.paste(drawing(key,frame),7,16)
    # Readable name is live text in integration; mockups show the intended typesetting.
    words=meta[1].split();lines=[];line=''
    for word in words:
        from .pixels import text_width
        if text_width((line+' '+word).strip())>64 and line:lines.append(line);line=word
        else:line=(line+' '+word).strip()
    lines.append(line)
    for i,s in enumerate(lines):
        # Tighten print tracking for long single words without changing the
        # source-pixel size, distorting glyphs, clipping or renaming the card.
        tracking=0 if text_width(s)>64 else 1
        assert text_width(s,tracking=tracking)<=64,meta[1]
        p.text(s,39,88+i*9,'felt0' if family=='augment' else 'paper3',align='center',tracking=tracking)
    p.line([(17,109),(30,109)],border);p.line([(47,109),(60,109)],border)
    p.oval(36,106,6,6,border)
    # A few deliberate nicks at the handled corners, not image-wide random wear.
    p.box(2,115,2,2,'paper0');p.box(73,4,2,3,'paper3');p.box(9,119,9,1,'paper1')
    # Engraved edge work at the refined common source grid. Both decks retain
    # their distinct print families and the same individual illustrations.
    for yy in (27,53,79,105,131,157):
        p.fine_line([(12,yy),(14,yy+3),(12,yy+6)],border)
        p.fine_line([(143,yy),(141,yy+3),(143,yy+6)],border)
    p.fine_line([(19,9),(135,9)],'paper3' if family=='augment' else 'brass_dull')
    p.fine_line([(21,232),(134,232)],'paper0' if family=='augment' else 'wine2')
    return p


def card_sheet():
    p=Pixel(716,510,'void')
    p.text('THE HOUSE DECKS',22,17,'brass3',2)
    p.text('14 AUGMENTS / 7 POWERS / EVERY FACE HAS ITS OWN SCENE',22,42,'paper1')
    for i,(key,name,family,effect) in enumerate(CARDS):
        x=22+(i%7)*100;y=65+(i//7)*146
        p.paste(card(key),x,y)
        p.text(f'{i+1:02}',x,y+128,'brass2')
    return p
