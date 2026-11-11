# Red Frontier art (region id `backroads`): a dusty rust road of sintered regolith, rust-red
# regolith ground, the Mars dusk sky panorama, and the region logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/backroads/textures.py').read())"
#
# Colours here are written as they look on screen (sRGB) and go through srgb(), because GEGL
# reads "rgb(r,g,b)" as linear light: written directly, every colour came out pale and washed out.
#
# The sky is what you see on Mars just after sunset: butterscotch-pink, with the sunset's blue
# glow round the sun straight down the road (Martian dust scatters blue light forward), two
# small moons, the Earth as a bright evening star, and mesas and crater rims on the horizon.
# Only the band from the horizon to about 11 degrees above it is ever in shot (the camera looks
# down the road), so everything that matters sits there: within about 450 px of the centre
# column and 125 px of the horizon.
import colorsys
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/backroads/textures")


def srgb(r, g, b):
    """An on-screen (sRGB) colour as the linear rgb() string GEGL expects."""
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return "rgb(%.5f,%.5f,%.5f)" % (lin(r), lin(g), lin(b))


def hsl(r, g, b):
    """Hue (degrees) and saturation arguments for colorize_hsl from an sRGB colour (lightness kept)."""
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360.0, s * 100.0, 0.0


def soft_noise(img, name, tint, mode, opacity, x_size, y_size, seed, lo, hi, blur=0.0):
    """A tinted layer of tileable cloud noise, levelled so only its brightest blobs show.
    x_size and y_size are frequencies: a large x_size and small y_size stretch blobs vertically."""
    layer = add_layer(img, name, "black", mode, opacity)
    gegl(layer, "gegl:noise-solid", x_size=x_size, y_size=y_size, detail=3, tileable=True, turbulent=False,
         seed=seed, width=img.get_width(), height=img.get_height())
    layer.levels(Gimp.HistogramChannel.VALUE, lo, hi, True, 1.0, 0.0, 0.8, True)
    layer.colorize_hsl(*hsl(*tint))
    if blur:
        gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    return layer


def pebbles(img, name, rgb, count, r_from, r_to, seed, opacity=100.0, blur=0.6):
    """Small pebbles or grains as filled dots, kept off the edges so the tile still wraps."""
    r = random.Random(seed)
    size = img.get_width()
    layer = add_layer(img, name, alpha=True, opacity=opacity)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, 0, 1, 1)
    first = True
    for _ in range(count):
        rad = r.uniform(r_from, r_to)
        x, y = r.uniform(rad + 1, size - rad - 1), r.uniform(rad + 1, size - rad - 1)
        img.select_ellipse(Gimp.ChannelOps.REPLACE if first else Gimp.ChannelOps.ADD, x - rad, y - rad * 0.8,
                           rad * 2, rad * 1.6)
        first = False
    fill_selection(img, layer, srgb(*rgb))
    if blur:
        gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    return layer


def road():
    """Sintered regolith slabs, dark rust-brown so the cyan notes read, with faint wind-laid dust
    across it, pebbles, and seams every half tile (they scroll past, so the road reads as moving)."""
    size = 1024
    img = mottled(size, srgb(0.27, 0.15, 0.115), None, "road", 7.0)
    soft_noise(img, "dust", (0.62, 0.38, 0.25), Gimp.LayerMode.SCREEN, 9.0, 1.5, 9.0, 3101, 0.55, 1.0, 8.0)
    pebbles(img, "pebbles_dark", (0.06, 0.035, 0.03), 420, 1.2, 3.2, 3103, 70.0)
    pebbles(img, "pebbles_light", (0.42, 0.27, 0.2), 160, 1.0, 2.4, 3105, 55.0)
    # Slab seams: across the road every 512 px, and along it in a brick bond, so the tile wraps.
    seams = add_layer(img, "seams", alpha=True, opacity=55.0)
    Gimp.context_set_foreground(color(srgb(0.04, 0.025, 0.02)))
    for y in (0, 512):
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, y, size, 6)
        seams.edit_fill(Gimp.FillType.FOREGROUND)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, 0, 5, 512)
    seams.edit_fill(Gimp.FillType.FOREGROUND)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 510, 512, 5, 512)
    seams.edit_fill(Gimp.FillType.FOREGROUND)
    Gimp.Selection.none(img)
    gegl(seams, "gegl:gaussian-blur", std_dev_x=1.2, std_dev_y=1.2)
    save_png(img, "road.png")
    img.delete()


def ground():
    """Rust-red regolith: oxide mottling, paler wind-blown dust, dark basalt grit, pale grains."""
    size = 1024
    img = mottled(size, srgb(0.66, 0.29, 0.15), None, "ground", 9.0)
    soft_noise(img, "dust", (0.82, 0.5, 0.32), Gimp.LayerMode.SCREEN, 11.0, 3.0, 5.0, 4201, 0.55, 1.0, 8.0)
    pebbles(img, "grit", (0.16, 0.07, 0.045), 900, 1.0, 3.5, 4203, 80.0)
    pebbles(img, "stones", (0.2, 0.09, 0.06), 70, 4.0, 9.0, 4205, 85.0, 1.0)
    pebbles(img, "grains", (0.85, 0.6, 0.45), 260, 0.8, 1.8, 4207, 60.0)
    save_png(img, "ground.png")
    img.delete()


def mesas(img, layer, base_y, rgb, seed, count, h_range, w_range, clear=0.0):
    """Flat-topped mesas (talus slope, cliff, cap rock) along the horizon. Wraps the seam.
    `clear` keeps that many pixels either side of the centre column free, where the road heads."""
    r = random.Random(seed)
    w = img.get_width()
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, base_y, w, img.get_height() - base_y)
    placed = 0
    while placed < count:
        mw, mh = r.uniform(*w_range), r.uniform(*h_range)
        x0 = r.uniform(0, w)
        centre = x0 + mw / 2
        if clear and min(abs(centre - w / 2), abs(centre + w - w / 2)) < clear + mw / 2:
            continue
        placed += 1
        s1, s2 = mh * r.uniform(0.9, 1.7), mh * r.uniform(0.9, 1.7)
        cap = mh * r.uniform(0.0, 0.08)
        for shift in (0.0, -float(w)):
            x = x0 + shift
            pts = [x, base_y + 2.0, x + s1, base_y - mh * 0.5, x + s1 * 1.15, base_y - mh,
                   x + mw * 0.5, base_y - mh - cap, x + mw - s2 * 1.15, base_y - mh,
                   x + mw - s2, base_y - mh * 0.45, x + mw, base_y + 2.0]
            img.select_polygon(Gimp.ChannelOps.ADD, pts)
    fill_selection(img, layer, srgb(*rgb))


def rims(img, layer, base_y, rgb, seed, count, h_range, w_range, clear=0.0):
    """Low, wide crater rims: a gentle arch with a broken crest."""
    r = random.Random(seed)
    w = img.get_width()
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, base_y, w, img.get_height() - base_y)
    placed = 0
    while placed < count:
        rw, rh = r.uniform(*w_range), r.uniform(*h_range)
        x0 = r.uniform(0, w)
        centre = x0 + rw / 2
        if clear and min(abs(centre - w / 2), abs(centre + w - w / 2)) < clear + rw / 2:
            continue
        placed += 1
        for shift in (0.0, -float(w)):
            pts = [x0 + shift, base_y + 2.0]
            steps = 14
            for i in range(1, steps):
                t = i / steps
                lift = rh * (math.sin(math.pi * t) ** 0.45) * r.uniform(0.85, 1.0)
                pts += [x0 + shift + rw * t, base_y - lift]
            pts += [x0 + shift + rw, base_y + 2.0]
            img.select_polygon(Gimp.ChannelOps.ADD, pts)
    fill_selection(img, layer, srgb(*rgb))


def disc(img, name, x, y, rx, ry, rgb, mode=Gimp.LayerMode.NORMAL, opacity=100.0, blur=0.0):
    layer = add_layer(img, name, alpha=True, mode=mode, opacity=opacity)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, x - rx, y - ry, rx * 2, ry * 2)
    fill_selection(img, layer, srgb(*rgb))
    if blur:
        gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    return layer


def sky():
    w, h = 4096, 2048
    hz = h // 2
    cx = w / 2
    img = new_image(w, h)
    base = add_layer(img, "base", srgb(0.10, 0.07, 0.13))
    # Dusky violet overhead, warming through dusty rose to butterscotch-pink at the horizon.
    bands = [
        (0.00, 0.24, (0.10, 0.07, 0.13), (0.20, 0.12, 0.18)),
        (0.24, 0.39, (0.20, 0.12, 0.18), (0.44, 0.26, 0.27)),
        (0.39, 0.46, (0.44, 0.26, 0.27), (0.70, 0.45, 0.37)),
        (0.46, 0.50, (0.70, 0.45, 0.37), (0.88, 0.63, 0.44)),
        (0.50, 0.56, (0.88, 0.63, 0.44), (0.36, 0.20, 0.17)),
    ]
    for top, bottom, rgb_top, rgb_bottom in bands:
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * top), w, int(h * (bottom - top)) + 2)
        gradient(base, srgb(*rgb_top), srgb(*rgb_bottom), h * top, h * bottom)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * 0.56), w, h - int(h * 0.56))
    fill_selection(img, base, srgb(0.36, 0.20, 0.17))

    # The first stars, only high up where the dusk has gone.
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN, 70.0)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=6161)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.975, 1.0)
    gegl(stars, "gegl:gaussian-blur", std_dev_x=0.6, std_dev_y=0.6)
    mask = stars.create_mask(Gimp.AddMaskType.WHITE)
    stars.add_mask(mask)
    gradient(mask, "white", "black", hz * 0.45, hz * 0.8)

    # The blue sunset: a wide cool glow round the sun, a brighter core, and the small pale sun
    # itself just above the horizon, straight down the road.
    disc(img, "blue_glow", cx, hz - 10, 430, 175, (0.34, 0.52, 0.84), opacity=85.0, blur=95.0)
    disc(img, "blue_core", cx, hz - 18, 160, 72, (0.5, 0.7, 1.0), Gimp.LayerMode.SCREEN, 75.0, 40.0)
    disc(img, "sun_halo", cx, hz - 26, 34, 34, (0.85, 0.92, 1.0), Gimp.LayerMode.SCREEN, 90.0, 14.0)
    disc(img, "sun", cx, hz - 26, 9, 9, (1.0, 1.0, 0.98), blur=1.2)

    # Dust haze: long faint streaks lying along the horizon.
    haze = soft_noise(img, "haze", (0.95, 0.65, 0.45), Gimp.LayerMode.SCREEN, 30.0, 1.2, 16.0, 6363, 0.45, 1.0)
    hmask = haze.create_mask(Gimp.AddMaskType.BLACK)
    haze.add_mask(hmask)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, hz - 170, w, 130)
    gradient(hmask, "black", "white", hz - 170, hz - 40)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, hz - 42, w, 80)
    gradient(hmask, "white", "black", hz - 40, hz + 36)
    Gimp.Selection.none(img)

    # Earth: a bright blue-white evening star near the sun, its moon a speck beside it.
    disc(img, "earth_halo", cx - 150, hz - 60, 16, 16, (0.6, 0.78, 1.0), Gimp.LayerMode.SCREEN, 85.0, 6.0)
    disc(img, "earth", cx - 150, hz - 60, 3.6, 3.6, (0.88, 0.95, 1.0))
    disc(img, "luna", cx - 141, hz - 63, 1.2, 1.2, (0.9, 0.9, 0.9), opacity=80.0)
    sparkle = add_layer(img, "sparkle", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=70.0)
    Gimp.context_set_foreground(color(srgb(0.85, 0.92, 1.0)))
    img.select_rectangle(Gimp.ChannelOps.REPLACE, cx - 150 - 18, hz - 61, 36, 2)
    sparkle.edit_fill(Gimp.FillType.FOREGROUND)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, cx - 151, hz - 60 - 18, 2, 36)
    sparkle.edit_fill(Gimp.FillType.FOREGROUND)
    Gimp.Selection.none(img)
    gegl(sparkle, "gegl:gaussian-blur", std_dev_x=1.5, std_dev_y=1.5)

    # Phobos, a lumpy little moon up and to the right (low enough to clear the HUD), lit from below by the set sun; Deimos a
    # tiny bright point to the left.
    phobos = add_layer(img, "phobos", alpha=True)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, cx + 250, hz - 82, 30, 21)
    img.select_ellipse(Gimp.ChannelOps.ADD, cx + 262, hz - 86, 22, 20)
    fill_selection(img, phobos, srgb(0.93, 0.85, 0.76))
    shade = add_layer(img, "phobos_shade", alpha=True, mode=Gimp.LayerMode.MULTIPLY, opacity=70.0)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, cx + 254, hz - 94, 32, 20)
    fill_selection(img, shade, srgb(0.62, 0.52, 0.52))
    gegl(shade, "gegl:gaussian-blur", std_dev_x=3.0, std_dev_y=3.0)
    for _ in range(4):
        cr = random.uniform(1.5, 3.0)
        x, y = cx + 258 + random.uniform(0, 18), hz - 78 + random.uniform(-6, 4)
        disc(img, "crater", x, y, cr, cr, (0.72, 0.62, 0.58), Gimp.LayerMode.MULTIPLY, 60.0, 0.8)
    disc(img, "deimos_halo", cx - 340, hz - 72, 9, 9, (0.95, 0.88, 0.8), Gimp.LayerMode.SCREEN, 50.0, 4.0)
    disc(img, "deimos", cx - 340, hz - 72, 4.2, 4.0, (0.97, 0.92, 0.85))

    # The horizon, back to front: hazy far hills and mesas in the dust, crater rims, darker near
    # mesas, and the low near ridge. The near layers leave the road's vanishing point open.
    far = add_layer(img, "far_hills", alpha=True)
    ridge(img, far, hz + 3, 20, srgb(0.58, 0.37, 0.36), 21)
    far_mesas = add_layer(img, "far_mesas", alpha=True)
    mesas(img, far_mesas, hz + 3, (0.49, 0.29, 0.29), 23, 22, (18, 48), (120, 420), clear=60)
    rim = add_layer(img, "rims", alpha=True)
    rims(img, rim, hz + 5, (0.34, 0.18, 0.17), 27, 9, (8, 18), (260, 620), clear=140)
    near_mesas = add_layer(img, "near_mesas", alpha=True)
    mesas(img, near_mesas, hz + 6, (0.23, 0.11, 0.10), 29, 14, (14, 34), (90, 300), clear=260)
    near = add_layer(img, "near_ridge", alpha=True)
    ridge(img, near, hz + 9, 7, srgb(0.17, 0.085, 0.075), 31)
    save_png(img, "sky.png")
    img.delete()


def frontier_wordmark(text, file_name, fonts, size, pad=110):
    """RED FRONTIER: dusty orange letters, sand-blasted, a dark rust outline, and a warm glow."""
    img = new_image(32, 32)
    font = pick_font(fonts)
    face = Gimp.TextLayer.new(img, text, font, size, Gimp.Unit.pixel())
    img.insert_layer(face, None, 0)
    face.set_color(color(srgb(1.0, 0.66, 0.32)))
    face.set_letter_spacing(12.0)
    w, h = face.get_width() + pad * 2, face.get_height() + pad * 2
    img.resize(w, h, pad, pad)
    face.resize_to_image_size()
    # Inserted at position 1 each time, so the last one sits just under the face.
    for name, rgb, grow, blur, opacity in (
        ("wide_glow", (1.0, 0.34, 0.06), 10, 34.0, 80.0),
        ("glow", (1.0, 0.48, 0.14), 4, 12.0, 100.0),
        ("outline", (0.30, 0.08, 0.03), 3, 0.0, 100.0),
    ):
        layer = Gimp.Layer.new(img, name, w, h, Gimp.ImageType.RGBA_IMAGE, opacity, Gimp.LayerMode.NORMAL)
        img.insert_layer(layer, None, 1)
        layer.fill(Gimp.FillType.TRANSPARENT)
        img.select_item(Gimp.ChannelOps.REPLACE, face)
        Gimp.Selection.grow(img, grow)
        Gimp.context_set_foreground(color(srgb(*rgb)))
        layer.edit_fill(Gimp.FillType.FOREGROUND)
        Gimp.Selection.none(img)
        if blur:
            gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    # Over the letters only: a light-to-rust shade top to bottom, and sand-blasted grain.
    shade = Gimp.Layer.new(img, "shade", w, h, Gimp.ImageType.RGBA_IMAGE, 100.0, Gimp.LayerMode.MULTIPLY)
    img.insert_layer(shade, None, 0)
    shade.fill(Gimp.FillType.TRANSPARENT)
    img.select_item(Gimp.ChannelOps.REPLACE, face)
    gradient(shade, srgb(1.0, 1.0, 1.0), srgb(0.92, 0.55, 0.4), pad, h - pad)
    dust = Gimp.Layer.new(img, "dust", w, h, Gimp.ImageType.RGBA_IMAGE, 45.0, Gimp.LayerMode.MULTIPLY)
    img.insert_layer(dust, None, 0)
    Gimp.context_set_foreground(color("rgb(0.5,0.5,0.5)"))
    dust.fill(Gimp.FillType.FOREGROUND)
    gegl(dust, "gegl:noise-rgb", red=1.0, green=1.0, blue=1.0, independent=False, seed=8181)
    gegl(dust, "gegl:pixelize", size_x=2, size_y=2)
    dust.levels(Gimp.HistogramChannel.VALUE, 0.0, 0.25, True, 1.0, 0.45, 1.0, True)
    img.select_item(Gimp.ChannelOps.REPLACE, face)
    Gimp.Selection.invert(img)
    dust.edit_clear()
    Gimp.Selection.none(img)
    save_png(img, file_name)
    img.delete()


random.seed(1987)
road()
ground()
sky()
frontier_wordmark("RED FRONTIER", "region_logo.png", ["Copperplate Bold", "Rockwell Bold", "DIN Condensed Bold"], 112)
print("TEXTURES DONE")
