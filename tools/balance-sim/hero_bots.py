"""Throwaway balance bots for the starter stage: the numbers in design/gdd/hero-system.md.

shortcut: scripted bots in plain Python, not game code. Replace with the Hero stories' real bots.
Run: python3 tools/balance-sim/hero_bots.py          (table and clamp self-check)
     python3 tools/balance-sim/hero_bots.py --left   (the same table, left hand)
     python3 tools/balance-sim/hero_bots.py --sweeps (radius, reach, thumb and skill sweeps)
     python3 tools/balance-sim/hero_bots.py --orders (fill first against upgrading in pairs, every placement)
     python3 tools/balance-sim/hero_bots.py --calls  (mid-skill: never calling, calling when the burst is Ready, always calling, each with and without the bonus)
"""
# Throwaway balance sim of the starter stage. Tick order per Combat Rule 11. Not game code.
import itertools
import math,sys
DT=1/60; BR=70; BLOG=[]; THUMB=None; START=(350.0,800.0)
PATH=[(-40,210),(430,210),(430,400),(110,400),(110,570),(270,570),(270,980)]
SLOTS=[(270,305),(190,485),(350,485),(170,700),(370,700)]
cum=[0]
for a,b in zip(PATH,PATH[1:]): cum.append(cum[-1]+math.dist(a,b))
LEN=cum[-1]
def pos(d):
    if d>=LEN: return PATH[-1]
    for k in range(len(PATH)-1):
        if d<cum[k+1]:
            t=(d-cum[k])/(cum[k+1]-cum[k]); a,b=PATH[k],PATH[k+1]
            return (a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1]))
EN={'n':(125,60,4,1),'f':(60,110,3,1),'h':(750,38,16,3)}
WAVES=[([('n',8,1.5,0)],15),([('n',6,.6,0),('n',6,.6,12)],15),([('n',12,.7,0),('f',8,.5,0)],15),
([('h',2,3,0),('n',8,.6,8)],15),([('f',8,.4,0),('h',2,4,0),('n',10,.5,4),('f',8,.4,16)],15),
([('h',4,3,0),('n',12,.5,10),('f',10,.4,20),('n',8,.5,24)],15)]
def tk(s): return int(math.floor(s/DT+.5))

# Read the live values from assets/data so the sim matches the game (first playable,
# 2026-11-05). The literals above are the pre-playtest values, kept as a fallback.
import json,os
_DATA=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','assets','data')
def _load(name): return json.load(open(os.path.join(_DATA,name)))
GOLD=120
WAVE_HP=[1.0]*6
try:
    _short={'normal':'n','fast':'f','heavy':'h'}
    EN={_short[e['id']]:(e['max_hp'],e['move_speed'],e['bounty'],e['lives_cost']) for e in _load('enemies.json')['enemy']}
    WAVES=[([(_short[g['enemy_id']],g['count'],g['spawn_interval'],g['start_delay']) for g in w['groups']],w['intermission_duration']) for w in _load('waves.json')['wave']]
    GOLD=_load('stages.json')['stage'][0]['starting_gold']
    WAVE_HP=[float(w.get('hp_scale',1.0)) for w in _load('waves.json')['wave']]
    LIVE_DATA=True
except (OSError,KeyError,ValueError):
    LIVE_DATA=False

# pin_exclusion: (a, b, radius, hand). Only the active hand's burst line counts, and Start/Call ("both").
SHAPES=[((456,816),(456,888),60.0,'right'),((84,816),(84,888),60.0,'left'),((186,800),(186,800),60.0,'both')]
HAND='right'
def zones(): return [(a,b,r) for a,b,r,h in SHAPES if h in ('both',HAND)]
RECT=(48.0,174.0,492.0,888.0)
def _segd(p,a,b):
    ax,ay=a;bx,by=b;dx,dy=bx-ax,by-ay;L=dx*dx+dy*dy
    t=0 if L==0 else max(0,min(1,((p[0]-ax)*dx+(p[1]-ay)*dy)/L))
    return (ax+t*dx,ay+t*dy)
def valid_pin(p):
    if not(RECT[0]<=p[0]<=RECT[2] and RECT[1]<=p[1]<=RECT[3]): return False
    return all((p[0]-q[0])**2+(p[1]-q[1])**2>=r*r for a,b,r in zones() for q in [_segd(p,a,b)])
def clamp_pin(f,eps=.01,hold=START):
    """Hero GDD clamp_pin: nearest valid candidate, ties to smaller y then smaller x."""
    x0,y0,x1,y1=RECT
    c=[(min(x1,max(x0,f[0])),min(y1,max(y0,f[1]))),(x0,y0),(x1,y0),(x0,y1),(x1,y1)]
    circles=[];lines=[]
    for a,b,r in zones():
        R_=r+eps
        for e in {a,b}:
            circles.append((e,R_))
            d=math.dist(f,e)
            u=((f[0]-e[0])/d,(f[1]-e[1])/d) if d>0 else (0.0,-1.0)
            c.append((e[0]+u[0]*R_,e[1]+u[1]*R_))
        if a!=b:
            L_=math.dist(a,b); tx,ty=(b[0]-a[0])/L_,(b[1]-a[1])/L_; nx,ny=-ty,tx
            for sgn in (1,-1):
                p=(a[0]+sgn*nx*R_,a[1]+sgn*ny*R_); lines.append((p,(tx,ty)))
                k=(f[0]-p[0])*tx+(f[1]-p[1])*ty; c.append((p[0]+k*tx,p[1]+k*ty))
    for x in (x0,x1): lines.append(((x,y0),(0.0,1.0)))
    for y in (y0,y1): lines.append(((x0,y),(1.0,0.0)))
    for (e,R_) in circles:
        for p,t in lines:
            fx,fy=p[0]-e[0],p[1]-e[1]; bq=fx*t[0]+fy*t[1]; disc=bq*bq-(fx*fx+fy*fy-R_*R_)
            if disc>=0:
                for sg in (1,-1):
                    k=-bq+sg*math.sqrt(disc); q=[p[0]+k*t[0],p[1]+k*t[1]]
                    if t==(0.0,1.0): q[0]=p[0]
                    if t==(1.0,0.0): q[1]=p[1]
                    c.append(tuple(q))
    for i_,(e1,r1) in enumerate(circles):
        for e2,r2 in circles[i_+1:]:
            d=math.dist(e1,e2)
            if d==0 or d>r1+r2 or d<abs(r1-r2): continue
            a_=(d*d+r1*r1-r2*r2)/(2*d); h2=r1*r1-a_*a_
            if h2<0: continue
            h=math.sqrt(h2); ux,uy=(e2[0]-e1[0])/d,(e2[1]-e1[1])/d
            for sg in (1,-1): c.append((e1[0]+a_*ux-sg*h*uy,e1[1]+a_*uy+sg*h*ux))
    for i_,(p1,t1) in enumerate(lines):
        for p2,t2 in lines[i_+1:]:
            den=t1[0]*t2[1]-t1[1]*t2[0]
            if abs(den)<1e-12: continue
            k=((p2[0]-p1[0])*t2[1]-(p2[1]-p1[1])*t2[0])/den
            c.append((p1[0]+k*t1[0],p1[1]+k*t1[1]))
    best=None
    for q in c:
        if not valid_pin(q): continue
        key=((q[0]-f[0])**2+(q[1]-f[1])**2,q[1],q[0])
        if best is None or key[0]<best[0][0]-1e-6 or (abs(key[0]-best[0][0])<=1e-6 and key[1:]<best[0][1:]): best=(key,q)
    return hold if best is None else best[1]

class E: pass
def run(F,order,hero=None,early=False,bonus=1.8,lives=10,gold=None,burst_d=130,burst_cd=10.0,tele=.25,hero_dps=(4,1.0),log=False):
    if gold is None: gold=GOLD
    towers={}; sid=0; roster=[]; dealt={'t':0.,'h':0.,'b':0.}; q=list(order)
    bursts=[];
    def buy():
        nonlocal gold
        while q:
            a=q[0]
            if a[0]=='b':
                c=F[a[1]][0]['cost']
                if gold<c: return
                gold-=c; towers[a[2]]={'r':a[1],'l':0,'cd':0}
            else:
                t=towers[a[1]]
                if t['l']>=len(F[t['r']])-1: q.pop(0); continue
                c=F[t['r']][t['l']+1]['cost']
                if gold<c: return
                gold-=c; t['l']+=1
            q.pop(0)
    def deliver(e,a,k):
        ap=min(a,e.hp); e.hp-=ap; dealt[k]+=ap
    buy()
    hp=[None,None]; pin=None; hx=None
    pinned=False
    if hero:
        hx=list(START); pin=hero.get('pin',START)
        pinned=hero['mode']=='once' or (hero['mode']=='driven' and not hero.get('repin',True))
        if pinned: hx=list(pin)  # Hero Rule 2: a pin in Build places the hero at once
    hcd=0; bcd=0; bwait=0; bq=None; tick=0; wt=[]
    goldhist=[]
    for wi,(groups,inter) in enumerate(WAVES):
        sched=[]
        for g in groups:
            for i in range(g[1]): sched.append((tk(g[3]+i*g[2]),g[0]))
        sched.sort(key=lambda x:x[0]); si=0; w=0
        while True:
            # spawn, move, leak
            while si<len(sched) and sched[si][0]<=w:
                e=E(); e.t=sched[si][1]; e.hp=float(EN[e.t][0])*WAVE_HP[wi]; e.d=0.; e.sl=0; e.sf=1.; e.id=sid; sid+=1; roster.append(e); si+=1
            w+=1; tick+=1
            for e in list(roster):
                e.d+=EN[e.t][1]*e.sf*DT; e.p=pos(e.d)
                if e.d>=LEN:
                    roster.remove(e); lives-=EN[e.t][3]
                    if lives<=0: return dict(won=False,lives=0,wave=wi+1,**res(dealt,gold,towers,tick))
            for e in roster:
                if e.sl>0:
                    e.sl-=1
                    if e.sl==0: e.sf=1.
            tg=[e for e in roster if e.hp>0 and 0<=e.p[0]<=540 and 0<=e.p[1]<=960]
            for s in sorted(towers):
                t=towers[s]
                if t['cd']>0: t['cd']-=1
                if t['cd']>0: continue
                f=F[t['r']][t['l']]; o=SLOTS[s]
                live=[e for e in tg if e.hp>0 and math.dist(e.p,o)<=f['range']]
                if not live: continue
                if t['r']=='slow':
                    un=[e for e in live if e.sf==1.]
                    a=max(un or live,key=lambda e:(e.d,-e.id))
                else: a=max(live,key=lambda e:(e.d,-e.id))
                t['cd']=tk(f['int'])
                r=f.get('radius',0)
                vs=[e for e in tg if e.hp>0 and math.dist(e.p,a.p)<=r] if r else [a]
                for v in vs:
                    if f['dmg']: deliver(v,f['dmg'],'t')
                    if 'str' in f and v.hp>0:
                        d=tk(f['dur'])
                        if 1-f['str']<v.sf or (1-f['str']==v.sf and d>v.sl): v.sf=1-f['str']; v.sl=d
                        elif 1-f['str']==v.sf: pass
            if hero:
                tg=[e for e in tg if e.hp>0]
                if hero['mode']=='driven' and hero.get('repin',True) and tick%tk(hero.get('cad',1.5))==0 and tg:
                    # re-pin to the most advanced enemy, a little ahead, clear of nothing else
                    lead=max(tg,key=lambda e:e.d); ahead=pos(min(LEN,lead.d+60)); pin=clamp_pin(ahead,hold=tuple(pin)); pinned=True
                if hero['mode']!='none':
                    dx,dy=pin[0]-hx[0],pin[1]-hx[1]; m=math.hypot(dx,dy); st=240*DT
                    if m>st: hx[0]+=dx/m*st; hx[1]+=dy/m*st
                    else: hx[0],hx[1]=pin
                    if hcd>0: hcd-=1
                    if pinned and hcd==0 and (hx[0],hx[1])==tuple(pin):
                        c=[e for e in tg if math.dist(e.p,pin)<=90]
                        if c:
                            v=min(c,key=lambda e:(math.dist(e.p,hx),e.id)); deliver(v,hero_dps[0],'h'); hcd=tk(hero_dps[1])
                    if pinned and hero.get('burst',True) and hero['mode']=='driven':
                        if bcd>0: bcd-=1
                        if bq is not None:
                            bq[0]-=1
                            if bq[0]<=0:
                                _h=_k=0
                                for e in tg:
                                    if e.hp>0 and math.dist(e.p,bq[1])<=BR:
                                        deliver(e,burst_d,'b'); _h+=1; _k+=e.hp<=0
                                BLOG.append((_h,_k)); bq=None; bcd=tk(burst_cd)
                        elif bcd==0 and [e for e in tg if math.dist(e.p,hx)<=hero.get('reach',1e9)]:
                            bwait+=1
                            cand=[e for e in tg if math.dist(e.p,hx)<=hero.get('reach',1e9)]
                            best=max(cand,key=lambda a:sum(1 for e in tg if math.dist(e.p,a.p)<=BR))
                            n=sum(1 for e in tg if math.dist(e.p,best.p)<=BR)
                            need=min(5,hero.get('need',5))
                            if bwait>=tk(hero.get('react',0))and(n>=need or max(e.d for e in cand)>LEN*.8):
                                o=hero.get('off',0); ax,ay=best.p[0]+o,best.p[1]+o
                                ax=min(540.0,max(0.0,ax)); ay=min(960.0,max(0.0,ay))
                                if THUMB is not None: ay=min(ay,THUMB)
                                rc=hero.get('reach',None)
                                if rc is not None:
                                    d_=math.dist((ax,ay),hx)
                                    if d_>rc-.01:
                                        k_=(rc-.01)/d_; ax=hx[0]+(ax-hx[0])*k_; ay=hx[1]+(ay-hx[1])*k_
                                bq=[tk(tele),(ax,ay)]; bwait=0
            # reap
            for e in sorted([e for e in roster if e.hp<=0],key=lambda e:e.id):
                gold+=EN[e.t][2]; roster.remove(e)
            buy()
            if si>=len(sched) and not roster: break
            if w>60*600: raise SystemExit('stuck')
        goldhist.append(gold)
        if wi<len(WAVES)-1:
            # intermission
            n=tk(inter)
            # early: True calls at once; 'ready' calls the moment the burst is Ready (Flow Rule 9's gate)
            wait=(min(bcd,n) if early=='ready' else 0) if early else n
            if early: gold+=int((n-wait)//tk(bonus))
            tick+=wait
            for _ in range(wait):
                for t in towers.values():
                    if t['cd']>0: t['cd']-=1
                if bcd>0: bcd-=1
            buy()
    return dict(won=True,lives=lives,wave=6,**res(dealt,gold,towers,tick))
def res(d,g,tw,tick):
    tot=sum(d.values()) or 1
    return dict(gold=g,hs=(d['h']+d['b'])/tot,bs=d['b']/tot,tw=len(tw),up=sum(t['l'] for t in tw.values()),mins=tick/60/60)

def L(c,dmg,rng,iv,**k): return dict(cost=c,dmg=dmg,range=rng,int=iv,**k)
F={'single':[L(50,12,150,.6),L(60,21,165,.6)],
   'splash':[L(70,20,150,1,radius=55),L(80,30,165,1,radius=75)],
   'slow':[L(60,0,150,.6,str=.4,dur=2),L(70,0,165,.6,str=.5,dur=2.5)]}
def _tower_levels():
    out={}
    for t in _load('towers.json')['tower']:
        role={'tower_single':'single','tower_splash':'splash','tower_slow':'slow'}[t['id']]
        lv=[]
        for l in t['levels']:
            k={}
            if 'splash_radius' in l: k['radius']=l['splash_radius']
            if 'slow_strength' in l: k['str']=l['slow_strength']; k['dur']=l['slow_duration']
            lv.append(L(l['cost'],l['damage'],l['range'],l['attack_interval'],**k))
        out[role]=lv
    return out
if LIVE_DATA: F=_tower_levels()
NONE={r:[L(1,0,1,1)] for r in F}
ORD=[1,0,2,3,4]
UP=max(len(v) for v in F.values())-1
def mono(r): return [('b',r,s_) for s_ in ORD]+[('u',s_) for _ in range(UP) for s_ in ORD]
def mix(a): return [('b',a[i],ORD[i]) for i in range(5)]+[('u',s_) for _ in range(UP) for s_ in ORD]
MIXED={'3 single, 1 splash, 1 slow':mix(('single','splash','slow','single','single')),
 '2 single, 2 splash, 1 slow':mix(('splash','single','slow','single','splash')),
 '3 single, 2 splash':mix(('single','splash','single','single','splash')),
 '2 single, 1 splash, 2 slow':mix(('single','splash','slow','single','slow'))}
BUILDS={'Single only':mono('single'),'Splash only':mono('splash'),'Slow only':mono('slow'),**MIXED}
MID=dict(mode='driven',cad=3.0,react=2.0,off=25)
CEIL=dict(mode='driven')
GRID=[(x,y) for x in range(70,500,40) for y in range(200,880,40)]
fm=lambda r:('Won, %d'%r['lives'] if r['won'] else 'Lost W%d'%r['wave'])
def median(v):
    v=sorted(v);n=len(v)
    return v[n//2] if n%2 else (v[n//2-1]+v[n//2])/2
def table(reach=160.0,grid=True,**kw):
    x={} if reach is None else dict(reach=reach)
    print(f"BR {BR} reach {reach} THUMB {THUMB} {kw}")
    print('hero alone',fm(run(NONE,[],hero=dict(CEIL,**x),**kw)))
    sh=[]
    for b,o in BUILDS.items():
        a=run(F,o,**kw);ac=run(F,o,early=True,**kw)
        pn=run(F,o,hero=dict(MID,repin=False,pin=(270,480),**x),**kw)
        BLOG.clear();m=run(F,o,hero=dict(MID,**x),**kw);hit3=[k for h,k in BLOG if h>=3];n=len(BLOG)
        BLOG.clear();c=run(F,o,early=True,hero=dict(MID,**x),**kw);nc=len(BLOG)
        d=run(F,o,hero=dict(CEIL,**x),**kw);nb=run(F,o,hero=dict(MID,burst=False,**x),**kw)
        bp=''
        if grid and b in MIXED:
            best=None
            for p in GRID:
                if not valid_pin(p): continue
                r=run(F,o,hero=dict(MID,repin=False,pin=p,**x),**kw);q=(r['won'],r['lives'],r['wave'])
                if best is None or q>best[0]: best=(q,p,r)
            bp=f" | best pin {fm(best[2])} at {best[1]}"
        if b in MIXED: sh.append(m['hs'])
        print(f"{b:27} towers {fm(a)} | once {fm(pn)} | mid {fm(m)} share {m['hs']*100:.0f} burst {m['bs']*100:.0f} kills3+ {median(hit3) if hit3 else 0} bursts {n} {m['mins']:.1f}m | ceil {fm(d)} {d['hs']*100:.0f} | towers call {fm(ac)} | mid call {fm(c)} bursts {nc} {c['mins']:.1f}m | no burst {fm(nb)}{bp}")
    print('median share of mixed builds %.1f'%(median(sh)*100))
def boundary_samples(step=.5):
    x0,y0,x1,y1=RECT;out=[]
    for i in range(int((x1-x0)/step)+1): out+=[(x0+i*step,y0),(x0+i*step,y1)]
    for i in range(int((y1-y0)/step)+1): out+=[(x0,y0+i*step),(x1,y0+i*step)]
    for a,b,r in zones():
        for e in {a,b}:
            for i in range(int(2*math.pi*r/step)):
                t=i*step/r;out.append((e[0]+r*math.cos(t),e[1]+r*math.sin(t)))
        if a!=b:
            for sx in (-r,r):
                for i in range(int((b[1]-a[1])/step)+1): out.append((a[0]+sx,a[1]+i*step))
    return [p for p in out if valid_pin(p)]
def check_clamp():
    """Hero GDD criterion 14, for each hand: valid on an 8-unit grid; near against boundary samples at the shape ends and the bottom third."""
    global HAND
    EX={'right':(((492,888),(395.99,888)),((480,850),(492,767.99)),((200,800),(246.01,800)),((186,800),(186,739.99))),
        'left':(((60,888),(144.01,888)),((84,850),(144.01,850)),((186,800),(186,739.99)))}
    for HAND in ('right','left'):
        for fx in list(range(0,541,8))+[540]:
            for fy in list(range(0,961,8))+[960]:
                f=(float(fx),float(fy));assert valid_pin(clamp_pin(f)),f
        pts=boundary_samples()
        F=[e for a,b,r in zones() for e in (a,b)]
        F+=[(x,y) for x in list(range(0,541,20))+[540] for y in list(range(660,961,20))+[960]]
        worst=0.0;n=0
        for f in F:
            f=(float(f[0]),float(f[1]))
            if valid_pin(f): continue
            c=clamp_pin(f);worst=max(worst,math.dist(f,c)-min(math.dist(f,p) for p in pts));n+=1
        assert worst<=.03,worst
        for f,e in EX[HAND]:
            assert math.dist(clamp_pin(f),e)<.02,(HAND,f,clamp_pin(f))
        print(f"clamp_pin ok, {HAND} hand: {n} fingers against {len(pts)} boundary samples, worst excess {worst:.3f}")
    HAND='right'
def pairs(a,s): return [x for i in (0,2) for x in (('b',a[i],s[i]),('b',a[i+1],s[i+1]),('u',s[i]),('u',s[i+1]))]+[('b',a[4],s[4]),('u',s[4])]
def fill(a,s): return [('b',a[i],s[i]) for i in range(5)]+[('u',x) for x in s]
def _lives(o):
    r=run(F,o,hero=dict(MID,reach=160.0)); return r['lives'] if r['won'] else 0
def orders():
    # every placement of each mix: does upgrading early compete with filling, and does the slot matter
    for lab,b in (('3 single, 1 splash, 1 slow',('single','single','single','splash','slow')),('2 single, 2 splash, 1 slow',('single','single','splash','splash','slow')),('3 single, 2 splash',('single','single','single','splash','splash')),('2 single, 1 splash, 2 slow',('single','single','splash','slow','slow'))):
        ps=sorted(set(itertools.permutations(b)))
        fl=[_lives(fill(p,ORD)) for p in ps]; pr=[_lives(pairs(p,ORD)) for p in ps]
        print(f"{lab:27} placements {len(ps)} | fill first median {median(fl)} range {min(fl)}-{max(fl)} | upgrade in pairs median {median(pr)} range {min(pr)}-{max(pr)}")
        assert median(pr)>=median(fl) and max(fl)-min(fl)>=3
if __name__=='__main__':
    assert valid_pin(START) and valid_pin((270,480))
    check_clamp()
    if '--sweeps' in sys.argv:
        for r in (65,75): BR=r; table(grid=False)
        BR=70
        for rc in (200.0,None): table(reach=rc)
        THUMB=860.0; table(grid=False); THUMB=None
        for lab,mm in (('react 1 s, exact',dict(react=1.0,off=0)),('react 3 s, 50 off',dict(react=3.0,off=50))):
            print(lab,[(b,fm(r:=run(F,o,hero=dict(MID,reach=160.0,**mm))),round(r['hs']*100)) for b,o in MIXED.items()])
    elif '--orders' in sys.argv:
        orders()
    elif '--calls' in sys.argv:
        for b,o in BUILDS.items():
            print(f"{b:27}",' | '.join(f"{lab} {fm(r:=run(F,o,early=e,bonus=bn,hero=dict(MID,reach=160.0)))} {r['mins']:.1f}m gold {r['gold']}" for lab,e,bn in (('never',False,1.8),('ready','ready',1.8),('ready no bonus','ready',1e9),('always',True,1.8),('always no bonus',True,1e9))))
    elif '--left' in sys.argv:
        HAND='left'; table()
    else:
        table()
