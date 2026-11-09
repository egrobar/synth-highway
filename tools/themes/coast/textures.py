# Coast Road art: sea-worn asphalt, a sandy scrub tile, the teal-to-violet sky panorama
# with a big moon low over the sea and its glitter path, and the region logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/coast/textures.py').read())"
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/coast/textures")

# The moon hangs this many degrees to the right of straight down the road, over the
# sea, so its glitter path lands on the water beside the road instead of under it.
# Must match MOON_YAW in game/scripts/themes/coast.gd.
MOON_YAW = 20.0
MOON_ELEVATION = 4.8  # degrees above the horizon; must match MOON_ELEVATION in coast.gd
# +1 when larger panorama x is to the driver's right (checked against a preview render).
RIGHT = 1
# Colours below are GEGL "rgb()" values, which are LINEAR light: rgb(0.04,...) is
# already a visible blue once written to the sRGB PNG. coast.gd's ocean shader is
# given the sRGB equivalents of the horizon colours, so sea and sky meet without a seam.


def asphalt():
    size = 1024
    img = mottled(size, "rgb(0.070,0.073,0.084)", None, "asphalt", 5.0)
    # Sealed seams run along the road and start and end at the same x, so the tile scrolls cleanly.
    tar = add_layer(img, "tar", alpha=True)
    Gimp.context_set_foreground(color("rgb(0.010,0.011,0.016)"))
    Gimp.context_set_brush(Gimp.Brush.get_by_name("2. Hardness 100"))
    for _ in range(3):
        start = rng.randint(80, size - 80)
        x, points = start, []
        steps = 10
        for s in range(steps + 1):
            if s == steps:
                x = start
            points.extend([float(x), float(s * size / steps)])
            x = max(10, min(size - 10, x + rng.randint(-24, 24)))
        Gimp.context_set_brush_size(rng.uniform(3.0, 6.0))
        Gimp.paintbrush_default(tar, points)
    save_png(img, "asphalt.png")
    img.delete()


def ground():
    size = 1024
    img = mottled(size, "rgb(0.150,0.128,0.095)", None, "ground", 7.0)
    # Pebbles and dark scrub patches: thresholded noise, blurred a touch, multiplied in.
    pebbles = add_layer(img, "pebbles", "white", Gimp.LayerMode.MULTIPLY, 70.0)
    gegl(pebbles, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=777)
    pebbles.threshold(Gimp.HistogramChannel.VALUE, 0.0, 0.93)
    gegl(pebbles, "gegl:gaussian-blur", std_dev_x=1.2, std_dev_y=1.2)
    patches = add_layer(img, "patches", "gray", Gimp.LayerMode.MULTIPLY, 55.0)
    gegl(patches, "gegl:noise-solid", x_size=3.0, y_size=3.0, detail=3, tileable=True, turbulent=False,
         seed=4321, width=size, height=size)
    tint = add_layer(img, "tint", "rgb(0.55,0.62,0.50)", Gimp.LayerMode.MULTIPLY, 30.0)
    save_png(img, "ground.png")
    img.delete()


def sky():
    w, h = 4096, 2048
    horizon = h // 2
    px_per_deg = h / 180.0
    img = new_image(w, h)
    base = add_layer(img, "base", "rgb(0.012,0.010,0.040)")
    # Indigo overhead, violet lower down, and a soft teal band on the sea horizon. The
    # camera only sees about 11 degrees above the horizon, so the blend lives low.
    bands = [(0, 0.30, "rgb(0.004,0.003,0.014)", "rgb(0.016,0.010,0.042)"),
             (0.30, 0.445, "rgb(0.016,0.010,0.042)", "rgb(0.058,0.030,0.120)"),
             (0.445, 0.5, "rgb(0.058,0.030,0.120)", "rgb(0.040,0.130,0.160)"),
             (0.5, 0.52, "rgb(0.012,0.032,0.045)", "rgb(0.007,0.019,0.030)"),
             (0.52, 1.0, "rgb(0.007,0.019,0.030)", "rgb(0.002,0.005,0.010)")]
    for top, bottom, c0, c1 in bands:
        y0, y1 = int(h * top), int(h * bottom)
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, y0, w, y1 - y0)
        gradient(base, c0, c1, float(y0), float(y1))
    Gimp.Selection.none(img)

    # Stars, thinned toward the horizon and kept off the sea.
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=9090)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.968, 1.0)
    gegl(stars, "gegl:gaussian-blur", std_dev_x=0.7, std_dev_y=0.7)
    mask = stars.create_mask(Gimp.AddMaskType.WHITE)
    stars.add_mask(mask)
    gradient(mask, "white", "black", horizon * 0.55, horizon * 0.97)

    mx = w * 0.5 + RIGHT * MOON_YAW * (w / 360.0)
    my = horizon - MOON_ELEVATION * px_per_deg
    radius = 44

    # The moon's light on the haze: a wide teal-white glow and a tighter warm halo.
    glow = add_layer(img, "glow", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - 420, my - 260, 840, 520)
    fill_selection(img, glow, "rgb(0.030,0.062,0.072)")
    gegl(glow, "gegl:gaussian-blur", std_dev_x=150.0, std_dev_y=110.0)
    halo = add_layer(img, "halo", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - radius * 2.3, my - radius * 2.3, radius * 4.6, radius * 4.6)
    fill_selection(img, halo, "rgb(0.40,0.39,0.33)")
    gegl(halo, "gegl:gaussian-blur", std_dev_x=60.0, std_dev_y=60.0)

    # A distant headland across the bay, low on the sea horizon past the moon.
    far = add_layer(img, "far_headland", alpha=True)
    r = random.Random(5)
    x0 = mx + RIGHT * 260
    x1 = mx + RIGHT * 900
    pts = [x0, float(horizon + 2)]
    steps = 16
    for i in range(steps + 1):
        t = i / steps
        hgt = (1 - abs(t - 0.62) / 0.62) ** 0.7 * 26 + r.uniform(-3, 3)
        pts.extend([x0 + (x1 - x0) * t, horizon - max(hgt, 0.0)])
    pts.extend([x1, float(horizon + 2)])
    img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
    fill_selection(img, far, "rgb(0.010,0.018,0.030)")

    moon = add_layer(img, "moon", alpha=True)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - radius, my - radius, radius * 2, radius * 2)
    fill_selection(img, moon, "rgb(1.0,0.97,0.87)")
    craters = add_layer(img, "craters", alpha=True, mode=Gimp.LayerMode.MULTIPLY, opacity=45.0)
    for _ in range(14):
        cr = rng.uniform(4, 13)
        cx, cy = mx + rng.uniform(-32, 32), my + rng.uniform(-32, 32)
        img.select_ellipse(Gimp.ChannelOps.REPLACE, cx - cr, cy - cr, cr * 2, cr * 2)
        fill_selection(img, craters, "rgb(0.74,0.72,0.70)")
    gegl(craters, "gegl:gaussian-blur", std_dev_x=2.5, std_dev_y=2.5)

    # The glitter path: short bright dashes on the dark water under the moon, widening
    # toward the viewer, over a soft column of reflected light.
    column = add_layer(img, "column", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_polygon(Gimp.ChannelOps.REPLACE, [mx - 14, float(horizon), mx + 14, float(horizon),
                                                 mx + 150, float(horizon + 330), mx - 150, float(horizon + 330)])
    fill_selection(img, column, "rgb(0.09,0.11,0.11)")
    gegl(column, "gegl:gaussian-blur", std_dev_x=26.0, std_dev_y=10.0)
    glitter = add_layer(img, "glitter", alpha=True, mode=Gimp.LayerMode.SCREEN)
    g = random.Random(77)
    for _ in range(520):
        depth = g.random() ** 1.6
        y = horizon + 2 + depth * 320
        spread = 10 + depth * 140
        x = mx + g.gauss(0, spread * 0.45)
        dash = g.uniform(2, 6) + depth * g.uniform(4, 16)
        thick = 1.0 + depth * 2.0
        img.select_ellipse(Gimp.ChannelOps.REPLACE, x - dash / 2, y - thick / 2, dash, thick)
        bright = g.uniform(0.55, 1.0) * (1.0 - depth * 0.55)
        fill_selection(img, glitter, f"rgb({bright:.3f},{bright * 0.97:.3f},{bright * 0.86:.3f})")
    gegl(glitter, "gegl:gaussian-blur", std_dev_x=0.8, std_dev_y=0.5)

    # The coast on the land side: hills stepping back into the haze, kept off the sea half.
    land = add_layer(img, "land", alpha=True)
    coast_hills(img, land, horizon + 2, 70, "rgb(0.014,0.016,0.036)", 21, mx)
    coast_hills(img, land, horizon + 4, 38, "rgb(0.004,0.005,0.011)", 22, mx)
    save_png(img, "sky.png")
    img.delete()


def coast_hills(img, layer, base_y, amp, css, seed, moon_x):
    """Hills that run from behind the driver round the land side, and drop into the
    sea just short of the road's vanishing point."""
    r = random.Random(seed)
    w = img.get_width()
    centre = w * 0.5
    # On the land side, the hills cover from straight ahead (less 2 degrees) to behind.
    end = centre - RIGHT * (w / 360.0) * 2.0
    start = centre - RIGHT * (w / 360.0) * 175.0
    knots = 40
    pts = [start, float(base_y)]
    for i in range(knots + 1):
        t = i / knots
        taper = min(1.0, (1 - t) * 6.0)  # the last stretch slopes down to the water
        pts.extend([start + (end - start) * t, base_y - (r.uniform(0.35, 1.0) * amp) * taper])
    pts.extend([end, float(base_y)])
    img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
    fill_selection(img, layer, css)


asphalt()
ground()
sky()
wordmark("COAST ROAD", "region_logo.png", ["Futura Bold", "Avenir Next Heavy", "Gill Sans Bold", "Helvetica Neue Bold"],
         110, "rgb(1.0,0.40,0.29)", "rgb(0.06,0.62,0.60)")
print("TEXTURES DONE")
