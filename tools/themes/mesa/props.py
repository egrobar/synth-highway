"""Io Burn props (region id `mesa`): a volcanic moon under Jupiter.

Black basalt crags and a cliff of hexagonal basalt columns, spatter cones with lava fountains in
their craters, erupting umbrella plumes (static: the world script pulses their glow), lava-vent
fissures to lie beside the road, a lava river that repeats along it, sulphur-crusted rocks,
sulphur crystals and little glowing fumaroles for scatter, a drill rig and an ore smelter with
warning beacons, a radiation-hazard sign gantry (beside the road, never over it), heavy cable
pylons whose cables tile, hazard bollards for the shoulders, and the player's armoured hauler hood.

High detail (2026-11-10). Rock is built from convex hulls of jittered rings and point clouds, so
every piece is faceted and chipped rather than a smooth primitive: crag spires are stacks of lava
flows (each stratum bulges, steps in at the next one, leaves a ledge for sulphur frost, and some
are split by a fracture with one half slumped), standing on a rock plinth in a skirt of talus;
the column cliff is jointed hexagonal columns (each segment a touch smaller and turned, so the
joints read) with tilted, chipped caps, broken stumps in front and fallen column logs in the
talus; spatter cones have a lumpy rim of welded clots, crust rafts on the crater's lava and bombs
round the foot. The plant is real plant: the drill rig has a braced substructure, a lattice
derrick with an open V-door, monkey board, crown sheaves, travelling block and top drive, a BOP
stack glowing over the melt, a railed deck with stairs, a dog house, tanks with caged ladders,
generators with exhaust stacks and a pipe rack; the smelter has a pilastered hall with a pitched
roof and a glowing louvred monitor, a furnace mouth with a launder into a slag bay, a slag-pot car
on rails, a catwalk, tanks, a conveyor with its feed hopper and ore heap, a flue duct and a banded
stack with platforms and a ladder. The gantry and pylons have bolted base plates, splice flanges,
gussets, box trusses, cable conduit, insulator strings and hazard striping cut as geometry.

Every model is a Part (copied from tools/themes/neon/props.py), which bevels only what is marked
(masses, housings) and leaves fine detail (rungs, rails, bolts, stripes) as flat boxes; rock has
no bevel at all, so its facets stay crisp. Material names pick the shared surface maps
(ThemeWorld.SURFACE_KEYWORDS and mesa.gd's `surfaces`): basalt / crust / sulphur -> rock,
frost -> ice, steel -> brushed metal, hull -> riveted plating, concrete -> concrete.
Hazard black is the prop's own dark metal (hull_plant, steel_dark) or sign ink, so stripes cost
no extra material.

Material names matter to game/scripts/themes/mesa.gd: lava* and vent_glow pulse slowly,
plume* breathe with the eruption cycle, beacon_red flashes slowly and beacon_amber strobes.
The hood uses none of those names, so it never pulses.
Run: blender --background --python tools/themes/mesa/props.py -- game/assets/themes/mesa/models [preview.png]
"""
import math
import pathlib
import random
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset  # noqa: E402

PYLON_SPACING = 32.0  # must match PYLON_SPACING in game/scripts/themes/mesa.gd
LAVA_TILE = 24.0  # must match LAVA_TILE in game/scripts/themes/mesa.gd
BOLLARD_SPACING = 12.0  # must match BOLLARD_SPACING in game/scripts/themes/mesa.gd
OUT_DIR, PREVIEW = args()
reset()

TAU = 2 * math.pi
ALONG_Y = (math.radians(90), 0, 0)  # turns a cylinder's axis from Z to Y
ALONG_X = (0, math.radians(90), 0)  # turns a cylinder's axis from Z to X

# Rock. Basalt is near-black so the lava and sulphur carry the colour.
BASALT = material("basalt", (0.038, 0.034, 0.035), rough=0.9)
BASALT_GREY = material("basalt_grey", (0.075, 0.068, 0.064), rough=0.86)
CRUST = material("crust", (0.045, 0.026, 0.02), rough=0.95)
SULPHUR = material("sulphur", (0.72, 0.52, 0.04), rough=0.8)
SULPHUR_ORANGE = material("sulphur_orange", (0.55, 0.2, 0.025), rough=0.85)
FROST = material("frost", (0.62, 0.6, 0.52), rough=0.55)
# Sulphur crystals glint a little on their own, so the scatter reads in the dark.
CRYSTAL = material("crystal", (0.85, 0.62, 0.05), rough=0.25, emit=(0.9, 0.62, 0.04), strength=0.35)
# Lava. Emission strength is HDR: above 1.0 it blooms. Kept red-orange and moderate: at 5 / 8 the
# river beside the road bloomed to a near-white yellow and pulled the eye off the notes.
LAVA = material("lava", (0.5, 0.08, 0.01), emit=(1.0, 0.2, 0.02), strength=3.0)
LAVA_HOT = material("lava_hot", (0.6, 0.2, 0.03), emit=(1.0, 0.42, 0.06), strength=4.5)
VENT_GLOW = material("vent_glow", (0.6, 0.2, 0.03), emit=(1.0, 0.38, 0.05), strength=3.0)
# Plumes are glowing gas: near-black albedo so the key light does not shade them into solid brown
# shapes (they read as giant mushrooms that way), and all their look comes from emission. The world
# script draws plume_warm and plume_veil additive and two-sided, so they stay see-through.
PLUME_HOT = material("plume_hot", (0.08, 0.03, 0.005), emit=(1.0, 0.45, 0.07), strength=4.0)
PLUME_WARM = material("plume_warm", (0.04, 0.01, 0.004), emit=(0.95, 0.22, 0.03), strength=1.6)
PLUME_VEIL = material("plume_veil", (0.012, 0.006, 0.006), emit=(0.85, 0.24, 0.07), strength=0.6)
# Industry. Bare steel is a real metal (bright albedo, high metalness); the plant's painted
# cladding is dark plating; hazard yellow is paint.
STEEL = material("steel", (0.36, 0.36, 0.37), rough=0.42, metal=0.9)
STEEL_DARK = material("steel_dark", (0.07, 0.07, 0.075), rough=0.5, metal=0.75)
HULL = material("hull_plant", (0.055, 0.053, 0.057), rough=0.55, metal=0.55)
HAZARD = material("hazard", (0.75, 0.48, 0.02), rough=0.55)
CONCRETE = material("concrete", (0.13, 0.12, 0.11), rough=0.95)
INSULATOR = material("insulator", (0.22, 0.07, 0.03), rough=0.22)
WINDOW = material("window", (1.0, 0.82, 0.55), emit=(1.0, 0.8, 0.52), strength=3.5)
BEACON_RED = material("beacon_red", (1.0, 0.08, 0.03), emit=(1.0, 0.08, 0.03), strength=9.0)
BEACON_AMBER = material("beacon_amber", (1.0, 0.5, 0.05), emit=(1.0, 0.48, 0.05), strength=6.0)
REFLECT = material("reflector", (1.0, 0.5, 0.1), emit=(1.0, 0.46, 0.08), strength=1.6)
# The hazard sign's yellow glows faintly, as if lit by its floodlights, so it reads at night (and
# the gantry's post bands use it too, like retro-reflective tape in the headlights).
SIGN_FACE = material("sign_face", (0.8, 0.55, 0.02), rough=0.6, emit=(1.0, 0.7, 0.06), strength=0.5)
SIGN_INK = material("sign_ink", (0.006, 0.006, 0.006), rough=0.7)
SIGN_LAMP = material("sign_lamp", (1.0, 0.92, 0.7), emit=(1.0, 0.9, 0.66), strength=4.0)
# The hood. None of these names start with lava, vent, plume or beacon.
ARMOUR = material("armour", (0.05, 0.05, 0.055), rough=0.55, metal=0.55)
ARMOUR_PLATE = material("armour_plate", (0.085, 0.082, 0.085), rough=0.5, metal=0.6)
SEAM = material("seam", (0.008, 0.008, 0.009), rough=0.7)
BOLT = material("bolt", (0.3, 0.3, 0.31), rough=0.35, metal=0.9)
CHEVRON = material("chevron", (0.62, 0.4, 0.02), rough=0.55)
LAMP = material("lamp", (1.0, 0.9, 0.72), emit=(1.0, 0.88, 0.68), strength=9.0)
# Sits right beside the outer keys, so it only just glows (as on the other regions' hoods).
LAMP_BAR = material("lamp_bar", (0.5, 0.36, 0.2), emit=(1.0, 0.62, 0.25), strength=0.9)
MARKER = material("marker", (1.0, 0.5, 0.1), emit=(1.0, 0.46, 0.08), strength=3.5)

# A stroke font for the hazard sign: each letter is line segments on a 2-wide, 4-tall grid.
FONT = {
    "A": [(0, 0, 0, 4), (2, 0, 2, 4), (0, 4, 2, 4), (0, 2, 2, 2)],
    "D": [(0, 0, 0, 4), (0, 4, 1.4, 4), (1.4, 4, 2, 3.3), (2, 3.3, 2, 0.7), (2, 0.7, 1.4, 0), (1.4, 0, 0, 0)],
    "E": [(0, 0, 0, 4), (0, 4, 2, 4), (0, 2, 1.4, 2), (0, 0, 2, 0)],
    "N": [(0, 0, 0, 4), (2, 0, 2, 4), (0, 4, 2, 0)],
    "O": [(0, 0, 0, 4), (2, 0, 2, 4), (0, 4, 2, 4), (0, 0, 2, 0)],
    "R": [(0, 0, 0, 4), (0, 4, 2, 4), (2, 4, 2, 2), (0, 2, 2, 2), (0.9, 2, 2, 0)],
    "Z": [(0, 4, 2, 4), (2, 4, 0, 0), (0, 0, 2, 0)],
}


# ---------------------------------------------------------------- the Part model

class Part(Model):
    """A Model that bevels only the primitives built with bevel=True (after neon/props.py).

    Each bevelled primitive's edges get a bevel weight; at finish() the prop gets its own
    weight-limited bevel (`width` metres, two segments, hardened normals) and propkit's
    all-edges bevel is switched off (obj["bevel"] = 0). Every edge sharper than 35 degrees is
    marked sharp, so unbevelled detail and rock facets shade flat under propkit's weighted
    normals, and round things of 12+ segments stay smooth. width=0 makes a prop with no bevel.
    hull() adds the convex hull of a point cloud (rock chunks, strata, crystals). Rock props pass a
    lower `crease` (degrees), so neighbouring facets break sharply instead of shading smooth."""

    def __init__(self, name, width=0.03, crease=35.0):
        super().__init__(name)
        self.width = width
        self.crease = crease
        self.weight = self.bm.edges.layers.float.new("bevel_weight_edge")

    def index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

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

    def beam(self, a, b, r, mat, segs=4, bevel=False):
        a, b = Vector(a), Vector(b)
        if (b - a).length < 1e-4:
            return
        rot = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_euler()
        self.cyl(r, r, (b - a).length, (a + b) / 2, mat, segs=segs, rot=rot, bevel=bevel)

    def hull(self, pts, mat):
        """The convex hull of a point cloud, never bevelled (crisp facets). Points left inside the
        hull stay as loose vertices until finish() clears them: deleting them here would free
        slots that later primitives reuse, which breaks _mark's vertex-index ranges."""
        if len(pts) < 4:
            return
        vs = [self.bm.verts.new(p) for p in pts]
        out = bmesh.ops.convex_hull(self.bm, input=vs)
        idx = self.index(mat)
        for g in out["geom"]:
            if isinstance(g, bmesh.types.BMFace):
                g.material_index = idx

    def finish(self):
        bm = self.bm
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        crease = math.radians(self.crease)
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


# ---------------------------------------------------------------- geometry helpers

def shell(m, verts, faces, mats):
    """One connected surface with its own material per face (Model.poly paints a whole call one
    material). Uses Model's bmesh directly; nothing else touches these vertices."""
    vs = [m.bm.verts.new(v) for v in verts]
    for f, mat in zip(faces, mats):
        face = m.bm.faces.new([vs[i] for i in f])
        if mat not in m.mats:
            m.mats.append(mat)
        face.material_index = m.mats.index(mat)


def lathe(m, profile, segs, mats, loc=(0.0, 0.0, 0.0), jitter=0.0, seed=0, top_mat=None, turn=0.0):
    """A closed surface of revolution. `profile` is [(radius, z), ...] or [(radius, z, radial
    jitter, height jitter), ...] from the bottom up (no zero radii); mats[i] paints the band
    between points i and i+1; the top is capped with top_mat (or the last band's material). Radii
    and heights are jittered per vertex for a rough, lumpy, hand-made outline."""
    rr = random.Random(seed)
    cx, cy, cz = loc
    verts = []
    for p in profile:
        r, z = p[0], p[1]
        jr = p[2] if len(p) > 2 else jitter
        jz = p[3] if len(p) > 3 else 0.0
        for s in range(segs):
            a = TAU * s / segs + turn
            j = 1.0 + rr.uniform(-jr, jr)
            verts.append((cx + r * j * math.cos(a), cy + r * j * math.sin(a), cz + z + rr.uniform(-jz, jz)))
    faces, fmats = [], []
    for k in range(len(profile) - 1):
        for s in range(segs):
            s1 = (s + 1) % segs
            faces.append((k * segs + s, k * segs + s1, (k + 1) * segs + s1, (k + 1) * segs + s))
            fmats.append(mats[min(k, len(mats) - 1)])
    faces.append(tuple(reversed(range(segs))))
    fmats.append(mats[0])
    top = len(profile) - 1
    faces.append(tuple(top * segs + s for s in range(segs)))
    fmats.append(top_mat or mats[-1])
    shell(m, verts, faces, fmats)


def slab(m, pts, y0, y1, mat):
    """A convex outline in the X-Z plane, extruded from y0 to y1 (for sign faces and symbols)."""
    n = len(pts)
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    shell(m, verts, faces, [mat] * len(faces))


def prism(m, pts, nrm, d0, d1, mat):
    """A planar convex polygon (3D points, in order) extruded along nrm from offset d0 to d1."""
    n = Vector(nrm)
    k = len(pts)
    verts = [tuple(Vector(p) + n * d0) for p in pts] + [tuple(Vector(p) + n * d1) for p in pts]
    faces = [tuple(reversed(range(k))), tuple(range(k, 2 * k))]
    faces += [(i, (i + 1) % k, k + (i + 1) % k, k + i) for i in range(k)]
    shell(m, verts, faces, [mat] * len(faces))


def clip(poly, a, b, d):
    """The part of a convex polygon (points of 2 or 3 coordinates, in order) where a*x + b*y <= d
    (Sutherland-Hodgman, on x and y only; other coordinates are interpolated)."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        dp, dq = a * p[0] + b * p[1] - d, a * q[0] + b * q[1] - d
        if dp <= 0:
            out.append(p)
        if dp * dq < 0:
            t = dp / (dp - dq)
            out.append(tuple(p[j] + (q[j] - p[j]) * t for j in range(len(p))))
    return out


def ring_sector(m, cx, cz, r_in, r_out, a0, a1, y0, y1, mat, steps=5):
    """A flat ring sector in the X-Z plane (a blade of the radiation trefoil), made of convex quads
    joined into one closed slab."""
    pts_in = [(cx + r_in * math.cos(a0 + (a1 - a0) * k / steps), cz + r_in * math.sin(a0 + (a1 - a0) * k / steps))
              for k in range(steps + 1)]
    pts_out = [(cx + r_out * math.cos(a0 + (a1 - a0) * k / steps), cz + r_out * math.sin(a0 + (a1 - a0) * k / steps))
               for k in range(steps + 1)]
    n = steps + 1
    verts = []
    for y in (y0, y1):
        verts += [(x, y, z) for x, z in pts_in] + [(x, y, z) for x, z in pts_out]
    back = 2 * n
    faces = []
    for k in range(steps):
        faces.append((k, n + k, n + k + 1, k + 1))
        faces.append((back + k + 1, back + n + k + 1, back + n + k, back + k))
        faces.append((n + k, back + n + k, back + n + k + 1, n + k + 1))
        faces.append((k + 1, back + k + 1, back + k, k))
    faces.append((0, back, back + n, n))
    faces.append((steps, n + steps, back + n + steps, back + steps))
    shell(m, verts, faces, [mat] * len(faces))


def stroke_text(m, text, cx, cz, y, unit, mat, depth=0.05, stroke=None):
    """Block letters as stroke boxes standing just proud of a sign face lying in the X-Z plane at y
    (facing -Y, toward oncoming traffic), centred on (cx, cz), reading along +X."""
    stroke = stroke or unit * 0.5
    n = len(text)
    for k, ch in enumerate(text):
        ou, ov = -(n * 3 - 1) * unit / 2 + k * 3 * unit, -2 * unit
        for x0, y0, x1, y1 in FONT.get(ch, []):
            du, dv = (x1 - x0) * unit, (y1 - y0) * unit
            length = math.hypot(du, dv)
            mu, mv = ou + (x0 + x1) / 2 * unit, ov + (y0 + y1) / 2 * unit
            theta = math.atan2(-dv, du)
            m.box((length + stroke, depth, stroke), (cx + mu, y - depth / 2, cz + mv), mat, rot=(0, theta, 0),
                  bevel=False)


def strip(m, pts, width, z_of, mat, seed, rough=0.0):
    """A low jagged ridge along a polyline of (x, y) points: a triangular prism whose crest height
    comes from z_of(i) (plus jitter), for lava levees and fissure lips."""
    rr = random.Random(seed)
    n = len(pts)
    verts = []
    for i, (x, y) in enumerate(pts):
        if i == 0 or i == n - 1:
            nx, ny = 1.0, 0.0
        else:
            dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
            ln = math.hypot(dx, dy)
            nx, ny = dy / ln, -dx / ln
        h = z_of(i) * (1.0 + rr.uniform(-rough, rough))
        verts += [(x - nx * width / 2, y - ny * width / 2, -0.05), (x, y, h), (x + nx * width / 2, y + ny * width / 2, -0.05)]
    faces = []
    for i in range(n - 1):
        a, b = i * 3, (i + 1) * 3
        faces += [(a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2), (a + 2, b + 2, b, a)]
    faces += [(0, 1, 2), ((n - 1) * 3 + 2, (n - 1) * 3 + 1, (n - 1) * 3)]
    shell(m, verts, faces, [mat] * len(faces))


def jring(r, cx, cy, z, n, rad, jit=0.18, zjit=0.0, tilt=(0.0, 0.0), sx=1.0, sy=1.0, angles=None):
    """n points round an irregular ring (in angle order): radius and spacing jittered, optionally
    tilted (dz per metre in x and y) and roughened in height. Rock strata and chunks are hulls
    of these. Rings given the same `angles` line up, so a hull of them has upright facets."""
    a0 = r.uniform(0, TAU)
    pts = []
    for k in range(n):
        a = angles[k] if angles else a0 + TAU * (k + r.uniform(-0.3, 0.3)) / n
        rr = rad * r.uniform(1.0 - jit, 1.0 + jit * 0.4)
        x, y = cx + rr * math.cos(a) * sx, cy + rr * math.sin(a) * sy
        pts.append((x, y, z + tilt[0] * (x - cx) + tilt[1] * (y - cy) + r.uniform(-zjit, zjit)))
    return pts


def chunk(m, r, x, y, size, mat, n=10, bury=0.35, z=0.0):
    """A faceted rock chunk sitting on the ground at z: the hull of n points scattered over an
    ellipsoid of half-sizes `size`, turned to a random heading, its underside cut flat where
    `bury` of it would be below ground."""
    sx, sy, sz = size
    cz = z + sz * (1.0 - bury)
    a = r.uniform(0, TAU)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    # Points spread evenly over the sphere (a jittered Fibonacci spiral) and only a little in
    # radius: random ones leave half of them inside the hull, which made flat, few-sided flakes.
    for i in range(n):
        zz = 1.0 - 2.0 * (i + 0.5) / n + r.uniform(-0.5, 0.5) / n
        ring_r = math.sqrt(max(0.0, 1.0 - zz * zz))
        phi = i * 2.399963 + r.uniform(-0.35, 0.35)
        d = Vector((ring_r * math.cos(phi), ring_r * math.sin(phi), zz))
        k = r.uniform(0.84, 1.0)
        px, py = d.x * sx * k, d.y * sy * k
        pts.append((x + px * ca - py * sa, y + px * sa + py * ca, max(cz + d.z * sz * k, z - 0.06)))
    m.hull(pts, mat)
    return pts, (x, y, cz)


def drape(m, r, pts, centre, mat, reach=0.75, lift=1.05):
    """A crust draped over part of a rock: the rock's own hull points within `reach` (a cosine)
    of a random, mostly upward direction, pushed out by `lift` from its centre, hulled with the
    centre so the crust follows the rock's facets."""
    c = Vector(centre)
    aim = Vector((r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6), 1.0)).normalized()
    cap = [tuple(c + (Vector(p) - c) * lift) for p in pts if (Vector(p) - c).normalized().dot(aim) > reach]
    if len(cap) >= 3:
        m.hull(cap + [tuple(c + aim * 0.05)], mat)


def stripes(m, centre, u, v, w, h, mat, nrm, band=0.22, pitch=0.5, proud=0.012):
    """Diagonal hazard stripes cut as geometry over a w x h rectangle on a face: `centre` on the
    face, u and v unit vectors along its width and height, nrm out of it. Each stripe is a thin
    slab clipped to the rectangle, standing `proud` off the face."""
    c, u, v = Vector(centre), Vector(u), Vector(v)
    rect = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    s = -(w + h) / 2 + (pitch - band) / 2
    while s < (w + h) / 2:
        poly = clip(clip(rect, 1, 1, s + band), -1, -1, -s)
        if len(poly) >= 3:
            prism(m, [tuple(c + u * px + v * py) for px, py in poly], nrm, -0.004, proud, mat)
        s += pitch


def bolt(m, loc, normal, mat, r=0.035, h=0.06, hexed=True):
    """A bolt head (hexagonal, or a cheaper square one) standing out along `normal`."""
    rot = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_euler()
    if hexed:
        m.cyl(r, r, h, loc, mat, segs=6, rot=rot, bevel=False)
    else:
        m.box((r * 1.8, r * 1.8, h), loc, mat, rot=rot, bevel=False)


def flange_bolts(m, cx, cy, z, half, mat, r=0.035, h=0.12, hexed=True, mids=True):
    """Bolts through a square flange plate on a vertical member: corners, and mid-sides."""
    spots = [(-1, -1), (1, -1), (1, 1), (-1, 1)] + ([(0, -1), (1, 0), (0, 1), (-1, 0)] if mids else [])
    for bx, by in spots:
        bolt(m, (cx + bx * half, cy + by * half, z), (0, 0, 1), mat, r=r, h=h, hexed=hexed)


def railing(m, pts, z, mat, h=1.05, every=1.4, closed=False, post=0.06, rail=0.05):
    """Posts with a top and a knee rail along a polyline of (x, y) points, standing on a deck at z."""
    segs = list(zip(pts, pts[1:])) + ([(pts[-1], pts[0])] if closed else [])
    for (x0, y0), (x1, y1) in segs:
        length = math.hypot(x1 - x0, y1 - y0)
        n = max(1, round(length / every))
        ang = math.atan2(y1 - y0, x1 - x0)
        for k in range(n):
            t = k / n
            m.box((post, post, h), (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + h / 2), mat, bevel=False)
        for zz in (h, h * 0.5):
            m.box((length + post, rail, rail), ((x0 + x1) / 2, (y0 + y1) / 2, z + zz), mat, rot=(0, 0, ang),
                  bevel=False)
    if not closed:
        m.box((post, post, h), (pts[-1][0], pts[-1][1], z + h / 2), mat, bevel=False)


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


def tank(m, x, y, rad, h, body, trim, z=0.0, segs=16, hoops=(0.3, 0.62), ladder_out=(0, -1), plinth=None):
    """A vertical tank: optional plinth, a shell with hoops, a low conical roof, a caged ladder on
    the `ladder_out` side and a railing round the roof edge."""
    if plinth is not None:
        m.cyl(rad + 0.35, rad + 0.3, 0.35, (x, y, z + 0.175), plinth, segs=segs)
        z += 0.35
    m.cyl(rad, rad, h, (x, y, z + h / 2), body, segs=segs)
    m.cyl(rad + 0.05, rad * 0.3, rad * 0.35, (x, y, z + h + rad * 0.175), body, segs=segs, bevel=False)
    for t in hoops:
        m.cyl(rad + 0.05, rad + 0.05, 0.1, (x, y, z + h * t), trim, segs=segs, bevel=False)
    ox, oy = ladder_out
    ladder(m, (x + ox * (rad + 0.2), y + oy * (rad + 0.2)), z + 0.1, z + h + 1.05, (abs(oy), abs(ox)), ladder_out,
           trim, cage_from=z + 2.4)
    n = 10
    pts = [(x + (rad - 0.12) * math.cos(TAU * k / n), y + (rad - 0.12) * math.sin(TAU * k / n)) for k in range(n)]
    railing(m, pts, z + h, trim, h=1.0, every=10.0, closed=True, post=0.05, rail=0.04)


# ---------------------------------------------------------------- rock

def spire(m, r, x, y, height, rad, lean, heading, mats, strata=6, n=8):
    """A leaning basalt spire of stacked lava flows. Each stratum is the hull of three jittered
    rings (bulging at its middle, its top tilted and rough); the next one starts narrower, leaving a
    ledge where sulphur frost settles; big strata are sometimes split by a fracture with one half
    slumped. The spire leans along `heading`, more with height, so it kinks instead of standing
    straight, and ends in a slanted break with one jag standing up from it."""
    dx, dy = math.cos(heading), math.sin(heading)

    def radius(t):
        return rad * max(0.3, 1.0 - 0.72 * t ** 1.1)

    weights = [r.uniform(0.7, 1.3) for _ in range(strata)]
    cx, cy, z = x, y, 0.0
    for i in range(strata):
        h = height * weights[i] / sum(weights)
        t0, t1 = z / height, (z + h) / height
        shift = lean * h * (1.0 + 0.3 * i)
        nx_, ny_ = cx + dx * shift, cy + dy * shift
        r0 = radius(t0) * (1.05 if i == 0 else 0.86)
        r1 = radius(t1) * r.uniform(0.9, 1.0)
        last = i == strata - 1
        k_t = 0.55 if last else 0.12
        tilt = (r.uniform(-k_t, k_t), r.uniform(-k_t, k_t))
        a0 = r.uniform(0, TAU)
        angles = [a0 + TAU * (k + r.uniform(-0.32, 0.32)) / n for k in range(n)]
        lo = jring(r, cx, cy, z - 0.2, n, r0, jit=0.16, angles=angles)
        mid = jring(r, (cx + nx_) / 2, (cy + ny_) / 2, z + h * r.uniform(0.35, 0.65), n, max(r0, r1) * 1.02,
                    jit=0.16, angles=[a + r.uniform(-0.12, 0.12) for a in angles])
        hi = jring(r, nx_, ny_, z + h, n, r1, jit=0.16, zjit=min(0.35, h * 0.08), tilt=tilt, angles=angles)
        if last:
            ja = r.uniform(0, TAU)
            hi.append((nx_ + math.cos(ja) * r1 * 0.55, ny_ + math.sin(ja) * r1 * 0.55, z + h + r1 * r.uniform(0.9, 1.6)))
        mat = CRUST if r.random() < 0.18 else mats[i % len(mats)]
        if r0 > 0.9 and r.random() < 0.35:
            # A fracture: a vertical plane through the stratum; the far half slumps a little.
            ang = r.uniform(0, math.pi)
            fa, fb = math.cos(ang), math.sin(ang)
            d = fa * (cx + nx_) / 2 + fb * (cy + ny_) / 2 + r.uniform(-0.3, 0.3) * r0
            gap = r.uniform(0.08, 0.16)
            slump = r.uniform(0.08, 0.3)
            part_a = clip(lo, fa, fb, d - gap / 2) + clip(mid, fa, fb, d - gap / 2) + clip(hi[:n], fa, fb, d - gap / 2)
            part_b = clip(lo, -fa, -fb, -d - gap / 2) + clip(mid, -fa, -fb, -d - gap / 2) + clip(hi[:n], -fa, -fb,
                                                                                            -d - gap / 2)
            m.hull(part_a + hi[n:], mat)
            m.hull([(px, py, pz - slump) for px, py, pz in part_b], mat)
        else:
            m.hull(lo + mid + hi, mat)
        if i < strata - 1 and r.random() < 0.5:
            # Sulphur frost lying on the ledge this stratum leaves.
            ledge = jring(r, nx_, ny_, z + h - 0.02, n, r1 * 0.98, jit=0.12, tilt=tilt)
            crest = jring(r, nx_, ny_, z + h + 0.14, n, r1 * 0.86, jit=0.12, tilt=tilt)
            m.hull(ledge + crest, SULPHUR)
        cx, cy, z = nx_, ny_, z + h


def crag():
    """Jagged basalt spires of stacked, fractured lava flows rising from a rock plinth in a skirt of
    talus, sulphur frost on their ledges and patches at the foot, and a lava crack glowing at the
    foot on the road side (-X), its lips broken into crust."""
    m = Part("crag", width=0.0, crease=20.0)
    r = random.Random(11)
    m.hull(jring(r, 0.4, 0.4, -0.1, 11, 6.2, jit=0.22) + jring(r, 0.3, 0.3, 1.6, 10, 5.2, jit=0.3, zjit=0.6)
           + jring(r, 0.1, 0.2, 3.2, 8, 3.2, jit=0.35, zjit=0.5), BASALT_GREY)
    # Blocks fallen onto the plinth round the spires' feet.
    for _ in range(9):
        a = r.uniform(0, TAU)
        d = r.uniform(3.4, 5.4)
        s = r.uniform(0.7, 1.5)
        chunk(m, r, math.cos(a) * d, math.sin(a) * d, (s, s * 0.8, s * 0.7), r.choice([BASALT, BASALT_GREY]),
              n=9, bury=0.45, z=2.4 - 0.35 * d)
    for x, y, h, rad, lean, strata in ((0.0, 0.0, 19.0, 2.6, 0.07, 7), (2.8, 2.2, 13.0, 2.0, -0.11, 6),
                                       (-2.4, 3.4, 10.5, 1.8, 0.14, 5), (1.2, -3.2, 8.0, 1.7, -0.08, 5),
                                       (-3.0, -1.6, 6.0, 1.5, 0.18, 4), (4.6, -1.0, 5.0, 1.4, 0.1, 4)):
        heading = (0.0 if lean > 0 else math.pi) + r.uniform(-0.6, 0.6)
        spire(m, r, x, y, h, rad, abs(lean), heading, (BASALT, BASALT_GREY), strata=strata)
    # Talus: big blocks close in, smaller ones further out; heavier on the road side.
    for _ in range(46):
        a = r.uniform(0, TAU)
        d = r.uniform(4.6, 9.5)
        if math.cos(a) > 0.3 and r.random() < 0.5:
            a = math.pi - a  # bias toward -X, where it is seen
        s = 1.9 - 0.15 * d + r.uniform(-0.25, 0.25)
        chunk(m, r, math.cos(a) * d, math.sin(a) * d, (s, s * r.uniform(0.6, 1.0), s * r.uniform(0.5, 0.85)),
              r.choice([BASALT, BASALT_GREY, CRUST]), n=r.randint(12, 16))
    for x, y, s in ((-4.4, 2.2, 1.6), (-5.2, -2.6, 1.1), (3.8, 4.6, 1.3), (-1.2, 6.2, 0.9)):
        chunk(m, r, x, y, (s, s * 0.7, 0.22), SULPHUR, n=9, bury=0.5)
    # The lava crack on the road side, its lips broken into crust plates.
    for y0, y1, w, mat in ((-1.6, 2.0, 0.35, LAVA), (1.6, 3.6, 0.22, LAVA_HOT)):
        m.box((w, y1 - y0, 0.12), (-5.7, (y0 + y1) / 2, 0.02), mat, rot=(0, 0, 0.18), bevel=False)
    for k in range(7):
        y = -1.8 + k * 0.85
        for side in (-1, 1):
            chunk(m, r, -5.7 + side * r.uniform(0.35, 0.6) - 0.15 * y * 0.18, y, (0.32, 0.4, 0.14), CRUST, n=8,
                  bury=0.4)
    return m.finish()


def hex_prism(m, cx, cy, rad, turn, z0, tops, mat, bevel_top=False):
    """A hexagonal column segment from z0 up to a cap whose six corners sit at heights tops[k];
    bevel_top marks only the cap's rim for the bevel (the rest stays a crisp, cheap prism)."""
    ring = [(cx + rad * math.cos(turn + k * math.pi / 3), cy + rad * math.sin(turn + k * math.pi / 3))
            for k in range(6)]
    vs = [m.bm.verts.new((x, y, z0)) for x, y in ring] + [m.bm.verts.new((x, y, tops[k])) for k, (x, y) in
                                                          enumerate(ring)]
    idx = m.index(mat)
    faces = [m.bm.faces.new([vs[k] for k in reversed(range(6))]), m.bm.faces.new([vs[6 + k] for k in range(6)])]
    for k in range(6):
        k1 = (k + 1) % 6
        faces.append(m.bm.faces.new([vs[k], vs[k1], vs[6 + k1], vs[6 + k]]))
    for f in faces:
        f.material_index = idx
    if bevel_top:
        for k in range(6):
            e = m.bm.edges.get((vs[6 + k], vs[6 + (k + 1) % 6]))
            if e is not None:
                e[m.weight] = 1.0


def columns():
    """A cliff of jointed hexagonal basalt columns, tallest in the middle: each column is stacked
    segments (each a touch narrower and turned, so the joints read), its cap tilted and sometimes
    chipped; broken stumps in front (-X), sulphur crust on a few tops, and fallen column logs and
    blocks in the talus at the foot."""
    m = Part("columns", width=0.05, crease=20.0)
    r = random.Random(23)
    rad = 1.05
    dx, dy = rad * math.sqrt(3), rad * 1.5
    for j in range(-4, 4):
        for i in range(-2, 4):
            x = i * dx + (dx / 2 if j % 2 else 0.0) + r.uniform(-0.03, 0.03)
            y = j * dy + r.uniform(-0.03, 0.03)
            peak = 17.0 * math.exp(-(y / 7.0) ** 2) * (1.0 - 0.1 * (i + 2))
            h = max(1.2, peak + r.uniform(-3.0, 2.0))
            broken = i == -2 and r.random() < 0.6
            if broken:
                h = r.uniform(0.8, 3.0)  # the front row is broken off
            base_r = rad * 0.95 * r.uniform(0.96, 1.02)
            base_turn = math.pi / 6 + r.uniform(-0.05, 0.05)
            cr, turn, cx, cy = base_r, base_turn, x, y
            mat = BASALT if (i + j) % 3 else BASALT_GREY
            z = 0.0
            while z < h - 0.01:
                top = min(h, z + r.uniform(1.3, 2.8))
                if h - top < 0.6:
                    top = h
                last = top >= h
                if last:
                    k_t = 3.0 if broken else 1.0
                    tx, ty = r.uniform(-0.12, 0.12) * k_t, r.uniform(-0.12, 0.12) * k_t
                    tops = [top + (tx * math.cos(turn + k * math.pi / 3) + ty * math.sin(turn + k * math.pi / 3)) * cr
                            for k in range(6)]
                    chipped = broken or r.random() < 0.3
                    if chipped:
                        k = r.randrange(6)
                        tops[k] -= r.uniform(0.25, 0.55)
                        tops[(k + 1) % 6] -= r.uniform(0.1, 0.3)
                else:
                    tops = [top] * 6
                hex_prism(m, cx, cy, cr, turn, z, tops, mat, bevel_top=last)
                if last and not chipped and r.random() < 0.3:
                    s = 0.8
                    hex_prism(m, cx, cy, cr * s, turn, min(tops) - 0.05,
                              [top + (tx * math.cos(turn + k * math.pi / 3) + ty * math.sin(turn + k * math.pi / 3))
                               * cr * s + 0.1 for k in range(6)], SULPHUR)
                z = top
                # The next drum steps in or out a little, sits a touch off-centre and is turned, so
                # every joint shows as a lip or a notch (a steady taper read as one smooth prism).
                cr = base_r * r.uniform(0.92, 1.0)
                turn = base_turn + r.uniform(-0.08, 0.08)
                cx, cy = x + r.uniform(-0.04, 0.04), y + r.uniform(-0.04, 0.04)
    # Fallen column logs lying in the talus in front, partly buried, and a couple propped up.
    for k in range(12):
        lr = rad * r.uniform(0.82, 0.95)
        length = r.uniform(0.8, 2.3)
        x, y = r.uniform(-8.0, -4.6), r.uniform(-6.5, 6.5)
        pitch = math.pi / 2 + (r.uniform(0.35, 0.7) if k < 2 else r.uniform(-0.12, 0.12))
        m.cyl(lr, lr * 0.98, length, (x, y, lr * 0.72 + (0.4 if k < 2 else 0.0)), r.choice([BASALT, BASALT_GREY]),
              segs=6, rot=(pitch, r.uniform(-0.2, 0.2), r.uniform(0, TAU)), bevel=False)
    for _ in range(26):
        x, y = r.uniform(-8.5, -4.2), r.uniform(-7.5, 7.5)
        s = r.uniform(0.25, 0.8)
        chunk(m, r, x, y, (s, s * 0.8, s * 0.6), r.choice([BASALT, BASALT_GREY, CRUST]), n=r.randint(8, 10))
    for _ in range(8):
        a = r.uniform(0, TAU)
        x, y = 4.5 * math.cos(a) * 1.4, 7.0 * math.sin(a)
        s = r.uniform(0.4, 0.9)
        chunk(m, r, x, y, (s, s * 0.8, s * 0.6), r.choice([BASALT, BASALT_GREY]), n=9)
    for x, y in ((-5.4, 1.5), (-6.2, -3.8)):
        chunk(m, r, x, y, (1.2, 0.8, 0.18), SULPHUR, n=9, bury=0.5)
    return m.finish()


def spatter_cone():
    """A spatter cone: a rough black cone whose rim is a lumpy wall of welded spatter clots and
    horns, a lava pool in its crater with rafts of crust riding on it, a fountain of lava spurting
    from it, glowing spatter dribbling down the slopes, a sulphur skirt and bombs round the foot."""
    m = Part("spatter_cone", width=0.0, crease=20.0)
    outer = [(9.4, -0.05, 0.05, 0.0), (8.2, 0.8, 0.1, 0.2), (6.8, 2.2, 0.1, 0.3), (5.2, 3.9, 0.1, 0.32),
             (4.0, 5.4, 0.1, 0.3), (3.3, 6.5, 0.1, 0.3), (2.9, 7.0, 0.08, 0.35)]
    inner = [(2.4, 6.6, 0.08, 0.2), (2.0, 6.05, 0.05, 0.03)]
    lathe(m, outer + inner, 30, [SULPHUR, BASALT, BASALT, CRUST, BASALT, CRUST, CRUST, CRUST], seed=5,
          top_mat=LAVA_HOT)

    def slope_z(rad):
        """Height of the outer slope at a radius (linear between the profile's points)."""
        for p0, p1 in zip(outer, outer[1:]):
            if p1[0] <= rad <= p0[0]:
                return p0[1] + (p1[1] - p0[1]) * (p0[0] - rad) / (p0[0] - p1[0])
        return 0.0

    r = random.Random(7)
    # Crust rafts on the crater's lava, glowing seams between them.
    for k in range(6):
        a = TAU * k / 6 + r.uniform(-0.3, 0.3)
        d = r.uniform(0.45, 1.1)
        pr = r.uniform(0.32, 0.5)
        px, py = math.cos(a) * d, math.sin(a) * d
        m.hull(jring(r, px, py, 6.02, 6, pr, jit=0.25) + jring(r, px, py, 6.14, 6, pr * 0.8, jit=0.2), CRUST)
    # The rim: welded clots all round, and a few horns of stacked clots.
    for k in range(30):
        a = TAU * (k + r.uniform(-0.4, 0.4)) / 30
        d = r.uniform(2.6, 3.4)
        s = r.uniform(0.55, 1.05)
        chunk(m, r, math.cos(a) * d, math.sin(a) * d, (s, s * 0.8, s * 0.75), r.choice([CRUST, BASALT, CRUST]),
              n=10, bury=0.4, z=6.6 + r.uniform(-0.25, 0.15))
    for k in range(5):
        a = r.uniform(0, TAU)
        d = r.uniform(2.6, 3.1)
        z = 6.9
        s = r.uniform(0.55, 0.75)
        for _ in range(r.randint(2, 3)):
            chunk(m, r, math.cos(a) * d, math.sin(a) * d, (s, s * 0.8, s * 0.9), CRUST, n=9, bury=0.3, z=z)
            z += s * 1.1
            s *= 0.72
            d += r.uniform(-0.1, 0.15)
    # The fountain: a hot core rising well clear of the rim, and a spray of thinner jets fanning
    # out round it (one solid cone read as an orange post).
    m.cyl(0.55, 0.06, 7.0, (0.0, 0.0, 9.4), PLUME_HOT, segs=8, bevel=False)
    for k in range(7):
        a = TAU * k / 7 + r.uniform(-0.3, 0.3)
        lean = r.uniform(0.18, 0.45)
        length = r.uniform(3.0, 5.5)
        m.cyl(0.32, 0.03, length, (math.cos(a) * math.sin(lean) * length / 2, math.sin(a) * math.sin(lean) * length / 2,
                                   6.2 + math.cos(lean) * length / 2), PLUME_WARM if k % 2 else PLUME_HOT, segs=5,
              rot=(0, lean, a), bevel=False)
    for k in range(8):
        a = TAU * k / 8 + r.uniform(-0.2, 0.2)
        if math.cos(a) > 0.6:
            continue  # the far side (+X) is out of sight anyway
        # Spatter running down from the rim: a flat, wandering ribbon of lava lying on the slope,
        # narrowing as it runs, ending in a little toe (round beams read as neon tubes).
        foot_r = r.uniform(5.6, 8.2)
        width = r.uniform(0.3, 0.45)
        prev = None
        for rad in (3.0, 4.0, 5.0, 6.0, foot_r):
            if rad > foot_r:
                break
            aa = a + r.uniform(-0.05, 0.05)
            c = Vector((rad * math.cos(aa), rad * math.sin(aa), slope_z(rad) + 0.22))
            side = Vector((-math.sin(aa), math.cos(aa), 0.0))
            cur = [c + side * width, c - side * width, c + Vector((0, 0, 0.16))]
            if prev:
                m.hull([tuple(p) for p in prev + cur], LAVA)
            prev = cur
            width *= 0.85
        m.hull(jring(r, prev[2].x, prev[2].y, prev[2].z - 0.25, 6, width * 1.6, jit=0.25)
               + jring(r, prev[2].x, prev[2].y, prev[2].z - 0.05, 6, width * 1.1, jit=0.25), LAVA)
    # Bombs round the foot, and sulphur crusting the skirt.
    for _ in range(20):
        a = r.uniform(0, TAU)
        d = r.uniform(8.8, 12.5)
        s = r.uniform(0.5, 1.4)
        chunk(m, r, math.cos(a) * d, math.sin(a) * d, (s, s * 0.8, s * 0.6), r.choice([BASALT, CRUST, BASALT]),
              n=r.randint(8, 10))
    for _ in range(4):
        a = r.uniform(0, TAU)
        d = r.uniform(8.6, 9.8)
        chunk(m, r, math.cos(a) * d, math.sin(a) * d, (1.4, 0.9, 0.2), SULPHUR, n=9, bury=0.5)
    return m.finish()


def plume():
    """An Io umbrella plume, far off: a shield vent ringed with clots, a hot core of ejecta inside a
    wider glowing sheath, a broad faint canopy in two layers, and a curtain of fallout hanging from
    the canopy's rim. The sheath, canopy and fallout are drawn additive by the world script, so the
    whole plume stays see-through gas."""
    m = Part("plume", width=0.0, crease=20.0)
    lathe(m, [(16.0, -0.1, 0.05, 0.0), (12.5, 0.9, 0.1, 0.25), (8.5, 2.0, 0.1, 0.3), (5.6, 2.9, 0.08, 0.2),
              (4.4, 3.2, 0.05, 0.1)], 24, [BASALT, BASALT, CRUST, CRUST], seed=31, top_mat=LAVA_HOT)
    r = random.Random(37)
    for k in range(16):
        a = TAU * (k + r.uniform(-0.4, 0.4)) / 16
        d = r.uniform(4.6, 5.8)
        s = r.uniform(0.6, 1.2)
        chunk(m, r, math.cos(a) * d, math.sin(a) * d, (s, s * 0.8, s * 0.7), r.choice([BASALT, CRUST]), n=9,
              bury=0.5, z=2.8)
    lathe(m, [(3.0, 3.0), (3.4, 10.0), (4.4, 20.0), (6.2, 29.0), (8.5, 35.0)], 14, [PLUME_HOT, PLUME_HOT, PLUME_WARM,
                                                                                   PLUME_WARM],
          seed=33, jitter=0.06, top_mat=PLUME_WARM)
    lathe(m, [(4.2, 3.2), (5.0, 12.0), (6.8, 22.0), (9.6, 31.0), (12.5, 37.0)], 16, [PLUME_WARM], seed=34,
          jitter=0.08, turn=0.2)
    # The canopy: shallow domes from the column's top out to a wide, drooping rim, in two layers.
    lathe(m, [(33.0, 31.5), (30.0, 34.5), (21.0, 38.5), (10.0, 40.8), (3.0, 41.5)], 24, [PLUME_VEIL], seed=35,
          jitter=0.05, turn=0.1)
    lathe(m, [(35.5, 30.2), (32.0, 34.0), (23.0, 39.6), (11.0, 42.4), (3.0, 43.2)], 24, [PLUME_VEIL], seed=36,
          jitter=0.07, turn=0.25)
    # Fallout: thin streamers hanging from the rim, tapering away as they fall (not legs: widest at
    # the rim, uneven lengths, leaning outward).
    for k in range(20):
        a = TAU * (k + r.uniform(0.2, 0.8)) / 20
        length = r.uniform(6.0, 14.0)
        top = (math.cos(a) * 32.0, math.sin(a) * 32.0, 32.0)
        foot = (math.cos(a) * (33.0 + length * 0.15), math.sin(a) * (33.0 + length * 0.15), 32.0 - length)
        mid = ((top[0] + foot[0]) / 2, (top[1] + foot[1]) / 2, (top[2] + foot[2]) / 2)
        tilt = math.atan2(math.hypot(foot[0] - top[0], foot[1] - top[1]), top[2] - foot[2])
        m.cyl(0.15, r.uniform(0.9, 1.5), length, mid, PLUME_VEIL, segs=5, rot=(0, -tilt, a), bevel=False)
    return m.finish()


def fissure():
    """A lava-vent fissure: a zigzag crack 16 long, glowing lava in it between raised crust lips
    broken into tilted plates (pressure ridges), hot spots, sulphur crusting the outer edges and
    spatter along it. Low (under 0.8), so it can lie near the road."""
    m = Part("fissure", width=0.0, crease=20.0)
    r = random.Random(41)
    pts = []
    for k in range(9):
        y = -8.0 + 16.0 * k / 8
        pts.append((r.uniform(-0.5, 0.5) if 0 < k < 8 else 0.0, y))
    for k in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(x1 - x0, y1 - y0)
        width = 0.55 + 0.35 * math.sin(math.pi * (k + 0.5) / 8)
        m.box((width, length + 0.3, 0.12), ((x0 + x1) / 2, (y0 + y1) / 2, 0.03), LAVA, rot=(0, 0, -ang), bevel=False)
        if k in (2, 5):
            m.box((width * 0.45, length * 0.6, 0.14), ((x0 + x1) / 2, (y0 + y1) / 2, 0.05), LAVA_HOT,
                  rot=(0, 0, -ang), bevel=False)
    for side in (-1, 1):
        lip = [(x + side * 0.85, y) for x, y in pts]
        strip(m, lip, 1.0, lambda i: 0.45 + 0.2 * math.sin(i * 1.3), CRUST, seed=43 + side, rough=0.3)
        # Crust plates heaved up along the lip, tilted up toward the crack.
        for k in range(10):
            y = -7.4 + k * 1.6 + r.uniform(-0.4, 0.4)
            xc = pts[min(8, max(0, int((y + 8.0) / 2.0)))][0] + side * r.uniform(1.25, 1.75)
            pr = r.uniform(0.38, 0.7)
            tilt = (-side * r.uniform(0.25, 0.45), r.uniform(-0.1, 0.1))
            m.hull(jring(r, xc, y, 0.0, 6, pr, jit=0.25, tilt=tilt) + jring(r, xc, y, 0.12, 6, pr * 0.85, jit=0.2,
                                                                          tilt=tilt), r.choice([CRUST, BASALT]))
        for k in range(5):
            y = r.uniform(-7.0, 7.0)
            xc = side * r.uniform(2.1, 2.8)
            chunk(m, r, xc, y, (0.7, 1.1, 0.12), SULPHUR, n=8, bury=0.5)
    for _ in range(10):
        y = r.uniform(-7.5, 7.5)
        s = r.uniform(0.15, 0.4)
        chunk(m, r, r.choice([-1, 1]) * r.uniform(1.8, 3.0), y, (s, s * 0.8, s * 0.55), r.choice([CRUST, BASALT]),
              n=8)
    return m.finish()


def lava_river():
    """One LAVA_TILE of a lava river running beside the road: glowing lava between levees of
    broken black blocks, rafts of crust riding on it (some split, glowing through the crack),
    hot seams between them and sulphur crusting the far bank. The levees' base heights at both
    ends match, so repeats join up; nothing crosses the tile's ends."""
    m = Part("lava_river", width=0.0, crease=20.0)
    r = random.Random(51)
    half = LAVA_TILE / 2
    width = 7.0
    m.box((width, LAVA_TILE, 0.1), (0.0, 0.0, 0.0), LAVA, bevel=False)
    for _ in range(7):
        y = r.uniform(-half + 1.8, half - 1.8)
        x = r.uniform(-1.6, 1.6)
        rad = r.uniform(0.8, 1.45)
        lo = jring(r, x, y, 0.05, 7, rad, jit=0.25, sy=1.4)
        hi = jring(r, x, y, r.uniform(0.14, 0.22), 7, rad * 0.8, jit=0.25, sy=1.4)
        if rad > 1.05 and r.random() < 0.6:
            ang = r.uniform(0, math.pi)
            fa, fb = math.cos(ang), math.sin(ang)
            d = fa * x + fb * y
            m.hull(clip(lo, fa, fb, d - 0.08) + clip(hi, fa, fb, d - 0.08), CRUST)
            m.hull(clip(lo, -fa, -fb, -d - 0.08) + clip(hi, -fa, -fb, -d - 0.08), CRUST)
        else:
            m.hull(lo + hi, CRUST)
    for _ in range(4):
        y = r.uniform(-half + 1.0, half - 1.0)
        m.box((r.uniform(0.15, 0.3), r.uniform(1.5, 3.0), 0.1), (r.uniform(-2.5, 2.5), y, 0.06), LAVA_HOT,
              rot=(0, 0, r.uniform(-0.5, 0.5)), bevel=False)
    n = 9
    for side in (-1, 1):
        pts = [(side * (width / 2 + 0.6), -half + LAVA_TILE * k / (n - 1)) for k in range(n)]
        crest = [0.75 + (0.0 if k in (0, n - 1) else r.uniform(-0.25, 0.45)) for k in range(n)]
        strip(m, pts, 1.8, lambda i, c=crest: c[i], CRUST, seed=53 + side)
        for k in range(12):
            y = -half + 1.0 + k * (LAVA_TILE - 2.0) / 11 + r.uniform(-0.4, 0.4)
            s = r.uniform(0.5, 0.85)
            chunk(m, r, side * (width / 2 + 0.6 + r.uniform(-0.35, 0.35)), y, (s, s * 1.3, s * 0.8), CRUST, n=12,
                  bury=0.35, z=0.2)
    for _ in range(3):
        y = r.uniform(-half + 2.0, half - 2.0)
        chunk(m, r, width / 2 + 1.9, y, (0.7, 1.0, 0.16), SULPHUR, n=8, bury=0.5)
    return m.finish()


# ---------------------------------------------------------------- scatter

def sulphur_rock():
    """A faceted basalt lump with a sulphur crust draped over its top, an orange accretion at its
    foot, a fleck of frost and two chips beside it. Scattered by the hundred."""
    m = Part("sulphur_rock", width=0.0, crease=20.0)
    r = random.Random(84)
    pts, centre = chunk(m, r, 0.0, 0.0, (0.52, 0.42, 0.36), BASALT, n=26, bury=0.25)
    drape(m, r, pts, centre, SULPHUR, reach=0.45, lift=1.06)
    drape(m, r, pts, centre, FROST, reach=0.93, lift=1.1)
    pts2, centre2 = chunk(m, r, 0.46, -0.3, (0.24, 0.2, 0.17), BASALT_GREY, n=11, bury=0.3)
    drape(m, r, pts2, centre2, SULPHUR_ORANGE, reach=0.3, lift=1.07)
    chunk(m, r, -0.6, -0.12, (0.13, 0.1, 0.09), BASALT, n=8)
    chunk(m, r, 0.22, 0.52, (0.1, 0.08, 0.07), SULPHUR, n=8)
    return m.finish()


def bipyramid(m, base, axis, length, wa, wb, mat, turn=0.0, waist=(0.4, 0.62)):
    """An elongated rhombic bipyramid, sulphur's own crystal habit: a point at `base`, widening to a
    short four-sided prism (half-widths wa, wb) and tapering to a sharp point along `axis`."""
    a = Vector(axis).normalized()
    u = Vector((1, 0, 0)) if abs(a.x) < 0.9 else Vector((0, 1, 0))
    u = (u - a * u.dot(a)).normalized()
    v = a.cross(u)
    u, v = u * math.cos(turn) + v * math.sin(turn), v * math.cos(turn) - u * math.sin(turn)
    b = Vector(base)
    rings = []
    for t in waist:
        c = b + a * length * t
        rings.append([c + u * wa, c + v * wb, c - u * wa, c - v * wb])
    verts = [tuple(b)] + [tuple(p) for p in rings[0]] + [tuple(p) for p in rings[1]] + [tuple(b + a * length)]
    faces = [(0, 1 + (k + 1) % 4, 1 + k) for k in range(4)]
    faces += [(1 + k, 1 + (k + 1) % 4, 5 + (k + 1) % 4, 5 + k) for k in range(4)]
    faces += [(5 + k, 5 + (k + 1) % 4, 9) for k in range(4)]
    shell(m, verts, faces, [mat] * len(faces))


def crystal():
    """A cluster of sulphur crystals: sharp, elongated bipyramids fanning out of a crust base."""
    m = Part("crystal", width=0.0, crease=20.0)
    r = random.Random(61)
    chunk(m, r, 0.0, 0.0, (0.32, 0.26, 0.12), CRUST, n=9, bury=0.3)
    for k in range(8):
        h = r.uniform(0.3, 0.95) * (1.0 if k else 1.15)
        tilt = r.uniform(0.0, 0.55) if k else 0.08
        heading = r.uniform(0, TAU)
        axis = (math.sin(tilt) * math.cos(heading), math.sin(tilt) * math.sin(heading), math.cos(tilt))
        x, y = r.uniform(-0.16, 0.16), r.uniform(-0.14, 0.14)
        w = r.uniform(0.08, 0.13) * (0.7 + 0.5 * h)
        bipyramid(m, (x, y, 0.1 - h * 0.15), axis, h, w, w * r.uniform(0.7, 0.95), CRYSTAL, turn=r.uniform(0, TAU),
                  waist=(0.22, 0.68))
    return m.finish()


def vent():
    """A small fumarole: a lumpy crust mound ringed with sulphur, accretions round its throat,
    glowing deep inside."""
    m = Part("vent", width=0.0, crease=20.0)
    lathe(m, [(1.0, -0.05, 0.1, 0.0), (0.75, 0.2, 0.15, 0.05), (0.42, 0.42, 0.15, 0.05), (0.27, 0.5, 0.1, 0.03),
              (0.2, 0.44, 0.05, 0.0)], 10, [SULPHUR, CRUST, CRUST, CRUST], seed=71, top_mat=VENT_GLOW)
    r = random.Random(73)
    for k in range(6):
        a = TAU * k / 6 + r.uniform(-0.3, 0.3)
        s = r.uniform(0.08, 0.14)
        chunk(m, r, math.cos(a) * 0.36, math.sin(a) * 0.36, (s, s * 0.8, s * 0.7), SULPHUR, n=7, bury=0.4, z=0.4)
    for _ in range(2):
        a = r.uniform(0, TAU)
        chunk(m, r, math.cos(a) * 1.05, math.sin(a) * 1.05, (0.14, 0.11, 0.09), CRUST, n=7)
    return m.finish()


# ---------------------------------------------------------------- industry

def drill_rig():
    """A magma-tap drill rig. A braced substructure on pads carries a railed deck (hazard-striped
    skirt and stairs on the road side, -X); on it a lattice derrick (girts and X-bracing, the road
    face's lowest bay left open as the V-door, a monkey board with a railing, crown sheaves under an
    A-frame with a red beacon, red lights halfway up), a travelling block and top drive hanging on
    guide rails, the drill string into a rotary table glowing at the bore, and a dog house with a
    lit, framed window, a door, an air-con unit and an antenna. Under the deck a BOP stack sits over
    the glowing melt; behind (+X) coolant tanks with caged ladders, generators with exhaust stacks
    and a melt pipe on supports, glowing at its joints; in front (-Y) a pipe rack."""
    m = Part("drill_rig", width=0.04)
    dz, top = 1.6, 26.0
    # Substructure: pads, eight legs, X-bracing round the sides.
    ring8 = [(-4, -4), (0, -4), (4, -4), (4, 0), (4, 4), (0, 4), (-4, 4), (-4, 0)]
    for x, y in ring8:
        m.box((0.9, 0.9, 0.2), (x, y, 0.1), HULL)
        m.box((0.4, 0.4, dz - 0.6), (x, y, 0.2 + (dz - 0.6) / 2), STEEL)
    for k in range(8):
        (x0, y0), (x1, y1) = ring8[k], ring8[(k + 1) % 8]
        m.beam((x0, y0, 0.3), (x1, y1, dz - 0.45), 0.05, STEEL)
        m.beam((x1, y1, 0.3), (x0, y0, dz - 0.45), 0.05, STEEL)
    # Deck: plate, edge beams, a hazard-striped skirt on the road side, railing, stairs.
    m.box((9.0, 9.0, 0.14), (0, 0, dz - 0.07), HULL)
    for s in (-1, 1):
        m.box((9.3, 0.3, 0.4), (0, s * 4.5, dz - 0.3), STEEL)
        m.box((0.3, 9.3, 0.4), (s * 4.5, 0, dz - 0.3), STEEL)
    m.box((0.05, 9.0, 0.36), (-4.675, 0, dz - 0.3), HAZARD, bevel=False)
    stripes(m, (-4.7, 0, dz - 0.3), (0, 1, 0), (0, 0, 1), 9.0, 0.36, HULL, (-1, 0, 0), band=0.2, pitch=0.46)
    railing(m, [(-4.4, -0.4), (-4.4, 2.3)], dz, STEEL)
    railing(m, [(-4.4, 3.5), (-4.4, 4.4), (4.4, 4.4), (4.4, -4.4), (-0.9, -4.4)], dz, STEEL)
    sy, run = 2.9, 1.9
    for k in range(1, 7):
        t = k / 7
        m.box((0.32, 1.0, 0.05), (-4.6 - t * run, sy, dz - t * dz), STEEL, bevel=False)
    for s in (-1, 1):
        m.beam((-4.6, sy + s * 0.53, dz - 0.05), (-4.6 - run, sy + s * 0.53, -0.05), 0.06, STEEL)
        m.beam((-4.45, sy + s * 0.56, dz + 1.0), (-4.6 - run, sy + s * 0.56, 1.0), 0.03, STEEL, segs=6)
        m.box((0.05, 0.05, 1.0), (-4.6 - run, sy + s * 0.56, 0.5), STEEL, bevel=False)
    # Deck corner beacons (the dog house roof has the fourth).
    for sx, sy_ in ((1, -1), (1, 1), (-1, 1)):
        m.box((0.1, 0.1, 0.9), (sx * 4.45, sy_ * 4.45, dz + 0.45), STEEL, bevel=False)
        m.box((0.34, 0.34, 0.34), (sx * 4.45, sy_ * 4.45, dz + 1.07), BEACON_AMBER, bevel=False)

    # The derrick.
    def leg(sx, sy_, z):
        t = (z - dz) / (top - dz)
        s = 3.0 - 2.2 * t
        return (sx * s, sy_ * s, z)

    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    levels = [dz, 5.9, 10.2, 14.4, 18.5, 22.4, top]
    for c in corners:
        m.beam(leg(*c, dz), leg(*c, top), 0.17, STEEL)
        m.box((0.7, 0.7, 0.1), (c[0] * 3.0, c[1] * 3.0, dz + 0.05), STEEL, bevel=False)
    for i in range(len(levels) - 1):
        z0, z1 = levels[i], levels[i + 1]
        for k in range(4):
            a, b = corners[k], corners[(k + 1) % 4]
            m.beam(leg(*a, z1), leg(*b, z1), 0.08, STEEL)
            if i == 0 and k == 3:
                continue  # the V-door: the road face's lowest bay is open
            m.beam(leg(*a, z0), leg(*b, z1), 0.05, STEEL)
            m.beam(leg(*b, z0), leg(*a, z1), 0.05, STEEL)
    zb = levels[4]
    s = leg(1, 1, zb)[0]
    m.box((1.7, 2.6, 0.08), (-s - 0.75, 0, zb), HULL, bevel=False)
    railing(m, [(-s, -1.25), (-s - 1.6, -1.25), (-s - 1.6, 1.25), (-s, 1.25)], zb, STEEL, h=1.0, every=1.2)
    for sy_ in (-1.2, 1.2):
        m.beam((-s, sy_, zb - 1.0), (-s - 1.5, sy_, zb - 0.05), 0.04, STEEL)
    for sy_ in (-1, 1):
        p = leg(-1, sy_, levels[3])
        m.box((0.28, 0.28, 0.28), (p[0] - 0.25, p[1], p[2] + 0.1), BEACON_RED, bevel=False)
    # Crown: block, sheaves on a shaft, an A-frame with the aviation light.
    m.box((2.4, 2.4, 0.45), (0, 0, top + 0.22), STEEL)
    m.cyl(0.08, 0.08, 2.0, (0, 0, top + 0.85), STEEL, segs=6, rot=ALONG_Y, bevel=False)
    for k in range(4):
        m.cyl(0.5, 0.5, 0.12, (0, -0.6 + k * 0.4, top + 0.85), HULL, segs=14, rot=ALONG_Y, bevel=False)
    for sx in (-1, 1):
        m.beam((sx * 1.0, 0, top + 0.45), (0, 0, top + 2.0), 0.06, STEEL)
    m.cyl(0.08, 0.08, 0.3, (0, 0, top + 2.1), STEEL, segs=6, bevel=False)
    m.box((0.42, 0.42, 0.42), (0, 0, top + 2.45), BEACON_RED, bevel=False)
    # Travelling block on its lines, top drive on guide rails, the string into the rotary table.
    for sy_ in (-1, 1):
        m.box((0.12, 0.14, top - dz - 2.5), (0.75, sy_ * 0.55, (top + dz) / 2 - 0.5), STEEL, bevel=False)
    for ox, oy in ((-0.3, -0.25), (0.3, -0.25), (-0.3, 0.25), (0.3, 0.25)):
        m.beam((ox, oy * 2.4, top), (ox * 0.6, oy, 15.3), 0.025, STEEL)
    m.box((0.9, 0.7, 1.3), (0, 0, 14.7), HULL)
    m.cyl(0.1, 0.1, 0.6, (0, 0, 13.8), STEEL, segs=8, bevel=False)
    m.box((1.2, 1.2, 1.8), (0, 0, 12.6), HULL)
    for sy_ in (-1, 1):
        m.cyl(0.26, 0.26, 0.9, (-0.2, sy_ * 0.38, 13.95), STEEL, segs=12)
    hose = [(0.6, 0.0, 13.2), (1.0, 0.6, 12.3), (1.4, 1.2, 11.9), (1.7, 1.6, 12.1), (1.9, 1.9, 12.6)]
    for p0, p1 in zip(hose, hose[1:]):
        m.beam(p0, p1, 0.07, HULL, segs=6)
    m.beam((1.9, 1.9, dz), (1.9, 1.9, 12.6), 0.07, STEEL, segs=6)
    m.cyl(0.11, 0.11, 11.7 - dz - 0.35, (0, 0, (dz + 0.35 + 11.7) / 2), STEEL, segs=8, bevel=False)
    m.cyl(1.1, 1.1, 0.35, (0, 0, dz + 0.17), HULL, segs=16)
    m.cyl(0.42, 0.42, 0.37, (0, 0, dz + 0.18), LAVA_HOT, segs=12, bevel=False)
    # Under the deck: the BOP stack over the melt, rams with handwheels.
    zz = 0.15
    for rad, h in ((0.62, 0.3), (0.75, 0.45), (0.6, 0.3)):
        m.cyl(rad, rad, h, (0, 0, zz + h / 2), HULL, segs=14)
        m.cyl(rad + 0.1, rad + 0.1, 0.07, (0, 0, zz + h), STEEL, segs=14, bevel=False)
        zz += h
    m.cyl(0.32, 0.32, dz - 0.15 - zz, (0, 0, (zz + dz - 0.15) / 2), STEEL, segs=10, bevel=False)
    for sy_ in (-1, 1):
        m.box((0.5, 0.7, 0.36), (0, sy_ * 0.95, 0.67), HULL)
        m.cyl(0.22, 0.22, 0.05, (0, sy_ * 1.33, 0.67), STEEL, segs=10, rot=ALONG_Y, bevel=False)
    m.cyl(1.5, 1.5, 0.06, (0, 0, 0.03), LAVA_HOT, segs=16, bevel=False)
    # The dog house on the road side: a lit window toward the road, door, air-con, antenna, beacon.
    cx, cy, w, d, h = -2.6, -2.4, 3.2, 3.6, 2.8
    m.box((w, d, h), (cx, cy, dz + h / 2), HULL)
    m.box((w + 0.25, d + 0.25, 0.16), (cx, cy, dz + h + 0.08), HULL)
    m.box((0.05, d + 0.25, 0.3), (cx - w / 2 - 0.15, cy, dz + h - 0.05), HAZARD, bevel=False)
    stripes(m, (cx - w / 2 - 0.175, cy, dz + h - 0.05), (0, 1, 0), (0, 0, 1), d + 0.25, 0.3, HULL, (-1, 0, 0),
            band=0.14, pitch=0.32)
    wx = cx - w / 2 - 0.03
    m.box((0.05, 2.2, 0.95), (wx, cy + 0.2, dz + 1.75), WINDOW, bevel=False)
    for dzz in (-0.5, 0.5):
        m.box((0.1, 2.36, 0.08), (wx - 0.02, cy + 0.2, dz + 1.75 + dzz), STEEL, bevel=False)
    for dyy in (-1.14, 0.0, 1.14):
        m.box((0.1, 0.08, 1.0), (wx - 0.02, cy + 0.2 + dyy, dz + 1.75), STEEL, bevel=False)
    m.box((0.5, 2.5, 0.06), (wx - 0.25, cy + 0.2, dz + 2.33), STEEL, rot=(0, -0.25, 0), bevel=False)
    door_y = cy + d / 2 + 0.02
    m.box((0.95, 0.06, 2.05), (cx + 0.7, door_y, dz + 1.03), HULL)
    for sx in (-1, 1):
        m.box((0.08, 0.1, 2.15), (cx + 0.7 + sx * 0.52, door_y, dz + 1.08), STEEL, bevel=False)
    m.box((1.12, 0.1, 0.08), (cx + 0.7, door_y, dz + 2.15), STEEL, bevel=False)
    m.box((0.05, 0.08, 0.2), (cx + 1.05, door_y + 0.05, dz + 1.05), STEEL, bevel=False)
    m.box((1.0, 0.5, 0.75), (cx + 0.6, cy - d / 2 - 0.25, dz + 1.9), HULL)
    for k in range(4):
        m.box((0.86, 0.04, 0.04), (cx + 0.6, cy - d / 2 - 0.52, dz + 1.65 + k * 0.16), STEEL, bevel=False)
    m.beam((cx + 1.0, cy + 1.2, dz + h + 0.16), (cx + 1.0, cy + 1.2, dz + h + 2.8), 0.035, STEEL, segs=6)
    m.box((0.32, 0.32, 0.3), (cx - w / 2 + 0.35, cy - d / 2 + 0.35, dz + h + 0.31), BEACON_AMBER, bevel=False)
    # Behind: coolant tanks, generators, the melt pipe.
    tank(m, 7.4, 2.8, 1.3, 5.0, HULL, STEEL, ladder_out=(0, -1), segs=14)
    tank(m, 7.4, 5.9, 1.3, 5.0, HULL, STEEL, ladder_out=(1, 0), segs=14)
    m.beam((6.1, 2.8, 2.2), (4.4, 2.8, 2.2), 0.12, STEEL, segs=8)
    m.cyl(0.2, 0.2, 0.08, (5.3, 2.8, 2.2), STEEL, segs=8, rot=ALONG_X, bevel=False)
    gx, gy = 7.4, -3.6
    m.box((3.6, 2.2, 0.2), (gx, gy, 0.1), STEEL)
    m.box((3.2, 1.9, 1.8), (gx, gy, 1.1), HULL)
    for k in range(6):
        m.box((0.04, 1.7, 0.06), (gx - 1.62, gy, 0.5 + k * 0.22), STEEL, bevel=False)
    m.cyl(0.3, 0.3, 1.5, (gx + 0.3, gy, 2.35), STEEL, segs=10, rot=ALONG_X, bevel=False)
    for ex in (-0.3, 0.9):
        m.cyl(0.13, 0.13, 2.2, (gx + ex, gy, 3.4), STEEL, segs=8, bevel=False)
        m.box((0.36, 0.36, 0.04), (gx + ex + 0.06, gy, 4.55), STEEL, rot=(0, 0.45, 0), bevel=False)
    py = -0.9
    m.cyl(0.3, 0.3, 10.0, (5.5, py, 0.85), STEEL, segs=10, rot=ALONG_X, bevel=False)
    for x in (3.0, 5.6, 8.2, 10.4):
        m.cyl(0.4, 0.4, 0.1, (x, py, 0.85), STEEL, segs=10, rot=ALONG_X, bevel=False)
    for x in (4.3, 9.3):
        m.cyl(0.33, 0.33, 0.35, (x, py, 0.85), LAVA_HOT, segs=10, rot=ALONG_X, bevel=False)
    for x in (6.9, 9.9):
        m.box((0.2, 0.2, 0.5), (x, py, 0.25), STEEL, bevel=False)
        m.box((0.2, 0.9, 0.12), (x, py, 0.52), STEEL, bevel=False)
    # In front: a rack of drill pipe.
    for x in (-3.0, 0.6, 4.2):
        for yy in (-6.5, -7.5):
            m.box((0.16, 0.16, 2.4), (x, yy, 1.2), STEEL, bevel=False)
        for z in (1.15, 2.15):
            m.box((0.16, 1.3, 0.14), (x, -7.0, z), STEEL, bevel=False)
    for yy, z in ((-7.3, 1.36), (-6.95, 1.36), (-6.6, 1.36), (-7.2, 2.36), (-6.8, 2.36)):
        m.cyl(0.14, 0.14, 8.6, (0.6, yy, z), HULL, segs=8, rot=ALONG_X, bevel=False)
    return m.finish()


def smelter():
    """An ore smelter. A furnace hall on a concrete plinth: clad walls with steel pilasters and
    girts, a pitched roof with a ridge monitor glowing through its louvres, a hazard band under the
    eaves on the road face (-X). On that face the furnace mouth (heavy surround, raised door in its
    guides, a hood) runs slag down a launder into a walled slag bay; a slag-pot car stands on rails
    beside it; a catwalk with a railing and a caged ladder, and a personnel door. Behind (+X) two
    tanks with caged ladders piped to the hall; at the +Y end an ore heap and a conveyor truss from
    its feed hopper up into the gable; at the -Y end a flue duct into a tall banded concrete stack
    with platforms, a ladder, red beacons and a glow at its mouth. Amber beacons on the roof."""
    m = Part("smelter", width=0.05)
    r = random.Random(101)
    W, D, H = 4.0, 6.0, 6.0
    pitch = math.radians(14.0)
    ridge = H + 0.4 + (W + 0.4) * math.sin(pitch)
    m.box((2 * W + 0.8, 2 * D + 0.8, 0.4), (0, 0, 0.2), CONCRETE)
    m.box((2 * W, 2 * D, H - 0.4), (0, 0, 0.4 + (H - 0.4) / 2), HULL)
    for k in range(7):
        y = -D + k * 2.0
        for sx in (-1, 1):
            m.box((0.3, 0.32, H - 0.4), (sx * (W + 0.1), y, 0.4 + (H - 0.4) / 2), STEEL, bevel=False)
    for x in (-W, -2.0, 0.0, 2.0, W):
        for sy in (-1, 1):
            m.box((0.32, 0.3, H - 0.4), (x, sy * (D + 0.1), 0.4 + (H - 0.4) / 2), STEEL, bevel=False)
    for z in (2.4, 4.2):
        for sx in (-1, 1):
            m.box((0.14, 2 * D, 0.14), (sx * (W + 0.07), 0, z), STEEL, bevel=False)
    m.box((2 * W + 0.5, 2 * D + 0.5, 0.4), (0, 0, H + 0.2), STEEL)
    half = (W + 0.4) / 2
    for sx in (-1, 1):
        m.box((W + 0.4, 2 * D + 0.6, 0.16), (sx * half * math.cos(pitch), 0, H + 0.4 + half * math.sin(pitch)), HULL,
              rot=(0, sx * pitch, 0))
    for sy in (-1, 1):
        prism(m, [(-W - 0.3, sy * D, H + 0.4), (W + 0.3, sy * D, H + 0.4), (0, sy * D, ridge)], (0, sy, 0), -0.1,
              0.1, HULL)
    # The ridge monitor: furnace light glowing between louvres.
    m.box((1.9, 2 * D - 1.0, 0.14), (0, 0, ridge + 1.15), HULL)
    m.box((1.2, 2 * D - 1.4, 0.8), (0, 0, ridge + 0.6), LAVA_HOT, bevel=False)
    for sx in (-1, 1):
        for k in range(4):
            m.box((0.05, 2 * D - 1.2, 0.2), (sx * 0.8, 0, ridge + 0.3 + k * 0.24), STEEL, rot=(0, sx * 0.6, 0),
                  bevel=False)
    for sy in (-1, 1):
        m.box((1.8, 0.1, 1.1), (0, sy * (D - 0.55), ridge + 0.6), HULL)
    # Hazard band under the eaves on the road face.
    m.box((0.05, 2 * D + 0.4, 0.45), (-W - 0.28, 0, H - 0.3), HAZARD, bevel=False)
    stripes(m, (-W - 0.305, 0, H - 0.3), (0, 1, 0), (0, 0, 1), 2 * D + 0.4, 0.45, HULL, (-1, 0, 0), band=0.22,
            pitch=0.5)
    # The furnace mouth, its door raised in guides, a hood over it.
    fy = -2.0
    m.box((0.7, 4.4, 3.6), (-W - 0.35, fy, 0.4 + 1.8), HULL)
    m.box((0.1, 2.6, 1.9), (-W - 0.68, fy, 0.4 + 1.0), LAVA_HOT, bevel=False)
    for sy in (-1, 1):
        m.box((0.2, 0.3, 2.3), (-W - 0.8, fy + sy * 1.45, 0.4 + 1.15), STEEL, bevel=False)
        m.box((0.16, 0.16, 4.2), (-W - 0.95, fy + sy * 1.65, 2.9), STEEL, bevel=False)
    m.box((0.2, 3.1, 0.3), (-W - 0.8, fy, 0.4 + 2.15), STEEL, bevel=False)
    m.box((0.18, 3.0, 1.3), (-W - 0.95, fy, 3.4), HULL)
    m.box((1.6, 4.8, 0.16), (-W - 1.1, fy, 4.9), STEEL, rot=(0, -0.3, 0))
    # The launder: a steel channel of running slag, down into a walled slag bay.
    x0, x1, z0, z1 = -W - 0.75, -W - 3.6, 0.95, 0.45
    length = math.hypot(x0 - x1, z0 - z1)
    ang = math.atan2(z0 - z1, x0 - x1)
    lx, lz = (x0 + x1) / 2, (z0 + z1) / 2
    m.box((length, 0.62, 0.08), (lx, fy, lz - 0.12), STEEL, rot=(0, -ang, 0), bevel=False)
    for sy in (-1, 1):
        m.box((length, 0.07, 0.3), (lx, fy + sy * 0.31, lz), STEEL, rot=(0, -ang, 0), bevel=False)
    m.box((length, 0.5, 0.05), (lx, fy, lz - 0.05), LAVA_HOT, rot=(0, -ang, 0), bevel=False)
    for t in (0.35, 0.8):
        x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
        m.box((0.12, 0.7, z - 0.2), (x, fy, (z - 0.2) / 2), STEEL, bevel=False)
    bx = x1 - 1.5
    m.hull(jring(r, bx, fy, 0.0, 9, 1.3, jit=0.25, sx=1.1) + jring(r, bx, fy, 0.08, 9, 1.18, jit=0.25, sx=1.1),
           LAVA_HOT)
    for sy in (-1, 1):
        m.box((3.0, 0.3, 0.6), (x1 - 1.5, fy + sy * 1.8, 0.3), CONCRETE)
    m.box((0.3, 3.9, 0.6), (x1 - 3.0, fy, 0.3), CONCRETE)
    # The slag-pot car on its rails, its pot still glowing.
    ry = fy + 3.4
    for s in (-1, 1):
        m.box((7.0, 0.1, 0.12), (-W - 3.8, ry + s * 0.55, 0.06), STEEL, bevel=False)
    for k in range(8):
        m.box((0.25, 1.6, 0.08), (-W - 0.7 - k * 0.9, ry, 0.03), CONCRETE, bevel=False)
    px = -W - 4.2
    m.box((2.0, 1.6, 0.4), (px, ry, 0.55), HULL)
    for sx in (-0.7, 0.7):
        for s in (-1, 1):
            m.cyl(0.25, 0.25, 0.1, (px + sx, ry + s * 0.55, 0.32), STEEL, segs=10, rot=ALONG_Y, bevel=False)
    m.cyl(0.75, 1.1, 1.3, (px, ry, 1.4), HULL, segs=14)
    m.cyl(1.0, 1.0, 0.05, (px, ry, 2.07), LAVA_HOT, segs=14, bevel=False)
    for s in (-1, 1):
        m.cyl(0.14, 0.14, 0.35, (px, ry + s * 1.0, 1.6), STEEL, segs=8, rot=ALONG_Y, bevel=False)
    # Catwalk, caged ladder and a personnel door on the road face.
    cz = 3.6
    m.box((1.1, 5.0, 0.08), (-W - 0.8, 3.0, cz), HULL, bevel=False)
    railing(m, [(-W - 0.3, 0.5), (-W - 1.3, 0.5), (-W - 1.3, 5.5)], cz, STEEL, every=1.25)
    for y in (1.0, 3.0, 5.0):
        m.beam((-W - 0.3, y, cz - 0.9), (-W - 1.25, y, cz - 0.05), 0.04, STEEL)
    ladder(m, (-W - 0.45, 5.9), 0.4, cz + 1.05, (0, 1), (-1, 0), STEEL, cage_from=2.4)
    m.box((0.06, 1.0, 2.1), (-W - 0.27, 3.4, 0.4 + 1.05), HULL)
    for s in (-1, 1):
        m.box((0.1, 0.08, 2.2), (-W - 0.3, 3.4 + s * 0.56, 0.4 + 1.1), STEEL, bevel=False)
    m.box((0.1, 1.2, 0.08), (-W - 0.3, 3.4, 0.4 + 2.2), STEEL, bevel=False)
    # Tanks behind, piped to the hall; a pipe run along the back wall.
    tank(m, W + 3.6, -3.0, 2.0, 7.0, HULL, STEEL, ladder_out=(0, -1), plinth=CONCRETE, segs=18)
    tank(m, W + 3.4, 2.8, 1.7, 5.6, HULL, STEEL, ladder_out=(1, 0), plinth=CONCRETE, segs=16)
    m.cyl(2.04, 2.04, 0.45, (W + 3.6, -3.0, 1.4), HAZARD, segs=18, bevel=False)
    for y, z, x_end in ((-3.0, 4.6, W + 1.6), (2.8, 4.6, W + 1.7)):
        m.beam((W + 0.42, y, z), (x_end, y, z), 0.15, STEEL, segs=8)
        m.cyl(0.24, 0.24, 0.08, (x_end - 0.25, y, z), STEEL, segs=8, rot=ALONG_X, bevel=False)
    for z in (4.6, 5.05):
        m.cyl(0.13, 0.13, 2 * D - 0.6, (W + 0.42, 0, z), STEEL, segs=8, rot=ALONG_Y, bevel=False)
    for y in (-4.0, 0.0, 4.0):
        m.box((0.42, 0.12, 0.85), (W + 0.37, y, 4.8), STEEL, bevel=False)
    # The ore heap and the conveyor from its feed hopper up into the +Y gable.
    lathe(m, [(3.4, -0.05, 0.12, 0.0), (2.9, 0.5, 0.16, 0.12), (2.2, 1.2, 0.2, 0.18), (1.3, 1.9, 0.22, 0.15),
              (0.45, 2.45, 0.25, 0.1)], 16, [SULPHUR], loc=(-4.6, D + 5.5, 0.0), seed=103)
    cxc = -0.8
    a = Vector((cxc, D + 9.6, 0.9))
    b = Vector((cxc, D + 0.4, 5.7))
    span = b - a
    length = span.length
    phi = math.atan2(a.z - b.z, a.y - b.y)
    mid = (a + b) / 2
    up = Vector((0, -math.sin(phi), math.cos(phi)))
    m.box((1.0, length, 0.1), mid, HULL, rot=(phi, 0, 0), bevel=False)
    m.box((0.7, length - 0.6, 0.08), mid + up * 0.09, SULPHUR, rot=(phi, 0, 0), bevel=False)
    n = int(length / 1.4)
    for s in (-1, 1):
        off_t, off_b = Vector((s * 0.55, 0, 0.15)), Vector((s * 0.55, 0, -0.45))
        m.beam(a + off_t, b + off_t, 0.05, STEEL)
        m.beam(a + off_b, b + off_b, 0.05, STEEL)
        for k in range(n + 1):
            p = a + span * (k / n)
            m.beam(p + off_b, p + off_t, 0.03, STEEL)
            if k < n:
                q = a + span * ((k + 1) / n)
                m.beam(p + off_b, q + off_t, 0.03, STEEL)
    for t in (0.35, 0.7):
        p = a + span * t
        for s in (-1, 1):
            m.beam((cxc + s * 0.85, p.y, 0.0), (cxc + s * 0.55, p.y, p.z - 0.45), 0.07, STEEL)
        m.box((1.3, 0.1, 0.1), (cxc, p.y, p.z * 0.45), STEEL, bevel=False)
    m.cyl(0.45, 1.1, 1.0, (cxc, a.y + 0.2, a.z + 0.75), HULL, segs=4, rot=(0, 0, math.pi / 4))
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.12, 0.12, a.z + 0.3), (cxc + sx * 0.5, a.y + 0.2 + sy * 0.5, (a.z + 0.3) / 2), STEEL,
                  bevel=False)
    m.box((1.6, 0.9, 1.4), (cxc, D + 0.4, 5.9), HULL)
    # The stack, its flue duct from the roof, platforms, ladder, bands and beacons.
    sx_, sy_ = 1.6, -D - 3.2
    m.box((3.4, 3.4, 0.9), (sx_, sy_, 0.45), CONCRETE)
    lathe(m, [(1.3, 0.85), (1.08, 12.0), (0.88, 24.0)], 14, [CONCRETE], loc=(sx_, sy_, 0.0), top_mat=CONCRETE)

    def stack_r(z):
        return 1.3 + (0.88 - 1.3) * (z - 0.85) / (24.0 - 0.85)

    m.cyl(0.72, 0.72, 0.05, (sx_, sy_, 24.02), LAVA_HOT, segs=12, bevel=False)
    for k, z in enumerate((19.6, 20.2, 20.8, 21.4, 22.0, 22.6)):
        m.cyl(stack_r(z) + 0.03, stack_r(z + 0.6) + 0.03, 0.6, (sx_, sy_, z + 0.3), HAZARD if k % 2 == 0 else HULL,
              segs=14, bevel=False)
    for z in (11.0, 23.0):
        rr = stack_r(z) + 0.75
        m.cyl(rr, rr, 0.1, (sx_, sy_, z), HULL, segs=14, bevel=False)
        pts = [(sx_ + (rr - 0.05) * math.cos(TAU * k / 10), sy_ + (rr - 0.05) * math.sin(TAU * k / 10))
               for k in range(10)]
        railing(m, pts, z + 0.05, STEEL, h=1.0, every=10.0, closed=True, post=0.05, rail=0.04)
        for k in range(4):
            aa = TAU * k / 4 + math.pi / 4
            m.beam((sx_ + stack_r(z - 0.8) * math.cos(aa), sy_ + stack_r(z - 0.8) * math.sin(aa), z - 0.8),
                   (sx_ + (rr - 0.2) * math.cos(aa), sy_ + (rr - 0.2) * math.sin(aa), z - 0.05), 0.04, STEEL)
    z0, z1 = 0.9, 23.0
    for s in (-1, 1):
        m.beam((sx_ - stack_r(z0) - 0.25, sy_ + s * 0.22, z0), (sx_ - stack_r(z1) - 0.25, sy_ + s * 0.22, z1 + 1.0),
               0.03, STEEL)
    z = z0 + 0.4
    while z < z1 + 0.9:
        m.box((0.04, 0.44, 0.04), (sx_ - stack_r(z) - 0.25, sy_, z), STEEL, bevel=False)
        z += 0.45
    for k in range(3):
        aa = TAU * k / 3 + 0.5
        m.box((0.34, 0.34, 0.34), (sx_ + 0.95 * math.cos(aa), sy_ + 0.95 * math.sin(aa), 24.25), BEACON_RED,
              bevel=False)
    m.box((0.3, 0.3, 0.3), (sx_ - stack_r(11.0) - 0.7, sy_, 12.3), BEACON_RED, bevel=False)
    m.box((1.0, 1.0, 1.3), (sx_, -D + 0.8, H + 1.2), HULL)
    m.box((1.0, 3.6, 1.0), (sx_, -D - 1.0, 7.4), HULL)
    for y in (-D - 0.2, -D - 1.6):
        m.box((1.16, 0.1, 1.16), (sx_, y, 7.4), STEEL, bevel=False)
    m.box((0.25, 0.25, 6.9), (sx_, -D - 1.3, 3.45), STEEL, bevel=False)
    # Amber beacons on the road-side roof corners.
    for sy in (-1, 1):
        m.box((0.1, 0.1, 0.5), (-W, sy * (D - 0.3), H + 0.65), STEEL, bevel=False)
        m.box((0.36, 0.36, 0.36), (-W, sy * (D - 0.3), H + 1.05), BEACON_AMBER, bevel=False)
    return m.finish()


def hazard_gantry():
    """A radiation-hazard sign on a gantry beside the road (never over it). Two box-section posts
    on concrete footings with bolted, gusseted base plates and a bolted splice flange halfway,
    banded yellow and black at the foot, amber beacons on top; a box truss between them (chords,
    verticals, diagonals both faces, lacing) bolted to the posts through plates; the sign under it
    (yellow face, black border with bolts, trefoil, RAD ZONE, chevrons, stiffeners behind) on bolted
    hangers; three floodlights on arms; conduit from a ground pull box up the post to a junction
    box and along the truss to the lights; a ladder up the outer post. Right of the road only."""
    m = Part("hazard_gantry", width=0.04)
    half, post_h, ps = 4.2, 8.2, 0.45
    for sx in (-1, 1):
        x = sx * half
        m.box((1.2, 1.2, 0.5), (x, 0, 0.25), CONCRETE)
        m.box((0.9, 0.9, 0.05), (x, 0, 0.525), STEEL)
        flange_bolts(m, x, 0, 0.6, 0.34, STEEL, r=0.04, h=0.12, mids=False)
        for gx, gy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            f = ps / 2
            p0 = (x + gx * f, gy * f, 0.55)
            p1 = (x + gx * (f + 0.22), gy * (f + 0.22), 0.55)
            p2 = (x + gx * f, gy * f, 1.0)
            prism(m, [p0, p1, p2], (gy, gx, 0), -0.012, 0.012, STEEL)
        m.box((ps, ps, post_h - 0.55), (x, 0, 0.55 + (post_h - 0.55) / 2), STEEL)
        for z in (3.97, 4.03):
            m.box((0.7, 0.7, 0.05), (x, 0, z), STEEL, bevel=False)
        flange_bolts(m, x, 0, 4.0, 0.28, STEEL, r=0.032, h=0.22)
        for k in range(5):
            m.box((ps + 0.04, ps + 0.04, 0.36), (x, 0, 0.8 + k * 0.36), SIGN_FACE if k % 2 == 0 else SIGN_INK,
                  bevel=False)
        m.box((0.6, 0.6, 0.05), (x, 0, post_h + 0.025), STEEL, bevel=False)
        m.cyl(0.1, 0.1, 0.2, (x, 0, post_h + 0.15), STEEL, segs=8, bevel=False)
        m.cyl(0.2, 0.17, 0.36, (x, 0, post_h + 0.43), BEACON_AMBER, segs=10, bevel=False)
        m.cyl(0.22, 0.22, 0.05, (x, 0, post_h + 0.64), STEEL, segs=10, bevel=False)
    # The box truss.
    zb, zt = post_h - 1.55, post_h - 0.15
    xs = [-half + ps / 2 + (2 * half - ps) * k / 6 for k in range(7)]
    for y in (-0.32, 0.32):
        for z in (zb, zt):
            m.box((2 * half + ps, 0.14, 0.14), (0, y, z), STEEL, bevel=False)
        for x in xs:
            m.box((0.09, 0.09, zt - zb), (x, y, (zb + zt) / 2), STEEL, bevel=False)
        for k in range(6):
            za, zc = (zb, zt) if k % 2 == 0 else (zt, zb)
            m.beam((xs[k], y, za), (xs[k + 1], y, zc), 0.04, STEEL)
    for k in range(6):
        m.beam((xs[k], -0.32, zt), (xs[k + 1], 0.32, zt), 0.03, STEEL)
        m.beam((xs[k], 0.32, zb), (xs[k + 1], -0.32, zb), 0.03, STEEL)
    for x in xs:
        for z in (zb, zt):
            m.box((0.07, 0.64, 0.07), (x, 0, z), STEEL, bevel=False)
    for sx in (-1, 1):
        px = sx * (half - ps / 2 - 0.02)
        m.box((0.04, 0.9, 1.9), (px, 0, (zb + zt) / 2), STEEL, bevel=False)
        for by in (-0.3, 0.3):
            for bz in (zb + 0.1, (zb + zt) / 2, zt - 0.1):
                bolt(m, (px - sx * 0.04, by, bz), (-sx, 0, 0), STEEL, r=0.03, h=0.06)
    # The sign: a yellow face with a black border, hung under the truss.
    sw, sh, sz = 7.6, 3.6, 4.6
    t = 0.2
    m.box((sw, t, sh), (0, 0, sz), SIGN_FACE)
    front = -t / 2
    for dz in (-sh / 2, sh / 2):
        m.box((sw + 0.1, t + 0.06, 0.18), (0, 0, sz + dz), SIGN_INK, bevel=False)
    for dx in (-sw / 2, sw / 2):
        m.box((0.18, t + 0.06, sh), (dx, 0, sz), SIGN_INK, bevel=False)
    for bx in (-sw / 2, -sw / 4, 0.0, sw / 4, sw / 2):
        for bz in (-sh / 2, sh / 2):
            bolt(m, (bx, front - 0.04, sz + bz), (0, -1, 0), STEEL, r=0.035, h=0.04)
    for hx in (-sw * 0.35, sw * 0.35):
        m.box((0.12, 0.12, zb - (sz + sh / 2)), (hx, 0.18, (zb + sz + sh / 2) / 2), STEEL, bevel=False)
        m.box((0.3, 0.06, 0.3), (hx, 0.13, sz + sh / 2 - 0.12), STEEL, bevel=False)
        bolt(m, (hx, 0.09, sz + sh / 2 - 0.12), (0, -1, 0), STEEL, r=0.03, h=0.05)
    for z in (sz - 1.2, sz, sz + 1.2):
        m.box((sw - 0.4, 0.1, 0.12), (0, t / 2 + 0.05, z), STEEL, bevel=False)
    for x in (-3.2, -1.2, 1.2, 3.2):
        m.box((0.12, 0.1, sh - 0.2), (x, t / 2 + 0.1, sz), STEEL, bevel=False)
    # Trefoil on the left of the face: a hub and three 60-degree blades (two up, one down).
    tx, tz, rr_ = -2.0, sz, 1.2
    m.cyl(rr_ * 0.2, rr_ * 0.2, 0.06, (tx, front - 0.03, tz), SIGN_INK, segs=12, rot=ALONG_Y, bevel=False)
    for centre in (30.0, 150.0, 270.0):
        a = math.radians(centre)
        ring_sector(m, tx, tz, rr_ * 0.32, rr_, a - math.radians(30), a + math.radians(30), front, front - 0.06,
                    SIGN_INK)
    stroke_text(m, "RAD", 1.55, sz + 0.75, front, 0.3, SIGN_INK)
    stroke_text(m, "ZONE", 1.55, sz - 0.7, front, 0.24, SIGN_INK)
    for k in range(8):
        x0 = -sw / 2 + 0.3 + k * 0.9
        slab(m, [(x0, sz - sh / 2 + 0.12), (x0 + 0.35, sz - sh / 2 + 0.12), (x0 + 0.65, sz - sh / 2 + 0.5),
                 (x0 + 0.3, sz - sh / 2 + 0.5)], front - 0.04, front + 0.01, SIGN_INK)
    # Floodlights on arms off the front chord, tilted back down onto the face.
    tilt = 0.6
    for fx in (-2.6, 0.0, 2.6):
        m.box((0.08, 0.95, 0.08), (fx, -0.32 - 0.47, zb), STEEL, bevel=False)
        hc = Vector((fx, -1.22, zb - 0.12))
        m.box((0.9, 0.42, 0.24), hc, STEEL, rot=(tilt, 0, 0))
        m.box((0.78, 0.34, 0.04), hc + Vector((0, math.sin(tilt), -math.cos(tilt))) * 0.13, SIGN_LAMP,
              rot=(tilt, 0, 0), bevel=False)
        for k in range(3):
            m.box((0.05, 0.3, 0.05), (fx - 0.3 + k * 0.3, -1.22 - 0.05, zb + 0.02), STEEL, rot=(tilt, 0, 0),
                  bevel=False)
    # Cable run: pull box, conduit up the outer post's front face with clips, a junction box, then
    # along under the front chord to each floodlight.
    cy = -(ps / 2 + 0.07)
    m.box((0.6, 0.6, 0.15), (half + 0.25, -1.2, 0.07), CONCRETE)
    m.beam((half + 0.25, -1.2, 0.14), (half, cy, 0.62), 0.035, STEEL, segs=6)
    m.beam((half, cy, 0.62), (half, cy, zb - 0.12), 0.035, STEEL, segs=6)
    z = 1.0
    while z < zb - 0.3:
        m.box((0.12, 0.05, 0.04), (half, cy - 0.01, z), STEEL, bevel=False)
        z += 0.9
    m.box((0.36, 0.16, 0.5), (half, cy - 0.07, 2.9), STEEL)
    m.cyl(0.05, 0.05, 0.08, (half, cy - 0.07, 2.62), STEEL, segs=6, bevel=False)
    m.beam((half, cy, zb - 0.12), (-2.6, cy - 0.1, zb - 0.12), 0.03, STEEL, segs=6)
    for fx in (-2.6, 0.0, 2.6):
        m.beam((fx, cy - 0.1, zb - 0.12), (fx, -1.0, zb - 0.05), 0.025, STEEL, segs=4)
    for k in range(5):
        m.box((0.04, 0.12, 0.1), (half - 1.2 - k * 1.4, cy - 0.1, zb - 0.1), STEEL, bevel=False)
    ladder(m, (half + ps / 2 + 0.2, 0.0), 0.55, post_h - 0.1, (0, 1), (1, 0), STEEL, width=0.4, rung=0.35)
    return m.finish()


def pylon():
    """A heavy cable pylon: twin dark steel columns on concrete footings (bolted base plates, a
    bolted splice flange halfway, proud hazard bands at the foot), X-bracing with gussets and a
    strut between them, a deep box crossbeam with stiffener ribs and a hazard band striped as
    geometry, three insulator strings on yokes, a red beacon, a ladder up the road-side column, and
    three thick cables sagging exactly to the next pylon (PYLON_SPACING), so repeats join up."""
    m = Part("pylon", width=0.04)
    top = 17.0
    for sx in (-1, 1):
        x = sx * 3.2
        m.box((1.6, 1.6, 1.2), (x, 0, 0.6), CONCRETE)
        m.box((1.2, 1.2, 0.06), (x, 0, 1.23), STEEL, bevel=False)
        flange_bolts(m, x, 0, 1.3, 0.47, STEEL, r=0.045, h=0.12, hexed=False, mids=False)
        m.box((0.9, 0.9, top - 1.26), (x, 0, 1.26 + (top - 1.26) / 2), STEEL_DARK)
        for z in (8.97, 9.03):
            m.box((1.15, 1.15, 0.06), (x, 0, z), STEEL, bevel=False)
        flange_bolts(m, x, 0, 9.0, 0.51, STEEL, r=0.04, h=0.22, hexed=False)
        for k in range(3):
            m.box((0.98, 0.98, 0.5), (x, 0, 1.75 + k * 1.0), HAZARD, bevel=False)
    xi = 3.2 - 0.45
    for z0, z1 in ((4.0, 9.0), (9.0, 14.0)):
        m.beam((-xi, 0, z0), (xi, 0, z1), 0.13, STEEL)
        m.beam((xi, 0, z0), (-xi, 0, z1), 0.13, STEEL)
        m.box((0.5, 0.06, 0.5), (0, 0.15, (z0 + z1) / 2), STEEL, bevel=False)
        for sx in (-1, 1):
            for z in (z0, z1):
                m.box((0.06, 0.5, 0.7), (sx * (xi - 0.03), 0, z), STEEL, bevel=False)
    m.box((2 * xi, 0.3, 0.3), (0, 0, 9.0), STEEL, bevel=False)
    # The crossbeam: a deep box girder, ribbed, with a striped hazard band along its foot.
    m.box((10.4, 1.0, 1.4), (0, 0, top + 0.2), STEEL_DARK)
    for x in (-4.4, -2.2, 0.0, 2.2, 4.4):
        for sy in (-1, 1):
            m.box((0.08, 0.06, 1.1), (x, sy * 0.53, top + 0.35), STEEL, bevel=False)
    m.box((10.5, 1.04, 0.28), (0, 0, top - 0.36), HAZARD, bevel=False)
    stripes(m, (0, -0.52, top - 0.36), (1, 0, 0), (0, 0, 1), 10.5, 0.28, STEEL_DARK, (0, -1, 0), band=0.18, pitch=0.42)
    m.box((0.5, 0.5, 0.15), (0, 0, top + 0.98), STEEL, bevel=False)
    m.cyl(0.26, 0.22, 0.5, (0, 0, top + 1.3), BEACON_RED, segs=10, bevel=False)
    for x in (-4.6, 0.0, 4.6):
        m.box((0.3, 0.3, 0.1), (x, 0, top - 0.55), STEEL, bevel=False)
        m.cyl(0.04, 0.04, 1.9, (x, 0, top - 1.5), STEEL, segs=6, bevel=False)
        for k in range(5):
            m.cyl(0.4, 0.4, 0.12, (x, 0, top - 0.8 - k * 0.3), INSULATOR, segs=10, bevel=False)
        m.box((0.5, 0.12, 0.14), (x, 0, top - 2.35), STEEL, bevel=False)
        m.cyl(0.12, 0.12, 0.3, (x, 0, top - 2.5), STEEL, segs=8, rot=ALONG_Y, bevel=False)
        z = top - 2.5
        prev = None
        n = 12
        for i in range(n + 1):
            p = i / n
            cur = (x, p * PYLON_SPACING, z - 2.4 * 4 * p * (1 - p))
            if prev:
                m.beam(prev, cur, 0.08, STEEL_DARK)
            prev = cur
    ladder(m, (3.2, -0.66), 1.3, top - 0.5, (1, 0), (0, -1), STEEL, rung=0.45)
    return m.finish()


def bollard():
    """A hexagonal steel hazard bollard on a bolted base plate, two yellow bands, a sloped cap and an
    amber reflector in a housing on the road-facing flat (-X)."""
    m = Part("bollard", width=0.02)
    m.box((0.46, 0.46, 0.04), (0, 0, 0.02), STEEL_DARK, bevel=False)
    for bx in (-0.17, 0.17):
        for by in (-0.17, 0.17):
            m.box((0.05, 0.05, 0.05), (bx, by, 0.06), STEEL_DARK, bevel=False)
    hexa = (0, 0, math.pi / 6)  # a flat face toward the road
    m.cyl(0.19, 0.17, 1.0, (0, 0, 0.54), STEEL_DARK, segs=6, rot=hexa)
    m.cyl(0.196, 0.19, 0.14, (0, 0, 0.84), HAZARD, segs=6, rot=hexa, bevel=False)
    m.cyl(0.2, 0.196, 0.14, (0, 0, 0.56), HAZARD, segs=6, rot=hexa, bevel=False)
    m.cyl(0.175, 0.08, 0.1, (0, 0, 1.09), STEEL_DARK, segs=6, rot=hexa, bevel=False)
    m.box((0.05, 0.15, 0.26), (-0.17, 0, 0.7), STEEL_DARK, bevel=False)
    m.box((0.03, 0.11, 0.2), (-0.195, 0, 0.7), REFLECT, bevel=False)
    return m.finish()


# ---------------------------------------------------------------- the player's hauler

def hood():
    """The player's armoured ore hauler, seen from the driver's seat, behind the keyboard. Same
    footprint as the Red Frontier rover (half-width 8, running about 9.6 toward -Y, top from 0 to
    0.95, lamps at the front corners). Only the front strip and the corner pods are in shot:
    gunmetal armour in bolted plates, flat seams (nothing raised in front of the keys), hazard
    chevrons cut as geometry on the pods between bolted edge rails, caged lamps in finned housings
    with bezel rings, and a ribbed ram plate."""
    m = Part("hood", width=0.03)
    w = 8.0
    slope = -math.atan(0.95 / 9.2)

    def on_top(y):
        return 0.95 * (0.2 - y) / 9.2

    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], ARMOUR)
    # Armour plates: slightly lighter flat panels laid on the slope, with dark seams between, so the
    # hood reads as bolted plate without anything standing up in front of the keys.
    for x0, x1 in ((-7.8, -2.7), (-2.5, 2.5), (2.7, 7.8)):
        for y0, y1 in ((0.05, -2.3), (-2.5, -6.0)):
            cy = (y0 + y1) / 2
            m.box((x1 - x0, y0 - y1, 0.02), ((x0 + x1) / 2, cy, on_top(cy) + 0.012), ARMOUR_PLATE, rot=(slope, 0, 0),
                  bevel=False)
    for x in (-2.6, 2.6):
        m.box((0.14, 8.6, 0.03), (x, -4.2, on_top(-4.2) + 0.018), SEAM, rot=(slope, 0, 0), bevel=False)
    m.box((w * 2 - 0.4, 0.14, 0.03), (0, -2.4, on_top(-2.4) + 0.018), SEAM, rot=(slope, 0, 0), bevel=False)
    # Bolt heads along the outer plates' edges (kept off the middle plate, which sits under the keys).
    for x in (-7.5, -3.0, 3.0, 7.5):
        for y in (-0.3, -1.1, -1.9, -2.9, -3.8, -4.8, -5.7):
            m.box((0.16, 0.16, 0.05), (x, y, on_top(y) + 0.03), BOLT, rot=(slope, 0, 0), bevel=False)
    for y in (-0.3, -1.9, -2.9, -5.7):
        for x in (-6.0, -4.5, 4.5, 6.0):
            m.box((0.16, 0.16, 0.05), (x, y, on_top(y) + 0.03), BOLT, rot=(slope, 0, 0), bevel=False)
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.5), (x, -4.5, -0.25), ARMOUR)
        # Hazard chevrons along the pod top, cut as geometry, between two bolted edge rails.
        m.box((1.5, 9.4, 0.05), (x, -4.5, 0.52), CHEVRON, bevel=False)
        stripes(m, (x, -4.5, 0.545), (0, side, 0), (1, 0, 0), 9.4, 1.5, SEAM, (0, 0, 1), band=0.32, pitch=0.8,
                proud=0.012)
        m.box((0.18, 9.6, 0.12), (x - side * 0.88, -4.5, 0.56), ARMOUR_PLATE)
        m.box((0.14, 9.6, 0.1), (x + side * 0.88, -4.5, 0.55), ARMOUR_PLATE)
        for k in range(10):
            y = -0.3 - k * 0.95
            m.box((0.08, 0.08, 0.04), (x - side * 0.88, y, 0.64), BOLT, bevel=False)
            m.box((0.07, 0.07, 0.04), (x + side * 0.88, y, 0.62), BOLT, bevel=False)
        # Lamps: a finned armoured housing, two round lamps in bezel rings behind a cage of bars, an
        # amber marker outside, the lamp bar on top.
        m.box((1.95, 0.42, 0.95), (x, 0.36, 0.3), ARMOUR_PLATE)
        for k in range(6):
            m.box((0.05, 0.2, 0.07), (x - 0.75 + k * 0.3, 0.24, 0.8), SEAM, bevel=False)
        for dx in (-0.48, 0.48):
            m.cyl(0.32, 0.32, 0.12, (x + dx, 0.6, 0.32), LAMP, segs=16, rot=(math.radians(-90), 0, 0), bevel=False)
            m.cyl(0.39, 0.39, 0.1, (x + dx, 0.58, 0.32), BOLT, segs=16, rot=(math.radians(-90), 0, 0), bevel=False)
        for dz in (0.14, 0.32, 0.5):
            m.box((1.8, 0.06, 0.05), (x, 0.72, dz), SEAM, bevel=False)
        for dx in (-0.8, -0.48, -0.16, 0.16, 0.48, 0.8):
            m.box((0.05, 0.06, 0.5), (x + dx, 0.72, 0.32), SEAM, bevel=False)
        m.box((0.3, 0.16, 0.58), (x + side * 0.9, 0.56, 0.3), ARMOUR_PLATE, bevel=False)
        m.box((0.22, 0.14, 0.5), (x + side * 0.9, 0.6, 0.3), MARKER, bevel=False)
        m.box((1.6, 0.16, 0.06), (x, 0.42, 0.79), ARMOUR_PLATE, bevel=False)
        m.box((1.5, 0.1, 0.04), (x, 0.42, 0.83), LAMP_BAR, bevel=False)
    # The ram plate across the front, low, with ribs and tow eyes.
    m.box((w * 2 + 3.7, 0.6, 0.45), (0, 0.55, -1.15), ARMOUR_PLATE)
    for k in range(9):
        m.box((0.16, 0.2, 0.42), (-8.0 + k * 2.0, 0.92, -1.15), ARMOUR, bevel=False)
    for x in (-5.0, 5.0):
        m.cyl(0.16, 0.16, 0.12, (x, 0.95, -0.85), BOLT, segs=8, rot=ALONG_Y, bevel=False)
    return m.finish()


export_all([crag, columns, spatter_cone, plume, fissure, lava_river, sulphur_rock, crystal, vent, drill_rig,
            smelter, hazard_gantry, pylon, bollard, hood], OUT_DIR, PREVIEW)
