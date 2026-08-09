"""Render a lightweight Eevee preview of the reproducible shrine asset."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path("/home/cenkai/game_dev_plan")
SOURCE_PATH = ROOT / "art_source" / "shrine" / "stylized_shrine.blend"
PREVIEW_PATH = ROOT / "previews" / "stylized_shrine.png"


def look_at(obj, point: Vector) -> None:
    obj.rotation_euler = (point - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.open_mainfile(filepath=str(SOURCE_PATH))

bpy.ops.mesh.primitive_plane_add(size=30.0, location=(0.0, 0.0, -0.01))
ground = bpy.context.object
ground.name = "Preview_Ground"
ground_material = bpy.data.materials.new("Preview_Ground_Material")
ground_material.diffuse_color = (0.12, 0.20, 0.17, 1.0)
ground.data.materials.append(ground_material)

bpy.ops.object.light_add(type="AREA", location=(3.5, -4.0, 6.0))
key = bpy.context.object
key.name = "Preview_Key"
key.data.energy = 850.0
key.data.color = (1.0, 0.72, 0.48)
key.data.shape = "DISK"
key.data.size = 5.0
look_at(key, Vector((0.0, 0.0, 1.0)))

bpy.ops.object.light_add(type="AREA", location=(-4.0, 1.5, 3.0))
fill = bpy.context.object
fill.name = "Preview_Fill"
fill.data.energy = 620.0
fill.data.color = (0.25, 0.75, 0.82)
fill.data.size = 4.0
look_at(fill, Vector((0.0, 0.0, 1.2)))

bpy.ops.object.camera_add(location=(5.4, -7.2, 4.1))
camera = bpy.context.object
camera.data.lens = 58.0
look_at(camera, Vector((0.0, 0.0, 1.0)))
bpy.context.scene.camera = camera

world = bpy.context.scene.world
world.color = (0.025, 0.045, 0.055)
world.use_nodes = True
background = world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = (0.018, 0.04, 0.05, 1.0)
background.inputs["Strength"].default_value = 0.32

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.filepath = str(PREVIEW_PATH)
scene.view_settings.look = "AgX - Medium High Contrast"
PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"SHRINE_PREVIEW_OK output={PREVIEW_PATH}")

