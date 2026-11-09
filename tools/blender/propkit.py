"""Shared toolkit for building region props in headless Blender.

A region's tools/themes/<id>/props.py imports this, builds its models with
Model, and calls export_all(). Conventions every region follows:
  - 1 Blender unit = 1 game unit, origin on the ground at the prop's centre;
  - Blender +Y (forward) becomes Godot -Z (down the road) on export;
  - buildings put their lit, road-facing side on Blender -X (the game turns
    props on the left side of the road around);
  - repeating props (poles, fences, lamps) are exactly one repeat long.
Run: blender --background --python tools/themes/<id>/props.py -- <out_dir> [preview.png]
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

rng = random.Random(1987)


def args() -> tuple[str, str | None]:
    argv = sys.argv[sys.argv.index("--") + 1:]
    return os.path.abspath(argv[0]), (os.path.abspath(argv[1]) if len(argv) > 1 else None)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, rough=0.85, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1)  # the workbench preview reads this
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        m.diffuse_color = (*emit, 1)
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


class Model:
    """Accumulates primitives into a single mesh, so each GLB is one draw per material."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _paint(self, verts, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        idx = self.mats.index(mat)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = idx

    def box(self, size, loc, mat, rot=(0, 0, 0)):
        mtx = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
        self._paint(bmesh.ops.create_cube(self.bm, size=1.0, matrix=mtx)["verts"], mat)

    def cyl(self, r1, r2, h, loc, mat, segs=12, rot=(0, 0, 0)):
        """r1 is the radius at the bottom, r2 at the top."""
        mtx = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4()
        v = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                                  radius1=r1, radius2=r2, depth=h, matrix=mtx)["verts"]
        self._paint(v, mat)

    def blob(self, r, loc, mat, subdiv=2, jitter=0.16, squash=1.0):
        mtx = Matrix.Translation(loc)
        v = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=r, matrix=mtx)["verts"]
        for vert in v:
            d = vert.co - Vector(loc)
            d *= 1.0 + rng.uniform(-jitter, jitter)
            d.z *= squash
            vert.co = Vector(loc) + d
        self._paint(v, mat)

    def beam(self, a, b, r, mat, segs=5):
        a, b = Vector(a), Vector(b)
        rot = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_euler()
        self.cyl(r, r, (b - a).length, (a + b) / 2, mat, segs=segs, rot=rot)

    def poly(self, verts, faces, mat):
        vs = [self.bm.verts.new(v) for v in verts]
        for f in faces:
            self.bm.faces.new([vs[i] for i in f])
        self.bm.verts.index_update()
        self._paint(vs, mat)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        for m in self.mats:
            mesh.materials.append(m)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def export_all(builders, out_dir: str, preview: str | None = None) -> None:
    os.makedirs(out_dir, exist_ok=True)
    objects = []
    for build in builders:
        obj = build()
        objects.append(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        path = os.path.join(out_dir, f"{obj.name}.glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_cameras=False, export_lights=False)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"EXPORTED {obj.name}: {tris} tris, {os.path.getsize(path) // 1024} KB")
    if preview:
        _contact_sheet(objects, preview)


def _contact_sheet(objects, path: str) -> None:
    """Workbench render of every prop in a row, to check shapes without the game."""
    x = 0.0
    for obj in objects:
        half = obj.dimensions.x / 2
        obj.location.x = x + half
        x += half * 2 + 3.0
    scene = bpy.context.scene
    cam = bpy.data.cameras.new("cam")
    cam_obj = bpy.data.objects.new("cam", cam)
    scene.collection.objects.link(cam_obj)
    tallest = max(o.dimensions.z for o in objects)
    cam.type = "ORTHO"
    cam.ortho_scale = max(x, tallest * 3.2)
    cam_obj.location = (x / 2, -200, tallest * 0.5)
    cam_obj.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam_obj
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 600
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
