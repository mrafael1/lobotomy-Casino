"""Alternative machine: direct 320x640 raster, authored two-pixel curve clusters.

Shares the cabinet construction, not its exported raster. No image input,
downsampling, pixelation filter, random texture or runtime dependencies.
"""
from math import sin, cos, radians
from .pixels import Pixel, rgba
from .console import machine as cabinet


class ClusterPixel(Pixel):
    def __init__(self,w=320,h=640,bg=None):
        super().__init__(w,h,bg,density=1)

    @staticmethod
    def step(value):
        return 2*round(value/2)

    def fine_line(self,pts,c,width=1):
        # Fine-line recipes use the original 640-wide native coordinate space.
        # Re-author their engraving as single pixels on this variant's grid.
        self.d.line([(round(x/2),round(y/2)) for x,y in pts],fill=rgba(c),width=max(1,round(width/2)))

    def illustrate_reel(self,kind):
        if kind!='eye':return False
        # Authored lid runs and iris clusters replace subpixel curve engraving.
        self.poly([(3,30),(9,24),(17,20),(25,18),(35,18),(43,22),(49,26),
                   (55,32),(49,36),(41,40),(33,44),(23,44),(15,40),(7,36)],'ruby0')
        self.poly([(7,30),(15,24),(23,22),(35,22),(43,26),(51,32),(43,36),
                   (35,40),(23,40),(15,36)],'cream2')
        self.poly([(25,17),(33,17),(38,23),(38,37),(33,44),(25,44),(20,37),(20,24)],'jade0')
        self.poly([(26,19),(32,19),(35,25),(35,36),(32,41),(26,41),(23,36),(23,25)],'jade2')
        self.box(27,20,5,21,'ink');self.box(32,23,3,4,'cream3')
        self.line([(24,23),(24,28)],'jade4');self.line([(24,34),(25,38)],'jade3')
        self.line([(34,32),(34,36)],'jade4')
        self.line([(8,36),(16,41),(24,44),(33,44),(41,41)],'ruby3')
        for x,y in ((9,24),(17,20),(43,22),(49,26)):
            self.line([(x,y),(x-2,y-4)],'ruby0')
        return True

    def contour(self,start,segments,c,stroke=0):
        current=start;points=[tuple(self.step(v) for v in start)]
        for a,b,end in segments:
            sx,sy=current;ax,ay=a;bx,by=b;ex,ey=end
            for i in range(1,33):
                t=i/32;u=1-t
                points.append((self.step(u**3*sx+3*u*u*t*ax+3*u*t*t*bx+t**3*ex),
                               self.step(u**3*sy+3*u*u*t*ay+3*u*t*t*by+t**3*ey)))
            current=end
        if stroke:self.d.line(points,fill=rgba(c),width=max(1,round(stroke/2)))
        else:self.d.polygon(points,fill=rgba(c))

    def oval(self,x,y,w,h,c):
        # Small lamps retain crisp one-pixel cores; larger glass and enamel
        # forms use stepped silhouettes with broad, uninterrupted clusters.
        if min(w,h)<12:
            super().oval(x,y,w,h,c);return
        pts=[(self.step(x+(w-1)/2+(w-1)/2*cos(radians(a))),
              self.step(y+(h-1)/2+(h-1)/2*sin(radians(a)))) for a in range(0,360,10)]
        self.d.polygon(pts,fill=rgba(c))


def machine(tier=1,frame=0,warning=False,payout=0):
    return cabinet(tier,frame,warning,payout,canvas=ClusterPixel)
