"""Stage content-test reference check for design/gdd/enemy-wave.md.

Implements layout rules L1 to L9, L12, L13 and the wave rules that criterion 19
runs today, on the starter stage and on every copy in criterion 20's table.
Prints the reported ID set per copy and whether it matches the table.
Run: python3 tools/balance-sim/stage_rules.py
"""
import math

W, H = 540, 960
DT = 1 / 60
EPS = 1e-9
SAMPLE_STEP = 2.0                             # L8 sample spacing along the path
L8_RATIO = 1 / math.sin(math.radians(22.5))   # about 2.613


def base():
    return dict(
        P=[(-40, 226), (430, 226), (430, 400), (110, 400), (110, 570), (270, 570), (270, 980)],
        S=[(270, 320), (190, 485), (350, 485), (170, 700), (370, 700)],
        pw=72, lives=10,
        E={'normal': dict(speed=60, cost=1), 'fast': dict(speed=110, cost=1),
           'heavy': dict(speed=38, cost=2)},
        # wave id: ([(type, count, interval, start_delay)], intermission)
        waves={1: ([('normal', 8, 1.5, 0)], 15),
               2: ([('normal', 6, .6, 0), ('normal', 6, .6, 12)], 15),
               3: ([('normal', 12, .7, 0), ('fast', 8, .5, 0)], 15),
               4: ([('heavy', 2, 3, 0), ('normal', 8, .6, 8)], 15),
               5: ([('fast', 8, .4, 0), ('heavy', 2, 4, 0), ('normal', 10, .5, 4),
                    ('fast', 8, .4, 16)], 15),
               6: ([('heavy', 4, 3, 0), ('normal', 12, .5, 10), ('fast', 10, .4, 20),
                    ('normal', 8, .5, 24)], 15)},
        ids=[1, 2, 3, 4, 5, 6])


def dpp(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dy * dy
    t = 0 if l2 == 0 else max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def dss(a, b, c, d):
    d1, d2, d3, d4 = cross(c, d, a), cross(c, d, b), cross(a, b, c), cross(a, b, d)
    if d1 * d2 < 0 and d3 * d4 < 0:
        return 0
    return min(dpp(a, c, d), dpp(b, c, d), dpp(c, a, b), dpp(d, a, b))


def clip(a, b):
    """Liang-Barsky clip of segment ab to the field; returns (t0, t1) or None."""
    x0, y0 = a
    dx, dy = b[0] - a[0], b[1] - a[1]
    t0, t1 = 0.0, 1.0
    for p, q in ((-dx, x0), (dx, W - x0), (-dy, y0), (dy, H - y0)):
        if p == 0:
            if q < 0:
                return None
        else:
            r = q / p
            if p < 0:
                if r > t1:
                    return None
                t0 = max(t0, r)
            else:
                if r < t0:
                    return None
                t1 = min(t1, r)
    return t0, t1


def lerp(a, b, t):
    return (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))


def outside_by(p):
    """Euclidean distance from p to the field rectangle (0 when inside)."""
    return math.hypot(max(0, -p[0], p[0] - W), max(0, -p[1], p[1] - H))


def to_ticks(s):
    x = s / DT
    return int(math.floor(abs(x) + 0.5)) * (1 if x >= 0 else -1)


def samples(P):
    """(arc, point) at every path point and every SAMPLE_STEP along each segment."""
    out, arc = [], 0.0
    for a, b in zip(P, P[1:]):
        L = math.dist(a, b)
        n = max(1, math.ceil(L / SAMPLE_STEP))
        for k in range(n):
            out.append((arc + L * k / n, lerp(a, b, k / n)))
        arc += L
    out.append((arc, P[-1]))
    return out


def l8_fails(P, w):
    limit = w + 60
    sm = samples(P)
    for i in range(len(sm)):
        ai, pi = sm[i]
        for j in range(i + 1, len(sm)):
            aj, pj = sm[j]
            chord = math.dist(pi, pj)
            if chord < limit - EPS and (aj - ai) > L8_RATIO * chord + EPS:
                return True
    return False


def check(c):
    ids = set()
    P, S, w = c['P'], c['S'], c['pw']
    segs = list(zip(P, P[1:]))
    btn = [((456, 816), (456, 888)), ((84, 816), (84, 888))]
    if any(not (138 <= x <= 402 and y >= 304) for x, y in S):
        ids.add('L1')
    if any(min(dpp(s, a, b) for a, b in segs) < w / 2 + 40 - EPS for s in S):
        ids.add('L2')
    if any(dpp(s, a, b) < 92 - EPS for s in S for a, b in btn):
        ids.add('L3')
    if any(math.dist(S[i], S[j]) < 72 - EPS for i in range(len(S)) for j in range(i + 1, len(S))):
        ids.add('L4')
    if outside_by(P[0]) < 16 or outside_by(P[-1]) < 16:
        ids.add('L5')
    clipped = []
    for a, b in segs:
        r = clip(a, b)
        if r:
            clipped.append((lerp(a, b, r[0]), lerp(a, b, r[1])))
    miny = min(min(p[1], q[1]) for p, q in clipped) if clipped else math.inf
    if miny - w / 2 < 174 - EPS:
        ids.add('L6')
    if any(dss(a, b, *bb) < w / 2 + 64 - EPS for a, b in segs for bb in btn):
        ids.add('L7')
    if l8_fails(P, w):
        ids.add('L8')
    if sum(math.dist(p, q) for p, q in clipped) < 800:
        ids.add('L9')
    if not 3 <= len(S) <= 5:
        ids.add('L12')
    bad = any(not (0 <= x <= W and 0 <= y <= H) for x, y in P[1:-1])
    entries, exits = [], []
    for a, b in segs:
        r = clip(a, b)
        if not r:
            continue
        if r[0] > 1e-12:
            entries.append(lerp(a, b, r[0]))
        if r[1] < 1 - 1e-12:
            exits.append(lerp(a, b, r[1]))
    if len(entries) != 1 or len(exits) != 1:
        bad = True
    else:
        e, x = entries[0], exits[0]
        if not (abs(e[0]) < EPS or abs(e[0] - W) < EPS):
            bad = True
        if abs(x[1] - H) > EPS:
            bad = True
    if bad:
        ids.add('L13')
    plen = sum(math.dist(a, b) for a, b in segs)
    used, lar = set(), []
    for pos, wid in enumerate(c['ids']):
        groups, inter = c['waves'][wid]
        ticks = sorted({to_ticks(d + i * iv) for t, n, iv, d in groups for i in range(n)})
        if ticks[0] * DT > 2 + EPS:
            ids.add('first_spawn')
        if any((b - a) * DT > 12 + EPS for a, b in zip(ticks, ticks[1:])):
            ids.add('max_gap')
        lar.append(sum(n * c['E'][t]['cost'] for t, n, iv, d in groups))
        used.update(t for t, *_ in groups)
        if pos < len(c['ids']) - 1 and inter > 30:
            ids.add('intermission_cap')
        if any(n >= 2 and iv < DT - 1e-12 for t, n, iv, d in groups):
            ids.add('interval_floor')
    for t in used:
        tte = plen / c['E'][t]['speed']
        if tte < 12:
            ids.add('time_to_exit_min')
        if tte > 60:
            ids.add('time_to_exit_max')
    L = c['lives']
    if lar[0] >= L:
        ids.add('first_lives')
    if any(x < 1 for x in lar):
        ids.add('wave_lives')
    if sum(lar) < L:
        ids.add('stage_lives')
    if any(e['cost'] > math.ceil(L / 3) for t, e in c['E'].items() if t in used):
        ids.add('lives_cost_cap')
    if L < 2 or len(c['ids']) < 2:
        ids.add('min_lives_waves')
    return ids


B = base()['P']


def copy_with(fn):
    c = base()
    fn(c)
    return c


def set_slot(i, v):
    return lambda c: c['S'].__setitem__(i, v)


def set_path(pts):
    return lambda c: c.__setitem__('P', pts)


def set_point(i, v):
    return lambda c: c['P'].__setitem__(i, v)


def set_group(wid, gi, field, val):
    def f(c):
        groups, inter = c['waves'][wid]
        groups = list(groups)
        t, n, iv, d = groups[gi]
        if field == 'start_delay':
            d = val
        else:
            iv = val
        groups[gi] = (t, n, iv, d)
        c['waves'][wid] = (groups, inter)
    return f


def set_enemy(t, k, v):
    return lambda c: c['E'][t].__setitem__(k, v)


def set_inter(wid, v):
    return lambda c: c['waves'].__setitem__(wid, (c['waves'][wid][0], v))


def both(f, g):
    return lambda c: (f(c), g(c))


# Quarter arc of radius 40 baked to points, replacing the corner at (430, 226).
ARC = [(390 + 40 * math.sin(math.radians(a)), 266 - 40 * math.cos(math.radians(a)))
       for a in range(0, 91, 15)]

COPIES = [
    ('L1, x low', set_slot(3, (130, 700)), {'L1'}),
    ('L1, x high', set_slot(4, (410, 700)), {'L1'}),
    ('L1, y low', set_slot(0, (270, 303)), {'L1'}),
    ('L2', set_slot(1, (180, 485)), {'L2'}),
    ('L3, left hand', set_slot(3, (150, 760)), {'L3'}),
    ('L3, right hand', set_slot(4, (390, 760)), {'L3'}),
    ('L4', set_slot(2, (250, 485)), {'L4'}),
    ('L5, first point', set_point(0, (-10, 226)), {'L5'}),
    ('L5, last point', set_point(6, (270, 970)), {'L5'}),
    ('L6', both(set_point(0, (-40, 200)), set_point(1, (430, 200))), {'L6'}),
    ('L7', set_path(B[:5] + [(270, 570), (270, 780), (400, 980)]), {'L7'}),
    ('L8, close legs', set_path([(-40, 226), (500, 226), (500, 300), (430, 300)] + B[2:]), {'L8'}),
    ('L8, doubled back', set_path(B[:6] + [(270, 900), (250, 700), (250, 980)]), {'L8'}),
    ('L8, baked curve passes', set_path([B[0]] + ARC + B[2:]), set()),
    ('L9', set_path([(-40, 620), (270, 620), (270, 980)]), {'L9', 'time_to_exit_min'}),
    ('L12, too few', lambda c: c.__setitem__('S', c['S'][:2]), {'L12'}),
    ('L12, too many', lambda c: c['S'].append((350, 630)), {'L12'}),
    ('L13, interior point outside', set_path([(-40, 226), (-20, 226)] + B[1:]), {'L13'}),
    ('L13, entry by the top', set_path([(430, -40)] + B[2:]), {'L13', 'L6'}),
    ('L13, entry by the right passes', set_point(0, (580, 226)), set()),
    ('L13, exit by a side', set_path(B[:5] + [(580, 570)]), {'L13'}),
    ('first_spawn', set_group(1, 0, 'start_delay', 3), {'first_spawn'}),
    ('max_gap', set_group(2, 1, 'start_delay', 17), {'max_gap'}),
    ('time_to_exit_min', set_enemy('fast', 'speed', 150), {'time_to_exit_min'}),
    ('time_to_exit_max', set_enemy('heavy', 'speed', 25), {'time_to_exit_max'}),
    ('first_lives', lambda c: c.__setitem__('lives', 8), {'first_lives'}),
    ('wave_lives', set_enemy('normal', 'cost', 0), {'wave_lives'}),
    ('stage_lives', lambda c: c.__setitem__('lives', 121), {'stage_lives'}),
    ('lives_cost_cap', set_enemy('heavy', 'cost', 5), {'lives_cost_cap'}),
    ('intermission_cap', set_inter(1, 31), {'intermission_cap'}),
    ('interval_floor', set_group(1, 0, 'interval', 0.01), {'interval_floor'}),
    ('min_lives_waves, lives', lambda c: c.__setitem__('lives', 1),
     {'min_lives_waves', 'first_lives', 'lives_cost_cap'}),
    ('min_lives_waves, waves', lambda c: c.__setitem__('ids', [1]),
     {'min_lives_waves', 'stage_lives'}),
]


def main():
    ok = True
    real = check(base())
    print('real stage:', sorted(real))
    ok &= real == set()
    for name, fn, expected in COPIES:
        got = check(copy_with(fn))
        match = got == expected
        ok &= match
        print('OK  ' if match else 'DIFF', name, sorted(got),
              '' if match else 'expected ' + str(sorted(expected)))
    print('ALL MATCH' if ok else 'MISMATCH')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
