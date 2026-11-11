"""Tidewater props (region id `coast`): the shore of an ocean moon. A steel guard rail on a concrete sea
wall, the ice shelf falling to the water, lattice light masts, ice floes with pressure ridges and icebergs
in strata, a lighthouse-style beacon tower on its islet, floating habitat platforms (one moored to the shore
by a catwalk), a marker buoy; on the land side ice cliffs, terraced ice shelves, an antenna mast with a
relay hut, cryo-geyser vents, ice crystals, frosted boulders and roadside markers; and the player's
hover-convertible hood.

Run: blender --background --python tools/themes/coast/props.py -- game/assets/themes/coast/models [preview.png]

High-detail pass (2026-11-10): every prop rebuilt to read as a real object up close. Hard-surface parts
(rails, hulls, decks) are closed boxes and cylinders that propkit's finish bevels; the ice and rock are
FACETS, each face its own vertices, so they shade flat and crisp and the bevel (which only touches edges
shared by two faces) leaves them alone, which keeps a whole iceberg to a few thousand triangles. Thin
round members (lattice, railings, pipes, ladders) are open 12-sided tubes: their faces turn less than the
bevel's 35 degree limit, so they cost 24 triangles each and shade round. Bolts are open hex studs, also
too shallow for the bevel.

Props that stand in the water are modelled from the WATERLINE up (z = 0 is the sea surface) and the world
script lifts them to SEA_LEVEL: scaled landmarks then keep their waterline, and the prop shader's grime
(measured up from the model's origin) becomes a band of wet grime and algae just above the water instead of
covering everything below the road. The sea-side row props (bank) are built the same way.
Lights the world script blinks use the material "blink".
"""
import math
import pathlib
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset  # noqa: E402

RAIL_LENGTH = 6.0  # must match RAIL_LENGTH in game/scripts/themes/coast.gd
BANK_LENGTH = 12.0  # must match BANK_LENGTH in game/scripts/themes/coast.gd
LAMP_SPACING = 30.0  # must match LAMP_SPACING in game/scripts/themes/coast.gd
MARKER_SPACING = 15.0  # must match MARKER_SPACING in game/scripts/themes/coast.gd
SEA_LEVEL = -5.0  # the waterline, below the road; must match SEA_LEVEL in coast.gd
ROAD = -SEA_LEVEL  # the road's height above the waterline, for props modelled from the waterline up
BEAM_HEIGHT = 26.0  # the beacon's lens, above the waterline; must match BEAM_HEIGHT in coast.gd
VENT_HEIGHT = 2.4  # the geyser's throat; must match VENT_HEIGHT in coast.gd
OUT_DIR, PREVIEW = args()
reset()

# Ice: pale blue faces, deep blue-green shadows, frost on top, and a faint teal glow in a few facets
# (the moon's ice is lit from inside). Colours are linear, as Blender takes them. Material NAMES pick the
# game's surface maps (theme_world.gd SURFACE_KEYWORDS, coast.gd `surfaces`): ice/frost -> ice,
# rock -> rock, concrete -> concrete, steel -> brushed, walkway -> grate, hull -> panel, coral -> panel.
# Names avoid "ice" inside other words (lattice, service) and "shed" (brushed), which the keywords catch.
ICE = material("ice", (0.20, 0.34, 0.44), rough=0.3)
ICE_LIGHT = material("ice_light", (0.28, 0.42, 0.52), rough=0.35)
ICE_DEEP = material("ice_deep", (0.035, 0.09, 0.14), rough=0.25)
FROST = material("frost", (0.32, 0.42, 0.50), rough=0.85)
VEIN = material("vein", (0.22, 0.70, 0.78), emit=(0.20, 0.66, 0.76), strength=0.7)
ROCK = material("rock", (0.032, 0.036, 0.046), rough=0.8)
ROCK_BAND = material("rock_band", (0.055, 0.06, 0.072), rough=0.75)
# Kept dim: brighter, the slush rims read as white donuts and a neon band along the shore.
SLUSH = material("slush", (0.10, 0.18, 0.21), emit=(0.16, 0.42, 0.44), strength=0.18)
CONCRETE = material("concrete", (0.15, 0.17, 0.19), rough=0.9)
# Galvanised guard-rail steel: mid grey and properly metallic, so the headlights run along it.
GALV = material("steel_galv", (0.30, 0.32, 0.34), rough=0.42, metal=0.8)
STEEL = material("steel_dark", (0.09, 0.10, 0.11), rough=0.45, metal=0.75)
WALKWAY = material("walkway_grate", (0.13, 0.14, 0.15), rough=0.55, metal=0.7)
REFLECTOR = material("reflector", (1.0, 0.42, 0.32), emit=(1.0, 0.40, 0.30), strength=3.5)
# Painted plating: mostly dielectric paint over metal, so it takes the lights diffusely.
HULL = material("hull", (0.085, 0.10, 0.12), rough=0.5, metal=0.3)
HULL_LIGHT = material("hull_light", (0.40, 0.44, 0.48), rough=0.5, metal=0.2)
CORAL = material("coral_paint", (0.50, 0.12, 0.09), rough=0.5, metal=0.1)
WINDOW = material("window", (1.0, 0.62, 0.42), emit=(1.0, 0.58, 0.38), strength=3.2)
PORT = material("port", (0.6, 0.9, 1.0), emit=(0.55, 0.88, 1.0), strength=3.0)
# Kept to 4: at 14 its bloom swallowed the lamp room's glazing bars and gallery; the beams carry the reach.
BEACON = material("beacon", (0.85, 1.0, 1.0), emit=(0.80, 1.0, 0.98), strength=4.0)
# A faint inner glow keeps the glass out of the weathering (glowing materials are left alone) and lit at night.
GLASS = material("glass", (0.05, 0.10, 0.13), rough=0.08, metal=0.2, emit=(0.05, 0.14, 0.18), strength=0.6)
BLINK = material("blink", (1.0, 0.30, 0.22), emit=(1.0, 0.28, 0.20), strength=8.0)
LIGHT_BAR = material("light_bar", (0.85, 0.97, 1.0), emit=(0.82, 0.96, 1.0), strength=7.0)
# A pearl teal-grey: a darker paint melted into the road and stopped framing the bottom edge.
PAINT = material("paint", (0.20, 0.28, 0.32), rough=0.3, metal=0.35)
PAINT_EDGE = material("paint_edge", (0.05, 0.08, 0.10), rough=0.3, metal=0.6)
TRIM = material("trim", (1.0, 0.45, 0.36), emit=(1.0, 0.42, 0.32), strength=1.1)
HEADLAMP = material("headlamp", (0.9, 0.98, 1.0), emit=(0.86, 0.96, 1.0), strength=9.0)


class Prop(Model):
    """propkit's Model with two changes, both in finish():
    - lone facets (the faceted ice and rock, each face on its own vertices) keep the outward winding they
      were built with: recalc_face_normals cannot tell outside from inside for a single flat face, and a
      flipped facet puts the shader's salt frost on its underside;
    - only the pieces built with bevel=True are bevelled (the Neon Sprawl `Part` pattern): masses, housings
      and frames get propkit's 3 cm two-segment bevel through edge weights, while fine detail (plates,
      straps, brackets, reflectors, fins) stays a flat box of 12 triangles instead of about 100. Every edge
      sharper than 35 degrees is marked sharp, so unbevelled detail still shades flat under propkit's
      weighted normals and round tubes stay smooth."""

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

    def poly(self, verts, faces, mat, bevel=True):
        start = len(self.bm.verts)
        super().poly(verts, faces, mat)
        self._mark(start, bevel)

    def finish(self):
        bm = self.bm
        joined = [f for f in bm.faces if not all(e.is_boundary for e in f.edges)]
        if joined:
            bmesh.ops.recalc_face_normals(bm, faces=joined)
        bm.normal_update()
        crease = math.radians(35.0)
        for e in bm.edges:
            sharp = len(e.link_faces) != 2 or e.calc_face_angle(0.0) > crease
            e.smooth = not sharp
            if not sharp:
                e[self.weight] = 0.0  # a smooth edge (round tube sides) is never bevelled
        mesh = bpy.data.meshes.new(self.name)
        for mat in self.mats:
            mesh.materials.append(mat)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj["bevel"] = 0  # propkit's all-edges bevel off: this weighted one replaces it
        if self.width > 0.0:
            bevel = obj.modifiers.new("bevel", "BEVEL")
            bevel.width = self.width
            bevel.segments = 2
            bevel.limit_method = "WEIGHT"
            bevel.use_clamp_overlap = True
            bevel.harden_normals = True
        return obj


# ---------------------------------------------------------------- building blocks

def newell(pts):
    """A polygon's normal (unnormalised) from its vertices in order: counter-clockwise faces you."""
    n = Vector((0.0, 0.0, 0.0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


def facet(m, pts, mat, out=None):
    """One flat face on its own vertices, turned to face `out` when given."""
    pts = [Vector(p) for p in pts]
    if out is not None and newell(pts).dot(Vector(out)) < 0.0:
        pts.reverse()
    m.poly([tuple(p) for p in pts], [tuple(range(len(pts)))], mat, bevel=False)


def tube(m, a, b, r, mat, segs=12, r2=None, caps=False, phase=0.0):
    """A round tube from a to b (radius r, r2 at b). Twelve sides turn 30 degrees each, under the bevel's
    35 degree limit, so it stays 24 triangles and shades round; open ends hide in the joints."""
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    if abs(axis.z) > 0.999:
        u = Vector((1.0, 0.0, 0.0))
    else:
        u = axis.cross(Vector((0.0, 0.0, 1.0))).normalized()
    v = axis.cross(u)
    r2 = r if r2 is None else r2
    verts = []
    for p, rr in ((a, r), (b, r2)):
        for s in range(segs):
            t = 2.0 * math.pi * s / segs + phase
            verts.append(tuple(p + (u * math.cos(t) + v * math.sin(t)) * rr))
    faces = [(s, (s + 1) % segs, segs + (s + 1) % segs, segs + s) for s in range(segs)]
    if caps:
        faces += [tuple(range(segs - 1, -1, -1)), tuple(range(segs, 2 * segs))]
    m.poly(verts, faces, mat, bevel=caps)


def stud(m, loc, normal, r, mat):
    """A bolt head or rivet: a low hex dome with no back face, shallow enough that the bevel leaves it be."""
    n = Vector(normal).normalized()
    u = n.cross(Vector((0.0, 0.0, 1.0))) if abs(n.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    u.normalize()
    v = n.cross(u)
    c = Vector(loc)
    verts = []
    for rr, h in ((r, 0.0), (r * 0.62, r * 0.24)):
        for s in range(6):
            t = math.pi / 3.0 * s
            verts.append(tuple(c + n * h + (u * math.cos(t) + v * math.sin(t)) * rr))
    faces = [(s, (s + 1) % 6, 6 + (s + 1) % 6, 6 + s) for s in range(6)] + [tuple(range(6, 12))]
    m.poly(verts, faces, mat, bevel=False)


def extrude(m, profile, y0, y1, mat, front_scale=1.0, cx=0.0, cz=0.0, caps=True):
    """A prism along Y from an (x, z) profile; the +Y end is narrowed by front_scale."""
    n = len(profile)
    verts = [(cx + x, y0, cz + z) for x, z in profile] + [(cx + x * front_scale, y1, cz + z) for x, z in profile]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    if caps:
        faces += [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    m.poly(verts, faces, mat)


def prism_z(m, pts, z0, z1, mat, cx=0.0, cy=0.0):
    """A capped prism standing on an (x, y) outline, from z0 to z1."""
    n = len(pts)
    verts = [(cx + x, cy + y, z0) for x, y in pts] + [(cx + x, cy + y, z1) for x, y in pts]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces += [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    m.poly(verts, faces, mat)


def ibeam(m, cx, cy, z0, z1, depth, width, mat, tf=0.012, tw=0.009):
    """An I-section post standing up: flanges across X (facing the road and the sea), the web along X."""
    d, w = depth / 2, width / 2
    pts = [(-d, -w), (-d, w), (-d + tf, w), (-d + tf, tw / 2), (d - tf, tw / 2), (d - tf, w), (d, w), (d, -w),
           (d - tf, -w), (d - tf, -tw / 2), (-d + tf, -tw / 2), (-d + tf, -w)]
    prism_z(m, pts, z0, z1, mat, cx, cy)


def annulus(m, cx, cy, z, r_in, r_out, mat, segs=12, aspect=1.0):
    """A flat ring lying face-up: slush round something afloat, or a painted circle."""
    for s in range(segs):
        a0, a1 = 2 * math.pi * s / segs, 2 * math.pi * (s + 1) / segs
        pts = [(cx + math.cos(a) * rr, cy + math.sin(a) * rr * aspect, z)
               for a, rr in ((a0, r_in), (a0, r_out), (a1, r_out), (a1, r_in))]
        facet(m, pts, mat, out=(0, 0, 1))


def frame_ring(m, c, yaw, w, h, border, depth, mat):
    """A window or door frame: a rectangular ring standing `depth` proud of its wall, with inner reveals."""
    rot = Euler((0.0, 0.0, yaw)).to_matrix()
    c = Vector(c)

    def rect(hw, hh, x):
        return [c + rot @ Vector((x, y, z)) for y, z in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))]

    of, inf = rect(w / 2 + border, h / 2 + border, depth / 2), rect(w / 2, h / 2, depth / 2)
    ob, inb = rect(w / 2 + border, h / 2 + border, -depth / 2), rect(w / 2, h / 2, -depth / 2)
    verts = [tuple(p) for p in of + inf + ob + inb]
    faces = []
    for i in range(4):
        j = (i + 1) % 4
        faces.append((i, j, 4 + j, 4 + i))  # front of the frame
        faces.append((8 + i, 8 + j, j, i))  # outer edge
        faces.append((4 + i, 4 + j, 12 + j, 12 + i))  # inner reveal
    m.poly(verts, faces, mat)


def window(m, c, yaw, w, h, frame=None, pane=None, border=0.09, depth=0.16, mullions=0):
    """A lit window on a wall facing direction `yaw` (0 = +X, pi = the road): a frame proud of the wall,
    the glowing pane set back inside it (a single flat face, which the bevel skips), and optional round
    glazing bars. `c` is the wall-face point."""
    frame = frame or STEEL
    pane = pane or WINDOW
    c = Vector(c)
    normal = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    side = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
    up = Vector((0.0, 0.0, 1.0))
    frame_ring(m, c, yaw, w, h, border, depth, frame)
    p = c + normal * (depth / 2 - 0.05)
    facet(m, [p - side * (w / 2) - up * (h / 2), p + side * (w / 2) - up * (h / 2), p + side * (w / 2) + up * (h / 2),
              p - side * (w / 2) + up * (h / 2)], pane, out=normal)
    for i in range(mullions):
        off = side * (w * ((i + 1) / (mullions + 1) - 0.5)) + normal * (depth / 2 - 0.03)
        tube(m, c + off - up * (h / 2), c + off + up * (h / 2), 0.025, frame)


def door(m, c, yaw, w=1.0, h=2.0, frame=None, leaf=None, lit=True):
    """A hatch door: frame, a recessed leaf, a small lit port in it and a handle stud. `c` is the wall
    point at the foot of the door's centre."""
    frame = frame or STEEL
    leaf = leaf or HULL
    c = Vector(c)
    normal = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    side = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
    mid = c + Vector((0, 0, h / 2))
    frame_ring(m, mid, yaw, w, h, 0.1, 0.18, frame)
    m.box((0.06, w + 0.02, h + 0.02), mid + normal * 0.0, leaf, rot=(0, 0, yaw))
    if lit:
        p = mid + normal * 0.035 + Vector((0, 0, h * 0.22))
        facet(m, [p - side * (w * 0.2) - Vector((0, 0, 0.15)), p + side * (w * 0.2) - Vector((0, 0, 0.15)),
                  p + side * (w * 0.2) + Vector((0, 0, 0.15)), p - side * (w * 0.2) + Vector((0, 0, 0.15))], WINDOW, out=normal)
    stud(m, mid + normal * 0.03 + side * (w * 0.32), normal, 0.04, frame)


def railing(m, pts, mat, h=1.05, every=1.5, r=0.03, knee=True):
    """A handrail along a polyline of deck points: posts, a top rail and a knee rail, all tubes."""
    pts = [Vector(p) for p in pts]
    up = Vector((0.0, 0.0, h))
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        tube(m, a + up, b + up, r, mat)
        if knee:
            tube(m, a + up * 0.5, b + up * 0.5, r * 0.75, mat)
        n = max(1, round((b - a).length / every))
        last = i == len(pts) - 2
        for k in range(n + (1 if last else 0)):
            p = a.lerp(b, k / n)
            tube(m, p, p + up, r, mat)


def ring_rail(m, cx, cy, z, rad, mat, h=1.0, posts=12, r=0.03):
    """A railing round a circular gallery or deck edge."""
    pts = [(cx + math.cos(2 * math.pi * k / posts) * rad, cy + math.sin(2 * math.pi * k / posts) * rad, z)
           for k in range(posts + 1)]
    railing(m, pts, mat, h=h, every=1e9, r=r)


def ladder(m, a, b, side, mat, width=0.45, spacing=0.34, r=0.02):
    """Two stiles and round rungs from a to b; `side` points across the ladder."""
    a, b = Vector(a), Vector(b)
    s = Vector(side).normalized() * (width / 2)
    tube(m, a - s, b - s, r * 1.4, mat)
    tube(m, a + s, b + s, r * 1.4, mat)
    n = max(1, int((b - a).length / spacing))
    for i in range(1, n + 1):
        p = a.lerp(b, i / (n + 1))
        tube(m, p - s, p + s, r, mat)


def chunk(m, centre, half, seed, mats=None, top=None, yaw=0.0, tilt=0.0, n=10, box=False, cuts=(), top_cut=0.62):
    """A faceted lump of ice or rock: the convex hull of jittered points, each face a flat facet. `box`
    jitters a box's corners (slabs, blocks) instead of points on an ellipsoid (rubble, boulders). `cuts` are
    (point, normal) planes that split the faces into strata; `mats(face_centre, up, rng)` picks each face's
    material, and faces turned up past `top_cut` take `top` (frost settles there)."""
    r = random.Random(seed)
    c = Vector(centre)
    rot = Euler((tilt, 0.0, yaw)).to_matrix()
    pts = []
    if box:
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    pts.append(Vector((sx * half[0] * r.uniform(0.7, 1.0), sy * half[1] * r.uniform(0.7, 1.0),
                                       sz * half[2] * r.uniform(0.75, 1.0))))
        for _ in range(max(0, n - 8)):
            pts.append(Vector((r.uniform(-1, 1) * half[0], r.uniform(-1, 1) * half[1], half[2] * r.uniform(0.85, 1.1))))
    else:
        for _ in range(n):
            zz = r.uniform(-1.0, 1.0)
            th = r.uniform(0.0, 2.0 * math.pi)
            s = math.sqrt(1.0 - zz * zz)
            k = r.uniform(0.72, 1.0)
            pts.append(Vector((s * math.cos(th) * half[0] * k, s * math.sin(th) * half[1] * k, zz * half[2] * k)))
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(c + rot @ p)
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    for co, no in cuts:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
    for f in bm.faces:
        fc = f.calc_center_median()
        poly = [v.co.copy() for v in f.verts]
        nrm = newell(poly)
        if nrm.dot(fc - c) < 0.0:
            poly.reverse()
            nrm = -nrm
        up = nrm.z / max(nrm.length, 1e-9)
        if top is not None and up > top_cut:
            mat = top
        elif callable(mats):
            mat = mats(fc, up, r)
        else:
            mat = mats or ICE
        facet(m, poly, mat)
    bm.free()


def strata(r_bottom, r_top, height, count, seed, z_start=0.0, step=0.1, ledge=0.06):
    """(radius, z) rings for spire(): `count` strata from r_bottom to r_top over `height`. Each stratum is a
    steep face whose top lip stands about `step` proud of the stratum above, so a frosted ledge runs round
    between them."""
    r = random.Random(seed)
    out = []
    for i in range(count):
        z_lo = z_start + height * i / count + (ledge * height / count if i else 0.0)
        z_hi = z_start + height * (i + 1) / count
        rad_lo = r_bottom + (r_top - r_bottom) * i / count
        rad_hi = r_bottom + (r_top - r_bottom) * (i + 1) / count
        out.append((rad_lo * r.uniform(0.97, 1.03), z_lo))
        lip = 1.0 + step * r.uniform(0.5, 1.5) if i < count - 1 else 1.0
        out.append((rad_hi * lip, z_hi))
    return out


def spire(m, cx, cy, z0, layers, seed, segs=10, jit=0.22, band=None, cap=None, cleft=0, apex=0.0,
          lean=(0.0, 0.0), aspect=1.0, cleft_mats=(ICE_DEEP,), wander=0.07, warp=0.08, dip=None,
          seracs=0, vein=VEIN):
    """A column of ice or rock: rings of points at each (radius, z) of `layers`, skinned with flat facets.
    The points sit on shared columns (one angle and radial factor all the way up, plus a little of their
    own), so the faces read as vertical fractures and flutes rather than noise. band(j, rng) gives ring j's
    stratum material; faces that turn up (ledges, where a stratum steps in) take frost. `cleft` columns are
    cut deep into the face (fractures), lined with deep ice, a thin glowing `vein` seam broken along the
    back of each (whole glowing facets read as neon slabs on a big cliff). `apex` raises the top to a point;
    otherwise it is capped flat with `cap`. Returns the rings.
    So it never reads as a stack of rings: each stratum's centre wanders (`wander`), each ring is warped by
    a slow lobed wave of its own (`warp`), so ledges widen, narrow and turn to overhangs round the column,
    the strata dip together at a random angle (`dip`), and `seracs` blocks stick out of the faces."""
    r = random.Random(seed)
    band = band or (lambda j, rr: ICE)
    ang = [2 * math.pi * (s + r.uniform(-0.3, 0.3)) / segs for s in range(segs)]
    col = [r.uniform(1.0 - jit, 1.0 + jit) for _ in range(segs)]
    clefts = set(r.sample(range(segs), cleft)) if cleft else set()
    heading = r.uniform(0, 2 * math.pi)
    slope = math.tan(r.uniform(0.04, 0.14) if dip is None else dip)
    ddx, ddy = math.cos(heading) * slope, math.sin(heading) * slope
    wx = wy = 0.0
    rings = []
    for j, (rad, z) in enumerate(layers):
        if j and j % 2 == 0:
            wx += r.uniform(-wander, wander) * rad
            wy += r.uniform(-wander, wander) * rad
        ox, oy = cx + lean[0] * z + wx, cy + lean[1] * z + wy
        deep = 0.62 if 0 < j < len(layers) - 1 else 1.0
        lobes, phase = r.choice((2, 3)), r.uniform(0, 2 * math.pi)
        amp = warp if j else warp * 0.4
        tilt = 1.0 if j else 0.0  # the foot stays level, buried in the ground or the sea
        ring = []
        for s in range(segs):
            k = col[s] * r.uniform(0.95, 1.05) * (1.0 + amp * math.sin(lobes * ang[s] + phase))
            k *= deep if s in clefts else 1.0
            dx, dy = math.cos(ang[s]) * rad * k, math.sin(ang[s]) * rad * k * aspect
            ring.append(Vector((ox + dx, oy + dy, z0 + z + tilt * (dx * ddx + dy * ddy) + r.uniform(-0.05, 0.05) * min(rad, 2.0))))
        rings.append(ring)
    # Rings run counter-clockwise, so (j s, j s+1, j+1 s+1, j+1 s) faces outward: ledges up, overhangs down.
    for j in range(len(rings) - 1):
        for s in range(segs):
            s1 = (s + 1) % segs
            q = [rings[j][s], rings[j][s1], rings[j + 1][s1], rings[j + 1][s]]
            nrm = newell(q)
            if nrm.z > 0.6 * nrm.length:
                mat = FROST
            elif s in clefts or s1 in clefts:
                mat = r.choice(cleft_mats)
            else:
                mat = band(j, r)
            facet(m, q, mat)
    for s in clefts if vein is not None else ():
        for j in range(1, len(rings) - 2):
            if r.random() < 0.3:
                continue
            a, b = rings[j][s], rings[j + 1][s]
            out = Vector((a.x + b.x, a.y + b.y, 0.0)) / 2 - Vector((cx, cy, 0.0))
            out = out.normalized() * 0.1 if out.length > 1e-6 else Vector((0.0, 0.0, 0.0))
            w = Vector((-out.y, out.x, 0.0)).normalized() * min(0.12, 0.03 * layers[j][0]) if out.length else Vector()
            facet(m, [a - w + out, a + w + out, b + w + out, b - w + out], vein, out=out)
    top = rings[-1]
    if apex > 0.0:
        tip = sum(top, Vector()) / segs + Vector((r.uniform(-0.3, 0.3) * apex, r.uniform(-0.3, 0.3) * apex, apex))
        for s in range(segs):
            tri = [top[s], top[(s + 1) % segs], tip]
            nrm = newell(tri)
            facet(m, tri, FROST if nrm.z > 0.55 * nrm.length else band(len(rings) - 1, r))
    elif cap is not None:
        facet(m, top, cap)
    for b in range(seracs):
        j = r.randrange(1, len(rings) - 1)
        sidx = r.randrange(segs)
        p = rings[j][sidx]
        centre = sum(rings[j], Vector()) / segs
        size = (p - centre).length * r.uniform(0.12, 0.22) + 0.2
        at = centre.lerp(p, 0.97)
        chunk(m, (at.x, at.y, at.z - size * 0.3), (size, size * 0.8, size * 1.3), seed * 31 + b, mats=band(j, r), top=FROST,
              yaw=ang[sidx] + r.uniform(-0.4, 0.4), tilt=r.uniform(-0.3, 0.3), box=True)
    return rings


def bands(seed, palette, rock=0, rock_mat=None):
    """A stratum material picker for spire(): the lowest `rock` strata rock, the rest drawn from `palette`
    stratum by stratum (one material per stratum, so the layers read as bands)."""
    r = random.Random(seed)
    picks = [r.choice(palette) for _ in range(64)]

    def pick(j, rr):
        s = j // 2
        if s < rock:
            return rock_mat or ROCK
        return picks[s % 64]
    return pick


BERG = (ICE, ICE, ICE_LIGHT, ICE_LIGHT, ICE_DEEP)


def wobble(y, key, length, amp):
    """Smooth periodic noise along a repeating prop: equal at both ends, so tiles join."""
    r = random.Random(key * 7919 + 13)
    return amp * sum(r.uniform(0.5, 1.0) / m * math.sin(2 * math.pi * m * y / length + r.uniform(0, 6.283))
                     for m in (1, 2, 3))


def strip(m, rows, length, segs, mats, out):
    """A surface stretched along Y between profile rows of (x, z, wobble_x, wobble_z, key); rows sharing a
    key wobble together (a stratum's face and its ledge move as one). Facets face `out`."""
    for i in range(segs):
        y0, y1 = -length / 2 + i * length / segs, -length / 2 + (i + 1) * length / segs
        for k in range(len(rows) - 1):
            def at(y, kk):
                x, z, ax, az, key = rows[kk]
                return (x + wobble(y, key * 3 + 1, length, ax), y, z + wobble(y, key * 3 + 2, length, az))
            facet(m, [at(y0, k), at(y1, k), at(y1, k + 1), at(y0, k + 1)], mats(k, i), out=out)


# ---------------------------------------------------------------- along the road

def barrier():
    """The sea wall: a W-beam guard rail of galvanised steel bolted through spacer blocks to I-beam posts on
    a concrete kerb, with a lapped and bolted splice and a coral reflector over each post. Exactly one
    RAIL_LENGTH long (two posts 3 m apart, one splice), so tiles join seamlessly."""
    m = Prop("barrier")
    half = RAIL_LENGTH / 2
    # The kerb stops 2 cm short of each end: the joint reads as an expansion gap.
    extrude(m, [(-0.40, -0.10), (0.40, -0.10), (0.40, 0.14), (0.33, 0.24), (-0.33, 0.24), (-0.40, 0.14)],
            -half + 0.02, half - 0.02, CONCRETE)
    rail_z = 0.64  # the W-beam's centre line
    xb = -0.155  # the rail's back, against the spacer blocks
    for y in (-half / 2, half / 2):
        m.box((0.30, 0.24, 0.025), (0.05, y, 0.2525), GALV, bevel=False)
        for dx in (-0.1, 0.1):
            for dy in (-0.08, 0.08):
                stud(m, (0.05 + dx, y + dy, 0.265), (0, 0, 1), 0.022, GALV)
        ibeam(m, 0.05, y, 0.265, 0.96, 0.15, 0.10, GALV)
        m.box((0.012, 0.11, 0.012), (0.05, y, 0.966), GALV, bevel=False)  # cap strap
        m.box((0.13, 0.11, 0.30), (-0.09, y, rail_z), GALV)  # spacer block
        stud(m, (xb - 0.02, y, rail_z), (-1, 0, 0), 0.03, GALV)
        # The reflector rides proud of the rail's peaks on a bracket in the valley.
        m.box((0.07, 0.03, 0.05), (xb - 0.06, y, rail_z), GALV, bevel=False)
        m.box((0.016, 0.1, 0.15), (xb - 0.1, y, rail_z), REFLECTOR, bevel=False)
    # The W-beam: two peaks toward the road, a valley between; an open sheet 12 mm thick.
    w = [(0.0, 0.155), (-0.035, 0.135), (-0.075, 0.10), (-0.083, 0.075), (-0.07, 0.04), (-0.03, 0.012), (-0.02, 0.0),
         (-0.03, -0.012), (-0.07, -0.04), (-0.083, -0.075), (-0.075, -0.10), (-0.035, -0.135), (0.0, -0.155)]
    face = [(xb + px, rail_z + pz) for px, pz in w]
    back = [(xb + px + 0.012, rail_z + pz) for px, pz in reversed(w)]
    extrude(m, face + back, -half, half, GALV, caps=False)
    # Splice: the next rail's end lapped 32 cm over this one, eight bolts through the lap.
    extrude(m, [(x - 0.008, z) for x, z in face + back], -half, -half + 0.32, GALV, caps=False)
    for y in (-half + 0.05, -half + 0.12, -half + 0.2, -half + 0.27):
        for dz in (-0.05, 0.05):
            stud(m, (xb - 0.058, y, rail_z + dz), (-1, 0, 0), 0.017, GALV)
    return m.finish()


def bank():
    """The ice shelf's broken edge from the road's lip down to the water, modelled from the waterline up:
    a frosted slope, then strata stepping down in ledges to a wet wash zone, with calved blocks and a dim
    glowing slush line at the water. Gentler than a cliff on purpose: anything steeper than the camera's
    sight line over the lip is never seen."""
    m = Prop("bank")
    rows = [(-0.5, ROAD - 0.12, 0.0, 0.0, 0), (1.2, ROAD - 0.7, 0.4, 0.1, 1), (3.4, ROAD - 1.75, 0.8, 0.3, 2),
            (5.6, 2.3, 0.7, 0.2, 3), (6.3, 2.12, 0.7, 0.1, 3),  # top of the strata, and its ledge
            (6.5, 1.25, 0.6, 0.1, 4), (7.5, 1.08, 0.6, 0.08, 4),  # a stratum and its ledge
            (7.75, 0.3, 0.7, 0.05, 5), (9.8, -0.1, 0.8, 0.0, 6), (11.2, -0.7, 0.7, 0.0, 7)]

    def mats(k, i):
        if k == 0:
            return ROCK
        if k in (1, 3, 5):
            return FROST
        if k == 2:
            return FROST if (i % 3) else ICE_LIGHT
        if k == 4:
            return ICE if i % 4 else ICE_LIGHT
        if k == 6:
            return ICE_DEEP
        return ICE

    strip(m, rows, BANK_LENGTH, 12, mats, out=(1.0, 0.0, 1.0))
    r = random.Random(2203)
    for b in range(7):
        y = -BANK_LENGTH / 2 + 1.0 + b * (BANK_LENGTH - 2.0) / 6 + r.uniform(-0.4, 0.4)
        size = r.uniform(0.5, 1.1)
        chunk(m, (r.uniform(8.2, 11.0), y, size * r.uniform(-0.1, 0.3)), (size * 1.3, size, size * 0.7), 2210 + b,
              mats=lambda c, up, rr: ICE_LIGHT if rr.random() < 0.4 else ICE, top=FROST, yaw=r.uniform(0, 6.3),
              tilt=r.uniform(-0.3, 0.3), box=True)
    # Calved slabs leaning on the lowest stratum.
    for b in range(3):
        y = -BANK_LENGTH / 2 + 2.5 + b * 3.6
        chunk(m, (8.1, y, 0.35), (0.25, 0.9, 0.7), 2230 + b, mats=ICE, top=FROST, tilt=0.0,
              yaw=r.uniform(-0.3, 0.3), box=True)
    strip(m, [(9.8, 0.04, 0.7, 0.0, 6), (12.4, 0.04, 0.9, 0.0, 8)], BANK_LENGTH, 8, lambda k, i: SLUSH, out=(0, 0, 1))
    return m.finish()


def lightmast():
    """A light mast by the sea wall: a three-chord tubular lattice on a concrete footing and bolted base
    plate, a lattice arm reaching toward the road (-X) to a finned lamp head with a cool-white light bar
    that stops short of the road's edge, a junction box with its conduit, and a coral marker on top."""
    m = Prop("lightmast")
    m.cyl(0.5, 0.42, 0.5, (0, 0, 0.1), CONCRETE, segs=8)
    m.box((0.6, 0.6, 0.04), (0, 0, 0.37), STEEL, bevel=False)
    for dx in (-0.22, 0.22):
        for dy in (-0.22, 0.22):
            stud(m, (dx, dy, 0.39), (0, 0, 1), 0.03, STEEL)
    z0, z1 = 0.39, 7.2

    def chord(k, z):
        t = (z - z0) / (z1 - z0)
        rad = 0.30 - 0.15 * t
        a = math.pi + k * 2 * math.pi / 3
        return Vector((math.cos(a) * rad, math.sin(a) * rad, z))

    for k in range(3):
        tube(m, chord(k, z0), chord(k, z1), 0.032, STEEL)
    bays = 11
    for i in range(bays):
        za, zb = z0 + (z1 - z0) * i / bays, z0 + (z1 - z0) * (i + 1) / bays
        for k in range(3):
            k1 = (k + 1) % 3
            if i % 2:
                tube(m, chord(k, za), chord(k1, zb), 0.014, STEEL)
            else:
                tube(m, chord(k1, za), chord(k, zb), 0.014, STEEL)
            if i % 3 == 0:
                tube(m, chord(k, za), chord(k1, za), 0.014, STEEL)
    m.cyl(0.22, 0.22, 0.06, (0, 0, z1 + 0.03), STEEL, segs=12, bevel=False)
    # The arm: a small Warren truss out to the lamp head.
    top_a, top_b = Vector((-0.05, 0, z1 + 0.06)), Vector((-1.12, 0, z1 + 0.24))
    bot_a, bot_b = Vector((-0.12, 0, z1 - 0.55)), Vector((-1.05, 0, z1 + 0.12))
    tube(m, top_a, top_b, 0.026, STEEL)
    tube(m, bot_a, bot_b, 0.026, STEEL)
    for i in range(4):
        t0, t1 = i / 4, (i + 1) / 4
        if i % 2:
            tube(m, top_a.lerp(top_b, t0), bot_a.lerp(bot_b, t1), 0.014, STEEL)
        else:
            tube(m, bot_a.lerp(bot_b, t0), top_a.lerp(top_b, t1), 0.014, STEEL)
    head = Vector((-1.15, 0.0, z1 + 0.2))
    m.box((0.5, 1.3, 0.14), head, STEEL, rot=(0, math.radians(-4), 0))
    m.box((0.36, 1.1, 0.04), head + Vector((0, 0, -0.08)), LIGHT_BAR, bevel=False)
    for y in (-0.45, -0.15, 0.15, 0.45):
        m.box((0.42, 0.025, 0.07), head + Vector((0, y, 0.1)), STEEL, bevel=False)
    # Junction box on the sea side, its conduit running down into the footing.
    m.box((0.16, 0.28, 0.38), (0.27, 0.0, 1.3), STEEL)
    stud(m, (0.352, 0.08, 1.42), (1, 0, 0), 0.025, STEEL)
    stud(m, (0.352, -0.08, 1.42), (1, 0, 0), 0.025, STEEL)
    tube(m, (0.27, 0.0, 1.11), (0.27, 0.0, 0.33), 0.03, STEEL)
    tube(m, (0, 0, z1 + 0.06), (0, 0, z1 + 0.5), 0.03, STEEL)
    m.box((0.12, 0.12, 0.12), (0, 0, z1 + 0.56), REFLECTOR, bevel=False)
    return m.finish()


def marker():
    """A roadside marker post on the land side: a galvanised post in a concrete collar with anchor bolts, a
    coral reflector in a bezel on its road (-X) face, a pyramid cap, and frost drifted against its foot."""
    m = Prop("marker")
    m.cyl(0.26, 0.22, 0.3, (0, 0, 0.0), CONCRETE, segs=8)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        stud(m, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.152), (0, 0, 1), 0.02, GALV)
    m.box((0.14, 0.14, 0.04), (0, 0, 0.17), GALV, bevel=False)
    m.box((0.11, 0.11, 1.3), (0, 0, 0.8), GALV)
    m.box((0.025, 0.105, 0.36), (-0.066, 0, 1.18), GALV, bevel=False)
    m.box((0.02, 0.08, 0.3), (-0.078, 0, 1.18), REFLECTOR, bevel=False)
    m.box((0.02, 0.06, 0.08), (0.062, 0, 1.3), REFLECTOR, bevel=False)  # a small one on the back, for the far lane
    m.cyl(0.09, 0.015, 0.1, (0, 0, 1.5), GALV, segs=4, rot=(0, 0, math.pi / 4))
    chunk(m, (0.06, 0.1, 0.02), (0.34, 0.26, 0.12), 401, mats=FROST)
    chunk(m, (0.24, -0.16, 0.0), (0.18, 0.16, 0.08), 402, mats=FROST)
    return m.finish()


# ---------------------------------------------------------------- the sea (modelled from the waterline up)

def _floe(name, radius, seed, ridges):
    """A flat ice floe afloat: a faceted slab with a ragged outline and a lumpy frosted top, pressure ridges
    of up-ended slabs across it, snow drifts, rubble at its edge and a dim slush ring on the water."""
    r = random.Random(seed)
    m = Prop(name)
    segs = 13
    ry = r.uniform(0.62, 0.85)
    outline = []
    for s in range(segs):
        a = 2 * math.pi * (s + r.uniform(-0.3, 0.3)) / segs
        k = r.uniform(0.74, 1.12)
        outline.append((math.cos(a) * radius * k, math.sin(a) * radius * ry * k))

    def ring(z, scale, jz=0.0):
        return [Vector((x * scale, y * scale, z + r.uniform(-jz, jz))) for x, y in outline]

    under, water, rim, inner = ring(-0.7, 0.86), ring(0.0, 1.0), ring(0.26, 0.95, 0.06), ring(0.36, 0.58, 0.09)
    crown = Vector((r.uniform(-0.2, 0.2) * radius, r.uniform(-0.2, 0.2) * radius * ry, 0.42))
    for s in range(segs):
        s1 = (s + 1) % segs
        facet(m, [under[s], under[s1], water[s1], water[s]], ICE_DEEP)
        facet(m, [water[s], water[s1], rim[s1], rim[s]], ICE_LIGHT if s % 3 else ICE)
        facet(m, [rim[s], rim[s1], inner[s1], inner[s]], FROST)
        facet(m, [inner[s], inner[s1], crown], FROST)
    for g in range(ridges):
        phi = r.uniform(0, math.pi)
        d = r.uniform(-0.25, 0.25) * radius
        length = radius * r.uniform(1.0, 1.4)
        count = int(length / 0.55)
        for b in range(count):
            t = (b + 0.5) / count - 0.5
            x = math.cos(phi) * t * length - math.sin(phi) * d
            y = (math.sin(phi) * t * length + math.cos(phi) * d) * ry
            h = r.uniform(0.18, 0.45) * (1.0 - abs(t) * 1.2)
            chunk(m, (x, y, 0.34 + h * 0.4), (r.uniform(0.26, 0.42), r.uniform(0.06, 0.12), h + 0.08),
                  seed * 100 + g * 20 + b, mats=lambda c, up, rr: ICE_LIGHT if rr.random() < 0.6 else ICE, top=FROST,
                  yaw=phi + r.uniform(-0.35, 0.35), tilt=r.choice((-1, 1)) * r.uniform(0.25, 0.6), box=True)
    for b in range(2):
        a = r.uniform(0, 2 * math.pi)
        chunk(m, (math.cos(a) * radius * 0.4, math.sin(a) * radius * ry * 0.4, 0.34),
              (radius * 0.28, radius * 0.16, 0.12), seed * 100 + 80 + b, mats=FROST, yaw=r.uniform(0, 6.3), n=9)
    for b in range(4):
        a = r.uniform(0, 2 * math.pi)
        x, y = math.cos(a) * radius * 1.02, math.sin(a) * radius * ry * 1.02
        s = r.uniform(0.25, 0.5)
        chunk(m, (x, y, s * 0.2), (s, s * 0.8, s * 0.6), seed * 100 + 90 + b, mats=ICE_LIGHT, top=FROST, n=8)
    pts_in = [Vector((x * 1.0, y * 1.0, 0.03)) for x, y in outline]
    pts_out = [Vector((x * 1.16, y * 1.16, 0.03)) for x, y in outline]
    for s in range(segs):
        s1 = (s + 1) % segs
        facet(m, [pts_in[s], pts_out[s], pts_out[s1], pts_in[s1]], SLUSH, out=(0, 0, 1))
    return m.finish()


def floe_a():
    return _floe("floe_a", 2.6, 81, 1)


def floe_b():
    return _floe("floe_b", 4.4, 82, 2)


def _calved(m, cx, cy, spread, count, seed, size=(0.8, 2.0), mats=None):
    """Calved blocks round a berg's waterline: tilted, faceted, half under."""
    r = random.Random(seed)
    for b in range(count):
        a = r.uniform(0, 2 * math.pi)
        d = spread * r.uniform(0.85, 1.3)
        s = r.uniform(*size)
        chunk(m, (cx + math.cos(a) * d, cy + math.sin(a) * d, s * r.uniform(-0.2, 0.25)), (s * 1.2, s, s * 0.8),
              seed * 50 + b, mats=mats or (lambda c, up, rr: rr.choice(BERG[:4])), top=FROST, yaw=r.uniform(0, 6.3),
              tilt=r.uniform(-0.4, 0.4), box=r.random() < 0.5, n=11)


def iceberg_a():
    """A jagged iceberg: a tall spire in strata with a fracture glowing teal down its face, two shoulders,
    calved blocks round its foot and a slush ring at the waterline."""
    m = Prop("iceberg_a")
    spire(m, 0, 0, -2.0, strata(7.0, 1.3, 19.0, 9, 51, step=0.09), 51, segs=16, jit=0.3, band=bands(51, BERG),
          cleft=3, apex=2.6, lean=(0.05, -0.03), seracs=6)
    spire(m, 5.5, 4.0, -1.5, strata(3.9, 0.9, 8.4, 5, 52), 52, segs=12, jit=0.32, band=bands(52, BERG), cleft=1, apex=1.2,
          lean=(0.08, 0.05), seracs=2)
    spire(m, -3.5, -5.0, -1.0, strata(3.0, 0.8, 5.2, 3, 53), 53, segs=10, jit=0.3, band=bands(53, BERG), apex=0.8,
          seracs=1)
    _calved(m, 0.5, 0.0, 8.2, 9, 54)
    annulus(m, 0.8, 0.0, 0.04, 7.2, 10.2, SLUSH, segs=14)
    return m.finish()


def iceberg_b():
    """A tabular iceberg: a broad slab in strata with ledges, a smaller slab on top, a spire on one corner
    and calved blocks along its foot."""
    m = Prop("iceberg_b")
    spire(m, 0, 0, -2.0, strata(9.0, 7.6, 9.0, 5, 54, step=0.05), 54, segs=20, jit=0.14, band=bands(55, BERG),
          cap=FROST, cleft=3, aspect=0.66, warp=0.06, dip=0.05, seracs=5)
    spire(m, -1.5, 0.8, 6.8, strata(5.0, 3.8, 3.6, 2, 56, step=0.05), 56, segs=13, jit=0.16, band=bands(57, BERG),
          cap=FROST, aspect=0.72, dip=0.05, seracs=2)
    spire(m, 6.0, -3.0, -1.0, strata(3.4, 0.8, 11.4, 5, 58), 58, segs=11, jit=0.3, band=bands(59, BERG), cleft=1,
          apex=1.4, lean=(0.06, -0.04), seracs=2)
    _calved(m, 0.0, 0.0, 9.6, 8, 60, size=(0.9, 2.2))
    annulus(m, 0, 0, 0.04, 9.4, 12.0, SLUSH, segs=16, aspect=0.7)
    return m.finish()


def beacon():
    """A lighthouse-style beacon tower on a rock islet: a stair climbs from a floating jetty up the rock to
    the tower's plinth, where a service hut and a canopied door face the road. The plated shaft has coral
    bands and lit slit windows; at the top a gallery on brackets with a railing rings the lamp room, whose
    glazing bars stand round a glowing lens (the world script sweeps beams from BEAM_HEIGHT), under a coral
    roof with a ventilator ball, a lightning rod and a blinker."""
    m = Prop("beacon")
    top = 4.6  # the islet's level top, above the waterline
    rock = bands(61, (ROCK,))
    spire(m, 0, 0, -2.0, strata(9.4, 5.2, top + 2.0, 4, 61, step=0.08), 61, segs=16, jit=0.16, band=rock, cap=FROST,
          cleft=3, cleft_mats=(ROCK,), dip=0.0, wander=0.02, seracs=3, vein=None)
    spire(m, 5.6, 6.2, -1.0, strata(4.2, 1.6, 4.4, 3, 62), 62, segs=10, jit=0.28, band=rock, apex=0.8, seracs=1)
    _calved(m, 0.0, 0.0, 9.2, 5, 63, size=(0.6, 1.3), mats=ROCK)
    # Plinth and shaft.
    m.cyl(3.2, 3.2, 0.8, (0, 0, top), STEEL, segs=16)
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        stud(m, (math.cos(a) * 2.75, math.sin(a) * 2.75, top + 0.4), (0, 0, 1), 0.06, STEEL)
    base, high = top + 0.4, 24.0

    def radius(z):
        return 1.8 - 0.7 * (z - base) / (high - base)

    tube(m, (0, 0, base), (0, 0, high), radius(base), HULL_LIGHT, r2=radius(high), phase=math.pi / 12)
    for z in [base + 2.2 * i for i in range(1, 9)]:
        tube(m, (0, 0, z - 0.05), (0, 0, z + 0.05), radius(z) + 0.03, STEEL, phase=math.pi / 12)
    for z in (8.4, 13.8, 19.2):
        tube(m, (0, 0, z - 0.6), (0, 0, z + 0.6), radius(z - 0.6) + 0.035, CORAL, r2=radius(z + 0.6) + 0.035,
             phase=math.pi / 12)
    for z, deg in ((7.0, 180), (10.6, 150), (16.4, 210), (21.6, 180)):
        a = math.radians(deg)
        rr = radius(z) * math.cos(math.pi / 12)
        window(m, (math.cos(a) * rr, math.sin(a) * rr, z), a, 0.34, 0.8, frame=STEEL, border=0.08)
    # The door, its canopy and a lamp over it.
    rr = radius(base) * math.cos(math.pi / 12)
    door(m, (-rr, 0, base + 0.02), math.pi, 1.0, 2.1, leaf=STEEL)
    m.box((0.9, 1.6, 0.08), (-rr - 0.42, 0, base + 2.45), STEEL)
    m.box((0.1, 0.3, 0.12), (-rr - 0.06, 0, base + 2.62), WINDOW)
    # Gallery on brackets, its railing, and the lamp room.
    m.cyl(2.4, 2.4, 0.25, (0, 0, high + 0.12), STEEL, segs=16)
    for k in range(12):
        a = 2 * math.pi * k / 12
        tube(m, (math.cos(a) * radius(high - 1.2) * 0.9, math.sin(a) * radius(high - 1.2) * 0.9, high - 1.2),
             (math.cos(a) * 2.2, math.sin(a) * 2.2, high), 0.06, STEEL)
    ring_rail(m, 0, 0, high + 0.25, 2.3, STEEL, h=1.05, posts=16)
    tube(m, (0, 0, high + 0.25), (0, 0, BEAM_HEIGHT - 1.0), 1.3, HULL_LIGHT, caps=True)
    m.cyl(0.8, 0.8, 1.8, (0, 0, BEAM_HEIGHT), BEACON, segs=12)
    m.cyl(0.95, 0.95, 0.12, (0, 0, BEAM_HEIGHT - 0.95), STEEL, segs=12)
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        tube(m, (math.cos(a) * 1.22, math.sin(a) * 1.22, BEAM_HEIGHT - 1.0),
             (math.cos(a) * 1.22, math.sin(a) * 1.22, BEAM_HEIGHT + 1.2), 0.045, STEEL)
    for z in (BEAM_HEIGHT - 0.95, BEAM_HEIGHT + 0.1):
        ring_pts = [(math.cos(2 * math.pi * (k + 0.5) / 12) * 1.22, math.sin(2 * math.pi * (k + 0.5) / 12) * 1.22, z)
                    for k in range(13)]
        for a, b in zip(ring_pts, ring_pts[1:]):
            tube(m, a, b, 0.035, STEEL)
    roof = BEAM_HEIGHT + 1.2
    m.cyl(1.5, 1.5, 0.16, (0, 0, roof + 0.08), CORAL, segs=12)
    m.cyl(1.42, 0.22, 1.25, (0, 0, roof + 0.78), CORAL, segs=12)
    m.blob(0.32, (0, 0, roof + 1.6), STEEL, subdiv=2, jitter=0.0)
    tube(m, (0, 0, roof + 1.85), (0, 0, roof + 3.6), 0.04, STEEL, r2=0.015)
    m.blob(0.22, (0, 0, roof + 3.75), BLINK, subdiv=1, jitter=0.0)
    # Service hut on the plinth's road side.
    hx, hy = -2.6, 2.6
    m.box((2.0, 2.4, 2.9), (hx, hy, top + 1.15), HULL_LIGHT)
    m.box((2.3, 2.7, 0.14), (hx, hy, top + 2.67), CORAL)
    m.box((0.6, 0.6, 0.35), (hx + 0.3, hy + 0.4, top + 2.92), STEEL)
    window(m, (hx - 1.0, hy + 0.4, top + 1.75), math.pi, 0.7, 0.6, frame=STEEL)
    door(m, (hx + 0.1, hy - 1.2, top + 0.4), -math.pi / 2, 0.8, 1.9, leaf=STEEL)
    tube(m, (hx + 0.7, hy + 0.9, top + 2.74), (hx + 0.7, hy + 0.9, top + 5.0), 0.03, STEEL)
    # Stair from the jetty up the rock to the plinth (road side), with railings.
    sy, w = -1.6, 0.6
    foot, head = Vector((-9.6, sy, 0.6)), Vector((-3.2, sy, top + 0.4))
    steps = 13
    for i in range(steps):
        p = foot.lerp(head, (i + 0.5) / steps)
        m.box((0.42, 2 * w, 0.06), (p.x, p.y, p.z), STEEL, bevel=False)
    for side in (-1, 1):
        a, b = foot + Vector((0, side * w, -0.15)), head + Vector((0, side * w, -0.15))
        m.box(((b - a).length, 0.06, 0.24), (a + b) / 2, STEEL, rot=(0, -math.atan2(b.z - a.z, b.x - a.x), 0))
        railing(m, [foot + Vector((0, side * (w + 0.04), 0)), head + Vector((0, side * (w + 0.04), 0))], STEEL,
                h=1.0, every=1.4)
    # The floating jetty, with bollards and coral fenders.
    m.box((2.6, 4.6, 0.45), (-11.0, sy, 0.12), STEEL)
    for y in (sy - 1.6, sy + 1.6):
        m.cyl(0.14, 0.12, 0.4, (-11.9, y, 0.55), STEEL, segs=12)
        m.cyl(0.2, 0.2, 0.9, (-12.35, y, 0.1), CORAL, segs=12, rot=(0, 0, 0))
    return m.finish()


def _leg_band(m, x, y, r, z0, z1, mat=None):
    tube(m, (x, y, z0), (x, y, z1), r + 0.03, mat or CORAL)


def habitat():
    """A floating habitat out at sea: a hexagonal deck on six column legs with coral waterline bands and
    cross-bracing; two stacked modules facing the road (-X) with framed lit windows, a door, ladder and roof
    plant; a glass dome with ribs and a glazed band; a raised helipad with its circle, H and edge lights; a
    lattice-boom deck crane; a pipe rack; a gangway with railings down to a boat landing; a railing round
    the deck and a comms mast with a blinker."""
    m = Prop("habitat")
    deck = 3.4  # deck top, above the waterline
    rad = 9.0  # hexagon's corner radius
    apo = rad * math.cos(math.pi / 6)
    legs = [(math.cos(k * math.pi / 3) * 6.4, math.sin(k * math.pi / 3) * 6.4) for k in range(6)]
    for x, y in legs:
        m.cyl(0.95, 0.95, deck - 0.6 + 1.6, (x, y, (deck - 0.6 - 1.6) / 2), HULL, segs=12)
        _leg_band(m, x, y, 0.95, -0.3, 0.45)
    for k in range(6):
        (ax, ay), (bx, by) = legs[k], legs[(k + 1) % 6]
        tube(m, (ax, ay, 0.9), (bx, by, 0.9), 0.17, STEEL)
        tube(m, (ax, ay, 0.9), (bx, by, deck - 0.8), 0.12, STEEL)
        tube(m, (bx, by, 0.9), (ax, ay, deck - 0.8), 0.12, STEEL)
        tube(m, (ax, ay, 0.9), (0, 0, 0.9), 0.14, STEEL)
    m.cyl(1.2, 1.2, deck - 0.8 + 1.6, (0, 0, (deck - 0.8 - 1.6) / 2), HULL, segs=12)
    # Deck: a hexagon turned so one face looks at the road, a coral fascia, lights at the corners.
    m.cyl(rad, rad, 0.7, (0, 0, deck - 0.35), HULL, segs=6, rot=(0, 0, math.pi / 6))
    m.cyl(rad + 0.12, rad + 0.12, 0.22, (0, 0, deck - 0.5), CORAL, segs=6, rot=(0, 0, math.pi / 6))
    corners = [(math.cos(math.pi / 6 + k * math.pi / 3) * (rad - 0.35), math.sin(math.pi / 6 + k * math.pi / 3) * (rad - 0.35))
               for k in range(7)]
    for x, y in corners[:6]:
        m.box((0.3, 0.3, 0.22), (x, y, deck + 0.11), PORT, bevel=False)
    # Deck railing, open on the road face where the gangway leaves.
    for k in range(6):
        a, b = Vector((*corners[k], deck)), Vector((*corners[k + 1], deck))
        if abs((a + b).x / 2 + apo - 0.35) < 0.5:  # the face toward -X
            mid = (a + b) / 2
            gap = (b - a).normalized() * 0.95
            railing(m, [a, mid - gap], STEEL, every=2.2)
            railing(m, [mid + gap, b], STEEL, every=2.2)
        else:
            railing(m, [a, b], STEEL, every=2.2)
    # Modules: lower and upper, plated, a coral belt, framed windows toward the road.
    lx, ly = -3.4, -2.6
    m.box((4.2, 6.0, 2.8), (lx, ly, deck + 1.4), HULL_LIGHT)
    m.box((4.3, 6.1, 0.18), (lx, ly, deck + 2.0), CORAL)
    m.box((4.5, 6.3, 0.16), (lx, ly, deck + 2.88), HULL)
    for y in (ly - 1.9, ly, ly + 1.9):
        window(m, (lx - 2.1, y, deck + 1.25), math.pi, 1.2, 0.7, mullions=1)
    window(m, (lx + 0.6, ly - 3.0, deck + 1.25), -math.pi / 2, 1.4, 0.7, mullions=1)
    door(m, (lx + 1.2, ly + 3.0, deck), math.pi / 2, 1.0, 2.0)
    ux, uy = -3.2, -2.9
    m.box((3.0, 4.2, 2.2), (ux, uy, deck + 3.98), HULL_LIGHT)
    m.box((3.3, 4.5, 0.16), (ux, uy, deck + 5.16), CORAL)
    for y in (uy - 1.0, uy + 1.0):
        window(m, (ux - 1.5, y, deck + 4.05), math.pi, 1.1, 0.6)
    # Roof plant: an air handler with a fan ring, two vents; a railing round the lower roof.
    m.box((1.4, 1.0, 0.6), (ux + 0.5, uy - 1.2, deck + 5.54), STEEL)
    tube(m, (ux + 0.5, uy + 0.6, deck + 5.24), (ux + 0.5, uy + 0.6, deck + 5.6), 0.45, STEEL)
    for dy in (-0.6, 0.6):
        tube(m, (ux - 0.8, uy + dy, deck + 5.24), (ux - 0.8, uy + dy, deck + 5.7), 0.12, STEEL, caps=True)
    roof = deck + 2.96
    railing(m, [(lx - 2.0, ly - 2.9, roof), (lx - 2.0, ly + 2.9, roof), (lx + 2.0, ly + 2.9, roof)], STEEL, every=1.5)
    ladder(m, (lx + 1.6, ly - 3.08, deck + 0.05), (lx + 1.6, ly - 3.08, roof + 1.0), (1, 0, 0), STEEL)
    # The dome: glass on a plated ring wall, ribs over it, a glazed band with bars round its foot.
    dx, dy, dr = 2.9, 1.0, 4.0
    tube(m, (dx, dy, deck), (dx, dy, deck + 1.2), dr, HULL_LIGHT, segs=16)
    tube(m, (dx, dy, deck + 1.2), (dx, dy, deck + 2.0), dr, WINDOW, segs=16)
    tube(m, (dx, dy, deck + 2.0), (dx, dy, deck + 2.25), dr + 0.05, STEEL, segs=16)
    m.blob(dr, (dx, dy, deck + 2.2), GLASS, subdiv=2, jitter=0.0, squash=0.72)
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = Vector((dx + math.cos(a) * (dr + 0.06), dy + math.sin(a) * (dr + 0.06), deck + 1.2))
        tube(m, p, p + Vector((0, 0, 0.82)), 0.05, STEEL)
    for k in range(8):
        a = 2 * math.pi * k / 8
        prev = None
        for i in range(5):
            el = math.pi / 2 * i / 4
            p = Vector((dx + math.cos(a) * math.cos(el) * (dr + 0.06), dy + math.sin(a) * math.cos(el) * (dr + 0.06),
                        deck + 2.2 + math.sin(el) * dr * 0.72 + 0.05))
            if prev is not None:
                tube(m, prev, p, 0.06, STEEL)
            prev = p
    # Helipad: raised on struts, a coral edge, painted circle and H, edge lights.
    px, py, pr = -3.2, 4.7, 3.0
    pz = deck + 0.8
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        tube(m, (px + math.cos(a) * 1.8, py + math.sin(a) * 1.8, deck), (px + math.cos(a) * 2.0, py + math.sin(a) * 2.0, pz - 0.1),
             0.1, STEEL)
    m.cyl(pr, pr, 0.18, (px, py, pz - 0.09), HULL, segs=16)
    tube(m, (px, py, pz - 0.22), (px, py, pz + 0.02), pr + 0.04, CORAL, segs=16)
    annulus(m, px, py, pz + 0.008, 2.1, 2.35, HULL_LIGHT, segs=20)
    for qx, qy, w, h in ((-0.45, 0.0, 0.22, 1.5), (0.45, 0.0, 0.22, 1.5), (0.0, 0.0, 0.7, 0.2)):
        facet(m, [(px + qx - w / 2, py + qy - h / 2, pz + 0.01), (px + qx + w / 2, py + qy - h / 2, pz + 0.01),
                  (px + qx + w / 2, py + qy + h / 2, pz + 0.01), (px + qx - w / 2, py + qy + h / 2, pz + 0.01)],
              HULL_LIGHT, out=(0, 0, 1))
    for k in range(10):
        a = 2 * math.pi * k / 10
        stud(m, (px + math.cos(a) * (pr - 0.18), py + math.sin(a) * (pr - 0.18), pz + 0.005), (0, 0, 1), 0.12, PORT)
    # Deck crane: pedestal, slewing house, lattice boom, hook on its fall.
    cx, cy = 5.0, -4.3
    m.cyl(0.6, 0.5, 2.2, (cx, cy, deck + 1.1), CORAL, segs=12)
    m.box((1.8, 1.3, 1.1), (cx, cy, deck + 2.75), CORAL)
    m.box((0.5, 1.2, 0.5), (cx + 0.6, cy, deck + 2.55), STEEL)
    root, tip = Vector((cx - 0.5, cy, deck + 3.0)), Vector((cx - 5.2, cy - 2.2, deck + 8.6))
    along = (tip - root).normalized()
    side = along.cross(Vector((0, 0, 1))).normalized() * 0.32
    lift = side.cross(along).normalized() * 0.32
    chords = [side + lift, side - lift, -side - lift, -side + lift]
    for c in chords:
        tube(m, root + c, tip + c * 0.4, 0.05, STEEL)
    for i in range(8):
        t0, t1 = i / 8, (i + 1) / 8
        for k in range(4):
            a = root.lerp(tip, t0) + chords[k] * (1 - 0.6 * t0)
            b = root.lerp(tip, t1) + chords[(k + 1) % 4] * (1 - 0.6 * t1)
            tube(m, a, b, 0.025, STEEL)
    tube(m, (cx + 0.6, cy, deck + 3.3), tip, 0.02, STEEL)
    tube(m, tip, tip - Vector((0, 0, 3.4)), 0.02, STEEL)
    m.box((0.3, 0.25, 0.4), tip - Vector((0, 0, 3.6)), CORAL)
    # Pipe rack along the -Y faces, on stands, dropping into the sea by a leg.
    rack = [Vector((-1.0, -6.9, deck + 0.45)), Vector((3.6, -6.9, deck + 0.45))]
    for off, rr, mat in ((0.0, 0.14, STEEL), (0.35, 0.1, CORAL), (0.65, 0.1, STEEL)):
        shifted = [p + Vector((0, off, 0)) for p in rack]
        for a, b in zip(shifted, shifted[1:]):
            tube(m, a, b, rr, mat)
    for x in (-0.6, 1.3, 3.2):
        m.box((0.12, 1.0, 0.45), (x, -6.6, deck + 0.22), STEEL, bevel=False)
    tube(m, rack[0], (-1.0, -8.1, deck + 0.45), 0.14, STEEL)
    tube(m, (-1.0, -8.1, deck + 0.45), (-1.0, -8.1, -0.8), 0.14, STEEL)
    # Gangway down to a boat landing on the road side.
    g0, g1 = Vector((-apo + 0.2, 0.0, deck)), Vector((-apo - 4.4, 0.0, 0.55))
    run = g1 - g0
    m.box((run.length, 1.2, 0.08), (g0 + g1) / 2, STEEL, rot=(0, -math.atan2(run.z, run.x), 0))
    for s in (-0.62, 0.62):
        railing(m, [g0 + Vector((0, s, 0)), g1 + Vector((0, s, 0))], STEEL, h=1.0, every=1.3)
    m.box((2.6, 4.2, 0.5), (g1.x - 1.0, 0.0, 0.2), HULL)
    for y in (-1.7, 1.7):
        m.cyl(0.14, 0.12, 0.4, (g1.x - 2.0, y, 0.6), STEEL, segs=12)
    # Comms mast with a dish and the blinker.
    mx, my = 6.4, 4.4
    tube(m, (mx, my, deck), (mx, my, deck + 10.0), 0.14, STEEL, r2=0.08)
    for z in (deck + 3.0, deck + 6.0):
        tube(m, (mx, my - 0.7, z), (mx, my + 0.7, z), 0.04, STEEL)
    m.cyl(0.9, 0.15, 0.35, (mx - 0.3, my, deck + 7.6), HULL_LIGHT, segs=14, rot=(0, math.radians(90), 0))
    m.blob(0.25, (mx, my, deck + 10.3), BLINK, subdiv=1, jitter=0.0)
    return m.finish()


def platform():
    """A small platform moored to the shore: a grated catwalk with railings and lamp posts, on braced
    stilts, from a landing at the road's lip down over the ice and out to a round deck on braced legs.
    Pipes run under the catwalk to it. On the deck a plated module with framed lit windows and a door, a
    radome, a davit crane, bollards and a mast with a blinker."""
    m = Prop("platform")
    road = ROAD - 0.05
    deck = 1.8
    w = 0.8
    path = [Vector((-0.4, 0.0, road)), Vector((1.6, 0.0, road)), Vector((12.0, 0.0, deck)), Vector((38.4, 0.0, deck))]
    for a, b in zip(path, path[1:]):
        run = b - a
        pitch = math.atan2(run.z, run.x)
        mid = (a + b) / 2
        m.box((run.length, 2 * w, 0.1), mid, WALKWAY, rot=(0, -pitch, 0))
        for s in (-1, 1):
            m.box((run.length, 0.06, 0.26), mid + Vector((0, s * (w - 0.03), -0.15)), STEEL, rot=(0, -pitch, 0))
    for s in (-1, 1):
        railing(m, [p + Vector((0, s * w, 0.05)) for p in path], STEEL, h=1.05, every=1.8)
    # Pipes under the catwalk's sea side, clamped to its stringer.
    for off, rr, mat in ((1.0, 0.11, CORAL), (1.3, 0.08, STEEL)):
        pts = [p + Vector((0, off, -0.35)) for p in path]
        for a, b in zip(pts, pts[1:]):
            tube(m, a, b, rr, mat)
    for x in (6.0, 14.0, 20.0, 26.0, 32.0):
        z = road + (deck - road) * min(1.0, max(0.0, (x - 1.6) / 10.4))
        m.box((0.1, 0.62, 0.08), (x, w + 0.3, z - 0.3), STEEL, bevel=False)
    # Stilts: on the ice under the ramp, then in the water, each pair cross-braced, coral at the waterline.
    for x, foot in ((6.0, 1.9), (10.0, -1.4), (14.0, -1.5), (20.0, -1.5), (26.0, -1.5), (32.0, -1.5)):
        z = road + (deck - road) * min(1.0, max(0.0, (x - 1.6) / 10.4)) - 0.2
        for s in (-1, 1):
            tube(m, (x, s * w, foot), (x, s * w, z), 0.15, STEEL)
            if foot < 0:
                _leg_band(m, x, s * w, 0.15, -0.25, 0.35)
        lo = max(foot, 0.2)
        tube(m, (x, -w, lo), (x, w, z - 0.1), 0.06, STEEL)
        tube(m, (x, w, lo), (x, -w, z - 0.1), 0.06, STEEL)
    # Lamp posts on the land side of the catwalk.
    for x in (8.0, 18.0, 28.0):
        z = road + (deck - road) * min(1.0, max(0.0, (x - 1.6) / 10.4))
        tube(m, (x, -w - 0.05, z), (x, -w - 0.05, z + 2.3), 0.05, STEEL)
        tube(m, (x, -w - 0.05, z + 2.3), (x, -w + 0.4, z + 2.45), 0.04, STEEL)
        m.box((0.3, 0.3, 0.12), (x, -w + 0.45, z + 2.42), STEEL)
        m.box((0.22, 0.22, 0.04), (x, -w + 0.45, z + 2.35), PORT, bevel=False)
    # The round deck on four braced legs.
    cx = 44.0
    m.cyl(6.0, 6.0, 0.6, (cx, 0, deck - 0.3), HULL, segs=16)
    tube(m, (cx, 0, deck - 0.62), (cx, 0, deck - 0.4), 6.12, CORAL, segs=16)
    legs = [(cx + math.cos(a) * 4.2, math.sin(a) * 4.2) for a in (math.pi / 4 + k * math.pi / 2 for k in range(4))]
    for x, y in legs:
        m.cyl(0.85, 0.85, deck + 1.0, (x, y, (deck - 1.6) / 2), HULL, segs=12)
        _leg_band(m, x, y, 0.85, -0.3, 0.4)
    for k in range(4):
        (ax, ay), (bx, by) = legs[k], legs[(k + 1) % 4]
        tube(m, (ax, ay, 0.5), (bx, by, 0.5), 0.12, STEEL)
        tube(m, (ax, ay, 0.5), (bx, by, deck - 0.6), 0.09, STEEL)
    rail_pts = [(cx + math.cos(a) * 5.8, math.sin(a) * 5.8, deck)
                for a in (math.pi + 0.2 + i * (2 * math.pi - 0.4) / 14 for i in range(15))]
    railing(m, rail_pts, STEEL, every=1e9)
    # The module, facing the catwalk and the road.
    mx, my = cx - 1.2, -1.4
    m.box((4.0, 5.0, 2.6), (mx, my, deck + 1.3), HULL_LIGHT)
    m.box((4.1, 5.1, 0.16), (mx, my, deck + 1.9), CORAL)
    m.box((4.3, 5.3, 0.16), (mx, my, deck + 2.68), HULL)
    for y in (my - 1.5, my + 0.1):
        window(m, (mx - 2.0, y, deck + 1.2), math.pi, 1.0, 0.65, mullions=1)
    door(m, (mx - 2.0, my + 1.75, deck), math.pi, 0.9, 2.0)
    window(m, (mx + 0.2, my - 2.5, deck + 1.2), -math.pi / 2, 1.4, 0.65, mullions=1)
    m.box((1.2, 1.4, 0.5), (mx + 0.8, my - 1.0, deck + 3.01), STEEL)
    tube(m, (mx - 0.8, my + 1.4, deck + 2.76), (mx - 0.8, my + 1.4, deck + 3.2), 0.3, STEEL)
    # Radome on its drum.
    rx, ry = cx + 2.4, 2.6
    tube(m, (rx, ry, deck), (rx, ry, deck + 1.1), 1.4, HULL_LIGHT, segs=14)
    m.blob(1.75, (rx, ry, deck + 1.9), HULL_LIGHT, subdiv=2, jitter=0.0)
    # Davit crane on the sea side: post, arm, brace, hook.
    dx, dy = cx + 4.6, -2.4
    tube(m, (dx, dy, deck), (dx, dy, deck + 3.4), 0.16, CORAL)
    tube(m, (dx, dy, deck + 3.3), (dx + 2.2, dy - 0.6, deck + 3.6), 0.12, CORAL)
    tube(m, (dx, dy, deck + 1.8), (dx + 1.4, dy - 0.38, deck + 3.45), 0.07, CORAL)
    tube(m, (dx + 2.2, dy - 0.6, deck + 3.55), (dx + 2.2, dy - 0.6, deck + 1.6), 0.015, STEEL)
    m.box((0.22, 0.18, 0.3), (dx + 2.2, dy - 0.6, deck + 1.45), STEEL)
    for a in (math.pi * 0.75, math.pi * 1.25, 0.3):
        m.cyl(0.16, 0.13, 0.42, (cx + math.cos(a) * 5.2, math.sin(a) * 5.2, deck + 0.21), STEEL, segs=12)
    # Mast and blinker.
    tube(m, (cx + 3.4, 1.6 - 4.4, deck), (cx + 3.4, 1.6 - 4.4, deck + 5.2), 0.09, STEEL, r2=0.05)
    tube(m, (cx + 3.4, 1.0 - 4.4, deck + 4.2), (cx + 3.4, 2.2 - 4.4, deck + 4.2), 0.03, STEEL)
    m.blob(0.22, (cx + 3.4, 1.6 - 4.4, deck + 5.42), BLINK, subdiv=1, jitter=0.0)
    return m.finish()


def buoy():
    """A marker buoy riding the swell: a coral float with a light band at the waterline and a fender, a
    deck, a lattice cage carrying solar panels, a radar reflector and the lamp (blinked by the world
    script), and a boarding ladder down its side into the water."""
    m = Prop("buoy")
    m.cyl(1.25, 1.25, 1.5, (0, 0, -0.15), CORAL, segs=12)
    m.cyl(0.6, 1.25, 0.6, (0, 0, -1.2), CORAL, segs=12)
    tube(m, (0, 0, -0.2), (0, 0, 0.25), 1.28, HULL_LIGHT)
    fender = [(math.cos(2 * math.pi * k / 12) * 1.3, math.sin(2 * math.pi * k / 12) * 1.3, 0.48) for k in range(13)]
    for a, b in zip(fender, fender[1:]):
        tube(m, a, b, 0.09, HULL)
    m.cyl(1.3, 1.3, 0.1, (0, 0, 0.65), STEEL, segs=12)
    z0, z1 = 0.7, 3.3

    def leg(k, z):
        t = (z - z0) / (z1 - z0)
        rad = 0.95 - 0.55 * t
        a = math.pi / 4 + k * math.pi / 2
        return Vector((math.cos(a) * rad, math.sin(a) * rad, z))

    for k in range(4):
        tube(m, leg(k, z0), leg(k, z1), 0.05, STEEL)
    levels = [z0 + 0.05, 1.6, 2.5, z1]
    for i, z in enumerate(levels):
        for k in range(4):
            tube(m, leg(k, z), leg((k + 1) % 4, z), 0.03, STEEL)
            if i + 1 < len(levels):
                tube(m, leg(k, z), leg((k + 1) % 4, levels[i + 1]), 0.022, STEEL)
    for k in range(3):
        a = math.pi + (k - 1) * 2 * math.pi / 3
        m.box((0.04, 0.55, 0.42), (math.cos(a) * 0.62, math.sin(a) * 0.62, 2.05), HULL, rot=(0, 0.35, a))
    m.blob(0.3, (0, 0, 1.6), STEEL, subdiv=0, jitter=0.0, squash=1.3)
    m.cyl(0.42, 0.42, 0.08, (0, 0, z1 + 0.04), STEEL, segs=12)
    m.cyl(0.18, 0.18, 0.3, (0, 0, z1 + 0.23), STEEL, segs=12)
    m.blob(0.22, (0, 0, z1 + 0.55), BLINK, subdiv=1, jitter=0.0)
    tube(m, (0, 0, z1 + 0.75), (0, 0, z1 + 1.4), 0.02, STEEL)
    ladder(m, (-1.36, 0, -0.6), (-1.36, 0, 0.7), (0, 1, 0), STEEL, width=0.4, spacing=0.3)
    tube(m, (-1.36, -0.2, 0.7), (-1.0, -0.2, 1.3), 0.025, STEEL)
    tube(m, (-1.36, 0.2, 0.7), (-1.0, 0.2, 1.3), 0.025, STEEL)
    annulus(m, 0, 0, 0.03, 1.38, 2.1, SLUSH, segs=12)
    return m.finish()


# ---------------------------------------------------------------- the land

CLIFF = (ICE, ICE, ICE_LIGHT, ICE_DEEP, ICE)


def _talus(m, spread, count, seed, side=-1.0):
    """Scree at a cliff's foot, mostly on the road side: faceted rock and ice, frost on top."""
    r = random.Random(seed)
    for b in range(count):
        a = math.pi + side * 0.0 + r.uniform(-1.3, 1.3) if side else r.uniform(0, 2 * math.pi)
        d = spread * r.uniform(0.9, 1.25)
        s = r.uniform(0.4, 1.1)
        chunk(m, (math.cos(a) * d, math.sin(a) * d, s * 0.25), (s * 1.2, s, s * 0.75), seed * 40 + b,
              mats=lambda c, up, rr: ROCK if rr.random() < 0.55 else ICE, top=FROST, yaw=r.uniform(0, 6.3), n=10)


def cliff_a():
    """An ice crag in strata on a rock foot: a tall fractured spire with two shoulders, frosted ledges, glowing
    fractures and scree at its foot."""
    m = Prop("cliff_a")
    spire(m, 0, 0, -0.6, strata(6.0, 1.3, 14.6, 8, 31), 31, segs=15, jit=0.32, band=bands(31, CLIFF, rock=1), cleft=3,
          apex=1.6, lean=(0.04, 0.03), seracs=5)
    spire(m, 1.5, 6.5, -0.6, strata(4.6, 1.0, 7.8, 5, 32), 32, segs=12, jit=0.32, band=bands(32, CLIFF, rock=1), cleft=1,
          apex=0.9, seracs=2)
    spire(m, 2.0, -6.0, -0.6, strata(4.0, 0.9, 6.2, 4, 33), 33, segs=11, jit=0.3, band=bands(33, CLIFF, rock=1), cleft=1,
          apex=0.7, seracs=1)
    _talus(m, 6.4, 9, 34)
    return m.finish()


def cliff_b():
    """A wide ice wall in strata."""
    m = Prop("cliff_b")
    spire(m, 0, 0, -0.6, strata(7.5, 2.4, 10.0, 6, 37), 37, segs=16, jit=0.28, band=bands(37, CLIFF, rock=1), cleft=3,
          apex=1.0, seracs=5)
    spire(m, 3.5, 5.5, -0.6, strata(5.0, 1.4, 11.2, 6, 38), 38, segs=13, jit=0.3, band=bands(38, CLIFF, rock=1), cleft=2,
          apex=1.1, lean=(-0.03, 0.04), seracs=3)
    _talus(m, 7.6, 10, 39)
    return m.finish()


def cliff_c():
    """A tall ice spire with a low shoulder."""
    m = Prop("cliff_c")
    spire(m, 0, 0, -0.6, strata(4.4, 0.6, 18.8, 9, 41, step=0.12), 41, segs=13, jit=0.3,
          band=bands(41, CLIFF, rock=1), cleft=2, apex=1.5, lean=(0.03, -0.04), seracs=4)
    spire(m, 2.5, 4.0, -0.6, strata(3.6, 0.8, 7.2, 4, 42), 42, segs=11, jit=0.32, band=bands(42, CLIFF, rock=1), apex=0.7,
          seracs=1)
    _talus(m, 4.8, 7, 43)
    return m.finish()


def shelf():
    """A terraced ice shelf, long along the road and narrow across it, three tiers high, each tier in strata
    with glowing fractures, seracs breaking off its edges."""
    m = Prop("shelf")
    # Ragged and leaning: with neat outlines and sheer sides the tiers read as a ship's decks.
    spire(m, 0.0, 0.0, -0.6, strata(6.5, 5.3, 3.4, 3, 91, step=0.06), 91, segs=28, jit=0.15,
          band=bands(91, CLIFF), cap=FROST, cleft=4, aspect=3.1, dip=0.03, wander=0.03, seracs=3)
    spire(m, 1.2, -2.0, 2.6, strata(4.6, 3.4, 2.8, 2, 92, step=0.06), 92, segs=22, jit=0.15,
          band=bands(92, CLIFF), cap=FROST, cleft=3, aspect=3.0, dip=0.03, wander=0.03, seracs=2)
    spire(m, 2.0, -4.5, 5.2, strata(2.8, 1.9, 2.0, 1, 93), 93, segs=14, jit=0.17, band=bands(93, CLIFF), cap=FROST,
          aspect=2.5, dip=0.03)
    r = random.Random(94)
    for b in range(8):
        y = r.uniform(-17.0, 15.0)
        tier_x = -5.6 if b % 2 else -3.6 + 1.2
        z = 2.8 if b % 2 else 5.4
        s = r.uniform(0.5, 1.0)
        chunk(m, (tier_x + r.uniform(-0.3, 0.3), y, z + s * 0.4), (s, s * 1.3, s), 940 + b, mats=ICE_LIGHT, top=FROST,
              yaw=r.uniform(0, 6.3), tilt=r.uniform(-0.3, 0.3), box=True)
    return m.finish()


def mast():
    """A lattice antenna mast on three concrete footings: tubular legs and X-bracing, coral bands near the
    top for aircraft, two railed platforms, a ladder up one leg, a big dish facing the road, a small dish,
    sector antennas, blinkers and a lightning rod; at its foot a relay hut with a framed lit window toward
    the road (-X), a door, an air-con unit, and a cable bridge across to the tower."""
    m = Prop("mast")
    height = 26.0
    feet = [(math.cos(k * 2 * math.pi / 3), math.sin(k * 2 * math.pi / 3)) for k in range(3)]

    def leg(k, z):
        rad = 1.6 - 1.2 * z / height
        return Vector((feet[k][0] * rad, feet[k][1] * rad, z))

    for k in range(3):
        m.cyl(0.5, 0.4, 0.5, (*leg(k, 0)[:2], 0.05), CONCRETE, segs=8)
        m.box((0.4, 0.4, 0.04), (*leg(k, 0)[:2], 0.32), STEEL)
        tube(m, leg(k, 0.3), leg(k, height * 0.78), 0.1, STEEL)
        tube(m, leg(k, height * 0.78), leg(k, height), 0.09, CORAL)
    levels = [0.3 + i * 2.6 for i in range(10)]
    for i, z in enumerate(levels):
        hi = levels[i + 1] if i + 1 < len(levels) else height
        mat = CORAL if z > height * 0.77 else STEEL
        for k in range(3):
            k1 = (k + 1) % 3
            tube(m, leg(k, z), leg(k1, z), 0.04, mat)
            tube(m, leg(k, z), leg(k1, hi), 0.03, mat)
            tube(m, leg(k1, z), leg(k, hi), 0.03, mat)
    for zp in (13.3, 21.1):
        tri = [leg(k, zp) * 1.0 for k in range(3)]
        centre = Vector((0, 0, zp))
        outer = [centre + (p - centre) * 1.7 for p in tri]
        prism_z(m, [(p.x, p.y) for p in outer], zp - 0.08, zp, STEEL)
        railing(m, outer + [outer[0]], STEEL, h=1.0, every=1.2)
    ladder(m, leg(0, 0.4) + Vector((0.18, 0, 0)), leg(0, height * 0.8) + Vector((0.18, 0, 0)), (0, 1, 0), STEEL,
           width=0.4, spacing=0.5)
    # Big dish toward the road, on a mount with its feed on three struts.
    dc = Vector((-1.5, 0.0, 16.5))
    tube(m, leg(1, 16.5), dc + Vector((0.3, 0, 0)), 0.06, STEEL)
    tube(m, leg(2, 16.5), dc + Vector((0.3, 0, 0)), 0.06, STEEL)
    m.cyl(1.8, 0.3, 0.55, dc, HULL_LIGHT, segs=16, rot=(0, math.radians(90), 0))
    feed = dc + Vector((-1.6, 0, 0))
    for k in range(3):
        a = k * 2 * math.pi / 3
        tube(m, dc + Vector((-0.3, math.cos(a) * 1.6, math.sin(a) * 1.6)), feed, 0.02, STEEL)
    m.box((0.3, 0.2, 0.2), feed, STEEL)
    # Small dish facing along the road.
    sd = leg(1, 20.5) + Vector((0.2, 0.7, 0))
    m.cyl(0.8, 0.15, 0.3, sd, HULL_LIGHT, segs=14, rot=(math.radians(-90), 0, 0))
    # Sector antennas round the top section.
    for k in range(3):
        p = leg(k, 23.8)
        out = Vector((p.x, p.y, 0)).normalized() * 0.35
        m.box((0.12, 0.3, 1.4), p + out, HULL_LIGHT, rot=(0, 0, math.atan2(out.y, out.x)))
    tube(m, (0, 0, height - 0.2), (0, 0, height + 2.0), 0.04, STEEL, r2=0.015)
    m.blob(0.25, (0, 0, height + 0.25), BLINK, subdiv=1, jitter=0.0)
    m.blob(0.18, leg(0, 15.0) + Vector((0.1, 0, 0)), BLINK, subdiv=1, jitter=0.0)
    # The relay hut on its slab.
    hx = -3.8
    m.box((3.4, 4.0, 0.25), (hx, 0, 0.05), CONCRETE)
    m.box((3.0, 3.6, 2.4), (hx, 0, 1.38), HULL_LIGHT)
    m.box((3.3, 3.9, 0.16), (hx, 0, 2.62), CORAL)
    m.box((3.0, 3.6, 0.1), (hx, 0, 2.75), HULL)
    window(m, (hx - 1.5, 0.6, 1.6), math.pi, 0.9, 0.6, mullions=1)
    door(m, (hx + 0.3, -1.8, 0.18), -math.pi / 2, 0.9, 2.0)
    m.box((0.6, 1.0, 0.8), (hx - 0.4, 2.1, 0.6), STEEL)
    tube(m, (hx - 0.71, 2.1, 0.6), (hx - 0.74, 2.1, 0.6), 0.34, HULL)
    tube(m, (hx + 1.0, -1.0, 2.8), (hx + 1.0, -1.0, 3.2), 0.12, STEEL, caps=True)
    # Cable bridge from the hut wall to the tower, on two posts.
    bridge_a, bridge_b = Vector((hx + 1.5, 0.0, 2.2)), Vector((-0.9, 0.0, 2.2))
    m.box(((bridge_b - bridge_a).length, 0.4, 0.08), (bridge_a + bridge_b) / 2, STEEL)
    for x in (hx + 2.0, -1.2):
        tube(m, (x, 0, 0.0), (x, 0, 2.15), 0.05, STEEL)
    return m.finish()


def geyser():
    """A cryo-geyser vent: a terraced cone of ice in strata, frost on its ledges, cracks running down it lit from inside, a rimmed throat dropping to a glow; ejecta blocks
    round it. The world script erupts a plume from VENT_HEIGHT now and then."""
    m = Prop("geyser")
    rings = spire(m, 0, 0, -0.5, strata(4.6, 1.5, VENT_HEIGHT + 0.5, 4, 71, step=0.14, ledge=0.1), 71, segs=16,
                  jit=0.18, band=bands(71, (ICE, ICE_LIGHT, ICE, ICE_DEEP)), cleft=3, cleft_mats=(ICE_DEEP,),
                  dip=0.0, warp=0.14, wander=0.04, seracs=2)
    top = rings[-1]
    centre = sum(top, Vector()) / len(top)
    lip = [centre + (p - centre) * 0.62 + Vector((0, 0, 0.12)) for p in top]
    throat = [centre + (p - centre) * 0.42 - Vector((0, 0, 1.1)) for p in top]
    n = len(top)
    for s in range(n):
        s1 = (s + 1) % n
        facet(m, [top[s], top[s1], lip[s1], lip[s]], FROST)
        facet(m, [lip[s], lip[s1], throat[s1], throat[s]], ROCK if s % 3 else ICE_DEEP)
    facet(m, throat, VEIN)
    r = random.Random(72)
    for b in range(7):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(4.6, 6.2)
        s = r.uniform(0.3, 0.7)
        chunk(m, (math.cos(a) * d, math.sin(a) * d, s * 0.2), (s * 1.2, s, s * 0.7), 720 + b, mats=ICE_LIGHT,
              top=FROST, yaw=r.uniform(0, 6.3), n=9)
    return m.finish()


def shard():
    """A cluster of ice crystals on a frost mound: hexagonal prisms with pyramid tips, every facet flat.
    Scattered by the thousand, so it is kept to a couple of hundred triangles."""
    m = Prop("shard")
    r = random.Random(303)
    chunk(m, (0, 0, -0.02), (0.55, 0.45, 0.16), 304, mats=FROST, n=9)
    for k in range(5):
        x, y = r.uniform(-0.3, 0.3), r.uniform(-0.25, 0.25)
        length = r.uniform(0.35, 1.05) * (1.0 if k else 1.25)
        rad = r.uniform(0.045, 0.085)
        axis = Vector((r.uniform(-0.45, 0.45), r.uniform(-0.45, 0.45), 1.0)).normalized()
        base = Vector((x, y, 0.02))
        u = axis.cross(Vector((0, 0, 1))).normalized() if abs(axis.z) < 0.999 else Vector((1, 0, 0))
        v = axis.cross(u)
        mat = ICE_LIGHT if r.random() < 0.6 else ICE
        lo = [base + (u * math.cos(t) + v * math.sin(t)) * rad for t in (i * math.pi / 3 for i in range(6))]
        hi = [p + axis * length * 0.72 for p in lo]
        tip = base + axis * length
        for i in range(6):
            i1 = (i + 1) % 6
            facet(m, [lo[i], lo[i1], hi[i1], hi[i]], mat)
            facet(m, [hi[i], hi[i1], tip], mat)
    return m.finish()


def boulder():
    """A frost-capped boulder: faceted rock in two dipping strata, frost on its upper faces, a chip beside it."""
    m = Prop("boulder")
    dip = Vector((0.25, 0.1, 1.0)).normalized()

    def strata_mat(c, up, rr):
        return ROCK if int((c.dot(dip) + 2.0) / 0.22) % 2 else ROCK_BAND

    chunk(m, (0, 0, 0.18), (0.62, 0.5, 0.42), 501, mats=strata_mat, top=FROST, n=14, top_cut=0.7,
          cuts=[(Vector((0, 0, z)), dip) for z in (0.0, 0.2, 0.4)])
    chunk(m, (0.62, 0.26, 0.05), (0.3, 0.24, 0.16), 502, mats=ROCK, top=FROST, n=9)
    chunk(m, (-0.5, -0.35, 0.0), (0.18, 0.15, 0.1), 503, mats=ROCK, top=FROST, n=8)
    return m.finish()


# ---------------------------------------------------------------- the player's car

def hood():
    """The player's hover-convertible from the driver's seat: dark pearl-teal paint, flush seams and louvred
    vents painted on the bonnet's slope, side panels edged with coral light lines, and two hover nacelles
    with intake grilles, side strakes and light-bar lamps at the front corners. Same footprint as the
    Backroads truck, so the keyboard framing is identical."""
    m = Prop("hood")
    w = 8.0
    # Blender +Y is down the road, so the hood runs toward -Y from the keyboard.
    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], PAINT)

    # Everything on the bonnet is flush, painted on its slope: a raised ridge in front of the keys stood up
    # into the middle lanes on the Backroads truck. Flush pieces are lone facets turned to face up.
    def on_hood(x, y, lift):
        return (x, y, (0.2 - y) / 9.2 * 0.95 + lift)

    def flush(x0, x1, y0, y1, lift, mat):
        facet(m, [on_hood(x0, y0, lift), on_hood(x1, y0, lift), on_hood(x1, y1, lift), on_hood(x0, y1, lift)], mat,
              out=(0, 0, 1))

    for side in (-1, 1):
        front, rear = side * 6.6, side * 5.4
        facet(m, [on_hood(front, 0.15, 0.008), on_hood(side * 7.98, 0.15, 0.008), on_hood(side * 7.98, -8.95, 0.008),
                  on_hood(rear, -8.95, 0.008)], PAINT_EDGE, out=(0, 0, 1))
        facet(m, [on_hood(front - 0.07, 0.12, 0.016), on_hood(front + 0.07, 0.12, 0.016),
                  on_hood(rear + 0.07, -8.92, 0.016), on_hood(rear - 0.07, -8.92, 0.016)], TRIM, out=(0, 0, 1))
        # Panel seams and a louvred vent on each side of the bonnet, all flush.
        seam = side * 3.4
        flush(seam - 0.025, seam + 0.025, -8.9, 0.1, 0.006, PAINT_EDGE)
        flush(min(side * 0.6, seam), max(side * 0.6, seam), -7.95, -7.9, 0.006, PAINT_EDGE)
        lo, hi = sorted((side * 3.9, side * 5.0))
        flush(lo, hi, -7.3, -5.3, 0.007, PAINT_EDGE)
        for i in range(6):
            y = -7.15 + i * 0.32
            flush(lo + 0.08, hi - 0.08, y, y + 0.12, 0.011, PAINT)

    # Hover nacelles where the wheels were: chamfered pods, narrower at the front, a coral line along the
    # top, an intake grille, strakes on the outer side and a light bar across the nose.
    profile = [(-0.95, -1.0), (0.95, -1.0), (0.95, 0.25), (0.55, 0.62), (-0.55, 0.62), (-0.95, 0.25)]
    for side in (-1, 1):
        x = side * (w + 0.85)
        cz = -0.2
        extrude(m, [(px, cz + pz) for px, pz in profile], -9.3, 0.32, PAINT, front_scale=0.78, cx=x)
        m.box((0.1, 9.0, 0.03), (x, -4.5, cz + 0.635), TRIM)
        m.box((1.3, 0.34, 0.22), (x, 0.42, cz + 0.12), HEADLAMP)
        m.box((1.5, 0.1, 0.36), (x, 0.3, cz + 0.12), PAINT_EDGE)
        # Intake grille: a dark well with slats across it, on the pod's top toward the rear.
        m.box((0.8, 2.2, 0.03), (x - side * 0.05, -6.6, cz + 0.62), PAINT_EDGE)
        for i in range(7):
            m.box((0.82, 0.07, 0.05), (x - side * 0.05, -7.55 + i * 0.32, cz + 0.645), PAINT)
        # Strakes along the outer flank.
        for i in range(3):
            m.box((0.05, 2.6, 0.06), (x + side * 0.97, -6.0, cz + 0.05 - i * 0.22), PAINT_EDGE)
        # Emitter glow under the pod's front.
        m.box((1.2, 1.4, 0.03), (x, -1.2, cz - 1.0), TRIM)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), PAINT_EDGE)
    m.box((w * 2 + 3.0, 0.08, 0.04), (0, 0.72, -0.93), TRIM)
    return m.finish()


export_all([barrier, bank, lightmast, marker, floe_a, floe_b, iceberg_a, iceberg_b, beacon, habitat, platform, buoy,
            cliff_a, cliff_b, cliff_c, shelf, mast, geyser, shard, boulder, hood], OUT_DIR, PREVIEW)
