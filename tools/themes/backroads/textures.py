# Backroads art: tiling asphalt and soil, the moonlit sky panorama, the region logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/backroads/textures.py').read())"
import os
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/backroads/textures")


def asphalt():
    size = 1024
    img = mottled(size, "rgb(0.082,0.082,0.090)", None, "asphalt", 6.0)
    # Tar-sealed cracks run along the road and start and end at the same x, so
    # the texture still tiles as it scrolls.
    tar = add_layer(img, "tar", alpha=True)
    Gimp.context_set_foreground(color("rgb(0.012,0.012,0.016)"))
    Gimp.context_set_brush(Gimp.Brush.get_by_name("2. Hardness 100"))
    for _ in range(4):
        start = rng.randint(60, size - 60)
        x, points = start, []
        steps = 12
        for s in range(steps + 1):
            if s == steps:
                x = start
            points.extend([float(x), float(s * size / steps)])
            x = max(10, min(size - 10, x + rng.randint(-36, 36)))
        Gimp.context_set_brush_size(rng.uniform(3.0, 7.0))
        Gimp.paintbrush_default(tar, points)
    save_png(img, "asphalt.png")
    img.delete()


def ground():
    img = mottled(1024, "rgb(0.13,0.10,0.055)", None, "ground", 9.0)
    save_png(img, "ground.png")
    img.delete()


def sky():
    w, h = 4096, 2048
    horizon = int(h * 0.5)
    img = new_image(w, h)
    base = add_layer(img, "base", "rgb(0.006,0.010,0.038)")
    # Night overhead, easing to a low warm band of last light at the horizon.
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * 0.12), w, horizon - int(h * 0.12))
    gradient(base, "rgb(0.006,0.010,0.038)", "rgb(0.030,0.052,0.150)", h * 0.12, horizon * 0.86)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(horizon * 0.86), w, int(horizon * 0.14) + 2)
    gradient(base, "rgb(0.030,0.052,0.150)", "rgb(0.42,0.17,0.10)", horizon * 0.86, float(horizon))
    Gimp.Selection.none(img)

    # Stars: thresholded noise, softened, screened over the sky and thinned near the horizon.
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=4242)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.965, 1.0)
    gegl(stars, "gegl:gaussian-blur", std_dev_x=0.7, std_dev_y=0.7)
    mask = stars.create_mask(Gimp.AddMaskType.WHITE)
    stars.add_mask(mask)
    gradient(mask, "white", "black", horizon * 0.5, horizon * 0.95)

    # Moon dead ahead of the road, low enough to sit in frame, with a soft halo.
    mx, my, radius = w * 0.5, h * 0.435, 52
    halo = add_layer(img, "halo", alpha=True, mode=Gimp.LayerMode.SCREEN)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - radius * 2.2, my - radius * 2.2, radius * 4.4, radius * 4.4)
    fill_selection(img, halo, "rgb(0.72,0.72,0.56)")
    gegl(halo, "gegl:gaussian-blur", std_dev_x=70.0, std_dev_y=70.0)
    moon = add_layer(img, "moon", alpha=True)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - radius, my - radius, radius * 2, radius * 2)
    fill_selection(img, moon, "rgb(1.0,0.96,0.82)")
    craters = add_layer(img, "craters", alpha=True, mode=Gimp.LayerMode.MULTIPLY, opacity=55.0)
    for _ in range(14):
        cr = rng.uniform(5, 15)
        cx, cy = mx + rng.uniform(-34, 34), my + rng.uniform(-34, 34)
        img.select_ellipse(Gimp.ChannelOps.REPLACE, cx - cr, cy - cr, cr * 2, cr * 2)
        fill_selection(img, craters, "rgb(0.72,0.68,0.62)")
    gegl(craters, "gegl:gaussian-blur", std_dev_x=2.5, std_dev_y=2.5)

    land = add_layer(img, "land", alpha=True)
    ridge(img, land, horizon + 2, 62, "rgb(0.022,0.030,0.062)", 11)
    ridge(img, land, horizon + 6, 32, "rgb(0.008,0.012,0.024)", 12)
    save_png(img, "sky.png")
    img.delete()


asphalt()
ground()
sky()
wordmark("BACKROADS", "region_logo.png", ["Rockwell Bold", "American Typewriter Bold", "Georgia Bold"],
         110, "rgb(1.0,0.86,0.6)", "rgb(0.95,0.45,0.12)")
print("TEXTURES DONE")
