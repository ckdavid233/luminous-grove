"""Build a reproducible low-poly rigged character with three game animations."""

from pathlib import Path
from math import radians

import bpy
from mathutils import Vector


ROOT = Path("/home/cenkai/game_dev_plan")
SOURCE_PATH = ROOT / "art_source" / "player" / "spirit_child.blend"
EXPORT_PATH = ROOT / "game" / "content" / "characters" / "player" / "spirit_child.glb"


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    emission_strength: float = 0.0,
):
    value = bpy.data.materials.new(name)
    value.diffuse_color = color
    value.use_nodes = True
    principled = value.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    if emission_strength:
        principled.inputs["Emission Color"].default_value = color
        principled.inputs["Emission Strength"].default_value = emission_strength
    return value


def add_ellipsoid(name: str, location, scale, mat, bone_name: str):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bind_to_bone(obj, bone_name)
    return obj


def add_limb(name: str, start, end, radius: float, mat, bone_name: str):
    start_vector = Vector(start)
    end_vector = Vector(end)
    direction = end_vector - start_vector
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=radius,
        depth=direction.length,
        location=(start_vector + end_vector) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = Vector((0.0, 0.0, 1.0)).rotation_difference(direction).to_euler()
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bind_to_bone(obj, bone_name)
    return obj


def bind_to_bone(obj, bone_name: str) -> None:
    obj.parent = armature_object
    obj.matrix_parent_inverse = armature_object.matrix_world.inverted()
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    modifier = obj.modifiers.new(name="Armature", type="ARMATURE")
    modifier.object = armature_object


def create_bone(name: str, head, tail, parent=None):
    bone = armature_object.data.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.parent = parent
    return bone


def clear_pose() -> None:
    for pose_bone in armature_object.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)


def key_bone(bone_name: str, frame: int, rotation=(0.0, 0.0, 0.0), location=None, scale=None):
    bone = armature_object.pose.bones[bone_name]
    bone.rotation_euler = rotation
    bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
    if location is not None:
        bone.location = location
        bone.keyframe_insert(data_path="location", frame=frame, group=bone_name)
    if scale is not None:
        bone.scale = scale
        bone.keyframe_insert(data_path="scale", frame=frame, group=bone_name)


def create_action(name: str, end_frame: int, poses) -> None:
    clear_pose()
    action = bpy.data.actions.new(name=name)
    action.use_fake_user = True
    armature_object.animation_data.action = action
    for pose in poses:
        frame = pose["frame"]
        for bone_name, transform in pose["bones"].items():
            key_bone(
                bone_name,
                frame,
                transform.get("rotation", (0.0, 0.0, 0.0)),
                transform.get("location"),
                transform.get("scale"),
            )
    for fcurve in action.fcurves:
        for point in fcurve.keyframe_points:
            point.interpolation = "BEZIER"
    action.frame_start = 1
    action.frame_end = end_frame


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

skin = make_material("M_Skin", (0.93, 0.73, 0.54, 1.0), 0.86)
cloth = make_material("M_Cloth", (0.19, 0.47, 0.58, 1.0), 0.91)
cloth_light = make_material("M_Cloth_Light", (0.43, 0.72, 0.70, 1.0), 0.82)
spirit = make_material("M_Spirit", (0.48, 1.0, 0.88, 1.0), 0.25, 1.4)

armature_data = bpy.data.armatures.new("SpiritChild_Rig")
armature_object = bpy.data.objects.new("SpiritChild_Rig", armature_data)
bpy.context.collection.objects.link(armature_object)
bpy.context.view_layer.objects.active = armature_object
armature_object.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")

root = create_bone("Root", (0, 0, 0.08), (0, 0, 0.32))
hips = create_bone("Hips", (0, 0, 0.32), (0, 0, 0.78), root)
torso = create_bone("Torso", (0, 0, 0.78), (0, 0, 1.42), hips)
head = create_bone("Head", (0, 0, 1.42), (0, 0, 1.96), torso)

upper_arm_l = create_bone("UpperArm_L", (0.22, 0, 1.3), (0.58, 0, 1.12), torso)
lower_arm_l = create_bone("LowerArm_L", (0.58, 0, 1.12), (0.84, 0, 0.92), upper_arm_l)
upper_arm_r = create_bone("UpperArm_R", (-0.22, 0, 1.3), (-0.58, 0, 1.12), torso)
lower_arm_r = create_bone("LowerArm_R", (-0.58, 0, 1.12), (-0.84, 0, 0.92), upper_arm_r)

upper_leg_l = create_bone("UpperLeg_L", (0.15, 0, 0.52), (0.17, 0, 0.15), hips)
lower_leg_l = create_bone("LowerLeg_L", (0.17, 0, 0.15), (0.17, 0, -0.28), upper_leg_l)
upper_leg_r = create_bone("UpperLeg_R", (-0.15, 0, 0.52), (-0.17, 0, 0.15), hips)
lower_leg_r = create_bone("LowerLeg_R", (-0.17, 0, 0.15), (-0.17, 0, -0.28), upper_leg_r)

bpy.ops.object.mode_set(mode="OBJECT")

add_ellipsoid("Body", (0, 0, 0.98), (0.34, 0.25, 0.48), cloth, "Torso")
add_ellipsoid("Cape", (0, 0.13, 0.9), (0.39, 0.10, 0.52), cloth_light, "Torso")
add_ellipsoid("Head", (0, 0, 1.62), (0.31, 0.29, 0.34), skin, "Head")
add_ellipsoid("SpiritMark", (0, -0.285, 1.64), (0.075, 0.025, 0.11), spirit, "Head")

add_limb("UpperArm_L", (0.22, 0, 1.3), (0.58, 0, 1.12), 0.105, cloth, "UpperArm_L")
add_limb("LowerArm_L", (0.58, 0, 1.12), (0.84, 0, 0.92), 0.09, skin, "LowerArm_L")
add_limb("UpperArm_R", (-0.22, 0, 1.3), (-0.58, 0, 1.12), 0.105, cloth, "UpperArm_R")
add_limb("LowerArm_R", (-0.58, 0, 1.12), (-0.84, 0, 0.92), 0.09, skin, "LowerArm_R")
add_limb("UpperLeg_L", (0.15, 0, 0.52), (0.17, 0, 0.15), 0.13, cloth, "UpperLeg_L")
add_limb("LowerLeg_L", (0.17, 0, 0.15), (0.17, 0, -0.28), 0.115, cloth_light, "LowerLeg_L")
add_limb("UpperLeg_R", (-0.15, 0, 0.52), (-0.17, 0, 0.15), 0.13, cloth, "UpperLeg_R")
add_limb("LowerLeg_R", (-0.17, 0, 0.15), (-0.17, 0, -0.28), 0.115, cloth_light, "LowerLeg_R")

armature_object.animation_data_create()
create_action(
    "Idle",
    48,
    [
        {"frame": 1, "bones": {"Torso": {"scale": (1, 1, 1)}, "Head": {"rotation": (0, 0, radians(-2))}}},
        {"frame": 24, "bones": {"Torso": {"scale": (1.015, 1.015, 1.035)}, "Head": {"rotation": (0, 0, radians(2))}}},
        {"frame": 48, "bones": {"Torso": {"scale": (1, 1, 1)}, "Head": {"rotation": (0, 0, radians(-2))}}},
    ],
)
create_action(
    "Walk",
    24,
    [
        {
            "frame": 1,
            "bones": {
                "UpperLeg_L": {"rotation": (radians(30), 0, 0)},
                "UpperLeg_R": {"rotation": (radians(-30), 0, 0)},
                "UpperArm_L": {"rotation": (radians(-20), 0, radians(-5))},
                "UpperArm_R": {"rotation": (radians(20), 0, radians(5))},
            },
        },
        {
            "frame": 7,
            "bones": {
                "Root": {"location": (0, 0, 0.045)},
                "UpperLeg_L": {"rotation": (0, 0, 0)},
                "UpperLeg_R": {"rotation": (0, 0, 0)},
            },
        },
        {
            "frame": 13,
            "bones": {
                "UpperLeg_L": {"rotation": (radians(-30), 0, 0)},
                "UpperLeg_R": {"rotation": (radians(30), 0, 0)},
                "UpperArm_L": {"rotation": (radians(20), 0, radians(-5))},
                "UpperArm_R": {"rotation": (radians(-20), 0, radians(5))},
            },
        },
        {
            "frame": 19,
            "bones": {
                "Root": {"location": (0, 0, 0.045)},
                "UpperLeg_L": {"rotation": (0, 0, 0)},
                "UpperLeg_R": {"rotation": (0, 0, 0)},
            },
        },
        {
            "frame": 24,
            "bones": {
                "UpperLeg_L": {"rotation": (radians(30), 0, 0)},
                "UpperLeg_R": {"rotation": (radians(-30), 0, 0)},
                "UpperArm_L": {"rotation": (radians(-20), 0, radians(-5))},
                "UpperArm_R": {"rotation": (radians(20), 0, radians(5))},
            },
        },
    ],
)
create_action(
    "Interact",
    42,
    [
        {"frame": 1, "bones": {"UpperArm_L": {"rotation": (0, 0, 0)}, "UpperArm_R": {"rotation": (0, 0, 0)}}},
        {
            "frame": 16,
            "bones": {
                "UpperArm_L": {"rotation": (radians(-55), radians(-15), radians(-18))},
                "LowerArm_L": {"rotation": (radians(-35), 0, 0)},
                "UpperArm_R": {"rotation": (radians(-55), radians(15), radians(18))},
                "LowerArm_R": {"rotation": (radians(-35), 0, 0)},
                "Head": {"rotation": (radians(-8), 0, 0)},
            },
        },
        {
            "frame": 30,
            "bones": {
                "UpperArm_L": {"rotation": (radians(-48), radians(-12), radians(-15))},
                "UpperArm_R": {"rotation": (radians(-48), radians(12), radians(15))},
            },
        },
        {"frame": 42, "bones": {"UpperArm_L": {"rotation": (0, 0, 0)}, "UpperArm_R": {"rotation": (0, 0, 0)}}},
    ],
)

bpy.context.scene.render.fps = 24
armature_object.animation_data.action = bpy.data.actions["Idle"]
SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
EXPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=str(EXPORT_PATH),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_nla_strips=False,
    export_materials="EXPORT",
)
print(
    "PLAYER_ASSET_OK",
    f"source={SOURCE_PATH}",
    f"export={EXPORT_PATH}",
    f"actions={','.join(sorted(bpy.data.actions.keys()))}",
)
