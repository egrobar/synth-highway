"""Neon Sprawl props: an elevated freeway through a rain-soaked megacity.

Megatowers with curtain walls (mullions, spandrels, corner piers, setbacks, lit window runs) and
rooftop plant (HVAC units, water tanks, dishes, lattice masts with aircraft lights, a window-
cleaning crane); a cluster of older blocks for the skyline with balconies, fire escapes, window
AC units, a blade sign and roof tanks; holographic billboards on bolted monopoles with a catwalk,
lamp arms, a caged ladder and back framing; a vertical holo pylon; the freeway deck with an
expansion joint, scuppers, a gutter, a cable tray and an edge parapet with a handrail; jersey
barriers in two precast segments with bolted joint plates and an LED rail; streetlamps with LED
heads; an overhead sign gantry with a box truss, caged ladder, catwalk and sign lights; a scatter
of city lights for the streets far below; and the player's car hood.

High detail (2026-11-10): every model is a Part, which bevels only the primitives that ask for it
(massing, frames, housings) and leaves fine detail (mullions, rungs, bolts, slats) as plain boxes,
flat-shaded through sharp edges. propkit.detail() alone would bevel every edge sharper than 35
degrees, about 100 triangles a box, which would put a tower's facade grid far over budget.
Material names pick the shared surface maps (ThemeWorld.SURFACE_KEYWORDS): concrete -> poured
concrete, steel -> brushed metal, panel -> riveted plating, grate -> walkway grating; tower glass
gets none (the world script's `surfaces`). Emissive materials stay emissive and are never weathered.

Towers, billboards, pylons and skyline blocks are rooted 40 units below the deck, because the world
script drops the ground away to make the road an elevated freeway; their facade detail starts at
FACADE_FROM, below which the street mist hides everything. Signs and billboards carry abstract
graphics only: no text, brands or logos.

Run: blender --background --python tools/themes/neon/props.py -- game/assets/themes/neon/models [preview.png]
"""
import math
import pathlib
import random
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset  # noqa: E402

LAMP_SPACING = 20.0  # must match LAMP_SPACING in game/scripts/themes/neon.gd
BARRIER_LENGTH = 10.0  # two precast segments; must match BARRIER_LENGTH in game/scripts/themes/neon.gd
DECK_LENGTH = 30.0  # must match DECK_LENGTH in game/scripts/themes/neon.gd
GANTRY_HALF = 11.6  # leg offset for a road half-width of 8.4 (clear of the lamps); the world script scales x
BELOW = -40.0  # how far city props reach down, past the dropped ground
FACADE_FROM = -14.0  # facades are detailed from here up; the street mist (fog height -12) hides the rest
OUT_DIR, PREVIEW = args()
reset()

# Structure. Names pick the surface maps (see the module docstring).
CONCRETE = material("concrete", (0.085, 0.085, 0.10), rough=0.55)
CONCRETE_DARK = material("concrete_dark", (0.045, 0.045, 0.06), rough=0.7)
BLOCK_WALL = material("concrete_block", (0.075, 0.066, 0.085), rough=0.75)
GLASS = material("glass", (0.018, 0.02, 0.04), rough=0.18, metal=0.7)
CLAD = material("panel_clad", (0.045, 0.045, 0.06), rough=0.38, metal=0.65)
STEEL = material("steel", (0.13, 0.13, 0.16), rough=0.35, metal=0.85)
GRATE = material("grate_walkway", (0.1, 0.1, 0.115), rough=0.45, metal=0.8)
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


class Part(Model):
    """A Model that bevels only the primitives built with bevel=True.

    Each bevelled primitive's edges get a bevel weight; at finish() the prop gets its own
    weight-limited bevel (`width` metres, two segments, hardened normals) and propkit's
    all-edges bevel is switched off (obj["bevel"] = 0). Every edge sharper than 35 degrees is
    marked sharp, so the unbevelled detail still shades flat under propkit's weighted normals,
    and cylinders of 12+ segments stay smooth. width=0 makes a prop with no bevel at all."""

    def __init__(self, name, width=0.03):
        super().__init__(name)
        self.width = width
        self.weight = self.bm.edges.layers.float.new("bevel_weight_edge")

    def _mark(self, start, bevel):
        if not bevel:
            return
        self.bm.verts.ensure_lookup_table()
        for i in range(start, len(self.bm.verts)):
            for e in self.bm.verts[i].link_edges:
                e[self.weight] = 1.0

    def box(self, size, loc, mat, rot=(0, 0, 0), bevel=True):
        start = len(self.bm.verts)
        super().box(size, loc, mat, rot)
        self._mark(start, bevel)

    def cyl(self, r1, r2, h, loc, mat, segs=12, rot=(0, 0, 0), bevel=True):
        start = len(self.bm.verts)
        super().cyl(r1, r2, h, loc, mat, segs=segs, rot=rot)
        self._mark(start, bevel)

    def beam(self, a, b, r, mat, segs=6, bevel=False):
        a, b = Vector(a), Vector(b)
        rot = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_euler()
        self.cyl(r, r, (b - a).length, (a + b) / 2, mat, segs=segs, rot=rot, bevel=bevel)

    def poly(self, verts, faces, mat, bevel=True):
        start = len(self.bm.verts)
        super().poly(verts, faces, mat)
        self._mark(start, bevel)

    def finish(self):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        crease = math.radians(35.0)
        for e in bm.edges:
            sharp = len(e.link_faces) != 2 or e.calc_face_angle(0.0) > crease
            e.smooth = not sharp
            if not sharp:
                e[self.weight] = 0.0  # a smooth edge (round cylinder sides) is never bevelled
        obj = super().finish()
        obj["bevel"] = 0
        if self.width > 0.0:
            bevel = obj.modifiers.new("bevel", "BEVEL")
            bevel.width = self.width
            bevel.segments = 2
            bevel.limit_method = "WEIGHT"
            bevel.use_clamp_overlap = True
            bevel.harden_normals = True
        return obj


# ---------------------------------------------------------------- small hardware


def bolt(m, loc, normal, mat=STEEL, r=0.03, h=0.05):
    """A hex bolt head standing out along `normal`."""
    rot = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_euler()
    m.cyl(r, r, h, loc, mat, segs=6, rot=rot, bevel=False)


def ladder(m, base, z0, z1, along, out, mat, width=0.44, rung=0.32, cage_from=None):
    """A fixed ladder at base (x, y): stiles either side along the unit axis `along`, rungs every
    `rung`, and from `cage_from` up a safety cage of hoops reaching 0.72 m out along `out`."""
    bx, by = base
    ax, ay = along
    ox, oy = out

    def size(a_len, o_len, h):
        return (a_len * abs(ax) + o_len * abs(ox), a_len * abs(ay) + o_len * abs(oy), h)

    for s in (-1, 1):
        m.box(size(0.06, 0.07, z1 - z0), (bx + s * ax * width / 2, by + s * ay * width / 2, (z0 + z1) / 2), mat,
              bevel=False)
    z = z0 + rung
    while z < z1 - 0.1:
        m.box(size(width, 0.035, 0.035), (bx, by, z), mat, bevel=False)
        z += rung
    if cage_from is None:
        return
    reach = 0.72
    z = cage_from
    while z < z1:
        m.box(size(width + 0.3, 0.04, 0.05), (bx + ox * reach, by + oy * reach, z), mat, bevel=False)
        for s in (-1, 1):
            m.box(size(0.04, reach, 0.05), (bx + s * ax * (width / 2 + 0.15) + ox * reach / 2,
                                            by + s * ay * (width / 2 + 0.15) + oy * reach / 2, z), mat, bevel=False)
        z += 1.0
    for s in (-1, 0, 1):
        m.box(size(0.04, 0.04, z1 - cage_from), (bx + s * ax * (width / 2 + 0.15) + ox * reach,
                                                 by + s * ay * (width / 2 + 0.15) + oy * reach,
                                                 (cage_from + z1) / 2), mat, bevel=False)


# ---------------------------------------------------------------- towers


def curtain(m, r, w, d, z0, z1, floor_h=3.2, bay=1.5, lit=10, band_every=2, accent=None, accent_every=0,
            corner=None, fins=None, fin_at=(), windows=(WARM, COOL)):
    """A curtain-wall shaft (half sizes w x d, centred on the origin) from z0 to z1: a glass core;
    a dark spandrel at every floor wrapping all four faces, every band_every-th carrying a thin dim
    glowing strip and every accent_every-th a brighter accent strip; mullions every `bay` on every
    face (the ones at `fin_at` are glowing `fins`); clad corner piers with an optional LED line on
    their outer corner; and `lit` runs of lit panes, mostly on the road face (-X)."""
    m.box((w * 2, d * 2, z1 - z0), (0, 0, (z0 + z1) / 2), GLASS, bevel=False)
    lo = max(z0, FACADE_FROM)
    h, zm = z1 - lo, (lo + z1) / 2
    floors = []
    z = lo + floor_h
    while z < z1 - 1.0:
        i = len(floors)
        floors.append(z)
        m.box((w * 2 + 0.16, d * 2 + 0.16, 0.55), (0, 0, z), CLAD, bevel=False)
        if accent is not None and accent_every and i % accent_every == accent_every - 1:
            m.box((w * 2 + 0.26, d * 2 + 0.26, 0.2), (0, 0, z), accent, bevel=False)
        elif band_every and i % band_every == 0:
            m.box((w * 2 + 0.24, d * 2 + 0.24, 0.12), (0, 0, z), BAND, bevel=False)
        z += floor_h
    spans = []
    for axis, half in ((0, d), (1, w)):
        n = max(2, round(half * 2 / bay))
        step = half * 2 / n
        spans.append((n, step, half))
        for k in range(1, n):
            t = -half + k * step
            fin = fins is not None and any(abs(t - f) < step / 2 for f in fin_at)
            deep, wide = (0.38, 0.2) if fin else (0.3, 0.14)
            for s in (-1, 1):
                if axis == 0:
                    m.box((deep, wide, h), (s * w, t, zm), fins if fin else CLAD, bevel=False)
                else:
                    m.box((wide, deep, h), (t, s * d, zm), fins if fin else CLAD, bevel=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.8, 0.8, h), (sx * w, sy * d, zm), CLAD)
            if corner is not None:
                m.box((0.14, 0.14, h - 0.6), (sx * (w + 0.4), sy * (d + 0.4), zm), corner, bevel=False)
    for _ in range(lit if len(floors) > 1 else 0):
        face = r.choice((0, 0, 0, 1, 2, 2, 3))  # 0 -X (the road face), 1 +X, 2 -Y (oncoming), 3 +Y
        f = r.randrange(len(floors) - 1)
        za, zb = floors[f], floors[f + 1]
        zc, hz = (za + zb) / 2, (zb - za) - 0.75
        n, step, half = spans[0] if face < 2 else spans[1]
        start = r.randrange(n)
        mat = r.choice(windows)
        for k in range(start, min(n, start + r.randint(2, 6))):
            t = -half + (k + 0.5) * step
            if face < 2:
                m.box((0.06, step - 0.32, hz), ((-1 if face == 0 else 1) * (w + 0.03), t, zc), mat, bevel=False)
            else:
                m.box((step - 0.32, 0.06, hz), (t, (-1 if face == 2 else 1) * (d + 0.03), zc), mat, bevel=False)


def parapet(m, w, d, z, h=1.0, mat=CLAD, t=0.3, at=(0.0, 0.0)):
    cx, cy = at
    for s in (-1, 1):
        m.box((w * 2 + t, t, h), (cx, cy + s * d, z + h / 2), mat)
        m.box((t, d * 2 - t, h), (cx + s * w, cy, z + h / 2), mat)


def hvac(m, x, y, z, lx=2.4, ly=1.3, mat=CLAD, hole=GLASS, bevel=True):
    """A rooftop air handler on a curb: louvred housing, fan shrouds over dark fan wells."""
    m.box((lx + 0.2, ly + 0.2, 0.2), (x, y, z + 0.1), mat, bevel=False)
    m.box((lx, ly, 1.1), (x, y, z + 0.75), mat, bevel=bevel)
    for k in range(4):
        m.box((lx + 0.04, ly + 0.04, 0.05), (x, y, z + 0.42 + k * 0.17), mat, bevel=False)
    fans = max(1, int(max(lx, ly) / 1.2))
    for i in range(fans):
        f = -max(lx, ly) / 2 + (i + 0.5) * max(lx, ly) / fans
        fx, fy = (x + f, y) if lx >= ly else (x, y + f)
        m.cyl(0.46, 0.46, 0.22, (fx, fy, z + 1.4), mat, segs=12, bevel=bevel)
        m.cyl(0.38, 0.38, 0.05, (fx, fy, z + 1.5), hole, segs=12, bevel=False)


def tank(m, x, y, z, r=1.2, h=2.2, mat=CLAD, legs=CLAD, bevel=True, segs=14, hoops=(0.22, 0.5, 0.78)):
    """A water tank on a braced stand, with hoops and a conical roof."""
    leg_h = 1.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.14, 0.14, leg_h), (x + sx * r * 0.62, y + sy * r * 0.62, z + leg_h / 2), legs, bevel=False)
        m.beam((x + sx * r * 0.62, y - r * 0.62, z + 0.2), (x + sx * r * 0.62, y + r * 0.62, z + leg_h - 0.1), 0.03,
               legs, segs=4)
    m.box((r * 1.6, r * 1.6, 0.12), (x, y, z + leg_h), legs, bevel=False)
    m.cyl(r, r, h, (x, y, z + leg_h + h / 2), mat, segs=segs, bevel=bevel)
    m.cyl(r + 0.03, 0.12, 0.6, (x, y, z + leg_h + h + 0.3), mat, segs=segs, bevel=False)
    for k in hoops:
        m.cyl(r + 0.035, r + 0.035, 0.07, (x, y, z + leg_h + h * k), legs, segs=segs, bevel=False)


def mast(m, x, y, z, h, base=0.55, top=0.18, mat=CLAD, step=1.5):
    """A three-legged lattice mast with zig-zag bracing and a whip antenna on top."""
    def ring(zz, rr):
        return [(x + rr * math.cos(a), y + rr * math.sin(a), zz) for a in (math.pi / 2, math.pi * 7 / 6, math.pi * 11 / 6)]

    for a, b in zip(ring(z, base), ring(z + h, top)):
        m.beam(a, b, 0.05, mat, segs=4)
    n = max(2, int(h / step))
    for i in range(n):
        pa = ring(z + i * h / n, base + (top - base) * i / n)
        pb = ring(z + (i + 1) * h / n, base + (top - base) * (i + 1) / n)
        for j in range(3):
            m.beam(pa[j], pb[(j + 1) % 3], 0.025, mat, segs=4)
    m.cyl(0.035, 0.015, 3.0, (x, y, z + h + 1.5), mat, segs=6, bevel=False)


def dish(m, x, y, z, r=0.8, facing=-1, mat=CLAD):
    """A microwave dish on a post, its bowl turned out along X (facing -1 looks toward -X)."""
    m.cyl(0.08, 0.08, 1.0, (x, y, z + 0.5), mat, segs=6, bevel=False)
    m.cyl(0.12, r, 0.35, (x + facing * 0.2, y, z + 1.1), mat, segs=14, rot=(0, math.radians(facing * 70), 0),
          bevel=False)
    m.beam((x + facing * 0.3, y, z + 1.1), (x + facing * 0.9, y, z + 1.32), 0.02, mat, segs=4)


def bmu(m, x, y, z, reach=2.6, mat=CLAD):
    """A window-cleaning crane on the roof: carriage, mast and a jib reaching out over -X."""
    m.box((1.4, 1.2, 0.9), (x, y, z + 0.45), mat)
    m.box((0.36, 0.36, 2.0), (x, y, z + 1.9), mat, bevel=False)
    m.box((reach + 0.8, 0.24, 0.3), (x - reach / 2, y, z + 2.9), mat, bevel=False)
    m.beam((x, y, z + 2.2), (x - reach * 0.6, y, z + 2.78), 0.04, mat, segs=4)
    m.box((0.05, 0.05, 1.4), (x - reach, y, z + 2.05), mat, bevel=False)


def beacon(m, loc, s=0.4):
    m.box((s, s, s), loc, BEACON, bevel=False)


def tower_a():
    """Square megatower with a setback at 50 m: cyan corner lines and pink accent floors, a terrace
    parapet over a glowing slab edge, a louvred plant penthouse under the pink crown ring, and roof
    plant: HVAC units, a water tank, a dish, a crane and a lattice mast with aircraft lights."""
    m = Part("tower_a", width=0.08)
    r = random.Random(11)
    curtain(m, r, 6.5, 6.5, BELOW, 50.0, lit=18, band_every=2, accent=PINK, accent_every=5, corner=CYAN)
    m.box((14.2, 14.2, 0.6), (0, 0, 50.3), CLAD)
    m.box((14.5, 14.5, 0.22), (0, 0, 50.05), PINK, bevel=False)
    parapet(m, 6.95, 6.95, 50.6, 1.0)
    curtain(m, r, 5.0, 5.0, 50.6, 72.0, lit=8, band_every=2, accent=PINK, accent_every=4, corner=CYAN)
    m.box((10.9, 10.9, 0.5), (0, 0, 72.25), CLAD)
    parapet(m, 5.3, 5.3, 72.5, 1.1)
    bmu(m, -4.4, 3.4, 72.5)
    m.box((7.6, 7.6, 6.4), (0, 0, 75.7), CLAD)
    for k in range(6):
        m.box((7.76, 7.76, 0.1), (0, 0, 73.4 + k * 0.85), CLAD, bevel=False)
    m.box((8.0, 8.0, 0.4), (0, 0, 79.1), CLAD)
    m.box((9.0, 9.0, 0.3), (0, 0, 79.0), PINK, bevel=False)
    rz = 79.3
    hvac(m, -1.8, -2.2, rz, 2.6, 1.3)
    hvac(m, -1.8, 2.2, rz, 2.6, 1.3)
    tank(m, 2.3, 2.4, rz, 0.95, 1.8)
    dish(m, 2.7, -2.6, rz, 0.7, -1)
    mast(m, 1.0, -0.2, rz, 13.0)
    beacon(m, (1.0, -0.2, rz + 13.25), 0.45)
    beacon(m, (1.0, 0.15, rz + 7.0), 0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            beacon(m, (sx * 3.75, sy * 3.75, rz + 0.2), 0.28)
    return m.finish()


def tower_b():
    """Stepped tower in three tiers, each terrace with a pink rim, a parapet and plant; a vertical
    holo banner in a bracketed frame on its road face; a mast and a crane on the top roof."""
    m = Part("tower_b", width=0.08)
    r = random.Random(23)
    tiers = [(8.0, 7.0, BELOW, 30.0, 2.9, 14), (6.0, 5.2, 30.6, 56.0, 3.4, 8), (3.8, 3.8, 56.6, 82.0, 3.4, 5)]
    for w, d, z0, z1, fh, lit in tiers:
        curtain(m, r, w, d, z0, z1, fh, 1.6, lit=lit, band_every=1, accent=VIOLET, accent_every=3)
        m.box((w * 2 + 0.5, d * 2 + 0.5, 0.6), (0, 0, z1 + 0.3), CLAD)
        m.box((w * 2 + 0.7, d * 2 + 0.7, 0.3), (0, 0, z1 + 0.1), PINK, bevel=False)
        parapet(m, w + 0.1, d + 0.1, z1 + 0.6, 0.9)
    # First terrace (30.6): air handlers on the back ring, a tank and a dish toward the road.
    hvac(m, 7.0, -2.6, 30.6, 1.3, 2.6)
    hvac(m, 7.0, 2.1, 30.6, 1.3, 2.6)
    tank(m, -7.0, 6.1, 30.6, 0.7, 1.5)
    dish(m, -7.0, -5.9, 30.6, 0.7, -1)
    # Second terrace (56.6): dishes and an air handler.
    dish(m, -4.9, 0.6, 56.6, 0.6, -1)
    dish(m, -4.9, -2.6, 56.6, 0.8, -1)
    hvac(m, 4.9, 0.0, 56.6, 1.2, 2.4)
    # Top roof (82.6).
    tz = 82.6
    hvac(m, -1.6, -1.7, tz, 2.0, 1.1)
    bmu(m, -2.0, 2.0, tz)
    mast(m, 2.0, 1.0, tz, 9.0, 0.45, 0.15)
    beacon(m, (2.0, 1.0, tz + 9.25), 0.5)
    for sx in (-1, 1):
        beacon(m, (sx * 3.6, -3.6, tz + 1.0), 0.26)
    # Banner: a tall violet screen of abstract glyph blocks (no lettering), held off the road face.
    bx = -8.65
    m.box((0.12, 4.4, 22.0), (bx, 0, 16.0), HOLO_BG, bevel=False)
    for s in (-1, 1):
        m.box((0.4, 5.0, 0.3), (bx + 0.08, 0, 16.0 + s * 11.15), CLAD)
        m.box((0.4, 0.3, 22.0), (bx + 0.08, s * 2.35, 16.0), CLAD)
        for z in (7.0, 13.0, 19.0, 25.0):
            m.box((0.55, 0.14, 0.14), (-8.38, s * 1.7, z), CLAD, bevel=False)
        m.box((0.5, 0.08, 0.08), (bx - 0.1, s * 2.0, 27.45), CLAD, bevel=False)
    for k in range(13):
        z = 6.0 + k * 1.6
        for _ in range(r.randint(1, 3)):
            m.box((0.08, r.uniform(0.6, 1.4), 0.9), (bx - 0.09, r.uniform(-1.4, 1.4), z), COOL, bevel=False)
    m.box((0.14, 4.6, 0.1), (bx - 0.35, 0, 27.45), PINK, bevel=False)
    return m.finish()


def tower_c():
    """Slim needle tower: glowing violet fins up every face, cyan accent floors, a recessed sky
    lobby with exposed columns and a lit soffit, a finned slanted crown and a spire."""
    m = Part("tower_c", width=0.08)
    r = random.Random(37)
    w = d = 4.5
    top = 92.0
    fins = {"fins": VIOLET, "fin_at": (-1.5, 1.5)}
    curtain(m, r, w, d, BELOW, 44.0, 3.5, 1.5, lit=9, band_every=0, accent=CYAN, accent_every=2, **fins)
    m.box((9.4, 9.4, 0.5), (0, 0, 44.25), CLAD)
    m.box((7.6, 7.6, 3.0), (0, 0, 46.0), GLASS, bevel=False)
    for t in (-4.15, -1.5, 1.5, 4.15):
        for s in (-1, 1):
            m.box((0.45, 0.45, 3.0), (s * 4.15, t, 46.0), CLAD, bevel=False)
            if abs(t) < 4:
                m.box((0.45, 0.45, 3.0), (t, s * 4.15, 46.0), CLAD, bevel=False)
    m.box((8.4, 8.4, 0.12), (0, 0, 47.38), COOL, bevel=False)
    m.box((9.4, 9.4, 0.5), (0, 0, 47.75), CLAD)
    curtain(m, r, w, d, 48.0, top, 3.5, 1.5, lit=8, band_every=0, accent=CYAN, accent_every=2, **fins)
    # Crown: glass sloping up away from the road, pink edges, fins continuing the facade's lines.
    crown = [(-w, -d, top), (w, -d, top), (w, d, top), (-w, d, top), (-w, -d, top + 3.0), (w, -d, top + 9.0),
             (w, d, top + 9.0), (-w, d, top + 3.0)]
    m.poly(crown, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)], GLASS)
    m.beam((-w, -d - 0.05, top + 3.0), (w, -d - 0.05, top + 9.0), 0.16, PINK, segs=4)
    m.beam((-w, d + 0.05, top + 3.0), (w, d + 0.05, top + 9.0), 0.16, PINK, segs=4)
    m.box((0.3, d * 2 + 0.3, 0.3), (-w, 0, top + 3.0), CLAD)
    m.box((0.3, d * 2 + 0.3, 0.3), (w, 0, top + 9.0), CLAD)
    for t in (-3.0, -1.5, 0.0, 1.5, 3.0):
        mat = VIOLET if abs(abs(t) - 1.5) < 0.1 else CLAD
        ht = 3.0 + 6.0 * (t + w) / (2 * w)
        for s in (-1, 1):
            m.box((0.14, 0.24, ht), (t, s * (d + 0.06), top + ht / 2), mat, bevel=False)
        m.box((0.24, 0.14, 3.0), (-w - 0.06, t, top + 1.5), mat, bevel=False)
        m.box((0.24, 0.14, 9.0), (w + 0.06, t, top + 4.5), mat, bevel=False)
    mast(m, 3.0, 0.0, top + 8.0, 9.0, 0.4, 0.12)
    beacon(m, (3.0, 0.0, top + 17.2), 0.45)
    beacon(m, (w - 0.4, 0, top + 9.5), 0.5)
    return m.finish()


def block():
    """A city block of older towers for the skyline: concrete walls with ribbon windows between
    piers, floor ledges, balconies and fire escapes, window AC units, a neon blade sign, glowing
    cornice lines and roof clutter (water tanks, stair bulkheads, air handlers, antennas).
    No bevels: it stands 66 m and more from the road, where a bevel is under a pixel and would cost
    a tenth of the budget."""
    m = Part("block", width=0.0)
    r = random.Random(53)
    # x, y, half width, half depth, roof height, accent, road-face extra, side extra
    layout = [
        (-9.0, -13.0, 5.5, 5.0, 24.0, PINK, "balconies", "escape_s"),
        (-10.0, 0.0, 6.0, 5.5, 18.0, CYAN, "balconies", "blade"),
        (-9.0, 13.0, 5.0, 5.5, 30.0, PINK, "", "escape_n"),
        (5.0, -7.0, 7.0, 6.0, 46.0, CYAN, "", "escape_s"),
        (6.0, 8.0, 6.5, 6.5, 52.0, PINK, "", ""),
        (4.0, 22.0, 5.0, 4.5, 38.0, CYAN, "balconies", ""),
    ]
    bay, floor_h, lo = 2.4, 3.0, FACADE_FROM + 7.0
    for x, y, w, d, top, accent, front, side in layout:
        m.box((w * 2, d * 2, top - BELOW), (x, y, (top + BELOW) / 2), BLOCK_WALL)
        floors = []
        z = lo
        while z < top - 2.5:
            floors.append(z)
            m.box((w * 2 + 0.12, d * 2 + 0.12, 0.22), (x, y, z), BLOCK_WALL, bevel=False)
            m.box((0.08, d * 2 - 1.0, 1.4), (x - w - 0.01, y, z + 1.4), GLASS, bevel=False)
            m.box((w * 2 - 1.0, 0.08, 1.4), (x, y - d - 0.01, z + 1.4), GLASS, bevel=False)
            m.box((w * 2 - 1.0, 0.08, 1.4), (x, y + d + 0.01, z + 1.4), GLASS, bevel=False)
            z += floor_h
        h = top - 1.0 - lo
        ny, nx = max(2, round(d * 2 / bay)), max(2, round(w * 2 / bay))
        sy, sx = d * 2 / ny, w * 2 / nx
        for k in range(1, ny):
            m.box((0.2, 0.5, h), (x - w, y - d + k * sy, lo + h / 2), BLOCK_WALL, bevel=False)
        for k in range(1, nx):
            for s in (-1, 1):
                m.box((0.5, 0.2, h), (x - w + k * sx, y + s * d, lo + h / 2), BLOCK_WALL, bevel=False)
        # Lit windows and the AC units under some of them.
        for _ in range(int(len(floors) * 1.3)):
            z = r.choice(floors) + 1.4
            mat = r.choice((WARM, WARM, COOL))
            if r.random() < 0.5:
                cy = y - d + (r.randrange(ny) + 0.5) * sy
                m.box((0.06, sy - 0.6, 1.3), (x - w - 0.04, cy, z), mat, bevel=False)
                if r.random() < 0.45:
                    m.box((0.5, 0.62, 0.42), (x - w - 0.25, cy + r.uniform(-0.4, 0.4), z - 1.0), STEEL, bevel=False)
            else:
                s = r.choice((-1, 1))
                cx = x - w + (r.randrange(nx) + 0.5) * sx
                m.box((sx - 0.6, 0.06, 1.3), (cx, y + s * (d + 0.04), z), mat, bevel=False)
                if r.random() < 0.45:
                    m.box((0.62, 0.5, 0.42), (cx + r.uniform(-0.4, 0.4), y + s * (d + 0.25), z - 1.0), STEEL,
                          bevel=False)
        if front == "balconies":
            for z in floors:
                if z < 0.0:
                    continue
                for by in (y - d * 0.45, y + d * 0.45):
                    m.box((1.1, 2.2, 0.14), (x - w - 0.55, by, z + 0.07), BLOCK_WALL, bevel=False)
                    m.box((0.05, 2.2, 0.85), (x - w - 1.08, by, z + 0.55), STEEL, bevel=False)
                    m.box((1.1, 0.05, 0.85), (x - w - 0.55, by - 1.08, z + 0.55), STEEL, bevel=False)
        if side.startswith("escape"):
            s = -1 if side == "escape_s" else 1
            yf, xe = y + s * d, x - w * 0.35
            esc = [z for z in floors if z >= -6.0]
            for i, z in enumerate(esc):
                m.box((3.4, 1.0, 0.07), (xe, yf + s * 0.5, z + 0.05), STEEL, bevel=False)
                m.box((3.4, 0.04, 0.04), (xe, yf + s * 1.0, z + 0.95), STEEL, bevel=False)
                m.box((3.4, 0.04, 0.04), (xe, yf + s * 1.0, z + 0.5), STEEL, bevel=False)
                if i + 1 < len(esc):
                    flip = 1 if i % 2 else -1
                    m.beam((xe - flip * 1.4, yf + s * 0.5, z + 0.1), (xe + flip * 1.4, yf + s * 0.5, z + floor_h),
                           0.07, STEEL, segs=4)
            if esc:
                m.box((0.06, 0.4, 2.6), (xe + 1.5, yf + s * 0.8, esc[0] - 1.3), STEEL, bevel=False)
        if side == "blade":
            m.box((1.6, 0.24, 7.4), (x - w - 0.85, y - d + 1.4, 9.0), STEEL)
            m.box((1.36, 0.3, 7.0), (x - w - 0.85, y - d + 1.4, 9.0), accent, bevel=False)
            for bz in (5.6, 12.4):
                m.box((0.5, 0.1, 0.1), (x - w - 0.25, y - d + 1.4, bz), STEEL, bevel=False)
        # Cornice and its glowing line; roof clutter.
        m.box((w * 2 + 0.4, d * 2 + 0.4, 0.5), (x, y, top - 0.25), BLOCK_WALL)
        m.box((w * 2 + 0.5, d * 2 + 0.5, 0.18), (x, y, top - 0.9), accent, bevel=False)
        m.box((2.4, 2.8, 2.6), (x + w * 0.35, y - d * 0.4, top + 1.3), BLOCK_WALL)
        if top < 45.0:
            tank(m, x - w * 0.35, y + d * 0.35, top, 1.05, 2.0, STEEL, STEEL, bevel=False, segs=10, hoops=(0.3, 0.7))
        m.box((1.6, 1.0, 0.9), (x + w * 0.4, y + d * 0.45, top + 0.45), STEEL, bevel=False)
        m.cyl(0.04, 0.02, r.uniform(3.0, 6.0), (x - w * 0.2, y - d * 0.6, top + 2.0), STEEL, segs=6, bevel=False)
    return m.finish()


# ---------------------------------------------------------------- signs


def billboard():
    """A holographic billboard on a bolted monopole: a sliced synthwave sun over a perspective grid
    in a deep frame with back framing, a grated catwalk with handrails and lamp arms along its
    foot, and a caged ladder up the pole. The face is on -X; the world script yaws it toward the
    road and the oncoming driver."""
    m = Part("billboard", width=0.04)
    zc, half_y, half_z = 14.0, 5.6, 3.2
    bottom = zc - half_z
    pole_top = bottom - 0.9
    px = 0.6

    def pole_r(z):
        return 0.62 - 0.16 * (z - BELOW) / (pole_top - BELOW)

    m.cyl(0.62, 0.46, pole_top - BELOW, (px, 0, (BELOW + pole_top) / 2), STEEL, segs=16)
    for fz in (-8.0, 4.0):
        fr = pole_r(fz) + 0.1
        m.cyl(fr, fr, 0.14, (px, 0, fz), STEEL, segs=16)
        for k in range(10):
            a = k * math.tau / 10 + 0.3
            bolt(m, (px + (fr - 0.05) * math.cos(a), (fr - 0.05) * math.sin(a), fz + 0.09), (0, 0, 1))
    # Head: a cap plate, two stringers on knee braces under the screen.
    m.box((0.9, 0.9, 0.45), (px, 0, pole_top + 0.225), STEEL)
    m.box((0.5, half_y * 2 - 0.4, 0.45), (0.45, 0, bottom - 0.225), STEEL)
    m.box((0.3, half_y * 2 - 1.6, 0.3), (0.45, 0, bottom - 1.4), STEEL, bevel=False)
    for s in (-1, 1):
        m.beam((px, 0, pole_top - 2.6), (0.45, s * (half_y - 1.0), bottom - 0.45), 0.09, STEEL, segs=6)
        m.beam((px, 0, pole_top - 1.2), (0.45, s * (half_y - 0.8), bottom - 1.4), 0.06, STEEL, segs=6)
    # Face (glitches as one with the graphics) in a deep frame; back skin, posts, girts and braces.
    m.box((0.12, half_y * 2, half_z * 2), (-0.05, 0, zc), HOLO_BG, bevel=False)
    for s in (-1, 1):
        m.box((0.7, half_y * 2 + 0.6, 0.3), (0.2, 0, zc + s * (half_z + 0.15)), STEEL)
        m.box((0.7, 0.3, half_z * 2), (0.2, s * (half_y + 0.15), zc), STEEL)
    m.box((0.08, half_y * 2, half_z * 2), (0.52, 0, zc), STEEL, bevel=False)
    for t in (-3.6, -1.2, 1.2, 3.6):
        m.box((0.18, 0.14, half_z * 2 + 0.4), (0.65, t, zc), STEEL, bevel=False)
    for zz in (zc - 2.1, zc, zc + 2.1):
        m.box((0.16, half_y * 2, 0.14), (0.8, 0, zz), STEEL, bevel=False)
    for s in (-1, 1):
        m.beam((0.85, s * 0.2, zc - half_z + 0.2), (0.85, s * (half_y - 0.3), zc + half_z - 0.2), 0.04, STEEL, segs=4)
    m.box((0.35, 0.6, 0.8), (0.95, 2.4, bottom - 0.9), STEEL)  # power cabinet
    m.beam((0.95, 2.4, bottom - 1.3), (px + 0.5, 0.3, pole_top - 3.0), 0.05, STEEL, segs=6)
    m.beam((px + 0.5, 0.3, pole_top - 3.0), (px + 0.5, 0.3, -12.0), 0.05, STEEL, segs=6)
    # Catwalk along the foot of the face: grating, toe board, brackets, handrails, lamp arms.
    cz = bottom - 0.3
    m.box((1.1, half_y * 2 + 0.4, 0.06), (-0.55, 0, cz), GRATE, bevel=False)
    m.box((0.03, half_y * 2 + 0.4, 0.14), (-1.08, 0, cz + 0.1), STEEL, bevel=False)
    for t in (-4.8, -1.6, 1.6, 4.8):
        m.box((1.3, 0.08, 0.1), (-0.45, t, cz - 0.08), STEEL, bevel=False)
        m.beam((0.35, t, bottom - 1.4), (-1.0, t, cz - 0.1), 0.035, STEEL, segs=4)
    t = -half_y - 0.1
    while t <= half_y + 0.15:
        m.box((0.045, 0.045, 1.0), (-1.06, t, cz + 0.5), STEEL, bevel=False)
        t += 1.6
    for rz in (cz + 0.5, cz + 1.0):
        m.beam((-1.06, -half_y - 0.15, rz), (-1.06, half_y + 0.15, rz), 0.025, STEEL, segs=6)
    tilt = math.radians(-35)
    n = Vector((math.cos(tilt), 0, -math.sin(tilt)))
    for t in (-4.2, -1.4, 1.4, 4.2):
        m.beam((-1.06, t, cz + 0.2), (-2.05, t, cz + 0.85), 0.035, STEEL, segs=4)
        head = Vector((-2.15, t, cz + 0.95))
        m.box((0.32, 0.5, 0.2), head, STEEL, rot=(0, tilt, 0))
        m.box((0.04, 0.42, 0.14), head + n * 0.17, LAMP, rot=(0, tilt, 0), bevel=False)
    ladder(m, (-0.14, 0.0), -10.0, cz, (0, 1), (-1, 0), STEEL, cage_from=0.0)
    # Sun: horizontal slices of a circle, the lower ones thinner, as in the genre's posters.
    sun_r, sun_z = 2.3, zc + 0.6
    z = sun_z + sun_r - 0.2
    while z > sun_z - 0.4:
        dz = z - sun_z
        width = 2.0 * math.sqrt(max(sun_r * sun_r - dz * dz, 0.0))
        thick = 0.42 if dz > 0.4 else 0.26
        m.box((0.08, width, thick), (-0.12, 0, z), HOLO_SUN if dz > 0.6 else HOLO_SUN_LOW, bevel=False)
        z -= thick + (0.08 if dz > 0.4 else 0.16)
    # Grid: horizon line, receding rows and converging columns.
    floor = sun_z - 0.55
    m.box((0.08, half_y * 2 - 0.4, 0.09), (-0.13, 0, floor), HOLO_GRID, bevel=False)
    for gz in (floor - 0.45, floor - 1.05, floor - 1.9):
        m.box((0.08, half_y * 2 - 0.4, 0.07), (-0.13, 0, gz), HOLO_GRID, bevel=False)
    for i in range(-3, 4):
        top_y, low_y = i * 0.5, i * 1.55
        m.beam((-0.13, top_y, floor), (-0.13, low_y, zc - half_z + 0.25), 0.04, HOLO_GRID, segs=4)
    return m.finish()


def pylon():
    """A free-standing vertical holo screen: glyph blocks scroll down a violet panel in a bezelled
    frame on knee braces, on a clad column with corner angles, a service hatch, conduits, a caged
    ladder up its back and a lit sensor mast on top."""
    m = Part("pylon", width=0.04)
    r = random.Random(71)
    m.box((1.2, 1.2, 24.0 - BELOW), (0.6, 0, (24.0 + BELOW) / 2), CLAD)
    for sx in (0.0, 1.2):
        for sy in (-0.6, 0.6):
            m.box((0.12, 0.12, 24.0 - FACADE_FROM), (sx, sy, (24.0 + FACADE_FROM) / 2), CLAD, bevel=False)
    z = FACADE_FROM + 2.0
    while z < 24.0:
        m.box((1.28, 1.28, 0.1), (0.6, 0, z), CLAD, bevel=False)
        z += 3.0
    m.box((0.06, 0.7, 1.5), (-0.02, 0, 2.3), CLAD)  # service hatch
    m.box((0.06, 0.06, 0.2), (-0.07, 0.25, 2.3), CLAD, bevel=False)
    for cy in (0.66, 0.78):
        m.beam((0.4, cy, 23.5), (0.4, cy, FACADE_FROM), 0.045, CLAD, segs=6)
    # Screen in its frame, bezel lip, side LED lines, visor and knee braces back to the column.
    m.box((0.4, 4.0, 15.4), (0.0, 0, 15.0), CLAD)
    for s in (-1, 1):
        m.box((0.14, 4.0, 0.26), (-0.25, 0, 15.0 + s * 7.57), CLAD, bevel=False)
        m.box((0.14, 0.26, 15.4), (-0.25, s * 1.87, 15.0), CLAD, bevel=False)
        m.box((0.1, 0.1, 15.2), (-0.12, s * 2.05, 15.0), PINK, bevel=False)
        for kz in (9.0, 13.5, 18.0):
            m.beam((0.9, s * 0.6, kz - 1.2), (0.15, s * 1.85, kz), 0.06, CLAD, segs=6)
    m.box((0.1, 3.4, 14.6), (-0.22, 0, 15.0), HOLO_BG, bevel=False)
    for k in range(11):
        z = 8.6 + k * 1.25
        y = -1.2
        while y < 1.2:
            w = r.uniform(0.3, 0.8)
            if r.random() < 0.7:
                m.box((0.06, w, 0.7), (-0.3, y + w / 2, z), HOLO_GLYPH if r.random() < 0.75 else HOLO_SUN_LOW,
                      bevel=False)
            y += w + 0.2
    m.box((0.12, 4.2, 0.18), (-0.25, 0, 22.8), PINK, bevel=False)
    m.box((0.12, 4.2, 0.18), (-0.25, 0, 7.2), PINK, bevel=False)
    m.box((0.9, 4.4, 0.12), (-0.3, 0, 22.95), CLAD, rot=(0, math.radians(12), 0))
    # Cap, sensor pod and whip antenna with an aircraft light.
    m.box((1.5, 1.5, 0.3), (0.6, 0, 24.15), CLAD)
    m.box((0.4, 0.3, 0.3), (0.2, -0.3, 24.45), CLAD)
    m.cyl(0.04, 0.02, 3.0, (0.9, 0.3, 25.8), CLAD, segs=6, bevel=False)
    beacon(m, (0.9, 0.3, 27.4), 0.3)
    ladder(m, (1.36, 0.0), 0.4, 24.0, (0, 1), (1, 0), CLAD, cage_from=3.0)
    return m.finish()


# ---------------------------------------------------------------- freeway


def deck():
    """One span of the freeway deck beside the road. Origin at the road edge; it reaches outward
    along +X. The shoulder has a gutter and scuppers; beyond the barrier a cable tray on stands
    runs to an edge parapet with a violet LED line and a handrail; a steel finger expansion joint
    crosses the span's end; a hammerhead pier carries it from the street."""
    m = Part("deck", width=0.04)
    span = DECK_LENGTH
    half = span / 2
    m.box((5.2, span, 0.5), (2.6, 0, -0.3), CONCRETE)
    m.box((0.45, span, 2.0), (4.98, 0, -1.4), CONCRETE_DARK)
    m.box((0.35, span, 0.65), (5.02, 0, 0.27), CONCRETE)  # edge parapet
    m.box((0.08, span, 0.06), (4.82, 0, 0.52), VIOLET, bevel=False)  # reads as a second rail of light from afar
    # Handrail on the parapet.
    y = -half + 1.25
    while y < half:
        m.box((0.16, 0.16, 0.02), (5.02, y, 0.605), STEEL, bevel=False)
        m.cyl(0.035, 0.035, 0.62, (5.02, y, 0.92), STEEL, segs=8, bevel=False)
        y += 2.5
    for rz in (0.95, 1.24):
        m.beam((5.02, -half, rz), (5.02, half, rz), 0.03 if rz < 1.0 else 0.04, STEEL, segs=8)
    # Shoulder drainage: a gutter channel and scuppers in steel frames.
    m.box((0.22, span, 0.02), (0.28, 0, -0.045), CONCRETE_DARK, bevel=False)
    for sy in (-11.25, -3.75, 3.75, 11.25):
        m.box((0.44, 0.86, 0.025), (0.58, sy, -0.04), STEEL, bevel=False)
        m.box((0.32, 0.72, 0.03), (0.58, sy, -0.035), GRATE, bevel=False)
    # Expansion joint at the span's end (shared with the next span): finger plate, sealant, cover.
    m.box((4.8, 0.4, 0.03), (2.4, -half, -0.035), STEEL, bevel=False)
    for k in range(12):
        m.box((0.18, 0.22, 0.032), (0.25 + k * 0.4, -half + (0.12 if k % 2 else -0.12), -0.033), STEEL, bevel=False)
    for s in (-1, 1):
        m.box((4.8, 0.05, 0.02), (2.4, -half + s * 0.23, -0.04), CONCRETE_DARK, bevel=False)
    m.box((0.42, 0.4, 0.04), (5.02, -half, 0.62), STEEL, bevel=False)
    # Cable tray on stands, two cable runs in it.
    m.box((0.4, span, 0.03), (4.45, 0, 0.3), STEEL, bevel=False)
    for s in (-1, 1):
        m.box((0.03, span, 0.12), (4.45 + s * 0.2, 0, 0.35), STEEL, bevel=False)
    for cyy in (-0.07, 0.08):
        m.beam((4.45 + cyy, -half, 0.36), (4.45 + cyy, half, 0.36), 0.035, CONCRETE_DARK, segs=6)
    y = -half + 1.25
    while y < half:
        m.box((0.05, 0.05, 0.3), (4.45, y, 0.13), STEEL, bevel=False)
        m.box((0.46, 0.05, 0.04), (4.45, y, 0.27), STEEL, bevel=False)
        y += 2.5
    # Pier and pier cap.
    m.box((2.2, 2.2, -1.9 - BELOW), (2.6, 0, (BELOW - 1.9) / 2), CONCRETE_DARK, bevel=False)
    m.box((4.6, 2.8, 1.4), (2.6, 0, -1.25), CONCRETE_DARK, bevel=False)
    return m.finish()


def barrier():
    """Two precast jersey segments (BARRIER_LENGTH a tile), road face on -X, with bolted steel
    plates over their joints, a pink LED rail in a steel channel on top, a tube handrail on
    bolted posts and cyan reflectors."""
    m = Part("barrier", width=0.03)
    seg = BARRIER_LENGTH / 2
    prof = [(-0.4, 0.0), (-0.4, 0.08), (-0.26, 0.3), (-0.13, 1.0), (0.13, 1.0), (0.26, 0.3), (0.4, 0.08), (0.4, 0.0)]
    n = len(prof)
    for c in (-seg / 2, seg / 2):
        y0, y1 = c - seg / 2 + 0.03, c + seg / 2 - 0.03
        verts = [(x, y0, z) for x, z in prof] + [(x, y1, z) for x, z in prof]
        faces = [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
        faces += [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
        m.poly(verts, faces, CONCRETE)
    m.box((0.13, BARRIER_LENGTH, 0.05), (-0.06, 0, 1.025), STEEL)
    m.box((0.08, BARRIER_LENGTH, 0.035), (-0.06, 0, 1.055), RAIL, bevel=False)
    for y in (-3.75, -1.25, 1.25, 3.75):
        m.box((0.11, 0.18, 0.02), (0.065, y, 1.01), STEEL, bevel=False)
        m.cyl(0.035, 0.035, 0.48, (0.065, y, 1.26), STEEL, segs=8, bevel=False)
        for by in (-0.06, 0.06):
            bolt(m, (0.065, y + by, 1.03), (0, 0, 1), r=0.018, h=0.03)
    m.cyl(0.045, 0.045, BARRIER_LENGTH - 0.02, (0.065, 0, 1.52), STEEL, segs=12, rot=(math.radians(90), 0, 0))
    # Joint plates on the upper slope of the road face, at the middle joint and the tile's end.
    lean = math.atan(0.13 / 0.7)
    normal = Vector((-math.cos(lean), 0, math.sin(lean)))
    up_slope = Vector((math.sin(lean), 0, math.cos(lean)))
    for jy in (0.0, -seg):
        zc = 0.62
        centre = Vector((-0.26 + 0.13 * (zc - 0.3) / 0.7, jy, zc)) + normal * 0.012
        m.box((0.02, 0.36, 0.42), centre, STEEL, rot=(0, lean, 0))
        for dy in (-0.12, 0.12):
            for dz in (-0.14, 0.14):
                bolt(m, centre + normal * 0.022 + Vector((0, dy, 0)) + up_slope * dz, normal, r=0.022, h=0.03)
    for c in (-seg / 2, seg / 2):
        zc = 0.76
        centre = Vector((-0.26 + 0.13 * (zc - 0.3) / 0.7, c, zc)) + normal * 0.022
        m.box((0.04, 0.3, 0.1), centre, CYAN, rot=(0, lean, 0), bevel=False)
    return m.finish()


def lamp():
    """A freeway streetlamp: concrete plinth, bolted base plate and collar, tapered pole with a hatch,
    a violet LED ring and a slip joint, a braced arm reaching toward the road (-X) and a finned LED
    head."""
    m = Part("lamp", width=0.03)
    top = 10.6
    m.box((0.7, 0.7, 0.5), (0, 0, 0.25), CONCRETE)
    m.box((0.5, 0.5, 0.04), (0, 0, 0.52), STEEL)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.cyl(0.025, 0.025, 0.12, (sx * 0.19, sy * 0.19, 0.58), STEEL, segs=6, bevel=False)
            m.box((0.07, 0.07, 0.04), (sx * 0.19, sy * 0.19, 0.56), STEEL, bevel=False)
    m.cyl(0.25, 0.19, 0.5, (0, 0, 0.79), STEEL, segs=12)
    m.cyl(0.17, 0.11, top - 0.5, (0, 0, (top + 0.5) / 2), STEEL, segs=12, bevel=False)
    m.box((0.14, 0.05, 0.42), (0, -0.165, 1.6), STEEL)  # access hatch
    m.cyl(0.165, 0.163, 0.5, (0, 0, 3.0), VIOLET, segs=12, bevel=False)
    m.cyl(0.155, 0.15, 0.16, (0, 0, 6.4), STEEL, segs=12)
    m.cyl(0.12, 0.04, 0.14, (0, 0, top + 0.07), STEEL, segs=12, bevel=False)
    # Arm: three tapering segments curving out over the road, a brace under them.
    pts = [(0.0, 0, top - 0.4), (-0.55, 0, top + 0.12), (-1.35, 0, top + 0.34), (-1.75, 0, top + 0.36)]
    for (a, b), rr in zip(zip(pts, pts[1:]), (0.065, 0.055, 0.05)):
        m.beam(a, b, rr, STEEL, segs=8)
    m.beam((0.0, 0, top - 1.4), (-0.95, 0, top + 0.26), 0.03, STEEL, segs=6)
    # Head: housing with a tapered top, a clamp on the arm, heat-sink fins and the LED panel under it.
    hx, hz = -2.45, top + 0.3
    m.box((0.3, 0.22, 0.16), (-1.75, 0, top + 0.36), STEEL)
    m.box((1.5, 0.52, 0.16), (hx, 0, hz), STEEL)
    m.box((1.3, 0.38, 0.08), (hx, 0, hz + 0.11), STEEL)
    for k in range(6):
        m.box((0.03, 0.34, 0.07), (hx - 0.5 + k * 0.2, 0, hz + 0.18), STEEL, bevel=False)
    m.box((1.3, 0.36, 0.04), (hx, 0, hz - 0.09), LAMP, bevel=False)
    for k in (-1, 0, 1):
        m.box((0.03, 0.38, 0.045), (hx + k * 0.33, 0, hz - 0.095), STEEL, bevel=False)
    return m.finish()


def gantry():
    """An overhead sign gantry, legs on the deck outside the barriers: concrete footings with bolted
    base plates, braced twin-column legs (a caged ladder up the right one), a square box truss
    with Warren bracing on all four faces, and two sign cabinets on hangers with a catwalk and sign
    lights under them. The signs hang well above the camera (8.8), so the gantry only ever crosses
    the sky, never the notes. Built for road half 8.4."""
    m = Part("gantry", width=0.04)
    leg = GANTRY_HALF
    zb, zt, yd = 12.0, 13.6, 0.6
    for sx in (-1, 1):
        x = sx * leg
        m.box((1.1, 1.9, 0.5), (x, 0, 0.25), CONCRETE)
        m.box((0.7, 1.6, 0.04), (x, 0, 0.52), STEEL, bevel=False)
        for bx in (-0.25, 0.25):
            for by in (-0.65, 0.0, 0.65):
                bolt(m, (x + bx, by, 0.56), (0, 0, 1))
        for sy in (-1, 1):
            m.box((0.32, 0.32, zt + 0.3 - 0.54), (x, sy * yd, (zt + 0.3 + 0.54) / 2), STEEL)
            m.box((0.12, 0.14, 2.4), (x - sx * 0.2, sy * yd, 1.8), PINK, bevel=False)
        z = 1.4
        while z < zb - 1.0:
            m.box((0.12, yd * 2, 0.12), (x, 0, z), STEEL, bevel=False)
            m.beam((x, -yd, z), (x, yd, z + 2.0), 0.04, STEEL, segs=4)
            m.beam((x, yd, z), (x, -yd, z + 2.0), 0.04, STEEL, segs=4)
            z += 2.0
        m.box((0.6, yd * 2 + 0.6, 0.12), (x, 0, zt + 0.36), STEEL)
    ladder(m, (leg + 0.3, 0.0), 0.6, zb - 0.2, (0, 1), (1, 0), STEEL, cage_from=2.6)
    # Box truss: four chords, verticals and cross ties at every panel point, Warren diagonals.
    for sy in (-1, 1):
        for z in (zb, zt):
            m.box((leg * 2 + 0.6, 0.24, 0.24), (0, sy * yd, z), STEEL)
    panels = 13
    step = leg * 2 / panels
    for i in range(panels + 1):
        x = -leg + i * step
        for sy in (-1, 1):
            m.box((0.1, 0.1, zt - zb), (x, sy * yd, (zb + zt) / 2), STEEL, bevel=False)
        for z in (zb, zt):
            m.box((0.08, yd * 2, 0.08), (x, 0, z), STEEL, bevel=False)
    for i in range(panels):
        xa, xb = -leg + i * step, -leg + (i + 1) * step
        flip = i % 2 == 0
        for sy in (-1, 1):
            m.beam((xa, sy * yd, zb if flip else zt), (xb, sy * yd, zt if flip else zb), 0.045, STEEL, segs=4)
        m.beam((xa, -yd, zt), (xb, yd, zt), 0.035, STEEL, segs=4)
        m.beam((xa, yd, zb), (xb, -yd, zb), 0.035, STEEL, segs=4)
    # Two signs facing the driver (-Y), bottoms at 9.9: a lane chevron and abstract bars, no text.
    face_y = -yd - 0.65
    for sx, kind in ((-4.6, "arrow"), (4.6, "bars")):
        m.box((6.4, 0.4, 2.2), (sx, -yd - 0.45, 11.0), SIGN_FACE)
        for hx in (-2.2, 2.2):
            m.box((0.14, 0.14, zt + 0.1 - 9.0), (sx + hx, -yd - 0.17, (zt + 0.1 + 9.0) / 2), STEEL, bevel=False)
            for z in (zb, zt):
                m.box((0.24, 0.1, 0.3), (sx + hx, -yd - 0.06, z), STEEL, bevel=False)
            m.box((0.08, 1.3, 0.1), (sx + hx, -yd - 0.8, 9.5), STEEL, bevel=False)
            m.beam((sx + hx, -yd - 0.17, 9.05), (sx + hx, -1.9, 9.5), 0.035, STEEL, segs=4)
        for z in (10.3, 11.0, 11.7):
            m.box((6.0, 0.06, 0.1), (sx, -yd - 0.25, z), STEEL, bevel=False)
        m.box((6.6, 0.12, 0.08), (sx, face_y - 0.04, 12.12), CYAN, bevel=False)
        m.box((6.6, 0.12, 0.08), (sx, face_y - 0.04, 9.88), CYAN, bevel=False)
        for s in (-1, 1):
            m.box((0.08, 0.1, 2.2), (sx + s * 3.24, face_y - 0.03, 11.0), STEEL, bevel=False)
        gy = face_y - 0.06
        if kind == "arrow":
            for side in (-1, 1):
                m.box((0.16, 0.08, 1.3), (sx + side * 0.42, gy, 11.0), SIGN_MARK,
                      rot=(0, math.radians(side * 38), 0), bevel=False)
            m.box((0.16, 0.08, 1.2), (sx - 1.9, gy, 11.0), PINK, bevel=False)
            m.box((0.16, 0.08, 1.2), (sx + 1.9, gy, 11.0), PINK, bevel=False)
        else:
            for k, (bw, bz) in enumerate(((4.6, 11.55), (3.2, 11.05), (4.0, 10.55))):
                m.box((bw, 0.08, 0.22), (sx - (4.6 - bw) / 2, gy, bz), SIGN_MARK if k != 1 else PINK, bevel=False)
        # Sign lights on short arms off the catwalk's front edge, aimed up at the face.
        tilt = math.radians(37)
        n = Vector((0, math.cos(tilt), math.sin(tilt)))
        for lx in (-1.6, 1.6):
            m.beam((sx + lx, -1.98, 9.68), (sx + lx, -2.4, 9.92), 0.03, STEEL, segs=4)
            head = Vector((sx + lx, -2.48, 9.96))
            m.box((0.5, 0.3, 0.2), head, STEEL, rot=(tilt, 0, 0))
            m.box((0.42, 0.04, 0.13), head + n * 0.16, SIGN_MARK, rot=(tilt, 0, 0), bevel=False)
    # Catwalk under both signs.
    m.box((16.6, 0.75, 0.05), (0, -1.6, 9.58), GRATE, bevel=False)
    m.box((16.6, 0.03, 0.15), (0, -1.98, 9.66), STEEL, bevel=False)
    return m.finish()


def citylight():
    """A loose handful of pinpoint lights for the streets far below (Godot scatters these with a
    MultiMesh, hundreds of copies): street lights, lit windows and a car's head- and tail-lights.
    Tiny and spread out, so from the deck they read as points, not confetti. No bevel: at this size
    it is invisible, and it would cost nine-tenths of the triangles."""
    m = Part("citylight", width=0.0)
    r = random.Random(89)
    for _ in range(7):
        s = r.uniform(0.12, 0.26)
        m.box((s, s * r.uniform(1.0, 2.5), s), (r.uniform(-6.0, 6.0), r.uniform(-6.0, 6.0), 0.2),
              r.choice([WARM, PINK, COOL, COOL, VIOLET]), bevel=False)
    for cx, cy, mat in ((2.0, -3.0, COOL), (2.0, -1.9, PINK)):
        for dx in (-0.18, 0.18):
            m.box((0.1, 0.1, 0.08), (cx + dx, cy, 0.15), mat, bevel=False)
    return m.finish()


def hood():
    """The player's car, seen from the driver's seat, behind the keyboard.
    Same footprint as the Backroads truck; dark gloss paint with slatted bonnet vents and crease
    lines, a magenta underglow lip, fenders with vents and violet lines, and segmented LED lamps
    in glowing bezels at the front corners."""
    m = Part("hood", width=0.03)
    w = 8.0
    rise = math.atan(0.95 / 9.2)

    def bonnet_z(y):
        return 0.95 * (0.2 - y) / 9.2

    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], PAINT)
    # Underglow lip: where the hood rises out of the road (about y = -1.7), just below the keys.
    lip_y = -1.85
    m.box((w * 2 - 0.6, 0.16, 0.05), (0, lip_y, bonnet_z(lip_y) + 0.03), UNDERGLOW, rot=(-rise, 0, 0))
    # Bonnet: two slatted vents either side of the centre and two crease lines. Dark on dark, so
    # they catch the light without brightening the area under the keys.
    for side in (-1, 1):
        vy = -3.7
        m.box((2.4, 1.7, 0.03), (side * 4.4, vy, bonnet_z(vy) + 0.01), TRIM, rot=(-rise, 0, 0), bevel=False)
        for k in range(5):
            y = vy - 0.64 + k * 0.32
            m.box((2.3, 0.1, 0.05), (side * 4.4, y, bonnet_z(y) + 0.035), PAINT, rot=(-rise, 0, 0))
        m.box((0.06, 6.0, 0.03), (side * 2.2, -5.4, bonnet_z(-5.4) + 0.015), TRIM, rot=(-rise, 0, 0), bevel=False)
        bolt(m, (side * 1.0, -5.2, bonnet_z(-5.2) + 0.02), (0, math.sin(rise), math.cos(rise)), TRIM, 0.05, 0.04)
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.4), (x, -4.5, -0.3), PAINT)
        m.box((1.95, 9.6, 0.08), (x, -4.5, 0.42), TRIM)
        # A violet line along each fender's inner top edge, so the dark car still reads.
        m.box((0.1, 9.0, 0.07), (x - side * 0.9, -4.8, 0.46), FENDER_LINE, bevel=False)
        for k in range(3):
            m.box((1.1, 0.09, 0.04), (x + side * 0.15, -1.3 - k * 0.24, 0.47), TRIM, bevel=False)
        # Lamp: a wide slim LED bar in three segments inside a violet bezel, plus a cyan running
        # light. It sits high enough to clear the road plane (the hood's nose is sunk just below it).
        lz = 0.3
        m.box((1.85, 0.26, 0.62), (x, 0.32, lz), TRIM)
        m.box((1.95, 0.2, 0.72), (x, 0.26, lz), BEZEL)
        m.box((1.55, 0.3, 0.3), (x, 0.4, lz + 0.05), HEADLAMP)
        for dx in (-0.26, 0.26):
            m.box((0.05, 0.34, 0.33), (x + dx, 0.4, lz + 0.05), TRIM, bevel=False)
        m.box((0.14, 0.3, 0.62), (x - side * 0.95, 0.38, lz), CYAN)
        m.box((1.9, 0.12, 0.06), (x, -1.0, -1.02), UNDERGLOW)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), PAINT)
    m.box((w * 2 + 3.6, 0.1, 0.06), (0, 0.78, -1.34), UNDERGLOW)
    return m.finish()


export_all([tower_a, tower_b, tower_c, block, billboard, pylon, deck, barrier, lamp, gantry, citylight, hood],
           OUT_DIR, PREVIEW)
