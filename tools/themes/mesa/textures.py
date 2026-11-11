# Io Burn art (region id `mesa`): a black basalt road paved in hexagonal column tops, sulphur-yellow
# and orange ground with dark cracks, the night sky over Io, and the region logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/mesa/textures.py').read())"
#
# Colours are written as they look on screen and go through paintkit's srgb(), because GEGL reads
# "rgb(r,g,b)" as linear light (typed straight in, they come out pale).
#
# The sky: Io has no air, so it is black-violet space with stars right down to the horizon. Jupiter
# hangs huge over the left of the road, banded, with the Great Red Spot, lit from the right with a
# sliver of night on its left limb. Along the horizon, dark volcanic massifs and shield rims stand
# against the glow of distant eruptions, and two far umbrella plumes rise faintly orange.
# Only the band from the horizon to about 11 degrees above it is in shot (126 px of the 2048), and
# about 490 px either side of the centre column (straight down the road). Jupiter is centred above
# that band on purpose: the view cuts it off, so it reads as too big to fit in the sky.
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/mesa/textures")

JUPITER_X = -120  # px from the centre column (negative is left of the road)
JUPITER_Y = 154  # px above the horizon, the disc's centre
JUPITER_R = 148  # px


def patches(img, name, rgb, opacity, x_size, y_size, seed, lo, hi, mode=Gimp.LayerMode.NORMAL):
    """A layer of solid colour showing through a mask of tileable cloud noise, levelled so only the
    brightest blobs show: patches of another colour across a ground tile."""
    w, h = img.get_width(), img.get_height()
    layer = add_layer(img, name, "black", mode, opacity)
    gegl(layer, "gegl:noise-solid", x_size=x_size, y_size=y_size, detail=3, tileable=True, turbulent=False,
         seed=seed, width=w, height=h)
    layer.levels(Gimp.HistogramChannel.VALUE, lo, hi, True, 1.0, 0.0, 1.0, True)
    mask = layer.create_mask(Gimp.AddMaskType.COPY)
    layer.add_mask(mask)
    Gimp.context_set_foreground(color(srgb(*rgb)))
    layer.fill(Gimp.FillType.FOREGROUND)
    return layer


def pebbles(img, name, rgb, count, r_from, r_to, seed, opacity=100.0, blur=0.6):
    """Small pebbles or grains as filled dots, kept off the edges so the tile still wraps."""
    r = random.Random(seed)
    size = img.get_width()
    layer = add_layer(img, name, alpha=True, opacity=opacity)
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


def brush(rgb, size):
    Gimp.context_set_foreground(color(srgb(*rgb)))
    Gimp.context_set_brush(Gimp.Brush.get_by_name("2. Hardness 100"))
    Gimp.context_set_brush_size(size)


def road():
    """Black basalt paving: the tops of hexagonal basalt columns, each a slightly different tone,
    dark joints between them, vesicle pits, glassy glints, a breath of sulphur dust. Dark enough that
    the cyan notes read. The hex lattice repeats exactly across the tile (8 across, 10 rows)."""
    size = 1024
    img = mottled(size, srgb(0.13, 0.12, 0.125), None, "road", 8.0)
    cols, rows = 8, 10
    dx, dy = size / cols, size / rows
    rx, ry = dx / (2 * math.cos(math.radians(30))), dy / 1.5

    def corners(i, j):
        cx, cy = i * dx + (dx / 2 if j % 2 else 0.0), j * dy
        pts = []
        for k in range(7):
            a = math.radians(90 - 60 * (k % 6))
            x, y = cx + rx * math.cos(a), cy + ry * math.sin(a)
            # Jitter each corner by its own position in the repeating lattice, so neighbours (and
            # the copies across the tile's edges) agree on where a shared corner is.
            jr = random.Random("%.1f,%.1f" % (x % size, y % size))
            pts += [x + jr.uniform(-6, 6), y + jr.uniform(-6, 6)]
        return pts

    tones = add_layer(img, "tones", alpha=True, mode=Gimp.LayerMode.OVERLAY, opacity=55.0)
    tr = random.Random(9090)
    shade = {(i, j): tr.choice([0.36, 0.44, 0.5, 0.56, 0.62]) for i in range(cols) for j in range(rows)}
    for value in sorted(set(shade.values())):
        first = True
        for j in range(-1, rows + 1):
            for i in range(-1, cols + 1):
                if shade[(i % cols, j % rows)] != value:
                    continue
                img.select_polygon(Gimp.ChannelOps.REPLACE if first else Gimp.ChannelOps.ADD, corners(i, j)[:12])
                first = False
        fill_selection(img, tones, srgb(value, value, value))
    gegl(tones, "gegl:gaussian-blur", std_dev_x=2.0, std_dev_y=2.0)

    pebbles(img, "vesicles", (0.025, 0.022, 0.025), 520, 1.0, 2.8, 5101, 75.0)
    pebbles(img, "glints", (0.34, 0.32, 0.36), 140, 0.6, 1.4, 5103, 55.0, 0.4)
    patches(img, "dust", (0.55, 0.45, 0.16), 7.0, 3.0, 3.0, 5105, 0.55, 1.0)

    joints = add_layer(img, "joints", alpha=True, opacity=80.0)
    brush((0.012, 0.01, 0.012), 4.5)
    for j in range(-1, rows + 1):
        for i in range(-1, cols + 1):
            Gimp.paintbrush_default(joints, corners(i, j))
    gegl(joints, "gegl:gaussian-blur", std_dev_x=1.0, std_dev_y=1.0)
    save_png(img, "road.png")
    img.delete()


def crack(layer, size, start, along_y, wander, steps, r):
    """A crack across the tile that starts and ends at the same offset, so the tile still wraps."""
    pos, points = start, []
    for s in range(steps + 1):
        if s == steps:
            pos = start
        t = float(s * size / steps)
        points.extend([float(pos), t] if along_y else [t, float(pos)])
        pos = max(10, min(size - 10, pos + r.randint(-wander, wander)))
    Gimp.paintbrush_default(layer, points)
    return points


def ground():
    """Sulphur plains: yellow sulphur, orange and red-brown sulphur compounds in patches, pale SO2
    frost, dark old flow stains, a network of dark cracks with short branches, grit and grains."""
    size = 1024
    # The base is a strong, warm yellow: the mottling multiplies it down, and a weaker yellow came
    # out olive-khaki under the night lighting.
    img = mottled(size, srgb(0.95, 0.74, 0.12), None, "ground", 6.0)
    patches(img, "yellow", (1.0, 0.86, 0.22), 55.0, 3.0, 3.0, 6100, 0.42, 0.62)
    patches(img, "orange", (0.92, 0.42, 0.06), 75.0, 2.5, 2.5, 6101, 0.44, 0.66)
    patches(img, "red_brown", (0.6, 0.16, 0.04), 60.0, 4.0, 4.0, 6103, 0.52, 0.72)
    patches(img, "frost", (0.95, 0.92, 0.74), 50.0, 3.5, 3.5, 6105, 0.56, 0.76)
    patches(img, "stain", (0.1, 0.06, 0.04), 55.0, 2.0, 2.0, 6107, 0.58, 0.78)
    pebbles(img, "grit", (0.14, 0.08, 0.04), 700, 1.0, 3.0, 6109, 70.0)
    pebbles(img, "grains", (0.98, 0.9, 0.45), 220, 0.8, 1.8, 6111, 60.0)

    cracks = add_layer(img, "cracks", alpha=True, opacity=90.0)
    r = random.Random(6113)
    for k in range(4):
        brush((0.06, 0.035, 0.025), r.uniform(3.0, 5.5))
        crack(cracks, size, 128 + k * 256 + r.randint(-60, 60), True, 38, 14, r)
        brush((0.06, 0.035, 0.025), r.uniform(3.0, 5.5))
        crack(cracks, size, 128 + k * 256 + r.randint(-60, 60), False, 38, 14, r)
    # Short branches, kept inside the tile.
    for _ in range(26):
        brush((0.07, 0.04, 0.03), r.uniform(1.6, 3.2))
        x, y = r.uniform(80, size - 80), r.uniform(80, size - 80)
        a = r.uniform(0, 2 * math.pi)
        pts = [x, y]
        for _ in range(r.randint(2, 4)):
            a += r.uniform(-0.6, 0.6)
            step = r.uniform(18, 42)
            x = max(12.0, min(size - 12.0, x + math.cos(a) * step))
            y = max(12.0, min(size - 12.0, y + math.sin(a) * step))
            pts += [x, y]
        Gimp.paintbrush_default(cracks, pts)
    gegl(cracks, "gegl:gaussian-blur", std_dev_x=0.8, std_dev_y=0.8)
    save_png(img, "ground.png")
    img.delete()


def disc(img, name, x, y, rx, ry, rgb, mode=Gimp.LayerMode.NORMAL, opacity=100.0, blur=0.0):
    layer = add_layer(img, name, alpha=True, mode=mode, opacity=opacity)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, x - rx, y - ry, rx * 2, ry * 2)
    fill_selection(img, layer, srgb(*rgb))
    if blur:
        gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    return layer


def massifs(img, layer, base_y, rgb, seed, count, h_range, w_range, clear=0.0):
    """Io's mountains: steep-sided massifs with tilted, uneven tops, along the horizon. Wraps the
    seam. `clear` keeps that many pixels either side of the centre column free."""
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
        tilt = r.uniform(-0.35, 0.35) * mh
        s1, s2 = mh * r.uniform(0.5, 1.1), mh * r.uniform(0.5, 1.1)
        for shift in (0.0, -float(w)):
            x = x0 + shift
            pts = [x, base_y + 2.0, x + s1, base_y - mh * 0.75 + tilt * 0.5, x + s1 * 1.3, base_y - mh + tilt,
                   x + mw * 0.45, base_y - mh - r.uniform(0, 0.1) * mh, x + mw * 0.62, base_y - mh * 0.9,
                   x + mw - s2 * 1.3, base_y - mh - tilt, x + mw - s2, base_y - mh * 0.5, x + mw, base_y + 2.0]
            img.select_polygon(Gimp.ChannelOps.ADD, pts)
    fill_selection(img, layer, srgb(*rgb))


def shields(img, layer, base_y, rgb, seed, count, h_range, w_range, clear=0.0):
    """Low shield volcanoes: wide gentle domes, some with a notch of a caldera at the top."""
    r = random.Random(seed)
    w = img.get_width()
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, base_y, w, img.get_height() - base_y)
    placed = 0
    while placed < count:
        sw, sh = r.uniform(*w_range), r.uniform(*h_range)
        x0 = r.uniform(0, w)
        centre = x0 + sw / 2
        if clear and min(abs(centre - w / 2), abs(centre + w - w / 2)) < clear + sw / 2:
            continue
        placed += 1
        notch = r.random() < 0.6
        for shift in (0.0, -float(w)):
            pts = [x0 + shift, base_y + 2.0]
            steps = 16
            for i in range(1, steps):
                t = i / steps
                lift = sh * math.sin(math.pi * t) ** 0.7
                if notch and abs(t - 0.5) < 0.07:
                    lift -= sh * 0.22
                pts += [x0 + shift + sw * t, base_y - lift]
            pts += [x0 + shift + sw, base_y + 2.0]
            img.select_polygon(Gimp.ChannelOps.ADD, pts)
    fill_selection(img, layer, srgb(*rgb))


def jupiter(img, cx, cy, rad):
    """Jupiter: cream zones and rust belts with turbulent edges, the Great Red Spot, limb darkening,
    and a sliver of night on the left limb (lit from the right). Europa's shadow on the disc."""
    def in_disc(op=Gimp.ChannelOps.REPLACE):
        img.select_ellipse(op, cx - rad, cy - rad, rad * 2, rad * 2)

    body = add_layer(img, "jupiter", alpha=True)
    in_disc()
    fill_selection(img, body, srgb(0.86, 0.79, 0.66))
    # Belts and zones by latitude (degrees, north up); the disc is seen side-on, so y = R sin(lat).
    bands = [(90, 52, (0.5, 0.48, 0.47)), (52, 38, (0.66, 0.58, 0.5)), (38, 30, (0.6, 0.48, 0.38)),
             (30, 22, (0.84, 0.76, 0.62)), (22, 17, (0.62, 0.44, 0.3)), (17, 8, (0.66, 0.4, 0.24)),
             (8, -6, (0.92, 0.85, 0.7)), (-6, -19, (0.6, 0.36, 0.2)), (-19, -26, (0.88, 0.8, 0.66)),
             (-26, -33, (0.64, 0.46, 0.32)), (-33, -42, (0.8, 0.72, 0.6)), (-42, -90, (0.52, 0.48, 0.46))]
    belts = add_layer(img, "belts", alpha=True)
    br = random.Random(7303)
    xs = [cx - rad - 4 + (rad * 2 + 8) * k / 40 for k in range(41)]

    def boundary(lat):
        """A band edge: the latitude's height on the disc, wobbled by two sines and a little noise, so
        the belts have the turbulent edges Jupiter's do. Each edge is shared by the bands either side."""
        if abs(lat) >= 90:
            return [cy - math.copysign(rad + 4, lat)] * len(xs)
        y = cy - rad * math.sin(math.radians(lat))
        p1, p2 = br.uniform(0, 6.3), br.uniform(0, 6.3)
        amp = 1.5 + 2.5 * math.cos(math.radians(lat))
        return [y + amp * (math.sin(x / 23.0 + p1) * 0.7 + math.sin(x / 9.0 + p2) * 0.3) + br.uniform(-0.6, 0.6)
                for x in xs]

    edges = {}
    for top, bottom, _ in bands:
        for lat in (top, bottom):
            if lat not in edges:
                edges[lat] = boundary(lat)
    for top, bottom, rgb in bands:
        pts = []
        for x, y in zip(xs, edges[top]):
            pts += [x, y]
        for x, y in zip(reversed(xs), reversed(edges[bottom])):
            pts += [x, y]
        img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
        in_disc(Gimp.ChannelOps.INTERSECT)
        fill_selection(img, belts, srgb(*rgb))
    gegl(belts, "gegl:gaussian-blur", std_dev_x=1.6, std_dev_y=1.1)
    # Long streaks within the bands: cloud noise stretched sideways, on a layer the size of the disc
    # (noise-solid's frequencies top out at 16 across the layer, too coarse over the whole sky).
    side = int(rad * 2 + 8)
    streaks = Gimp.Layer.new(img, "streaks", side, side, Gimp.ImageType.RGBA_IMAGE, 40.0, Gimp.LayerMode.OVERLAY)
    img.insert_layer(streaks, None, 0)
    streaks.set_offsets(int(cx - side / 2), int(cy - side / 2))
    gegl(streaks, "gegl:noise-solid", x_size=1.2, y_size=13.0, detail=4, tileable=False, turbulent=True,
         seed=7301, width=side, height=side)
    in_disc()
    Gimp.Selection.invert(img)
    streaks.edit_clear()
    Gimp.Selection.none(img)
    # The Great Red Spot in the south equatorial belt's southern edge, with its pale collar.
    spot_y = cy + rad * math.sin(math.radians(22))
    disc(img, "grs_collar", cx + 38, spot_y, 30, 15, (0.93, 0.86, 0.74), opacity=85.0, blur=2.0)
    disc(img, "grs", cx + 38, spot_y, 23, 11, (0.78, 0.38, 0.24), blur=1.6)
    disc(img, "grs_core", cx + 40, spot_y, 12, 5.5, (0.7, 0.28, 0.17), opacity=70.0, blur=2.0)
    # White ovals in the south temperate zone.
    for ox in (-60, -10, 70):
        disc(img, "oval", cx + ox, cy + rad * math.sin(math.radians(37)), 7, 3.5, (0.93, 0.9, 0.84), opacity=70.0,
             blur=1.0)
    # Europa's shadow: a small black dot on the equatorial zone.
    disc(img, "europa_shadow", cx - 34, cy + rad * math.sin(math.radians(2)), 4.5, 4.5, (0.02, 0.015, 0.02), blur=0.8)
    # Limb darkening: a radial multiply, plain in the middle and browning toward the edge.
    limb = add_layer(img, "limb", alpha=True, mode=Gimp.LayerMode.MULTIPLY)
    in_disc()
    Gimp.context_set_foreground(color(srgb(1.0, 1.0, 1.0)))
    Gimp.context_set_background(color(srgb(0.42, 0.3, 0.26)))
    Gimp.context_set_gradient_fg_bg_rgb()
    limb.edit_gradient_fill(Gimp.GradientType.RADIAL, 45.0, False, 1, 0.0, True, cx + rad * 0.15, cy, cx + rad * 1.1, cy)
    Gimp.Selection.none(img)
    # Night on the left limb: the disc's left half minus a terminator ellipse, soft-edged.
    night = add_layer(img, "night", alpha=True, mode=Gimp.LayerMode.MULTIPLY)
    in_disc()
    img.select_rectangle(Gimp.ChannelOps.INTERSECT, cx - rad - 2, cy - rad - 2, rad + 2, rad * 2 + 4)
    img.select_ellipse(Gimp.ChannelOps.SUBTRACT, cx - rad * 0.72, cy - rad, rad * 1.44, rad * 2)
    fill_selection(img, night, srgb(0.1, 0.07, 0.12))
    gegl(night, "gegl:gaussian-blur", std_dev_x=9.0, std_dev_y=4.0)
    # Keep the softened terminator inside the disc.
    in_disc()
    Gimp.Selection.invert(img)
    night.edit_clear()
    Gimp.Selection.none(img)
    # A faint warm haze round the lit limb.
    halo = add_layer(img, "halo", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=40.0)
    img.select_ellipse(Gimp.ChannelOps.REPLACE, cx - rad - 6, cy - rad - 6, rad * 2 + 12, rad * 2 + 12)
    img.select_ellipse(Gimp.ChannelOps.SUBTRACT, cx - rad + 2, cy - rad + 2, rad * 2 - 4, rad * 2 - 4)
    fill_selection(img, halo, srgb(0.5, 0.36, 0.24))
    gegl(halo, "gegl:gaussian-blur", std_dev_x=6.0, std_dev_y=6.0)


def far_plume(img, x, base_y, height, spread, opacity):
    """A distant umbrella plume on the horizon: a faint column and canopy, glowing at the vent."""
    layer = add_layer(img, "far_plume", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=opacity)
    top = base_y - height
    # A fan of gas widening from the vent into a soft oval canopy, heavily blurred. (A crisp dome with
    # drooping fallout read as an orange arch.)
    img.select_polygon(Gimp.ChannelOps.REPLACE, [x - 3, base_y, x + 3, base_y, x + spread * 0.55, top + spread * 0.1,
                                                 x - spread * 0.55, top + spread * 0.1])
    img.select_ellipse(Gimp.ChannelOps.ADD, x - spread * 0.8, top - spread * 0.22, spread * 1.6, spread * 0.5)
    fill_selection(img, layer, srgb(0.75, 0.28, 0.1))
    gegl(layer, "gegl:gaussian-blur", std_dev_x=6.0, std_dev_y=5.0)
    core = add_layer(img, "far_plume_core", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=opacity)
    img.select_polygon(Gimp.ChannelOps.REPLACE, [x - 2, base_y, x + 2, base_y, x + spread * 0.12, top + spread * 0.3,
                                                 x - spread * 0.12, top + spread * 0.3])
    fill_selection(img, core, srgb(1.0, 0.5, 0.18))
    gegl(core, "gegl:gaussian-blur", std_dev_x=2.0, std_dev_y=3.0)
    disc(img, "plume_vent", x, base_y - 3, 16, 6, (1.0, 0.5, 0.15), Gimp.LayerMode.SCREEN, opacity + 25.0, 4.0)


def sky():
    w, h = 4096, 2048
    hz = h // 2
    cx = w / 2
    img = new_image(w, h)
    base = add_layer(img, "base", srgb(0.012, 0.008, 0.03))
    # Black-violet overhead to a dusky violet-maroon at the horizon, where the eruptions light it.
    bands = [(0.0, 0.3, (0.01, 0.007, 0.026), (0.02, 0.012, 0.045)),
             (0.3, 0.44, (0.02, 0.012, 0.045), (0.04, 0.02, 0.07)),
             (0.44, 0.5, (0.04, 0.02, 0.07), (0.075, 0.035, 0.08)),
             (0.5, 0.56, (0.075, 0.035, 0.08), (0.04, 0.02, 0.03))]
    for top, bottom, rgb_top, rgb_bottom in bands:
        img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * top), w, int(h * (bottom - top)) + 2)
        gradient(base, srgb(*rgb_top), srgb(*rgb_bottom), h * top, h * bottom)
    img.select_rectangle(Gimp.ChannelOps.REPLACE, 0, int(h * 0.56), w, h - int(h * 0.56))
    fill_selection(img, base, srgb(0.04, 0.02, 0.03))

    # A faint violet haze of the galaxy's band, and stars all the way down (no air to dim them).
    haze = add_layer(img, "haze", "black", Gimp.LayerMode.SCREEN, 9.0)
    gegl(haze, "gegl:noise-solid", x_size=2.0, y_size=5.0, detail=4, tileable=True, turbulent=True,
         seed=7101, width=w, height=h)
    haze.levels(Gimp.HistogramChannel.VALUE, 0.45, 1.0, True, 1.0, 0.0, 0.5, True)
    haze.colorize_hsl(268.0, 55.0, -30.0)
    stars = add_layer(img, "stars", "gray", Gimp.LayerMode.SCREEN, 85.0)
    gegl(stars, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=7103)
    stars.threshold(Gimp.HistogramChannel.VALUE, 0.974, 1.0)
    gegl(stars, "gegl:gaussian-blur", std_dev_x=0.6, std_dev_y=0.6)
    r = random.Random(7105)
    for _ in range(26):
        x, y = r.uniform(0, w), r.uniform(hz - 700, hz - 12)
        tint = r.choice([(1.0, 0.95, 0.85), (0.8, 0.86, 1.0), (1.0, 0.8, 0.7)])
        disc(img, "bright_star", x, y, 4.0, 4.0, tint, Gimp.LayerMode.SCREEN, 55.0, 2.0)
        disc(img, "bright_core", x, y, 1.3, 1.3, (1.0, 1.0, 1.0), opacity=90.0)

    jupiter(img, cx + JUPITER_X, hz - JUPITER_Y, JUPITER_R)
    # Europa, a small pale moon further left, lit from the right like Jupiter.
    disc(img, "europa", cx - 420, hz - 96, 6.0, 6.0, (0.88, 0.84, 0.76), blur=0.6)
    disc(img, "europa_night", cx - 424, hz - 96, 4.0, 5.6, (0.1, 0.08, 0.1), Gimp.LayerMode.MULTIPLY, 80.0, 1.2)

    # The glow of distant eruptions along the horizon, a few inside the view.
    # Each is a small, local glow sitting on the horizon (a broad band of them read as a sunset).
    for x, rx, ry, rgb, opacity in ((cx + 300, 70, 14, (1.0, 0.42, 0.1), 60.0), (cx - 390, 85, 12, (0.95, 0.3, 0.08), 50.0),
                                    (cx + 470, 45, 10, (1.0, 0.5, 0.14), 50.0), (cx + 120, 40, 8, (0.9, 0.3, 0.08), 35.0),
                                    (cx - 1300, 100, 14, (1.0, 0.4, 0.1), 55.0), (cx + 1250, 90, 14, (0.95, 0.35, 0.1), 55.0),
                                    (cx + 1900, 110, 14, (1.0, 0.42, 0.12), 55.0), (cx - 1900, 80, 12, (1.0, 0.4, 0.1), 50.0)):
        disc(img, "eruption_glow", x, hz - 2, rx, ry, rgb, Gimp.LayerMode.SCREEN, opacity, ry * 1.4)
    far_plume(img, cx + 300, hz + 1, 62, 46, 38.0)
    far_plume(img, cx - 470, hz + 1, 40, 30, 32.0)
    far_plume(img, cx + 1250, hz + 1, 64, 46, 38.0)

    # The horizon, back to front: far massifs in the glow, shield volcano rims, a near black ridge.
    far = add_layer(img, "far_massifs", alpha=True)
    massifs(img, far, hz + 3, (0.12, 0.06, 0.08), 7201, 18, (16, 44), (140, 380), clear=40)
    sh = add_layer(img, "shields", alpha=True)
    shields(img, sh, hz + 4, (0.07, 0.035, 0.05), 7203, 10, (8, 20), (300, 700), clear=120)
    near = add_layer(img, "near_massifs", alpha=True)
    massifs(img, near, hz + 6, (0.035, 0.018, 0.028), 7205, 12, (10, 26), (90, 260), clear=220)
    ridge(img, add_layer(img, "near_ridge", alpha=True), hz + 9, 6, srgb(0.025, 0.014, 0.02), 7207)
    save_png(img, "sky.png")
    img.delete()


def io_wordmark(text, file_name, fonts, size, pad=110):
    """IO BURN: hot yellow letters cooling to orange at their feet, a dark red outline, a red glow,
    and a fine scorch grain over the letters."""
    img = new_image(32, 32)
    font = pick_font(fonts)
    face = Gimp.TextLayer.new(img, text, font, size, Gimp.Unit.pixel())
    img.insert_layer(face, None, 0)
    face.set_color(color(srgb(1.0, 0.9, 0.38)))
    face.set_letter_spacing(14.0)
    w, h = face.get_width() + pad * 2, face.get_height() + pad * 2
    img.resize(w, h, pad, pad)
    face.resize_to_image_size()
    # Inserted at position 1 each time, so the last one sits just under the face.
    for name, rgb, grow, blur, opacity in (
        ("wide_glow", (0.95, 0.1, 0.02), 12, 36.0, 85.0),
        ("glow", (1.0, 0.3, 0.05), 5, 12.0, 100.0),
        ("outline", (0.32, 0.03, 0.02), 3, 0.0, 100.0),
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
    shade = Gimp.Layer.new(img, "shade", w, h, Gimp.ImageType.RGBA_IMAGE, 100.0, Gimp.LayerMode.MULTIPLY)
    img.insert_layer(shade, None, 0)
    shade.fill(Gimp.FillType.TRANSPARENT)
    img.select_item(Gimp.ChannelOps.REPLACE, face)
    gradient(shade, srgb(1.0, 1.0, 1.0), srgb(1.0, 0.45, 0.16), pad + size * 0.25, h - pad)
    grain = Gimp.Layer.new(img, "grain", w, h, Gimp.ImageType.RGBA_IMAGE, 35.0, Gimp.LayerMode.MULTIPLY)
    img.insert_layer(grain, None, 0)
    Gimp.context_set_foreground(color("rgb(0.5,0.5,0.5)"))
    grain.fill(Gimp.FillType.FOREGROUND)
    gegl(grain, "gegl:noise-rgb", red=1.0, green=1.0, blue=1.0, independent=False, seed=7401)
    gegl(grain, "gegl:pixelize", size_x=2, size_y=2)
    grain.levels(Gimp.HistogramChannel.VALUE, 0.0, 0.25, True, 1.0, 0.5, 1.0, True)
    img.select_item(Gimp.ChannelOps.REPLACE, face)
    Gimp.Selection.invert(img)
    grain.edit_clear()
    Gimp.Selection.none(img)
    save_png(img, file_name)
    img.delete()


random.seed(4040)
road()
ground()
sky()
io_wordmark("IO BURN", "region_logo.png", ["Futura Condensed ExtraBold", "Impact", "Arial Black"], 120)
print("TEXTURES DONE")
