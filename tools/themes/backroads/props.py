"""Red Frontier props (region id `backroads`): a Mars homestead at dusk.

Greenhouse domes (a big one, a connected pair, and a small pod Godot scatters), crop tubes
that repeat in rows where the wheat fields were, lattice power pylons whose cables tile,
pressurised habitat modules with warm lit windows, a habitat hub with a rooftop greenhouse,
twin water-ice silos, a landing pad with beacon lights and a parked cargo shuttle, dust
turbines (the rotor is its own model so the world script can spin it), rocks, boulders, dunes,
roadside marker posts, and the player's pressurised rover hood.

High-detail pass (2026-11-10): each prop is built to read as a real object up close: hull
plating with seam bands, framed windows and airlock doors with lit glass, stairs, caged ladders,
railings, dishes and whip antennae, utility pipes on supports running out to the domes, lattice
towers of angle iron with insulator strings and clamps, ribbed silos on a hopper, a pad with
kerbs, markings and lights, a shuttle with a lofted hull, engine bells and landing legs, and
rocks chipped into facets and stacked in strata. Red dust lies banked against the footings.

Finish: propkit's blanket 3 cm bevel is replaced here by a per-part one (Kit and done()). Parts
made with bev=True (boxes, frames, bands: the hard-surface parts that catch the light) get the
same 3 cm two-segment bevel; everything else (lattice members, ribs, cables, rock facets) keeps
crisp edges, marked sharp so flat faces stay flat. The triangle budget goes on visible structure
instead of on bevelling hundreds of thin members whose edges nobody can see.

Material names pick the game's surface maps (ThemeWorld.SURFACE_KEYWORDS, plus `surfaces` in
game/scripts/themes/backroads.gd): hull/plate -> riveted panel, steel -> brushed, footing/slab ->
concrete, rock -> rock, ice -> ice, solar -> cell grid, dune -> wind ripples. Avoid names that
contain a keyword by accident ("lattice" contains "ice").
Materials named beacon_* blink in game/scripts/themes/backroads.gd, so the hood has none.
Run: blender --background --python tools/themes/backroads/props.py -- game/assets/themes/backroads/models [preview.png]
"""
import math
import pathlib
import random
import sys

import bmesh
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset  # noqa: E402

PYLON_SPACING = 30.0  # must match PYLON_SPACING in game/scripts/themes/backroads.gd
CROP_TILE = 18.0  # must match CROP_TILE in game/scripts/themes/backroads.gd (a 14-long tube and a gap)
MARKER_SPACING = 12.0  # must match MARKER_SPACING in game/scripts/themes/backroads.gd
TURBINE_HUB = (0.0, -1.4, 17.0)  # rotor position; the world script mounts the rotor at Godot (0, 17, 1.4)
OUT_DIR, PREVIEW = args()
reset()

Z = Vector((0.0, 0.0, 1.0))
ALONG_Y = (math.radians(90), 0, 0)  # turns a cylinder's axis from Z to Y (its top end toward -Y)
ALONG_X = (0, math.radians(90), 0)  # turns a cylinder's axis from Z to +X

# Weathered (opaque) materials; the name picks the surface map in the game.
HULL = material("hull", (0.60, 0.56, 0.50), rough=0.55, metal=0.25)
HULL_DARK = material("hull_dark", (0.17, 0.16, 0.15), rough=0.5, metal=0.5)
TRIM = material("trim_steel", (0.09, 0.085, 0.08), rough=0.42, metal=0.8)
STEEL = material("steel", (0.34, 0.33, 0.32), rough=0.38, metal=0.9)
ORANGE = material("orange_plate", (0.78, 0.26, 0.05), rough=0.5, metal=0.15)
CONCRETE = material("footing_sinter", (0.42, 0.25, 0.18), rough=0.92)
# Satin, not glossy: glossy solar caps on the marker posts flashed the low sun back at the driver.
SOLAR = material("solar", (0.025, 0.04, 0.12), rough=0.5, metal=0.25)
# A deeper, cooler blue than looks right in a neutral light: under the pink dusk ambient a paler
# frost read as beige.
ICE = material("ice", (0.40, 0.57, 0.76), rough=0.38, metal=0.15)
PAD = material("slab_pad", (0.12, 0.10, 0.095), rough=0.85)
PAD_PAINT = material("slab_paint", (0.62, 0.42, 0.16), rough=0.7)
ROCK = material("rock", (0.21, 0.085, 0.05), rough=0.95)
ROCK_DARK = material("rock_dark", (0.10, 0.045, 0.032), rough=0.95)
DUNE = material("dune", (0.34, 0.13, 0.065), rough=1.0)
CABLE = material("cable", (0.04, 0.035, 0.035), rough=0.5, metal=0.5)
INSULATOR = material("insulator", (0.25, 0.42, 0.40), rough=0.2)
# The hood is never weathered, so its names pick nothing.
ROVER = material("rover", (0.30, 0.25, 0.21), rough=0.6, metal=0.1)
FRAME = material("frame", (0.06, 0.055, 0.055), rough=0.5, metal=0.5)
# Emissive palette. Strength is HDR: above 1.0 it blooms through the glow pass.
WINDOW = material("window", (1.0, 0.66, 0.32), emit=(1.0, 0.62, 0.28), strength=4.5)
COCKPIT = material("cockpit", (0.95, 0.88, 0.72), emit=(0.95, 0.86, 0.68), strength=3.0)
# Grow lights: saturated and only just over the bloom threshold. Brighter, the rows of crop tubes
# washed out to white and glared beside the keys.
GROW = material("grow", (0.05, 0.16, 0.04), emit=(0.16, 0.78, 0.1), strength=1.15)
GROW_DIM = material("grow_dim", (0.04, 0.1, 0.03), emit=(0.1, 0.5, 0.06), strength=0.8)
GROW_GOLD = material("grow_gold", (0.12, 0.07, 0.02), emit=(0.95, 0.48, 0.07), strength=0.8)
BEACON_RED = material("beacon_red", (1.0, 0.1, 0.05), emit=(1.0, 0.1, 0.05), strength=9.0)
BEACON_AMBER = material("beacon_amber", (1.0, 0.5, 0.08), emit=(1.0, 0.48, 0.08), strength=6.0)
NAV_GREEN = material("nav_green", (0.3, 1.0, 0.4), emit=(0.3, 1.0, 0.4), strength=6.0)
STATUS = material("status", (0.6, 0.8, 1.0), emit=(0.55, 0.78, 1.0), strength=3.0)
ENGINE = material("engine", (0.8, 0.72, 1.0), emit=(0.78, 0.7, 1.0), strength=2.4)
LAMP = material("lamp", (1.0, 0.9, 0.74), emit=(1.0, 0.88, 0.7), strength=9.0)
# The hood's lamp-top bars sit right beside the outer keys, so they only just glow.
LAMP_BAR = material("lamp_bar", (0.5, 0.42, 0.32), emit=(1.0, 0.78, 0.5), strength=0.9)
MARKER = material("marker", (1.0, 0.5, 0.1), emit=(1.0, 0.46, 0.08), strength=3.5)
REFLECT = material("reflector", (1.0, 0.55, 0.15), emit=(1.0, 0.5, 0.12), strength=1.6)


# ---------------------------------------------------------------- kit: per-part finish and shapes

def rect(w, h=None):
    h = w if h is None else h
    return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]


def diamond(r):
    return [(r, 0.0), (0.0, r), (-r, 0.0), (0.0, -r)]


def circle(r, n=8):
    return [(r * math.cos(2 * math.pi * k / n), r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def facing(n):
    """Euler angles that turn a box's local +X toward direction n, its local Z kept as upright as it can."""
    n = Vector(n).normalized()
    return (0.0, -math.asin(max(-1.0, min(1.0, n.z))), math.atan2(n.y, n.x))


class Kit(Model):
    """Model with a per-part finish (see done()). `bevel` is the width parts made with bev=True get;
    edges sharper than `smooth_below` degrees elsewhere are marked sharp, except between faces of
    `smooth_mats` (cables stay round)."""

    def __init__(self, name, bevel=0.03, smooth_below=35.0, smooth_mats=()):
        super().__init__(name)
        self.width = bevel
        self.smooth_below = math.radians(smooth_below)
        self.smooth_mats = list(smooth_mats)
        self.soft = set()
        self._last = []

    def mat_index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _paint(self, verts, mat):
        super()._paint(verts, mat)
        self._last = list(verts)

    def _keep(self, bev):
        if bev:
            self.soft.update(self._last)

    def box(self, size, loc, mat, rot=(0, 0, 0), bev=True):
        super().box(size, loc, mat, rot)
        self._keep(bev)

    def cyl(self, r1, r2, h, loc, mat, segs=12, rot=(0, 0, 0), bev=True):
        super().cyl(r1, r2, h, loc, mat, segs, rot)
        self._keep(bev)

    def beam(self, a, b, r, mat, segs=6, bev=False):
        a, b = Vector(a), Vector(b)
        rot = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_euler()
        self.cyl(r, r, (b - a).length, (a + b) / 2, mat, segs=segs, rot=rot, bev=bev)

    def poly(self, verts, faces, mat, bev=False):
        super().poly(verts, faces, mat)
        self._keep(bev)

    def faces(self, verts, faces, mats, bev=False):
        """One connected surface with its own material per face."""
        vs = [self.bm.verts.new(v) for v in verts]
        for f, mat in zip(faces, mats):
            self.bm.faces.new([vs[i] for i in f]).material_index = self.mat_index(mat)
        if bev:
            self.soft.update(vs)
        return vs

    def sweep(self, path, profile, mat, closed=False, caps=True, up=(0, 0, 1), bev=False):
        """A 2D profile (u across, v up) swept along a polyline, its frame carried round bends by
        parallel transport so round profiles never twist."""
        pts = [Vector(p) for p in path]
        n = len(pts)

        def tangent(i):
            if closed:
                return (pts[(i + 1) % n] - pts[(i - 1) % n]).normalized()
            return (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()

        t = tangent(0)
        side = t.cross(Vector(up))
        if side.length < 1e-5:
            side = t.cross(Vector((1.0, 0.0, 0.0)))
        side.normalize()
        rings, prev = [], t
        for i in range(n):
            t = tangent(i)
            side = prev.rotation_difference(t) @ side
            side = (side - t * side.dot(t)).normalized()
            nrm = side.cross(t).normalized()
            rings.append([self.bm.verts.new(pts[i] + side * u + nrm * v) for u, v in profile])
            prev = t
        idx, k = self.mat_index(mat), len(profile)
        for i in range(n if closed else n - 1):
            a, b = rings[i], rings[(i + 1) % n]
            for j in range(k):
                self.bm.faces.new((a[j], a[(j + 1) % k], b[(j + 1) % k], b[j])).material_index = idx
        if caps and not closed:
            for ring in (rings[0], rings[-1]):
                self.bm.faces.new(ring).material_index = idx
        if bev:
            self.soft.update(v for ring in rings for v in ring)

    def strut(self, a, b, w, mat, h=None, up=(0, 0, 1), caps=False, bev=False):
        """A straight rectangular member from a to b; open-ended, as its ends hide in the joints."""
        self.sweep([a, b], rect(w, h), mat, caps=caps, up=up, bev=bev)

    def lathe(self, prof, loc, mat, segs=16, rot=(0, 0, 0), mats=None, bev=False):
        """(radius, height) points revolved round local Z; a radius of 0 closes to a pole."""
        mtx = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4()
        rings = []
        for r, z in prof:
            if r <= 1e-6:
                rings.append([self.bm.verts.new(mtx @ Vector((0.0, 0.0, z)))])
            else:
                rings.append([self.bm.verts.new(mtx @ Vector((r * math.cos(2 * math.pi * s / segs),
                                                              r * math.sin(2 * math.pi * s / segs), z)))
                              for s in range(segs)])
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            idx = self.mat_index(mats[i] if mats else mat)
            for s in range(segs):
                s1 = (s + 1) % segs
                if len(a) == 1:
                    f = (a[0], b[s1], b[s])
                elif len(b) == 1:
                    f = (a[s], a[s1], b[0])
                else:
                    f = (a[s], a[s1], b[s1], b[s])
                self.bm.faces.new(f).material_index = idx
        if bev:
            self.soft.update(v for ring in rings for v in ring)


def done(m):
    """Finishes a Kit: sharp edges of bev=True parts get bevel weights (a WEIGHT-limited 3 cm bevel
    with hardened normals, as propkit's own), every other sharp edge is marked sharp. propkit's
    blanket bevel is switched off (obj["bevel"] = 0); its weighted-normal pass still runs after."""
    bm = m.bm
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    weight = bm.edges.layers.float.get("bevel_weight_edge") or bm.edges.layers.float.new("bevel_weight_edge")
    keep_round = {m.mats.index(x) for x in m.smooth_mats if x in m.mats}
    bevelled = 0
    for e in bm.edges:
        if len(e.link_faces) != 2 or e.calc_face_angle(0.0) <= m.smooth_below:
            continue
        if keep_round and all(f.material_index in keep_round for f in e.link_faces):
            continue
        if m.width > 0 and e.verts[0] in m.soft and e.verts[1] in m.soft:
            e[weight] = 1.0
            bevelled += 1
        else:
            e.smooth = False
    obj = m.finish()
    obj["bevel"] = 0
    if bevelled:
        mod = obj.modifiers.new("soft_bevel", "BEVEL")
        mod.width = m.width
        mod.segments = 2
        mod.limit_method = "WEIGHT"
        mod.use_clamp_overlap = True
        mod.harden_normals = True
    return obj


# ---------------------------------------------------------------- shared parts

def angle_iron(m, a, b, fx, fy, w, t, mat):
    """An L-section member (a lattice tower's leg): the corner on the line a-b, flanges toward fx, fy."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    u = Vector(fx)
    u = (u - d * u.dot(d)).normalized()
    v = Vector(fy)
    v = v - d * v.dot(d)
    v = (v - u * v.dot(u)).normalized()
    prof = [(0, 0), (w, 0), (w, t), (t, t), (t, w), (0, w)]
    verts = [p + u * pu + v * pv for p in (a, b) for pu, pv in prof]
    n = len(prof)
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces += [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    m.faces(verts, faces, [mat] * len(faces))


def annulus(m, r0, r1, z0, z1, mat, segs=32):
    """A flat ring with thickness (painted markings): closed, so its normals always face out."""
    verts = []
    for z in (z0, z1):
        for rad in (r0, r1):
            verts += [(rad * math.cos(2 * math.pi * k / segs), rad * math.sin(2 * math.pi * k / segs), z)
                      for k in range(segs)]
    bi, bo, ti, to = 0, segs, 2 * segs, 3 * segs
    faces = []
    for k in range(segs):
        k1 = (k + 1) % segs
        faces += [(bi + k, bo + k, bo + k1, bi + k1), (ti + k, ti + k1, to + k1, to + k),
                  (bo + k, to + k, to + k1, bo + k1), (bi + k, bi + k1, ti + k1, ti + k)]
    m.faces(verts, faces, [mat] * len(faces))


def window(m, at, n, w, h, glass=WINDOW, frame=TRIM, brow=HULL):
    """A lit window: a dark frame plate on the wall at `at` (facing n), the glass proud of it, and a
    sun brow above."""
    at, n = Vector(at), Vector(n).normalized()
    rot = facing(n)
    m.box((0.14, w + 0.2, h + 0.2), at + n * 0.03, frame, rot=rot)
    m.box((0.05, w, h), at + n * 0.1, glass, rot=rot, bev=False)
    if brow:
        m.box((0.34, w + 0.34, 0.06), at + n * 0.2 + Z * (h / 2 + 0.17), brow, rot=rot)


def door(m, at, n, w, h, leaf=HULL, glass=WINDOW, frame=TRIM, light=None, glass_size=(0.6, 0.42)):
    """A framed door whose foot is at `at` on its wall, facing n: frame, leaf, a lit window in the
    leaf, and an optional lamp above."""
    at, n = Vector(at), Vector(n).normalized()
    rot = facing(n)
    m.box((0.18, w + 0.3, h + 0.18), at + n * 0.05 + Z * ((h + 0.18) / 2), frame, rot=rot)
    m.box((0.08, w, h), at + n * 0.17 + Z * (h / 2), leaf, rot=rot)
    if glass:
        gw, gh = glass_size
        m.box((0.05, w * gw, h * gh), at + n * 0.22 + Z * (h * (1.0 - gh / 2 - 0.08)), glass, rot=rot, bev=False)
    if light:
        m.box((0.12, 0.42, 0.1), at + n * 0.2 + Z * (h + 0.3), light, rot=rot, bev=False)


def ladder(m, foot, top, along, out, width=0.46, step=0.3, cage_from=None, mat=TRIM):
    """A ladder: rails `width` apart along `along` from `foot` (the ground point between them) up to
    `top`, standing off its wall toward `out`; a safety cage of hoops from `cage_from` up."""
    foot, al, o = Vector(foot), Vector(along).normalized(), Vector(out).normalized()
    rise = top - foot.z
    for s in (-1, 1):
        p = foot + al * (s * width / 2)
        m.strut(p, p + Z * rise, 0.06, mat)
    z = step
    while z < rise - 0.25:
        m.strut(foot + al * (-width / 2) + Z * z, foot + al * (width / 2) + Z * z, 0.035, mat)
        z += step
    if cage_from is not None:
        c = foot + o * 0.32
        z = cage_from
        while z < top - 0.2:
            hoop = [c + al * (0.42 * math.cos(math.radians(a))) + o * (0.42 * math.sin(math.radians(a)))
                    + Z * (z - foot.z) for a in range(-15, 196, 35)]
            m.sweep(hoop, diamond(0.024), mat)
            z += 0.9
        for a in (40, 90, 140):
            p = c + al * (0.42 * math.cos(math.radians(a))) + o * (0.42 * math.sin(math.radians(a)))
            m.strut(p + Z * (cage_from - foot.z), p + Z * rise, 0.04, mat)


def railing(m, pts, height=1.0, mat=TRIM, closed=False, post_every=1):
    """Posts at the points (every `post_every`th) with a top rail and a knee rail."""
    pts = [Vector(p) for p in pts]
    for i, p in enumerate(pts):
        if i % post_every == 0:
            m.strut(p, p + Z * height, 0.05, mat)
    for h in (height, height * 0.5):
        m.sweep([p + Z * h for p in pts], diamond(0.03), mat, closed=closed)


def dish(m, at, aim, radius, mat, struts=TRIM):
    """A parabolic dish at `at` looking along `aim`, its feed horn held on three struts."""
    at, aim = Vector(at), Vector(aim).normalized()
    q = Z.rotation_difference(aim)
    rot = q.to_euler()
    m.lathe([(0.0, 0.0), (radius * 0.35, radius * 0.04), (radius * 0.7, radius * 0.16), (radius, radius * 0.34)],
            at, mat, segs=14, rot=rot)
    focus = at + aim * (radius * 0.72)
    for k in range(3):
        a = 2 * math.pi * k / 3
        rim = at + q @ Vector((radius * 0.95 * math.cos(a), radius * 0.95 * math.sin(a), radius * 0.31))
        m.strut(rim, focus, 0.035, struts)
    m.cyl(0.07, 0.11, 0.18, focus, struts, segs=8, rot=rot, bev=False)


def pipe_supports(m, x0, x1, ys, z, mat=TRIM):
    """Little H-frames under a pipe run along Y: two posts and a cross bar at height z."""
    for y in ys:
        for x in (x0, x1):
            m.strut((x, y, -0.05), (x, y, z), 0.08, mat)
        m.strut((x0 - 0.06, y, z), (x1 + 0.06, y, z), 0.09, mat, h=0.07)


def dome_shell(m, r, loc, segs, rings, panes, seed, rib=0.07, rib_mat=TRIM):
    """A geodesic-looking greenhouse dome: rings of triangles, every other ring turned half a step,
    each pane picked from `panes` (repeat an entry to weight it), and a crisp rib on every edge
    standing a little proud of the panes."""
    rr = random.Random(seed)
    cx, cy, cz = loc
    verts, rings_idx = [], []
    for k in range(rings):
        phi = (math.pi / 2) * k / rings
        off = (math.pi / segs) * (k % 2)
        idx = []
        for s in range(segs):
            th = 2 * math.pi * s / segs + off
            idx.append(len(verts))
            verts.append((cx + r * math.cos(phi) * math.cos(th), cy + r * math.cos(phi) * math.sin(th),
                          cz + r * math.sin(phi)))
        rings_idx.append(idx)
    apex = len(verts)
    verts.append((cx, cy, cz + r))
    faces = []
    for k in range(rings - 1):
        a, b = rings_idx[k], rings_idx[k + 1]
        for s in range(segs):
            s1 = (s + 1) % segs
            if k % 2 == 0:  # the upper ring is turned half a step: b[s] sits between a[s] and a[s1]
                faces += [(a[s], a[s1], b[s]), (a[s1], b[s1], b[s])]
            else:  # the lower ring is turned: a[s] sits between b[s] and b[s1]
                faces += [(a[s], b[s1], b[s]), (a[s], a[s1], b[s1])]
    top = rings_idx[-1]
    for s in range(segs):
        faces.append((top[s], top[(s + 1) % segs], apex))
    m.faces(verts, faces, [rr.choice(panes) for _ in faces])
    if rib:
        c = Vector(loc)
        edges = {tuple(sorted((f[i], f[(i + 1) % len(f)]))) for f in faces for i in range(len(f))}
        for a_i, b_i in sorted(edges):
            a, b = Vector(verts[a_i]), Vector(verts[b_i])
            out_a, out_b = (a - c).normalized() * rib * 0.5, (b - c).normalized() * rib * 0.5
            m.strut(a + out_a, b + out_b, rib * 2.0, rib_mat, h=rib * 1.4, up=tuple((a + b) / 2 - c))


def stone(m, size, loc, mat, rr, subdiv=2, cuts=5):
    """A rock: a lumpy icosphere chipped flat by `cuts` random planes (fresh fracture faces), scaled."""
    c = Vector(loc)
    vs = bmesh.ops.create_icosphere(m.bm, subdivisions=subdiv, radius=1.0)["verts"]
    planes = []
    for _ in range(cuts):
        n = Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.15, 1.0)))
        planes.append(((n if n.length > 1e-3 else Z).normalized(), rr.uniform(0.55, 0.85)))
    # Smooth lumps (a few long waves), not per-vertex jitter: at high subdivision jitter turned the
    # surface to gravel and the plane cuts into stair-steps.
    waves = [(Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-1, 1))).normalized() * rr.uniform(1.5, 3.2),
              rr.uniform(0, 2 * math.pi), rr.uniform(0.04, 0.09)) for _ in range(4)]
    for v in vs:
        p = v.co * (1.0 + sum(a * math.sin(v.co.dot(k) + ph) for k, ph, a in waves))
        for n, d in planes:
            h = p.dot(n)
            if h > d:
                p = p - n * (h - d)
        v.co = c + Vector((p.x * size[0], p.y * size[1], p.z * size[2]))
    m._paint(vs, mat)


def strata(m, loc, radius, layers, mats, rr, sides=9, thick=(0.22, 0.4), taper=0.84):
    """Layered regolith: a stack of ragged slabs, each a little smaller and offset, edges eroded."""
    x, y, z = loc
    r = radius
    for i in range(layers):
        th = rr.uniform(*thick)
        a0 = rr.uniform(0, 2 * math.pi)
        outline = []
        for k in range(sides):
            a = a0 + 2 * math.pi * k / sides + rr.uniform(-0.2, 0.2)
            rad = r * rr.uniform(0.78, 1.12)
            outline.append((math.cos(a) * rad, math.sin(a) * rad))
        dx, dy = rr.uniform(-0.12, 0.12) * r, rr.uniform(-0.12, 0.12) * r
        verts = [(x + dx + px, y + dy + py, z) for px, py in outline]
        verts += [(x + dx + px * 0.9, y + dy + py * 0.9, z + th) for px, py in outline]
        faces = [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
        faces += [tuple(range(sides - 1, -1, -1)), tuple(range(sides, 2 * sides))]
        m.faces(verts, faces, [mats[i % len(mats)]] * len(faces))
        z += th * 0.96
        r *= taper * rr.uniform(0.92, 1.04)


# ---------------------------------------------------------------- props

def pylon():
    """A lattice transmission tower ("wine glass"): four angle-iron legs on concrete footings with dust
    banked round them, X-braced panels up to a waist, two V arms holding a truss cross-arm, earth-wire
    peaks, a red beacon, three insulator strings with clamps and grading rings, and the cables, which
    reach exactly to the next pylon so the repeats join up. No bevel: thin members, crisp edges."""
    m = Kit("pylon", bevel=0.0, smooth_below=50.0, smooth_mats=(CABLE,))
    waist, arm_z, beam_top = 9.0, 13.2, 14.2

    def body(sx, sy, z):  # a corner of the lower body at height z
        t = (z - 0.4) / (waist - 0.4)
        return Vector((sx * (2.3 - 1.55 * t), sy * (1.9 - 1.15 * t), z))

    for sx in (-1, 1):
        for sy in (-1, 1):
            p = body(sx, sy, 0.4)
            m.box((0.75, 0.75, 0.55), (p.x, p.y, 0.17), CONCRETE)
            m.cyl(0.9, 0.42, 0.24, (p.x, p.y, 0.05), CONCRETE, segs=8)
            m.box((0.42, 0.42, 0.06), (p.x, p.y, 0.47), STEEL)
            angle_iron(m, p, body(sx, sy, waist), (-sx, 0, 0), (0, -sy, 0), 0.24, 0.05, STEEL)
    levels = [0.4, 3.1, 5.4, 7.4, waist]
    for i in range(4):
        z0, z1 = levels[i], levels[i + 1]
        for face in ((-1, -1, 1, -1), (-1, 1, 1, 1), (-1, -1, -1, 1), (1, -1, 1, 1)):
            a0, b0 = body(face[0], face[1], z0), body(face[2], face[3], z0)
            a1, b1 = body(face[0], face[1], z1), body(face[2], face[3], z1)
            m.strut(a1, b1, 0.1, STEEL)
            m.strut(a0, b1, 0.08, STEEL)
            m.strut(b0, a1, 0.08, STEEL)
    for z in (5.4, waist):
        m.strut(body(-1, -1, z), body(1, 1, z), 0.07, STEEL)
        m.strut(body(1, -1, z), body(-1, 1, z), 0.07, STEEL)

    for sx in (-1, 1):
        def chord(sy, outer, z):  # the V arm's chords, from the waist corner up to the cross-arm
            t = (z - waist) / (arm_z - waist)
            x_top = 2.9 if outer else 1.35
            return Vector((sx * (0.75 + (x_top - 0.75) * t), sy * (0.75 - 0.15 * t), z))

        zs = [waist, 10.5, 11.9, arm_z]
        for sy in (-1, 1):
            angle_iron(m, chord(sy, True, waist), chord(sy, True, arm_z), (-sx, 0, 0), (0, -sy, 0), 0.2, 0.045, STEEL)
            m.strut(chord(sy, False, waist), chord(sy, False, arm_z), 0.12, STEEL)
            for k in range(3):
                za, zb = zs[k], zs[k + 1]
                m.strut(chord(sy, True, zb), chord(sy, False, zb), 0.08, STEEL)
                m.strut(chord(sy, k % 2 == 0, za), chord(sy, k % 2 == 1, zb), 0.07, STEEL)
        for z in (10.5, 11.9):
            for outer in (True, False):
                m.strut(chord(-1, outer, z), chord(1, outer, z), 0.07, STEEL)

    x_end, x_top = 5.0, 4.4
    for sy in (-1, 1):
        y = sy * 0.6
        m.strut((-x_end, y, arm_z), (x_end, y, arm_z), 0.13, STEEL)
        m.strut((-x_top, y, beam_top), (x_top, y, beam_top), 0.11, STEEL)
        for s in (-1, 1):
            m.strut((s * x_top, y, beam_top), (s * x_end, y, arm_z), 0.1, STEEL)
        xs = [-x_top + i * (2 * x_top / 8) for i in range(9)]
        for i in range(8):
            lo, hi = (xs[i], xs[i + 1]) if i % 2 == 0 else (xs[i + 1], xs[i])
            m.strut((lo, y, arm_z), (hi, y, beam_top), 0.07, STEEL)
    for x in (-x_top, -2.2, 0.0, 2.2, x_top):
        m.strut((x, -0.6, arm_z), (x, 0.6, arm_z), 0.07, STEEL)
        m.strut((x, -0.6, beam_top), (x, 0.6, beam_top), 0.07, STEEL)
    for i in range(4):
        x0, x1 = -x_top + i * 2.2, -x_top + (i + 1) * 2.2
        m.strut((x0, -0.6, arm_z), (x1, 0.6, arm_z), 0.06, STEEL)
    for sx in (-1, 1):
        apex = Vector((sx * 2.9, 0.0, 15.7))
        for dx in (-0.45, 0.45):
            for sy in (-1, 1):
                m.strut((sx * 2.9 + dx, sy * 0.6, beam_top), apex, 0.08, STEEL)
        m.box((0.16, 0.3, 0.12), apex, TRIM)
    m.strut((0, 0, beam_top), (0, 0, 15.6), 0.1, STEEL)
    m.box((0.36, 0.36, 0.36), (0, 0, 15.75), BEACON_RED)

    attach = arm_z - 1.75
    for x in (-x_top, 0.0, x_top):
        m.box((0.12, 0.22, 0.22), (x, 0, arm_z - 0.14), TRIM)
        m.strut((x, 0, arm_z - 0.2), (x, 0, attach + 0.1), 0.035, TRIM)
        for k in range(7):
            m.cyl(0.17, 0.11, 0.07, (x, 0, arm_z - 0.42 - k * 0.165), INSULATOR, segs=8)
        m.box((0.14, 0.42, 0.12), (x, 0, attach + 0.05), TRIM)
        m.sweep([(x + 0.3 * math.cos(2 * math.pi * k / 8), 0.3 * math.sin(2 * math.pi * k / 8), attach + 0.24)
                 for k in range(8)], diamond(0.025), TRIM, closed=True)

    def span(x, z, sag, n=16):
        return [(x, PYLON_SPACING * i / n, z - sag * 4 * (i / n) * (1 - i / n)) for i in range(n + 1)]

    for x in (-x_top, 0.0, x_top):
        m.sweep(span(x, attach, 1.9), diamond(0.04), CABLE)
    for sx in (-1, 1):
        m.sweep(span(sx * 2.9, 15.65, 1.1), diamond(0.022), CABLE)
    return done(m)


def marker():
    """A roadside marker post: a ground sleeve in a little drift of dust, a composite post, an amber
    reflector in a housing facing the road (-X), a tilted solar cap and a mesh-net whip antenna."""
    m = Kit("marker")
    m.cyl(0.3, 0.1, 0.14, (0, 0, 0.0), CONCRETE, segs=8, bev=False)
    m.box((0.22, 0.22, 0.26), (0, 0, 0.12), TRIM)
    m.box((0.14, 0.14, 1.0), (0, 0, 0.62), HULL)
    m.box((0.18, 0.18, 0.04), (0, 0, 0.34), TRIM)
    m.box((0.05, 0.17, 0.32), (-0.085, 0, 0.86), TRIM)
    m.box((0.03, 0.12, 0.25), (-0.11, 0, 0.86), REFLECT, bev=False)
    # Tilted toward the sun ahead (+Y), away from the driver, so it cannot flash at them.
    tilt = (math.radians(-14), 0, 0)
    m.box((0.32, 0.32, 0.04), (0, 0, 1.15), TRIM, rot=tilt)
    m.box((0.27, 0.27, 0.02), (0, 0.005, 1.175), SOLAR, rot=tilt, bev=False)
    m.strut((0.09, 0.09, 1.1), (0.09, 0.09, 1.62), 0.016, TRIM)
    m.box((0.035, 0.035, 0.035), (0.09, 0.09, 1.63), TRIM, bev=False)
    return done(m)


def crop_tube(name, glow):
    """One crop tube, 14 long, half sunk in the regolith: a lit tunnel under arched ribs and three
    purlins, on sintered kerbs with dust drifted against them, an airlock at the near end (-Y, toward
    the driver) with a framed lit door, a utility pipe on brackets, and a fan housing at the far end.
    The world script lays these in rows, CROP_TILE apart."""
    m = Kit(name, smooth_below=40.0)
    length, r = 14.0, 1.6
    half = length / 2
    n = 16

    def arch(rad, y):
        return [(rad * math.cos(math.pi * k / n), y, rad * math.sin(math.pi * k / n) - 0.05) for k in range(n + 1)]

    verts = arch(r, -half) + arch(r, half)
    faces = [(k, k + 1, n + 2 + k, n + 1 + k) for k in range(n)]
    faces += [tuple(range(n + 1)), tuple(range(2 * n + 1, n, -1)), (0, n + 1, 2 * n + 1, n)]
    m.faces(verts, faces, [glow] * len(faces))
    for k in range(8):
        y = -half + 0.25 + k * (length - 0.5) / 7
        m.sweep(arch(r + 0.06, y), rect(0.14, 0.12), TRIM)
    for ang in (50, 90, 130):
        a = math.radians(ang)
        c = Vector((math.cos(a) * (r + 0.04), 0, math.sin(a) * (r + 0.04) - 0.05))
        m.strut(c + Vector((0, -half, 0)), c + Vector((0, half, 0)), 0.08, TRIM, h=0.05,
                up=(math.cos(a), 0, math.sin(a)))
    for sx in (-1, 1):
        m.box((0.45, length + 0.3, 0.32), (sx * (r + 0.12), 0, 0.1), CONCRETE, bev=False)
        x0, x1 = sx * (r + 0.34), sx * (r + 1.64)
        m.faces([(x0, -half, -0.05), (x0, half, -0.05), (x0, half, 0.26), (x0, -half, 0.26),
                 (x1, -half, -0.05), (x1, half, -0.05)],
                [(0, 1, 2, 3), (0, 4, 5, 1), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2)], [CONCRETE] * 5)
    y0 = -half - 0.65
    m.box((1.9, 1.3, 2.0), (0, y0, 0.95), HULL)
    m.box((2.05, 1.45, 0.12), (0, y0, 2.0), TRIM)
    door(m, (0, y0 - 0.65, 0.0), (0, -1, 0), 0.85, 1.55, leaf=HULL, glass=WINDOW, glass_size=(0.75, 0.55))
    m.box((0.5, 0.5, 0.28), (0.45, y0 + 0.1, 2.2), TRIM)
    m.cyl(0.12, 0.12, 0.4, (-0.5, y0 + 0.25, 2.25), TRIM, segs=8, bev=False)
    m.box((1.2, 0.5, 0.15), (0, y0 - 1.0, 0.05), CONCRETE)
    px = -(r + 0.45)
    m.sweep([(px, half + 0.2, 0.42), (px, -half - 0.7, 0.42), (px + 0.2, -half - 0.9, 0.42), (-0.9, -half - 0.9, 0.42)],
            circle(0.1, 8), TRIM)
    for y in (-4.5, -0.5, 3.5):
        m.box((0.1, 0.1, 0.36), (px, y, 0.22), TRIM, bev=False)
    m.cyl(0.5, 0.5, 0.25, (0, half + 0.1, 0.85), TRIM, segs=12, rot=ALONG_Y)
    m.cyl(0.38, 0.38, 0.06, (0, half + 0.24, 0.85), HULL, segs=12, rot=ALONG_Y, bev=False)
    return done(m)


def crop_tube_green():
    return crop_tube("crop_tube", GROW)


def crop_tube_gold():
    return crop_tube("crop_tube_gold", GROW_GOLD)


def pod():
    """A small greenhouse pod. Godot scatters these across the plain (a MultiMesh), so it stays cheap:
    no bevel, crisp ribs."""
    m = Kit("pod", bevel=0.0, smooth_below=40.0)
    r = 1.3
    m.cyl(r + 0.1, r + 0.16, 0.32, (0, 0, 0.12), HULL, segs=10)
    m.cyl(r + 0.04, r + 0.04, 0.06, (0, 0, 0.3), TRIM, segs=10)
    dome_shell(m, r, (0, 0, 0.3), 8, 2, [GROW, GROW, GROW_GOLD, GROW_DIM], seed=21, rib=0.045)
    m.box((0.62, 0.55, 0.72), (-r - 0.12, 0, 0.36), HULL)
    m.box((0.05, 0.34, 0.4), (-r - 0.45, 0, 0.4), GROW_GOLD)
    m.cyl(0.07, 0.07, 0.4, (0.35, 0.3, r + 0.35), TRIM, segs=6)
    return done(m)


def dome():
    """The big greenhouse: a glowing geodesic dome on a sintered ring wall with buttresses and a
    steel sill, dust banked round it, a vent cupola, an airlock vestibule toward the road (-X) with a
    lit glazed door, and a pair of utility pipes on supports arriving from -Y into a manifold."""
    m = Kit("dome")
    r, base = 7.5, 0.75
    m.cyl(r + 0.3, r + 0.3, base, (0, 0, base / 2), CONCRETE, segs=24)
    m.cyl(r + 1.5, r + 0.35, 0.4, (0, 0, 0.08), CONCRETE, segs=24, bev=False)
    m.cyl(r + 0.12, r + 0.12, 0.16, (0, 0, base + 0.05), TRIM, segs=24)
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        if abs(math.cos(a) + 1) < 0.2:
            continue  # the airlock side
        m.box((0.6, 0.45, 0.95), ((r + 0.5) * math.cos(a), (r + 0.5) * math.sin(a), 0.42), CONCRETE, rot=(0, 0, a))
    dome_shell(m, r, (0, 0, base - 0.1), 16, 5, [GROW, GROW, GROW, GROW_DIM, GROW_DIM, HULL], seed=5, rib=0.08)
    top = base - 0.1 + r
    m.cyl(1.0, 1.0, 0.45, (0, 0, top - 0.05), TRIM, segs=12)
    m.cyl(1.15, 0.45, 0.4, (0, 0, top + 0.38), HULL, segs=12)
    m.strut((0.6, 0.0, top + 0.2), (0.6, 0.0, top + 2.0), 0.03, TRIM)

    ax = -r - 1.2
    m.box((3.0, 3.0, 2.6), (ax, 0, 1.3), HULL)
    m.box((3.2, 3.2, 0.16), (ax, 0, 2.66), TRIM)
    door(m, (ax - 1.5, 0, 0.2), (-1, 0, 0), 1.1, 1.85, leaf=TRIM, glass=WINDOW, light=WINDOW, glass_size=(0.82, 0.8))
    m.box((1.0, 2.2, 0.1), (ax - 1.95, 0, 2.45), HULL, rot=(0, math.radians(-6), 0))
    for y in (-0.9, 0.9):
        m.strut((ax - 2.4, y, 2.4), (ax - 1.5, y, 1.9), 0.06, TRIM)
    for sy in (-1, 1):
        window(m, (ax, sy * 1.5, 1.55), (0, sy, 0), 1.0, 0.5)
    m.box((1.2, 2.0, 0.2), (ax - 2.1, 0, 0.1), CONCRETE)
    m.box((1.0, 0.8, 0.5), (ax + 0.5, 0.6, 2.98), TRIM)
    m.cyl(0.15, 0.15, 0.5, (ax - 0.6, -0.8, 2.98), TRIM, segs=8, bev=False)

    for px, rad, mat in ((-3.3, 0.16, TRIM), (-2.8, 0.12, HULL)):
        m.sweep([(px, -15.0, -0.4), (px, -14.2, 0.45), (px, -7.9, 0.45)], circle(rad, 10), mat)
    m.box((1.1, 0.6, 0.9), (-3.05, -7.75, 0.5), TRIM)
    pipe_supports(m, -3.55, -2.55, (-13.0, -10.5), 0.29)
    return done(m)


def dome_pair():
    """Two smaller greenhouses joined by a banded corridor: one green-lit, one in a wheat-gold light,
    each on a ring wall with dust banked round it and a vent cap, a vestibule toward the road on the
    big one, and utility pipes arriving from -Y."""
    m = Kit("dome_pair")
    for (x, y, r, segs, rings, panes, seed) in ((0.0, -3.8, 5.0, 12, 4, [GROW, GROW, GROW, HULL], 9),
                                                 (1.2, 5.2, 3.3, 10, 3, [GROW_GOLD, GROW_GOLD, GROW_GOLD, HULL], 13)):
        m.cyl(r + 0.2, r + 0.2, 0.6, (x, y, 0.3), CONCRETE, segs=segs * 2)
        m.cyl(r + 1.1, r + 0.25, 0.32, (x, y, 0.05), CONCRETE, segs=segs * 2, bev=False)
        m.cyl(r + 0.08, r + 0.08, 0.12, (x, y, 0.62), TRIM, segs=segs * 2)
        dome_shell(m, r, (x, y, 0.55), segs, rings, panes, seed=seed, rib=0.065)
        m.cyl(0.55, 0.55, 0.3, (x, y, 0.55 + r - 0.02), TRIM, segs=10)
        m.cyl(0.65, 0.25, 0.25, (x, y, 0.55 + r + 0.2), HULL, segs=10)
    a, b = Vector((0.35, -0.6, 1.05)), Vector((0.95, 2.4, 1.05))
    m.sweep([a, b], circle(0.82, 12), HULL)
    d = (b - a).normalized()
    for f in (0.2, 0.5, 0.8):
        p = a.lerp(b, f)
        m.sweep([p - d * 0.1, p + d * 0.1], circle(0.9, 12), TRIM, bev=True)
    vx = -5.9
    m.box((2.6, 2.4, 2.3), (vx, -3.8, 1.15), HULL)
    m.box((2.8, 2.6, 0.14), (vx, -3.8, 2.35), TRIM)
    door(m, (vx - 1.3, -3.8, 0.15), (-1, 0, 0), 1.0, 1.7, leaf=TRIM, glass=WINDOW, light=WINDOW, glass_size=(0.82, 0.8))
    m.box((1.1, 1.9, 0.2), (vx - 1.85, -3.8, 0.1), CONCRETE)
    m.box((0.8, 0.7, 0.4), (vx + 0.4, -3.3, 2.6), TRIM)
    for px, rad, mat in ((-3.2, 0.15, TRIM), (-2.7, 0.11, HULL)):
        m.sweep([(px, -15.0, -0.4), (px, -14.2, 0.42), (px, -8.4, 0.42)], circle(rad, 10), mat)
    m.box((1.1, 0.6, 0.9), (-2.95, -8.3, 0.48), TRIM)
    pipe_supports(m, -3.45, -2.45, (-13.0, -10.6), 0.26)
    return done(m)


def habitat():
    """A pressurised habitat: a long module on A-frame legs, hull plating (the panel map) between seam
    bands, domed ends, a row of framed portholes with sun brows and an orange stripe on the road side
    (-X), an airlock with a framed lit door, landing, stairs and railings, an end hatch with a platform
    and ladder toward the driver (-Y), a smaller module behind on a tunnel, radiator panels, a dish and
    whip antennae on the roof, a solar wing, and two utility pipes running out along +Y to the domes."""
    m = Kit("habitat")
    r, length, zc = 2.4, 10.0, 3.3
    half = length / 2
    m.cyl(r, r, length, (0, 0, zc), HULL, segs=20, rot=ALONG_Y, bev=False)
    for s in (-1, 1):
        m.lathe([(r, 0.0), (r * 0.94, 0.35), (r * 0.74, 0.75), (r * 0.42, 1.0), (0.0, 1.08)], (0, s * half, zc), HULL,
                segs=20, rot=(math.radians(-90 * s), 0, 0))
    for y in (-4.8, -1.5, 1.5, 4.8):
        m.cyl(r + 0.07, r + 0.07, 0.24, (0, y, zc), TRIM, segs=20, rot=ALONG_Y)
    m.box((0.06, length - 0.4, 0.22), (-2.21, 0, zc - 0.95), ORANGE, rot=(0, math.radians(-23.3), 0), bev=False)
    wz = 0.45
    wx = -math.sqrt(r * r - wz * wz)
    n = Vector((wx, 0, wz)).normalized()
    for y in (-4.05, -3.15, -2.25, 2.25, 3.15, 4.05):
        window(m, (wx, y, zc + wz), n, 0.5, 0.46)

    az = zc - 0.35
    m.cyl(1.2, 1.2, 1.5, (-r - 0.35, 0, az), HULL, segs=16, rot=ALONG_X, bev=False)
    for x in (-3.42, -2.55):
        m.cyl(1.27, 1.27, 0.16, (x, 0, az), TRIM, segs=16, rot=ALONG_X)
    door(m, (-3.5, 0, az - 0.88), (-1, 0, 0), 0.9, 1.6, light=MARKER, glass_size=(0.66, 0.5))
    for y in (-0.75, 0.75):
        m.box((0.05, 0.14, 1.3), (-3.53, y, az), ORANGE, bev=False)
    m.box((1.5, 2.6, 0.12), (-4.3, 0, 2.0), TRIM)
    for y in (-1.15, 1.15):
        m.strut((-4.95, y, 0.0), (-4.95, y, 1.94), 0.12, TRIM, bev=True)
    railing(m, [(-5.0, -1.25, 2.06), (-5.0, 1.25, 2.06), (-3.65, 1.25, 2.06)], 0.95)
    run, rise, steps = 3.0, 2.0, 8
    for sx in (-4.85, -3.75):
        m.strut((sx, -1.3, 1.95), (sx, -1.3 - run, -0.05), 0.07, TRIM, h=0.26, bev=True)
        m.sweep([(sx, -1.3, 2.96), (sx, -1.3 - run, 0.96)], diamond(0.03), TRIM)
        m.strut((sx, -1.3 - run, 0.0), (sx, -1.3 - run, 0.96), 0.05, TRIM)
    for i in range(steps):
        t = (i + 1) / (steps + 1)
        m.box((1.0, 0.3, 0.05), (-4.3, -1.3 - run * t, 2.0 - rise * t), TRIM, bev=False)

    for y in (-3.6, 3.6):
        for sx in (-1, 1):
            m.strut((sx * 1.95, y, 0.12), (sx * 1.15, y, 1.4), 0.2, TRIM, bev=True)
            m.box((0.6, 0.6, 0.12), (sx * 1.95, y, 0.06), TRIM, bev=False)
        m.strut((-1.6, y, 0.75), (1.6, y, 0.75), 0.12, TRIM)

    rx, ry, rz, rr = 5.4, 0.8, 2.6, 1.8
    m.cyl(rr, rr, 7.0, (rx, ry, rz), HULL, segs=16, rot=ALONG_Y, bev=False)
    for s in (-1, 1):
        m.lathe([(rr, 0.0), (rr * 0.9, 0.35), (rr * 0.6, 0.65), (0.0, 0.8)], (rx, ry + s * 3.5, rz), HULL, segs=16,
                rot=(math.radians(-90 * s), 0, 0))
        m.cyl(rr + 0.07, rr + 0.07, 0.22, (rx, ry + s * 2.4, rz), TRIM, segs=16, rot=ALONG_Y)
        for sx in (-1, 1):
            m.strut((rx + sx * 1.45, ry + s * 2.4, 0.12), (rx + sx * 0.8, ry + s * 2.4, 1.1), 0.16, TRIM, bev=True)
    m.cyl(0.8, 0.8, 2.3, (2.85, ry, 2.85), HULL, segs=12, rot=ALONG_X, bev=False)
    m.cyl(0.88, 0.88, 0.2, (3.0, ry, 2.85), TRIM, segs=12, rot=ALONG_X)

    for y in (-1.0, 0.2, 1.4):
        m.box((0.08, 1.0, 1.8), (1.25, y, 6.55), TRIM)
        m.strut((1.25, y, 5.3), (1.25, y, 5.7), 0.08, TRIM)
    for z in (5.72, 7.38):
        m.cyl(0.07, 0.07, 3.6, (1.25, 0.2, z), TRIM, segs=8, rot=ALONG_Y, bev=False)
    m.strut((-0.6, 3.4, 5.5), (-0.6, 3.4, 6.9), 0.12, TRIM)
    m.box((0.3, 0.3, 0.25), (-0.6, 3.4, 6.95), TRIM)
    dish(m, (-0.6, 3.4, 7.15), (-0.5, 0.15, 0.85), 1.1, HULL)
    for (x, y, hgt) in ((-0.9, -3.0, 2.4), (-0.5, -2.6, 1.6)):
        m.strut((x, y, 5.4), (x, y, 5.4 + hgt), 0.035, TRIM)
        m.box((0.09, 0.09, 0.09), (x, y, 5.4 + hgt), TRIM, bev=False)

    sx_, sy_ = 9.4, -1.0
    m.box((0.8, 0.8, 0.3), (sx_, sy_, 0.15), TRIM)
    m.strut((sx_, sy_, 0.3), (sx_, sy_, 3.3), 0.2, TRIM, bev=True)
    tilt = (0, math.radians(-28), 0)
    m.box((3.7, 5.7, 0.08), (sx_, sy_, 3.45), TRIM, rot=tilt)
    m.box((3.5, 5.5, 0.05), (sx_ - 0.03, sy_, 3.51), SOLAR, rot=tilt, bev=False)
    for dy in (-2.0, 2.0):
        m.strut((sx_, sy_, 2.2), (sx_ + 0.5, sy_ + dy, 3.65), 0.07, TRIM)

    for px, rad, mat in ((0.35, 0.14, TRIM), (0.85, 0.1, ORANGE)):
        m.sweep([(px, 4.3, 1.4), (px, 4.3, 0.8), (px, 4.9, 0.45), (px, 13.2, 0.45), (px, 14.2, -0.5)],
                circle(rad, 10), mat)
        m.cyl(rad + 0.07, rad + 0.07, 0.12, (px, 9.0, 0.45), TRIM, segs=10, rot=ALONG_Y)
    pipe_supports(m, 0.1, 1.1, (6.6, 11.8), 0.29)

    ey = -half - 1.08
    m.cyl(0.72, 0.72, 0.12, (0, ey + 0.02, zc), TRIM, segs=16, rot=ALONG_Y)
    m.cyl(0.56, 0.56, 0.14, (0, ey - 0.02, zc), HULL, segs=16, rot=ALONG_Y)
    m.box((0.5, 0.06, 0.06), (0, ey - 0.12, zc), TRIM, bev=False)
    m.box((1.9, 1.15, 0.1), (0, ey - 0.62, 2.5), TRIM)
    for x in (-0.85, 0.85):
        m.strut((x, ey - 1.1, 0.0), (x, ey - 1.1, 2.45), 0.1, TRIM, bev=True)
        m.strut((x, ey - 0.15, 2.45), (x * 0.8, ey + 0.35, 1.6), 0.07, TRIM)
    ladder(m, (0.0, ey - 1.32, 0.0), 3.45, (1, 0, 0), (0, -1, 0))
    railing(m, [(-0.92, ey - 0.12, 2.55), (-0.92, ey - 1.15, 2.55), (-0.32, ey - 1.15, 2.55)], 0.95)
    railing(m, [(0.32, ey - 1.15, 2.55), (0.92, ey - 1.15, 2.55), (0.92, ey - 0.12, 2.55)], 0.95)
    return done(m)


def hab_hub():
    """A round habitat hub on a steel plinth: plated wall with pilasters, an orange band and an eave,
    framed lit windows with brows, a glazed main door under a canopy on the road side (-X), a ladder
    to a railed roof with a rooftop greenhouse, a lattice comms mast with a dish and a red beacon,
    and two arm modules on legs, one feeding a pipe out into the ground."""
    m = Kit("hab_hub")
    r, h, b = 4.4, 3.8, 0.6
    top = b + h
    m.cyl(r + 0.5, r + 0.62, b, (0, 0, b / 2), TRIM, segs=24)
    m.cyl(r, r, h, (0, 0, b + h / 2), HULL, segs=24, bev=False)
    m.cyl(r + 0.06, r + 0.06, 0.26, (0, 0, b + 0.5), ORANGE, segs=24)
    m.cyl(r + 0.12, r + 0.12, 0.22, (0, 0, top - 0.04), TRIM, segs=24)
    m.cyl(r + 0.04, r - 1.3, 0.9, (0, 0, top + 0.45), HULL, segs=24, bev=False)
    for k in range(12):
        deg = 15 + 30 * k
        if any(abs(((deg - a + 180) % 360) - 180) < 25 for a in (90, 270, 135)):
            continue  # the arm junctions and the ladder
        a = math.radians(deg)
        m.box((0.24, 0.3, h - 0.8), ((r + 0.06) * math.cos(a), (r + 0.06) * math.sin(a), b + 0.65 + (h - 0.8) / 2),
              TRIM, rot=(0, 0, a))
    for deg in (120, 150, 210, 240):
        a = math.radians(deg)
        n = Vector((math.cos(a), math.sin(a), 0))
        window(m, n * r + Z * 2.85, n, 0.85, 0.75)
    door(m, (-r + 0.06, 0, b), (-1, 0, 0), 1.3, 2.1, leaf=HULL, glass=WINDOW, glass_size=(0.8, 0.7))
    m.box((1.2, 2.2, 0.12), (-r - 0.55, 0, b + 2.55), HULL, rot=(0, math.radians(-8), 0))
    for y in (-0.95, 0.95):
        m.strut((-r - 1.05, y, b + 2.5), (-r + 0.05, y, b + 1.9), 0.06, TRIM)
    m.box((0.12, 0.5, 0.1), (-r - 0.25, 0, b + 2.38), WINDOW, bev=False)
    m.box((0.6, 2.0, 0.3), (-r - 0.75, 0, 0.15), TRIM)
    a = math.radians(135)
    n, t = Vector((math.cos(a), math.sin(a), 0)), Vector((-math.sin(a), math.cos(a), 0))
    ladder(m, n * (r + 0.32) + Z * b, top + 1.3, t, n)
    rail_r = r - 0.2
    zr = top + 0.24 * 0.9 / 1.34
    railing(m, [(rail_r * math.cos(2 * math.pi * k / 24), rail_r * math.sin(2 * math.pi * k / 24), zr) for k in range(24)],
            1.0, closed=True, post_every=2)
    m.cyl(2.8, 2.8, 0.25, (0, 0, top + 0.85), TRIM, segs=20)
    dome_shell(m, 2.6, (0, 0, top + 0.95), 10, 3, [GROW, GROW, GROW, HULL], seed=33, rib=0.05)

    mx, my, z0 = 2.6, -2.2, top + 0.6
    zt = z0 + 7.0
    angles = (0.0, 2 * math.pi / 3, 4 * math.pi / 3)

    def leg(i, f):
        rad = 0.32 + (0.12 - 0.32) * f
        return Vector((mx + rad * math.cos(angles[i]), my + rad * math.sin(angles[i]), z0 + (zt - z0) * f))

    for i in range(3):
        m.strut(leg(i, 0.0), leg(i, 1.0), 0.06, TRIM)
        for k in range(6):
            m.strut(leg(i, k / 6), leg((i + 1) % 3, (k + 1) / 6), 0.03, TRIM)
    m.box((0.6, 0.6, 0.15), (mx, my, z0), TRIM)
    m.box((0.32, 0.32, 0.32), (mx, my, zt + 0.2), BEACON_RED, bev=False)
    m.strut((mx + 0.1, my, zt), (mx + 0.1, my, zt + 1.6), 0.025, TRIM)
    dish(m, leg(1, 0.55) + Vector((-0.45, 0, 0)), (-0.8, -0.2, 0.55), 0.7, HULL)

    for sy in (-1, 1):
        m.cyl(1.7, 1.7, 6.0, (0, sy * (r + 2.6), 2.2), HULL, segs=16, rot=ALONG_Y, bev=False)
        m.lathe([(1.7, 0.0), (1.55, 0.35), (1.1, 0.7), (0.0, 0.85)], (0, sy * (r + 5.6), 2.2), HULL, segs=16,
                rot=(math.radians(-90 * sy), 0, 0))
        for y in (r + 1.0, r + 4.9):
            m.cyl(1.77, 1.77, 0.22, (0, sy * y, 2.2), TRIM, segs=16, rot=ALONG_Y)
        wx = -math.sqrt(1.7 ** 2 - 0.3 ** 2)
        wn = Vector((wx, 0, 0.3)).normalized()
        for y in (r + 2.0, r + 3.6):
            window(m, (wx, sy * y, 2.5), wn, 0.5, 0.42)
        for sx in (-1, 1):
            m.strut((sx * 1.5, sy * (r + 4.2), 0.1), (sx * 0.8, sy * (r + 4.2), 1.0), 0.16, TRIM, bev=True)
            m.box((0.5, 0.5, 0.1), (sx * 1.5, sy * (r + 4.2), 0.05), TRIM, bev=False)
    m.sweep([(0.9, r + 5.0, 1.0), (0.9, r + 5.0, 0.6), (0.9, r + 5.6, 0.35), (0.9, r + 9.0, 0.35), (0.9, r + 9.8, -0.4)],
            circle(0.13, 10), ORANGE)
    pipe_supports(m, 0.7, 1.1, (r + 6.6, r + 8.4), 0.2)
    return done(m)


def silo():
    """Twin water-ice silos, frosted pale blue. The big one stands on six braced legs with concrete
    footings and empties through a hopper and valve into a pipe to the pump house; both have vertical
    stiffeners, ring bands, a roof vent and roof railing, status lights facing the road and a ladder
    (caged on the tall one). A pipe bridge joins them; the pump house is sintered regolith with a
    framed door and window."""
    m = Kit("silo")
    big, small = (0.0, -2.7, 2.3, 3.4, 14.5, True), (0.5, 2.9, 1.9, 0.45, 10.5, False)
    for (x, y, r, z0, z1, tall) in (big, small):
        hgt = z1 - z0
        m.cyl(r, r, hgt, (x, y, z0 + hgt / 2), ICE, segs=24, bev=False)
        m.cyl(r + 0.06, r * 0.24, 1.2, (x, y, z1 + 0.6), ICE, segs=24, bev=False)
        m.cyl(r + 0.12, r + 0.12, 0.24, (x, y, z1 - 0.06), TRIM, segs=24)
        for f in (0.3, 0.6):
            m.cyl(r + 0.07, r + 0.07, 0.18, (x, y, z0 + hgt * f), TRIM, segs=24)
        for k in range(12):
            a = 2 * math.pi * (k + 0.5) / 12
            if abs(math.cos(a) + 1) < 0.1:
                continue  # the ladder side
            m.box((0.1, 0.12, hgt - 0.3), (x + (r + 0.04) * math.cos(a), y + (r + 0.04) * math.sin(a), z0 + hgt / 2),
                  TRIM, rot=(0, 0, a), bev=False)
        m.cyl(0.32, 0.32, 0.45, (x, y, z1 + 1.35), TRIM, segs=10)
        m.cyl(0.5, 0.12, 0.25, (x, y, z1 + 1.7), TRIM, segs=10)
        rail_r = r - 0.15
        zr = z1 + 1.2 * 0.21 / (0.76 * r + 0.06)
        railing(m, [(x + rail_r * math.cos(2 * math.pi * k / 16), y + rail_r * math.sin(2 * math.pi * k / 16), zr)
                    for k in range(16)], 0.9, closed=True, post_every=2)
        wall_x = x - math.sqrt(r * r - 0.85 ** 2)
        for f in (0.42, 0.74):
            z = z0 + hgt * f
            m.box((0.14, 0.5, 0.42), (wall_x - 0.05, y + 0.85, z), TRIM)
            m.box((0.05, 0.38, 0.28), (wall_x - 0.13, y + 0.85, z), STATUS, bev=False)
        ladder(m, (x - r - 0.36, y, 0.0 if tall else z0), z1 + 1.1, (0, 1, 0), (-1, 0, 0),
               cage_from=2.6 if tall else None)

    bx, by, br, b0 = big[0], big[1], big[2], big[3]
    for k in range(6):
        a = math.radians(30 + 60 * k)
        p = Vector((bx + (br - 0.2) * math.cos(a), by + (br - 0.2) * math.sin(a), 0))
        q = Vector((bx + (br - 0.2) * math.cos(a + math.pi / 3), by + (br - 0.2) * math.sin(a + math.pi / 3), 0))
        m.box((0.32, 0.32, b0 + 0.1), p + Z * ((b0 + 0.1) / 2), TRIM, rot=(0, 0, a))
        m.box((0.75, 0.75, 0.32), p + Z * 0.1, CONCRETE)
        m.strut(p + Z * 0.4, q + Z * (b0 - 0.3), 0.08, TRIM)
        m.strut(q + Z * 0.4, p + Z * (b0 - 0.3), 0.08, TRIM)
    m.cyl(br + 0.14, br + 0.14, 0.36, (bx, by, b0 - 0.05), TRIM, segs=24)
    m.cyl(0.32, br, 1.5, (bx, by, b0 - 0.75), ICE, segs=24, bev=False)
    m.cyl(0.3, 0.3, 0.5, (bx, by, b0 - 1.75), TRIM, segs=12)
    m.box((0.62, 0.62, 0.45), (bx, by, 1.2), TRIM)
    m.sweep([(bx, by, 1.0), (bx - 0.95, by + 1.2, 1.0), (-1.6, -0.6, 1.0)], circle(0.16, 10), HULL)

    px, py = -2.4, 0.1
    m.box((3.0, 2.6, 2.4), (px, py, 1.2), CONCRETE)
    m.box((3.25, 2.85, 0.16), (px, py, 2.46), TRIM)
    door(m, (px - 1.5, py - 0.45, 0.0), (-1, 0, 0), 0.85, 1.8, leaf=HULL, glass=None, light=WINDOW)
    window(m, (px - 1.5, py + 0.75, 1.5), (-1, 0, 0), 0.65, 0.5)
    m.cyl(0.42, 0.42, 0.3, (px + 0.4, py + 0.5, 2.68), HULL, segs=12)
    m.box((0.7, 0.5, 0.35), (px - 0.6, py - 0.5, 2.72), HULL)

    a, b = Vector((0.05, -0.55, 12.2)), Vector((0.4, 1.15, 10.2))
    m.sweep([a, b], circle(0.2, 10), HULL)
    d = (b - a).normalized()
    for f in (0.25, 0.75):
        p = a.lerp(b, f)
        m.sweep([p - d * 0.06, p + d * 0.06], circle(0.28, 10), TRIM, bev=True)
    return done(m)


def pad():
    """A landing pad: an octagonal deck of eight sintered slabs with expansion joints, painted kerbs
    round the rim (open on the road side, -X, where a ramp comes up), a painted target, amber edge
    lights (beacon_amber, they pulse with the beat), two floodlight masts with lamp heads aimed at the
    deck and red beacons, and a blast fence on the far side."""
    m = Kit("pad")
    R, deck = 10.0, 0.5
    apo = R * math.cos(math.pi / 8)
    gap = 0.03 / math.sin(math.pi / 8)
    for i in range(8):
        a0, a1 = math.pi / 8 + i * math.pi / 4, math.pi / 8 + (i + 1) * math.pi / 4
        mid = (a0 + a1) / 2
        off = Vector((math.cos(mid), math.sin(mid), 0)) * gap
        tri = [Vector((0, 0, 0)), Vector((R * math.cos(a0), R * math.sin(a0), 0)), Vector((R * math.cos(a1), R * math.sin(a1), 0))]
        verts = [p + off for p in tri] + [p + off + Z * deck for p in tri]
        m.faces(verts, [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], [PAD] * 5, bev=True)
    m.cyl(0.35, 0.35, deck, (0, 0, deck / 2), PAD, segs=8, bev=False)
    side = 2 * R * math.sin(math.pi / 8)
    rim = apo + gap - 0.22
    for k in range(8):
        if k == 4:
            continue  # the ramp side
        a = math.radians(45 * k)
        c = Vector((math.cos(a), math.sin(a), 0)) * rim
        m.box((0.4, side - 1.0, 0.26), c + Z * (deck + 0.12), PAD_PAINT, rot=(0, 0, a))
        m.box((0.24, 0.24, 0.1), c + Z * (deck + 0.3), BEACON_AMBER, rot=(0, 0, a), bev=False)
    x0, hw = -(apo + gap), 3.2
    m.faces([(x0, -hw, -0.02), (x0, hw, -0.02), (x0, hw, deck), (x0, -hw, deck), (x0 - 3.2, -hw, -0.02), (x0 - 3.2, hw, -0.02)],
            [(0, 1, 2, 3), (0, 4, 5, 1), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2)], [PAD] * 5, bev=True)
    annulus(m, 7.15, 7.5, deck - 0.02, deck + 0.012, PAD_PAINT)
    annulus(m, 2.8, 3.05, deck - 0.02, deck + 0.012, PAD_PAINT)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        m.box((3.3, 0.3, 0.03), Vector((math.cos(a), math.sin(a), 0)) * 5.1 + Z * (deck - 0.004), PAD_PAINT,
              rot=(0, 0, a), bev=False)
    for s in (-1, 1):
        m.box((1.6, 0.28, 0.03), (-8.3, s * 0.46, deck - 0.004), PAD_PAINT, rot=(0, 0, s * math.radians(-35)), bev=False)
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        p = Vector((math.cos(a), math.sin(a), 0)) * (R - 0.45)
        m.box((0.34, 0.34, 0.16), p + Z * (deck + 0.08), TRIM, rot=(0, 0, a), bev=False)
        m.box((0.24, 0.24, 0.08), p + Z * (deck + 0.2), BEACON_AMBER, rot=(0, 0, a), bev=False)
    for sy in (-1, 1):
        a = math.radians(45 * sy)
        out = Vector((math.cos(a), math.sin(a), 0))
        tan = Vector((-math.sin(a), math.cos(a), 0))
        base = out * (R + 0.5)
        m.box((1.0, 1.0, 0.45), base + Z * 0.2, PAD)
        m.cyl(0.22, 0.13, 9.0, base + Z * 4.9, TRIM, segs=10, bev=False)
        m.box((0.25, 0.5, 0.6), base - out * 0.32 + Z * 0.75, TRIM, rot=(0, 0, a))
        head = base + Z * 9.35
        m.box((0.25, 1.9, 0.2), head + Z * 0.28, TRIM, rot=(0, 0, a))
        rot = (0, math.radians(-25), a)
        turn = Euler(rot).to_matrix()
        for j in (-1, 0, 1):
            p = head + tan * (j * 0.58)
            m.box((0.42, 0.48, 0.38), p, TRIM, rot=rot)
            m.box((0.05, 0.38, 0.28), p + turn @ Vector((-0.215, 0, 0)), LAMP, rot=rot, bev=False)
        m.box((0.3, 0.3, 0.3), base + Z * 9.85, BEACON_RED, bev=False)
        for k in range(10):
            z = 1.2 + k * 0.7
            m.strut(base - out * 0.2 + tan * -0.2 + Z * z, base - out * 0.2 + tan * 0.2 + Z * z, 0.035, TRIM)
    m.box((0.7, 12.6, 0.3), (12.0, 0, 0.12), PAD)
    for k in range(4):
        y = -4.65 + k * 3.1
        m.box((0.14, 3.0, 2.9), (12.25, y, 1.55), TRIM, rot=(0, math.radians(18), 0))
        for dy in (-1.1, 1.1):
            m.strut((12.75, y + dy, 2.55), (13.6, y + dy, 0.0), 0.12, TRIM, bev=True)
    return done(m)


def section(w, lo, hi):
    """The shuttle's cross-section at one station: a flat belly, chines, near-vertical sides, rounded
    shoulders and a flat top, as 12 (x, z) points round the loop."""
    hgt = hi - lo
    return [(-0.55 * w, lo), (-0.9 * w, lo + 0.12 * hgt), (-w, lo + 0.38 * hgt), (-0.95 * w, lo + 0.62 * hgt),
            (-0.76 * w, lo + 0.86 * hgt), (-0.38 * w, hi), (0.38 * w, hi), (0.76 * w, lo + 0.86 * hgt),
            (0.95 * w, lo + 0.62 * hgt), (w, lo + 0.38 * hgt), (0.9 * w, lo + 0.12 * hgt), (0.55 * w, lo)]


def shuttle():
    """A cargo shuttle parked on the pad (its feet stand on the pad's 0.5-high deck): a hull lofted
    through seven stations (dark heat-shield belly, orange chine stripes, payload-bay seams, a framed
    canopy), delta wings with elevons and nav lights, an orange fin with a rudder and beacon, three
    engine bells (inside a glow) on thrust rings with gimbal actuators toward -Y, RCS blocks, a crew
    hatch, four landing legs (sleeve and piston, drag brace, footpad, open bay door), and the cargo
    ramp down on the road side (-X), ahead of the wing, with the framed hold lit."""
    m = Kit("shuttle")
    z0, zb = 0.5, 2.1
    stations = [(-5.6, 1.95, 0.05, 2.65), (-4.6, 2.08, 0.0, 2.82), (1.4, 2.1, 0.0, 2.86), (3.3, 1.95, 0.06, 2.74),
                (4.9, 1.55, 0.2, 2.32), (6.1, 0.95, 0.4, 1.78), (6.9, 0.32, 0.64, 1.22)]
    rings = [[Vector((x, y, zb + z)) for x, z in section(w, lo, hi)] for y, w, lo, hi in stations]
    n = 12
    verts = [p for ring in rings for p in ring]
    faces, mats = [], []
    for s in range(len(rings) - 1):
        for j in range(n):
            faces.append((s * n + j, s * n + (j + 1) % n, (s + 1) * n + (j + 1) % n, (s + 1) * n + j))
            if j in (0, 10, 11):
                mats.append(HULL_DARK)
            elif j in (2, 8) and s <= 2:
                mats.append(ORANGE)
            elif s == 3 and j in (4, 5, 6):
                mats.append(COCKPIT)
            else:
                mats.append(HULL)
    last = (len(rings) - 1) * n
    faces += [tuple(range(n - 1, -1, -1)), tuple(range(last, last + n))]
    mats += [HULL_DARK, HULL_DARK]
    m.faces(verts, faces, mats)
    for j in (4, 5, 6, 7):
        m.strut(rings[3][j], rings[4][j], 0.08, HULL_DARK, h=0.06)
    for s in (3, 4):
        m.sweep([rings[s][j] for j in (4, 5, 6, 7)], rect(0.08, 0.06), HULL_DARK)
    for x in (-0.62, 0.62):
        m.strut((x, -4.6, zb + 2.83), (x, 1.4, zb + 2.87), 0.05, HULL_DARK, h=0.04)
    for y in (-2.6, -0.6):
        m.strut((-0.62, y, zb + 2.86), (0.62, y, zb + 2.86), 0.05, HULL_DARK, h=0.04)
    m.cyl(0.5, 0.5, 0.16, (0, 2.3, zb + 2.86), HULL_DARK, segs=16)

    bell = [(0.3, 0.0), (0.35, 0.28), (0.47, 0.62), (0.63, 1.08), (0.6, 1.12), (0.44, 0.68), (0.31, 0.36), (0.25, 0.14)]
    for x, z in ((-1.0, 1.0), (1.0, 1.0), (0.0, 2.0)):
        c = Vector((x, -5.6, zb + z))
        m.cyl(0.46, 0.46, 0.3, c + Vector((0, -0.05, 0)), HULL_DARK, segs=16, rot=ALONG_Y)
        m.lathe(bell, c + Vector((0, -0.15, 0)), HULL_DARK, segs=16, rot=ALONG_Y)
        m.cyl(0.27, 0.27, 0.04, c + Vector((0, -0.35, 0)), ENGINE, segs=12, rot=ALONG_Y, bev=False)
        for dx in (-1, 1):
            m.strut(c + Vector((dx * 0.5, -0.02, 0.3)), c + Vector((dx * 0.5, -0.75, 0.0)), 0.05, HULL_DARK)

    for sx in (-1, 1):
        top = [(sx * 1.95, 1.6, zb + 0.78), (sx * 1.95, -4.9, zb + 0.78), (sx * 6.0, -5.1, zb + 0.62), (sx * 6.0, -4.0, zb + 0.62)]
        bot = [(x, y, z - (0.32 if abs(x) < 3 else 0.14)) for x, y, z in top]
        m.faces(top + bot, [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)],
                [HULL, HULL_DARK, HULL, HULL_DARK, HULL, HULL], bev=True)
        m.box((3.3, 0.7, 0.1), (sx * 4.0, -5.42, zb + 0.6), HULL, rot=(math.radians(-6), 0, 0))
        m.box((0.36, 0.5, 0.16), (sx * 6.0, -4.6, zb + 0.62), NAV_GREEN if sx > 0 else BEACON_RED, bev=False)
        for y, x, z in ((5.6, 1.22, 1.3), (-5.1, 1.72, 2.1)):
            m.box((0.25, 0.45, 0.3), (sx * x, y, zb + z), HULL_DARK)
    fin = [(-0.13, -5.3, zb + 2.6), (-0.13, -2.7, zb + 2.75), (-0.08, -5.75, zb + 5.0),
           (0.13, -5.3, zb + 2.6), (0.13, -2.7, zb + 2.75), (0.08, -5.75, zb + 5.0)]
    m.faces(fin, [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], [ORANGE, ORANGE, HULL, HULL, HULL], bev=True)
    m.box((0.16, 0.5, 1.9), (0, -5.8, zb + 3.75), HULL, rot=(math.radians(10.6), 0, 0))
    m.box((0.3, 0.3, 0.3), (0, -5.75, zb + 5.15), BEACON_RED, bev=False)

    # The crew hatch is on the far side (+X); the road side has the cargo hold, ahead of the wing root
    # so the ramp comes down clear of the wing.
    m.box((0.12, 0.95, 1.35), (2.05, 2.0, zb + 1.35), HULL_DARK)
    m.box((0.08, 0.75, 1.15), (2.1, 2.0, zb + 1.35), HULL)
    m.box((0.05, 0.3, 0.3), (2.15, 2.0, zb + 1.7), COCKPIT, bev=False)
    hy = 3.0
    m.box((0.44, 2.1, 1.5), (-1.92, hy, zb + 1.2), COCKPIT, bev=False)
    m.box((0.22, 2.5, 0.22), (-2.08, hy, zb + 2.02), HULL_DARK)
    for y in (hy - 1.15, hy + 1.15):
        m.box((0.22, 0.2, 1.75), (-2.08, y, zb + 1.15), HULL_DARK)
    run, drop = 3.4, zb + 0.45 - z0
    ramp = math.atan2(drop, run)
    m.box((math.hypot(run, drop), 2.0, 0.12), (-2.14 - run / 2, hy, z0 + drop / 2 + 0.05), HULL_DARK, rot=(0, -ramp, 0))
    for y in (hy - 0.95, hy + 0.95):
        m.strut((-2.2, y, zb + 0.6), (-5.4, y, z0 + 0.15), 0.06, HULL_DARK, h=0.14)

    for sx in (-1, 1):
        for y in (-3.2, 0.8):
            top_p, foot = Vector((sx * 1.35, y, zb + 0.15)), Vector((sx * 2.55, y, z0 + 0.32))
            m.box((0.5, 0.6, 0.3), top_p + Z * 0.05, HULL_DARK)
            mid = top_p.lerp(foot, 0.55)
            m.beam(top_p, mid, 0.14, HULL_DARK, segs=10)
            m.beam(mid - (foot - top_p).normalized() * 0.15, foot, 0.085, HULL, segs=10)
            m.strut((sx * 0.9, y + (0.9 if y < 0 else -0.9), zb + 0.05), top_p.lerp(foot, 0.7), 0.07, HULL_DARK)
            m.cyl(0.5, 0.4, 0.14, (foot.x, foot.y, z0 + 0.07), HULL_DARK, segs=12)
            m.cyl(0.14, 0.14, 0.25, (foot.x, foot.y, z0 + 0.22), HULL_DARK, segs=8, bev=False)
            m.box((0.05, 1.0, 0.75), (sx * 1.05, y, zb - 0.32), HULL, rot=(0, sx * math.radians(25), 0))
    return done(m)


def turbine():
    """A dust turbine's tower and nacelle (the rotor is a separate model the world script spins): an
    octagonal concrete footing with dust banked round it, a bolted base flange, a door, a tapered
    tower in three flanged sections with an orange band, a yaw bearing, and a streamlined nacelle
    with a seam band, cooling fins, a roof hatch, a solar panel and a met mast (anemometer, vane,
    red beacon)."""
    m = Kit("turbine")
    hx, hy, hz = TURBINE_HUB
    m.cyl(2.6, 1.7, 0.32, (0, 0, 0.0), CONCRETE, segs=12, bev=False)
    m.cyl(1.75, 1.5, 0.6, (0, 0, 0.25), CONCRETE, segs=8)
    m.cyl(0.8, 0.8, 0.14, (0, 0, 0.6), TRIM, segs=16)
    for k in range(12):
        a = 2 * math.pi * k / 12
        m.cyl(0.045, 0.045, 0.1, (0.7 * math.cos(a), 0.7 * math.sin(a), 0.71), TRIM, segs=6, bev=False)
    for z0, z1, r0, r1 in ((0.67, 6.4, 0.55, 0.47), (6.4, 11.8, 0.47, 0.39), (11.8, 16.5, 0.39, 0.31)):
        m.cyl(r0, r1, z1 - z0, (0, 0, (z0 + z1) / 2), HULL, segs=16, bev=False)
    for z, rad in ((6.4, 0.47), (11.8, 0.39)):
        m.cyl(rad + 0.06, rad + 0.06, 0.14, (0, 0, z), TRIM, segs=16)
    m.cyl(0.39, 0.38, 0.6, (0, 0, 13.4), ORANGE, segs=16, bev=False)
    door(m, (-0.5, 0, 0.72), (-1, 0, 0), 0.6, 1.75, leaf=HULL, glass=None)
    m.cyl(0.42, 0.42, 0.22, (0, 0, 16.55), TRIM, segs=16)
    m.lathe([(0.0, 0.0), (0.32, 0.06), (0.52, 0.4), (0.62, 0.95), (0.64, 2.7), (0.58, 3.45), (0.5, 3.72), (0.0, 3.74)],
            (0, 2.5, hz), HULL, segs=16, rot=ALONG_Y)
    m.cyl(0.66, 0.66, 0.12, (0, 0.8, hz), TRIM, segs=16, rot=ALONG_Y)
    for dx in (-0.3, -0.1, 0.1, 0.3):
        m.box((0.05, 0.9, 0.22), (dx, 1.65, hz + 0.6), TRIM, bev=False)
    m.box((0.62, 0.8, 0.06), (0, 0.3, hz + 0.63), TRIM)
    m.box((0.5, 0.68, 0.04), (0, 0.3, hz + 0.67), HULL, bev=False)
    m.box((0.6, 0.9, 0.05), (0, -0.55, hz + 0.63), SOLAR, rot=(math.radians(-8), 0, 0), bev=False)
    m.strut((0, 2.1, hz + 0.45), (0, 2.1, hz + 1.7), 0.07, TRIM)
    m.strut((-0.5, 2.1, hz + 1.5), (0.5, 2.1, hz + 1.5), 0.05, TRIM)
    for k in range(3):
        a = 2 * math.pi * k / 3
        m.box((0.09, 0.09, 0.07), (-0.5 + 0.16 * math.cos(a), 2.1 + 0.16 * math.sin(a), hz + 1.62), TRIM, bev=False)
    m.box((0.04, 0.4, 0.25), (0.5, 2.3, hz + 1.6), TRIM, bev=False)
    m.box((0.26, 0.26, 0.26), (0, 2.1, hz + 1.85), BEACON_RED, bev=False)
    return done(m)


def rotor():
    """A lathed spinner and three tapered, twisted airfoil blades on pitch collars, their tips painted
    orange. Origin at the hub, blades in the XZ plane, spinner nose toward -Y (in Godot it spins about
    its local Z axis)."""
    m = Kit("rotor", smooth_below=50.0)
    m.lathe([(0.0, -0.05), (0.5, 0.0), (0.52, 0.25), (0.45, 0.6), (0.3, 0.9), (0.12, 1.08), (0.0, 1.12)],
            (0, 0.15, 0), HULL, segs=16, rot=ALONG_Y)
    foil = [(0.5, 0.0), (0.25, 0.35), (-0.05, 0.5), (-0.35, 0.42), (-0.5, 0.0), (-0.35, -0.3), (-0.05, -0.35), (0.25, -0.2)]
    stations = [(0.45, 0.32, 0.26, 0.5), (1.3, 0.85, 0.16, 0.42), (3.0, 0.62, 0.1, 0.25), (5.4, 0.4, 0.06, 0.12),
                (7.0, 0.26, 0.04, 0.07), (7.85, 0.1, 0.02, 0.05)]
    k = len(foil)
    for i in range(3):
        a = math.pi / 2 + 2 * math.pi * i / 3
        u = Vector((math.cos(a), 0.0, math.sin(a)))
        v = Vector((-math.sin(a), 0.0, math.cos(a)))
        verts = []
        for radius, chord, thick, twist in stations:
            c, s = math.cos(twist), math.sin(twist)
            for fx, fy in foil:
                w_off, t_off = fx * chord, fy * thick
                verts.append(u * radius + v * (w_off * c - t_off * s) + Vector((0, w_off * s + t_off * c, 0)))
        faces, mats = [], []
        for st in range(len(stations) - 1):
            for j in range(k):
                faces.append((st * k + j, st * k + (j + 1) % k, (st + 1) * k + (j + 1) % k, (st + 1) * k + j))
                mats.append(ORANGE if st >= len(stations) - 3 else HULL)
        last = (len(stations) - 1) * k
        faces += [tuple(range(k - 1, -1, -1)), tuple(range(last, last + k))]
        mats += [HULL, ORANGE]
        m.faces(verts, faces, mats)
        m.beam(u * 0.35 + Vector((0, -0.25, 0)), u * 0.85 + Vector((0, -0.25, 0)), 0.2, TRIM, segs=12, bev=True)
    return done(m)


def rock():
    """A small cluster: a rock chipped into fresh facets, a little stack of layered regolith and three
    pebbles, half sunk. Godot scatters thousands with a MultiMesh, so no bevel."""
    m = Kit("rock", bevel=0.0, smooth_below=48.0)
    rr = random.Random(41)
    stone(m, (0.62, 0.5, 0.36), (0, 0, 0.12), ROCK, rr, subdiv=3, cuts=6)
    strata(m, (0.75, -0.45, -0.08), 0.42, 3, [ROCK_DARK, ROCK], rr, sides=8, thick=(0.1, 0.16))
    for _ in range(3):
        s = rr.uniform(0.13, 0.26)
        stone(m, (s, s * 0.85, s * 0.6), (rr.uniform(-1.1, 1.1), rr.uniform(-1.1, 1.1), s * 0.15),
              rr.choice([ROCK, ROCK_DARK]), rr, subdiv=2, cuts=3)
    return done(m)


def boulder():
    """A heap of wind-cut boulders for the plain's middle distance: two big chipped masses, an outcrop
    of layered regolith, broken blocks and scree round them, and a tongue of dust in their lee."""
    m = Kit("boulder", bevel=0.0, smooth_below=45.0)
    rr = random.Random(57)
    stone(m, (3.6, 3.0, 2.6), (0, 0, 0.9), ROCK, rr, subdiv=4, cuts=8)
    stone(m, (2.2, 2.6, 1.9), (2.6, 2.4, 0.5), ROCK_DARK, rr, subdiv=4, cuts=7)
    strata(m, (-3.4, 2.6, -0.1), 2.3, 5, [ROCK, ROCK_DARK, ROCK], rr, sides=12, thick=(0.35, 0.6))
    for _ in range(5):
        s = rr.uniform(0.8, 1.6)
        a, d = rr.uniform(0, 2 * math.pi), rr.uniform(3.8, 6.0)
        stone(m, (s, s * rr.uniform(0.7, 1.0), s * 0.7), (math.cos(a) * d, math.sin(a) * d, s * 0.2),
              rr.choice([ROCK, ROCK_DARK]), rr, subdiv=3, cuts=5)
    for _ in range(9):
        s = rr.uniform(0.2, 0.45)
        a, d = rr.uniform(0, 2 * math.pi), rr.uniform(4.0, 7.5)
        stone(m, (s, s * 0.9, s * 0.6), (math.cos(a) * d, math.sin(a) * d, s * 0.1), rr.choice([ROCK, ROCK_DARK]), rr,
              subdiv=2, cuts=3)
    m.blob(3.0, (1.5, -4.2, -0.5), DUNE, subdiv=3, jitter=0.06, squash=0.2)
    return done(m)


def dune():
    """A long crescent dune, its gentle windward face toward the road (-X), a sharp crest and the steep
    slip face beyond; closed underneath so its normals face out."""
    m = Kit("dune", bevel=0.0, smooth_below=22.0)
    rr = random.Random(63)
    half_w, half_l, height = 14.0, 30.0, 4.5
    nl, nr, ny = 14, 8, 30
    rows = []
    for j in range(ny + 1):
        v = -1 + 2 * j / ny
        crest = 0.25 + 0.15 * math.sin(v * math.pi)
        env = max(0.0, 1 - v * v) ** 0.7
        us = [-1 + (crest + 1) * i / nl for i in range(nl)] + [crest + (1 - crest) * i / nr for i in range(nr + 1)]
        row = []
        for i, u in enumerate(us):
            if u <= crest:
                across = ((u + 1) / (1 + crest)) ** 1.15
            else:
                across = (1 - (u - crest) / (1 - crest)) ** 2.0
            h = height * across * env
            if 0 < i < len(us) - 1 and 0 < j < ny and i != nl:
                h += rr.uniform(-0.12, 0.12) * env
            row.append((u * half_w, v * half_l, h - 0.15))
        rows.append(row)
    cols = nl + nr + 1
    verts = [p for row in rows for p in row]
    faces = []
    for j in range(ny):
        for i in range(cols - 1):
            a = j * cols + i
            faces.append((a, a + 1, a + cols + 1, a + cols))
    border = [i for i in range(cols)] + [j * cols + cols - 1 for j in range(1, ny + 1)]
    border += [ny * cols + i for i in range(cols - 2, -1, -1)] + [j * cols for j in range(ny - 1, 0, -1)]
    faces.append(tuple(reversed(border)))
    m.faces(verts, faces, [DUNE] * len(faces))
    return done(m)


def hood():
    """The player's pressurised rover, seen from the driver's seat, behind the keyboard. Same
    footprint as the old pickup hood (half-width 8, running about 9.6 toward -Y, top from 0 to
    0.95, lamps at the front corners). Only its front strip and the wheel pods are in shot:
    composite panels, twin orange stripes, panel seams, louvred vents, a front lip, and on the pods
    (which frame the bottom corners) bolt rows, tread plate, a grab rail and finned LED lamp housings.
    Never weathered (the world script keeps it clean), so nothing here relies on a surface map."""
    m = Kit("hood")
    w = 8.0
    slope = -math.atan(0.95 / 9.2)

    def on_top(y):
        return 0.95 * (0.2 - y) / 9.2

    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], ROVER, bev=True)
    # Flat decals laid on the sloping top. No raised centre ridge: it would stand in front of the keys.
    for sx in (-1, 1):
        m.box((0.45, 8.6, 0.03), (sx * 2.6, -4.4, on_top(-4.4) + 0.02), ORANGE, rot=(slope, 0, 0))
        m.box((0.12, 8.6, 0.03), (sx * 3.15, -4.4, on_top(-4.4) + 0.02), ORANGE, rot=(slope, 0, 0))
    for y in (-2.4, -6.2):
        m.box((w * 2 - 0.6, 0.07, 0.03), (0, y, on_top(y) + 0.02), FRAME, rot=(slope, 0, 0))
    for sx in (-1, 1):
        m.box((0.07, 8.6, 0.03), (sx * 4.6, -4.4, on_top(-4.4) + 0.02), FRAME, rot=(slope, 0, 0))
    # Louvred vents: a dark recess with five slats laid across it.
    for sx in (-1, 1):
        m.box((1.8, 1.7, 0.03), (sx * 6.0, -3.55, on_top(-3.55) + 0.018), FRAME, rot=(slope, 0, 0))
        for k in range(5):
            y = -2.9 - k * 0.32
            m.box((1.6, 0.1, 0.05), (sx * 6.0, y, on_top(y) + 0.04), ROVER, rot=(slope - 0.5, 0, 0), bev=False)
    m.box((w * 2 - 0.4, 0.12, 0.07), (0, 0.16, 0.02), FRAME)
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.5), (x, -4.5, -0.25), ROVER)
        # A narrow orange stripe on the pod's inner edge (a full orange top was too loud in the corners).
        m.box((0.4, 9.6, 0.06), (x - side * 0.6, -4.5, 0.52), ORANGE)
        m.box((0.12, 9.6, 0.1), (x - side * 0.92, -4.5, 0.56), FRAME)
        for k in range(12):
            m.cyl(0.05, 0.05, 0.05, (x - side * 0.25, -0.35 - k * 0.7, 0.52), FRAME, segs=6, bev=False)
        # Tread plate on the pod top near the front: alternating raised bars.
        for i in range(3):
            for j in range(7):
                ang = math.radians(30 if (i + j) % 2 else -30)
                m.box((0.26, 0.07, 0.025), (x + side * 0.15 + (i - 1) * 0.28, -0.4 - j * 0.3, 0.51), FRAME,
                      rot=(0, 0, ang), bev=False)
        rx = x + side * 0.7
        m.sweep([(rx, -2.6, 0.48), (rx, -2.45, 0.68), (rx, -0.75, 0.68), (rx, -0.6, 0.48)], circle(0.045, 6), FRAME)
        # Lamp: a dark housing with two round LED pods in bezels, an amber marker on the outer edge,
        # and cooling fins on its back (the side the driver sees).
        # Raised so it clears the ground plane: the hood's nose is sunk just below the road.
        m.box((1.95, 0.34, 0.9), (x, 0.36, 0.3), FRAME)
        for dx in (-0.48, 0.48):
            m.cyl(0.38, 0.38, 0.08, (x + dx, 0.53, 0.32), ROVER, segs=16, rot=(math.radians(-90), 0, 0))
            m.cyl(0.32, 0.32, 0.12, (x + dx, 0.56, 0.32), LAMP, segs=16, rot=(math.radians(-90), 0, 0))
        m.box((0.22, 0.14, 0.5), (x + side * 0.9, 0.55, 0.3), MARKER)
        for k in range(7):
            m.box((0.05, 0.22, 0.55), (x - 0.75 + k * 0.25, 0.1, 0.3), FRAME, bev=False)
        # The lamps face down the road, away from the driver: a light bar on top is what you see.
        m.box((1.5, 0.1, 0.04), (x, 0.42, 0.77), LAMP_BAR)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), FRAME)
    return done(m)


export_all([dome, dome_pair, pod, crop_tube_green, crop_tube_gold, pylon, habitat, hab_hub, silo, pad, shuttle,
            turbine, rotor, rock, boulder, dune, marker, hood], OUT_DIR, PREVIEW)
