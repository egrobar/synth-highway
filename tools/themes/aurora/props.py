"""Aurora Pass props: snow-laden pines, snowbanks, snowy crags and rocks, snow poles with reflectors, a
log cabin and a chapel with warm windows, a stone viaduct beside the road, a split-rail fence,
and the player's snow 4x4 hood. (The mountains are in the sky panorama: 3D peaks hid the aurora.)

Run: blender --background --python tools/themes/aurora/props.py -- game/assets/themes/aurora/models [preview.png]
"""
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset, rng  # noqa: E402

POLE_SPACING = 16.0  # must match POLE_SPACING in game/scripts/themes/aurora.gd
BANK_LENGTH = 12.0  # must match BANK_LENGTH in game/scripts/themes/aurora.gd
FENCE_LENGTH = 6.0  # must match FENCE_LENGTH in game/scripts/themes/aurora.gd
OUT_DIR, PREVIEW = args()
reset()

BARK = material("bark", (0.10, 0.065, 0.045))
NEEDLE = material("needle", (0.018, 0.062, 0.048))
NEEDLE_DARK = material("needle_dark", (0.012, 0.042, 0.036))
SNOW = material("snow", (0.74, 0.80, 0.88), rough=0.9)
SNOW_SHADE = material("snow_shade", (0.50, 0.57, 0.68), rough=0.95)
BANK = material("bank", (0.56, 0.62, 0.72), rough=0.95)
ROCK = material("rock", (0.15, 0.15, 0.17), rough=0.95)
ROCK_DARK = material("rock_dark", (0.075, 0.078, 0.09), rough=0.95)
LOG = material("log", (0.19, 0.105, 0.055))
LOG_END = material("log_end", (0.40, 0.28, 0.17))
STONE = material("stone", (0.30, 0.29, 0.28))
STONE_DARK = material("stone_dark", (0.17, 0.17, 0.18))
WALL_WHITE = material("wall_white", (0.56, 0.54, 0.50))
ROOF = material("roof", (0.07, 0.07, 0.09), rough=0.7)
WINDOW = material("window", (0.95, 0.62, 0.28), emit=(1.0, 0.64, 0.28), strength=5.0)
LANTERN = material("lantern", (1.0, 0.75, 0.4), emit=(1.0, 0.72, 0.38), strength=8.0)
POLE_ORANGE = material("pole_orange", (0.62, 0.16, 0.03), rough=0.5)
POLE_BLACK = material("pole_black", (0.025, 0.025, 0.03))
REFLECTOR = material("reflector", (1.0, 0.55, 0.12), emit=(1.0, 0.52, 0.1), strength=3.0)
PAINT = material("paint", (0.075, 0.30, 0.15), rough=0.35, metal=0.15)
TRIM_BLACK = material("trim_black", (0.02, 0.022, 0.026), rough=0.6)
BEZEL = material("bezel", (0.55, 0.9, 1.0), emit=(0.5, 0.88, 1.0), strength=3.5)
LAMP = material("lamp", (0.92, 0.97, 1.0), emit=(0.88, 0.95, 1.0), strength=9.0)
LIGHT_BAR = material("light_bar", (0.86, 0.95, 1.0), emit=(0.8, 0.93, 1.0), strength=3.0)
MARKER = material("marker", (1.0, 0.6, 0.15), emit=(1.0, 0.55, 0.12), strength=4.0)
BELL = material("bell", (0.5, 0.4, 0.2), rough=0.35, metal=0.9)


def fir(m, height, base_r, tiers, x=0.0, y=0.0):
    """A snow-laden conifer: stacked cones, each tier's upper part white with snow."""
    m.cyl(base_r * 0.11, base_r * 0.07, height * 0.3, (x, y, height * 0.15), BARK, segs=6)
    z = height * 0.16
    for i in range(tiers):
        f = i / tiers
        r = base_r * (1.0 - 0.74 * f) * rng.uniform(0.92, 1.06)
        h = height * (0.42 - 0.12 * f)
        spin = (0, 0, rng.uniform(0, math.pi))
        m.cyl(r, 0.04, h, (x, y, z + h / 2), NEEDLE if i % 2 else NEEDLE_DARK, segs=8, rot=spin)
        # Snow lies on the part of each tier the next one does not cover, a hair wider than the needles,
        # leaving a dark rim of branch tips below it. (Snow on the upper part of a tier hides inside
        # the tier above.)
        s0, s1 = 0.2, 0.6 if i < tiers - 1 else 1.0
        sh = h * (s1 - s0) + (0.05 if s1 == 1.0 else 0.0)
        r0 = r * (1.0 - s0) * 1.05 + 0.04
        r1 = r * (1.0 - s1) * 1.05 + 0.03
        m.cyl(r0, r1, sh, (x, y, z + h * s0 + sh / 2), SNOW, segs=8, rot=spin)
        z += h * 0.52
    return m


def pine():
    return fir(Model("pine"), 13.0, 3.4, 5).finish()


def pine_small():
    return fir(Model("pine_small"), 6.0, 1.8, 3).finish()


def pine_pair():
    """Two firs on one footprint, for the forest scatter."""
    m = Model("pine_pair")
    fir(m, 10.5, 2.8, 4, -1.6, -0.8)
    fir(m, 7.0, 2.0, 3, 1.9, 1.2)
    return m.finish()


def snowbank():
    """The plough's bank along the shoulder: a low, long ridge of overlapping drifts (a little greyer
    than fresh snow, so it does not glare next to the keys), exactly one repeat long."""
    m = Model("snowbank")
    n = 8
    step = BANK_LENGTH / n
    for k in range(n):
        y = -BANK_LENGTH / 2 + (k + 0.5) * step
        m.blob(1.7, (0.3, y, -0.1), BANK, subdiv=2, jitter=0.07, squash=0.38)
        m.blob(1.3, (1.5, y + step * 0.5, 0.0), SNOW_SHADE, subdiv=1, jitter=0.12, squash=0.5)
    return m.finish()


def rock():
    """A small snow-capped rock, scattered in the drifts."""
    m = Model("rock")
    m.blob(0.9, (0, 0, 0.35), ROCK, subdiv=1, jitter=0.3, squash=0.8)
    m.blob(0.62, (0.05, 0.05, 0.92), SNOW, subdiv=1, jitter=0.15, squash=0.4)
    return m.finish()


def crag():
    """A broken rock outcrop with snow lying on its ledges."""
    m = Model("crag")
    spires = [((0, 0, 4.2), 3.6, 1.7), ((2.8, 1.6, 2.8), 2.7, 1.5), ((-2.4, -1.4, 2.4), 2.4, 1.4),
              ((1.0, -2.6, 1.8), 2.0, 1.3), ((-1.2, 2.7, 3.2), 2.4, 1.8)]
    for (x, y, z), r, stretch in spires:
        m.blob(r, (x, y, z), ROCK if r > 2.3 else ROCK_DARK, subdiv=1, jitter=0.28, squash=stretch)
        top = z + r * stretch * 0.72
        m.blob(r * 0.55, (x + 0.15, y, top), SNOW, subdiv=1, jitter=0.2, squash=0.32)
    m.blob(4.8, (0, 0, 0.0), SNOW_SHADE, subdiv=2, jitter=0.1, squash=0.22)
    return m.finish()


def snow_pole():
    """An orange snow pole with an amber reflector facing the road (-X). One per POLE_SPACING."""
    m = Model("snow_pole")
    m.box((0.12, 0.12, 2.0), (0, 0, 1.0), POLE_ORANGE)
    m.box((0.13, 0.13, 0.5), (0, 0, 2.25), POLE_BLACK)
    m.box((0.04, 0.1, 0.28), (-0.08, 0, 2.2), REFLECTOR)
    m.blob(0.4, (0.05, 0, 0.0), SNOW, subdiv=1, jitter=0.2, squash=0.5)
    return m.finish()


def fence():
    """A split-rail fence with snow on its posts and top rail, exactly FENCE_LENGTH long."""
    m = Model("fence")
    for y in (-FENCE_LENGTH / 2, 0.0):
        y += rng.uniform(-0.05, 0.05)
        m.box((0.18, 0.18, 1.5), (0, y, 0.75), LOG)
        m.box((0.24, 0.24, 0.1), (0, y, 1.53), SNOW)
    for z in (0.62, 1.18):
        m.box((0.09, FENCE_LENGTH, 0.13), (0.1, 0, z), LOG, rot=(rng.uniform(-0.012, 0.012), 0, 0))
    m.box((0.14, FENCE_LENGTH, 0.06), (0.1, 0, 1.27), SNOW)
    return m.finish()


def roof(m, w, l, h, ridge, overhang=0.45, snow=0.22, thick=0.2):
    """A gabled roof along Y: two slabs, each with a blanket of snow lying on it. Slabs rather than
    open faces, so every face is part of a closed solid and its normal points the right way."""
    run, rise = w + overhang, ridge - (h - 0.1)
    a = math.atan2(rise, run)
    span = math.hypot(run, rise) + 0.2
    for side in (-1, 1):
        cx, cz = side * run / 2, (h - 0.1 + ridge) / 2
        nx, nz = side * math.sin(a), math.cos(a)
        m.box((span, l * 2 + 0.7, thick), (cx, 0, cz), ROOF, rot=(0, side * a, 0))
        off = (thick + snow) / 2
        m.box((span - 0.15, l * 2 + 0.6, snow), (cx + nx * off, 0, cz + nz * off), SNOW, rot=(0, side * a, 0))


def gable(m, w, y, h, ridge, mat, depth=0.25):
    """The triangular wall under a roof end, as a thin closed prism."""
    pts = []
    for dy in (-depth / 2, depth / 2):
        pts += [(-w, y + dy, h), (w, y + dy, h), (0, y + dy, ridge)]
    m.poly(pts, [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], mat)


def cabin():
    """A log cabin with warm windows and a lantern by the door, on the road side (-X)."""
    m = Model("cabin")
    w, l, h, ridge = 3.4, 4.4, 3.0, 5.3
    r = 0.25
    for i in range(6):
        z = r + i * 2 * r
        for side in (-1, 1):
            m.cyl(r, r, l * 2 + 0.6, (side * w, 0, z), LOG, segs=6, rot=(math.radians(90), 0, 0))
            m.cyl(r, r, w * 2 + 0.6, (0, side * l, z), LOG, segs=6, rot=(0, math.radians(90), 0))
    for side in (-1, 1):
        gable(m, w, side * l, h, ridge - 0.1, LOG)
    roof(m, w, l, h, ridge)
    for y in (-2.4, 2.4):
        m.box((0.16, 1.2, 1.1), (-w - 0.22, y, 1.7), WINDOW)
        m.box((0.2, 1.45, 0.16), (-w - 0.26, y, 1.12), SNOW)
    m.box((0.14, 1.1, 2.1), (-w - 0.22, 0, 1.05), LOG_END)
    m.box((0.25, 0.25, 0.32), (-w - 0.4, 0.95, 2.35), LANTERN)
    m.box((0.12, 1.0, 0.9), (0, l + 0.22, 3.4), WINDOW)
    m.box((0.9, 0.9, 2.6), (1.8, -2.4, 5.4), STONE)
    m.box((1.05, 1.05, 0.22), (1.8, -2.4, 6.8), SNOW)
    m.blob(2.2, (-w - 0.4, -l - 0.6, 0), SNOW, subdiv=1, jitter=0.15, squash=0.35)
    return m.finish()


def chapel():
    """A small whitewashed chapel with tall warm windows on the road side (-X) and a bell tower."""
    m = Model("chapel")
    w, l, h, ridge = 2.8, 4.8, 3.6, 7.0
    m.box((w * 2, l * 2, h), (0, 0, h / 2), WALL_WHITE)
    for side in (-1, 1):
        gable(m, w, side * (l - 0.1), h, ridge, WALL_WHITE)
    roof(m, w, l, h, ridge, overhang=0.3, snow=0.25)
    for y in (-2.8, 0.0, 2.8):
        m.box((0.12, 0.75, 1.9), (-w - 0.02, y, 1.9), WINDOW)
        # A diamond half sunk into the wall makes the pointed top of a lancet window.
        m.box((0.12, 0.53, 0.53), (-w - 0.02, y, 2.85), WINDOW, rot=(math.radians(45), 0, 0))
    # Bell tower on the far end, with a snowy spire.
    tx, ty, tw = 0.0, l + 1.1, 1.4
    m.box((tw * 2, tw * 2, 7.8), (tx, ty, 3.9), WALL_WHITE)
    m.box((tw * 2 + 0.1, tw * 2 + 0.1, 0.3), (tx, ty, 7.9), STONE_DARK)
    m.box((0.12, 0.8, 1.3), (tx - tw - 0.02, ty, 6.6), WINDOW)
    m.box((0.12, 1.0, 2.2), (tx - tw - 0.02, ty, 1.1), LOG_END)
    m.cyl(0.32, 0.5, 0.6, (tx, ty, 6.9), BELL, segs=8)
    spire = [(tx - tw - 0.1, ty - tw - 0.1, 8.05), (tx + tw + 0.1, ty - tw - 0.1, 8.05),
             (tx + tw + 0.1, ty + tw + 0.1, 8.05), (tx - tw - 0.1, ty + tw + 0.1, 8.05), (tx, ty, 12.4)]
    m.poly(spire, [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)], ROOF)
    m.cyl(1.0, 0.05, 2.6, (tx, ty, 8.25 + 1.3 + 1.4), SNOW, segs=4, rot=(0, 0, math.radians(45)))
    m.box((0.06, 0.06, 1.0), (tx, ty, 12.9), BELL)
    m.box((0.06, 0.5, 0.06), (tx, ty, 13.1), BELL)
    m.box((0.18, 0.18, 0.28), (-w - 0.3, -l + 0.6, 2.3), LANTERN)
    return m.finish()


def viaduct():
    """A three-arch stone railway viaduct running alongside the road (never over it), snow on its deck.
    Built from thin vertical slices, so the arches come out stepped like dressed stone."""
    m = Model("viaduct")
    length, deck, thick = 22.0, 7.4, 3.0
    piers = [-11.0, -3.7, 3.7, 11.0]
    pier_w = 1.6
    slices = 55
    step = length / slices
    for i in range(slices):
        y = -length / 2 + (i + 0.5) * step
        opening = 0.0
        for a, b in zip(piers, piers[1:]):
            lo, hi = a + pier_w / 2, b - pier_w / 2
            if lo < y < hi:
                half = (hi - lo) / 2
                centre = (hi + lo) / 2
                spring = 2.6
                opening = spring + math.sqrt(max(0.0, half * half - (y - centre) ** 2))
        mat = STONE if i % 2 else STONE_DARK
        m.box((thick, step * 1.02, deck - opening), (0, y, opening + (deck - opening) / 2), mat)
    m.box((thick + 0.5, length + 0.6, 0.5), (0, 0, deck + 0.25), STONE_DARK)
    for side in (-1, 1):
        m.box((0.35, length + 0.6, 0.7), (side * (thick / 2 + 0.05), 0, deck + 0.85), STONE)
        m.box((0.5, length + 0.7, 0.18), (side * (thick / 2 + 0.05), 0, deck + 1.28), SNOW)
    m.box((thick - 0.4, length + 0.4, 0.3), (0, 0, deck + 0.62), SNOW)
    for y in piers:
        m.blob(1.7, (-0.2, y, 0.0), SNOW, subdiv=1, jitter=0.15, squash=0.45)
    return m.finish()


def hood():
    """The player's snow 4x4, seen from the driver's seat, behind the keyboard: forest green, black
    fender flares with amber markers, snow on the fenders, glowing ice-blue lamp bezels and a low
    light bar under the keys."""
    m = Model("hood")
    w = 8.0
    # Blender +Y is down the road, so the hood runs toward -Y from the keyboard.
    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], PAINT)
    # Plain paint on the hood itself: white stripes down its middle read as road markings from the
    # driver's seat, and a raised centre ridge stood up in front of the middle keys in Backroads.
    # Snow has piled on the fenders' back halves instead.
    for side in (-1, 1):
        for y, r in ((-6.2, 0.75), (-7.6, 0.85), (-8.9, 0.7)):
            m.blob(r, (side * (w + 0.85), y, 0.5), SNOW, subdiv=1, jitter=0.15, squash=0.35)
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.5), (x, -4.5, -0.25), PAINT)
        m.box((0.4, 9.7, 0.42), (side * (w + 1.92), -4.5, 0.32), TRIM_BLACK)
        m.box((0.3, 0.3, 0.14), (side * (w + 1.3), -0.4, 0.55), MARKER)
        m.cyl(0.74, 0.82, 0.3, (x, 0.42, 0.0), BEZEL, segs=20, rot=(math.radians(90), 0, 0))
        m.cyl(0.58, 0.58, 0.32, (x, 0.48, 0.0), LAMP, segs=20, rot=(math.radians(90), 0, 0))
    # The light bar sits below the hood's front edge, under the keys, so it never glares over them.
    m.box((w * 2 - 1.2, 0.3, 0.42), (0, 0.38, -0.55), TRIM_BLACK)
    m.box((w * 2 - 1.6, 0.12, 0.2), (0, 0.55, -0.55), LIGHT_BAR)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), TRIM_BLACK)
    return m.finish()


export_all([pine, pine_small, pine_pair, snowbank, rock, crag, snow_pole, fence, cabin, chapel, viaduct, hood],
           OUT_DIR, PREVIEW)
