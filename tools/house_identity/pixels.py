"""House Remembers: integer-only raster construction, no source images or filters."""
from PIL import Image, ImageDraw
from pathlib import Path
import io
import os
import tempfile
import time

P = {
    'void':'090c0e', 'ink':'101719', 'slate':'202b2c', 'smoke':'384344',
    'wood0':'171315', 'wood1':'2b1e20', 'wood2':'432c27', 'wood3':'63452f', 'wood4':'886342',
    'wine0':'1d131a', 'wine1':'351d25', 'wine2':'542833', 'wine3':'803e49', 'wine4':'b06459',
    'felt0':'0d211f', 'felt1':'14332e', 'felt2':'23483d', 'felt3':'3b614f', 'felt4':'68836b',
    'brass0':'2b2722', 'brass1':'514431', 'brass2':'81683e', 'brass3':'b69764', 'brass4':'ddbf88',
    'paper0':'655e51', 'paper1':'938974', 'paper2':'b7ac91', 'paper3':'ded2b2', 'ivory':'f4e3bf',
    'skin0':'302328', 'skin1':'583e39', 'skin2':'8d604e', 'skin3':'b58b6e', 'skin4':'c9aa86',
    'cold0':'263a3d', 'cold1':'496265', 'cold2':'78928d', 'cold3':'b2c1ab',
    'mint0':'234d46', 'mint1':'4a9b7b', 'mint2':'8edbb0', 'mint3':'d8f2c0',
    'red':'dc705b', 'amber':'e5a95e', 'blue':'687f9b', 'lilac':'a08a9e',
    'wood_edge':'755638', 'wood_warm':'51382d', 'wood_glaze':'362823',
    'brass_dull':'655439', 'brass_polish':'c3a674', 'brass_cool':'686c5e',
    'glass0':'101c1d', 'glass1':'1b2c2d', 'glass2':'2b3e3b', 'glass3':'3e5148',
    'enamel0':'251a20', 'enamel1':'39212b', 'enamel2':'492933', 'enamel3':'65343c',
    'membrane0':'292125', 'membrane1':'473039', 'membrane2':'725047',
    'cloth_mid':'b5aa8e', 'skin_mid':'a2765d', 'skin_light':'c09d79',
    # The healthy machine is the house's lure. This dedicated material ramp
    # leaves the deliberately subdued tables, folios and casino rooms intact.
    'ruby0':'351622', 'ruby1':'6b1f37', 'ruby2':'a8324b', 'ruby3':'d75262', 'ruby4':'f58b80',
    'gold0':'493025', 'gold1':'946039', 'gold2':'c48b4a', 'gold3':'ebbb6d', 'gold4':'ffe2a1',
    'jade0':'103b3e', 'jade1':'176465', 'jade2':'29998d', 'jade3':'65d5b3', 'jade4':'b9f4ce',
    'cream0':'a28a67', 'cream1':'d1ba8e', 'cream2':'eddbaf', 'cream3':'fff0ce',
    'bulb0':'88613a', 'bulb1':'e6a55c', 'bulb2':'ffd89a', 'bulb3':'fff5cf',
    'heat0':'55232a', 'heat1':'9d3431', 'heat2':'db5738', 'heat3':'ff9450',
    'heat4':'ffd18a', 'heat5':'fff4cd', 'heat_white':'ffffe7',
    'hot_metal0':'6e3827', 'hot_metal1':'ba6033', 'hot_metal2':'f3974d',
    'hot_metal3':'ffd28c', 'hot_glass0':'3e2427', 'hot_glass1':'713c31',
    'hot_glass2':'b96c41', 'heat_air':'733e31', 'heat_floor0':'352022', 'heat_floor1':'623329',
}

# Explicit 5x7 alphabet: titles, live-label mockups and card text share a grid.
ROWS = {
'A':['01110','10001','10001','11111','10001','10001','10001'],
'B':['11110','10001','10001','11110','10001','10001','11110'],
'C':['01111','10000','10000','10000','10000','10000','01111'],
'D':['11110','10001','10001','10001','10001','10001','11110'],
'E':['11111','10000','10000','11110','10000','10000','11111'],
'F':['11111','10000','10000','11110','10000','10000','10000'],
'G':['01111','10000','10000','10111','10001','10001','01111'],
'H':['10001','10001','10001','11111','10001','10001','10001'],
'I':['111','010','010','010','010','010','111'],
'J':['00111','00010','00010','00010','10010','10010','01100'],
'K':['10001','10010','10100','11000','10100','10010','10001'],
'L':['10000','10000','10000','10000','10000','10000','11111'],
'M':['10001','11011','10101','10101','10001','10001','10001'],
'N':['10001','11001','11001','10101','10011','10001','10001'],
'O':['01110','10001','10001','10001','10001','10001','01110'],
'P':['11110','10001','10001','11110','10000','10000','10000'],
'Q':['01110','10001','10001','10001','10101','10010','01101'],
'R':['11110','10001','10001','11110','10100','10010','10001'],
'S':['01111','10000','10000','01110','00001','00001','11110'],
'T':['11111','00100','00100','00100','00100','00100','00100'],
'U':['10001','10001','10001','10001','10001','10001','01110'],
'V':['10001','10001','10001','10001','10001','01010','00100'],
'W':['10001','10001','10001','10101','10101','10101','01010'],
'X':['10001','10001','01010','00100','01010','10001','10001'],
'Y':['10001','10001','01010','00100','00100','00100','00100'],
'Z':['11111','00001','00010','00100','01000','10000','11111'],
'0':['01110','10001','10011','10101','11001','10001','01110'],
'1':['010','110','010','010','010','010','111'],
'2':['01110','10001','00001','00010','00100','01000','11111'],
'3':['11110','00001','00001','01110','00001','00001','11110'],
'4':['00010','00110','01010','10010','11111','00010','00010'],
'5':['11111','10000','10000','11110','00001','00001','11110'],
'6':['01110','10000','10000','11110','10001','10001','01110'],
'7':['11111','00001','00010','00100','01000','01000','01000'],
'8':['01110','10001','10001','01110','10001','10001','01110'],
'9':['01110','10001','10001','01111','00001','00001','01110'],
' ':['000']*7, '.':['0']*6+['1'], ',':['00']*5+['01','10'],
':':['0','1','0','0','1','0','0'], '/':['00001','00001','00010','00100','01000','10000','10000'],
'-':['000','000','000','111','000','000','000'], '+':['00000','00100','00100','11111','00100','00100','00000'],
'?':['01110','10001','00001','00010','00100','00000','00100'],
'!':['1','1','1','1','1','0','1'], "'":['1','1','0','0','0','0','0'],
'%':['11001','11010','00100','00100','01000','10110','00110'],
'<':['001','010','100','100','100','010','001'], '>':['100','010','001','001','001','010','100'],
'=':['000','111','000','111','000','000','000'],
}


def rgba(c):
    if c is None:
        return (0, 0, 0, 0)
    if isinstance(c, tuple):
        return c
    v = P.get(c, c).lstrip('#')
    return tuple(int(v[i:i+2], 16) for i in (0, 2, 4)) + (255,)


def text_width(s, scale=1, tracking=1):
    return max(0, sum((len(ROWS.get(ch, ROWS['?'])[0])+tracking)*scale for ch in s.upper())-tracking*scale)


def write_image(im,path):
    """Atomic image replacement so the open Godot editor never reads half a PNG."""
    buf=io.BytesIO();im.save(buf,format='PNG',optimize=True)
    write_bytes_atomic(path,buf.getvalue())


def write_bytes_atomic(path,payload):
    """Keep image/GIF readers on complete old or new bytes during regeneration."""
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    if path.exists() and path.read_bytes()==payload:return
    with tempfile.NamedTemporaryFile(dir=path.parent,suffix='.tmp',delete=False) as f:
        f.write(payload);temp=Path(f.name)
    try:
        for attempt in range(10):
            try:
                os.replace(temp,path);break
            except OSError:
                if attempt==9:raise
                time.sleep(.1)
    finally:
        if temp.exists():temp.unlink()


class Pixel:
    def __init__(self, w=320, h=640, bg=None, density=2):
        # Recipe units stay stable; primitive rasterisation happens directly on
        # the finer source grid. No old raster is enlarged to make new masters.
        self.w,self.h,self.density=w,h,density
        self.im = Image.new('RGBA', (w*density, h*density), rgba(bg))
        self.d = ImageDraw.Draw(self.im)

    def box(self, x, y, w, h, c):
        assert all(isinstance(v, int) for v in (x, y, w, h))
        if w > 0 and h > 0:
            d=self.density
            self.d.rectangle((x*d, y*d, (x+w)*d-1, (y+h)*d-1), fill=rgba(c))

    def poly(self, pts, c):
        assert all(isinstance(v, int) for p in pts for v in p)
        self.d.polygon([(x*self.density,y*self.density) for x,y in pts], fill=rgba(c))

    def line(self, pts, c, width=1):
        assert all(isinstance(v, int) for p in pts for v in p)
        self.d.line([(x*self.density,y*self.density) for x,y in pts], fill=rgba(c), width=width*self.density)

    def oval(self, x, y, w, h, c):
        d=self.density
        self.d.ellipse((x*d,y*d,(x+w)*d-1,(y+h)*d-1), fill=rgba(c))

    def arc(self, box, start, end, c, width=1):
        d=self.density
        self.d.arc(tuple(v*d for v in box), start, end, fill=rgba(c), width=width*d)

    def paste(self, p, x, y):
        self.im.alpha_composite(p.im if isinstance(p, Pixel) else p, (x*self.density,y*self.density))

    def crop(self,box):
        return self.im.crop(tuple(v*self.density for v in box))

    def fine_line(self,pts,c,width=1):
        """Native source-pixel strokes for engraving, seams and small highlights."""
        assert all(isinstance(v,int) for pt in pts for v in pt)
        self.d.line(pts,fill=rgba(c),width=width)

    def contour(self,start,segments,c,stroke=0):
        """Cubic contours sampled onto integer source pixels, without smoothing."""
        d=self.density
        current=(start[0]*d,start[1]*d);points=[current]
        for a,b,end in segments:
            ax,ay=a[0]*d,a[1]*d;bx,by=b[0]*d,b[1]*d;ex,ey=end[0]*d,end[1]*d
            sx,sy=current
            for i in range(1,49):
                t=i/48;u=1-t
                points.append((round(u*u*u*sx+3*u*u*t*ax+3*u*t*t*bx+t*t*t*ex),
                               round(u*u*u*sy+3*u*u*t*ay+3*u*t*t*by+t*t*t*ey)))
            current=(ex,ey)
        if stroke:self.d.line(points,fill=rgba(c),width=stroke)
        else:self.d.polygon(points,fill=rgba(c))

    def text(self, s, x, y, c='paper3', scale=1, align='left', tracking=1):
        if align == 'center':
            x -= text_width(s, scale, tracking)//2
        elif align == 'right':
            x -= text_width(s, scale, tracking)
        for ch in s.upper():
            rows = ROWS.get(ch, ROWS['?'])
            for j,row in enumerate(rows):
                for i,bit in enumerate(row):
                    if bit == '1':
                        self.box(x+i*scale,y+j*scale,scale,scale,c)
            x += (len(rows[0])+tracking)*scale

    def wrap(self, s, x, y, width, c='paper3', gap=11):
        line=''
        for word in s.split():
            if text_width((line+' '+word).strip()) > width and line:
                self.text(line,x,y,c); y+=gap; line=word
            else:
                line=(line+' '+word).strip()
        if line:
            self.text(line,x,y,c)
        return y+gap

    def metal(self, x, y, w, h, ramp='brass', cut=4):
        names = [ramp+str(i) for i in range(4)]
        if ramp=='paper':
            names=['paper0','paper1','paper2','paper3']
        a,b,c,d=names
        self.poly([(x+cut,y),(x+w-cut-1,y),(x+w-1,y+cut),(x+w-1,y+h-cut-1),
                   (x+w-cut-1,y+h-1),(x+cut,y+h-1),(x,y+h-cut-1),(x,y+cut)],a)
        self.poly([(x+cut,y+1),(x+w-cut-2,y+1),(x+w-2,y+cut),(x+w-2,y+h-cut-2),
                   (x+w-cut-2,y+h-2),(x+cut,y+h-2),(x+1,y+h-cut-2),(x+1,y+cut)],c)
        self.line([(x+1,y+h-cut-2),(x+1,y+cut),(x+cut,y+1),(x+w-cut-2,y+1)],d)
        self.line([(x+cut,y+h-2),(x+w-cut-2,y+h-2),(x+w-2,y+h-cut-2)],b)

    def screw(self,x,y):
        self.oval(x-2,y-2,5,5,'brass0');self.line([(x-1,y-1),(x+1,y-1)],'brass3')
        self.line([(x-1,y+1),(x+1,y-1)],'ink')

    def save(self,path):
        write_image(self.im,path)


def chip(p,x,y,r=10,c='wine2',height=0):
    for k in range(height,-1,-3):
        p.oval(x-r,y-r//2-k,2*r+1,r+1,'ink')
        p.oval(x-r,y-r//2-k-1,2*r+1,r,c)
        p.arc((x-r+2,y-r//2-k,x+r-2,y+r//2-k),0,180,'paper1')
        for dx in (-r+2,0,r-3):p.box(x+dx,y+1-k,2,2,'paper2')
    p.oval(x-r+4,y-r//2-height+1,2*r-7,max(2,r-4),'brass0')
    p.line([(x-2,y-height),(x+2,y-height)],'brass3')


def button(p,x,y,w,label,active=True):
    p.metal(x,y,w,33,'brass',5)
    p.box(x+4,y+4,w-8,24,'felt0' if active else 'wine0')
    p.line([(x+6,y+5),(x+w-7,y+5)],'felt3' if active else 'wine2')
    scale=2 if text_width(label,2)<=w-12 else 1
    p.text(label,x+w//2,y+(9 if scale==2 else 12),'paper3' if active else 'paper1',scale,align='center')


def eye(p,x,y,w=29,late=False):
    p.poly([(x,y+5),(x+7,y),(x+w-8,y),(x+w-1,y+5),(x+w-8,y+10),(x+7,y+10)],'skin0')
    p.poly([(x+2,y+5),(x+8,y+2),(x+w-9,y+2),(x+w-3,y+5),(x+w-9,y+8),(x+8,y+8)],'paper2')
    p.oval(x+w//2-4,y+1,9,9,'mint1' if late else 'cold1')
    p.box(x+w//2-1,y+2,3,7,'ink');p.box(x+w//2+1,y+2,1,2,'ivory')


def item_badge(p,kind,x,y):
    """Five distinct native 16px silhouettes; the duration owns its own colour."""
    if kind=='T':
        p.poly([(x+2,y+11),(x+4,y+8),(x+14,y+11),(x+13,y+14)],'paper2')
        p.poly([(x+2,y+11),(x+4,y+8),(x+7,y+9),(x+5,y+12)],'wood3')
        p.line([(x+13,y+10),(x+14,y+7),(x+12,y+4),(x+13,y+1)],'cold2')
        p.box(x+13,y+11,2,2,'red')
    elif kind=='P':
        p.poly([(x+6,y+1),(x+10,y+1),(x+10,y+6),(x+14,y+11),(x+13,y+15),(x+3,y+15),(x+2,y+11),(x+6,y+6)],'cold2')
        p.poly([(x+5,y+9),(x+11,y+9),(x+12,y+13),(x+4,y+13)],'lilac')
        p.line([(x+4,y+10),(x+4,y+12)],'paper3');p.box(x+5,y,6,2,'brass2')
    elif kind=='E':
        p.metal(x+3,y+1,10,14,'brass',2);p.box(x+5,y+4,6,9,'wine2')
        p.line([(x+9,y+4),(x+6,y+8),(x+10,y+8),(x+7,y+12)],'paper3')
        p.box(x+6,y+1,4,1,'cold3')
    elif kind=='S':
        p.poly([(x+6,y),(x+9,y),(x+9,y+5),(x+11,y+7),(x+11,y+14),(x+9,y+15),(x+5,y+15),(x+4,y+14),(x+4,y+7),(x+6,y+5)],'cold1')
        p.box(x+6,y+8,4,6,'mint1');p.line([(x+5,y+7),(x+5,y+12)],'paper3')
        p.box(x+6,y+1,3,1,'paper2')
    elif kind=='C':
        p.poly([(x+1,y+2),(x+15,y+2),(x+8,y+9)],'cold2')
        p.poly([(x+3,y+3),(x+13,y+3),(x+8,y+7)],'wine3')
        p.line([(x+8,y+8),(x+8,y+14)],'paper2');p.line([(x+4,y+15),(x+12,y+15)],'brass2')
        p.line([(x+10,y+4),(x+13,y)],'paper1');p.box(x+1,y+1,3,3,'brass3')
    else:raise ValueError(kind)


def symbol(p,kind,x,y):
    """Each symbol drawn on a 38x44 source-pixel field, never scaled from an icon."""
    if kind=='eye':
        p.oval(x+2,y+9,34,26,'skin0');p.oval(x+3,y+7,31,25,'paper0')
        p.poly([(x+3,y+19),(x+12,y+12),(x+24,y+12),(x+34,y+19),(x+25,y+26),(x+12,y+26)],'paper3')
        p.oval(x+12,y+9,15,23,'felt2');p.oval(x+16,y+11,7,19,'ink');p.box(x+18,y+12,3,4,'mint2')
        p.line([(x+4,y+15),(x+11,y+10),(x+26,y+10),(x+34,y+16)],'skin1')
    elif kind=='brain':
        p.oval(x+2,y+6,34,29,'skin0');p.oval(x+2,y+3,31,27,'wine3')
        for xx,yy in [(7,7),(17,5),(24,9),(6,17),(18,15),(24,21)]:
            p.arc((x+xx-3,y+yy-2,x+xx+6,y+yy+7),160,460,'skin4',2)
        p.line([(x+17,y+4),(x+15,y+12),(x+18,y+19),(x+16,y+27)],'wine1')
        p.poly([(x+19,y+28),(x+26,y+27),(x+27,y+35),(x+24,y+38),(x+20,y+35)],'skin2')
    elif kind=='pill':
        p.poly([(x+6,y+10),(x+13,y+4),(x+20,y+4),(x+31,y+18),(x+31,y+26),(x+25,y+32),(x+18,y+32),(x+6,y+18)],'ink')
        p.poly([(x+7,y+11),(x+13,y+6),(x+19,y+6),(x+25,y+14),(x+15,y+24),(x+7,y+17)],'paper3')
        p.poly([(x+15,y+24),(x+25,y+14),(x+30,y+20),(x+30,y+25),(x+24,y+31),(x+19,y+31)],'wine3')
        p.line([(x+10,y+12),(x+14,y+9),(x+18,y+9)],'ivory',2)
    elif kind=='heart':
        p.poly([(x+19,y+10),(x+12,y+5),(x+6,y+7),(x+3,y+14),(x+5,y+23),(x+19,y+37),(x+33,y+23),(x+35,y+14),(x+31,y+7),(x+25,y+5)],'wine2')
        p.poly([(x+18,y+13),(x+11,y+9),(x+7,y+12),(x+7,y+19),(x+18,y+30)],'wine4')
        p.line([(x+12,y+3),(x+14,y+9),(x+22,y+8),(x+24,y+1)],'skin3',3)
        p.line([(x+7,y+21),(x+13,y+21),(x+16,y+16),(x+21,y+27),(x+24,y+20),(x+31,y+20)],'paper3')
    elif kind in ('vial','syringe'):
        if kind=='vial':
            p.metal(x+12,y+2,15,8,'brass',1);p.poly([(x+13,y+10),(x+25,y+10),(x+25,y+16),(x+29,y+20),(x+29,y+35),(x+25,y+39),(x+11,y+39),(x+8,y+35),(x+8,y+20),(x+13,y+16)],'cold1')
            p.box(x+10,y+24,17,11,'felt3');p.line([(x+11,y+21),(x+11,y+32)],'cold3',2);p.box(x+15,y+25,8,8,'paper2')
        else:
            p.line([(x+18,y+1),(x+18,y+9)],'paper3');p.box(x+11,y+9,15,3,'cold2');p.box(x+14,y+12,9,20,'cold1');p.box(x+16,y+13,3,17,'paper2')
            for yy in range(17,30,4):p.box(x+19,y+yy,3,1,'ink')
            p.box(x+10,y+32,17,3,'brass2');p.box(x+17,y+35,3,6,'cold3')
    elif kind=='book':
        p.poly([(x+3,y+7),(x+17,y+4),(x+20,y+8),(x+34,y+5),(x+34,y+34),(x+21,y+38),(x+17,y+35),(x+3,y+38)],'wood2')
        p.poly([(x+5,y+8),(x+16,y+6),(x+18,y+10),(x+18,y+33),(x+5,y+35)],'paper2')
        p.poly([(x+20,y+10),(x+32,y+7),(x+32,y+32),(x+20,y+35)],'paper1')
        for yy in range(13,31,4):p.line([(x+7,y+yy),(x+15,y+yy-1)],'paper0')
        p.line([(x+25,y+10),(x+25,y+36)],'wine3',2)
    else:
        p.line([(x+2,y+22),(x+11,y+22),(x+15,y+16),(x+19,y+30),(x+23,y+22),(x+36,y+22)],'mint2',2)
