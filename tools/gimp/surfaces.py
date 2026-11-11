"""The shared surface library: tileable greyscale detail maps for props, run inside GIMP's batch Python.

Every region's props are flat-coloured low-poly models. prop_detail.gdshader projects one of these
maps onto a prop from three sides (triplanar, in the model's own space), so no prop needs UVs:
the map's tone modulates the prop's own colour, and its slopes become surface relief (dark reads as
low: seams, cracks and pits sink; rivets and ribs stand up). A prop material picks its map by name
(ThemeWorld.SURFACE_KEYWORDS, or a region's `surfaces` table).

Writes game/assets/surfaces/<name>.png, 1024 px square, tiling on every edge. Neutral grey is
0.5 as stored; the shader re-centres on each map's own average, so a map may run light or dark.
Run by tools/build_assets.sh (shared section), or alone:
  SYNTH_ROOT=$PWD gimp -i --quit --batch-interpreter=python-fu-eval -b "exec(open('tools/gimp/surfaces.py').read())"
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F401,F403

set_out("game/assets/surfaces")
S = 1024


def grey(v: float) -> str:
    return srgb(v, v, v)


def base(v: float = 0.5):
    img = new_image(S, S)
    layer = add_layer(img, "base", grey(v))
    return img, layer


def noise_layer(img, mode, opacity, x_size, y_size, detail=3, turbulent=False, seed=1):
    layer = add_layer(img, "noise", "gray", mode, opacity)
    gegl(layer, "gegl:noise-solid", x_size=x_size, y_size=y_size, detail=detail, tileable=True,
         turbulent=turbulent, seed=seed, width=S, height=S)
    return layer


def grain(img, opacity=30.0, seed=1):
    layer = add_layer(img, "grain", "gray", Gimp.LayerMode.OVERLAY, opacity)
    gegl(layer, "gegl:noise-rgb", red=0.3, green=0.3, blue=0.3, independent=False, seed=seed)
    return layer


def fill_if_selected(img, layer, v):
    """Fills the selection, and nothing when it is empty: GIMP fills the WHOLE layer when nothing
    is selected, so a wrapped copy that lands off the canvas blacked out entire maps."""
    if Gimp.Selection.is_empty(img):
        return
    fill_selection(img, layer, grey(v))


def rect(img, layer, x, y, w, h, v):
    """A filled rectangle that wraps across the tile's edges, so features on a border tile."""
    for dx in (0, -S, S):
        for dy in (0, -S, S):
            if x + dx + w <= 0 or x + dx >= S or y + dy + h <= 0 or y + dy >= S:
                continue
            img.select_rectangle(Gimp.ChannelOps.REPLACE, x + dx, y + dy, w, h)
            fill_if_selected(img, layer, v)


def dot(img, layer, x, y, r, v):
    for dx in (0, -S, S):
        for dy in (0, -S, S):
            if x + dx + r <= 0 or x + dx - r >= S or y + dy + r <= 0 or y + dy - r >= S:
                continue
            img.select_ellipse(Gimp.ChannelOps.REPLACE, x + dx - r, y + dy - r, r * 2, r * 2)
            fill_if_selected(img, layer, v)


def crack(img, layer, rng, x, y, steps, v, width=2.4):
    """A wandering crack drawn as a chain of small dots, wrapping across the edges."""
    angle = rng.uniform(0, 6.283)
    for _ in range(steps):
        angle += rng.uniform(-0.6, 0.6)
        x = (x + 4.0 * math.cos(angle)) % S
        y = (y + 4.0 * math.sin(angle)) % S
        dot(img, layer, x, y, width * rng.uniform(0.6, 1.1), v)


def finish(img, name):
    save_png(img, name + ".png")
    img.delete()


# ---------------------------------------------------------------- the surfaces

def panel():
    """Hull plating: plates of a few sizes, dark seams with a shadow, rows of rivets along them."""
    rng = random.Random(11)
    img, layer = base(0.55)
    plates = add_layer(img, "plates", alpha=True)
    cols = [0, 256, 512, 768]
    for i, x in enumerate(cols):
        rows = [0, 512] if i % 2 == 0 else [0, 340, 680]
        for j, y in enumerate(rows):
            h = (rows[j + 1] if j + 1 < len(rows) else S) - y
            rect(img, plates, x, y, 256, h, rng.uniform(0.47, 0.62))
    noise_layer(img, Gimp.LayerMode.MULTIPLY, 22.0, 3.0, 3.0, seed=12)
    noise_layer(img, Gimp.LayerMode.MULTIPLY, 14.0, 1.0, 9.0, seed=13)  # faint vertical streaks
    grain(img, 18.0, 14)
    seams = add_layer(img, "seams", alpha=True)
    shade = add_layer(img, "seam_shadow", alpha=True, mode=Gimp.LayerMode.MULTIPLY, opacity=55.0)
    for i, x in enumerate(cols):
        rect(img, seams, x - 2, 0, 4, S, 0.12)
        rect(img, shade, x - 7, 0, 14, S, 0.45)
        rows = [0, 512] if i % 2 == 0 else [0, 340, 680]
        for y in rows:
            rect(img, seams, x, y - 2, 256, 4, 0.12)
            rect(img, shade, x, y - 7, 256, 14, 0.45)
    gegl(shade, "gegl:gaussian-blur", std_dev_x=3.0, std_dev_y=3.0)
    rivets = add_layer(img, "rivets", alpha=True)
    for i, x in enumerate(cols):
        for y in range(16, S, 32):
            dot(img, rivets, x + 12, y, 5.0, 0.3)
            dot(img, rivets, x + 12, y, 3.4, 0.86)
        rows = [0, 512] if i % 2 == 0 else [0, 340, 680]
        for y in rows:
            for k in range(1, 8):
                dot(img, rivets, x + k * 32, y + 12, 5.0, 0.3)
                dot(img, rivets, x + k * 32, y + 12, 3.4, 0.86)
    finish(img, "panel")


def concrete():
    """Cast concrete: mottled, pitted, with form-tie holes and two faint pour lines."""
    rng = random.Random(21)
    img, layer = base(0.56)
    noise_layer(img, Gimp.LayerMode.MULTIPLY, 45.0, 4.0, 4.0, detail=5, turbulent=True, seed=22)
    noise_layer(img, Gimp.LayerMode.OVERLAY, 35.0, 12.0, 12.0, detail=3, seed=23)
    grain(img, 30.0, 24)
    marks = add_layer(img, "marks", alpha=True)
    for _ in range(900):
        dot(img, marks, rng.uniform(0, S), rng.uniform(0, S), rng.uniform(0.8, 2.6), rng.uniform(0.18, 0.32))
    for gx in range(4):
        for gy in range(4):
            dot(img, marks, 128 + gx * 256, 128 + gy * 256, 9.0, 0.16)
            dot(img, marks, 128 + gx * 256, 128 + gy * 256, 5.0, 0.08)
    for y in (300, 760):
        rect(img, marks, 0, y, S, 3, 0.36)
    gegl(marks, "gegl:gaussian-blur", std_dev_x=0.7, std_dev_y=0.7)
    finish(img, "concrete")


def rock():
    """Bare rock: turbulent grain at two scales, faint strata, and wandering cracks."""
    rng = random.Random(31)
    img, layer = base(0.52)
    noise_layer(img, Gimp.LayerMode.MULTIPLY, 70.0, 5.0, 5.0, detail=6, turbulent=True, seed=32)
    noise_layer(img, Gimp.LayerMode.OVERLAY, 45.0, 2.0, 2.0, detail=4, seed=33)
    noise_layer(img, Gimp.LayerMode.OVERLAY, 25.0, 1.0, 14.0, detail=3, seed=34)  # strata
    grain(img, 35.0, 35)
    cracks = add_layer(img, "cracks", alpha=True)
    for _ in range(26):
        crack(img, cracks, rng, rng.uniform(0, S), rng.uniform(0, S), rng.randint(20, 70), 0.12)
    gegl(cracks, "gegl:gaussian-blur", std_dev_x=0.9, std_dev_y=0.9)
    finish(img, "rock")


def brushed():
    """Brushed metal: fine horizontal streaks and a few long scratches."""
    rng = random.Random(41)
    img, layer = base(0.55)
    noise_layer(img, Gimp.LayerMode.OVERLAY, 60.0, 1.0, 16.0, detail=4, seed=42)
    noise_layer(img, Gimp.LayerMode.MULTIPLY, 20.0, 2.0, 2.0, detail=3, seed=43)
    grain(img, 12.0, 44)
    scratches = add_layer(img, "scratches", alpha=True)
    for _ in range(40):
        x, y, w = rng.uniform(0, S), rng.uniform(0, S), rng.uniform(80, 400)
        rect(img, scratches, x, y, w, 1, rng.choice([0.3, 0.75]))
    finish(img, "brushed")


def grate():
    """Walkway grating: a bright frame of bars around dark slots."""
    img, layer = base(0.62)
    noise_layer(img, Gimp.LayerMode.MULTIPLY, 20.0, 3.0, 3.0, seed=52)
    slots = add_layer(img, "slots", alpha=True)
    for x in range(0, S, 32):
        for y in range(0, S, 64):
            rect(img, slots, x + 6, y + 6, 20, 52, 0.08)
    gegl(slots, "gegl:gaussian-blur", std_dev_x=1.0, std_dev_y=1.0)
    grain(img, 15.0, 53)
    finish(img, "grate")


def corrugated():
    """Corrugated sheet: rounded vertical ribs every 64 px, weathered."""
    img, layer = base(0.5)
    ribs = add_layer(img, "ribs", alpha=True)
    Gimp.context_set_foreground(color(grey(0.22)))
    Gimp.context_set_background(color(grey(0.82)))
    Gimp.context_set_gradient_fg_bg_rgb()
    Gimp.context_set_gradient_repeat_mode(Gimp.RepeatMode.TRIANGULAR)
    ribs.edit_gradient_fill(Gimp.GradientType.LINEAR, 0.0, False, 1, 0.0, True, 0.0, 0.0, 32.0, 0.0)
    Gimp.context_set_gradient_repeat_mode(Gimp.RepeatMode.NONE)
    noise_layer(img, Gimp.LayerMode.MULTIPLY, 25.0, 3.0, 6.0, detail=4, seed=62)
    grain(img, 15.0, 63)
    finish(img, "corrugated")


def ice():
    """Ice: smooth, with fine pale fractures and trapped bubbles."""
    rng = random.Random(71)
    img, layer = base(0.6)
    noise_layer(img, Gimp.LayerMode.OVERLAY, 40.0, 2.0, 2.0, detail=5, seed=72)
    fractures = add_layer(img, "fractures", alpha=True)
    for _ in range(18):
        crack(img, fractures, rng, rng.uniform(0, S), rng.uniform(0, S), rng.randint(15, 60), 0.85, 1.2)
    for _ in range(14):
        crack(img, fractures, rng, rng.uniform(0, S), rng.uniform(0, S), rng.randint(10, 40), 0.3, 1.4)
    for _ in range(260):
        dot(img, fractures, rng.uniform(0, S), rng.uniform(0, S), rng.uniform(1.0, 3.5), 0.82)
    gegl(fractures, "gegl:gaussian-blur", std_dev_x=0.8, std_dev_y=0.8)
    finish(img, "ice")


def membrane():
    """Woven membrane (dome skins, tents, crop tubes): a fine weave over soft folds."""
    img, layer = base(0.55)
    weave = add_layer(img, "weave", alpha=True)
    for i in range(0, S, 8):
        rect(img, weave, i, 0, 2, S, 0.38)
        rect(img, weave, 0, i + 4, S, 2, 0.66)
    gegl(weave, "gegl:gaussian-blur", std_dev_x=0.6, std_dev_y=0.6)
    noise_layer(img, Gimp.LayerMode.OVERLAY, 40.0, 2.0, 5.0, detail=3, seed=82)
    finish(img, "membrane")


for build in (panel, concrete, rock, brushed, grate, corrugated, ice, membrane):
    build()
print("DONE surfaces")
