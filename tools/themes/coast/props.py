"""Coast Road props: stone guardrail, rocky bank down to the sea, seaside lamp post,
two palms, cliff chunks, sea stacks, a lighthouse on its rock, a lit pier, a bell
buoy, a roadside diner with a sunset sign, a beach shack, coastal scrub, boulders,
and the player's convertible hood.

Run: blender --background --python tools/themes/coast/props.py -- game/assets/themes/coast/models [preview.png]

The ocean sits on the right (+X in game) at SEA_LEVEL; props that stand in or by
the water carry their own rock or pilings down to it, because the game places
every prop with its origin at road level.
"""
import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset, rng  # noqa: E402

RAIL_LENGTH = 6.0  # must match RAIL_LENGTH in game/scripts/themes/coast.gd
BANK_LENGTH = 12.0  # must match BANK_LENGTH in game/scripts/themes/coast.gd
LAMP_SPACING = 30.0  # must match LAMP_SPACING in game/scripts/themes/coast.gd
SEA_LEVEL = -5.0  # must match SEA_LEVEL in game/scripts/themes/coast.gd
OUT_DIR, PREVIEW = args()
reset()

STONE = material("stone", (0.30, 0.28, 0.25))
STONE_DARK = material("stone_dark", (0.20, 0.19, 0.17))
CAP_WHITE = material("cap_white", (0.62, 0.62, 0.58), rough=0.6)
REFLECTOR = material("reflector", (1.0, 0.5, 0.2), emit=(1.0, 0.45, 0.16), strength=3.5)
ROCK = material("rock", (0.085, 0.080, 0.078))
ROCK_LIGHT = material("rock_light", (0.15, 0.135, 0.12))
SCRUB = material("scrub", (0.055, 0.075, 0.045))
ICEPLANT = material("iceplant", (0.075, 0.11, 0.06))
BLOOM = material("bloom", (0.26, 0.085, 0.15))
FOAM = material("foam", (0.62, 0.70, 0.72), emit=(0.55, 0.66, 0.70), strength=0.55)
TRUNK = material("trunk", (0.15, 0.11, 0.075))
FROND = material("frond", (0.035, 0.075, 0.05))
COCONUT = material("coconut", (0.09, 0.06, 0.035))
TOWER_WHITE = material("tower_white", (0.66, 0.66, 0.64))
TOWER_RED = material("tower_red", (0.36, 0.05, 0.05))
IRON = material("iron", (0.045, 0.05, 0.055), rough=0.5, metal=0.6)
BEACON = material("beacon", (1.0, 0.94, 0.75), emit=(1.0, 0.92, 0.72), strength=14.0)
WINDOW = material("window", (0.9, 0.62, 0.3), emit=(1.0, 0.66, 0.34), strength=3.0)
PIER_WOOD = material("pier_wood", (0.13, 0.095, 0.07))
GLOBE = material("globe", (1.0, 0.86, 0.62), emit=(1.0, 0.82, 0.56), strength=8.0)
POST = material("post", (0.06, 0.075, 0.075), rough=0.5, metal=0.5)
RED_LIGHT = material("red_light", (1.0, 0.15, 0.1), emit=(1.0, 0.12, 0.08), strength=8.0)
BUOY_RED = material("buoy_red", (0.32, 0.05, 0.04), rough=0.5)
DINER_WALL = material("diner_wall", (0.50, 0.47, 0.42))
DINER_CORAL = material("diner_coral", (0.42, 0.12, 0.10))
ROOF_DARK = material("roof_dark", (0.07, 0.07, 0.08), rough=0.7)
NEON_CORAL = material("neon_coral", (1.0, 0.38, 0.32), emit=(1.0, 0.34, 0.28), strength=3.2)
NEON_GOLD = material("neon_gold", (1.0, 0.72, 0.32), emit=(1.0, 0.68, 0.28), strength=3.0)
SIGN_BACK = material("sign_back", (0.04, 0.05, 0.07))
SHACK_WOOD = material("shack_wood", (0.20, 0.15, 0.11))
SHACK_BLUE = material("shack_blue", (0.10, 0.17, 0.22))
CAR = material("car", (0.72, 0.60, 0.42), rough=0.32, metal=0.15)
CHROME = material("chrome", (0.75, 0.76, 0.78), rough=0.22, metal=1.0)
LAMP = material("lamp", (1.0, 0.88, 0.66), emit=(1.0, 0.86, 0.62), strength=9.0)
PINSTRIPE = material("pinstripe", (0.75, 0.25, 0.2), emit=(0.8, 0.26, 0.2), strength=0.35)
AMBER = material("amber", (1.0, 0.55, 0.15), emit=(1.0, 0.5, 0.12), strength=4.0)


def wobble(y, key, length, amp):
    """Smooth periodic noise along a repeating prop: equal at both ends, so tiles join."""
    r = random.Random(key * 7919 + 13)
    return amp * sum(r.uniform(0.5, 1.0) / m * math.sin(2 * math.pi * m * y / length + r.uniform(0, 6.283))
                     for m in (1, 2, 3))


def strip(m, rows, length, segs, mats):
    """A surface stretched along Y between profile rows of (x, z, wobble_x, wobble_z)."""
    for i in range(segs):
        y0, y1 = -length / 2 + i * length / segs, -length / 2 + (i + 1) * length / segs
        for k in range(len(rows) - 1):
            def at(y, kk):
                x, z, ax, az = rows[kk]
                return (x + wobble(y, kk * 3 + 1, length, ax), y, z + wobble(y, kk * 3 + 2, length, az))
            mat = mats(k, i)
            m.poly([at(y0, k), at(y1, k), at(y1, k + 1), at(y0, k + 1)], [(0, 1, 2, 3)], mat)


def guardrail():
    """Low stone wall with a white coping and a pillar per tile; the -X face looks at the road."""
    m = Model("guardrail")
    half = RAIL_LENGTH / 2
    m.box((0.6, RAIL_LENGTH, 0.72), (0, 0, 0.36), STONE)
    m.box((0.74, RAIL_LENGTH, 0.12), (0, 0, 0.78), CAP_WHITE)
    m.box((0.86, 0.7, 1.02), (0, -half + 0.35, 0.51), CAP_WHITE)
    m.box((0.05, 0.22, 0.12), (-0.44, -half + 0.35, 0.78), REFLECTOR)
    # A few proud stones break up the face; kept inside the tile so repeats join.
    for _ in range(5):
        y = rng.uniform(-half + 1.0, half - 0.5)
        m.box((0.06, rng.uniform(0.5, 1.0), rng.uniform(0.18, 0.3)), (-0.31, y, rng.uniform(0.15, 0.55)), STONE_DARK)
    return m.finish()


def bank():
    """The rocky bank from the road's lip down to the surf. Gentler than a cliff on
    purpose: anything steeper than the camera's sight line over the lip is never seen."""
    m = Model("bank")
    sea = SEA_LEVEL
    rows = [(-0.5, -0.12, 0.0, 0.0), (1.2, -0.75, 0.5, 0.12), (3.5, -1.9, 0.9, 0.35),
            (6.0, -3.2, 1.0, 0.4), (8.6, -4.3, 0.9, 0.3), (11.2, sea - 0.6, 0.7, 0.0)]
    strip(m, rows, BANK_LENGTH, 8, lambda k, i: ROCK_LIGHT if (k * 5 + i * 3) % 7 == 0 else ROCK)
    for _ in range(4):
        r = rng.uniform(0.7, 1.4)
        m.blob(r, (rng.uniform(8.5, 11.0), rng.uniform(-BANK_LENGTH / 2 + 1.5, BANK_LENGTH / 2 - 1.5), sea + r * 0.2),
               ROCK, subdiv=1, jitter=0.25, squash=0.7)
    # Surf where the rock meets the water, wobbling but tiling like the bank.
    foam = [(9.8, sea + 0.04, 0.7, 0.0), (12.4, sea + 0.04, 0.9, 0.0)]
    strip(m, foam, BANK_LENGTH, 8, lambda k, i: FOAM)
    return m.finish()


def lamp():
    """Seaside lamp post by the rail; the arm leans out toward the road (-X)."""
    m = Model("lamp")
    m.cyl(0.22, 0.2, 0.5, (0, 0, 0.25), POST, segs=8)
    m.cyl(0.09, 0.07, 6.0, (0, 0, 3.2), POST, segs=8)
    m.beam((0, 0, 5.9), (-0.7, 0, 6.35), 0.05, POST, segs=5)
    m.beam((-0.7, 0, 6.35), (-1.05, 0, 6.3), 0.05, POST, segs=5)
    m.cyl(0.32, 0.12, 0.3, (-1.1, 0, 6.2), POST, segs=10)
    m.blob(0.2, (-1.1, 0, 5.95), GLOBE, subdiv=1, jitter=0.0)
    return m.finish()


def _palm(name, height, lean, fronds, seed):
    r = random.Random(seed)
    m = Model(name)
    n = 7
    prev = (0.0, 0.0, 0.0)
    for i in range(1, n + 1):
        t = i / n
        cur = (lean * t * t, 0.0, height * t)
        m.cyl(0.3 - 0.12 * (t - 1 / n), 0.3 - 0.12 * t, math.dist(prev, cur), tuple((a + b) / 2 for a, b in zip(prev, cur)),
              TRUNK, segs=6, rot=_aim(prev, cur))
        prev = cur
    top = prev
    for k in range(fronds):
        a = k * 2 * math.pi / fronds + r.uniform(-0.25, 0.25)
        length = r.uniform(3.6, 4.6)
        lift, droop = r.uniform(0.8, 1.6), r.uniform(2.6, 3.6)
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for j in range(5):
            t = j / 4
            rr = length * t
            z = top[2] + lift * t - droop * t * t
            w = 0.62 * math.sin(math.pi * min(t + 0.08, 1.0)) + 0.04
            centre = (top[0] + ca * rr, top[1] + sa * rr, z)
            side = (-sa * w, ca * w, -0.22 * w)
            pts.append((centre, (centre[0] + side[0], centre[1] + side[1], centre[2] + side[2]),
                        (centre[0] - side[0], centre[1] - side[1], centre[2] + side[2])))
        for j in range(4):
            c0, l0, r0 = pts[j]
            c1, l1, r1 = pts[j + 1]
            m.poly([l0, c0, c1, l1], [(0, 1, 2, 3)], FROND)
            m.poly([c0, r0, r1, c1], [(0, 1, 2, 3)], FROND)
    for k in range(3):
        a = k * 2.1
        m.blob(0.22, (top[0] + math.cos(a) * 0.3, top[1] + math.sin(a) * 0.3, top[2] - 0.35), COCONUT, subdiv=1, jitter=0.0)
    return m.finish()


def _aim(a, b):
    from mathutils import Vector
    return Vector((0, 0, 1)).rotation_difference((Vector(b) - Vector(a)).normalized()).to_euler()


def palm():
    return _palm("palm", 9.5, 1.6, 9, 11)


def palm_tall():
    return _palm("palm_tall", 13.0, -2.2, 10, 23)


def crag(m, loc, radii, heights, seed, segs=7, jit=0.3, cap=None):
    """A weathered rock column: rings of jittered points stacked up and skinned with
    flat faces, the top capped (scrub on the land, bare rock at sea)."""
    r = random.Random(seed)
    cx, cy = loc[0], loc[1]
    rings = []
    for rad, z in zip(radii, heights):
        cx += r.uniform(-0.22, 0.22) * rad
        cy += r.uniform(-0.22, 0.22) * rad
        ring = []
        for s in range(segs):
            a = 2 * math.pi * s / segs + r.uniform(-0.25, 0.25)
            rr = rad * r.uniform(1 - jit, 1 + jit)
            ring.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, loc[2] + z + r.uniform(-0.12, 0.12) * rad))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for s in range(segs):
            q = [rings[j][s], rings[j][(s + 1) % segs], rings[j + 1][(s + 1) % segs], rings[j + 1][s]]
            m.poly(q, [(0, 1, 2, 3)], ROCK_LIGHT if r.random() < 0.22 else ROCK)
    m.poly(rings[-1], [tuple(range(segs))], cap or ROCK)


def cliff_a():
    m = Model("cliff_a")
    crag(m, (0, 0, 0), [6.0, 5.4, 4.6, 3.8, 2.8, 1.4], [-0.6, 3.0, 6.2, 9.0, 11.6, 13.2], 31, cap=SCRUB)
    crag(m, (1.5, 6.5, 0), [4.6, 4.0, 3.2, 2.0], [-0.6, 2.6, 5.4, 7.4], 32, cap=SCRUB)
    crag(m, (2.0, -6.0, 0), [4.0, 3.4, 2.4, 1.2], [-0.6, 2.2, 4.4, 5.6], 33, cap=SCRUB)
    return m.finish()


def cliff_b():
    m = Model("cliff_b")
    crag(m, (0, 0, 0), [7.5, 6.5, 5.4, 4.0, 2.2], [-0.6, 2.4, 4.8, 6.8, 8.2], 37, segs=8, cap=SCRUB)
    crag(m, (3.5, 5.0, 0), [5.0, 4.4, 3.4, 1.8], [-0.6, 3.5, 7.2, 9.6], 38, cap=SCRUB)
    return m.finish()


def cliff_c():
    m = Model("cliff_c")
    crag(m, (0, 0, 0), [4.4, 3.9, 3.4, 2.9, 2.3, 1.6, 0.7], [-0.6, 3.0, 6.5, 10.0, 13.0, 15.5, 16.8], 41, cap=SCRUB)
    crag(m, (2.5, 4.0, 0), [3.6, 3.0, 2.2, 1.0], [-0.6, 2.8, 5.6, 7.0], 42, cap=SCRUB)
    return m.finish()


def sea_stack():
    """A rock pillar standing in the sea, carrying its own foam ring."""
    sea = SEA_LEVEL
    m = Model("sea_stack")
    crag(m, (0, 0, sea), [4.6, 4.0, 3.4, 3.0, 2.6, 1.8, 0.8], [-2.0, 2.0, 5.5, 9.0, 12.5, 15.0, 16.2], 51)
    crag(m, (4.0, 3.0, sea), [2.4, 2.0, 1.4, 0.6], [-1.0, 1.6, 3.6, 4.6], 52)
    m.cyl(6.4, 5.4, 0.12, (0.6, 0.4, sea + 0.05), FOAM, segs=10)
    return m.finish()


def lighthouse():
    """Striped tower on a rocky islet. The world script sweeps a beam from the lamp room at z = 18.8."""
    sea = SEA_LEVEL
    m = Model("lighthouse")
    crag(m, (0, 0, sea), [9.0, 7.6, 5.6, 4.2, 3.0], [-1.5, 1.2, 3.4, 4.6, 5.05], 61, segs=9, jit=0.2)
    crag(m, (5.0, 6.0, sea), [4.0, 3.2, 1.8], [-1.0, 1.4, 2.8], 62)
    m.cyl(10.5, 9.0, 0.12, (0.5, 0.5, sea + 0.05), FOAM, segs=12)
    m.cyl(2.4, 2.4, 1.2, (0, 0, 0.6), TOWER_WHITE, segs=14)
    m.cyl(2.0, 1.3, 16.0, (0, 0, 9.2), TOWER_WHITE, segs=14)
    for z in (4.0, 8.6, 13.2):
        t = (z - 1.2) / 16.0
        r0, r1 = 2.0 - 0.7 * t + 0.02, 2.0 - 0.7 * (t + 0.11) + 0.02
        m.cyl(r0, r1, 1.8, (0, 0, z + 0.9), TOWER_RED, segs=14)
    m.cyl(2.1, 2.1, 0.25, (0, 0, 17.3), IRON, segs=14)
    for k in range(10):
        a = k * 2 * math.pi / 10
        m.box((0.06, 0.06, 0.7), (math.cos(a) * 2.0, math.sin(a) * 2.0, 17.75), IRON)
    m.cyl(2.02, 2.02, 0.06, (0, 0, 18.1), IRON, segs=14)
    m.cyl(1.0, 1.0, 1.6, (0, 0, 18.25 + 0.55), BEACON, segs=12)
    m.cyl(1.25, 0.15, 1.3, (0, 0, 20.3), TOWER_RED, segs=12)
    m.cyl(0.12, 0.05, 0.8, (0, 0, 21.3), IRON, segs=6)
    # Keeper's cottage with one lit window on the road side.
    m.box((3.0, 4.2, 2.4), (-3.4, 2.4, 1.2), TOWER_WHITE)
    m.poly([(-5.1, 0.1, 2.3), (-1.7, 0.1, 2.3), (-3.4, 0.1, 3.5), (-5.1, 4.7, 2.3), (-1.7, 4.7, 2.3), (-3.4, 4.7, 3.5)],
           [(0, 3, 5, 2), (1, 2, 5, 4), (0, 2, 1), (3, 4, 5)], TOWER_RED)
    m.box((0.08, 0.9, 0.8), (-4.93, 2.4, 1.4), WINDOW)
    return m.finish()


def pier():
    """A lit pier at sea level running out from the bank (+X is out to sea)."""
    sea = SEA_LEVEL
    m = Model("pier")
    length, deck = 64.0, sea + 1.9
    m.box((length, 4.0, 0.3), (length / 2, 0, deck), PIER_WOOD)
    # A ramp from the road's lip down to the deck.
    m.poly([(-1.0, -1.2, -0.1), (-1.0, 1.2, -0.1), (8.0, 1.2, deck + 0.15), (8.0, -1.2, deck + 0.15)], [(0, 1, 2, 3)],
           PIER_WOOD)
    for x in range(6, int(length) + 1, 6):
        for y in (-1.8, 1.8):
            m.cyl(0.2, 0.2, deck - sea + 2.0, (x, y, (deck + sea - 2.0) / 2), PIER_WOOD, segs=6)
    for y in (-1.95, 1.95):
        m.box((length - 8.0, 0.1, 0.1), (length / 2 + 4.0, y, deck + 1.0), PIER_WOOD)
    for x in range(12, int(length), 10):
        for y in (-1.95, 1.95):
            m.cyl(0.07, 0.06, 3.2, (x, y, deck + 1.75), POST, segs=6)
            m.blob(0.26, (x, y, deck + 3.45), GLOBE, subdiv=1, jitter=0.0)
    m.box((4.0, 3.4, 2.6), (length - 2.5, 0, deck + 1.45), SHACK_BLUE)
    m.box((4.6, 4.0, 0.25), (length - 2.5, 0, deck + 2.85), ROOF_DARK)
    m.box((0.08, 1.2, 0.8), (length - 4.55, 0.6, deck + 1.6), WINDOW)
    m.cyl(0.08, 0.08, 1.6, (length + 0.2, 0, deck + 3.6), POST, segs=6)
    m.blob(0.22, (length + 0.2, 0, deck + 4.5), RED_LIGHT, subdiv=1, jitter=0.0)
    return m.finish()


def buoy():
    """A bell buoy riding the swell; the world script blinks its light."""
    sea = SEA_LEVEL
    m = Model("buoy")
    m.cyl(1.1, 1.3, 1.0, (0, 0, sea + 0.2), BUOY_RED, segs=10)
    for k in range(3):
        a = k * 2 * math.pi / 3
        m.beam((math.cos(a) * 0.9, math.sin(a) * 0.9, sea + 0.6), (0, 0, sea + 3.2), 0.06, IRON, segs=4)
    m.cyl(0.35, 0.25, 0.45, (0, 0, sea + 2.4), IRON, segs=8)
    m.blob(0.2, (0, 0, sea + 3.4), RED_LIGHT, subdiv=1, jitter=0.0)
    m.cyl(1.9, 1.7, 0.08, (0, 0, sea + 0.03), FOAM, segs=10)
    return m.finish()


def diner():
    """Roadside diner (no name on it): warm window band facing the road (-X) and a neon sunset sign."""
    m = Model("diner")
    w, l, h = 4.0, 8.0, 3.4
    m.box((w * 2, l * 2, h), (0, 0, h / 2), DINER_WALL)
    m.box((w * 2 + 0.06, l * 2 + 0.06, 0.9), (0, 0, 0.45), DINER_CORAL)
    m.box((w * 2 + 1.6, l * 2 + 1.2, 0.32), (-0.3, 0, h + 0.16), ROOF_DARK)
    # Window band split into panes, so it reads as a lit room rather than one glowing strip.
    for k in range(6):
        m.box((0.08, 1.55, 1.25), (-w - 0.03, -l + 4.0 + k * 1.85, 1.8), WINDOW)
    m.box((0.1, 1.3, 2.2), (-w - 0.04, -l + 1.6, 1.1), WINDOW)
    m.box((0.06, l * 2 + 1.2, 0.08), (-w - 1.12, 0, h + 0.02), NEON_CORAL)
    # Pylon sign: a half sun over three gold bars. The diner only stands on the land
    # (left) side, where the game turns it round, so Blender +Y is toward the oncoming
    # driver: the board is angled 45 degrees that way to be read, not seen edge-on.
    px, py = -w - 1.5, l + 1.2
    m.cyl(0.16, 0.14, 7.6, (px, py, 3.8), POST, segs=6)
    turn = math.radians(-45)

    def board(u, v, z):
        """u: across the board (along Blender Y before turning), v: out of its face (toward -X)."""
        x, y = -v, u
        return (px + x * math.cos(turn) - y * math.sin(turn), py + x * math.sin(turn) + y * math.cos(turn), z)

    def slab(u0, u1, z0, z1, v, mat):
        m.poly([board(u0, v, z0), board(u1, v, z0), board(u1, v, z1), board(u0, v, z1),
                board(u0, v - 0.2, z0), board(u1, v - 0.2, z0), board(u1, v - 0.2, z1), board(u0, v - 0.2, z1)],
               [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], mat)

    slab(-2.3, 2.3, 7.2, 10.2, 0.12, SIGN_BACK)
    sun = [board(math.cos(a) * 1.7, 0.16, 8.0 + math.sin(a) * 1.7) for a in [math.pi * k / 8 for k in range(9)]]
    sun.append(board(0.0, 0.16, 8.0))
    m.poly(sun, [tuple(range(10))], NEON_CORAL)
    for z, half in ((7.75, 1.9), (7.45, 1.6)):
        slab(-half, half, z - 0.06, z + 0.06, 0.2, NEON_GOLD)
    slab(-2.35, 2.35, 10.18, 10.28, 0.2, NEON_CORAL)
    return m.finish()


def shack():
    """Weathered beach shack with a lit window and a string of party lights."""
    m = Model("shack")
    w, l, h = 2.6, 3.4, 2.8
    m.box((w * 2, l * 2, h), (0, 0, h / 2 + 0.4), SHACK_WOOD)
    for y in (-l + 0.3, l - 0.3):
        for x in (-w + 0.3, w - 0.3):
            m.box((0.25, 0.25, 0.5), (x, y, 0.2), SHACK_WOOD)
    m.poly([(-w - 0.6, -l - 0.4, h + 0.3), (w + 0.4, -l - 0.4, h + 1.1), (w + 0.4, l + 0.4, h + 1.1),
            (-w - 0.6, l + 0.4, h + 0.3)], [(0, 1, 2, 3)], SHACK_BLUE)
    m.box((0.08, 1.4, 1.0), (-w - 0.03, -1.2, 1.9), WINDOW)
    m.box((0.08, 1.0, 2.0), (-w - 0.03, 1.4, 1.4), SHACK_BLUE)
    prev = None
    for i in range(13):
        t = i / 12
        p = (-w - 0.6, -l - 0.4 + t * (l * 2 + 0.8), h + 0.25 - 0.5 * 4 * t * (1 - t))
        if prev:
            m.beam(prev, p, 0.015, IRON, segs=3)
        if 0 < i < 12:
            m.blob(0.09, (p[0], p[1], p[2] - 0.1), NEON_GOLD if i % 2 else NEON_CORAL, subdiv=0, jitter=0.0)
        prev = p
    return m.finish()


def scrub():
    """Coastal scrub: a low ice-plant mound with a few grass blades. Scattered by the thousand."""
    m = Model("scrub")
    m.blob(0.55, (0, 0, 0.05), ICEPLANT, subdiv=1, jitter=0.25, squash=0.4)
    m.blob(0.08, (0.25, 0.1, 0.24), BLOOM, subdiv=0, jitter=0.0)
    m.blob(0.07, (-0.2, -0.25, 0.21), BLOOM, subdiv=0, jitter=0.0)
    for _ in range(7):
        x, y = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
        height = rng.uniform(0.6, 1.1)
        lx, ly = rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35)
        w = 0.03
        m.poly([(x - w, y, 0), (x + w, y, 0), (x + lx, y + ly, height)], [(0, 1, 2)], SCRUB)
    return m.finish()


def boulder():
    m = Model("boulder")
    m.blob(0.6, (0, 0, 0.15), ROCK, subdiv=1, jitter=0.28, squash=0.6)
    m.blob(0.35, (0.55, 0.2, 0.05), ROCK_LIGHT, subdiv=1, jitter=0.25, squash=0.6)
    return m.finish()


def hood():
    """The player's convertible, seen from the driver's seat: cream paint, chrome, glowing bezels.
    Same footprint as the Backroads truck so the keyboard framing is identical."""
    m = Model("hood")
    w = 8.0
    # Blender +Y is down the road, so the hood runs toward -Y from the keyboard.
    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], CAR)
    # Flush coral pinstripes, painted on the hood's slope (no raised ridge in front of the keys).
    def on_hood(x, y):
        return (x, y, (0.2 - y) / 9.2 * 0.95 + 0.012)
    for x in (-5.6, 5.6):
        m.poly([on_hood(x - 0.07, 0.05), on_hood(x + 0.07, 0.05), on_hood(x + 0.07, -8.9), on_hood(x - 0.07, -8.9)],
               [(0, 1, 2, 3)], PINSTRIPE)
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.5), (x, -4.5, -0.25), CAR)
        m.box((0.14, 8.4, 0.07), (x, -4.9, 0.53), CHROME)
        m.cyl(0.78, 0.84, 0.32, (x, 0.42, 0.0), CHROME, segs=20, rot=(math.radians(90), 0, 0))
        m.cyl(0.6, 0.6, 0.34, (x, 0.48, 0.0), LAMP, segs=20, rot=(math.radians(90), 0, 0))
        m.box((0.7, 0.12, 0.22), (x - side * 0.1, 0.52, -0.7), AMBER)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), CHROME)
    m.box((w * 2 - 2.0, 0.12, 0.08), (0, 0.24, -0.35), CHROME)
    return m.finish()


export_all([guardrail, bank, lamp, palm, palm_tall, cliff_a, cliff_b, cliff_c, sea_stack, lighthouse, pier, buoy,
            diner, shack, scrub, boulder, hood], OUT_DIR, PREVIEW)
