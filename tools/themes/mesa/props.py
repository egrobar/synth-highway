"""Red Mesa props: banded mesas, a butte, hoodoos, boulders, saguaros, desert scrub, bunchgrass and
rocks for scatter, a rusted barbed-wire fence, an H-frame power line, a roadside motel with a neon
sign, a gas station canopy, a water tank with a windmill, and the player's muscle-car hood.

Run: blender --background --python tools/themes/mesa/props.py -- game/assets/themes/mesa/models [preview.png]

Material names matter: game/scripts/themes/mesa.gd looks up "neon_red" and "neon_green" by name to
make the motel sign buzz and blink.
"""
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset, rng  # noqa: E402

LINE_SPACING = 36.0  # must match LINE_SPACING in game/scripts/themes/mesa.gd
FENCE_LENGTH = 8.0  # must match FENCE_LENGTH in game/scripts/themes/mesa.gd
OUT_DIR, PREVIEW = args()
reset()

ROCK_RED = material("rock_red", (0.36, 0.09, 0.04))
ROCK_BAND = material("rock_band", (0.5, 0.18, 0.08))
ROCK_DARK = material("rock_dark", (0.2, 0.055, 0.03))
ROCK_CAP = material("rock_cap", (0.56, 0.3, 0.16))
CACTUS = material("cactus", (0.07, 0.14, 0.065))
SCRUB = material("scrub", (0.1, 0.105, 0.06))
SCRUB_DRY = material("scrub_dry", (0.2, 0.13, 0.065))
GRASS = material("grass", (0.5, 0.36, 0.17))
WOOD = material("wood", (0.13, 0.085, 0.055))
WOOD_GREY = material("wood_grey", (0.27, 0.23, 0.2))
RUST = material("rust", (0.34, 0.13, 0.05), rough=0.7, metal=0.35)
RUST_DARK = material("rust_dark", (0.16, 0.07, 0.04), rough=0.8, metal=0.3)
STEEL = material("steel", (0.4, 0.4, 0.42), rough=0.5, metal=0.6)
WIRE = material("wire", (0.025, 0.02, 0.02))
INSULATOR = material("insulator", (0.25, 0.42, 0.3), rough=0.3)
STUCCO = material("stucco", (0.58, 0.42, 0.3))
TURQUOISE = material("turquoise", (0.08, 0.3, 0.28), rough=0.6)
ROOF = material("roof", (0.1, 0.09, 0.09))
WINDOW = material("window", (0.9, 0.6, 0.3), emit=(1.0, 0.58, 0.26), strength=4.0)
WINDOW_DIM = material("window_dim", (0.05, 0.045, 0.05), rough=0.3)
PANEL = material("panel", (0.06, 0.05, 0.05), rough=0.5)
NEON_RED = material("neon_red", (1.0, 0.12, 0.05), emit=(1.0, 0.07, 0.03), strength=4.5)
NEON_AMBER = material("neon_amber", (1.0, 0.55, 0.15), emit=(1.0, 0.45, 0.08), strength=3.5)
NEON_GREEN = material("neon_green", (0.35, 1.0, 0.25), emit=(0.3, 1.0, 0.15), strength=3.5)
CANOPY = material("canopy", (0.62, 0.6, 0.56))
CANOPY_LIGHT = material("canopy_light", (1.0, 0.95, 0.85), emit=(1.0, 0.93, 0.8), strength=6.0)
PUMP = material("pump", (0.45, 0.05, 0.04), rough=0.5)
PAINT = material("paint", (0.02, 0.018, 0.022), rough=0.22, metal=0.65)
STRIPE = material("stripe", (0.55, 0.06, 0.03), rough=0.3, metal=0.3)
SCOOP = material("scoop", (0.012, 0.012, 0.014), rough=0.65)
CHROME = material("chrome", (0.8, 0.8, 0.82), rough=0.16, metal=1.0)
LAMP = material("lamp", (1.0, 0.88, 0.62), emit=(1.0, 0.86, 0.6), strength=9.0)
BEZEL = material("bezel_glow", (1.0, 0.45, 0.12), emit=(1.0, 0.36, 0.06), strength=2.4)

# A tiny stroke font for neon signs: each letter is line segments on a 2-wide, 4-tall grid.
FONT = {
    "A": [(0, 0, 0, 4), (2, 0, 2, 4), (0, 4, 2, 4), (0, 2, 2, 2)],
    "C": [(0, 0, 0, 4), (0, 4, 2, 4), (0, 0, 2, 0)],
    "E": [(0, 0, 0, 4), (0, 4, 2, 4), (0, 2, 1.4, 2), (0, 0, 2, 0)],
    "G": [(0, 0, 0, 4), (0, 4, 2, 4), (0, 0, 2, 0), (2, 0, 2, 2), (1, 2, 2, 2)],
    "L": [(0, 0, 0, 4), (0, 0, 2, 0)],
    "M": [(0, 0, 0, 4), (2, 0, 2, 4), (0, 4, 1, 2), (1, 2, 2, 4)],
    "N": [(0, 0, 0, 4), (2, 0, 2, 4), (0, 4, 2, 0)],
    "O": [(0, 0, 0, 4), (2, 0, 2, 4), (0, 4, 2, 4), (0, 0, 2, 0)],
    "S": [(0, 4, 2, 4), (0, 2, 0, 4), (0, 2, 2, 2), (2, 0, 2, 2), (0, 0, 2, 0)],
    "T": [(0, 4, 2, 4), (1, 0, 1, 4)],
    "V": [(0, 4, 1, 0), (1, 0, 2, 4)],
    "Y": [(0, 4, 1, 2), (2, 4, 1, 2), (1, 2, 1, 0)],
}


def neon_text(m, text, center, unit, face_y, mat, vertical=False, stroke=None):
    """Glowing stroke letters on a sign face that lies in the X-Z plane at y = center.y + face_y.
    face_y < 0 is the side oncoming traffic sees (reads along +X); face_y > 0 is the back (reads along -X)."""
    cx, cy, cz = center
    ax = 1.0 if face_y < 0 else -1.0
    stroke = stroke or unit * 0.42
    depth = 0.07
    y = cy + face_y + math.copysign(depth / 2, face_y)
    n = len(text)
    for k, ch in enumerate(text):
        if vertical:
            ou, ov = -unit, (n * 5.5 - 1.5) * unit / 2 - 4 * unit - k * 5.5 * unit
        else:
            ou, ov = -(n * 3 - 1) * unit / 2 + k * 3 * unit, -2 * unit
        for x0, y0, x1, y1 in FONT[ch]:
            du, dv = (x1 - x0) * unit, (y1 - y0) * unit
            length = math.hypot(du, dv)
            mu, mv = ou + (x0 + x1) / 2 * unit, ov + (y0 + y1) / 2 * unit
            theta = math.atan2(-dv, ax * du)
            m.box((length + stroke, depth, stroke), (cx + ax * mu, y, cz + mv), mat, rot=(0, theta, 0))


def sign_panel(m, text, center, size, unit, letters, frame, vertical=False):
    """A two-sided blade sign facing up and down the road, letters on both faces, neon frame."""
    cx, cy, cz = center
    w, t, h = size
    m.box((w, t, h), center, PANEL)
    for face in (-1, 1):
        neon_text(m, text, center, unit, face * t / 2, letters, vertical)
    tube = 0.11
    for dz in (-h / 2, h / 2):
        m.box((w + tube, t + tube, tube), (cx, cy, cz + dz), frame)
    for dx in (-w / 2, w / 2):
        m.box((tube, t + tube, h), (cx + dx, cy, cz), frame)


# ---------------------------------------------------------------- rock formations

def _footprint(n, rx, ry, jitter):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        j = rng.uniform(1 - jitter, 1 + jitter * 0.5)
        pts.append((math.cos(a) * rx * j, math.sin(a) * ry * j))
    return pts


def _layer(m, base, s_lo, z_lo, s_hi, z_hi, mat, wobble=0.035, offset=(0.0, 0.0)):
    """One eroded rock stratum: a closed prism from a scaled, wobbled footprint."""
    n = len(base)
    ox, oy = offset

    def ring(s, z):
        return [(ox + x * s * (1 + rng.uniform(-wobble, wobble)), oy + y * s * (1 + rng.uniform(-wobble, wobble)), z)
                for x, y in base]

    verts = ring(s_lo, z_lo) + ring(s_hi, z_hi)
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(range(n, 2 * n)))
    faces.append(tuple(reversed(range(n))))
    m.poly(verts, faces, mat)


def _strata(m, base, layers, offset=(0.0, 0.0)):
    for s_lo, z_lo, s_hi, z_hi, mat in layers:
        _layer(m, base, s_lo, z_lo, s_hi, z_hi, mat, offset=offset)


def mesa():
    """A long flat-topped mesa: talus skirt, banded cliffs, a pale caprock."""
    m = Model("mesa")
    base = _footprint(20, 15.0, 27.0, 0.14)
    _strata(m, base, [
        (1.5, 0.0, 1.1, 5.0, ROCK_DARK),
        (1.06, 5.0, 1.03, 10.0, ROCK_RED),
        (1.0, 10.0, 0.97, 11.0, ROCK_BAND),
        (0.93, 11.0, 0.9, 16.5, ROCK_RED),
        (0.88, 16.5, 0.87, 17.4, ROCK_BAND),
        (0.9, 17.4, 0.9, 19.0, ROCK_CAP),
    ])
    for _ in range(5):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(1.25, 1.5)
        m.blob(rng.uniform(1.4, 2.8), (math.cos(a) * 15 * d, math.sin(a) * 27 * d, 0.5), ROCK_DARK,
               subdiv=1, jitter=0.25, squash=0.7)
    return m.finish()


def butte():
    """A tall butte with a lower shoulder beside it."""
    m = Model("butte")
    base = _footprint(14, 7.0, 8.0, 0.12)
    _strata(m, base, [
        (1.8, 0.0, 1.15, 7.0, ROCK_DARK),
        (1.08, 7.0, 1.02, 15.0, ROCK_RED),
        (0.98, 15.0, 0.95, 16.2, ROCK_BAND),
        (0.92, 16.2, 0.86, 26.0, ROCK_RED),
        (0.84, 26.0, 0.82, 27.0, ROCK_BAND),
        (0.86, 27.0, 0.86, 28.8, ROCK_CAP),
    ])
    shoulder = _footprint(10, 5.0, 6.0, 0.15)
    _strata(m, shoulder, [
        (1.6, 0.0, 1.1, 5.0, ROCK_DARK),
        (1.05, 5.0, 0.98, 11.0, ROCK_RED),
        (1.0, 11.0, 1.0, 12.2, ROCK_CAP),
    ], offset=(3.0, 13.0))
    return m.finish()


def hoodoos():
    """Three eroded spires, each with a balanced cap rock."""
    m = Model("hoodoos")
    for x, y, h, r in ((0.0, 0.0, 9.0, 1.3), (2.6, 2.4, 6.5, 1.0), (-2.2, 3.0, 5.0, 0.9)):
        z = 0.0
        segs = int(h / 1.6) + 1
        for i in range(segs):
            seg_h = h / segs
            pinch = 0.75 + 0.25 * math.cos(i * 1.7)
            m.cyl(r * pinch * (1.25 if i == 0 else 1.0), r * pinch * 0.92, seg_h, (x, y, z + seg_h / 2),
                  ROCK_BAND if i % 2 else ROCK_RED, segs=7)
            z += seg_h
        m.blob(r * 1.5, (x, y, h + r * 0.4), ROCK_CAP, subdiv=1, jitter=0.15, squash=0.5)
    m.blob(2.0, (1.0, -1.5, 0.3), ROCK_DARK, subdiv=1, jitter=0.25, squash=0.6)
    return m.finish()


def boulders():
    m = Model("boulders")
    for loc, r, mat in (((0, 0, 1.2), 2.4, ROCK_RED), ((2.6, 1.0, 0.8), 1.6, ROCK_DARK),
                        ((-2.0, 1.8, 0.6), 1.3, ROCK_BAND), ((0.8, -2.4, 0.5), 1.1, ROCK_DARK),
                        ((0.3, 0.4, 3.1), 1.2, ROCK_RED)):
        m.blob(r, loc, mat, subdiv=1, jitter=0.22, squash=0.75)
    return m.finish()


# ---------------------------------------------------------------- plants and scatter

def saguaro():
    """A saguaro with two arms. Scattered with random turns and sizes, and used as landmarks."""
    m = Model("saguaro")
    h = 6.8
    m.cyl(0.44, 0.38, h, (0, 0, h / 2), CACTUS, segs=8)
    m.cyl(0.38, 0.14, 0.45, (0, 0, h + 0.22), CACTUS, segs=8)
    for side, z0, out, up in ((-1, 2.8, 1.25, 2.6), (1, 3.7, 1.05, 2.1)):
        top = z0 + 0.25 + up
        m.beam((0, 0, z0), (side * out, 0, z0 + 0.25), 0.27, CACTUS, segs=7)
        m.cyl(0.29, 0.26, up + 0.1, (side * out, 0, z0 + 0.2 + up / 2), CACTUS, segs=7)
        m.cyl(0.26, 0.1, 0.3, (side * out, 0, top + 0.15), CACTUS, segs=7)
    return m.finish()


def scrub():
    """A low sage bush, scattered by the thousand."""
    m = Model("scrub")
    m.blob(0.55, (0, 0, 0.36), SCRUB, subdiv=2, jitter=0.22, squash=0.8)
    m.blob(0.38, (0.48, 0.2, 0.26), SCRUB_DRY, subdiv=1, jitter=0.3, squash=0.8)
    return m.finish()


def grass():
    """A tuft of dry bunchgrass. Each blade is a thin closed spike, so it shows from every side."""
    m = Model("grass")
    for _ in range(9):
        x, y = rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25)
        height = rng.uniform(0.45, 0.85)
        lx, ly = x * 1.8 + rng.uniform(-0.15, 0.15), y * 1.8 + rng.uniform(-0.15, 0.15)
        w = 0.04
        m.poly([(x - w, y, 0), (x + w, y, 0), (x, y + w, 0), (lx, ly, height)],
               [(0, 2, 1), (0, 1, 3), (1, 2, 3), (2, 0, 3)], GRASS)
    return m.finish()


def rocks():
    m = Model("rocks")
    m.blob(0.5, (0, 0, 0.16), ROCK_DARK, subdiv=1, jitter=0.3, squash=0.6)
    m.blob(0.28, (0.55, 0.3, 0.08), ROCK_RED, subdiv=1, jitter=0.3, squash=0.7)
    return m.finish()


# ---------------------------------------------------------------- roadside

def fence():
    """Weathered posts and three rusted strands, sagging between posts. One repeat long."""
    m = Model("fence")
    half = FENCE_LENGTH / 2
    for y in (-half, 0.0):
        m.box((0.13, 0.13, 1.4), (0, y, 0.62), WOOD_GREY,
              rot=(rng.uniform(-0.07, 0.07), rng.uniform(-0.06, 0.06), 0))
    for z in (0.42, 0.8, 1.16):
        for y0 in (-half, 0.0):
            prev = None
            for i in range(5):
                p = i / 4
                cur = (0.08, y0 + p * half, z - 0.07 * 4 * p * (1 - p))
                if prev:
                    m.beam(prev, cur, 0.013, RUST, segs=3)
                prev = cur
    return m.finish()


def powerline():
    """An H-frame wooden power line, wires reaching exactly to the next frame so repeats join up."""
    m = Model("powerline")
    top = 11.5
    for x in (-2.1, 2.1):
        m.cyl(0.21, 0.15, top, (x, 0, top / 2), WOOD, segs=7)
    m.box((6.6, 0.24, 0.28), (0, 0, top - 1.0), WOOD)
    m.beam((-2.1, 0, top - 1.4), (2.1, 0, top - 4.8), 0.07, WOOD, segs=4)
    m.beam((2.1, 0, top - 1.4), (-2.1, 0, top - 4.8), 0.07, WOOD, segs=4)
    for x in (-3.0, 0.0, 3.0):
        m.cyl(0.09, 0.07, 0.45, (x, 0, top - 0.64), INSULATOR, segs=6)
        prev = None
        n = 10
        for i in range(n + 1):
            p = i / n
            cur = (x, p * LINE_SPACING, top - 0.42 - 1.8 * 4 * p * (1 - p))
            if prev:
                m.beam(prev, cur, 0.024, WIRE, segs=4)
            prev = cur
    return m.finish()


def motel():
    """A one-storey roadside motel, doors to the road, with a tall neon blade sign out front."""
    m = Model("motel")
    d, l, h = 4.0, 11.0, 3.2
    m.box((d * 2, l * 2, h), (0, 0, h / 2), STUCCO)
    m.box((d * 2 + 0.3, l * 2 + 0.3, 0.5), (0, 0, h + 0.2), TURQUOISE)
    m.box((2.4, l * 2, 0.16), (-d - 1.2, 0, 2.9), TURQUOISE)
    for y in range(-10, 11, 4):
        m.box((0.14, 0.14, 2.85), (-d - 2.2, y, 1.42), STUCCO)
    for i, y in enumerate(range(-9, 10, 3)):
        m.box((0.1, 0.9, 2.0), (-d - 0.03, y, 1.0), TURQUOISE)
        lit = i in (0, 2, 3, 6)
        m.box((0.1, 1.0, 0.8), (-d - 0.03, y + 1.15, 1.6), WINDOW if lit else WINDOW_DIM)
    # The office at the near end, its window always lit.
    m.box((5.0, 4.0, 3.6), (-0.5, -l - 2.0, 1.8), STUCCO)
    m.box((5.3, 4.3, 0.4), (-0.5, -l - 2.0, 3.7), TURQUOISE)
    m.box((0.1, 2.6, 1.4), (-3.03, -l - 2.0, 1.7), WINDOW)
    # The sign: a pole by the road, a vertical MOTEL blade and a VACANCY box under it.
    # The pole stops under the blade and is thinner than the panels, so it never shows through the letters.
    sx, sy = -d - 5.5, -l - 3.0
    m.cyl(0.13, 0.12, 6.3, (sx, sy, 3.15), STEEL, segs=8)
    sign_panel(m, "MOTEL", (sx, sy, 10.6), (2.1, 0.32, 9.0), 0.36, NEON_RED, NEON_AMBER, vertical=True)
    sign_panel(m, "VACANCY", (sx, sy, 4.9), (5.0, 0.28, 1.5), 0.17, NEON_GREEN, NEON_AMBER)
    m.box((0.5, 0.5, 0.4), (sx, sy, 15.3), NEON_AMBER)
    return m.finish()


def gas_station():
    """A canopy over two pump islands, a little shop behind it, and a GAS sign on a pole."""
    m = Model("gas_station")
    cw, cl, cz = 4.6, 7.0, 5.6
    m.box((cw * 2, cl * 2, 0.9), (0, 0, cz + 0.45), CANOPY)
    m.box((cw * 2 + 0.08, cl * 2 + 0.08, 0.3), (0, 0, cz + 0.5), NEON_RED)
    for x in (-2.6, 0.0, 2.6):
        for y in (-4.8, -1.6, 1.6, 4.8):
            m.box((1.3, 0.7, 0.06), (x, y, cz - 0.02), CANOPY_LIGHT)
    for y in (-3.8, 3.8):
        m.box((0.5, 0.5, cz), (0, y, cz / 2), CANOPY)
        m.box((1.1, 3.4, 0.25), (0, y, 0.12), CANOPY)
        for dy in (-1.1, 1.1):
            m.box((0.6, 0.7, 1.7), (0, y + dy, 1.1), PUMP)
            m.box((0.64, 0.5, 0.3), (0, y + dy, 1.62), WINDOW)
    m.box((5.0, 9.0, 3.2), (cw + 4.2, 0, 1.6), STUCCO)
    m.box((5.4, 9.4, 0.35), (cw + 4.2, 0, 3.35), PUMP)
    m.box((0.1, 5.6, 1.6), (cw + 1.67, -0.8, 1.5), WINDOW)
    m.box((0.1, 1.1, 2.2), (cw + 1.67, 3.0, 1.1), PANEL)
    sx, sy = -cw - 3.2, -cl - 2.5
    m.cyl(0.12, 0.11, 7.4, (sx, sy, 3.7), STEEL, segs=8)
    sign_panel(m, "GAS", (sx, sy, 8.2), (3.6, 0.3, 1.9), 0.3, NEON_RED, NEON_AMBER)
    sign_panel(m, "EAT", (sx, sy, 5.9), (2.6, 0.26, 1.3), 0.2, NEON_AMBER, NEON_RED)
    return m.finish()


def water_tank():
    """A rusted tank on a timber stand, with a windmill pump beside it, its wheel facing traffic."""
    m = Model("water_tank")
    for x in (-1.8, 1.8):
        for y in (-1.8, 1.8):
            m.box((0.32, 0.32, 4.0), (x, y, 2.0), WOOD)
    m.beam((-1.8, -1.8, 0.3), (1.8, -1.8, 3.6), 0.07, WOOD, segs=4)
    m.beam((1.8, 1.8, 0.3), (-1.8, 1.8, 3.6), 0.07, WOOD, segs=4)
    m.box((4.4, 4.4, 0.3), (0, 0, 4.1), WOOD)
    m.cyl(2.5, 2.5, 3.4, (0, 0, 5.95), RUST, segs=16)
    for z in (4.8, 5.95, 7.1):
        m.cyl(2.56, 2.56, 0.12, (0, 0, z), RUST_DARK, segs=16)
    m.cyl(2.62, 0.35, 0.9, (0, 0, 8.1), RUST_DARK, segs=16)
    wx, wy, top = 1.0, 6.0, 11.0
    legs = [(-1.4, -1.4), (1.4, -1.4), (1.4, 1.4), (-1.4, 1.4)]
    for lx, ly in legs:
        m.beam((wx + lx, wy + ly, 0), (wx + lx * 0.18, wy + ly * 0.18, top), 0.07, STEEL, segs=4)
    for z, f in ((3.5, 0.72), (7.0, 0.45)):
        for i, (lx, ly) in enumerate(legs):
            nx, ny = legs[(i + 1) % 4]
            m.beam((wx + lx * f, wy + ly * f, z), (wx + nx * f, wy + ny * f, z), 0.04, STEEL, segs=3)
    m.box((0.5, 1.6, 0.5), (wx, wy, top + 0.3), RUST_DARK)
    hub = (wx, wy - 0.9, top + 0.4)
    m.cyl(0.3, 0.3, 0.3, hub, RUST_DARK, segs=8, rot=(math.radians(90), 0, 0))
    for k in range(14):
        a = 2 * math.pi * k / 14
        m.box((1.7, 0.05, 0.36), (hub[0] + math.cos(a) * 1.35, hub[1], hub[2] + math.sin(a) * 1.35),
              STEEL, rot=(0, -a, 0))
    m.box((0.06, 3.0, 1.0), (wx, wy + 2.2, top + 0.5), RUST)
    return m.finish()


# ---------------------------------------------------------------- the player's car

def hood():
    """The player's muscle car, seen from the driver's seat, behind the keyboard. Same footprint as
    the Backroads truck: half-width 8, running toward -Y about 9.6, top from 0 to 0.95."""
    m = Model("hood")
    w = 8.0
    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], PAINT)

    def surface(y):
        return 0.95 * (0.2 - y) / 9.2

    # Twin racing stripes either side of the scoop: thin boxes tilted to the hood's slope, so their
    # normals face up (a lone quad's normal can come out flipped and be culled).
    slope = -math.atan(0.95 / 9.2)
    for cx in (-2.3, 2.3):
        m.box((0.84, 9.2, 0.03), (cx, -4.405, surface(-4.405) + 0.012), STRIPE, rot=(slope, 0, 0))
    # The scoop: a closed wedge, kept low and set back so it never stands in front of the keys.
    yf, yr, rise = -1.3, -5.4, 0.36
    zf, zr = surface(yf), surface(yr)
    verts = [(-1.45, yf, zf), (1.45, yf, zf), (1.3, yf, zf + rise), (-1.3, yf, zf + rise),
             (-1.15, yr, zr + 0.01), (1.15, yr, zr + 0.01)]
    m.poly(verts, [(3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 1, 2, 3), (0, 4, 5, 1)], SCOOP)
    m.box((2.75, 0.12, 0.08), (0, yf, zf + rise + 0.02), CHROME)
    for side in (-1, 1):
        m.beam((side * 1.38, yf, zf + rise * 0.5), (side * 1.17, yr, zr + 0.02), 0.04, CHROME, segs=4)
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.5), (x, -4.5, -0.25), PAINT)
        # Quad headlamps: chrome cups, glowing lamps, and a glowing brow along the fender's front edge.
        for lx in (x - 0.48, x + 0.48):
            m.cyl(0.44, 0.48, 0.3, (lx, 0.42, 0.0), CHROME, segs=16, rot=(math.radians(90), 0, 0))
            m.cyl(0.36, 0.36, 0.32, (lx, 0.48, 0.0), LAMP, segs=16, rot=(math.radians(90), 0, 0))
            m.box((0.78, 0.16, 0.05), (lx, 0.38, 0.52), BEZEL)
        m.box((0.08, 9.0, 0.06), (side * (w - 0.05), -4.5, 0.5), CHROME)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), CHROME)
    return m.finish()


export_all([mesa, butte, hoodoos, boulders, saguaro, scrub, grass, rocks, fence, powerline, motel, gas_station,
            water_tank, hood], OUT_DIR, PREVIEW)
