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
art+=path('M22 207H135L140 236H18Z','#383b3c')+path('M23 208H134L138 234H20Z','#86818a')+path('M23 208H134L135 210H22Z','#b0a6af')+path('M20 234H138V238H20Z','#49464c')
for _ in range(100): art+=rect(rng.randrange(24,134),rng.randrange(211,233),1,1,rng.choice(['#77737b','#9a919b']))
for left,right in [(27,55),(60,101),(105,120),(123,139)]:
    art+=path(f'M{left} 212H{right-2}L{right} 233H{left-2}Z','#444846')
    art+=path(f'M{left+1} 213H{right-3}L{right-1} 231H{left-1}Z','#111b18')
    art+=path(f'M{left-1} 232H{right-1}V233H{left-1}Z','#b1a5a2')
save('cabinet_controls.svg',art)
save('target_progress.svg',''.join(f'<g transform="translate({160*i} 0)">'+rect(74,59,46,2,'#263c32')+rect(74,59,int(46*i/11),1,'#a0ad80')+'</g>' for i in range(12)),12)
save('target_shimmer.svg',''.join(f'<g transform="translate({160*i} 0)">'+rect(74+i*8,60,3,1,'#405747')+'</g>' for i in range(6)),6)
cases=''; surround=''
for x in [45,57,69,81]:
    cases+=rect(x,258,10,14,'#ded1ab')+rect(x,258,10,2,'#b8ad90')+rect(x,270,10,2,'#b3a584')
    surround+=rect(x-1,257,12,1,'#736e56')+rect(x-1,272,12,1,'#403f31')+rect(x-1,258,1,14,'#8c8569')+rect(x+10,258,1,14,'#3f4636')
save('wealth_cases.svg',cases)
save('wealth_crt.svg',surround)
digits=['111101101101111','010110010010111','111001111100111','111001111001111','101101111001001','111100111001111','111100111101111','111001001001001','111101111101111','111101111001111']
order=[0,9,7,8,6,5,4,3,2,1,0]
for reel,x in enumerate([45,57,69,81]):
    art=''
    for frame,digit in enumerate(order):
        art+=f'<g transform="translate({160*frame} 0)">'
        art+=''.join(rect(x+2+2*(i%3),260+2*(i//3),2,2,'#283129') for i,bit in enumerate(digits[digit]) if bit=='1')
        art+='</g>'
    save(f'wealth_digit_{reel}.svg',art,11)
