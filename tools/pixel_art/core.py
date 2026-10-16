"""Integer-grid drawing vocabulary. No artwork is read, filtered or quantized."""
from PIL import Image, ImageDraw

# Shared 38-colour material ramps. Highlights travel toward warm bone; shadows
# travel toward blue-black. Each ramp describes planes, never a noisy texture.
P = {
    'void':'080b12', 'ink':'11151e', 'shadow':'1c202b', 'steel0':'252c38',
    'steel1':'3d4854', 'steel2':'65747b', 'steel3':'a3b1aa', 'white':'f6edd1',
    'red0':'291321', 'red1':'501e2c', 'red2':'7e2635', 'red3':'b33b40',
    'red4':'e96752', 'red5':'f8af71', 'gold0':'382a27', 'gold1':'69503a',
    'gold2':'a5804c', 'gold3':'d9b86f', 'gold4':'f3d99b', 'bone0':'796c58',
    'bone1':'b8ac84', 'bone2':'e1d4a4', 'green0':'10252b', 'green1':'1c4243',
    'green2':'2d6960', 'green3':'5aa88b', 'green4':'a4d6aa', 'cyan':'73e6cb',
    'teal':'39a99d', 'flesh0':'492734', 'flesh1':'7d4350', 'flesh2':'b86b6b',
    'flesh3':'e69c8b', 'purple0':'35263e', 'purple1':'79506b', 'purple2':'bb82a1',
    'blue':'5482aa', 'blue0':'263b59',
}


def color(key):
    if key is None:
        return (0, 0, 0, 0)
    if isinstance(key, tuple):
        return key
    value = P.get(key, key).lstrip('#')
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4)) + (255,)


class Canvas:
    def __init__(self, w, h, fill=None):
        self.image = Image.new('RGBA', (int(w), int(h)), color(fill))
        self.d = ImageDraw.Draw(self.image)

    def box(self, x, y, w, h, fill):
        x, y, w, h = map(round, (x, y, w, h))
        if w > 0 and h > 0:
            self.d.rectangle((x, y, x+w-1, y+h-1), fill=color(fill))

    def line(self, points, fill, width=1):
        self.d.line([(round(x), round(y)) for x, y in points], fill=color(fill), width=round(width))

    def poly(self, points, fill):
        self.d.polygon([(round(x), round(y)) for x, y in points], fill=color(fill))

    def ellipse(self, x, y, w, h, fill):
        self.d.ellipse((round(x), round(y), round(x+w-1), round(y+h-1)), fill=color(fill))

    def paste(self, image, x, y):
        if isinstance(image, Canvas):
            image = image.image
        self.image.alpha_composite(image, (round(x), round(y)))

    def bevel(self, x, y, w, h, material='red', cut=2):
        ramp = {'red':('red0','red1','red2','red3','red4'),
                'steel':('ink','steel0','steel1','steel2','steel3'),
                'gold':('gold0','gold1','gold2','gold3','gold4'),
                'bone':('gold0','bone0','bone1','bone2','white'),
                'green':('ink','green0','green1','green2','green3')}[material]
        dark, low, mid, high, light = ramp
        self.poly([(x+cut,y),(x+w-cut-1,y),(x+w-1,y+cut),(x+w-1,y+h-cut-1),
                   (x+w-cut-1,y+h-1),(x+cut,y+h-1),(x,y+h-cut-1),(x,y+cut)],dark)
        self.poly([(x+cut,y+1),(x+w-cut-1,y+1),(x+w-2,y+cut),(x+w-2,y+h-cut-2),
                   (x+w-cut-2,y+h-2),(x+cut,y+h-2),(x+1,y+h-cut-2),(x+1,y+cut)],mid)
        self.line([(x+cut,y+1),(x+w-cut-2,y+1),(x+w-2,y+cut)],high)
        self.line([(x+1,y+cut),(x+1,y+h-cut-2)],high)
        self.line([(x+cut,y+h-2),(x+w-cut-2,y+h-2),(x+w-2,y+h-cut-2)],low)
        if w > 12:
            self.line([(x+cut+2,y+1),(x+min(w//3,20),y+1)],light)

    def screw(self, x, y, brass=False):
        self.box(x-1,y-1,3,3,'ink')
        self.box(x-1,y-1,2,1,'gold3' if brass else 'steel3')
        self.box(x,y,1,2,'gold1' if brass else 'steel1')

    def text(self, text, x, y, fill='bone2', scale=1, center=False):
        text = text.upper()
        if center:
            x -= (len(text)*4-1)*scale//2
        for ch in text:
            rows = FONT.get(ch, FONT['?'])
            for yy, row in enumerate(rows.split('/')):
                for xx, bit in enumerate(row):
                    if bit == '1':
                        self.box(x+xx*scale,y+yy*scale,scale,scale,fill)
            x += 4*scale


FONT = dict(zip(
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 +-:/!?X.%',
    ['010/101/111/101/101','110/101/110/101/110','011/100/100/100/011',
     '110/101/101/101/110','111/100/110/100/111','111/100/110/100/100',
     '011/100/101/101/011','101/101/111/101/101','111/010/010/010/111',
     '001/001/001/101/010','101/101/110/101/101','100/100/100/100/111',
     '101/111/111/101/101','101/111/111/111/101','010/101/101/101/010',
     '110/101/110/100/100','010/101/101/111/011','110/101/110/101/101',
     '011/100/010/001/110','111/010/010/010/010','101/101/101/101/111',
     '101/101/101/101/010','101/101/111/111/101','101/101/010/101/101',
     '101/101/010/010/010','111/001/010/100/111',
     '111/101/101/101/111','010/110/010/010/111','110/001/010/100/111',
     '110/001/010/001/110','101/101/111/001/001','111/100/110/001/110',
     '011/100/111/101/111','111/001/010/010/010','111/101/111/101/111',
     '111/101/111/001/110','000/000/000/000/000','000/010/111/010/000',
     '000/000/111/000/000','000/010/000/010/000','001/001/010/100/100',
     '010/010/010/000/010','110/001/010/000/010','101/101/010/101/101',
     '000/000/000/000/010','101/001/010/100/101']))


def scaled(image, size):
    if isinstance(image, Canvas):
        image = image.image
    return image.resize(tuple(map(int, size)), Image.Resampling.NEAREST)


def sheet(frames):
    out = Canvas(sum(f.image.width for f in frames), frames[0].image.height)
    x = 0
    for frame in frames:
        out.paste(frame,x,0)
        x += frame.image.width
    return out


def icon(name, size=24, phase=0):
    """Anatomy and emblems drawn at 24px; small variants retain the same clusters."""
    c = Canvas(24,24)
    n = name.lower().replace('augment_', '').replace('power_', '')
    n = {'book_32':'book','scalpel_32':'syringe','lock':'memory', 'move':'swap',
         'cons_cigarette':'tobacco','cigarette':'tobacco','focus_serum':'serum',
         'herbal_tea':'tea','pill_item':'red_pill','win_boost':'combo'}.get(n,n)
    if n == 'brain':
        c.poly([(4,7),(7,3),(12,2),(17,3),(21,8),(21,15),(17,19),(7,19),(3,15),(2,10)],'ink')
        c.poly([(5,7),(8,4),(12,3),(17,5),(20,9),(19,16),(15,18),(7,17),(4,13)],'flesh2')
        c.poly([(5,8),(8,5),(11,5),(9,8),(7,8),(7,11),(4,12)],'flesh3')
        c.poly([(13,5),(16,5),(19,9),(17,9),(15,7),(13,9)],'flesh3')
        for pts in [[(11,4),(12,7),(10,10),(12,13),(11,17)],[(6,7),(8,9),(7,12),(5,13)],[(7,15),(9,13),(9,11)],[(14,10),(17,11),(18,14),(16,16)],[(16,7),(14,8),(14,12),(13,15)]]:
            c.line(pts,'flesh0')
        c.box(11,19,3,3,'flesh1')
    elif n in ('eye','hallucination','pattern_recognition'):
        c.poly([(1,12),(5,6),(11,4),(16,5),(22,11),(22,14),(18,19),(8,19),(3,17)],'ink')
        c.poly([(3,12),(7,7),(12,6),(17,8),(21,12),(18,17),(10,18),(5,16)],'bone2')
        c.ellipse(8,7,10,11,'green2' if n=='eye' else 'purple1')
        c.ellipse(10,9,6,7,'ink')
        c.box(10,9,2,3,'white'); c.box(15,15,2,1,'green4')
        c.line([(4,13),(7,14),(8,16)],'flesh2')
        if n=='pattern_recognition':
            c.box(2+phase%5*4,21,3,2,'cyan')
    elif n in ('pill','red_pill'):
        # A broad two-part capsule survives both the 16px result and 12px neighbours.
        # Its pale half must remain distinct from the warm paper drum behind it.
        c.poly([(1,9),(3,6),(6,5),(18,5),(21,7),(22,10),(22,15),(20,18),(18,19),(6,19),(3,17),(1,14)],'ink')
        c.poly([(3,10),(5,7),(7,7),(17,7),(20,9),(20,14),(18,17),(7,17),(4,15),(3,13)],'white')
        c.poly([(12,7),(17,7),(20,9),(20,14),(18,17),(12,17)],'red3')
        c.line([(12,7),(12,17)],'red1')
        c.line([(14,8),(17,8),(18,9)],'red5')
        c.line([(6,16),(10,16)],'bone1');c.line([(14,16),(18,16)],'red1')
    elif n in ('syringe','adrenaline'):
        c.line([(3,21),(20,4)],'ink',3)
        c.line([(2,21),(7,16)],'steel3')
        c.poly([(6,13),(12,7),(17,12),(11,18)],'steel0')
        c.poly([(7,13),(12,8),(15,11),(10,16)],'bone2')
        c.line([(8,14),(13,9)],'flesh2',2)
        c.line([(9,11),(12,14)],'steel1')
        c.line([(16,4),(20,8)],'gold2',2)
        c.line([(18,2),(22,6)],'steel3',2)
        c.line([(16,5),(19,3)],'steel3')
    elif n in ('vial','serum','potion','water','energy_drink'):
        col = {'vial':'green2','serum':'blue','potion':'purple1','water':'teal','energy_drink':'gold2'}[n]
        c.bevel(7,3,10,4,'gold' if n=='vial' else 'steel',1)
        c.box(8,7,8,3,'steel1')
        c.bevel(5,9,14,13,'steel',2)
        c.box(7,11,10,8,col)
        c.box(7,11,2,7,'white'); c.box(9,19,7,1,'steel3')
        if n=='water':
            c.poly([(12,12),(9,16),(12,18),(15,16)],'bone2')
        elif n=='energy_drink':
            c.poly([(13,10),(9,15),(12,15),(10,19),(16,13),(13,13)],'red1')
        else:
            c.box(11,13,4,4,'green4' if n=='vial' else 'bone2')
    elif n.startswith('heart'):
        c.poly([(3,6),(7,3),(11,4),(12,6),(14,4),(18,3),(22,6),(22,11),(12,22),(2,11)],'ink')
        c.poly([(4,6),(7,5),(10,6),(12,9),(15,6),(18,5),(20,7),(20,11),(12,19),(4,11)],'red3')
        c.poly([(5,7),(8,6),(10,8),(8,10),(5,10)],'flesh3')
        c.poly([(13,15),(19,9),(19,12),(12,19),(6,13)],'red1')
        if n.endswith(('1','2','3')):
            c.text(n[-1],11,11,'white')
    elif n in ('flatline','passive_gain','combo'):
        c.line([(1,13),(6,13),(8,8),(11,17),(14,5),(17,13),(22,13)],'ink',3)
        c.line([(1,12),(6,12),(8,7),(11,16),(14,4),(17,12),(22,12)],'red4' if n=='flatline' else 'cyan')
        if n=='combo': c.text('X',10,19,'gold3')
    elif n in ('book','learning'):
        c.poly([(4,4),(16,2),(20,5),(20,20),(8,23),(3,19)],'ink')
        c.poly([(5,5),(16,3),(18,5),(7,8),(5,7)],'bone2')
        c.poly([(7,8),(19,5),(19,19),(8,22)],'red1')
        c.box(4,8,3,12,'red2'); c.line([(9,9),(16,7),(16,17),(9,19),(9,9)],'gold2')
        c.ellipse(10,11,6,5,'gold3'); c.box(12,12,2,3,'ink')
    elif n=='memory':
        c.ellipse(6,2,12,15,'ink'); c.ellipse(8,4,8,11,'gold3'); c.ellipse(10,6,4,9,'ink')
        c.bevel(4,11,17,12,'gold',2); c.box(11,15,3,5,'ink'); c.box(10,14,5,3,'ink')
    elif n=='smart_saving':
        c.bevel(2,3,20,19,'gold',2);c.bevel(5,6,14,13,'steel',1)
        c.ellipse(7,8,8,8,'gold2');c.line([(8,12),(13,12)],'bone2');c.line([(11,9),(11,15)],'bone2')
        c.box(18,8,2,2,'gold4');c.box(18,16,2,2,'gold4')
    elif n in ('reroll','shift','rewind','swap','cheat','how_to_cheat'):
        if n in ('cheat','how_to_cheat'):
            c.bevel(5,2,15,20,'bone',1)
            c.poly([(12,6),(8,11),(12,14),(16,11)],'red2'); c.box(11,13,3,4,'red2')
            c.box(7,4,2,3,'red2'); c.box(16,17,2,3,'red2')
        elif n=='reroll':
            c.line([(18,6),(14,3),(7,4),(3,9),(4,16),(9,20),(16,18),(20,13)],'gold3',3)
            c.poly([(16,2),(21,7),(15,9)],'gold3')
        elif n=='shift':
            c.line([(4,7),(19,7)],'gold3',3);c.poly([(15,2),(21,7),(15,12)],'gold3')
            c.line([(5,17),(20,17)],'gold3',3);c.poly([(8,12),(2,17),(8,22)],'gold3')
        elif n=='rewind':
            c.poly([(11,4),(2,12),(11,20)],'gold3'); c.poly([(21,4),(12,12),(21,20)],'gold3')
        else:
            c.line([(3,5),(20,18)],'gold3',3); c.line([(3,18),(20,5)],'gold3',3)
            c.poly([(15,3),(22,3),(22,10)],'gold3');c.poly([(15,20),(22,20),(22,13)],'gold3')
    elif n in ('tobacco','cocktail','tea','white_powder'):
        if n=='tobacco':
            c.poly([(2,16),(19,7),(22,11),(5,20)],'ink')
            c.line([(5,16),(19,9)],'bone2',3); c.line([(2,18),(6,16)],'red4',3)
            c.line([(3,12),(5,9),(4,6),(7,3)],'steel2')
        elif n=='tea':
            c.ellipse(17,10,6,8,'gold2');c.ellipse(18,12,3,4,'ink')
            c.bevel(3,10,16,11,'bone',2);c.ellipse(4,8,14,6,'green0');c.line([(6,10),(14,10)],'green3')
            c.line([(9,6),(8,4),(10,2)],'steel2')
        elif n=='cocktail':
            c.poly([(2,5),(22,5),(13,15),(11,15)],'steel3')
            c.poly([(5,7),(19,7),(12,13)],'purple1');c.box(11,15,2,5,'steel3');c.box(6,21,12,1,'steel3')
            c.line([(14,9),(19,1),(22,1)],'gold3')
        else:
            c.poly([(7,2),(17,2),(20,6),(20,21),(4,21),(4,6)],'ink')
            c.poly([(8,3),(16,3),(18,7),(18,19),(6,19),(6,7)],'bone2')
            c.line([(8,5),(16,5)],'bone0'); c.poly([(8,15),(11,11),(15,15),(16,17),(8,17)],'white')
    elif n.startswith('reward'):
        c.ellipse(3,3,18,18,'gold0');c.ellipse(4,3,16,16,'gold2');c.ellipse(6,5,12,12,'gold3')
        c.text('+',9,8,'gold0',2)
        for k in range(int(n[-1]) if n[-1:].isdigit() else 1): c.box(7+k*4,21,3,2,'cyan')
    elif n in ('tunnel_vision','vision'):
        c.bevel(2,5,21,15,'steel',2); c.box(4,7,17,10,'ink')
        for x in range(5,20,4):c.line([(x,7),(x-2,16)],'steel2')
        c.box(10,9,4,4,'cyan')
    elif n=='joker':
        c.poly([(3,10),(2,2),(8,6),(12,2),(16,6),(22,2),(21,11)],'purple1')
        c.ellipse(5,7,15,15,'bone2');c.box(7,11,3,4,'ink');c.box(15,11,3,4,'ink')
        c.line([(8,17),(11,19),(15,18),(17,16)],'red2')
    elif n in ('coin','power_coin'):
        c.ellipse(3,2,19,20,'ink');c.ellipse(3,2,18,18,'gold2' if n=='coin' else 'green2')
        c.ellipse(5,4,14,14,'gold3' if n=='coin' else 'green3')
        c.ellipse(7,6,10,10,'gold1' if n=='coin' else 'green1')
        c.text('$' if '$' in FONT else 'L',10,8,'gold4' if n=='coin' else 'cyan')
        c.line([(6,5),(9,4)],'white')
    else:
        # Distinct campaign emblems are authored here, rather than a generic badge.
        if 'symbol_level' in n:
            c.paste(icon('brain',17),3,6);c.poly([(17,7),(21,2),(23,7)],'gold3');c.box(20,7,2,6,'gold3')
        elif 'specialist' in n:
            c.bevel(1,6,22,13,'gold',1)
            for xx in (3,10,17):c.paste(icon('eye',6),xx,9)
        elif 'reserve' in n:
            c.poly([(3,3),(21,3),(20,15),(12,23),(4,15)],'gold2');c.paste(scaled(icon('heart'),(14,14)),5,5)
        elif 'tip' in n:
            c.ellipse(2,2,21,21,'gold2');c.ellipse(4,4,17,17,'bone2');c.line([(12,6),(12,12),(16,14)],'ink',2)
        elif 'discount' in n:
            c.bevel(3,5,18,14,'red',2);c.text('%',8,9,'bone2',2)
        elif 'offer' in n:
            for x in (2,8,14):c.bevel(x,3+x//4,9,16,'bone',1)
        elif 'spin' in n or 'chip' in n:
            for y in (15,11,7):c.bevel(3,y,18,5,'red',1);c.box(8,y+1,4,1,'bone2')
        else:
            c.paste(icon('brain'),0,0)
    return scaled(c,(size,size)) if size!=24 else c.image
