# Red Mesa art: sun-bleached asphalt, red desert gravel, the dusk sky panorama, the region logo.
# The sky is a 4096x2048 equirectangular panorama with the horizon at half height. From the play
# camera only a band about 1000 px wide (x 1550 to 2550) and 125 px tall above the horizon shows,
# so the storm, the glow and the distant mesas are composed inside that window.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/mesa/textures.py').read())"
import os
import random
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
import paintkit  # noqa: E402
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/mesa/textures")


def save_png(img, name):  # noqa: F811
    """paintkit.save_png, but written to a temp folder and renamed into place. Other regions run
    Godot imports while this paints, and a scan that caught the 1.5 MB sky half-written marked its
    import invalid (and Godot then never retried it)."""
    flat = img.duplicate()
    flat.merge_visible_layers(Gimp.MergeType.CLIP_TO_IMAGE)
    tmp = os.path.join(tempfile.mkdtemp(prefix="mesa_tex_"), name)
    Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, flat, Gio.File.new_for_path(tmp), None)
    flat.delete()
    path = os.path.join(paintkit.OUT, name)
    shutil.move(tmp, path)
    print("WROTE", name, os.path.getsize(path) // 1024, "KB")


paintkit.save_png = save_png  # wordmark() saves through it too


def crack(layer, size, start, along_y, wander, steps=12):
    """A tar-sealed crack that starts and ends at the same offset, so the tile still wraps."""
    pos, points = start, []
    for s in range(steps + 1):
        if s == steps:
            pos = start
        t = float(s * size / steps)
        points.extend([float(pos), t] if along_y else [t, float(pos)])
        pos = max(10, min(size - 10, pos + rng.randint(-wander, wander)))
    Gimp.paintbrush_default(layer, points)


def asphalt():
    size = 1024
    img = mottled(size, "rgb(0.118,0.108,0.100)", None, "asphalt", 6.0)
    # Pale aggregate showing through the worn binder.
    grit = add_layer(img, "grit", "gray", Gimp.LayerMode.SCREEN, 22.0)
    gegl(grit, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=771)
    grit.threshold(Gimp.HistogramChannel.VALUE, 0.9, 1.0)
    # Sun-faded patches, kept off the edges so the tile wraps.
    fade = add_layer(img, "fade", alpha=True, opacity=16.0)
    for _ in range(6):
        r = rng.uniform(50, 110)
        x, y = rng.uniform(140, size - 140), rng.uniform(140, size - 140)
        img.select_ellipse(Gimp.ChannelOps.ADD, x - r, y - r * 0.6, r * 2, r * 1.2)
    fill_selection(img, fade, "rgb(0.24,0.22,0.2)")
    gegl(fade, "gegl:gaussian-blur", std_dev_x=28.0, std_dev_y=28.0)
    tar = add_layer(img, "tar", alpha=True)
    Gimp.context_set_foreground(color("rgb(0.016,0.014,0.014)"))
    Gimp.context_set_brush(Gimp.Brush.get_by_name("2. Hardness 100"))
    for start in (190, 520, 850):
        Gimp.context_set_brush_size(rng.uniform(3.0, 6.0))
        crack(tar, size, start + rng.randint(-60, 60), True, 34)
    for _ in range(2):
        Gimp.context_set_brush_size(rng.uniform(2.5, 4.5))
        crack(tar, size, rng.randint(120, size - 120), False, 22)
    save_png(img, "asphalt.png")
    img.delete()


def ground():
    img = mottled(1024, "rgb(0.42,0.15,0.068)", None, "ground", 7.0)
    # Dark pebbles and pale grit over the red sand.
    pebbles = add_layer(img, "pebbles", "gray", Gimp.LayerMode.MULTIPLY, 70.0)
    gegl(pebbles, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=1313)
    pebbles.threshold(Gimp.HistogramChannel.VALUE, 0.06, 1.0)
    gegl(pebbles, "gegl:gaussian-blur", std_dev_x=0.8, std_dev_y=0.8)
    grit = add_layer(img, "grit", "gray", Gimp.LayerMode.SCREEN, 30.0)
    gegl(grit, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=2626)
    grit.threshold(Gimp.HistogramChannel.VALUE, 0.94, 1.0)
    save_png(img, "ground.png")
    img.delete()


def mesa_line(img, layer, base_y, css, shapes):
    """Flat-topped mesas and buttes on the horizon: talus, cliff, a plateau with a step or two.
    Each shape is (x, width, height) in pixels. The line starts and ends at base_y so it wraps."""
    w, h = img.get_width(), img.get_height()
    pts = [0.0, float(base_y)]
    for x, width, height in sorted(shapes):
        talus = min(width * 0.22, 26 + height * 0.5)
        cliff = 3 + height * 0.12
        top = base_y - height
        step = rng.uniform(-0.12, 0.12) * height
        pts.extend([x, base_y, x + talus, base_y - height * 0.32, x + talus + cliff, top,
                    x + width * 0.5, top, x + width * 0.5 + 2, top + step,
                    x + width - talus - cliff, top + step, x + width - talus, base_y - height * 0.3,
                    x + width, base_y])
    pts.extend([float(w), float(base_y), float(w), float(h), 0.0, float(h)])
    img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
    fill_selection(img, layer, css)


def random_shapes(seed, count, hmin, hmax, avoid=(1500, 2600)):
    r = random.Random(seed)
    shapes, x = [], 40.0
    while x < 4000 and len(shapes) < count:
        width = r.uniform(90, 420)
        if not (avoid[0] - width < x < avoid[1]) and x + width < 4060:
            shapes.append((x, width, r.uniform(hmin, hmax)))
        x += width + r.uniform(60, 300)
    return shapes


def sky():
    w, h = 4096, 2048
    horizon = int(h * 0.5)
    img = new_image(w, h)
    base = add_layer(img, "base", "rgb(0.006,0.005,0.022)")
    # Near-black indigo overhead, through maroon, to a hot red-orange band of last light.
    # The top of the play view is about 11 degrees up (y 900), so indigo reaches down to there.
    bands = [(0.30, 0.44, "rgb(0.004,0.003,0.016)", "rgb(0.012,0.007,0.036)"),
             (0.44, 0.466, "rgb(0.012,0.007,0.036)", "rgb(0.12,0.026,0.05)"),
             (0.466, 0.486, "rgb(0.15,0.032,0.06)", "rgb(0.52,0.12,0.045)"),
             (0.486, 0.5, "rgb(0.52,0.12,0.045)", "rgb(0.93,0.38,0.10)")]
    for top, bottom, a, b in bands:
        y0, y1 = int(h * top), int(h * bottom)
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, y0, w, y1 - y0 + 1)
        gradient(base, a, b, float(y0), float(y1))
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, horizon, w, h - horizon)
    fill_selection(img, base, "rgb(0.02,0.006,0.007)")

    # Where the sun went down: a wide, low glow just right of the road.
    glow = add_layer(img, "glow", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, w * 0.52 - 700, horizon - 70, 1400, 140)
    fill_selection(img, glow, "rgb(0.62,0.24,0.06)")
    gegl(glow, "gegl:gaussian-blur", std_dev_x=110.0, std_dev_y=28.0)

    # Stars: thresholded noise, screened over the sky, thinned toward the horizon.
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=5151)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.968, 1.0)
    gegl(stars, "gegl:gaussian-blur", std_dev_x=0.7, std_dev_y=0.7)
    mask = stars.create_mask(Gimp.AddMaskType.WHITE)
    stars.add_mask(mask)
    gradient(mask, "white", "black", h * 0.40, h * 0.468)

    # A thunderstorm off to the left of the road: dark towers with an underside lit red by the
    # last light, rain shafts hanging to the horizon, and a faint glow of lightning inside.
    # (GEGL "rgb()" colours are linear light, so storm darks have to be very low numbers.)
    r = random.Random(77)
    cloud_base = horizon - 40
    puffs = []
    for _ in range(120):
        x = r.uniform(1060, 2010)
        tower = 50 + 290 * max(0.0, 1.0 - abs(x - 1560) / 430) ** 0.8
        rx, ry = r.uniform(30, 90), r.uniform(18, 48)
        y = cloud_base - ry * 0.5 - r.uniform(0, tower)
        puffs.append((x, y, rx, ry))
    rain = add_layer(img, "rain", alpha=True, opacity=55.0)
    for _ in range(10):
        x = r.uniform(1150, 1900)
        width = r.uniform(26, 80)
        slant = r.uniform(-34, 8)
        img.select_polygon(Gimp.ChannelOps.ADD, [x, cloud_base - 20, x + width, cloud_base - 20,
                                                 x + width + slant, horizon + 4, x + slant, horizon + 4])
    fill_selection(img, rain, "rgb(0.035,0.012,0.022)")
    gegl(rain, "gegl:gaussian-blur", std_dev_x=16.0, std_dev_y=5.0)
    # The underside catches the red light from the horizon: a glowing strip under a flat base.
    lit = add_layer(img, "storm_lit", alpha=True)
    for x, y, rx, ry in puffs:
        if y + ry > cloud_base - 40:
            img.select_ellipse(Gimp.ChannelOps.ADD, x - rx, y - ry + 8, rx * 2, ry * 2)
    img.select_rectangle(Gimp.ChannelOps.INTERSECT, 0, 0, w, cloud_base + 7)
    fill_selection(img, lit, "rgb(0.72,0.19,0.05)")
    gegl(lit, "gegl:gaussian-blur", std_dev_x=7.0, std_dev_y=4.0)
    storm = add_layer(img, "storm", alpha=True)
    for x, y, rx, ry in puffs:
        img.select_ellipse(Gimp.ChannelOps.ADD, x - rx, y - ry, rx * 2, ry * 2)
    img.select_rectangle(Gimp.ChannelOps.INTERSECT, 0, 0, w, cloud_base)
    fill_selection(img, storm, "rgb(0.02,0.009,0.017)")
    # Only a ~1000 px slice of the panorama fills the screen, so edges are kept crisp here.
    gegl(storm, "gegl:gaussian-blur", std_dev_x=1.2, std_dev_y=1.2)
    # Billows: the upper side of each puff picks up a little maroon twilight.
    shade = add_layer(img, "storm_shade", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=55.0)
    for x, y, rx, ry in puffs[::2]:
        if y < cloud_base - 30:
            img.select_ellipse(Gimp.ChannelOps.ADD, x - rx * 0.75, y - ry * 0.95, rx * 1.3, ry * 0.8)
    fill_selection(img, shade, "rgb(0.06,0.018,0.03)")
    gegl(shade, "gegl:gaussian-blur", std_dev_x=6.0, std_dev_y=6.0)
    flash = add_layer(img, "flash", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=40.0)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, 1470, cloud_base - 130, 200, 100)
    fill_selection(img, flash, "rgb(0.3,0.18,0.42)")
    gegl(flash, "gegl:gaussian-blur", std_dev_x=36.0, std_dev_y=26.0)

    # Distant mesas: a dusky far line and a darker near line, with a few placed in the view window.
    far = add_layer(img, "far_mesas", alpha=True)
    mesa_line(img, far, horizon + 1, "rgb(0.25,0.07,0.068)",
              [(1590, 270, 34), (1890, 110, 54), (2140, 340, 27), (2440, 190, 42)]
              + random_shapes(11, 14, 14, 46))
    near = add_layer(img, "near_mesas", alpha=True)
    mesa_line(img, near, horizon + 3, "rgb(0.02,0.006,0.007)",
              [(1430, 320, 19), (2310, 400, 23)] + random_shapes(23, 12, 8, 28))
    save_png(img, "sky.png")
    img.delete()


asphalt()
ground()
sky()
wordmark("RED MESA", "region_logo.png", ["Impact", "Rockwell Extra Bold", "Futura Condensed ExtraBold",
                                         "Arial Black", "Arial Bold"],
         110, "rgb(1.0,0.36,0.07)", "rgb(0.95,0.05,0.01)")
print("TEXTURES DONE")
