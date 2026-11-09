# Aurora Pass art: snow-dusted asphalt, a snow ground tile, the night sky panorama with green and
# violet aurora curtains over snowy peaks dead ahead, and the region logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/aurora/textures.py').read())"
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/aurora/textures")


def fade(drawable, css, y_solid, y_clear):
    """Vertical colour-to-transparent gradient inside the current selection (paintkit's gradient()
    blends two colours; curtains and streaks need to fade out instead)."""
    Gimp.context_set_foreground(color(css))
    Gimp.context_set_gradient_fg_transparent()
    drawable.edit_gradient_fill(Gimp.GradientType.LINEAR, 0.0, False, 1, 0.0, True, 0.0, float(y_solid), 0.0,
                                float(y_clear))


def asphalt():
    size = 1024
    img = mottled(size, "rgb(0.070,0.074,0.086)", None, "asphalt", 6.0)
    # A faint dusting of powder, drawn out along the road. Tileable noise stretched down the road
    # (many cells across, few along) so it repeats seamlessly both ways; kept dim, because the notes
    # ride on this surface and a bright streak reads like a note trail.
    powder = add_layer(img, "powder", "gray", Gimp.LayerMode.SCREEN, 9.0)
    gegl(powder, "gegl:noise-solid", x_size=12.0, y_size=1.0, detail=3, tileable=True, turbulent=False,
         seed=rng.randint(1, 99999), width=size, height=size)
    powder.threshold(Gimp.HistogramChannel.VALUE, 0.7, 1.0)
    gegl(powder, "gegl:gaussian-blur", std_dev_x=6.0, std_dev_y=14.0)
    # Fine grains of salt and grit.
    grit = add_layer(img, "grit", "gray", Gimp.LayerMode.SCREEN, 30.0)
    gegl(grit, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=rng.randint(1, 99999))
    grit.threshold(Gimp.HistogramChannel.VALUE, 0.9, 1.0)
    save_png(img, "asphalt.png")
    img.delete()


def ground():
    size = 1024
    img = new_image(size, size)
    add_layer(img, "base", "rgb(0.50,0.55,0.64)")
    drifts = add_layer(img, "drifts", "gray", Gimp.LayerMode.SOFTLIGHT, 70.0)
    gegl(drifts, "gegl:noise-solid", x_size=3.0, y_size=5.0, detail=3, tileable=True, turbulent=False,
         seed=rng.randint(1, 99999), width=size, height=size)
    shade = add_layer(img, "shade", "gray", Gimp.LayerMode.MULTIPLY, 22.0)
    gegl(shade, "gegl:noise-solid", x_size=8.0, y_size=8.0, detail=4, tileable=True, turbulent=True,
         seed=rng.randint(1, 99999), width=size, height=size)
    speckle = add_layer(img, "speckle", "gray", Gimp.LayerMode.OVERLAY, 18.0)
    gegl(speckle, "gegl:noise-rgb", red=0.3, green=0.3, blue=0.3, independent=False, seed=rng.randint(1, 99999))
    # Frost glints: sparse single bright grains.
    glints = add_layer(img, "glints", "gray", Gimp.LayerMode.SCREEN, 55.0)
    gegl(glints, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=rng.randint(1, 99999))
    glints.threshold(Gimp.HistogramChannel.VALUE, 0.985, 1.0)
    save_png(img, "ground.png")
    img.delete()


def peaks(img, layer, base_y, amp, knots, seed, rock_css, snow_css=None, snow_depth=0.0):
    """A mountain range that wraps across the seam: alternating peaks and saddles. With a snow colour,
    the range is filled with snow and the rock is laid over it a little lower at each peak, so snow
    caps the summits and thins out toward the saddles."""
    r = random.Random(seed)
    w, h = img.get_width(), img.get_height()
    heights = [r.uniform(0.55, 1.0) if i % 2 == 0 else r.uniform(0.08, 0.42) for i in range(knots)]
    offsets = [r.uniform(-0.3, 0.3) for _ in range(knots)]
    pts = []
    for i in range(knots + 1):
        k = i % knots
        pts.append(((i + offsets[k] * (0 < i < knots)) * w / knots, base_y - heights[k] * amp))

    def fill(points, css):
        flat = [c for p in points for c in p] + [float(w), float(h), 0.0, float(h)]
        img.select_polygon(Gimp.ChannelOps.REPLACE, flat)
        fill_selection(img, layer, css)

    if snow_css:
        fill(pts, snow_css)
        lowered = []
        for i, (x, y) in enumerate(pts):
            k = i % knots
            depth = snow_depth * (heights[k] if k % 2 == 0 else 0.15) * r.uniform(0.7, 1.2)
            lowered.append((x, y + depth))
        # Extra knots between peak and saddle make the snow line ragged.
        ragged = []
        for (x0, y0), (x1, y1) in zip(lowered, lowered[1:]):
            ragged.append((x0, y0))
            for f in (0.33, 0.66):
                ragged.append((x0 + (x1 - x0) * f, y0 + (y1 - y0) * f + r.uniform(-snow_depth * 0.25,
                                                                                 snow_depth * 0.35)))
        ragged.append(lowered[-1])
        fill(ragged, rock_css)
    else:
        fill(pts, rock_css)


def aurora(img):
    """Green curtains rising behind the peaks ahead, violet above them, a bright hem along their feet,
    and a broad glow; all soft vertical streaks gathered into brighter folds.

    The game camera sees only about 12 degrees of sky above the horizon (panorama rows ~884 to 1024
    of 2048), so the curtains are short and low: green from behind the peaks to ~row 930, violet
    above that, cut off by the top of the screen."""
    w, h = img.get_width(), img.get_height()
    cx = w * 0.5
    glow = add_layer(img, "aurora_glow", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=35.0)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, cx - 1100, h * 0.5 - 150, 2200, 150)
    fill_selection(img, glow, "rgb(0.03,0.26,0.16)")
    gegl(glow, "gegl:gaussian-blur", std_dev_x=200.0, std_dev_y=40.0)

    green = add_layer(img, "aurora_green", alpha=True, mode=Gimp.LayerMode.SCREEN)
    violet = add_layer(img, "aurora_violet", alpha=True, mode=Gimp.LayerMode.SCREEN)
    hem = add_layer(img, "aurora_hem", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=80.0)
    x = cx - 1300.0
    while x < cx + 1300.0:
        width = rng.uniform(3.0, 11.0)
        # Folds: the curtain gathers into bright pleats with dim gaps between, swaying along its foot.
        near = math.exp(-((x - cx) / 750.0) ** 2)
        fold = max(0.0, math.sin(x / 61.0 + 2.2 * math.sin(x / 233.0))) ** 2.2
        foot = h * 0.5 - 24 + 7 * math.sin(x / 150.0) + 4 * math.sin(x / 41.0 + 1.0)
        tall = (34 + 26 * fold + rng.uniform(0, 16)) * (0.7 + 0.45 * near)
        bright = rng.uniform(0.55, 1.0) * (0.07 + 0.93 * fold) * (0.5 + 0.5 * near)
        g = f"rgb({0.06 * bright:.3f},{1.0 * bright:.3f},{0.50 * bright:.3f})"
        img.select_rectangle(Gimp.ChannelOps.REPLACE, x, foot - tall, width, tall)
        fade(green, g, foot - tall * 0.15, foot - tall)
        # Violet starts where the green has faded and climbs out of the top of the frame.
        top = foot - tall - rng.uniform(55, 110)
        img.select_rectangle(Gimp.ChannelOps.REPLACE, x, top, width, foot - tall * 0.7 - top)
        v = f"rgb({0.75 * bright:.3f},{0.12 * bright:.3f},{1.0 * bright:.3f})"
        fade(violet, v, foot - tall * 0.88, top)
        img.select_rectangle(Gimp.ChannelOps.REPLACE, x, foot - 6, width, 6)
        fill_selection(img, hem, f"rgb({0.45 * bright:.3f},{1.0 * bright:.3f},{0.70 * bright:.3f})")
        x += width + rng.uniform(0.0, 10.0)
    Gimp.Selection.none(img)
    gegl(green, "gegl:gaussian-blur", std_dev_x=3.0, std_dev_y=9.0)
    gegl(violet, "gegl:gaussian-blur", std_dev_x=5.0, std_dev_y=16.0)
    gegl(hem, "gegl:gaussian-blur", std_dev_x=2.5, std_dev_y=3.0)


def sky():
    w, h = 4096, 2048
    horizon = int(h * 0.5)
    img = new_image(w, h)
    base = add_layer(img, "base", "rgb(0.004,0.006,0.026)")
    # Night overhead, easing to a cold teal near the horizon where the aurora lights the air.
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * 0.1), w, horizon - int(h * 0.1))
    gradient(base, "rgb(0.004,0.006,0.026)", "rgb(0.012,0.030,0.068)", h * 0.1, horizon * 0.84)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(horizon * 0.84), w, int(horizon * 0.16) + 2)
    gradient(base, "rgb(0.012,0.030,0.068)", "rgb(0.035,0.085,0.110)", horizon * 0.84, float(horizon))
    Gimp.Selection.none(img)

    # Stars: thresholded noise, softened, screened over the sky and thinned toward the horizon.
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=8128)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.968, 1.0)
    gegl(stars, "gegl:gaussian-blur", std_dev_x=0.7, std_dev_y=0.7)
    mask = stars.create_mask(Gimp.AddMaskType.WHITE)
    stars.add_mask(mask)
    gradient(mask, "white", "black", horizon * 0.6, horizon * 0.97)

    aurora(img)

    land = add_layer(img, "land", alpha=True)
    # Peaks stay low (under ~60 rows) so they frame the curtains instead of hiding them.
    peaks(img, land, horizon + 4, 62, 40, 21, "rgb(0.050,0.066,0.100)", "rgb(0.24,0.30,0.39)", 22)
    peaks(img, land, horizon + 6, 34, 66, 22, "rgb(0.024,0.032,0.052)", "rgb(0.13,0.165,0.22)", 11)
    peaks(img, land, horizon + 8, 14, 140, 23, "rgb(0.008,0.013,0.022)")
    save_png(img, "sky.png")
    img.delete()


asphalt()
ground()
sky()
wordmark("AURORA PASS", "region_logo.png", ["Optima Bold", "Didot Bold", "Baskerville Bold", "Georgia Bold"],
         110, "rgb(0.90,1.0,0.96)", "rgb(0.24,0.95,0.62)")
print("TEXTURES DONE")
