"""Backroads props: silo, barn, farmhouse, water tower, telephone pole with wires,
fence, oak, road sign, wheat tuft, and the player's pickup hood.

Run: blender --background --python tools/themes/backroads/props.py -- game/assets/themes/backroads/models [preview.png]
"""
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "blender"))
from propkit import Model, args, export_all, material, reset, rng  # noqa: E402

POLE_SPACING = 24.0  # must match the pole repeat in game/scripts/themes/backroads.gd
FENCE_LENGTH = 6.0  # must match the fence repeat in game/scripts/themes/backroads.gd
OUT_DIR, PREVIEW = args()
reset()

WOOD = material("wood", (0.13, 0.08, 0.05))
WOOD_PALE = material("wood_pale", (0.32, 0.24, 0.16))
BARN_RED = material("barn_red", (0.30, 0.045, 0.035))
TRIM = material("trim", (0.55, 0.52, 0.46))
STEEL = material("steel", (0.42, 0.44, 0.47), rough=0.55, metal=0.6)
ROOF = material("roof", (0.11, 0.11, 0.13), rough=0.7)
WINDOW = material("window", (0.9, 0.6, 0.25), emit=(1.0, 0.62, 0.24), strength=5.0)
LEAF = material("leaf", (0.035, 0.075, 0.04))
WIRE = material("wire", (0.02, 0.02, 0.02))
WHEAT = material("wheat", (0.62, 0.47, 0.17))
WHEAT_HEAD = material("wheat_head", (0.8, 0.62, 0.26))
TRUCK = material("truck", (0.36, 0.055, 0.04), rough=0.42, metal=0.25)
CHROME = material("chrome", (0.75, 0.76, 0.78), rough=0.22, metal=1.0)
LAMP = material("lamp", (1.0, 0.86, 0.6), emit=(1.0, 0.84, 0.58), strength=9.0)
SIGN_GREEN = material("sign_green", (0.03, 0.2, 0.09), rough=0.45)
SIGN_WHITE = material("sign_white", (0.85, 0.85, 0.8), emit=(0.85, 0.85, 0.75), strength=0.6)


def silo():
    m = Model("silo")
    m.cyl(2.2, 2.2, 13.0, (0, 0, 6.5), STEEL, segs=20)
    for z in range(1, 13, 2):
        m.cyl(2.25, 2.25, 0.09, (0, 0, z), TRIM, segs=20)
    m.cyl(2.3, 0.35, 1.7, (0, 0, 13.85), ROOF, segs=20)
    m.box((0.5, 0.2, 12.0), (0, -2.25, 6.0), WOOD_PALE)
    m.cyl(1.7, 1.7, 9.0, (4.2, 0.4, 4.5), STEEL, segs=16)
    m.cyl(1.75, 0.3, 1.2, (4.2, 0.4, 9.6), ROOF, segs=16)
    return m.finish()


def barn():
    m = Model("barn")
    w, l, h, ridge = 5.5, 7.0, 4.6, 7.6
    m.box((w * 2, l * 2, h), (0, 0, h / 2), BARN_RED)
    gable = [(-w, -l, h), (w, -l, h), (0, -l, ridge), (-w, l, h), (w, l, h), (0, l, ridge)]
    m.poly(gable, [(0, 1, 2), (5, 4, 3)], BARN_RED)
    roof = [(-w - 0.4, -l - 0.5, h - 0.2), (0, -l - 0.5, ridge + 0.15), (w + 0.4, -l - 0.5, h - 0.2),
            (-w - 0.4, l + 0.5, h - 0.2), (0, l + 0.5, ridge + 0.15), (w + 0.4, l + 0.5, h - 0.2)]
    m.poly(roof, [(0, 3, 4, 1), (1, 4, 5, 2)], ROOF)
    # Faces the road (Blender -X side of the prop is turned toward the road in game).
    for y in (-3.5, 3.5):
        m.box((0.12, 1.3, 1.5), (-w - 0.03, y, 2.5), WINDOW)
    m.box((0.14, 3.0, 3.4), (-w - 0.05, 0, 1.7), TRIM)
    m.box((0.2, 2.6, 3.0), (-w - 0.08, 0, 1.6), BARN_RED)
    m.box((0.1, 1.2, 1.0), (-w * 0.0, -l - 0.04, 5.3), WINDOW)
    return m.finish()


def house():
    m = Model("house")
    w, l, h, ridge = 3.6, 4.6, 3.4, 5.6
    m.box((w * 2, l * 2, h), (0, 0, h / 2), WOOD_PALE)
    roof = [(-w - 0.45, -l - 0.3, h - 0.1), (0, -l - 0.3, ridge), (w + 0.45, -l - 0.3, h - 0.1),
            (-w - 0.45, l + 0.3, h - 0.1), (0, l + 0.3, ridge), (w + 0.45, l + 0.3, h - 0.1)]
    m.poly(roof, [(0, 3, 4, 1), (1, 4, 5, 2), (0, 2, 1), (3, 4, 5)], ROOF)
    for y in (-2.6, 2.6):
        m.box((0.1, 1.2, 1.3), (-w - 0.02, y, 1.9), WINDOW)
    m.box((0.12, 1.1, 2.3), (-w - 0.03, 0, 1.15), WOOD)
    m.box((1.8, 3.4, 0.15), (-w - 0.9, 0, 2.7), ROOF)
    m.box((0.8, 0.8, 2.2), (1.7, 2.6, 6.0), WOOD)
    return m.finish()


def pole():
    m = Model("pole")
    top = 9.0
    m.cyl(0.17, 0.12, top, (0, 0, top / 2), WOOD, segs=8)
    m.box((3.0, 0.18, 0.16), (0, 0, top - 0.8), WOOD)
    points = (-1.3, 0.0, 1.3)
    for x in points:
        m.cyl(0.07, 0.05, 0.3, (x, 0, top - 0.55), TRIM, segs=6)
        # Sagging wire reaching exactly to the next pole, so repeats join up.
        n = 10
        prev = None
        for i in range(n + 1):
            p = i / n
            cur = (x, p * POLE_SPACING, top - 0.42 - 1.15 * 4 * p * (1 - p))
            if prev:
                m.beam(prev, cur, 0.022, WIRE, segs=4)
            prev = cur
    return m.finish()


def fence():
    m = Model("fence")
    for y in (-FENCE_LENGTH / 2, 0.0):
        m.box((0.16, 0.16, 1.5), (0, y + rng.uniform(-0.05, 0.05), 0.75), WOOD_PALE)
    for z in (0.65, 1.2):
        m.box((0.05, FENCE_LENGTH, 0.13), (0.1, 0, z), WOOD_PALE, rot=(rng.uniform(-0.012, 0.012), 0, 0))
    return m.finish()


def tree():
    m = Model("tree")
    m.cyl(0.42, 0.24, 4.6, (0, 0, 2.3), WOOD, segs=7)
    m.beam((0, 0, 3.3), (1.5, 0.4, 5.2), 0.15, WOOD)
    m.beam((0, 0, 3.6), (-1.4, -0.3, 5.5), 0.14, WOOD)
    for loc, r in (((0, 0, 7.0), 3.0), ((2.1, 0.4, 6.0), 2.2), ((-2.2, -0.2, 6.2), 2.3),
                   ((0.4, -1.8, 5.8), 2.0), ((-0.3, 1.9, 6.1), 2.0)):
        m.blob(r, loc, LEAF, squash=0.82)
    return m.finish()


def water_tower():
    m = Model("water_tower")
    legs = [(-2.6, -2.6), (2.6, -2.6), (2.6, 2.6), (-2.6, 2.6)]
    for x, y in legs:
        m.beam((x * 1.3, y * 1.3, 0), (x * 0.8, y * 0.8, 12), 0.16, STEEL, segs=6)
    for i, (x, y) in enumerate(legs):
        nx, ny = legs[(i + 1) % 4]
        m.beam((x * 1.05, y * 1.05, 6), (nx * 1.05, ny * 1.05, 6), 0.07, STEEL, segs=4)
        m.beam((x * 1.3, y * 1.3, 0), (nx * 1.05, ny * 1.05, 6), 0.05, STEEL, segs=4)
    m.cyl(3.6, 3.6, 5.2, (0, 0, 14.4), TRIM, segs=20)
    m.cyl(3.8, 0.3, 2.2, (0, 0, 18.1), ROOF, segs=20)
    m.cyl(1.2, 3.6, 1.5, (0, 0, 11.1), STEEL, segs=20)
    return m.finish()


def sign():
    m = Model("sign")
    m.box((0.14, 0.14, 3.2), (-1.0, 0, 1.6), STEEL)
    m.box((0.14, 0.14, 3.2), (1.0, 0, 1.6), STEEL)
    m.box((3.2, 0.09, 1.6), (0, -0.06, 2.8), SIGN_GREEN)
    for z, w in ((3.2, 2.3), (2.75, 1.6), (2.35, 2.0)):
        m.box((w, 0.05, 0.13), (0, -0.13, z), SIGN_WHITE)
    return m.finish()


def wheat():
    """One tuft of stalks. Godot scatters thousands of these with a MultiMesh."""
    m = Model("wheat")
    for _ in range(12):
        x, y = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
        height = rng.uniform(1.0, 1.55)
        lean_x, lean_y = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)
        w = 0.022
        m.poly([(x - w, y, 0), (x + w, y, 0), (x + lean_x + w * 0.5, y + lean_y, height),
                (x + lean_x - w * 0.5, y + lean_y, height)], [(0, 1, 2, 3)], WHEAT)
        tx, ty, h = x + lean_x, y + lean_y, 0.3
        m.poly([(tx - 0.05, ty, height - 0.02), (tx + 0.05, ty, height - 0.02),
                (tx + 0.02 + lean_x * 0.3, ty + lean_y * 0.3, height + h),
                (tx - 0.02 + lean_x * 0.3, ty + lean_y * 0.3, height + h)], [(0, 1, 2, 3)], WHEAT_HEAD)
    return m.finish()


def hood():
    """The player's truck, seen from the driver's seat, behind the keyboard."""
    m = Model("hood")
    w = 8.0
    # Blender +Y is down the road, so the hood runs toward -Y from the keyboard.
    m.poly([(-w, 0.2, 0.0), (w, 0.2, 0.0), (w, -9.0, 0.95), (-w, -9.0, 0.95),
            (-w, 0.2, -1.2), (w, 0.2, -1.2), (w, -9.0, -1.2), (-w, -9.0, -1.2)],
           [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], TRUCK)
    # No raised centre ridge: from the driver's seat it stood up in front of the middle keys.
    for side in (-1, 1):
        x = side * (w + 0.85)
        m.box((1.9, 9.6, 1.5), (x, -4.5, -0.25), TRUCK)
        m.cyl(0.72, 0.8, 0.3, (x, 0.42, 0.0), CHROME, segs=20, rot=(math.radians(90), 0, 0))
        m.cyl(0.58, 0.58, 0.32, (x, 0.48, 0.0), LAMP, segs=20, rot=(math.radians(90), 0, 0))
    m.box((w * 2 + 3.7, 0.5, 0.42), (0, 0.5, -1.15), CHROME)
    return m.finish()


export_all([silo, barn, house, water_tower, pole, fence, tree, sign, wheat, hood], OUT_DIR, PREVIEW)
