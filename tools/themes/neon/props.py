"""Neon Sprawl props: an elevated freeway through a rain-soaked megacity.

Megatowers with emissive window strips, holographic billboards on monopoles, a
vertical holo pylon, distant skyline blocks, the freeway deck with its piers,
jersey barriers with an LED rail, streetlamps, an overhead sign gantry, a
scatter of city lights for the streets far below, and the player's car hood.

Towers, billboards, pylons and skyline blocks are rooted 40 units below the
deck, because the world script drops the ground away to make the road an
elevated freeway. Signs and billboards carry abstract graphics only: no text,
brands or logos.

Run: blender --background --python tools/themes/neon/props.py -- game/assets/themes/neon/models [preview.png]
"""
import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset  # noqa: E402

LAMP_SPACING = 20.0  # must match LAMP_SPACING in game/scripts/themes/neon.gd
BARRIER_LENGTH = 5.0  # must match BARRIER_LENGTH in game/scripts/themes/neon.gd
DECK_LENGTH = 30.0  # must match DECK_LENGTH in game/scripts/themes/neon.gd
GANTRY_HALF = 11.6  # leg offset for a road half-width of 8.4 (clear of the lamps); the world script scales x
BELOW = -40.0  # how far city props reach down, past the dropped ground
OUT_DIR, PREVIEW = args()
reset()

CONCRETE = material("concrete", (0.085, 0.085, 0.10), rough=0.55)
CONCRETE_DARK = material("concrete_dark", (0.045, 0.045, 0.06), rough=0.7)
GLASS = material("glass", (0.018, 0.02, 0.04), rough=0.18, metal=0.7)
STEEL = material("steel", (0.13, 0.13, 0.16), rough=0.35, metal=0.85)
PAINT = material("paint", (0.024, 0.02, 0.04), rough=0.14, metal=0.55)
TRIM = material("trim", (0.05, 0.05, 0.07), rough=0.25, metal=0.9)
# Emissive palette. Strength is HDR: above 1.0 it blooms through the glow pass.
BAND = material("band", (0.18, 0.25, 0.7), emit=(0.22, 0.32, 0.95), strength=0.9)
PINK = material("neon_pink", (1.0, 0.12, 0.62), emit=(1.0, 0.1, 0.6), strength=6.0)
CYAN = material("neon_cyan", (0.12, 0.85, 1.0), emit=(0.1, 0.82, 1.0), strength=4.0)
VIOLET = material("neon_violet", (0.55, 0.22, 1.0), emit=(0.55, 0.2, 1.0), strength=5.0)
WARM = material("window_warm", (1.0, 0.6, 0.4), emit=(1.0, 0.55, 0.35), strength=2.6)
COOL = material("window_cool", (0.6, 0.75, 1.0), emit=(0.55, 0.72, 1.0), strength=2.2)
BEACON = material("beacon", (1.0, 0.1, 0.12), emit=(1.0, 0.08, 0.1), strength=9.0)
LAMP = material("lamp", (1.0, 0.82, 0.95), emit=(1.0, 0.8, 0.95), strength=5.0)
HEADLAMP = material("headlamp", (0.85, 0.92, 1.0), emit=(0.85, 0.92, 1.0), strength=6.0)
BEZEL = material("bezel", (0.55, 0.22, 1.0), emit=(0.55, 0.2, 1.0), strength=2.2)
UNDERGLOW = material("underglow", (1.0, 0.1, 0.7), emit=(1.0, 0.08, 0.68), strength=3.5)
FENDER_LINE = material("fender_line", (0.6, 0.25, 1.0), emit=(0.55, 0.22, 1.0), strength=3.0)
RAIL = material("rail", (1.0, 0.2, 0.7), emit=(1.0, 0.18, 0.68), strength=2.6)
# Billboard faces are named holo_* so the world script can find and flicker them.
HOLO_BG = material("holo_bg", (0.22, 0.04, 0.4), emit=(0.26, 0.04, 0.46), strength=2.2)
HOLO_SUN = material("holo_sun", (1.0, 0.55, 0.35), emit=(1.0, 0.5, 0.3), strength=4.5)
HOLO_SUN_LOW = material("holo_sun_low", (1.0, 0.15, 0.55), emit=(1.0, 0.12, 0.55), strength=4.5)
HOLO_GRID = material("holo_grid", (0.15, 0.85, 1.0), emit=(0.15, 0.85, 1.0), strength=3.5)
HOLO_GLYPH = material("holo_glyph", (0.3, 0.95, 1.0), emit=(0.3, 0.95, 1.0), strength=3.2)
SIGN_FACE = material("sign_face", (0.02, 0.05, 0.08), rough=0.4)
SIGN_MARK = material("sign_mark", (0.85, 0.9, 1.0), emit=(0.8, 0.88, 1.0), strength=1.6)


def _windows(m, r, w, d, z0, z1, count, mats):
    """Lit window patches flush on all four faces of a w x d (half sizes) block."""
    for _ in range(count):
        face = r.randrange(4)
        z = r.uniform(z0, z1)
        size_a, size_z = r.uniform(0.8, 2.6), r.uniform(0.5, 1.4)
        mat = r.choice(mats)
        if face == 0:
            m.box((0.1, size_a, size_z), (-w - 0.03, r.uniform(-d + 1, d - 1), z), mat)
        elif face == 1:
            m.box((0.1, size_a, size_z), (w + 0.03, r.uniform(-d + 1, d - 1), z), mat)
        elif face == 2:
            m.box((size_a, 0.1, size_z), (r.uniform(-w + 1, w - 1), -d - 0.03, z), mat)
        else:
            m.box((size_a, 0.1, size_z), (r.uniform(-w + 1, w - 1), d + 0.03, z), mat)


def _block(m, w, d, z0, z1, mat=GLASS):
    m.box((w * 2, d * 2, z1 - z0), (0, 0, (z0 + z1) / 2), mat)


def _bands(m, w, d, z0, z1, step, accent_every, accent, dim=BAND, offset=(0.0, 0.0)):
    """Floor bands: one box a hair wider than the block wraps all four faces at once."""
    i = 0
    z = z0
    while z < z1:
        mat = accent if accent_every and i % accent_every == 0 else dim
        m.box((w * 2 + 0.14, d * 2 + 0.14, 0.24), (offset[0], offset[1], z), mat)
        z += step
        i += 1


def tower_a():
    """Square megatower: dim floor bands, magenta accents, cyan corner lines, a crown and a beacon."""
    m = Model("tower_a")
    r = random.Random(11)
    w = d = 6.0
    top = 72.0
    _block(m, w, d, BELOW, top)
    _bands(m, w, d, 2.0, top - 1.0, 3.0, 4, PINK)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.34, 0.34, top - 2.0), (sx * w, sy * d, (top + 2.0) / 2), CYAN)
    _windows(m, r, w, d, 3.0, top - 3.0, 26, [WARM, COOL, WARM])
    _block(m, 4.4, 4.4, top, top + 9.0)
    m.box((9.0, 9.0, 0.3), (0, 0, top + 9.0), PINK)
    m.cyl(0.25, 0.12, 14.0, (0, 0, top + 16.0), STEEL, segs=6)
    m.box((0.6, 0.6, 0.6), (0, 0, top + 23.2), BEACON)
    return m.finish()


def tower_b():
    """Stepped tower in three tiers, with a vertical holo banner on its road face."""
    m = Model("tower_b")
    r = random.Random(23)
    tiers = [(8.0, 7.0, BELOW, 30.0), (6.0, 5.2, 30.0, 56.0), (3.8, 3.8, 56.0, 82.0)]
    for i, (w, d, z0, z1) in enumerate(tiers):
        _block(m, w, d, z0, z1)
        _bands(m, w, d, max(z0, 1.5) + 1.0, z1 - 0.5, 2.6 if i == 0 else 3.4, 3, VIOLET)
        m.box((w * 2 + 0.6, d * 2 + 0.6, 0.35), (0, 0, z1), PINK if i < 2 else CYAN)
        _windows(m, r, w, d, max(z0, 2.0) + 1.0, z1 - 1.0, 9, [WARM, COOL])
    # Banner: a tall violet screen of abstract glyph blocks (no lettering) on the -X face.
    m.box((0.2, 4.4, 22.0), (-8.15, 0, 16.0), HOLO_BG)
    for k in range(13):
        z = 6.0 + k * 1.6
        for j in range(r.randint(1, 3)):
            m.box((0.12, r.uniform(0.6, 1.4), 0.9), (-8.3, r.uniform(-1.4, 1.4), z), HOLO_GLYPH)
    m.cyl(0.18, 0.1, 10.0, (2.0, 1.0, 87.0), STEEL, segs=6)
    m.box((0.5, 0.5, 0.5), (2.0, 1.0, 92.2), BEACON)
    return m.finish()


def tower_c():
    """Slim needle tower with paired violet stripes on every face and a slanted crown."""
    m = Model("tower_c")
    r = random.Random(37)
    w, d, top = 4.5, 4.5, 92.0
    _block(m, w, d, BELOW, top)
    for s in (-1.6, 1.6):
        m.box((0.2, 0.3, top - 4.0), (-w - 0.05, s, top / 2), VIOLET)
        m.box((0.2, 0.3, top - 4.0), (w + 0.05, s, top / 2), VIOLET)
        m.box((0.3, 0.2, top - 4.0), (s, -d - 0.05, top / 2), VIOLET)
        m.box((0.3, 0.2, top - 4.0), (s, d + 0.05, top / 2), VIOLET)
    _bands(m, w, d, 4.0, top - 2.0, 7.0, 2, CYAN)
    _windows(m, r, w, d, 3.0, top - 4.0, 18, [WARM, COOL, COOL])
    crown = [(-w, -d, top), (w, -d, top), (w, d, top), (-w, d, top), (-w, -d, top + 3.0), (w, -d, top + 9.0),
             (w, d, top + 9.0), (-w, d, top + 3.0)]
    m.poly(crown, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)], GLASS)
    m.beam((-w, -d - 0.05, top + 3.0), (w, -d - 0.05, top + 9.0), 0.16, PINK, segs=4)
    m.beam((-w, d + 0.05, top + 3.0), (w, d + 0.05, top + 9.0), 0.16, PINK, segs=4)
    m.box((0.6, 0.6, 0.6), (w - 0.4, 0, top + 9.5), BEACON)
    return m.finish()


def block():
    """A cluster of lower blocks for the distant skyline: dim bands, a few accents."""
    m = Model("block")
    r = random.Random(53)
    for _ in range(6):
        w, d = r.uniform(4.0, 9.0), r.uniform(4.0, 9.0)
        x, y = r.uniform(-14.0, 14.0), r.uniform(-14.0, 14.0)
        top = r.uniform(18.0, 52.0)
        m.box((w * 2, d * 2, top - BELOW), (x, y, (top + BELOW) / 2), GLASS)
        _bands(m, w, d, 3.0, top - 1.0, r.choice([3.0, 4.0, 5.0]), r.choice([0, 3, 5]),
               r.choice([PINK, CYAN, VIOLET]), offset=(x, y))
    return m.finish()


def billboard():
    """A holographic billboard on a monopole: a sliced synthwave sun over a perspective grid.
    The face is on -X; the world script yaws it toward the road and the oncoming driver."""
    m = Model("billboard")
    zc, half_y, half_z = 14.0, 5.6, 3.2
    m.cyl(0.55, 0.42, 14.0 - BELOW - half_z, (0.6, 0, (BELOW + zc - half_z) / 2), STEEL, segs=8)
    m.box((0.5, half_y * 2 + 0.6, half_z * 2 + 0.6), (0.25, 0, zc), TRIM)
    m.box((0.1, half_y * 2, half_z * 2), (-0.05, 0, zc), HOLO_BG)
    # Sun: horizontal slices of a circle, the lower ones thinner, as in the genre's posters.
    sun_r, sun_z = 2.3, zc + 0.6
    z = sun_z + sun_r - 0.2
    while z > sun_z - 0.4:
        dz = z - sun_z
        width = 2.0 * math.sqrt(max(sun_r * sun_r - dz * dz, 0.0))
        thick = 0.42 if dz > 0.4 else 0.26
        m.box((0.08, width, thick), (-0.12, 0, z), HOLO_SUN if dz > 0.6 else HOLO_SUN_LOW)
        z -= thick + (0.08 if dz > 0.4 else 0.16)
    # Grid: horizon line, receding rows and converging columns.
    floor = sun_z - 0.55
    m.box((0.08, half_y * 2 - 0.4, 0.09), (-0.13, 0, floor), HOLO_GRID)
    for gz in (floor - 0.45, floor - 1.05, floor - 1.9):
        m.box((0.08, half_y * 2 - 0.4, 0.07), (-0.13, 0, gz), HOLO_GRID)
    for i in range(-3, 4):
        top_y, low_y = i * 0.5, i * 1.55
        a, b = (-0.13, top_y, floor), (-0.13, low_y, zc - half_z + 0.25)
        m.beam(a, b, 0.04, HOLO_GRID, segs=4)
    return m.finish()


def pylon():
    """A free-standing vertical holo screen: glyph blocks scroll down a violet panel."""
    m = Model("pylon")
    r = random.Random(71)
    m.box((1.2, 1.2, 24.0 - BELOW), (0.6, 0, (24.0 + BELOW) / 2), STEEL)
    m.box((0.4, 4.0, 15.4), (0.0, 0, 15.0), TRIM)
    m.box((0.1, 3.4, 14.6), (-0.22, 0, 15.0), HOLO_BG)
    for k in range(11):
        z = 8.6 + k * 1.25
        y = -1.2
        while y < 1.2:
            w = r.uniform(0.3, 0.8)
            if r.random() < 0.7:
                m.box((0.06, w, 0.7), (-0.3, y + w / 2, z), HOLO_GLYPH if r.random() < 0.75 else HOLO_SUN_LOW)
            y += w + 0.2
    m.box((0.12, 4.2, 0.18), (-0.25, 0, 22.8), PINK)
    m.box((0.12, 4.2, 0.18), (-0.25, 0, 7.2), PINK)
    return m.finish()


def deck():
    """One span of the freeway deck beside the road: shoulder slab, LED edge, pier below.
    Origin at the road edge; it reaches outward along +X (the side away from the road)."""
    m = Model("deck")
    m.box((5.2, DECK_LENGTH, 2.4), (2.6, 0, -1.25), CONCRETE_DARK)
    m.box((0.1, DECK_LENGTH, 0.08), (5.15, 0, -0.02), VIOLET)
    m.box((2.2, 2.2, -2.4 - BELOW), (2.6, 0, (BELOW - 2.4) / 2), CONCRETE_DARK)
    m.box((5.0, 3.2, 1.0), (2.6, 0, -2.9), CONCRETE_DARK)
    # A drain lip on the deck's outer edge reads as a second rail of light from far off.
    m.box((0.3, DECK_LENGTH, 0.3), (5.0, 0, 0.1), CONCRETE)
    return m.finish()


def barrier():
    """One jersey barrier, exactly BARRIER_LENGTH long, road face on -X, LED rail on top."""
    m = Model("barrier")
    half = BARRIER_LENGTH / 2
    prof = [(-0.4, 0.0), (-0.4, 0.08), (-0.26, 0.3), (-0.13, 1.0), (0.13, 1.0), (0.26, 0.3), (0.4, 0.08), (0.4, 0.0)]
    verts = [(x, -half, z) for x, z in prof] + [(x, half, z) for x, z in prof]
    n = len(prof)
    faces = [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    faces += [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    m.poly(verts, faces, CONCRETE)
    m.box((0.14, BARRIER_LENGTH, 0.07), (0, 0, 1.03), RAIL)
    m.box((0.08, 0.08, 0.5), (0.0, 0, 1.3), STEEL)
    m.box((0.1, BARRIER_LENGTH, 0.1), (0.0, 0, 1.56), STEEL)
    m.box((0.06, 0.32, 0.12), (-0.27, 0, 0.66), CYAN, rot=(0, math.radians(-12), 0))
    return m.finish()


def lamp():
    """A freeway streetlamp: pole on the deck, short arm reaching toward the road (-X)."""
    m = Model("lamp")
    top = 10.6
    m.box((0.6, 0.6, 0.5), (0, 0, 0.25), CONCRETE)
    m.cyl(0.17, 0.11, top, (0, 0, top / 2), STEEL, segs=8)
    m.box((0.26, 0.26, 0.6), (0, 0, 3.0), VIOLET)
    m.beam((0.0, 0, top - 0.4), (-2.3, 0, top + 0.15), 0.08, STEEL, segs=5)
    m.box((1.5, 0.5, 0.2), (-2.45, 0, top + 0.12), TRIM)
    m.box((1.3, 0.36, 0.06), (-2.45, 0, top - 0.0), LAMP)
    return m.finish()


def gantry():
    """An overhead sign gantry, legs on the deck outside the barriers. Its signs hang well above
    the camera (8.8), so it only ever crosses the sky, never the notes. Built for road half 8.4."""
    m = Model("gantry")
    leg = GANTRY_HALF
    for sx in (-1, 1):
        m.box((0.9, 0.9, 0.6), (sx * leg, 0, 0.3), CONCRETE)
        m.box((0.55, 0.55, 13.8), (sx * leg, 0, 6.9), STEEL)
        m.box((0.2, 0.2, 2.4), (sx * leg - sx * 0.3, -0.3, 1.6), PINK)
    for z in (12.0, 13.6):
        m.box((leg * 2 + 0.6, 0.45, 0.45), (0, 0, z), STEEL)
    x = -leg + 1.2
    flip = 1
    while x < leg - 1.0:
        m.beam((x, 0, 12.0), (x + 1.8, 0, 13.6) if flip > 0 else (x + 1.8, 0, 12.0), 0.06, STEEL, segs=4)
        m.beam((x + 1.8, 0, 12.0), (x + 1.8, 0, 13.6), 0.05, STEEL, segs=4)
        x += 1.8
        flip = -flip
    # Two signs facing the driver (-Y), bottoms at 9.9: a lane chevron and abstract bars, no text.
    for sx, kind in ((-4.6, "arrow"), (4.6, "bars")):
        m.box((6.4, 0.2, 2.2), (sx, -0.3, 11.0), SIGN_FACE)
        m.box((6.6, 0.12, 0.08), (sx, -0.42, 12.12), CYAN)
        m.box((6.6, 0.12, 0.08), (sx, -0.42, 9.88), CYAN)
        if kind == "arrow":
            for side in (-1, 1):
                m.box((0.16, 0.08, 1.3), (sx + side * 0.42, -0.44, 11.0),
                      SIGN_MARK, rot=(0, math.radians(side * 38), 0))
            m.box((0.16, 0.08, 1.2), (sx - 1.9, -0.44, 11.0), PINK)
            m.box((0.16, 0.08, 1.2), (sx + 1.9, -0.44, 11.0), PINK)
        else:
            for k, (bw, bz) in enumerate(((4.6, 11.55), (3.2, 11.05), (4.0, 10.55))):
                m.box((bw, 0.08, 0.22), (sx - (4.6 - bw) / 2, -0.44, bz), SIGN_MARK if k != 1 else PINK)
    return m.finish()


def citylight():
    """A loose handful of pinpoint lights for the streets far below (Godot scatters these with a
    MultiMesh). Tiny and spread out, so from the deck they read as points, not confetti."""
    m = Model("citylight")
    r = random.Random(89)
    for _ in range(6):
        s = r.uniform(0.12, 0.26)
        m.box((s, s * r.uniform(1.0, 2.5), s), (r.uniform(-6.0, 6.0), r.uniform(-6.0, 6.0), 0.2),
              r.choice([WARM, PINK, COOL, COOL, VIOLET]))
    return m.finish()


def hood():
    """The player's car, seen from the driver's seat, behind the keyboard.
    Same footprint as the Backroads truck; dark gloss paint, a magenta underglow lip,
    slim LED lamps in glowing bezels at the front corners."""
    m = Model("hood")
    w = 8.0
    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], PAINT)
    # Underglow lip: where the hood rises out of the road (about y = -1.7), just below the keys.
    lip_y = -1.85
    lip_z = 0.95 * (0.2 - lip_y) / 9.2 + 0.03
    m.box((w * 2 - 0.6, 0.16, 0.05), (0, lip_y, lip_z), UNDERGLOW, rot=(-math.atan(0.95 / 9.2), 0, 0))
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.4), (x, -4.5, -0.3), PAINT)
        m.box((1.95, 9.6, 0.08), (x, -4.5, 0.42), TRIM)
        # A violet line along each fender's inner top edge, so the dark car still reads.
        m.box((0.1, 9.0, 0.07), (x - side * 0.9, -4.8, 0.46), FENDER_LINE)
        # Lamp: a wide slim LED bar inside a violet bezel, plus a cyan running light. It sits high
        # enough to clear the road plane (the hood's nose is sunk just below it).
        lz = 0.3
        m.box((1.85, 0.26, 0.62), (x, 0.32, lz), TRIM)
        m.box((1.95, 0.2, 0.72), (x, 0.26, lz), BEZEL)
        m.box((1.55, 0.3, 0.3), (x, 0.4, lz + 0.05), HEADLAMP)
        m.box((0.14, 0.3, 0.62), (x - side * 0.95, 0.38, lz), CYAN)
        m.box((1.9, 0.12, 0.06), (x, -1.0, -1.02), UNDERGLOW)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), PAINT)
    m.box((w * 2 + 3.6, 0.1, 0.06), (0, 0.78, -1.34), UNDERGLOW)
    return m.finish()


export_all([tower_a, tower_b, tower_c, block, billboard, pylon, deck, barrier, lamp, gantry, citylight, hood],
           OUT_DIR, PREVIEW)
