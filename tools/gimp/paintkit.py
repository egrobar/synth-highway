"""Shared GIMP helpers for region art, run inside GIMP's batch Python.

A region's tools/themes/<id>/textures.py does `from paintkit import *`, calls
set_out() with its folder, and paints. GIMP 3 hides gegl:linear-gradient from
scripts, so gradients go through gradient() instead.
"""
import os
import random

import gi

gi.require_version("Gimp", "3.0")
gi.require_version("Gegl", "0.4")
from gi.repository import Gegl, Gimp, Gio

ROOT = os.environ["SYNTH_ROOT"]
OUT = os.path.join(ROOT, "game/assets/textures")
rng = random.Random(1987)




def color(css):
    c = Gegl.Color.new(css)
    return c


def new_image(w, h):
    return Gimp.Image.new(w, h, Gimp.ImageBaseType.RGB)


def add_layer(img, name, css=None, mode=Gimp.LayerMode.NORMAL, opacity=100.0, alpha=False):
    w, h = img.get_width(), img.get_height()
    layer = Gimp.Layer.new(img, name, w, h, Gimp.ImageType.RGBA_IMAGE, opacity, mode)
    img.insert_layer(layer, None, 0)
    if css:
        Gimp.context_set_foreground(color(css))
        layer.fill(Gimp.FillType.FOREGROUND)
    elif alpha:
        layer.fill(Gimp.FillType.TRANSPARENT)
    return layer


def gegl(drawable, op, **props):
    """Applies one GEGL operation destructively. Keyword underscores become dashes."""
    f = Gimp.DrawableFilter.new(drawable, op, op)
    cfg = f.get_config()
    for key, value in props.items():
        cfg.set_property(key.replace("_", "-"), value)
    f.update()
    drawable.merge_filter(f)


def gradient(drawable, top_css, bottom_css, y0, y1):
    """Vertical gradient inside the current selection. GIMP hides gegl:linear-gradient from scripts."""
    Gimp.context_set_foreground(color(top_css))
    Gimp.context_set_background(color(bottom_css))
    Gimp.context_set_gradient_fg_bg_rgb()
    drawable.edit_gradient_fill(Gimp.GradientType.LINEAR, 0.0, False, 1, 0.0, True, 0.0, y0, 0.0, y1)


def fill_selection(img, drawable, css):
    Gimp.context_set_foreground(color(css))
    drawable.edit_fill(Gimp.FillType.FOREGROUND)
    Gimp.Selection.none(img)


def save_png(img, name):
    flat = img.duplicate()
    layer = flat.merge_visible_layers(Gimp.MergeType.CLIP_TO_IMAGE)
    path = os.path.join(OUT, name)
    # Write beside the target and rename into place: Godot's importer, running for another
    # region at the same time, once read a half-written sky and cached it as invalid.
    temp = os.path.join(OUT, ".writing_" + name)
    Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, flat, Gio.File.new_for_path(temp), None)
    os.replace(temp, path)
    flat.delete()
    print("WROTE", name, os.path.getsize(path) // 1024, "KB")


def mottled(size, base, dark, name, detail):
    """Shared base for ground surfaces: flat colour, cloud mottling, fine speckle."""
    img = new_image(size, size)
    add_layer(img, "base", base)
    clouds = add_layer(img, "clouds", "gray", Gimp.LayerMode.MULTIPLY, 70.0)
    gegl(clouds, "gegl:noise-solid", x_size=detail, y_size=detail, detail=4, tileable=True,
         turbulent=True, seed=rng.randint(1, 99999), width=size, height=size)
    speckle = add_layer(img, "speckle", "gray", Gimp.LayerMode.OVERLAY, 60.0)
    gegl(speckle, "gegl:noise-rgb", red=0.34, green=0.34, blue=0.34, independent=False,
         seed=rng.randint(1, 99999))
    return img


def ridge(img, layer, base_y, amp, css, seed):
    """A jagged horizon silhouette that wraps across the panorama's seam."""
    r = random.Random(seed)
    w, h = img.get_width(), img.get_height()
    knots = 46
    heights = [r.uniform(0.25, 1.0) for _ in range(knots)]
    pts = []
    for i in range(knots + 1):
        pts.extend([i * w / knots, base_y - heights[i % knots] * amp])
    pts.extend([float(w), float(h), 0.0, float(h)])
    img.select_polygon(Gimp.ChannelOps.REPLACE, pts)
    fill_selection(img, layer, css)


def pick_font(candidates):
    for name in candidates:
        font = Gimp.Font.get_by_name(name)
        if font:
            return font
    available = Gimp.fonts_get_list("")
    print("FONT FALLBACK", available[0].get_name())
    return available[0]


def wordmark(text, file_name, fonts, size, face_css, glow_css, pad=90):
    img = new_image(32, 32)
    font = pick_font(fonts)
    text_layer = Gimp.TextLayer.new(img, text, font, size, Gimp.Unit.pixel())
    img.insert_layer(text_layer, None, 0)
    text_layer.set_color(color(face_css))
    text_layer.set_letter_spacing(6.0)
    w, h = text_layer.get_width() + pad * 2, text_layer.get_height() + pad * 2
    img.resize(w, h, pad, pad)
    text_layer.resize_to_image_size()
    Gimp.context_set_foreground(color(glow_css))
    img.select_item(Gimp.ChannelOps.REPLACE, text_layer)
    glow_px = Gimp.Layer.new(img, "glow", w, h, Gimp.ImageType.RGBA_IMAGE, 100.0, Gimp.LayerMode.NORMAL)
    img.insert_layer(glow_px, None, 1)
    glow_px.fill(Gimp.FillType.TRANSPARENT)
    glow_px.edit_fill(Gimp.FillType.FOREGROUND)
    Gimp.Selection.none(img)
    gegl(glow_px, "gegl:gaussian-blur", std_dev_x=22.0, std_dev_y=22.0)
    # Merge visible keeps transparency, so the logo sits over the live 3D scene.
    save_png(img, file_name)
    img.delete()


def set_out(relative: str) -> None:
    """Where save_png() writes, relative to the repo root."""
    global OUT
    OUT = os.path.join(ROOT, relative)
    os.makedirs(OUT, exist_ok=True)


def srgb(r: float, g: float, b: float) -> str:
    """An on-screen (sRGB) colour, 0-1 per channel, as the rgb() string GEGL expects.
    GEGL reads "rgb(...)" as LINEAR light, so typing screen colours straight in comes out pale
    and washed out (found building Red Frontier, 2026-11-10). Use srgb(...) wherever a colour
    was picked by eye."""
    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return "rgb(%.5f,%.5f,%.5f)" % (lin(r), lin(g), lin(b))
