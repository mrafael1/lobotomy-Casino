"""Multiplier heat art, independent of progression, rewards and seeded game RNG."""
from .pixels import Pixel


def layer(p,name):
    if hasattr(p,'layer'):p.layer(name)


def ramps(tier):
    assert tier in (1,2,3)
    if tier==1:
        return (('ruby0','ruby1','ruby2','ruby3','ruby4'),
                ('gold0','gold1','gold2','gold3','gold4'),
                ('jade0','jade1','jade2','jade3','jade4'))
    if tier==2:
        return (('ruby0','heat0','heat2','heat3','heat4'),
                ('gold0','hot_metal0','gold2','hot_metal2','heat4'),
                ('hot_glass0','hot_glass1','hot_glass2','heat3','heat5'))
    return (('heat0','heat1','heat3','heat4','heat_white'),
            ('hot_metal0','hot_metal1','hot_metal2','heat4','heat_white'),
            ('hot_glass0','hot_glass1','heat1','heat4','heat_white'))


def exhaust(p,x,y,side,frame,large=False):
    """A narrow, vent-fed tongue with an ascending core, authored on the grid."""
    drift=(0,2,1,-1,-2,1)[frame%6]
    height=59 if large else 29
    p.contour((x,y),[
        ((x-side*6,y-9),(x+side*9,y-20),(x+side*(7+drift),y-height)),
        ((x+side*16,y-height+10),(x+side*4,y-14),(x+side*12,y-4)),
        ((x+side*7,y+2),(x+side*4,y+2),(x,y))], 'heat1')
    p.contour((x+side*3,y-2),[
        ((x-side*2,y-10),(x+side*10,y-21),(x+side*(8+drift),y-height+9)),
        ((x+side*12,y-18),(x+side*6,y-12),(x+side*9,y-5)),
        ((x+side*6,y),(x+side*4,y),(x+side*3,y-2))], 'heat3')
    p.contour((x+side*4,y-2),[
        ((x+side*2,y-9),(x+side*8,y-14),(x+side*8,y-21)),
        ((x+side*11,y-11),(x+side*6,y-9),(x+side*7,y-3))], 'heat5')


def backdrop(p,tier,frame):
    if tier==1:return
    layer(p,'floor_reflection')
    p.oval(1,571,318,63,'heat_floor0')
    p.oval(13,582,294,43,'heat_floor1')
    p.oval(43,592,234,26,'heat1' if tier==3 else 'hot_metal0')
    # Emission belongs to powered upper vents and the cabinet edges. It is
    # behind the cabinet, away from every live field and header control.
    layer(p,'shoulder_glow')
    for x,side in ((36,-1),(284,1)):
        p.contour((x,190),[((x+side*12,147),(x+side*15,110),(x+side*2,82))],
                  'heat_floor1',stroke=6 if tier==3 else 3)
        if tier==3:
            layer(p,'exhaust')
            exhaust(p,x,105,side,frame,True)
            layer(p,'shoulder_glow')
        else:
            p.contour((x+side*3,103),[((x+side*8,87),(x+side*3,75),(x+side*8,60))],
                      'heat_air',stroke=1)


def hardware(p,tier,frame,warning=False):
    if tier==1 or warning:return
    layer(p,'incandescence')
    core='heat5' if tier==2 else 'heat_white'
    rim='hot_metal2' if tier==2 else 'heat4'
    # Continuous incandescence lives in metal lips, not a flat screen tint.
    for xx in (35,284):
        p.line([(xx,214),(xx,334)],rim,2)
        p.fine_line([(xx*2+1,434),(xx*2+1,657)],core)
    for yy in (205,341):
        p.line([(43,yy),(277,yy)],rim,2)
        p.fine_line([(90,yy*2-1),(548,yy*2-1)],core)
    # A fitted pair of exhaust banks outside the glass explain where the
    # sustained output escapes. No cracks, missing parts or end-run decay.
    layer(p,'vent_hardware')
    for xx,side in ((29,-1),(286,1)):
        p.box(xx,350,6,76,'hot_metal0')
        for i in range(8):
            yy=353+i*9
            p.line([(xx,yy),(xx+5,yy)],'heat2',2)
            p.fine_line([(xx*2+1,yy*2),(xx*2+8,yy*2)],core if tier==3 else 'heat3')
        if tier==3 and not warning:
            root=xx+(0 if side<0 else 5)
            p.poly([(root,406),(root+side*7,401),(root+side*7,394),(root,399)],'hot_metal0')
            p.line([(root,400),(root+side*6,396)],'heat5')
            layer(p,'exhaust')
            exhaust(p,xx+(0 if side<0 else 5),402,side,frame)
            layer(p,'vent_hardware')
    # Contact highlights from the hot body seat the controls in the same
    # machine. All cap faces/glyphs remain legible and static during a loop.
    layer(p,'control_incandescence')
    if tier==3:
        # Moving hot air above powered shoulders leaves the header and text clear.
        for x,side in ((40,-1),(280,1)):
            drift=(frame%3)-1
            p.contour((x+side*6,94),[((x+side*(12+drift),75),(x+side*3,64),(x+side*(9-drift),45))],
                      'heat_air',stroke=2)
        p.contour((35,502),[((91,492),(233,492),(284,502))],'heat_white',stroke=2)
        for x in (76,160,244):p.arc((x-25,440,x+25,477),5,175,'heat4')
    if warning:return
    # Discrete reel-lip sparks and a rising ember stream. Formulae describe
    # authored frame positions; they do not read any random number generator.
    layer(p,'sparks')
    count=3 if tier==2 else 13
    for i in range(count):
        side=-1 if i%2==0 else 1
        xx=(35 if side<0 else 285)+side*(5+(i*3+frame)%9)
        yy=332-((frame*13+i*23)%119)
        p.line([(xx,yy),(xx+side*2,yy-3)],'heat4' if i%3 else core)
        if tier==3 and i%3==0:p.fine_line([(xx*2+side*3,yy*2-6),(xx*2+side*5,yy*2-9)],'heat2')
    if tier==3:
        layer(p,'embers')
        for i in range(5):
            xx=38+i*61+(frame%3-1)*3
            yy=90-((i*11+frame*7)%48)
            p.box(xx,yy,1,2,'heat3' if i%2 else 'heat5')
