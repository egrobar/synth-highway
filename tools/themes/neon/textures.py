# Neon Sprawl art: wet asphalt (albedo and a puddle roughness map), dark concrete for the
# streets far below, the light-polluted city sky panorama, and the region logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/neon/textures.py').read())"
#
# asphalt_rough.png is not one of the standard tiles: game/scripts/themes/neon.gd loads it as
# the road's roughness texture, so the puddles stay glossy and catch screen-space reflections.
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/neon/textures")
PUDDLE_SEED = 7731


def puddles(layer, size):
    """Puddles stretched along the road like standing water in the wheel ruts, tileable.
    Shared by the albedo and the roughness map, so the glossy patches are the darker ones."""
    gegl(layer, "gegl:noise-solid", x_size=10.0, y_size=2.5, detail=3, tileable=True, turbulent=False,
         seed=PUDDLE_SEED, width=size, height=size)


def asphalt():
    size = 1024
    img = mottled(size, "rgb(0.032,0.032,0.045)", None, "asphalt", 7.0)
    # Wet patches are darker than dry tar.
    wet = add_layer(img, "wet", "gray", Gimp.LayerMode.MULTIPLY, 16.0)
    puddles(wet, size)
    # Bright noise blobs are the puddles; the inverted output range makes them the dark ones.
    # Soft-edged and faint: hard dark blobs read as camouflage under the headlights.
    wet.levels(Gimp.HistogramChannel.VALUE, 0.34, 0.42, True, 1.0, 1.0, 0.4, True)
    gegl(wet, "gegl:gaussian-blur", std_dev_x=9.0, std_dev_y=9.0)
    # A faint violet sheen smeared along the road (vertical in the tile). No cyan: that is the notes' colour.
    streak = add_layer(img, "streak", "black", Gimp.LayerMode.SCREEN, 9.0)
    gegl(streak, "gegl:noise-solid", x_size=22.0, y_size=1.0, detail=2, tileable=True, turbulent=False,
         seed=101, width=size, height=size)
    streak.levels(Gimp.HistogramChannel.VALUE, 0.45, 0.85, True, 1.0, 0.0, 1.0, True)
    streak.colorize_hsl(*hsl("rgb(0.8,0.3,1.0)"))
    gegl(streak, "gegl:gaussian-blur", std_dev_x=3.0, std_dev_y=12.0)
    save_png(img, "asphalt.png")
    img.delete()


def asphalt_rough():
    """Roughness for the road: puddles near-mirror (dark), the rest a damp satin (light)."""
    size = 1024
    img = new_image(size, size)
    base = add_layer(img, "rough", "gray")
    puddles(base, size)
    # Modest contrast: very glossy puddles mirror the dark scene and read as black spots.
    base.levels(Gimp.HistogramChannel.VALUE, 0.34, 0.42, True, 1.0, 0.58, 0.28, True)
    gegl(base, "gegl:gaussian-blur", std_dev_x=4.0, std_dev_y=4.0)
    grain = add_layer(img, "grain", "gray", Gimp.LayerMode.OVERLAY, 30.0)
    gegl(grain, "gegl:noise-rgb", red=0.3, green=0.3, blue=0.3, independent=False, seed=rng.randint(1, 99999))
    save_png(img, "asphalt_rough.png")
    img.delete()


def hsl(css):
    """Hue (degrees), saturation and lightness arguments for colorize_hsl from an rgb() string."""
    import colorsys
    r, g, b = (float(v) for v in css[4:-1].split(","))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360.0, s * 100.0, 0.0


def ground():
    """Dark wet concrete with slab joints: the streets seen far below the freeway."""
    size = 1024
    img = mottled(size, "rgb(0.05,0.048,0.065)", None, "ground", 8.0)
    joints = add_layer(img, "joints", alpha=True)
    Gimp.context_set_foreground(color("rgb(0.015,0.015,0.02)"))
    for i in range(4):
        p = i * size // 4 + 2
        img.select_rectangle(Gimp.ChannelOps.REPLACE, p, 0, 5, size)
        joints.edit_fill(Gimp.FillType.FOREGROUND)
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, p, size, 5)
        joints.edit_fill(Gimp.FillType.FOREGROUND)
    Gimp.Selection.none(img)
    save_png(img, "ground.png")
    img.delete()


def skyline(img, layer, base_y, low, high, width_range, css, seed, spikes=0.0):
    """Blocky city silhouette along the horizon; wraps across the panorama seam.
    Leaves the buildings selected so the caller can light windows in them."""
    r = random.Random(seed)
    w = img.get_width()
    x = 0.0
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, base_y, w, img.get_height() - base_y)
    while x < w:
        bw = r.uniform(*width_range)
        bh = r.uniform(low, high) * (1.6 if r.random() < 0.12 else 1.0)
        img.select_rectangle(Gimp.ChannelOps.ADD, x, base_y - bh, bw, bh + 2)
        if r.random() < spikes:
            img.select_rectangle(Gimp.ChannelOps.ADD, x + bw * 0.45, base_y - bh - r.uniform(8, 22), 2, 24)
        x += bw - r.uniform(0, 6)
    Gimp.context_set_foreground(color(css))
    layer.edit_fill(Gimp.FillType.FOREGROUND)


def windows(img, name, css, seed, cut, opacity):
    """Sparse lit windows inside the current selection, as a screen layer tinted one colour."""
    lit = add_layer(img, name, alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=opacity)
    Gimp.context_set_foreground(color("rgb(0.5,0.5,0.5)"))
    lit.edit_fill(Gimp.FillType.FOREGROUND)
    gegl(lit, "gegl:noise-rgb", red=1.0, green=1.0, blue=1.0, independent=False, seed=seed)
    gegl(lit, "gegl:pixelize", size_x=4, size_y=3)
    # levels as a hard threshold (threshold() left a grey wash inside a selection).
    # Output tops out below white, so colorize keeps the windows saturated.
    lit.levels(Gimp.HistogramChannel.VALUE, cut - 0.01, cut, True, 1.0, 0.0, 0.7, True)
    lit.colorize_hsl(*hsl(css))
    return lit


def sky():
    w, h = 4096, 2048
    horizon = int(h * 0.5)
    img = new_image(w, h)
    base = add_layer(img, "base", "rgb(0.010,0.005,0.030)")
    # Deep violet overhead, warming to a magenta city glow that peaks right at the horizon.
    bands = [
        (0.10, 0.30, "rgb(0.010,0.005,0.030)", "rgb(0.032,0.012,0.080)"),
        (0.30, 0.44, "rgb(0.032,0.012,0.080)", "rgb(0.120,0.030,0.200)"),
        (0.44, 0.49, "rgb(0.120,0.030,0.200)", "rgb(0.520,0.110,0.400)"),
        (0.49, 0.50, "rgb(0.520,0.110,0.400)", "rgb(0.820,0.300,0.460)"),
        (0.50, 0.56, "rgb(0.820,0.300,0.460)", "rgb(0.180,0.040,0.160)"),
    ]
    for top, bottom, css_top, css_bottom in bands:
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * top), w, int(h * (bottom - top)) + 2)
        gradient(base, css_top, css_bottom, h * top, h * bottom)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * 0.56), w, h - int(h * 0.56))
    fill_selection(img, base, "rgb(0.180,0.040,0.160)")

    # A few stars, nearly all drowned by light pollution: only the faintest high up.
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN, 45.0)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=5151)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.985, 1.0)
    mask = stars.create_mask(Gimp.AddMaskType.WHITE)
    stars.add_mask(mask)
    gradient(mask, "white", "black", horizon * 0.3, horizon * 0.8)

    # A big dim moon low and a little right of the road, half sunk in the haze.
    mx, my, radius = w * 0.5 + 150, horizon - 86, 64
    halo = add_layer(img, "halo", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=70.0)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - radius * 2.6, my - radius * 2.6, radius * 5.2, radius * 5.2)
    fill_selection(img, halo, "rgb(0.55,0.22,0.5)")
    gegl(halo, "gegl:gaussian-blur", std_dev_x=90.0, std_dev_y=90.0)
    moon = add_layer(img, "moon", alpha=True, opacity=62.0)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, mx - radius, my - radius, radius * 2, radius * 2)
    fill_selection(img, moon, "rgb(0.98,0.80,0.92)")
    craters = add_layer(img, "craters", alpha=True, mode=Gimp.LayerMode.MULTIPLY, opacity=22.0)
    for _ in range(7):
        cr = rng.uniform(8, 18)
        cx, cy = mx + rng.uniform(-36, 36), my + rng.uniform(-36, 36)
        img.select_ellipse(Gimp.ChannelOps.REPLACE, cx - cr, cy - cr, cr * 2, cr * 2)
        fill_selection(img, craters, "rgb(0.7,0.6,0.75)")
    gegl(craters, "gegl:gaussian-blur", std_dev_x=7.0, std_dev_y=7.0)

    # Haze: long horizontal smears of pink light lying over the moon and the far towers.
    haze = add_layer(img, "haze", "black", Gimp.LayerMode.SCREEN, 55.0)
    gegl(haze, "gegl:noise-solid", x_size=1.5, y_size=14.0, detail=3, tileable=True, turbulent=False,
         seed=3434, width=w, height=h)
    haze.levels(Gimp.HistogramChannel.VALUE, 0.35, 1.0, True, 1.0, 0.0, 0.7, True)
    haze.colorize_hsl(*hsl("rgb(0.9,0.3,0.7)"))
    hmask = haze.create_mask(Gimp.AddMaskType.BLACK)
    haze.add_mask(hmask)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, horizon - 260, w, 200)
    gradient(hmask, "black", "white", horizon - 260, horizon - 60)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, horizon - 62, w, 120)
    gradient(hmask, "white", "black", horizon - 60, horizon + 50)
    Gimp.Selection.none(img)

    # The far city: a hazy violet skyline behind a darker near one, both lit with windows.
    far = add_layer(img, "far_city", alpha=True)
    skyline(img, far, horizon + 4, 18, 64, (26, 90), "rgb(0.200,0.060,0.240)", 61, spikes=0.2)
    windows(img, "far_windows", "rgb(1.0,0.4,0.75)", 62, 0.79, 45.0)
    near = add_layer(img, "near_city", alpha=True)
    skyline(img, near, horizon + 6, 8, 40, (18, 70), "rgb(0.075,0.022,0.095)", 71, spikes=0.3)
    windows(img, "near_windows_pink", "rgb(1.0,0.25,0.7)", 72, 0.77, 90.0)
    windows(img, "near_windows_cyan", "rgb(0.2,0.85,1.0)", 73, 0.81, 80.0)
    windows(img, "near_windows_warm", "rgb(1.0,0.65,0.35)", 74, 0.80, 80.0)
    Gimp.Selection.none(img)
    save_png(img, "sky.png")
    img.delete()


def neon_wordmark(text, file_name, fonts, size, pad=120):
    """A neon-tube wordmark: pale pink face, hot pink tube edge and glow, and an offset cyan glow."""
    img = new_image(32, 32)
    font = pick_font(fonts)
    face = Gimp.TextLayer.new(img, text, font, size, Gimp.Unit.pixel())
    img.insert_layer(face, None, 0)
    face.set_color(color("rgb(1.0,0.88,0.97)"))
    face.set_letter_spacing(10.0)
    w, h = face.get_width() + pad * 2, face.get_height() + pad * 2
    img.resize(w, h, pad, pad)
    face.resize_to_image_size()
    # Inserted at position 1 each time, so the last one sits just under the face.
    for name, css, grow, blur, dx, dy, opacity in (
        ("cyan_glow", "rgb(0.1,0.85,1.0)", 6, 30.0, 10, 8, 100.0),
        ("pink_glow", "rgb(1.0,0.1,0.6)", 4, 14.0, 0, 0, 100.0),
        ("pink_tube", "rgb(1.0,0.2,0.68)", 4, 0.0, 0, 0, 100.0),
    ):
        layer = Gimp.Layer.new(img, name, w, h, Gimp.ImageType.RGBA_IMAGE, opacity, Gimp.LayerMode.NORMAL)
        img.insert_layer(layer, None, 1)
        layer.fill(Gimp.FillType.TRANSPARENT)
        img.select_item(Gimp.ChannelOps.REPLACE, face)
        Gimp.Selection.grow(img, grow)
        if dx or dy:
            Gimp.Selection.translate(img, dx, dy)
        Gimp.context_set_foreground(color(css))
        layer.edit_fill(Gimp.FillType.FOREGROUND)
        Gimp.Selection.none(img)
        if blur:
            gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    save_png(img, file_name)
    img.delete()


asphalt()
asphalt_rough()
ground()
sky()
neon_wordmark("NEON SPRAWL", "region_logo.png",
              ["Avenir Next Condensed Heavy Italic", "Futura Condensed ExtraBold", "Helvetica Neue Condensed Black",
               "Impact Regular"], 120)
print("TEXTURES DONE")
