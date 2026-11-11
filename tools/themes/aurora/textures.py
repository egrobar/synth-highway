# Ring Road art (region id `aurora`): a clean dark panelled road, a dark metal deck for beyond the
# glass, the deep-space sky panorama with Saturn and our own ring curving up into the sky, and the
# region logo.
# Run from the repo root:
#   SYNTH_ROOT="$PWD" gimp -i --quit --batch-interpreter=python-fu-eval \
#     -b "exec(open('tools/themes/aurora/textures.py').read())"
#
# Colours are written as they look on screen and go through paintkit's srgb() (GEGL reads
# "rgb(...)" as linear light, so typed straight in they come out pale).
#
# Only the band from the horizon to about 11 degrees above it is ever in shot (the camera looks down
# the road): within about 490 px either side of the centre column and 125 px above the horizon. So:
# Saturn sits left of the road, its disc's top just out of frame and its rings sweeping up and right
# across the sky; our own ring rises from the road's vanishing point and curves up to the right, lit
# along its edges like the skyway the player is on; the rest is stars and a faint green nebula.
# Every shape on the planet is a polygon computed here (rotated ellipses for the disc and rings),
# so nothing depends on GIMP's layer transforms.
import colorsys
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/themes/aurora/textures")
REPLACE, ADD, SUBTRACT, INTERSECT = (Gimp.ChannelOps.REPLACE, Gimp.ChannelOps.ADD, Gimp.ChannelOps.SUBTRACT,
                                     Gimp.ChannelOps.INTERSECT)


def hsl(r, g, b):
    """Hue (degrees) and saturation arguments for colorize_hsl from an sRGB colour (lightness kept)."""
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360.0, s * 100.0, 0.0


def soft_noise(img, name, tint, mode, opacity, x_size, y_size, seed, lo, hi, blur=0.0):
    """A tinted layer of tileable cloud noise, levelled so only its brightest blobs show (after
    backroads/textures.py). x_size and y_size are frequencies."""
    layer = add_layer(img, name, "black", mode, opacity)
    gegl(layer, "gegl:noise-solid", x_size=x_size, y_size=y_size, detail=4, tileable=True, turbulent=False,
         seed=seed, width=img.get_width(), height=img.get_height())
    layer.levels(Gimp.HistogramChannel.VALUE, lo, hi, True, 1.0, 0.0, 0.8, True)
    layer.colorize_hsl(*hsl(*tint))
    if blur:
        gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    return layer


def fill_rect(img, layer, x, y, w, h, css):
    img.select_rectangle(REPLACE, x, y, w, h)
    fill_selection(img, layer, css)


def clip_to(img, layer, polygon):
    """Clears everything on `layer` outside `polygon`."""
    img.select_polygon(REPLACE, polygon)
    Gimp.Selection.invert(img)
    layer.edit_clear()
    Gimp.Selection.none(img)


# ------------------------------------------------------------------------------------------ road

def road():
    """Dark graphite panels (so the cyan notes read) with faint seams: across the road every quarter
    tile, so they scroll past and the road reads as moving, and along it every half tile."""
    size = 1024
    rr = random.Random(301)
    img = mottled(size, srgb(0.15, 0.165, 0.18), None, "road", 3.0)
    panels = add_layer(img, "panels", alpha=True, mode=Gimp.LayerMode.OVERLAY, opacity=30.0)
    for col in range(2):
        for row in range(4):
            v = rr.uniform(0.42, 0.58)
            fill_rect(img, panels, col * 512, row * 256, 512, 256, srgb(v, v, v))
    seams = add_layer(img, "seams", alpha=True, opacity=70.0)
    bevel = add_layer(img, "bevel", alpha=True, opacity=22.0)
    for y in range(0, size, 256):
        fill_rect(img, seams, 0, y, size, 4, srgb(0.02, 0.025, 0.03))
        fill_rect(img, bevel, 0, y + 4, size, 2, srgb(0.42, 0.46, 0.48))
    for x in (0, 512):
        fill_rect(img, seams, x, 0, 3, size, srgb(0.02, 0.025, 0.03))
        fill_rect(img, bevel, x + 3, 0, 1, size, srgb(0.42, 0.46, 0.48))
    gegl(seams, "gegl:gaussian-blur", std_dev_x=0.8, std_dev_y=0.8)
    save_png(img, "road.png")
    img.delete()


# ---------------------------------------------------------------------------------------- ground

def ground():
    """The ring's dark metal deck: 2.5-unit plates (four to a tile) with seams, rivets at the corners,
    a few grated plates and service hatches, and faint brushed streaks."""
    size = 1024
    rr = random.Random(402)
    img = mottled(size, srgb(0.2, 0.215, 0.23), None, "ground", 3.0)
    brushed = add_layer(img, "brushed", "black", Gimp.LayerMode.SCREEN, 10.0)
    gegl(brushed, "gegl:noise-solid", x_size=1.0, y_size=24.0, detail=3, tileable=True, turbulent=False,
         seed=4021, width=size, height=size)
    plates = add_layer(img, "plates", alpha=True, mode=Gimp.LayerMode.OVERLAY, opacity=45.0)
    grate = add_layer(img, "grate", alpha=True, opacity=40.0)
    hatch = add_layer(img, "hatch", alpha=True, opacity=55.0)
    rivets = add_layer(img, "rivets", alpha=True, opacity=70.0)
    seams = add_layer(img, "seams", alpha=True, opacity=80.0)
    bevel = add_layer(img, "bevel", alpha=True, opacity=25.0)
    p = 256
    for i in range(4):
        for j in range(4):
            x, y = i * p, j * p
            v = rr.uniform(0.38, 0.6)
            fill_rect(img, plates, x, y, p, p, srgb(v, v, v))
            kind = rr.random()
            if kind < 0.22:
                for k in range(16, p - 12, 12):
                    fill_rect(img, grate, x + 14, y + k, p - 28, 4, srgb(0.03, 0.035, 0.04))
            elif kind < 0.4:
                hx, hy = x + rr.randint(40, 110), y + rr.randint(40, 110)
                img.select_rectangle(REPLACE, hx, hy, 96, 72)
                img.select_rectangle(SUBTRACT, hx + 4, hy + 4, 88, 64)
                fill_selection(img, hatch, srgb(0.42, 0.45, 0.47))
            for cx, cy in ((x + 14, y + 14), (x + p - 14, y + 14), (x + 14, y + p - 14), (x + p - 14, y + p - 14)):
                img.select_ellipse(REPLACE, cx - 3, cy - 3, 6, 6)
                fill_selection(img, rivets, srgb(0.4, 0.43, 0.45))
    for k in range(0, size, p):
        fill_rect(img, seams, 0, k, size, 5, srgb(0.015, 0.018, 0.022))
        fill_rect(img, seams, k, 0, 5, size, srgb(0.015, 0.018, 0.022))
        fill_rect(img, bevel, 0, k + 5, size, 2, srgb(0.45, 0.48, 0.5))
        fill_rect(img, bevel, k + 5, 0, 2, size, srgb(0.45, 0.48, 0.5))
    save_png(img, "ground.png")
    img.delete()


# ------------------------------------------------------------------------------------------- sky

def ellipse(cx, cy, a, b, phi, t0=0.0, t1=2 * math.pi, n=160, centre_offset=(0.0, 0.0)):
    """Flat point list of an ellipse (semi-axes a along u, b along v) turned by phi (screen radians,
    y down, so a negative phi lifts its right end). centre_offset is in the ellipse's own frame."""
    cp, sp = math.cos(phi), math.sin(phi)
    ox, oy = centre_offset
    pts = []
    closed = abs((t1 - t0) - 2 * math.pi) < 1e-6
    for i in range(n if closed else n + 1):
        t = t0 + (t1 - t0) * i / n
        x, y = ox + a * math.cos(t), oy + b * math.sin(t)
        pts += [cx + x * cp - y * sp, cy + x * sp + y * cp]
    return pts


def frame_poly(cx, cy, phi, corners):
    """Flat point list of a polygon given in a turned frame (corners as (x, y) in that frame)."""
    cp, sp = math.cos(phi), math.sin(phi)
    pts = []
    for x, y in corners:
        pts += [cx + x * cp - y * sp, cy + x * sp + y * cp]
    return pts


def saturn(img, sx, sy, R, phi):
    """Saturn lit from the upper left: back half of the rings, the banded globe (slightly oblate),
    the rings' shadow on it, limb darkening and the night side, then the front half of the rings
    crossing the globe's lower half. Rings: C (dim), B (bright, with ringlets), the Cassini division,
    A. Seen from a little above the ring plane, so the ellipses are flat (ratio 0.24)."""
    ratio = 0.24
    oblate = 0.9
    disc = ellipse(sx, sy, R, R * oblate, phi)
    rr = random.Random(77)
    bands = [(1.24, 1.52, (0.34, 0.31, 0.27))]
    edges = [1.52 + (1.95 - 1.52) * k / 9 for k in range(10)]
    for a_in, a_out in zip(edges, edges[1:]):
        f = rr.uniform(0.86, 1.04)
        bands.append((a_in, a_out, (0.88 * f, 0.80 * f, 0.64 * f)))
    for a_in, a_out, f in ((2.03, 2.12, 0.92), (2.12, 2.205, 0.86), (2.215, 2.27, 0.8)):
        bands.append((a_in, a_out, (0.74 * f, 0.68 * f, 0.56 * f)))

    def rings(layer, side):
        big = 4.0 * R
        half = frame_poly(sx, sy, phi, [(-big, 0), (big, 0), (big, side * big), (-big, side * big)])
        for a_in, a_out, rgb in bands:
            img.select_polygon(REPLACE, ellipse(sx, sy, a_out * R, a_out * R * ratio, phi))
            img.select_polygon(SUBTRACT, ellipse(sx, sy, a_in * R, a_in * R * ratio, phi))
            img.select_polygon(INTERSECT, half)
            fill_selection(img, layer, srgb(*rgb))

    back = add_layer(img, "ring_back", alpha=True, opacity=90.0)
    rings(back, -1)

    halo = add_layer(img, "saturn_halo", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=28.0)
    img.select_polygon(REPLACE, ellipse(sx - 0.05 * R, sy - 0.03 * R, 1.05 * R, 1.05 * R * oblate, phi))
    fill_selection(img, halo, srgb(0.9, 0.82, 0.62))
    gegl(halo, "gegl:gaussian-blur", std_dev_x=R * 0.05, std_dev_y=R * 0.05)

    globe = add_layer(img, "globe", alpha=True)
    img.select_polygon(REPLACE, disc)
    fill_selection(img, globe, srgb(0.86, 0.76, 0.56))
    stripes = add_layer(img, "globe_bands", alpha=True)
    ry = R * oblate
    for y0, y1, rgb in [(-1.0, -0.62, (0.6, 0.62, 0.6)), (-0.62, -0.42, (0.8, 0.7, 0.52)),
                        (-0.42, -0.3, (0.9, 0.81, 0.62)), (-0.3, -0.12, (0.83, 0.71, 0.5)),
                        (-0.12, 0.1, (0.94, 0.86, 0.68)), (0.1, 0.22, (0.8, 0.68, 0.48)),
                        (0.22, 0.45, (0.88, 0.78, 0.58)), (0.45, 0.7, (0.77, 0.66, 0.49)),
                        (0.7, 1.0, (0.64, 0.61, 0.55))]:
        img.select_polygon(REPLACE, frame_poly(sx, sy, phi, [(-1.3 * R, y0 * ry), (1.3 * R, y0 * ry),
                                                             (1.3 * R, y1 * ry), (-1.3 * R, y1 * ry)]))
        fill_selection(img, stripes, srgb(*rgb))
    gegl(stripes, "gegl:gaussian-blur", std_dev_x=2.2, std_dev_y=2.2)
    streaks = add_layer(img, "globe_streaks", alpha=True, opacity=30.0)
    for _ in range(14):
        y = rr.uniform(-0.85, 0.85) * ry
        v = rr.choice([(0.98, 0.92, 0.78), (0.6, 0.5, 0.36)])
        img.select_polygon(REPLACE, frame_poly(sx, sy, phi, [(-1.3 * R, y), (1.3 * R, y), (1.3 * R, y + 1.2),
                                                             (-1.3 * R, y + 1.2)]))
        fill_selection(img, streaks, srgb(*v))
    clip_to(img, stripes, disc)
    clip_to(img, streaks, disc)

    # The rings' shadow on the globe: the B ring's front half, moved up the globe.
    rshadow = add_layer(img, "ring_shadow", alpha=True, mode=Gimp.LayerMode.MULTIPLY, opacity=70.0)
    off = (0.0, -0.3 * R)
    img.select_polygon(REPLACE, ellipse(sx, sy, 1.95 * R, 1.95 * R * ratio, phi, centre_offset=off))
    img.select_polygon(SUBTRACT, ellipse(sx, sy, 1.52 * R, 1.52 * R * ratio, phi, centre_offset=off))
    img.select_polygon(INTERSECT, frame_poly(sx, sy, phi, [(-3 * R, -0.3 * R), (3 * R, -0.3 * R), (3 * R, 3 * R),
                                                           (-3 * R, 3 * R)]))
    img.select_polygon(INTERSECT, disc)
    fill_selection(img, rshadow, srgb(0.35, 0.3, 0.26))

    # Limb and night are filled well past the disc before they are blurred and clipped to it: filled
    # only inside the disc, the blur pulled in the transparency around it and they came out half strength.
    around = (sx - 1.6 * R, sy - 1.6 * R, 3.2 * R, 3.2 * R)
    limb = add_layer(img, "limb", alpha=True, opacity=55.0)
    img.select_rectangle(REPLACE, *around)
    fill_selection(img, limb, srgb(0.16, 0.12, 0.08))
    img.select_polygon(REPLACE, ellipse(sx, sy, 0.84 * R, 0.84 * R * oblate, phi))
    limb.edit_clear()
    Gimp.Selection.none(img)
    gegl(limb, "gegl:gaussian-blur", std_dev_x=R * 0.09, std_dev_y=R * 0.09)
    clip_to(img, limb, disc)

    night = add_layer(img, "night", alpha=True, opacity=95.0)
    img.select_rectangle(REPLACE, *around)
    fill_selection(img, night, srgb(0.012, 0.012, 0.016))
    # The lit part: a disc shifted toward the sun (upper left), so about a third of the globe is night.
    img.select_ellipse(REPLACE, sx - 0.6 * R - 1.12 * R, sy - 0.28 * R - 1.06 * R, 2.24 * R, 2.12 * R)
    night.edit_clear()
    Gimp.Selection.none(img)
    gegl(night, "gegl:gaussian-blur", std_dev_x=R * 0.13, std_dev_y=R * 0.13)
    clip_to(img, night, disc)

    front = add_layer(img, "ring_front", alpha=True, opacity=92.0)
    rings(front, 1)


def our_ring(img, cx, hz):
    """Our own ring, rising from the road's vanishing point and curving up and to the right: a dark
    hull band widening as it climbs (it is nearer overhead), its sunlit left rim, a green-white light
    strip along each edge (the skyway up there), cross ribs that spread out as it nears, and a dotted
    line of lights down its middle."""

    def centre(t):
        return cx + 560.0 * t ** 1.3, hz + 3.0 - 360.0 * t

    def half_width(t):
        return 2.2 + 105.0 * t ** 1.4

    def normal(t):
        a, b = centre(max(t - 0.002, 0.0)), centre(t + 0.002)
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy)
        return -dy / n, dx / n

    def strip(f0, f1, t0=0.0, t1=1.0, n=90):
        """Polygon between offsets f0 and f1 (fractions of the half width, -1 is the left edge)."""
        left, right = [], []
        for i in range(n + 1):
            t = t0 + (t1 - t0) * i / n
            (x, y), (nx, ny), w = centre(t), normal(t), half_width(t)
            left += [x + nx * w * f0, y + ny * w * f0]
            right = [x + nx * w * f1, y + ny * w * f1] + right
        return left + right

    body = add_layer(img, "ring_body", alpha=True)
    img.select_polygon(REPLACE, strip(-1.0, 1.0))
    fill_selection(img, body, srgb(0.2, 0.23, 0.245))
    img.select_polygon(REPLACE, strip(-0.62, 0.62))
    fill_selection(img, body, srgb(0.06, 0.07, 0.08))
    rim = add_layer(img, "ring_rim", alpha=True)
    img.select_polygon(REPLACE, strip(-1.0, -0.85))
    fill_selection(img, rim, srgb(0.72, 0.78, 0.76))
    img.select_polygon(REPLACE, strip(0.88, 1.0))
    fill_selection(img, rim, srgb(0.28, 0.32, 0.33))
    ribs = add_layer(img, "ring_ribs", alpha=True, opacity=80.0)
    lights = add_layer(img, "ring_lights", alpha=True)
    k = 1
    while True:
        t = 0.012 * k ** 1.5
        if t > 1.0:
            break
        dt = 0.0025 + 0.004 * t
        # Ribs across the hull either side of the skyway, and only faintly across its road.
        img.select_polygon(REPLACE, strip(-0.85, -0.62, t, t + dt, 2))
        img.select_polygon(ADD, strip(0.62, 0.88, t, t + dt, 2))
        fill_selection(img, ribs, srgb(0.5, 0.56, 0.57))
        img.select_polygon(REPLACE, strip(-0.62, 0.62, t, t + dt * 0.6, 2))
        fill_selection(img, ribs, srgb(0.16, 0.19, 0.2))
        tm = 0.012 * (k + 0.5) ** 1.5
        if tm < 1.0:
            (x, y), r = centre(tm), 0.5 + 0.08 * half_width(tm)
            img.select_ellipse(REPLACE, x - r, y - r, 2 * r, 2 * r)
            fill_selection(img, lights, srgb(0.85, 1.0, 0.92))
        k += 1
    edge = add_layer(img, "ring_edges", alpha=True)
    glow = add_layer(img, "ring_glow", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=70.0)
    for f0, f1 in ((-0.66, -0.56), (0.56, 0.66)):
        for layer in (edge, glow):
            img.select_polygon(REPLACE, strip(f0, f1))
            fill_selection(img, layer, srgb(0.55, 1.0, 0.78))
    gegl(glow, "gegl:gaussian-blur", std_dev_x=4.0, std_dev_y=4.0)
    # Where the ring vanishes into the distance, a soft green-white haze.
    haze = add_layer(img, "ring_haze", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=40.0)
    img.select_ellipse(REPLACE, cx - 60, hz - 16, 120, 26)
    fill_selection(img, haze, srgb(0.16, 0.3, 0.27))
    gegl(haze, "gegl:gaussian-blur", std_dev_x=28.0, std_dev_y=10.0)


def stars(img, rr):
    dim = add_layer(img, "stars_dim", "gray", Gimp.LayerMode.SCREEN, 45.0)
    gegl(dim, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=9101)
    dim.threshold(Gimp.HistogramChannel.VALUE, 0.955, 1.0)
    gegl(dim, "gegl:gaussian-blur", std_dev_x=0.5, std_dev_y=0.5)
    mid = add_layer(img, "stars_mid", "gray", Gimp.LayerMode.SCREEN, 85.0)
    gegl(mid, "gegl:noise-rgb", red=0.5, green=0.5, blue=0.5, independent=False, seed=9103)
    mid.threshold(Gimp.HistogramChannel.VALUE, 0.988, 1.0)
    gegl(mid, "gegl:gaussian-blur", std_dev_x=0.7, std_dev_y=0.7)
    w, h = img.get_width(), img.get_height()
    bright = add_layer(img, "stars_bright", alpha=True, mode=Gimp.LayerMode.SCREEN)
    glow = add_layer(img, "stars_glow", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=60.0)
    tints = [(1.0, 1.0, 1.0), (0.8, 0.9, 1.0), (1.0, 0.92, 0.78), (0.85, 1.0, 0.95)]
    for _ in range(260):
        x, y = rr.uniform(0, w), rr.uniform(0, h * 0.52)
        r = rr.uniform(0.9, 1.7)
        tint = rr.choice(tints)
        img.select_ellipse(REPLACE, x - r, y - r, 2 * r, 2 * r)
        fill_selection(img, bright, srgb(*tint))
        img.select_ellipse(REPLACE, x - r * 3, y - r * 3, 6 * r, 6 * r)
        fill_selection(img, glow, srgb(tint[0] * 0.5, tint[1] * 0.5, tint[2] * 0.5))
    gegl(glow, "gegl:gaussian-blur", std_dev_x=2.5, std_dev_y=2.5)


def sky():
    w, h = 4096, 2048
    hz = h // 2
    cx = w / 2
    rr = random.Random(2049)
    img = new_image(w, h)
    base = add_layer(img, "base", srgb(0.004, 0.006, 0.012))
    # Space is black; just above the horizon a faint lift of scattered station light.
    img.select_rectangle(REPLACE, 0, int(hz * 0.7), w, hz - int(hz * 0.7))
    gradient(base, srgb(0.004, 0.006, 0.012), srgb(0.014, 0.024, 0.03), hz * 0.7, float(hz))
    fill_rect(img, base, 0, hz, w, h - hz, srgb(0.012, 0.018, 0.022))

    stars(img, rr)
    # A faint nebula: green-teal wisps with a violet edge, strongest high up, thinning to the horizon.
    for name, tint, opacity, seed, lo in (("nebula_green", (0.2, 0.62, 0.46), 46.0, 5501, 0.4),
                                          ("nebula_violet", (0.42, 0.26, 0.62), 30.0, 5503, 0.46)):
        neb = soft_noise(img, name, tint, Gimp.LayerMode.SCREEN, opacity, 5.0, 12.0, seed, lo, 1.0, 3.0)
        mask = neb.create_mask(Gimp.AddMaskType.WHITE)
        neb.add_mask(mask)
        img.select_rectangle(REPLACE, 0, int(hz * 0.6), w, hz - int(hz * 0.6))
        gradient(mask, "white", srgb(0.35, 0.35, 0.35), hz * 0.6, float(hz))
        fill_rect(img, mask, 0, hz, w, h - hz, "black")

    our_ring(img, cx, hz)
    saturn(img, cx - 250.0, hz - 72.0, 82.0, math.radians(-16.0))
    # Titan, a small hazy orange moon, and a speck of an icy moon further out.
    for x, y, r, rgb in ((cx - 95.0, hz - 40.0, 3.0, (0.88, 0.68, 0.42)), (cx - 455.0, hz - 104.0, 1.8,
                                                                                 (0.92, 0.94, 0.95))):
        moon_glow = add_layer(img, "moon_glow", alpha=True, mode=Gimp.LayerMode.SCREEN, opacity=30.0)
        img.select_ellipse(REPLACE, x - r * 3, y - r * 3, r * 6, r * 6)
        fill_selection(img, moon_glow, srgb(rgb[0] * 0.5, rgb[1] * 0.5, rgb[2] * 0.5))
        gegl(moon_glow, "gegl:gaussian-blur", std_dev_x=r, std_dev_y=r)
        moon = add_layer(img, "moon", alpha=True)
        img.select_ellipse(REPLACE, x - r, y - r, 2 * r, 2 * r)
        fill_selection(img, moon, srgb(*rgb))
    save_png(img, "sky.png")
    img.delete()


# ------------------------------------------------------------------------------------------ logo

def ring_wordmark(text, file_name, fonts, size, pad=110):
    """RING ROAD: clean white letters, widely spaced, with a soft green glow."""
    img = new_image(32, 32)
    font = pick_font(fonts)
    face = Gimp.TextLayer.new(img, text, font, size, Gimp.Unit.pixel())
    img.insert_layer(face, None, 0)
    face.set_color(color(srgb(0.97, 1.0, 0.98)))
    face.set_letter_spacing(20.0)
    w, h = face.get_width() + pad * 2, face.get_height() + pad * 2
    img.resize(w, h, pad, pad)
    face.resize_to_image_size()
    # Inserted at position 1 each time, so the last one sits just under the face.
    for name, rgb, grow, blur, opacity in (("wide_glow", (0.2, 0.95, 0.55), 10, 34.0, 70.0),
                                           ("glow", (0.5, 1.0, 0.74), 3, 9.0, 85.0)):
        layer = Gimp.Layer.new(img, name, w, h, Gimp.ImageType.RGBA_IMAGE, opacity, Gimp.LayerMode.NORMAL)
        img.insert_layer(layer, None, 1)
        layer.fill(Gimp.FillType.TRANSPARENT)
        img.select_item(REPLACE, face)
        Gimp.Selection.grow(img, grow)
        Gimp.context_set_foreground(color(srgb(*rgb)))
        layer.edit_fill(Gimp.FillType.FOREGROUND)
        Gimp.Selection.none(img)
        gegl(layer, "gegl:gaussian-blur", std_dev_x=blur, std_dev_y=blur)
    save_png(img, file_name)
    img.delete()


road()
ground()
sky()
ring_wordmark("RING ROAD", "region_logo.png", ["Futura Medium", "Avenir Next Demi Bold", "Avenir Next Medium",
                                               "Helvetica Neue Medium", "Gill Sans"], 112)
print("TEXTURES DONE")
