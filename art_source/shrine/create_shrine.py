"""Create the first reproducible stylized asset and export it to Godot."""

from pathlib import Path

import bpy
from math import cos, sin
from mathutils import Vector


ROOT = Path("/home/cenkai/game_dev_plan")
SOURCE_PATH = ROOT / "art_source" / "shrine" / "stylized_shrine.blend"
EXPORT_PATH = ROOT / "game" / "content" / "props" / "shrine" / "stylized_shrine.glb"


def material(name: str, color: tuple[float, float, float, float], roughness: float):
    value = bpy.data.materials.new(name)
    value.diffuse_color = color
    value.use_nodes = True
    principled = value.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    return value


def cylinder(name: str, radius: float, depth: float, z: float, vertices: int, mat):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=(0.0, 0.0, z),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth_by_angle()
    return obj


def create_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    stone = material("M_Stone", (0.27, 0.34, 0.32, 1.0), 0.92)
    stone_light = material("M_Stone_Light", (0.42, 0.50, 0.45, 1.0), 0.88)
    crystal = material("M_Crystal", (0.20, 0.78, 0.72, 1.0), 0.22)
    principled = crystal.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Emission Color"].default_value = (0.12, 0.9, 0.8, 1.0)
    principled.inputs["Emission Strength"].default_value = 1.8

    cylinder("Shrine_Base", 1.35, 0.38, 0.19, 10, stone)
    cylinder("Shrine_Step", 1.02, 0.32, 0.49, 10, stone_light)
    cylinder("Shrine_Pillar", 0.48, 1.12, 1.18, 8, stone)

    for index, angle in enumerate((0.0, 2.094, 4.188)):
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        rune = bpy.context.object
        rune.name = f"Shrine_Rune_{index + 1:02d}"
        rune.scale = (0.08, 0.025, 0.34)
        rune.location = Vector((sin(angle) * 0.49, -cos(angle) * 0.49, 1.18))
        rune.rotation_euler[2] = angle
        rune.data.materials.append(crystal)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=2,
        radius=0.46,
        location=(0.0, 0.0, 1.98),
    )
    core = bpy.context.object
    core.name = "Shrine_Core"
    core.scale.z = 1.35
    core.rotation_euler[2] = 0.35
    core.data.materials.append(crystal)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0.0, 0.0, 0.0))
    root = bpy.context.object
    root.name = "StylizedShrine"
    for obj in tuple(bpy.context.scene.objects):
        if obj != root and obj.type == "MESH":
            obj.parent = root

    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def save_and_export() -> None:
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    EXPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
    )


create_scene()
save_and_export()
print(f"ASSET_PIPELINE_OK source={SOURCE_PATH} export={EXPORT_PATH}")
