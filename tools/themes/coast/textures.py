# Tidewater art (region id `coast`): a cold dark road deck with rime, frosted ice-and-rock
# ground with pale cracks, the navy-teal sky panorama with a giant banded gas giant rising
# out of the sea a little to the sea side (its light path on the water below it), a small
# icy second moon over the land, ice ridges, a far ice shelf with lights, and the logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/coast/textures.py').read())"
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/coast/textures")

# The gas giant's disc: its centre this many degrees right of straight down the road and
# above the horizon, and its radius. The sea shader in coast.gd reflects a disc of the same
# size and place, so these must match PLANET_YAW / PLANET_ELEVATION / PLANET_RADIUS there.
PLANET_YAW = 20.0
PLANET_ELEVATION = 1.5
PLANET_RADIUS = 7.5
MOON_YAW = -18.0  # the small icy moon, over the land side
MOON_ELEVATION = 6.5
# +1 when larger panorama x is to the driver's right (checked against a preview render).
RIGHT = 1
# Colours below are GEGL "rgb()" values, which are LINEAR light: rgb(0.04,...) is already a
# visible blue once written to the sRGB PNG. coast.gd's sea shader is given the sRGB
# equivalents of the colours just under the horizon, so sea and sky meet without a seam.


def asphalt():
    """The road deck: cold blue-black composite with a fine rime speckle and sealed seams."""
    size = 1024
    img = mottled(size, "rgb(0.028,0.034,0.046)", None, "deck", 5.0)
    # No frost drifts: tried, they read as pale blotches scrolling under the notes.
    rime = add_layer(img, "rime", "gray", Gimp.LayerMode.SCREEN, 30.0)
    gegl(rime, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=4242)
    rime.threshold(Gimp.HistogramChannel.VALUE, 0.975, 1.0)
    gegl(rime, "gegl:gaussian-blur", std_dev_x=0.6, std_dev_y=0.6)
    # Sealed panel seams run along the road and start and end at the same x, so the tile scrolls cleanly.
    tar = add_layer(img, "seams", alpha=True)
    Gimp.context_set_foreground(color("rgb(0.006,0.008,0.012)"))
    Gimp.context_set_brush(Gimp.Brush.get_by_name("2. Hardness 100"))
    for _ in range(3):
        start = rng.randint(80, size - 80)
        x, points = start, []
        steps = 10
        for s in range(steps + 1):
            if s == steps:
                x = start
            points.extend([float(x), float(s * size / steps)])
            x = max(10, min(size - 10, x + rng.randint(-14, 14)))
        Gimp.context_set_brush_size(rng.uniform(3.0, 5.0))
        Gimp.paintbrush_default(tar, points)
    add_layer(img, "tint", "rgb(0.70,0.85,1.0)", Gimp.LayerMode.MULTIPLY, 35.0)
    save_png(img, "asphalt.png")
    img.delete()


def ground():
    """Frosted ice over dark rock: blue-grey ice, rock showing through in patches, grit, and
    pale crack lines (contours of a tileable noise, so the tile wraps)."""
    size = 1024
    img = mottled(size, "rgb(0.120,0.160,0.205)", None, "ground", 6.0)
    rock = add_layer(img, "rock", "white", Gimp.LayerMode.MULTIPLY, 42.0)
    gegl(rock, "gegl:noise-solid", x_size=4.0, y_size=4.0, detail=4, tileable=True, turbulent=True,
         seed=6161, width=size, height=size)
    rock.threshold(Gimp.HistogramChannel.VALUE, 0.38, 1.0)
    gegl(rock, "gegl:gaussian-blur", std_dev_x=3.0, std_dev_y=3.0)
    grit = add_layer(img, "grit", "white", Gimp.LayerMode.MULTIPLY, 55.0)
    gegl(grit, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=777)
    grit.threshold(Gimp.HistogramChannel.VALUE, 0.0, 0.93)
    gegl(grit, "gegl:gaussian-blur", std_dev_x=1.2, std_dev_y=1.2)
    cracks = add_layer(img, "cracks", "black", Gimp.LayerMode.SCREEN, 22.0)
    gegl(cracks, "gegl:noise-solid", x_size=3.0, y_size=3.0, detail=2, tileable=True, turbulent=False,
         seed=8282, width=size, height=size)
    cracks.threshold(Gimp.HistogramChannel.VALUE, 0.497, 0.512)
    gegl(cracks, "gegl:gaussian-blur", std_dev_x=0.9, std_dev_y=0.9)
    add_layer(img, "tint", "rgb(0.74,0.88,1.0)", Gimp.LayerMode.MULTIPLY, 30.0)
    save_png(img, "ground.png")
    img.delete()


def wavy_band(img, layer, cx, cy, radius, d, css, tilt, seed):
    """Fills everything from a wavy band edge (d radii from the centre, across the tilted
    bands) to well past the disc's far side; painting bands top to bottom leaves no gaps."""
    r = random.Random(seed)
    ux, uy = math.cos(tilt), math.sin(tilt)
    nx, ny = -math.sin(tilt), math.cos(tilt)
    amp = radius * r.uniform(0.012, 0.035)
    freq, phase = r.uniform(3.0, 8.0), r.uniform(0, 6.283)
    pts = []
    steps = 48
    for i in range(steps + 1):
        s = (-1.4 + 2.8 * i / steps) * radius
        off = d * radius + amp * math.sin(freq * s / radius + phase) + amp * 0.5 * math.sin(2.7 * freq * s / radius)
        pts.extend([cx + ux * s + nx * off, cy + uy * s + ny * off])
    far = 1.6 * radius
    pts.extend([cx + ux * 1.4 * radius + nx * far, cy + uy * 1.4 * radius + ny * far,
                cx - ux * 1.4 * radius + nx * far, cy - uy * 1.4 * radius + ny * far])
    img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
    fill_selection(img, layer, css)


def clip_disc(img, layer, cx, cy, radius, horizon):
    """Keeps a layer only inside the disc and above the horizon (the sea hides the rest)."""
    img.select_ellipse(Gimp.ChannelOps.REPLACE, cx - radius, cy - radius, radius * 2, radius * 2)
    img.select_rectangle(Gimp.ChannelOps.SUBTRACT, 0, horizon, img.get_width(), img.get_height() - horizon)
    Gimp.Selection.invert(img)
    layer.edit_clear()
    Gimp.Selection.none(img)


def night_side(img, layer, cx, cy, radius, dx, dy, css, opacity):
    """Darkens the side of a disc turned away from the sun, painted straight onto the disc's own
    layer before it is clipped: a big dark disc offset by (dx, dy) radii, its selection feathered
    into a soft terminator, filled at `opacity`. Keep the offset mostly sideways: a shadow pushed
    downward falls below the horizon, where the sea hides it. (A separate shading layer, by
    radial gradient or by blurred fill, came out of the full sky with no visible effect.)"""
    r2 = radius * 1.25
    img.select_ellipse(Gimp.ChannelOps.REPLACE, cx + dx * radius - r2, cy + dy * radius - r2, r2 * 2, r2 * 2)
    Gimp.Selection.feather(img, radius * 0.6)
    Gimp.context_set_opacity(opacity)
    fill_selection(img, layer, css)
    Gimp.context_set_opacity(100.0)


def sky():
    w, h = 4096, 2048
    horizon = h // 2
    ppd = h / 180.0
    img = new_image(w, h)
    base = add_layer(img, "base", "rgb(0.002,0.004,0.010)")
    # Deep navy overhead to a cold teal on the horizon. The camera only sees about 11 degrees
    # above the horizon, so the blend lives low.
    bands = [(0, 0.30, "rgb(0.0015,0.003,0.008)", "rgb(0.004,0.010,0.022)"),
             (0.30, 0.44, "rgb(0.004,0.010,0.022)", "rgb(0.008,0.026,0.048)"),
             (0.44, 0.5, "rgb(0.008,0.026,0.048)", "rgb(0.026,0.080,0.100)"),
             (0.5, 0.52, "rgb(0.010,0.030,0.040)", "rgb(0.006,0.018,0.026)"),
             (0.52, 1.0, "rgb(0.006,0.018,0.026)", "rgb(0.002,0.004,0.008)")]
    for top, bottom, c0, c1 in bands:
        y0, y1 = int(h * top), int(h * bottom)
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, y0, w, y1 - y0)
        gradient(base, c0, c1, float(y0), float(y1))
    Gimp.Selection.none(img)

    # Stars, thinned toward the horizon and kept off the sea, and a few bright ones.
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=9191)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.968, 1.0)
    gegl(stars, "gegl:gaussian-blur", std_dev_x=0.7, std_dev_y=0.7)
    mask = stars.create_mask(Gimp.AddMaskType.WHITE)
    stars.add_mask(mask)
    gradient(mask, "white", "black", horizon * 0.55, horizon * 0.98)
    bright = add_layer(img, "bright_stars", alpha=True, mode=Gimp.LayerMode.SCREEN)
    s = random.Random(31)
    for _ in range(70):
        x, y = s.uniform(0, w), s.uniform(horizon * 0.55, horizon - 30)
        rad = s.uniform(1.2, 2.4)
        img.select_ellipse(Gimp.ChannelOps.REPLACE, x - rad, y - rad, rad * 2, rad * 2)
        fill_selection(img, bright, s.choice(["rgb(0.75,0.85,1.0)", "rgb(1.0,0.85,0.75)", "rgb(0.9,0.95,1.0)"]))
    gegl(bright, "gegl:gaussian-blur", std_dev_x=0.9, std_dev_y=0.9)

    px = w * 0.5 + RIGHT * PLANET_YAW * (w / 360.0)
    py = horizon - PLANET_ELEVATION * ppd
    radius = PLANET_RADIUS * ppd

    # The planet's light in the haze: a wide cream glow and a warm coral band on the horizon under it.
    glow = add_layer(img, "glow", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, px - radius * 3.2, py - radius * 2.2, radius * 6.4, radius * 4.4)
    fill_selection(img, glow, "rgb(0.040,0.050,0.056)")
    gegl(glow, "gegl:gaussian-blur", std_dev_x=150.0, std_dev_y=110.0)
    warm = add_layer(img, "warm_horizon", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, px - radius * 3.6, horizon - 28, radius * 7.2, 56)
    fill_selection(img, warm, "rgb(0.075,0.032,0.026)")
    gegl(warm, "gegl:gaussian-blur", std_dev_x=90.0, std_dev_y=14.0)

    # A far ice shelf low on the sea horizon beyond the planet, with a few station lights.
    far = add_layer(img, "far_shelf", alpha=True)
    r = random.Random(5)
    x0, x1 = px + RIGHT * radius * 1.5, px + RIGHT * (radius * 1.5 + 760)
    pts = [x0, float(horizon + 2)]
    x, top = x0, 0.0
    while (x - x1) * RIGHT < 0:
        top = r.choice([6.0, 9.0, 12.0, 14.0]) if r.random() < 0.35 else top or 9.0
        pts.extend([x, horizon - top])
        x += RIGHT * r.uniform(30, 90)
        pts.extend([x, horizon - top])
    pts.extend([x1, float(horizon + 2)])
    img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
    fill_selection(img, far, "rgb(0.007,0.016,0.026)")
    lights = add_layer(img, "far_lights", alpha=True, mode=Gimp.LayerMode.SCREEN)
    for k in range(5):
        lx = x0 + RIGHT * r.uniform(60, 720)
        img.select_ellipse(Gimp.ChannelOps.REPLACE, lx - 1.4, horizon - 6 - r.uniform(0, 4), 2.8, 2.8)
        fill_selection(img, lights, "rgb(1.0,0.40,0.30)" if k % 2 else "rgb(0.7,0.95,1.0)")
    gegl(lights, "gegl:gaussian-blur", std_dev_x=0.8, std_dev_y=0.8)

    # The gas giant: tilted teal, aqua, cream and coral bands with wavy edges and a pale
    # storm, its night side to the lower right, a thin atmospheric rim, all cut off by the sea
    # horizon. Teal-led on purpose: Io Burn has Jupiter's tans and its red spot.
    planet = add_layer(img, "planet", alpha=True)
    tilt = math.radians(-14.0)
    palette = [(-1.3, "rgb(0.06,0.14,0.18)"), (-0.88, "rgb(0.16,0.34,0.38)"), (-0.72, "rgb(0.40,0.58,0.58)"),
               (-0.58, "rgb(0.62,0.20,0.13)"), (-0.47, "rgb(0.62,0.52,0.38)"), (-0.31, "rgb(0.20,0.40,0.44)"),
               (-0.19, "rgb(0.62,0.72,0.68)"), (0.02, "rgb(0.66,0.56,0.42)"), (0.14, "rgb(0.55,0.18,0.12)"),
               (0.24, "rgb(0.30,0.50,0.52)"), (0.42, "rgb(0.50,0.44,0.34)"), (0.58, "rgb(0.14,0.28,0.32)"),
               (0.78, "rgb(0.06,0.12,0.16)")]
    for i, (d, css) in enumerate(palette):
        wavy_band(img, planet, px, py, radius, d, css, tilt, 400 + i)
    gegl(planet, "gegl:gaussian-blur", std_dev_x=1.4, std_dev_y=1.4)
    storm = add_layer(img, "storm", alpha=True)
    sx, sy = px - radius * 0.3, py - radius * 0.24
    img.select_ellipse(Gimp.ChannelOps.REPLACE, sx - radius * 0.19, sy - radius * 0.09, radius * 0.38, radius * 0.18)
    fill_selection(img, storm, "rgb(0.14,0.32,0.36)")
    img.select_ellipse(Gimp.ChannelOps.REPLACE, sx - radius * 0.13, sy - radius * 0.055, radius * 0.26, radius * 0.11)
    fill_selection(img, storm, "rgb(0.78,0.88,0.86)")
    gegl(storm, "gegl:gaussian-blur", std_dev_x=1.2, std_dev_y=1.0)
    planet = img.merge_down(storm, Gimp.MergeType.EXPAND_AS_NECESSARY)
    # Nearly opaque and only a little low: GEGL blends the fill in linear light, so 88% left the
    # night side looking about a third darker, and pushed 0.45 radii down most of the shadow sat
    # under the sea horizon (only the planet's top 60% shows).
    night_side(img, planet, px, py, radius, 1.1, 0.1, "rgb(0.003,0.008,0.016)", 97.0)
    clip_disc(img, planet, px, py, radius, horizon)
    rim = add_layer(img, "rim", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, px - radius - 2, py - radius - 2, radius * 2 + 4, radius * 2 + 4)
    img.select_ellipse(Gimp.ChannelOps.SUBTRACT, px - radius + 1, py - radius + 1, radius * 2 - 2, radius * 2 - 2)
    fill_selection(img, rim, "rgb(0.07,0.18,0.20)")
    gegl(rim, "gegl:gaussian-blur", std_dev_x=4.0, std_dev_y=4.0)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, horizon, w, h - horizon)
    rim.edit_clear()
    Gimp.Selection.none(img)

    # Its light on the water: a broad soft column and short bright dashes in its colours,
    # widening toward the viewer. coast.gd's sea shader draws the same path on the 3D sea.
    column = add_layer(img, "column", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_polygon(Gimp.ChannelOps.REPLACE, [px - radius * 0.7, float(horizon), px + radius * 0.7, float(horizon),
                                                 px + radius * 2.4, float(horizon + 330), px - radius * 2.4, float(horizon + 330)])
    fill_selection(img, column, "rgb(0.10,0.085,0.07)")
    gegl(column, "gegl:gaussian-blur", std_dev_x=40.0, std_dev_y=12.0)
    glitter = add_layer(img, "glitter", alpha=True, mode=Gimp.LayerMode.SCREEN)
    g = random.Random(77)
    for _ in range(620):
        depth = g.random() ** 1.6
        y = horizon + 2 + depth * 320
        spread = radius * 0.5 + depth * radius * 1.8
        x = px + g.gauss(0, spread * 0.45)
        dash = g.uniform(2, 7) + depth * g.uniform(4, 18)
        thick = 1.0 + depth * 2.0
        img.select_ellipse(Gimp.ChannelOps.REPLACE, x - dash / 2, y - thick / 2, dash, thick)
        b = g.uniform(0.5, 1.0) * (1.0 - depth * 0.55)
        warm_dash = g.random() < 0.35
        css = f"rgb({b:.3f},{b * 0.45:.3f},{b * 0.34:.3f})" if warm_dash else f"rgb({b:.3f},{b * 0.9:.3f},{b * 0.76:.3f})"
        fill_selection(img, glitter, css)
    gegl(glitter, "gegl:gaussian-blur", std_dev_x=0.8, std_dev_y=0.5)

    # The small icy moon over the land side, lit from the same quarter as the planet.
    mx = w * 0.5 + RIGHT * MOON_YAW * (w / 360.0)
    my = horizon - MOON_ELEVATION * ppd
    mr = 13.0
    halo = add_layer(img, "moon_halo", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - mr * 3, my - mr * 3, mr * 6, mr * 6)
    fill_selection(img, halo, "rgb(0.035,0.055,0.07)")
    gegl(halo, "gegl:gaussian-blur", std_dev_x=24.0, std_dev_y=24.0)
    moon = add_layer(img, "moon", alpha=True)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - mr, my - mr, mr * 2, mr * 2)
    fill_selection(img, moon, "rgb(0.62,0.72,0.80)")
    night_side(img, moon, mx, my, mr, 1.2, 0.5, "rgb(0.006,0.014,0.026)", 85.0)
    clip_disc(img, moon, mx, my, mr, horizon)
    streaks = add_layer(img, "moon_streaks", alpha=True, mode=Gimp.LayerMode.MULTIPLY, opacity=55.0)
    for k in range(4):
        y = my - mr + (k + 0.6) * mr * 0.48
        img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - mr * 0.9, y, mr * 1.8, 1.6)
        fill_selection(img, streaks, "rgb(0.55,0.62,0.70)")
    clip_disc(img, streaks, mx, my, mr, horizon)

    # Ice ridges on the land side, stepping back into the haze, kept off the sea half.
    land = add_layer(img, "land", alpha=True)
    ice_ridges(img, land, horizon + 2, 64, "rgb(0.030,0.052,0.074)", 21)
    ice_ridges(img, land, horizon + 4, 34, "rgb(0.004,0.008,0.014)", 22)
    save_png(img, "sky.png")
    img.delete()


def ice_ridges(img, layer, base_y, amp, css, seed):
    """Jagged ice ridges from behind the driver round the land side, dropping into the sea
    just short of the road's vanishing point."""
    r = random.Random(seed)
    w = img.get_width()
    centre = w * 0.5
    end = centre - RIGHT * (w / 360.0) * 2.0
    start = centre - RIGHT * (w / 360.0) * 175.0
    knots = 90
    pts = [start, float(base_y)]
    for i in range(knots + 1):
        t = i / knots
        taper = min(1.0, (1 - t) * 6.0)
        peak = r.uniform(0.3, 1.0) if i % 2 else r.uniform(0.15, 0.55)
        pts.extend([start + (end - start) * t, base_y - peak * amp * taper])
    pts.extend([end, float(base_y)])
    img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
    fill_selection(img, layer, css)


asphalt()
ground()
sky()
wordmark("TIDEWATER", "region_logo.png", ["Avenir Next Heavy", "Futura Bold", "Gill Sans Bold", "Helvetica Neue Bold"],
         110, "rgb(0.36,0.86,0.88)", "rgb(1.0,0.36,0.26)")
print("TEXTURES DONE")
