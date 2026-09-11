"""Cabinet-integrated shelf, CRT progress and warm paper drum cases."""
from pathlib import Path
import random
OUT=Path(__file__).resolve().parents[1]/'godot/assets/images/machine_polished'
def rect(x,y,w,h,c): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>'
def path(d,c): return f'<path d="{d}" fill="{c}"/>'
def save(name,art,frames=1):
    (OUT/name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{160*frames}" height="320" shape-rendering="crispEdges">{art}</svg>\n')
art=path('M23 114H133L136 117V137H21V117Z','#77757d')+rect(24,114,108,1,'#b5acb4')+rect(23,137,111,2,'#383b3b')
rng=random.Random(42)
for _ in range(95): art+=rect(rng.randrange(25,133),rng.randrange(115,137),1,1,rng.choice(['#64646b','#85818a']))
for x in [25,132]:
    for y in [118,133]: art+=rect(x,y,2,2,'#3c4140')+rect(x,y,1,1,'#b8b5ad')
for x in [46,77,108]:
    art+=f'<circle cx="{x}" cy="127" r="12" fill="#323634"/><path d="M{x-7} 117H{x+7}V118H{x-7}Z" fill="#b0aba3"/>'
# A single folded plate: its back edge tucks under the reel frame and its
# front edge projects over the enamel fascia. Wells share this perspective.
art+=path('M22 207H135L141 237H16Z','#252629')
art+=path('M23 208H134L139 235H18Z','#66636e')
art+=path('M25 209H132L137 233H20Z','#8a8591')
art+=path('M23 208H134L135 210H23Z','#b8b0bc')
art+=path('M23 210H25L21 232H19Z','#a39ba9')
art+=path('M132 210H134L139 234H136Z','#a69aa7')
art+=path('M18 234H140V237H17Z','#454149')
art+=rect(19,234,119,1,'#c0b3b8')
for x,y,w in [(26,210,7),(51,234,4),(91,232,5),(129,210,3),(23,230,2),(101,234,3)]:
    art+=rect(x,y,w,1,'#a69da7')
for left,right in [(26,55),(59,102),(104,121),(123,138)]:
    art+=path(f'M{left+1} 211H{right-2}L{right} 230L{right-1} 233H{left-2}L{left-3} 230Z','#49474c')
    art+=path(f'M{left+2} 212H{right-3}L{right-1} 230V231H{left-1}L{left-2} 230Z','#1b2523')
    art+=path(f'M{left+2} 213H{right-3}V214H{left+2}L{left} 230H{left-1}Z','#45534d')
    art+=path(f'M{left+3} 214H{right-4}L{right-2} 229H{left}Z','#101916')
    art+=path(f'M{left-2} 232H{right-1}V233H{left-2}Z','#b5a7ad')
for x,y in [(23,211),(134,211),(20,231),(137,231),(56,232)]:
    art+=rect(x,y,2,3,'#454348')+rect(x,y,1,1,'#c1b6b9')+rect(x+1,y+1,1,1,'#24292a')
# The shelf's red front lip has depth; it is part of the cabinet, not a UI bar.
art+=path('M16 237H141V249H16Z','#35070d')
art+=rect(17,238,123,9,'#810d18')+rect(18,238,121,1,'#c62a32')
art+=rect(18,239,1,7,'#a72129')+rect(19,246,120,1,'#590b14')
art+=rect(122,241,10,4,'#260b10')+rect(123,242,8,2,'#101615')
for x in [20,136]: art+=rect(x,240,2,2,'#392a2c')+rect(x,240,1,1,'#ae7674')
save('cabinet_controls.svg',art)
save('target_progress.svg',''.join(f'<g transform="translate({160*i} 0)">'+rect(74,59,46,2,'#263c32')+rect(74,59,int(46*i/11),1,'#a0ad80')+'</g>' for i in range(12)),12)
save('target_shimmer.svg',''.join(f'<g transform="translate({160*i} 0)">'+rect(74+i*8,60,3,1,'#405747')+'</g>' for i in range(6)),6)
cases=''; surround=''
for x in [45,57,69,81]:
    cases+=rect(x,258,10,14,'#ded1ab')+rect(x,258,10,2,'#b8ad90')+rect(x,270,10,2,'#b3a584')
    surround+=rect(x-1,257,12,1,'#736e56')+rect(x-1,272,12,1,'#403f31')+rect(x-1,258,1,14,'#8c8569')+rect(x+10,258,1,14,'#3f4636')
save('wealth_cases.svg',cases)
save('wealth_crt.svg',surround)
beacon=''
for frame,glass in enumerate(['#494937','#c39b4c','#f0d68d']):
    beacon+=f'<g transform="translate({160*frame} 0)">'
    beacon+=path('M68 36V28L72 24H80L84 28V36Z','#252c28')
    beacon+=path('M70 35V28L73 25H79L82 28V35Z',glass)
    beacon+=rect(73,26,6,1,'#b5b38a' if frame==0 else '#fff0be')
    beacon+=rect(71,29,1,5,'#71735b' if frame==0 else '#fff0be')
    beacon+=rect(79,29,2,6,'#373e30' if frame==0 else '#ad7c37')
    beacon+=rect(74,30,3,4,'#5a5840' if frame==0 else '#ffe3a2')
    beacon+=path('M67 35H85V39H67Z','#303632')+rect(68,35,16,1,'#9d9984')+rect(68,37,16,1,'#66695c')
    beacon+='</g>'
save('jackpot_beacon.svg',beacon,3)
digits=['111101101101111','010110010010111','111001111100111','111001111001111','101101111001001','111100111001111','111100111101111','111001001001001','111101111101111','111101111001111']
order=[0,9,7,8,6,5,4,3,2,1,0]
for reel,x in enumerate([45,57,69,81]):
    art=''
    for frame,digit in enumerate(order):
        art+=f'<g transform="translate({160*frame} 0)">'
        art+=''.join(rect(x+2+2*(i%3),260+2*(i//3),2,2,'#283129') for i,bit in enumerate(digits[digit]) if bit=='1')
        art+='</g>'
    save(f'wealth_digit_{reel}.svg',art,11)
