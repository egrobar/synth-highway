"""Ring Road props (region id `aurora`): a skyway along an orbital ring under Saturn.

Glass skyway wall segments (they tile down both sides of the road), guide-light strips and a pipe
conduit for the deck beyond the glass, rows of solar panels, big ISS-style solar wings, observation
domes with a soft light inside, docking arms reaching out from the deck with a pod docked and
blinking lights, a distant ring station (hub, spokes and habitation ring) that the world script
hangs far off in the sky, small maintenance drones (static, hovering), and the player's transit
pod hood.

High-detail pass (2026-11-10): clean, maintained engineering rather than grime. The skyway wall
has a kerb with a recessed light channel, a glazing sill and head beam, a glass handrail on clamp
brackets, and at every joint a structural I-section mullion with a glazing cap, a bolted base
plate and gusset, a lamp, and a raking buttress to a bolted footing on the deck. The conduit
stands on H-columns with knee braces, its pipes held in split clamps on saddles, with flanged
joints, inspection hatches, a bellows and a cable tray. Solar rows have framed modules on a torque
tube, bearing yokes on pylons, actuator rams and junction boxes. The solar wings are ISS-like: a
mast with a ladder and a beta gimbal, blanket boxes, coilable lattice masts and hinged blankets.
Domes have a geodesic frame with hub nodes, a plated base ring with hatches, an airlock vestibule
and trees inside. Docking arms have a control tower with a glazed cab, a truss carrying a jetway
tube, hydraulic rams, a bolted airlock collar with guide petals and a lathed transit pod. The
station has octagonal habitation modules with window rows, collars, spokes, a lathed hub with
docking ports and docked craft. Drones have a lathed body with panel lines, a sensor head,
ducted thrusters with rotors and a tool arm.

Finish: propkit's blanket 3 cm bevel is replaced by a per-part one (Part, after Neon Sprawl and
Red Frontier): only primitives built with bevel=True (masses, plates, frames, housings) get the
3 cm two-segment bevel; fine detail (bars, bolts, struts, truss members) stays as plain boxes
with crisp edges marked sharp, at ~12 triangles instead of ~100.

Material names pick the game's surface maps (ThemeWorld.SURFACE_KEYWORDS and `surfaces` in
game/scripts/themes/aurora.gd): hull_* -> riveted panel plating, deck_plate -> small dark deck
plates, steel -> brushed metal, solar_cell -> cell grid (the grate map), foil_* -> crinkled
blanket (the membrane map), pearl (painted structure) -> almost none. Materials named glass* are
made see-through by the world script (propkit's materials are opaque), and materials named
beacon_* blink there, so the hood has neither. Avoid names that contain a keyword by accident.
Run: blender --background --python tools/themes/aurora/props.py -- game/assets/themes/aurora/models [preview.png]
"""
import math
import pathlib
import random
import sys

import bmesh
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset  # noqa: E402

WALL_LENGTH = 8.0  # must match WALL_LENGTH in game/scripts/themes/aurora.gd (one mullion per segment)
STRIP_LENGTH = 12.0  # must match STRIP_LENGTH in game/scripts/themes/aurora.gd
CONDUIT_TILE = 16.0  # must match CONDUIT_TILE in game/scripts/themes/aurora.gd
SOLAR_TILE = 16.0  # must match SOLAR_TILE in game/scripts/themes/aurora.gd (two panels)
WALL_LEAN = math.radians(14.0)  # the glass leans outward, away from the road, so it never looms over it
OUT_DIR, PREVIEW = args()
reset()

Z = Vector((0.0, 0.0, 1.0))
Y = Vector((0.0, 1.0, 0.0))
ALONG_Y = (math.radians(90), 0, 0)  # turns a cylinder's axis from Z to Y (its top end toward -Y)
TO_Y = (math.radians(-90), 0, 0)  # turns a lathe's axis from Z to +Y
ALONG_X = (0, math.radians(90), 0)  # turns a cylinder's (or a lathe's) axis from Z to +X

# Weathered (opaque) materials; the name picks the surface map in the game (see the module docstring).
HULL = material("hull_white", (0.66, 0.70, 0.70), rough=0.4, metal=0.15)
PEARL = material("pearl", (0.62, 0.66, 0.66), rough=0.32, metal=0.12)
STEEL = material("steel", (0.50, 0.53, 0.55), rough=0.28, metal=0.9)
DECK = material("deck_plate", (0.07, 0.08, 0.09), rough=0.5, metal=0.6)
FOIL = material("foil_gold", (0.55, 0.40, 0.14), rough=0.3, metal=0.9)
SOLAR = material("solar_cell", (0.02, 0.04, 0.10), rough=0.3, metal=0.35)
GLASS = material("glass", (0.55, 0.8, 0.74), rough=0.06)
DOME_GLASS = material("glass_dome", (0.6, 0.85, 0.78), rough=0.06)
# Frosted panes glow softly with the light inside the domes.
FROST = material("frost", (0.7, 0.85, 0.8), emit=(0.75, 1.0, 0.88), strength=0.5)
# Emissive palette: white and green only. Strength is HDR: above 1.0 it blooms through the glow pass.
STRIP = material("strip", (0.5, 0.9, 0.72), emit=(0.55, 1.0, 0.78), strength=1.5)
STRIP_WHITE = material("strip_white", (0.9, 1.0, 0.97), emit=(0.9, 1.0, 0.96), strength=1.8)
WINDOW = material("window", (0.85, 1.0, 0.92), emit=(0.82, 1.0, 0.9), strength=2.4)
INTERIOR = material("interior", (0.9, 0.95, 0.85), emit=(0.95, 1.0, 0.9), strength=1.3)
PLANT = material("plant", (0.1, 0.4, 0.2), emit=(0.25, 0.85, 0.45), strength=0.9)
BEACON_GREEN = material("beacon_green", (0.3, 1.0, 0.55), emit=(0.3, 1.0, 0.55), strength=7.0)
BEACON_WHITE = material("beacon_white", (1.0, 1.0, 1.0), emit=(0.95, 1.0, 1.0), strength=7.0)
DRONE_LIGHT = material("drone_light", (0.3, 1.0, 0.6), emit=(0.3, 1.0, 0.6), strength=2.5)
# The hood (never weathered, so its names pick nothing).
POD = material("pod", (0.36, 0.39, 0.4), rough=0.3, metal=0.15)
DARK = material("dark", (0.03, 0.035, 0.04), rough=0.5, metal=0.4)
TRIM = material("trim", (0.11, 0.12, 0.13), rough=0.3, metal=0.85)
LAMP = material("lamp", (0.92, 1.0, 0.97), emit=(0.9, 1.0, 0.96), strength=9.0)
# The hood's lamp-top bars and accent lines sit beside the outer keys, so they only just glow.
LAMP_BAR = material("lamp_bar", (0.5, 0.6, 0.56), emit=(0.75, 1.0, 0.86), strength=0.9)
ACCENT = material("accent", (0.1, 0.26, 0.19), emit=(0.3, 0.9, 0.58), strength=0.22)


# ---------------------------------------------------------------- kit: per-part finish and shapes

def rect(w, h=None):
    h = w if h is None else h
    return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]


def circle(r, n=8):
    return [(r * math.cos(2 * math.pi * k / n), r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def facing(n):
    """Euler angles that turn a box's local +X toward direction n, its local Z kept as upright as it can."""
    n = Vector(n).normalized()
    return (0.0, -math.asin(max(-1.0, min(1.0, n.z))), math.atan2(n.y, n.x))


class Part(Model):
    """A Model that bevels only the primitives built with bevel=True (after Neon Sprawl's Part).

    Bevelled primitives' edges get a bevel weight; finish() gives the prop its own weight-limited
    bevel (`width` metres, two segments, hardened normals) and switches propkit's all-edges bevel
    off (obj["bevel"] = 0). Every edge sharper than `crease` degrees is marked sharp, so unbevelled
    detail still shades flat under propkit's weighted normals, and cylinders and lathes of 12+
    segments stay smooth. width=0 makes a prop with no bevel at all."""

    def __init__(self, name, width=0.03, crease=35.0):
        super().__init__(name)
        self.width = width
        self.crease = math.radians(crease)
        self.weight = self.bm.edges.layers.float.new("bevel_weight_edge")
        self._last = []

    def _paint(self, verts, mat):
        super()._paint(verts, mat)
        self._last = list(verts)

    def _mark(self, verts, bevel):
        if bevel:
            for v in verts:
                for e in v.link_edges:
                    e[self.weight] = 1.0

    def mat_index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def box(self, size, loc, mat, rot=(0, 0, 0), bevel=False):
        super().box(size, loc, mat, rot)
        self._mark(self._last, bevel)

    def cyl(self, r1, r2, h, loc, mat, segs=12, rot=(0, 0, 0), bevel=False):
        super().cyl(r1, r2, h, loc, mat, segs=segs, rot=rot)
        self._mark(self._last, bevel)

    def beam(self, a, b, r, mat, segs=6, bevel=False):
        a, b = Vector(a), Vector(b)
        rot = Z.rotation_difference((b - a).normalized()).to_euler()
        self.cyl(r, r, (b - a).length, (a + b) / 2, mat, segs=segs, rot=rot, bevel=bevel)

    def poly(self, verts, faces, mat, bevel=False):
        super().poly(verts, faces, mat)
        self._mark(self._last, bevel)

    def faces(self, verts, faces, mats, bevel=False):
        """One connected surface with its own material per face."""
        vs = [self.bm.verts.new(v) for v in verts]
        for f, mat in zip(faces, mats):
            self.bm.faces.new([vs[i] for i in f]).material_index = self.mat_index(mat)
        self._mark(vs, bevel)
        return vs

    def sweep(self, path, profile, mat, closed=False, caps=True, up=(0, 0, 1), bevel=False):
        """A 2D profile (u across, v up) swept along a polyline, its frame carried round bends by
        parallel transport so round profiles never twist (after Red Frontier's Kit). Along +Y with
        the default `up`, u is +X and v is +Z."""
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
        self._mark([v for ring in rings for v in ring], bevel)

    def strut(self, a, b, w, mat, h=None, up=(0, 0, 1), caps=False, bevel=False):
        """A straight rectangular member from a to b; open-ended, as its ends hide in the joints."""
        self.sweep([a, b], rect(w, h), mat, caps=caps, up=up, bevel=bevel)

    def lathe(self, prof, loc, mat, segs=16, rot=(0, 0, 0), mats=None, closed=False, bevel=False):
        """(radius, height) points revolved round local Z; a radius of 0 closes to a pole. `mats`
        gives each band its own material; `closed` joins the last point back to the first (a ring
        with a cross-section, like a flange or a duct)."""
        mtx = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4()
        rings = []
        for r, z in prof:
            if r <= 1e-6:
                rings.append([self.bm.verts.new(mtx @ Vector((0.0, 0.0, z)))])
            else:
                rings.append([self.bm.verts.new(mtx @ Vector((r * math.cos(2 * math.pi * s / segs),
                                                              r * math.sin(2 * math.pi * s / segs), z)))
                              for s in range(segs)])
        bands = len(rings) if closed else len(rings) - 1
        for i in range(bands):
            a, b = rings[i], rings[(i + 1) % len(rings)]
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
        self._mark([v for ring in rings for v in ring], bevel)

    def finish(self):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        for e in bm.edges:
            sharp = len(e.link_faces) != 2 or e.calc_face_angle(0.0) > self.crease
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


def bolt(m, loc, normal, r=0.028, h=0.035, mat=STEEL):
    """A hex bolt head standing out of a surface along `normal`."""
    n = Vector(normal).normalized()
    m.cyl(r, r, h, Vector(loc) + n * (h / 2), mat, segs=6, rot=Z.rotation_difference(n).to_euler())


def ladder(m, foot, top, along, out, width=0.44, step=0.32, mat=PEARL, standoff_every=2.5):
    """A fixed ladder: two rails `width` apart along `along` from `foot` up to `top` (both points
    between the rails), rungs every `step`, and standoff brackets back toward -`out` every so often."""
    foot, top, al, o = Vector(foot), Vector(top), Vector(along).normalized(), Vector(out).normalized()
    for s in (-1, 1):
        m.strut(foot + al * (s * width / 2), top + al * (s * width / 2), 0.05, mat)
    rise = top - foot
    k = step
    while k < rise.length - 0.1:
        p = foot + rise.normalized() * k
        m.strut(p - al * (width / 2), p + al * (width / 2), 0.03, mat)
        k += step
    k = 0.6
    while k < rise.length:
        p = foot + rise.normalized() * k
        for s in (-1, 1):
            m.strut(p + al * (s * width / 2), p + al * (s * width / 2) - o * 0.28, 0.04, mat)
        k += standoff_every


# ---------------------------------------------------------------- the skyway wall

CL, SL = math.cos(WALL_LEAN), math.sin(WALL_LEAN)


def lean_x(z, x0=0.0):
    """Where the leaning glass plane is at height z, if its foot is at x0 at height 0.5."""
    return x0 + (z - 0.5) * math.tan(WALL_LEAN)


def glass_pt(u, z):
    """(x, z) of the point at height z that lies u metres off the glass plane (+u away from the road)."""
    s = (z - 0.5 + u * SL) / CL
    return u * CL + s * SL, z


def lean_span(m, thick, width, u, z0, z1, y, mat, bevel=False):
    """A box lying in the leaning glass plane's frame: `thick` across it, `width` along Y, reaching
    from height z0 to z1, its centre u metres off the plane (+u away from the road)."""
    s0 = (z0 - 0.5 + u * SL) / CL
    s1 = (z1 - 0.5 + u * SL) / CL
    sm = (s0 + s1) / 2
    m.box((thick, width, s1 - s0), (u * CL + sm * SL, y, 0.5 - u * SL + sm * CL), mat, rot=(0, WALL_LEAN, 0),
          bevel=bevel)


def wall():
    """One glass skyway wall segment, exactly WALL_LENGTH long, its road face toward -X: a dark kerb
    with a recessed green-white light channel, a glazing sill, a glass pane leaning outward to 3.0
    high under a white head beam, glazing bars halving the pane, and a steel handrail held off the
    glass on clamp brackets. At the segment's start (covering the joint with the next) stands a
    structural I-section mullion: flanges and web, a steel glazing cap, a capping plate, a bolted
    base plate with a gusset, a small white lamp near its top facing the road, and a raking
    buttress out to a bolted footing on the deck."""
    m = Part("wall")
    half, length = WALL_LENGTH / 2, WALL_LENGTH
    kerb = [(-0.34, 0.0), (0.55, 0.0), (0.55, 0.5), (-0.1, 0.5), (-0.1, 0.36), (-0.24, 0.36), (-0.24, 0.44),
            (-0.34, 0.44)]
    m.sweep([(0, -half, 0), (0, half, 0)], kerb, DECK, bevel=True)
    # The light lies in the kerb channel, just showing over its lip.
    m.box((0.12, length, 0.05), (-0.17, 0, 0.385), STRIP)
    lean_span(m, 0.2, length, 0.0, 0.5, 0.62, 0, PEARL, bevel=True)
    lean_span(m, 0.05, length, 0.0, 0.6, 3.0, 0, GLASS)
    lean_span(m, 0.34, length, 0.02, 2.98, 3.18, 0, PEARL, bevel=True)
    for u in (-0.045, 0.045):
        lean_span(m, 0.035, 0.07, u, 0.62, 2.98, 0.0, PEARL)
    # Handrail on brackets with round glass clamps.
    zr = 1.45
    xr = lean_x(zr) - 0.24
    m.cyl(0.042, 0.042, length, (xr, 0, zr), STEEL, segs=12, rot=ALONG_Y)
    gx, gz = glass_pt(-0.035, zr)
    for y in (-2.0, 0.0, 2.0):
        m.box((gx - xr, 0.04, 0.035), ((gx + xr) / 2, y, zr), STEEL)
        m.cyl(0.06, 0.06, 0.025, (gx, y, gz), STEEL, segs=8, rot=(0, math.pi / 2 + WALL_LEAN, 0))

    # The mullion: an I-section leaning with the glass.
    y = -half
    lean_span(m, 0.04, 0.3, -0.15, 0.6, 3.45, y, PEARL, bevel=True)
    lean_span(m, 0.26, 0.07, 0.0, 0.6, 3.45, y, PEARL)
    lean_span(m, 0.04, 0.3, 0.15, 0.6, 3.45, y, PEARL, bevel=True)
    lean_span(m, 0.025, 0.1, -0.18, 0.75, 2.85, y, STEEL)
    lean_span(m, 0.46, 0.4, 0.0, 3.43, 3.55, y, PEARL, bevel=True)
    m.box((0.64, 0.52, 0.05), (0.2, y, 0.525), STEEL, bevel=True)
    for bx in (0.31, 0.45):
        for by in (-0.19, 0.19):
            bolt(m, (bx, y + by, 0.55), Z)
    ax, _ = glass_pt(0.17, 0.55)
    cx, _ = glass_pt(0.17, 1.25)
    m.sweep([(0, y - 0.015, 0), (0, y + 0.015, 0)], [(ax, 0.55), (0.52, 0.55), (cx, 1.25)], PEARL)
    lean_span(m, 0.1, 0.22, -0.22, 2.82, 3.2, y, PEARL, bevel=True)
    lean_span(m, 0.03, 0.15, -0.28, 2.87, 3.15, y, STRIP_WHITE)
    # Raking buttress: a square tube from a clevis on the outer flange to a lug on a bolted footing.
    tx, tz = glass_pt(0.17, 1.9)
    m.box((0.14, 0.2, 0.24), (tx + 0.05, y, tz), STEEL)
    m.strut((tx + 0.08, y, tz - 0.04), (1.72, y, 0.22), 0.13, PEARL)
    m.box((0.56, 0.46, 0.05), (1.75, y, 0.025), STEEL, bevel=True)
    m.box((0.2, 0.18, 0.24), (1.75, y, 0.17), STEEL)
    for bx in (1.56, 1.94):
        for by in (-0.15, 0.15):
            bolt(m, (bx, y + by, 0.05), Z)
    return m.finish()


def light_strip():
    """A guide-light strip on the deck beyond the glass, exactly STRIP_LENGTH long: a low dark
    housing with chamfered sides and a channel holding four glowing lenses between steel clamp
    bars, and bolted anchor plates at its ends."""
    m = Part("light_strip", width=0.0)
    half = STRIP_LENGTH / 2
    housing = [(-0.3, 0.0), (0.3, 0.0), (0.24, 0.08), (0.1, 0.11), (0.1, 0.07), (-0.1, 0.07), (-0.1, 0.11),
               (-0.24, 0.08)]
    m.sweep([(0, -half, 0), (0, half, 0)], housing, DECK)
    for k in range(4):
        y = -half + (k + 0.5) * STRIP_LENGTH / 4
        m.box((0.16, 1.5, 0.05), (0, y, 0.085), STRIP)
        for s in (-1, 1):
            m.box((0.22, 0.07, 0.05), (0, y + s * 0.79, 0.1), STEEL)
    for y in (-half + 0.25, half - 0.25):
        m.box((0.78, 0.22, 0.03), (0, y, 0.015), STEEL)
        for sx in (-1, 1):
            m.box((0.05, 0.05, 0.04), (sx * 0.34, y, 0.04), STEEL)
    return m.finish()


# ---------------------------------------------------------------- the conduit

def conduit():
    """An elevated pipe conduit, exactly CONDUIT_TILE long, its road face toward -X: an H-column on
    a bolted base plate and footing with gussets, an I-beam cross-head with knee braces, two pipes
    (painted white and bare steel) in split clamps on saddles, flanged joints mid-span, inspection
    hatches, a bellows joint on the steel pipe, a cable tray hung under the cross-head, and a
    green-white light strip clipped along the road side of the white pipe."""
    m = Part("conduit")
    T = CONDUIT_TILE
    ys = -T / 2
    m.box((1.1, 1.1, 0.14), (0, ys, 0.07), DECK, bevel=True)
    m.box((0.72, 0.72, 0.05), (0, ys, 0.165), STEEL, bevel=True)
    for bx in (-0.27, 0.27):
        for by in (-0.27, 0.27):
            bolt(m, (bx, ys + by, 0.19), Z)
    h0, h1 = 0.19, 2.6
    for sx in (-1, 1):
        m.box((0.04, 0.36, h1 - h0), (sx * 0.17, ys, (h0 + h1) / 2), PEARL, bevel=True)
        m.sweep([(0, ys - 0.015, 0), (0, ys + 0.015, 0)], [(sx * 0.19, h0), (sx * 0.36, h0), (sx * 0.19, 0.62)],
                PEARL)
        m.strut((sx * 0.19, ys, 2.0), (sx * 0.95, ys, 2.6), 0.09, PEARL)
        m.box((0.03, 0.36, 0.3), (sx * 1.36, ys, 2.75), PEARL)
    m.box((0.3, 0.04, h1 - h0), (0, ys, (h0 + h1) / 2), PEARL)
    for z in (2.62, 2.88):
        m.box((2.7, 0.36, 0.04), (0, ys, z), PEARL, bevel=True)
    m.box((2.7, 0.04, 0.22), (0, ys, 2.75), PEARL)

    pipes = ((-0.65, 3.26, 0.36, PEARL, 16, 8), (0.7, 3.18, 0.28, STEEL, 12, 6))
    for px, pz, r, mat, segs, nb in pipes:
        m.cyl(r, r, T, (px, 0, pz), mat, segs=segs, rot=ALONG_Y)
        # Saddle and split clamp at the support.
        m.box((2 * r + 0.1, 0.34, 0.12), (px, ys, 2.95), STEEL)
        ring = [(px + (r + 0.02) * math.cos(2 * math.pi * k / 12), ys, pz + (r + 0.02) * math.sin(2 * math.pi * k / 12))
                for k in range(12)]
        m.sweep(ring, rect(0.1, 0.03), STEEL, closed=True)
        for sx in (-1, 1):
            m.box((0.12, 0.1, 0.06), (px + sx * (r + 0.07), ys, pz), STEEL)
            bolt(m, (px + sx * (r + 0.09), ys, pz + 0.03), Z, r=0.022, h=0.03)
        # Flanged joint mid-span, bolted on both faces.
        for sy in (-1, 1):
            m.cyl(r + 0.1, r + 0.1, 0.08, (px, sy * 0.045, pz), mat, segs=segs, rot=ALONG_Y, bevel=True)
            for k in range(nb):
                a = 2 * math.pi * (k + 0.5) / nb
                m.box((0.05, 0.05, 0.05), (px + (r + 0.055) * math.cos(a), sy * 0.1, pz + (r + 0.055) * math.sin(a)),
                      STEEL)

    def hatch(c, n, w, h):
        rot = facing(n)
        side = Y.cross(n).normalized()
        m.box((0.08, w + 0.12, h + 0.12), c, STEEL, rot=rot, bevel=True)
        m.box((0.05, w, h), c + n * 0.05, HULL, rot=rot, bevel=True)
        m.strut(c + n * 0.13 - Y * (w * 0.25), c + n * 0.13 + Y * (w * 0.25), 0.03, STEEL)
        for sy in (-1, 1):
            m.box((0.08, 0.03, 0.03), c + n * 0.1 + Y * (sy * w * 0.25), STEEL, rot=rot)
            for sw in (-1, 1):
                bolt(m, c + n * 0.075 + Y * (sy * (w / 2 - 0.05)) + side * (sw * (h / 2 - 0.05)), n, r=0.02, h=0.025)

    n = Vector((-1.0, 0.0, 1.0)).normalized()
    hatch(Vector((-0.65, 4.0, 3.26)) + n * 0.36, n, 0.58, 0.4)
    hatch(Vector((0.7, -3.5, 3.18 + 0.28)), Z, 0.5, 0.34)
    for k in range(5):
        m.cyl(0.33, 0.33, 0.06, (0.7, 5.2 + k * 0.12, 3.18), DECK, segs=12, rot=ALONG_Y)
    for y in (5.05, 5.83):
        m.cyl(0.34, 0.34, 0.1, (0.7, y, 3.18), STEEL, segs=12, rot=ALONG_Y)

    tray = [(-0.25, 0.0), (0.25, 0.0), (0.25, 0.14), (0.21, 0.14), (0.21, 0.03), (-0.21, 0.03), (-0.21, 0.14),
            (-0.25, 0.14)]
    m.sweep([(0.55, -T / 2, 2.2), (0.55, T / 2, 2.2)], tray, DECK, caps=False)
    for cx in (0.43, 0.55, 0.67):
        m.cyl(0.045, 0.045, T, (cx, 0, 2.28), DECK, segs=6, rot=ALONG_Y)
    for hx in (0.32, 0.78):
        m.strut((hx, ys, 2.6), (hx, ys, 2.2), 0.04, STEEL)
    # Light strip clipped to the white pipe's road side.
    m.box((0.06, T, 0.09), (-1.15, 0, 3.26), STRIP)
    for y in (-6.0, -2.0, 2.0, 6.0):
        m.box((0.16, 0.06, 0.12), (-1.07, y, 3.26), STEEL)
    return m.finish()


# ---------------------------------------------------------------- solar

def tilt_pt(centre, tilt, local):
    """A point in a panel's frame: `local` before the panel is tilted by `tilt` about Y."""
    lx, ly, lz = local
    c, s = math.cos(tilt), math.sin(tilt)
    return Vector((centre[0] + lx * c + lz * s, centre[1] + ly, centre[2] - lx * s + lz * c))


def tbox(m, size, local, centre, tilt, mat, bevel=False):
    m.box(size, tilt_pt(centre, tilt, local), mat, rot=(0, tilt, 0), bevel=bevel)


def solar_panel(m, centre, width, length, tilt, cols, rows, frame=STEEL, frame_bevel=True):
    """A framed solar panel: one cell sheet (the game's cell-grid map draws the cells) in an
    aluminium frame, with module bars dividing it cols x rows. Tilted about Y (a negative tilt faces
    the road, -X)."""
    tbox(m, (width, length, 0.04), (0, 0, 0), centre, tilt, SOLAR)
    for sx in (-1, 1):
        tbox(m, (0.07, length + 0.07, 0.08), (sx * width / 2, 0, 0.01), centre, tilt, frame, frame_bevel)
    for sy in (-1, 1):
        tbox(m, (width, 0.07, 0.08), (0, sy * length / 2, 0.01), centre, tilt, frame, frame_bevel)
    for i in range(1, cols):
        tbox(m, (0.04, length, 0.05), (-width / 2 + i * width / cols, 0, 0.025), centre, tilt, frame)
    for j in range(1, rows):
        tbox(m, (width, 0.04, 0.05), (0, -length / 2 + j * length / rows, 0.025), centre, tilt, frame)


def solar_row():
    """Two solar panels facing the road and the sun, exactly SOLAR_TILE long: each a framed 2 x 4
    module array on purlins and a torque tube, the tube turning in bearing yokes on two pylons (each
    on a bolted base plate and footing), a hydraulic actuator to set the tilt, and a junction box
    with its cable run."""
    m = Part("solar_row")
    tilt = -0.5
    width, length = 3.2, 7.2
    for k, yc in enumerate((-SOLAR_TILE / 4, SOLAR_TILE / 4)):
        c = (0.0, yc, 1.9)
        solar_panel(m, c, width, length, tilt, 2, 4)
        m.cyl(0.09, 0.09, length + 0.2, tilt_pt(c, tilt, (0, 0, -0.16)), STEEL, segs=12, rot=ALONG_Y)
        for yl in (-2.9, -1.0, 1.0, 2.9):
            tbox(m, (width - 0.25, 0.08, 0.1), (0, yl, -0.07), c, tilt, STEEL)
        for j, yl in enumerate((-2.6, 2.6)):
            b = tilt_pt(c, tilt, (0, yl, -0.16))
            y = yc + yl
            m.cyl(0.15, 0.15, 0.26, b, STEEL, segs=12, rot=ALONG_Y)
            for sy in (-1, 1):
                m.box((0.28, 0.03, 0.4), (b.x, y + sy * 0.15, b.z - 0.13), PEARL)
            top = b.z - 0.3
            m.box((0.34, 0.38, 0.04), (b.x, y, top + 0.02), STEEL)
            m.box((0.2, 0.2, top - 0.17), (b.x, y, (top + 0.17) / 2), PEARL, bevel=True)
            m.box((0.72, 0.72, 0.13), (b.x, y, 0.065), DECK, bevel=True)
            m.box((0.5, 0.5, 0.04), (b.x, y, 0.15), STEEL, bevel=True)
            for bx in (-0.17, 0.17):
                for by in (-0.17, 0.17):
                    m.box((0.045, 0.045, 0.04), (b.x + bx, y + by, 0.19), STEEL)
            if j == 1:
                # Actuator: a barrel from a lug on the pylon, its rod up to a lug under the panel.
                p0 = Vector((b.x + 0.13, y + 0.2, 0.75))
                p1 = tilt_pt(c, tilt, (0.95, yl + 0.2, -0.09))
                mid = p0.lerp(p1, 0.58)
                m.beam(p0, mid, 0.055, PEARL, segs=8)
                m.beam(mid, p1, 0.027, STEEL, segs=6)
                m.cyl(0.07, 0.07, 0.07, mid, STEEL, segs=8, rot=Z.rotation_difference(p1 - p0).to_euler())
                m.box((0.12, 0.1, 0.12), p0 - Vector((0.03, 0, 0)), STEEL)
                m.box((0.1, 0.1, 0.1), p1, STEEL)
            else:
                m.box((0.13, 0.28, 0.36), (b.x - 0.165, y, 0.95), DECK)
                m.strut((b.x - 0.165, y, 0.77), (b.x - 0.165, y, 0.17), 0.05, STEEL)
    return m.finish()


def solar_wing():
    """A big ISS-style solar array: a white mast on a flared, bolted pedestal, with steel bands and
    a service ladder on its road side (-X); a foil-wrapped beta gimbal drum on top; and either side
    along the road a pair of foil blanket boxes from which a triangular lattice mast runs out
    between two long cell blankets (hinge lines across them, tension wires down their edges) to a
    tip fitting with a green beacon. All turned toward the road and the sun."""
    m = Part("solar_wing")
    h = 10.5
    m.cyl(1.55, 1.55, 0.15, (0, 0, 0.075), STEEL, segs=24, bevel=True)
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        bolt(m, (1.38 * math.cos(a), 1.38 * math.sin(a), 0.15), Z, r=0.04, h=0.05)
    m.lathe([(0.0, 0.15), (1.25, 0.15), (1.02, 0.45), (0.72, 1.0), (0.58, 1.4), (0.0, 1.4)], (0, 0, 0), HULL, segs=20)

    def radius(z):
        return 0.58 + (0.4 - 0.58) * (z - 1.4) / (h - 1.4)

    m.cyl(0.58, 0.4, h - 1.4, (0, 0, (h + 1.4) / 2), HULL, segs=16)
    for z in (3.2, 5.7, 8.2):
        m.cyl(radius(z) + 0.05, radius(z) + 0.05, 0.18, (0, 0, z), STEEL, segs=16)
    ladder(m, (-radius(1.6) - 0.3, 0, 1.45), (-radius(h - 0.7) - 0.3, 0, h - 0.7), (0, 1, 0), (-1, 0, 0))
    # An access hatch at the foot (beside the ladder) and a cable riser up the far side.
    a = math.radians(180 - 35)
    n = Vector((math.cos(a), math.sin(a), 0.0))
    p = n * (radius(2.3) + 0.02) + Vector((0, 0, 2.3))
    m.box((0.08, 0.84, 1.5), p, STEEL, rot=facing(n), bevel=True)
    m.box((0.05, 0.7, 1.36), p + n * 0.04, HULL, rot=facing(n))
    m.box((0.05, 0.05, 0.3), p + n * 0.08 + Vector((0, 0, 0.1)), STEEL, rot=facing(n))
    m.strut((radius(1.4) + 0.12, 0, 1.3), (radius(h - 0.3) + 0.12, 0, h - 0.3), 0.16, PEARL, h=0.1)
    for z in (2.5, 4.5, 6.5, 8.5):
        m.box((0.22, 0.24, 0.06), (radius(z) + 0.1, 0, z), STEEL)
    # Beta gimbal: a collar, a foil drum along the road with steel end rings, boom stubs.
    m.cyl(0.46, 0.46, 0.5, (0, 0, h - 0.15), STEEL, segs=16)
    gz = h + 0.55
    m.cyl(0.75, 0.75, 1.6, (0, 0, gz), FOIL, segs=12, rot=ALONG_Y)
    for sy in (-1, 1):
        m.cyl(0.82, 0.82, 0.12, (0, sy * 0.8, gz), STEEL, segs=12, rot=ALONG_Y, bevel=True)
        m.box((0.55, 1.0, 0.55), (0, sy * 1.35, gz), PEARL, bevel=True)
    tilt = -0.65
    c = (0.0, 0.0, gz)
    tri = [(0.22 * math.cos(math.radians(a)), 0.22 * math.sin(math.radians(a))) for a in (90, 210, 330)]
    for s in (-1, 1):
        y0, y1 = s * 2.6, s * 13.6
        for bx in (-0.95, 0.95):
            tbox(m, (1.7, 0.6, 0.32), (bx, s * 2.15, 0), c, tilt, FOIL, bevel=True)
        m.cyl(0.3, 0.3, 0.7, tilt_pt(c, tilt, (0, s * 2.15, 0)), STEEL, segs=12, rot=ALONG_Y)
        # Coilable lattice mast: three longerons, a batten triangle every metre, a diagonal per face.
        stations = [y0 + (y1 - y0) * k / 11 for k in range(12)]
        for (ax, az) in tri:
            m.strut(tilt_pt(c, tilt, (ax, y0, az)), tilt_pt(c, tilt, (ax, y1, az)), 0.04, PEARL)
        for k, ys in enumerate(stations):
            for i in range(3):
                (ax, az), (bx_, bz) = tri[i], tri[(i + 1) % 3]
                m.strut(tilt_pt(c, tilt, (ax, ys, az)), tilt_pt(c, tilt, (bx_, ys, bz)), 0.03, PEARL)
                if k + 1 < len(stations):
                    m.strut(tilt_pt(c, tilt, (ax, ys, az)), tilt_pt(c, tilt, (bx_, stations[k + 1], bz)), 0.02, STEEL)
        # Blankets either side of the mast: a cell sheet with hinge lines and edge tension wires.
        ym = (y0 + y1) / 2
        for bx in (-0.95, 0.95):
            tbox(m, (1.6, 11.0, 0.025), (bx, ym, 0), c, tilt, SOLAR)
            for j in range(1, 10):
                tbox(m, (1.6, 0.035, 0.04), (bx, y0 + s * 1.1 * j, 0), c, tilt, STEEL)
            for ex in (-0.81, 0.81):
                tbox(m, (0.025, 11.0, 0.03), (bx + ex, ym, 0), c, tilt, STEEL)
        tbox(m, (2.1, 0.35, 0.18), (0, s * 13.75, 0), c, tilt, STEEL, bevel=True)
        tbox(m, (0.32, 0.32, 0.32), (0, s * 13.75, 0.25), c, tilt, BEACON_GREEN)
    return m.finish()


# ---------------------------------------------------------------- dome

def dome_shell(m, r, loc, segs, rings, panes, seed, rib, rib_mat, hub):
    """A geodesic-looking dome: rings of triangles, every other ring turned half a step, each pane
    picked from `panes`, a flat frame member standing proud on every edge, and a node at every hub."""
    rr = random.Random(seed)
    c = Vector(loc)
    verts, rings_idx = [], []
    for k in range(rings):
        phi = (math.pi / 2) * k / rings
        off = (math.pi / segs) * (k % 2)
        idx = []
        for s in range(segs):
            th = 2 * math.pi * s / segs + off
            idx.append(len(verts))
            verts.append((c.x + r * math.cos(phi) * math.cos(th), c.y + r * math.cos(phi) * math.sin(th),
                          c.z + r * math.sin(phi)))
        rings_idx.append(idx)
    apex = len(verts)
    verts.append((c.x, c.y, c.z + r))
    faces = []
    for k in range(rings - 1):
        a, b = rings_idx[k], rings_idx[k + 1]
        for s in range(segs):
            s1 = (s + 1) % segs
            if k % 2 == 0:
                faces += [(a[s], a[s1], b[s]), (a[s1], b[s1], b[s])]
            else:
                faces += [(a[s], b[s1], b[s]), (a[s], a[s1], b[s1])]
    top = rings_idx[-1]
    for s in range(segs):
        faces.append((top[s], top[(s + 1) % segs], apex))
    m.faces(verts, faces, [rr.choice(panes) for _ in faces])
    edges = {tuple(sorted((f[i], f[(i + 1) % len(f)]))) for f in faces for i in range(len(f))}
    for a_i, b_i in sorted(edges):
        a, b = Vector(verts[a_i]), Vector(verts[b_i])
        out_a, out_b = (a - c).normalized() * rib * 0.4, (b - c).normalized() * rib * 0.4
        m.strut(a + out_a, b + out_b, rib * 1.6, rib_mat, h=rib, up=tuple((a + b) / 2 - c))
    for v in verts:
        p = Vector(v)
        if p.z - c.z < 0.05:
            continue
        m.box((hub, hub, hub), p + (p - c).normalized() * rib * 0.45, rib_mat, rot=facing(p - c))


def tree(m, x, y, z, s, seed):
    """A small tree in a planter: a white ring planter, a slim pale trunk with two limbs, and a
    canopy of three lumps (emissive green, lit from inside the dome)."""
    rr = random.Random(seed)
    m.lathe([(0.0, z), (0.85 * s, z), (0.85 * s, z + 0.4), (0.72 * s, z + 0.4), (0.72 * s, z + 0.3), (0.0, z + 0.3)],
            (x, y, 0), PEARL, segs=12)
    trunk_top = z + 2.3 * s
    m.cyl(0.11 * s, 0.06 * s, trunk_top - z, (x, y, (z + trunk_top) / 2), PEARL, segs=6)
    for k in range(2):
        a = rr.uniform(0, 2 * math.pi)
        m.strut((x, y, z + 1.4 * s), (x + math.cos(a) * 0.6 * s, y + math.sin(a) * 0.6 * s, z + 2.0 * s),
                0.06 * s, PEARL)
    for (dx, dy, dz, r) in ((0.0, 0.0, 2.6, 1.0), (0.5, 0.2, 2.2, 0.72), (-0.4, -0.3, 2.3, 0.68)):
        m.blob(r * s, (x + dx * s, y + dy * s, z + dz * s), PLANT, subdiv=2, jitter=0.14, squash=0.8)


def dome():
    """An observation dome: clear glass panes (a few frosted ones glowing) on a white geodesic frame
    with hub nodes, a plated base ring on a stepped plinth with a glowing band, a cornice and four
    maintenance hatches, a cap with a vent and antenna at the top; inside, a softly lit floor with a
    path ring, three trees in planters and shrubs; toward the road an airlock vestibule with a lit
    glazed door, a light bar, a canopy on struts, side windows and steps."""
    m = Part("dome")
    r, base = 6.0, 1.0
    m.lathe([(6.4, 0.22), (6.6, 0.22), (6.9, 0.1), (6.9, 0.0), (6.4, 0.0)], (0, 0, 0), PEARL, segs=28, closed=True)
    m.cyl(r + 0.4, r + 0.4, base, (0, 0, base / 2), HULL, segs=28, bevel=True)
    m.cyl(r + 0.43, r + 0.43, 0.1, (0, 0, 0.84), WINDOW, segs=28)
    m.cyl(r + 0.5, r + 0.5, 0.1, (0, 0, base - 0.02), PEARL, segs=28, bevel=True)
    for deg in (60, 120, 240, 300):
        a = math.radians(deg)
        n = Vector((math.cos(a), math.sin(a), 0.0))
        p = n * (r + 0.4) + Vector((0, 0, 0.42))
        rot = facing(n)
        m.box((0.12, 1.0, 0.62), p + n * 0.03, PEARL, rot=rot, bevel=True)
        m.box((0.06, 0.82, 0.48), p + n * 0.08, HULL, rot=rot)
        m.box((0.05, 0.36, 0.05), p + n * 0.13 + Vector((0, 0, 0.1)), PEARL, rot=rot)
        for k in range(3):
            m.box((0.04, 0.5, 0.03), p + n * 0.12 + Vector((0, 0, -0.14 - k * 0.06)), PEARL, rot=rot)
    dome_shell(m, r, (0, 0, base), 14, 4, [DOME_GLASS] * 5 + [FROST], seed=7, rib=0.09, rib_mat=PEARL, hub=0.2)
    top = base + r
    m.cyl(0.85, 0.85, 0.22, (0, 0, top + 0.02), PEARL, segs=14, bevel=True)
    m.cyl(0.75, 0.35, 0.32, (0, 0, top + 0.28), HULL, segs=14)
    m.strut((0.45, 0, top + 0.3), (0.45, 0, top + 1.9), 0.04, PEARL)
    # Inside: the lit floor, a path ring, trees and shrubs.
    m.cyl(r - 0.1, r - 0.1, 0.06, (0, 0, base + 0.03), INTERIOR, segs=28)
    m.lathe([(3.1, base + 0.06), (3.6, base + 0.06), (3.6, base + 0.09), (3.1, base + 0.09)], (0, 0, 0), PEARL, segs=28,
            closed=True)
    for (x, y, s, seed) in ((1.4, -1.6, 1.0, 3), (-1.2, 1.9, 0.85, 4), (2.2, 2.2, 0.75, 5)):
        tree(m, x, y, base + 0.06, s, seed)
    rr = random.Random(21)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.4
        rad = rr.uniform(4.2, 4.9)
        m.blob(rr.uniform(0.35, 0.5), (rad * math.cos(a), rad * math.sin(a), base + 0.3), PLANT, subdiv=2,
               jitter=0.18, squash=0.7)
    # Airlock vestibule toward the road.
    vx = -r - 0.9
    m.box((2.6, 2.4, 2.4), (vx, 0, 1.2), HULL, bevel=True)
    m.box((2.8, 2.6, 0.14), (vx, 0, 2.47), PEARL, bevel=True)
    m.box((0.16, 1.5, 2.0), (vx - 1.32, 0, 1.12), PEARL, bevel=True)
    m.box((0.06, 1.1, 1.7), (vx - 1.42, 0, 1.0), WINDOW)
    for sy in (-1, 1):
        m.box((0.05, 0.05, 1.7), (vx - 1.45, sy * 0.02, 1.0), PEARL)
    m.box((0.1, 1.2, 0.08), (vx - 1.42, 0, 2.05), WINDOW)
    m.box((1.1, 1.9, 0.08), (vx - 1.85, 0, 2.3), PEARL, rot=(0, math.radians(-8), 0), bevel=True)
    for sy in (-0.85, 0.85):
        m.strut((vx - 2.35, sy, 2.25), (vx - 1.4, sy, 1.75), 0.06, PEARL)
    for sy in (-1, 1):
        m.box((0.9, 0.14, 0.7), (vx, sy * 1.22, 1.5), PEARL, bevel=True)
        m.box((0.7, 0.06, 0.5), (vx, sy * 1.28, 1.5), WINDOW)
    for k in range(2):
        m.box((0.42, 1.9 - k * 0.2, 0.12), (vx - 1.55 - (1 - k) * 0.4, 0, 0.06 + k * 0.12), PEARL, bevel=True)
    return m.finish()


# ---------------------------------------------------------------- docking arm

def docking_arm():
    """A docking arm. A control tower: plated faces between white corner pilasters and floor bands,
    framed window bands with mullions toward the road (-X) and slit windows to the sides, a framed
    lit door at its foot, a glazed control cab on top with a cornice, roof plant and an antenna mast
    with a green beacon. From it a white truss reaches out over the deck (+X, away from the road),
    carrying a lit jetway tube in ring frames, lifted by two hydraulic rams from the tower, with
    white beacons under it. At its end a bolted airlock collar with a docking ring, guide petals and
    a green beacon, and a transit pod docked there: a lathed hull with seam bands, framed windows
    down both sides, RCS quads and an engine bell."""
    m = Part("docking_arm")
    m.box((3.7, 3.7, 0.3), (0, 0, 0.15), DECK, bevel=True)
    m.box((3.0, 3.0, 8.0), (0, 0, 4.3), HULL)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.42, 0.42, 8.0), (sx * 1.45, sy * 1.45, 4.3), PEARL, bevel=True)
    for z in (2.75, 5.05, 7.35):
        m.box((3.14, 3.14, 0.16), (0, 0, z), PEARL, bevel=True)
    for z in (3.9, 6.2):
        m.box((0.08, 2.3, 0.8), (-1.52, 0, z), DECK)
        m.box((0.06, 2.1, 0.6), (-1.55, 0, z), WINDOW)
        for y in (-0.53, 0.0, 0.53):
            m.box((0.06, 0.06, 0.62), (-1.58, y, z), PEARL)
        m.box((0.22, 2.4, 0.06), (-1.6, 0, z - 0.42), PEARL)
        for sy in (-1, 1):
            m.box((0.5, 0.08, 0.7), (0, sy * 1.52, z), DECK)
            m.box((0.36, 0.06, 0.56), (0, sy * 1.55, z), WINDOW)
    m.box((0.16, 1.6, 2.15), (-1.55, 0, 1.38), PEARL, bevel=True)
    m.box((0.06, 1.2, 1.85), (-1.62, 0, 1.25), DECK)
    m.box((0.04, 0.8, 0.6), (-1.66, 0, 1.75), WINDOW)
    m.box((0.12, 0.7, 0.08), (-1.66, 0, 2.55), WINDOW)
    # The control cab.
    m.box((3.8, 3.8, 1.6), (0, 0, 9.1), HULL, bevel=True)
    for k, n in enumerate(((-1, 0), (1, 0), (0, -1), (0, 1))):
        nx, ny = n
        rot = facing((nx, ny, 0))
        m.box((0.06, 3.4, 0.7), (nx * 1.92, ny * 1.92, 9.15), WINDOW, rot=rot)
        for t in (-1.0, -0.33, 0.33, 1.0):
            m.box((0.06, 0.07, 0.72), (nx * 1.95 - ny * t * 1.25, ny * 1.95 + nx * t * 1.25, 9.15), PEARL)
    m.box((4.0, 4.0, 0.2), (0, 0, 9.98), PEARL, bevel=True)
    m.box((3.6, 3.6, 0.2), (0, 0, 10.18), DECK)
    m.box((1.0, 0.8, 0.5), (0.8, 0.6, 10.53), DECK)
    m.box((0.6, 0.6, 0.35), (-0.9, -0.8, 10.45), PEARL)
    m.strut((-0.6, 0.7, 10.28), (-0.6, 0.7, 12.0), 0.07, STEEL)
    m.box((0.36, 0.36, 0.36), (-0.6, 0.7, 12.15), BEACON_GREEN)

    # The arm: root housing, truss, jetway tube, rams, beacons.
    z0, z1, hw, x0, x1 = 7.2, 8.8, 0.75, 1.5, 21.0
    zc = (z0 + z1) / 2
    m.cyl(1.0, 1.0, 0.3, (1.6, 0, zc), STEEL, segs=16, rot=ALONG_X)
    m.box((1.2, 2.0, 2.2), (2.2, 0, zc), PEARL, bevel=True)
    bays = 8
    xs = [2.8 + (x1 - 2.8) * k / bays for k in range(bays + 1)]
    for sy in (-hw, hw):
        for sz in (z0, z1):
            m.beam((xs[0], sy, sz), (x1, sy, sz), 0.07, PEARL, segs=8)
    for k, x in enumerate(xs):
        m.strut((x, -hw, z0), (x, -hw, z1), 0.06, PEARL)
        m.strut((x, hw, z0), (x, hw, z1), 0.06, PEARL)
        m.strut((x, -hw, z1), (x, hw, z1), 0.06, PEARL)
        m.strut((x, -hw, z0), (x, hw, z0), 0.06, PEARL)
        m.cyl(0.6, 0.6, 0.14, (x, 0, zc), PEARL, segs=12, rot=ALONG_X)
        if k + 1 < len(xs):
            xb = xs[k + 1]
            for sy in (-hw, hw):
                m.strut((x, sy, z0), (xb, sy, z1), 0.045, STEEL)
            m.strut((x, -hw, z1), (xb, hw, z1), 0.045, STEEL)
            m.strut((x, hw, z0), (xb, -hw, z0), 0.045, STEEL)
    m.cyl(0.5, 0.5, x1 - 2.8, ((x1 + 2.8) / 2, 0, zc), HULL, segs=12, rot=ALONG_X)
    for sy in (-1, 1):
        m.box((x1 - 3.4, 0.04, 0.12), ((x1 + 2.8) / 2, sy * 0.5, zc + 0.05), WINDOW)
    for sy in (-0.55, 0.55):
        p0, p1 = Vector((1.75, sy, 4.2)), Vector((8.6, sy, z0 - 0.08))
        mid = p0.lerp(p1, 0.55)
        m.box((0.4, 0.3, 0.5), (1.65, sy, 4.2), STEEL)
        m.beam(p0, mid, 0.14, PEARL, segs=12)
        m.beam(mid, p1, 0.075, STEEL, segs=12)
        m.cyl(0.17, 0.17, 0.16, mid, STEEL, segs=12, rot=Z.rotation_difference(p1 - p0).to_euler())
        m.box((0.3, 0.26, 0.2), (8.6, sy, z0 - 0.12), STEEL)
        m.sweep([(1.55, sy * 1.3, 3.4), (1.7, sy * 1.0, 3.9), (2.1, sy * 0.75, 4.4)], circle(0.035, 6), DECK)
    for x in (7.0, 13.0, 19.0):
        m.box((0.42, 0.42, 0.12), (x, 0, z0 - 0.1), STEEL)
        m.box((0.3, 0.3, 0.2), (x, 0, z0 - 0.25), BEACON_WHITE)

    # Airlock collar.
    m.lathe([(0.0, 0.0), (1.9, 0.0), (1.9, 0.35), (1.55, 0.35), (1.55, 1.2), (1.72, 1.2), (1.72, 1.45), (0.0, 1.45)],
            (x1, 0, zc), DECK, segs=20, rot=ALONG_X, mats=[DECK, DECK, DECK, HULL, STEEL, STEEL, STEEL])
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        m.box((0.06, 0.07, 0.07), (x1 + 0.37, 1.73 * math.cos(a), zc + 1.73 * math.sin(a)), STEEL)
    for deg in (90, 210, 330):
        a = math.radians(deg)
        m.box((0.55, 0.5, 0.07), (x1 + 1.6, 1.5 * math.cos(a), zc + 1.5 * math.sin(a)), STEEL,
              rot=(a - math.pi / 2, 0, 0))
    m.strut((x1 + 0.6, 0, zc + 1.55), (x1 + 0.6, 0, zc + 2.0), 0.08, STEEL)
    m.box((0.32, 0.32, 0.32), (x1 + 0.6, 0, zc + 2.15), BEACON_GREEN)

    # The docked pod.
    px = x1 + 1.45
    m.lathe([(0.0, -0.02), (1.2, -0.02), (1.32, 0.12), (1.44, 0.5), (1.5, 1.2), (1.5, 4.6), (1.42, 5.5), (1.2, 6.3),
             (0.95, 6.8), (0.92, 7.0), (0.0, 7.0)], (px, 0, zc), HULL, segs=20, rot=ALONG_X,
            mats=[STEEL, HULL, HULL, HULL, HULL, HULL, PEARL, PEARL, PEARL, PEARL])
    m.lathe([(0.0, 6.95), (0.7, 6.95), (0.85, 7.2), (1.05, 7.75), (0.95, 7.78), (0.7, 7.3), (0.0, 7.25)], (px, 0, zc),
            DECK, segs=16, rot=ALONG_X)
    for d in (1.25, 4.55):
        m.cyl(1.53, 1.53, 0.1, (px + d, 0, zc), STEEL, segs=20, rot=ALONG_X)
    for sy in (-1, 1):
        for k in range(5):
            wx = px + 1.75 + k * 0.6
            m.box((0.46, 0.12, 0.4), (wx, sy * 1.44, zc + 0.36), DECK)
            m.box((0.36, 0.1, 0.3), (wx, sy * 1.47, zc + 0.36), WINDOW)
        m.box((3.0, 0.06, 0.05), (px + 2.95, sy * 1.5, zc - 0.05), WINDOW)
    for deg in (45, 135, 225, 315):
        a = math.radians(deg)
        cy, cz = 1.32 * math.cos(a), 1.32 * math.sin(a)
        m.box((0.3, 0.3, 0.3), (px + 5.75, cy, zc + cz), DECK, rot=(a, 0, 0))
        m.cyl(0.05, 0.08, 0.14, (px + 5.75, cy * 1.17, zc + cz * 1.17), STEEL, segs=6,
              rot=Z.rotation_difference(Vector((0, cy, cz))).to_euler())
    m.strut((px + 3.0, 0, zc + 1.48), (px + 3.0, 0, zc + 2.1), 0.03, STEEL)
    return m.finish()


# ---------------------------------------------------------------- the distant station

def station_hub():
    """A distant ring station: a lathed hub on the wheel's axis (Blender Y) with a glowing band,
    docking ports at both ends and four radial ports (two with craft docked), six spokes with
    sleeves, and a habitation ring of 24 octagonal modules joined by dark collars, with lit window
    rows on both faces and window bands round the outside, plus a solar mast behind the hub and
    beacons. The origin is the wheel's centre: the world script hangs it far off in the sky."""
    m = Part("station_hub", width=0.0)
    R, n = 30.0, 24
    w, hgt, ch = 2.0, 1.6, 0.6
    octagon = [(w, -hgt + ch), (w, hgt - ch), (w - ch, hgt), (-w + ch, hgt), (-w, hgt - ch), (-w, -hgt + ch),
               (-w + ch, -hgt), (w - ch, -hgt)]
    collar = [(u * 1.12, v * 1.14) for u, v in octagon]

    def on_ring(a, rad=R):
        return Vector((rad * math.cos(a), 0.0, rad * math.sin(a)))

    for i in range(n):
        a0, a1 = 2 * math.pi * (i + 0.04) / n, 2 * math.pi * (i + 0.96) / n
        am = 2 * math.pi * (i + 0.5) / n
        radial = on_ring(am, 1.0)
        mat = HULL if i % 6 else PEARL
        m.sweep([on_ring(a0), on_ring(a1)], octagon, mat, up=tuple(radial))
        aj = 2 * math.pi * i / n
        m.sweep([on_ring(aj - 0.012), on_ring(aj + 0.012)], collar, DECK, up=tuple(on_ring(aj, 1.0)))
        mid = (on_ring(a0) + on_ring(a1)) / 2  # the module's axis is the chord, inside the circle
        seg = (on_ring(a1) - on_ring(a0)).length
        rot = (0, math.pi / 2 - am, 0)
        for sy in (-1, 1):
            for dv in (-0.5, 0.5):
                m.box((seg - 1.4, 0.1, 0.3), mid + Y * (sy * (w + 0.02)) + radial * dv, WINDOW, rot=rot)
        m.box((seg - 1.6, 2.4, 0.08), mid + radial * (hgt + 0.03), WINDOW if i % 2 else DECK, rot=rot)
        if i % 3 == 0:
            m.box((seg - 3.0, 1.2, 0.5), mid + radial * (-hgt - 0.25), DECK, rot=rot)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        d = on_ring(a, 1.0)
        m.beam(d * 4.6, d * (R - hgt), 0.7, PEARL, segs=8)
        m.beam(d * 12.0, d * 15.0, 0.95, DECK, segs=8)
        m.beam(d * (R - hgt - 1.2), d * (R - hgt), 1.1, DECK, segs=8)
        m.strut(d * 5.0 + Y * 0.9, d * (R - hgt) + Y * 0.9, 0.18, DECK)
    # The hub, along Y.
    prof = [(0.0, -7.0), (1.5, -7.0), (1.9, -6.8), (1.9, -6.4), (1.6, -6.4), (1.6, -5.6), (2.8, -5.5), (5.0, -4.5),
            (5.0, 4.5), (2.8, 5.5), (1.6, 5.6), (1.6, 6.4), (1.9, 6.4), (1.9, 6.8), (1.5, 7.0), (0.0, 7.0)]
    mats = [DECK, DECK, DECK, DECK, DECK, PEARL, HULL, HULL, PEARL, DECK, DECK, DECK, DECK, DECK, DECK]
    m.lathe([(r, -z) for r, z in prof], (0, 0, 0), HULL, segs=24, rot=ALONG_Y, mats=mats)
    m.cyl(5.1, 5.1, 1.2, (0, -2.5, 0), STRIP, segs=24, rot=ALONG_Y)
    m.cyl(5.1, 5.1, 0.5, (0, 2.0, 0), DECK, segs=24, rot=ALONG_Y)
    for sy in (-1, 1):
        m.box((0.9, 0.9, 0.9), (0, sy * 7.5, 0), BEACON_GREEN)
    for k in range(4):
        a = 2 * math.pi * k / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        m.beam(d * 4.6 + Y * 1.0, d * 6.6 + Y * 1.0, 0.9, PEARL, segs=8)
        m.beam(d * 6.6 + Y * 1.0, d * 6.9 + Y * 1.0, 1.15, DECK, segs=8)
        if k % 2 == 0:
            m.beam(d * 6.9 + Y * 1.0, d * 9.8 + Y * 1.0, 0.8, HULL, segs=8)
            m.beam(d * 9.8 + Y * 1.0, d * 10.6 + Y * 1.0, 0.45, DECK, segs=8)
    m.beam((0, 7.0, 0), (0, 16.0, 0), 0.35, PEARL, segs=6)
    for sx in (-1, 1):
        m.box((7.0, 3.0, 0.12), (sx * 4.2, 13.5, 0), DECK)
        m.box((7.2, 0.15, 0.2), (sx * 4.2, 12.0, 0), PEARL)
        m.box((7.2, 0.15, 0.2), (sx * 4.2, 15.0, 0), PEARL)
    for k in range(4):
        a = 2 * math.pi * k / 4 + math.pi / 4
        m.box((1.2, 1.2, 1.2), on_ring(a, R + hgt + 0.8) - Y * 1.0, BEACON_WHITE)
    return m.finish()


# ---------------------------------------------------------------- drone

def drone():
    """A small maintenance drone hovering about 4.4 above the deck (scattered static by the world
    script), clear of the conduit and the solar panels: a lathed white body with a dark belly and
    panel lines, a sensor head with a green lens on a stalk, four ducted thrusters with rotors on
    arms, a green light on top, a whip antenna and a little tool arm with a claw hanging below.
    Scattered by the thousand through a MultiMesh, so it has no bevel."""
    m = Part("drone", width=0.0, crease=40.0)
    z = 4.4
    m.lathe([(0.0, -0.2), (0.22, -0.19), (0.36, -0.13), (0.44, -0.04), (0.45, 0.03), (0.38, 0.12), (0.24, 0.18),
             (0.0, 0.2)], (0, 0, z), HULL, segs=12, mats=[DECK, DECK, HULL, HULL, HULL, HULL, HULL])
    m.lathe([(0.452, -0.012), (0.462, -0.012), (0.462, 0.008), (0.452, 0.008)], (0, 0, z), DECK, segs=12, closed=True)
    m.lathe([(0.3, 0.145), (0.31, 0.14), (0.32, 0.155), (0.31, 0.16)], (0, 0, z), DECK, segs=12, closed=True)
    for k in range(4):
        a = k * math.pi / 2
        m.box((0.16, 0.012, 0.012), (0.3 * math.cos(a), 0.3 * math.sin(a), z + 0.165), DECK,
              rot=(0, math.radians(-25), a))
    m.cyl(0.035, 0.035, 0.1, (-0.3, 0, z - 0.2), DECK, segs=6)
    m.blob(0.11, (-0.3, 0, z - 0.28), DECK, subdiv=1, jitter=0.0)
    m.cyl(0.045, 0.045, 0.04, (-0.405, 0, z - 0.28), DRONE_LIGHT, segs=8, rot=ALONG_X)
    m.box((0.08, 0.06, 0.05), (0.32, -0.1, z - 0.17), DECK)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        m.box((0.44, 0.07, 0.05), (0.56 * ca, 0.56 * sa, z + 0.04), STEEL, rot=(0, 0, a))
        dc = (0.8 * ca, 0.8 * sa, z + 0.06)
        m.lathe([(0.2, -0.06), (0.25, -0.07), (0.27, 0.0), (0.25, 0.07), (0.21, 0.06)], dc, HULL, segs=10, closed=True)
        m.box((0.4, 0.025, 0.02), dc, DECK, rot=(0, 0, a))
        m.cyl(0.05, 0.05, 0.08, dc, DECK, segs=6)
        m.box((0.36, 0.05, 0.01), (dc[0], dc[1], z + 0.1), STEEL, rot=(0, 0, a + 0.7))
    m.box((0.12, 0.12, 0.05), (0, 0, z + 0.215), DRONE_LIGHT)
    m.strut((0.15, 0.1, z + 0.15), (0.15, 0.1, z + 0.5), 0.012, STEEL)
    m.beam((0.1, 0.0, z - 0.15), (0.3, 0.12, z - 0.55), 0.025, STEEL, segs=4)
    for s in (-1, 1):
        m.box((0.03, 0.03, 0.12), (0.3 + s * 0.04, 0.12, z - 0.62), STEEL, rot=(0, s * 0.3, 0))
    return m.finish()


# ---------------------------------------------------------------- hood

def hood():
    """The player's transit pod, seen from the driver's seat, behind the keyboard. Same footprint as
    backroads' rover hood (half-width 8, running about 9.6 toward -Y, top from 0 to 0.95, lamps at
    the front corners). Only its front strip and the nacelles are in shot: a pale pearl shell with a
    dark lip and a fine louvred grille across the front, dark seams, a fastener row and flush vents
    on the shoulders, short green chevrons on the outer shoulders (never down the middle, where they
    would read as road marks), and two maglev nacelles: lathed, with seam bands, a louvred intake on
    top, a dim green accent line, a chamfered skirt, and at the front a chrome bezel round a lamp
    ring with a dark centre, and a dim light bar on top for the driver. Never weathered."""
    m = Part("hood", width=0.03)
    w = 8.0
    slope = -math.atan(0.95 / 9.2)

    def on_top(y):
        return 0.95 * (0.2 - y) / 9.2

    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], POD, bevel=True)
    # A dark lip along the front edge, so the pale shell never glares right under the keys, with a
    # fine louvred grille in it.
    m.box((w * 2, 0.5, 0.05), (0, -0.05, on_top(-0.05) + 0.02), DARK, rot=(slope, 0, 0))
    for k in range(28):
        x = -w + 0.6 + k * (2 * w - 1.2) / 27
        m.box((0.05, 0.36, 0.03), (x, -0.05, on_top(-0.05) + 0.05), TRIM, rot=(slope, 0, 0))
    for y in (-2.2, -6.0):
        m.box((w * 2 - 0.6, 0.07, 0.03), (0, y, on_top(y) + 0.02), DARK, rot=(slope, 0, 0))
    for sx in (-1, 1):
        for k in range(3):
            y = -1.0 - k * 0.42
            m.box((1.1, 0.12, 0.03), (sx * (5.6 + k * 0.18), y, on_top(y) + 0.04), ACCENT,
                  rot=(slope, 0, sx * 0.35))
        m.box((0.1, 8.6, 0.03), (sx * 7.5, -4.6, on_top(-4.6) + 0.02), DARK, rot=(slope, 0, 0))
        for k in range(10):
            y = -0.6 - k * 0.8
            m.box((0.06, 0.06, 0.03), (sx * 7.3, y, on_top(y) + 0.035), TRIM, rot=(slope, 0, 0))
        # Flush vents on the shoulder: a dark recess with slats.
        m.box((1.0, 1.4, 0.025), (sx * 6.4, -3.6, on_top(-3.6) + 0.015), DARK, rot=(slope, 0, 0))
        for k in range(5):
            y = -3.05 - k * 0.27
            m.box((0.9, 0.06, 0.04), (sx * 6.4, y, on_top(y) + 0.035), TRIM, rot=(slope - 0.4, 0, 0))
    for side in (-1, 1):
        x = side * (w + 0.85)
        # A maglev nacelle: a lathed pod along the hood (front toward +Y) with a skirt below it.
        m.lathe([(0.0, -9.62), (0.55, -9.6), (0.78, -9.3), (0.8, -6.0), (0.81, -1.0), (0.84, -0.3), (0.84, 0.22),
                 (0.0, 0.22)], (x, 0, -0.05), POD, segs=20, rot=TO_Y, mats=[POD, POD, POD, POD, POD, POD, DARK])
        for y in (-1.2, -3.6, -6.6):
            m.cyl(0.825, 0.825, 0.05, (x, y, -0.05), DARK, segs=20, rot=ALONG_Y)
        skirt = [(-0.85, -0.35), (0.85, -0.35), (0.85, 0.15), (0.7, 0.35), (-0.7, 0.35), (-0.85, 0.15)]
        m.sweep([(x, -9.4, -0.75), (x, 0.2, -0.75)], skirt, DARK)
        m.box((0.08, 9.0, 0.05), (x - side * 0.5, -4.7, 0.6), ACCENT)
        # Louvred intake on top, behind the lamp.
        m.box((0.55, 1.5, 0.06), (x + side * 0.1, -2.4, 0.79), DARK)
        for k in range(6):
            m.box((0.5, 0.06, 0.04), (x + side * 0.1, -1.78 - k * 0.25, 0.83), TRIM, rot=(-0.4, 0, 0))
        # Front: a chrome bezel round the lamp ring (dark centre), and a dim bar on top for the driver.
        m.lathe([(0.84, 0.22), (0.86, 0.5), (0.7, 0.6), (0.62, 0.58), (0.62, 0.22)], (x, 0, -0.05), TRIM, segs=20,
                rot=TO_Y, closed=True, bevel=True)
        m.cyl(0.6, 0.6, 0.24, (x, 0.44, -0.05), LAMP, segs=20, rot=TO_Y)
        m.cyl(0.3, 0.3, 0.06, (x, 0.58, -0.05), DARK, segs=16, rot=TO_Y)
        m.box((1.2, 0.1, 0.04), (x, 0.36, 0.8), LAMP_BAR)
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), DARK)
    return m.finish()


export_all([wall, light_strip, conduit, solar_row, solar_wing, dome, docking_arm, station_hub, drone, hood],
           OUT_DIR, PREVIEW)
