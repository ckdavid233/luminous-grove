from pathlib import Path
from math import radians
from mathutils import Vector
import bpy

from bl_ext.user_default.mpfb.services import ExportService
from bl_ext.user_default.mpfb.services import ObjectService
from bl_ext.user_default.mpfb.services import RandomizationService
from bl_ext.user_default.mpfb.services import TargetService
from bl_ext.user_default.mpfb.ui.new_human.randomize.randomizeproperties import (
    RANDOMIZE_PROPERTIES,
)


SOURCE_PATH = Path(
    "/home/cenkai/game_dev_plan/art_source/realistic_player/ji_realistic.blend"
)
EXPORT_PATH = Path(
    "/home/cenkai/game_dev_plan/game/content/characters/realistic_player/ji_realistic.glb"
)
PREVIEW_PATH = Path(
    "/home/cenkai/game_dev_plan/previews/realistic_character.png"
)


def set_random_property(name, value):
    RANDOMIZE_PROPERTIES.set_value(
        name,
        value,
        entity_reference=bpy.context.scene,
    )


def configure_character():
    set_random_property("seed", 20260731)
    set_random_property("new_random_seed", False)
    set_random_property("scale_factor", "METER")
    set_random_property("detailed_helpers", True)
    set_random_property("extra_vertex_groups", True)
    set_random_property("mask_helpers", True)
    set_random_property("add_rig", "game_engine")
    set_random_property("add_subdiv_modifier", False)
    set_random_property("randomize_details", False)

    set_random_property("discrete_gender", True)
    set_random_property("gender_allow_female", True)
    set_random_property("gender_allow_male", False)
    set_random_property("discrete_age", True)
    for age in ["baby", "child", "young", "middleage", "old"]:
        set_random_property("age_allow_" + age, age == "young")
    set_random_property("discrete_race", True)
    for race in ["asian", "caucasian", "african"]:
        set_random_property("race_allow_" + race, race == "asian")

    for name, neutral, deviation in [
        ("muscle", 0.43, 0.04),
        ("weight", 0.47, 0.04),
        ("height", 0.48, 0.025),
        ("proportions", 0.52, 0.025),
        ("cupsize", 0.43, 0.025),
        ("firmness", 0.55, 0.025),
    ]:
        set_random_property(name + "_neutral", neutral)
        set_random_property(name + "_deviation", deviation)

    set_random_property("randomize_skin", True)
    set_random_property("match_gender", True)
    set_random_property("match_age", True)
    set_random_property("match_race", True)
    set_random_property("skin_include", "young_asian_female")
    set_random_property("skin_exclude", "special_suit")
    set_random_property("skin_type", "GAMEENGINE")

    set_random_property("asset_material_type", "GAMEENGINE")
    set_random_property("eyes_mode", "HIGHPOLY")
    set_random_property("eyes_material_type", "GAMEENGINE")
    set_random_property("eyes_randomize_alt_materials", False)
    set_random_property("hair_randomize", True)
    set_random_property("hair_match_gender", True)
    set_random_property("hair_include", "long01")
    set_random_property("hair_exclude", "")
    set_random_property("hair_randomize_alt_materials", False)

    for bodypart, include in [
        ("eyebrows", "eyebrow003"),
        ("eyelashes", "eyelashes01"),
        ("teeth", "teeth_base"),
        ("tongue", "tongue01"),
    ]:
        set_random_property(bodypart + "_enable", True)
        set_random_property(bodypart + "_include", include)
        set_random_property(bodypart + "_exclude", "")

    for slot in RandomizationService.get_clothes_slots():
        set_random_property("clothes_" + slot + "_enable", False)
    set_random_property("clothes_full_body_enable", True)
    set_random_property("clothes_full_body_chance", 100)
    set_random_property("clothes_full_body_include_any", "")
    set_random_property(
        "clothes_full_body_include_female",
        "female_casualsuit01",
    )
    set_random_property("clothes_full_body_include_male", "")
    set_random_property("clothes_full_body_exclude", "")
    set_random_property("clothes_feet_enable", True)
    set_random_property("clothes_feet_chance", 100)
    set_random_property("clothes_feet_include_any", "shoes01")
    set_random_property("clothes_feet_include_female", "")
    set_random_property("clothes_feet_include_male", "")
    set_random_property("clothes_feet_exclude", "")


def set_principled_color(material, color, roughness=None):
    if (
        material is None
        or not material.use_nodes
        or material.get("ji_art_directed", False)
    ):
        return
    node = next(
        (
            item
            for item in material.node_tree.nodes
            if item.type == "BSDF_PRINCIPLED"
        ),
        None,
    )
    if node is None:
        return
    if "Base Color" in node.inputs:
        base_color = node.inputs["Base Color"]
        if base_color.is_linked:
            old_link = base_color.links[0]
            old_output = old_link.from_socket
            material.node_tree.links.remove(old_link)
            multiply = material.node_tree.nodes.new("ShaderNodeMixRGB")
            multiply.name = "Ji_Color_Tint"
            multiply.label = "Ji material tint"
            multiply.blend_type = "MULTIPLY"
            multiply.inputs[0].default_value = 1.0
            multiply.inputs[2].default_value = color
            material.node_tree.links.new(old_output, multiply.inputs[1])
            material.node_tree.links.new(multiply.outputs[0], base_color)
        else:
            base_color.default_value = color
    if roughness is not None and "Roughness" in node.inputs:
        node.inputs["Roughness"].default_value = roughness
    material["ji_art_directed"] = True


def art_direct_materials(root):
    objects = [root, *root.children_recursive]
    for obj in objects:
        if obj.type != "MESH":
            continue
        object_name = obj.name.lower()
        for slot in obj.material_slots:
            material = slot.material
            if "long01" in object_name or "hair" in object_name:
                set_principled_color(
                    material,
                    (0.012, 0.018, 0.022, 1.0),
                    0.32,
                )
            elif "casualsuit" in object_name or "clothes" in object_name:
                set_principled_color(
                    material,
                    (0.035, 0.12, 0.13, 1.0),
                    0.72,
                )
            elif "shoes" in object_name:
                set_principled_color(
                    material,
                    (0.025, 0.035, 0.04, 1.0),
                    0.58,
                )


def make_accessory_material(name, color, roughness, metallic=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in principled.inputs:
        principled.inputs["Specular IOR Level"].default_value = 0.32
    return material


def parent_to_bone_preserving_world(obj, armature, bone_name):
    bpy.context.view_layer.update()
    world_matrix = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    bpy.context.view_layer.update()
    obj.matrix_world = world_matrix


def add_box_accessory(name, location, dimensions, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new(name="SoftenedEdges", type="BEVEL")
    bevel.width = min(dimensions) * 0.24
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(material)
    return obj


def add_travel_accessories(export_root):
    cloth = make_accessory_material(
        "Ji_Travel_Sash",
        (0.008, 0.045, 0.052, 1.0),
        0.78,
    )
    leather = make_accessory_material(
        "Ji_Weathered_Leather",
        (0.055, 0.028, 0.015, 1.0),
        0.72,
    )
    brass = make_accessory_material(
        "Ji_Memory_Brass",
        (0.34, 0.22, 0.075, 1.0),
        0.34,
        0.62,
    )

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.168,
        minor_radius=0.014,
        major_segments=32,
        minor_segments=6,
        location=(0.0, 0.0, 0.845),
    )
    belt = bpy.context.object
    belt.name = "Ji_Travel_Belt"
    belt.scale.y = 0.73
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    belt.data.materials.append(leather)
    parent_to_bone_preserving_world(belt, export_root, "pelvis")

    sash_start = Vector((-0.145, -0.145, 1.165))
    sash_end = Vector((0.145, -0.145, 0.875))
    sash_direction = sash_end - sash_start
    sash = add_box_accessory(
        "Ji_Crossbody_Sash",
        tuple((sash_start + sash_end) * 0.5),
        (0.052, 0.012, sash_direction.length),
        cloth,
    )
    sash.rotation_euler = sash_direction.to_track_quat("Z", "Y").to_euler()
    parent_to_bone_preserving_world(sash, export_root, "spine_02")

    pouch = add_box_accessory(
        "Ji_Memory_Pouch",
        (0.205, -0.105, 0.785),
        (0.105, 0.055, 0.135),
        leather,
    )
    pouch.rotation_euler.y = radians(-8.0)
    parent_to_bone_preserving_world(pouch, export_root, "pelvis")

    buckle = add_box_accessory(
        "Ji_Belt_Clasp",
        (0.0, -0.135, 0.845),
        (0.052, 0.018, 0.038),
        brass,
    )
    parent_to_bone_preserving_world(buckle, export_root, "pelvis")

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.027,
        minor_radius=0.005,
        major_segments=24,
        minor_segments=6,
        location=(-0.022, -0.158, 1.055),
        rotation=(radians(90.0), 0.0, 0.0),
    )
    seal = bpy.context.object
    seal.name = "Ji_Rain_Memory_Seal"
    seal.data.materials.append(brass)
    parent_to_bone_preserving_world(seal, export_root, "spine_03")


def create_export_copy(source_root):
    export_collection = bpy.data.collections.new("Godot_Export")
    bpy.context.scene.collection.children.link(export_collection)
    export_root = ExportService.create_character_copy(
        source_root,
        name_suffix="_Game",
        place_in_collection=export_collection,
    )
    export_root.name = "Ji_Realistic_Rig"
    export_basemesh = ObjectService.find_object_of_type_amongst_nearest_relatives(
        export_root
    )
    TargetService.bake_targets(export_basemesh)
    ExportService.bake_modifiers_remove_helpers(
        export_basemesh,
        bake_masks=True,
        bake_subdiv=False,
        remove_helpers=True,
        also_proxy=True,
    )
    for obj in [source_root, *source_root.children_recursive]:
        obj.hide_render = True
        obj.hide_set(True)
    return export_root


def clear_pose(armature):
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)


def key_bone(armature, bone_name, frame, transform):
    bone = armature.pose.bones.get(bone_name)
    if bone is None:
        raise RuntimeError("Animation bone is missing: " + bone_name)
    bone.rotation_euler = transform.get("rotation", (0.0, 0.0, 0.0))
    bone.keyframe_insert(
        data_path="rotation_euler",
        frame=frame,
        group=bone_name,
    )
    if "location" in transform:
        bone.location = transform["location"]
        bone.keyframe_insert(
            data_path="location",
            frame=frame,
            group=bone_name,
        )
    if "scale" in transform:
        bone.scale = transform["scale"]
        bone.keyframe_insert(
            data_path="scale",
            frame=frame,
            group=bone_name,
        )


def create_action(armature, name, end_frame, poses):
    clear_pose(armature)
    action = bpy.data.actions.new(name=name)
    action.use_fake_user = True
    armature.animation_data.action = action
    for pose in poses:
        for bone_name, transform in pose["bones"].items():
            key_bone(
                armature,
                bone_name,
                pose["frame"],
                transform,
            )
    for fcurve in action.fcurves:
        for point in fcurve.keyframe_points:
            point.interpolation = "BEZIER"
            point.handle_left_type = "AUTO_CLAMPED"
            point.handle_right_type = "AUTO_CLAMPED"
    action.frame_start = 1
    action.frame_end = end_frame


def add_secondary_motion(armature):
    """Add small overlapping motion so the clips do not read as rigid poses."""
    key_sets = {
        "Idle": [
            (1, "neck_01", (radians(-0.8), radians(-1.4), radians(-0.8))),
            (1, "head", (radians(-0.3), radians(1.0), radians(-0.6))),
            (24, "neck_01", (radians(0.7), radians(1.2), radians(0.7))),
            (24, "head", (radians(0.4), radians(-0.8), radians(0.5))),
            (48, "neck_01", (radians(-0.8), radians(-1.4), radians(-0.8))),
            (48, "head", (radians(-0.3), radians(1.0), radians(-0.6))),
        ],
        "Walk": [
            (1, "foot_l", (radians(-4.0), 0.0, radians(-2.0))),
            (1, "foot_r", (radians(4.0), 0.0, radians(2.0))),
            (6, "foot_l", (radians(7.0), 0.0, radians(1.0))),
            (6, "foot_r", (radians(-7.0), 0.0, radians(-1.0))),
            (12, "foot_l", (radians(-5.0), 0.0, radians(2.0))),
            (12, "foot_r", (radians(5.0), 0.0, radians(-2.0))),
            (18, "foot_l", (radians(7.0), 0.0, radians(1.0))),
            (18, "foot_r", (radians(-7.0), 0.0, radians(-1.0))),
            (24, "foot_l", (radians(-4.0), 0.0, radians(-2.0))),
            (24, "foot_r", (radians(4.0), 0.0, radians(2.0))),
            (1, "neck_01", (radians(1.0), 0.0, radians(-1.0))),
            (12, "neck_01", (radians(-1.0), 0.0, radians(1.0))),
            (24, "neck_01", (radians(1.0), 0.0, radians(-1.0))),
        ],
        "Run": [
            (1, "foot_l", (radians(-8.0), 0.0, radians(-3.0))),
            (1, "foot_r", (radians(8.0), 0.0, radians(3.0))),
            (5, "foot_l", (radians(12.0), 0.0, radians(2.0))),
            (5, "foot_r", (radians(-12.0), 0.0, radians(-2.0))),
            (10, "foot_l", (radians(-10.0), 0.0, radians(3.0))),
            (10, "foot_r", (radians(10.0), 0.0, radians(-3.0))),
            (14, "foot_l", (radians(12.0), 0.0, radians(2.0))),
            (14, "foot_r", (radians(-12.0), 0.0, radians(-2.0))),
            (18, "foot_l", (radians(-8.0), 0.0, radians(-3.0))),
            (18, "foot_r", (radians(8.0), 0.0, radians(3.0))),
            (1, "neck_01", (radians(2.0), 0.0, radians(-1.5))),
            (10, "neck_01", (radians(-1.5), 0.0, radians(1.5))),
            (18, "neck_01", (radians(2.0), 0.0, radians(-1.5))),
        ],
        "Jump": [
            (1, "foot_l", (radians(-8.0), 0.0, radians(-2.0))),
            (1, "foot_r", (radians(-8.0), 0.0, radians(2.0))),
            (7, "foot_l", (radians(12.0), 0.0, radians(-1.0))),
            (7, "foot_r", (radians(12.0), 0.0, radians(1.0))),
            (14, "foot_l", (radians(7.0), 0.0, radians(-1.0))),
            (14, "foot_r", (radians(7.0), 0.0, radians(1.0))),
            (20, "foot_l", (radians(3.0), 0.0, radians(-1.0))),
            (20, "foot_r", (radians(3.0), 0.0, radians(1.0))),
        ],
        "Fall": [
            (1, "neck_01", (radians(2.0), 0.0, radians(-1.0))),
            (12, "neck_01", (radians(-2.0), 0.0, radians(1.0))),
            (24, "neck_01", (radians(2.0), 0.0, radians(-1.0))),
            (1, "foot_l", (radians(4.0), 0.0, radians(-2.0))),
            (1, "foot_r", (radians(4.0), 0.0, radians(2.0))),
            (24, "foot_l", (radians(10.0), 0.0, radians(-2.0))),
            (24, "foot_r", (radians(10.0), 0.0, radians(2.0))),
        ],
        "Land": [
            (1, "foot_l", (radians(-12.0), 0.0, radians(-2.0))),
            (1, "foot_r", (radians(-12.0), 0.0, radians(2.0))),
            (7, "foot_l", (radians(5.0), 0.0, radians(-1.0))),
            (7, "foot_r", (radians(5.0), 0.0, radians(1.0))),
            (14, "foot_l", (radians(1.0), 0.0, radians(-1.0))),
            (14, "foot_r", (radians(1.0), 0.0, radians(1.0))),
        ],
        "Interact": [
            (1, "hand_l", (radians(-2.0), radians(-2.0), radians(-2.0))),
            (1, "hand_r", (radians(-2.0), radians(2.0), radians(2.0))),
            (15, "hand_l", (radians(-7.0), radians(-4.0), radians(-4.0))),
            (15, "hand_r", (radians(-7.0), radians(4.0), radians(4.0))),
            (27, "hand_l", (radians(-5.0), radians(-3.0), radians(-3.0))),
            (27, "hand_r", (radians(-5.0), radians(3.0), radians(3.0))),
            (42, "hand_l", (radians(-2.0), radians(-2.0), radians(-2.0))),
            (42, "hand_r", (radians(-2.0), radians(2.0), radians(2.0))),
        ],
    }
    for action_name, entries in key_sets.items():
        action = bpy.data.actions.get(action_name)
        if action is None:
            continue
        armature.animation_data.action = action
        for frame, bone_name, rotation in entries:
            bone = armature.pose.bones.get(bone_name)
            if bone is None:
                continue
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = rotation
            bone.keyframe_insert(
                data_path="rotation_euler",
                frame=frame,
                group=bone_name,
            )
        for fcurve in action.fcurves:
            for point in fcurve.keyframe_points:
                point.interpolation = "BEZIER"
                point.handle_left_type = "AUTO_CLAMPED"
                point.handle_right_type = "AUTO_CLAMPED"


def create_character_actions(export_root):
    if export_root.type != "ARMATURE":
        raise RuntimeError("Export root must be an armature")
    export_root.animation_data_clear()
    export_root.animation_data_create()

    create_action(
        export_root,
        "Idle",
        48,
        [
            {
                "frame": 1,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "spine_02": {
                        "rotation": (radians(-0.8), 0.0, radians(-0.8))
                    },
                    "spine_03": {
                        "rotation": (radians(0.6), 0.0, radians(1.1))
                    },
                    "head": {
                        "rotation": (radians(-0.4), 0.0, radians(-1.2))
                    },
                    "upperarm_l": {
                        "rotation": (radians(-2.0), 0.0, radians(-38.0))
                    },
                    "upperarm_r": {
                        "rotation": (radians(2.0), 0.0, radians(38.0))
                    },
                    "lowerarm_l": {"rotation": (radians(-5.0), 0.0, 0.0)},
                    "lowerarm_r": {"rotation": (radians(-5.0), 0.0, 0.0)},
                },
            },
            {
                "frame": 24,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.006)},
                    "spine_02": {
                        "rotation": (radians(1.0), 0.0, radians(0.6))
                    },
                    "spine_03": {
                        "rotation": (radians(-0.7), 0.0, radians(-0.9))
                    },
                    "head": {
                        "rotation": (radians(0.5), 0.0, radians(1.0))
                    },
                    "upperarm_l": {
                        "rotation": (radians(1.0), 0.0, radians(-38.0))
                    },
                    "upperarm_r": {
                        "rotation": (radians(-1.0), 0.0, radians(38.0))
                    },
                    "lowerarm_l": {"rotation": (radians(-7.0), 0.0, 0.0)},
                    "lowerarm_r": {"rotation": (radians(-7.0), 0.0, 0.0)},
                },
            },
            {
                "frame": 48,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "spine_02": {
                        "rotation": (radians(-0.8), 0.0, radians(-0.8))
                    },
                    "spine_03": {
                        "rotation": (radians(0.6), 0.0, radians(1.1))
                    },
                    "head": {
                        "rotation": (radians(-0.4), 0.0, radians(-1.2))
                    },
                    "upperarm_l": {
                        "rotation": (radians(-2.0), 0.0, radians(-38.0))
                    },
                    "upperarm_r": {
                        "rotation": (radians(2.0), 0.0, radians(38.0))
                    },
                    "lowerarm_l": {"rotation": (radians(-5.0), 0.0, 0.0)},
                    "lowerarm_r": {"rotation": (radians(-5.0), 0.0, 0.0)},
                },
            },
        ],
    )

    create_action(
        export_root,
        "Walk",
        24,
        [
            {
                "frame": 1,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {
                        "rotation": (0.0, radians(-1.5), radians(2.0))
                    },
                    "spine_03": {
                        "rotation": (radians(1.5), 0.0, radians(-2.0))
                    },
                    "thigh_l": {"rotation": (radians(27), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(4), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(-25), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(30), 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (radians(-18), 0.0, radians(-38))
                    },
                    "lowerarm_l": {"rotation": (radians(-10), 0.0, 0.0)},
                    "upperarm_r": {
                        "rotation": (radians(18), 0.0, radians(38))
                    },
                    "lowerarm_r": {"rotation": (radians(-18), 0.0, 0.0)},
                },
            },
            {
                "frame": 7,
                "bones": {
                    "Root": {"location": (0.0, 0.0, -0.017)},
                    "pelvis": {"rotation": (0.0, 0.0, 0.0)},
                    "spine_03": {"rotation": (radians(2.2), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(-8), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(28), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(12), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(10), 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (radians(2), 0.0, radians(-38))
                    },
                    "upperarm_r": {
                        "rotation": (radians(-2), 0.0, radians(38))
                    },
                },
            },
            {
                "frame": 13,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {
                        "rotation": (0.0, radians(1.5), radians(-2.0))
                    },
                    "spine_03": {
                        "rotation": (radians(1.5), 0.0, radians(2.0))
                    },
                    "thigh_l": {"rotation": (radians(-25), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(30), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(27), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(4), 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (radians(18), 0.0, radians(-38))
                    },
                    "lowerarm_l": {"rotation": (radians(-18), 0.0, 0.0)},
                    "upperarm_r": {
                        "rotation": (radians(-18), 0.0, radians(38))
                    },
                    "lowerarm_r": {"rotation": (radians(-10), 0.0, 0.0)},
                },
            },
            {
                "frame": 19,
                "bones": {
                    "Root": {"location": (0.0, 0.0, -0.017)},
                    "pelvis": {"rotation": (0.0, 0.0, 0.0)},
                    "spine_03": {"rotation": (radians(2.2), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(12), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(10), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(-8), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(28), 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (radians(-2), 0.0, radians(-38))
                    },
                    "upperarm_r": {
                        "rotation": (radians(2), 0.0, radians(38))
                    },
                },
            },
            {
                "frame": 24,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {
                        "rotation": (0.0, radians(-1.5), radians(2.0))
                    },
                    "spine_03": {
                        "rotation": (radians(1.5), 0.0, radians(-2.0))
                    },
                    "thigh_l": {"rotation": (radians(27), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(4), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(-25), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(30), 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (radians(-18), 0.0, radians(-38))
                    },
                    "lowerarm_l": {"rotation": (radians(-10), 0.0, 0.0)},
                    "upperarm_r": {
                        "rotation": (radians(18), 0.0, radians(38))
                    },
                    "lowerarm_r": {"rotation": (radians(-18), 0.0, 0.0)},
                },
            },
        ],
    )

    create_action(
        export_root,
        "Run",
        18,
        [
            {
                "frame": 1,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {"rotation": (radians(5), radians(-2), radians(4))},
                    "spine_02": {"rotation": (radians(7), 0.0, radians(-3))},
                    "spine_03": {"rotation": (radians(4), 0.0, radians(-4))},
                    "thigh_l": {"rotation": (radians(43), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(8), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(-38), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(56), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-34), 0.0, radians(-34))},
                    "lowerarm_l": {"rotation": (radians(-28), 0.0, 0.0)},
                    "upperarm_r": {"rotation": (radians(35), 0.0, radians(34))},
                    "lowerarm_r": {"rotation": (radians(-42), 0.0, 0.0)},
                },
            },
            {
                "frame": 5,
                "bones": {
                    "Root": {"location": (0.0, 0.0, -0.035)},
                    "pelvis": {"rotation": (radians(6), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(8), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(-5), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(42), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(16), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(18), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(7), 0.0, radians(-36))},
                    "upperarm_r": {"rotation": (radians(-8), 0.0, radians(36))},
                },
            },
            {
                "frame": 10,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {"rotation": (radians(5), radians(2), radians(-4))},
                    "spine_02": {"rotation": (radians(7), 0.0, radians(3))},
                    "spine_03": {"rotation": (radians(4), 0.0, radians(4))},
                    "thigh_l": {"rotation": (radians(-38), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(56), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(43), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(8), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(35), 0.0, radians(-34))},
                    "lowerarm_l": {"rotation": (radians(-42), 0.0, 0.0)},
                    "upperarm_r": {"rotation": (radians(-34), 0.0, radians(34))},
                    "lowerarm_r": {"rotation": (radians(-28), 0.0, 0.0)},
                },
            },
            {
                "frame": 14,
                "bones": {
                    "Root": {"location": (0.0, 0.0, -0.035)},
                    "pelvis": {"rotation": (radians(6), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(8), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(16), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(18), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(-5), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(42), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-8), 0.0, radians(-36))},
                    "upperarm_r": {"rotation": (radians(7), 0.0, radians(36))},
                },
            },
            {
                "frame": 18,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {"rotation": (radians(5), radians(-2), radians(4))},
                    "spine_02": {"rotation": (radians(7), 0.0, radians(-3))},
                    "spine_03": {"rotation": (radians(4), 0.0, radians(-4))},
                    "thigh_l": {"rotation": (radians(43), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(8), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(-38), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(56), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-34), 0.0, radians(-34))},
                    "lowerarm_l": {"rotation": (radians(-28), 0.0, 0.0)},
                    "upperarm_r": {"rotation": (radians(35), 0.0, radians(34))},
                    "lowerarm_r": {"rotation": (radians(-42), 0.0, 0.0)},
                },
            },
        ],
    )

    create_action(
        export_root,
        "Jump",
        20,
        [
            {
                "frame": 1,
                "bones": {
                    "Root": {"location": (0.0, 0.0, -0.045)},
                    "pelvis": {"rotation": (radians(8), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(7), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(20), 0.0, radians(-3))},
                    "thigh_r": {"rotation": (radians(20), 0.0, radians(3))},
                    "calf_l": {"rotation": (radians(32), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(32), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(12), 0.0, radians(-42))},
                    "upperarm_r": {"rotation": (radians(12), 0.0, radians(42))},
                },
            },
            {
                "frame": 7,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.035)},
                    "pelvis": {"rotation": (radians(-2), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(-4), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(-8), 0.0, radians(-3))},
                    "thigh_r": {"rotation": (radians(-8), 0.0, radians(3))},
                    "calf_l": {"rotation": (radians(5), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(5), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-38), 0.0, radians(-34))},
                    "upperarm_r": {"rotation": (radians(-38), 0.0, radians(34))},
                },
            },
            {
                "frame": 14,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.025)},
                    "pelvis": {"rotation": (radians(2), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(2), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(10), 0.0, radians(-2))},
                    "thigh_r": {"rotation": (radians(5), 0.0, radians(2))},
                    "calf_l": {"rotation": (radians(18), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(12), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-12), 0.0, radians(-44))},
                    "upperarm_r": {"rotation": (radians(-12), 0.0, radians(44))},
                },
            },
            {
                "frame": 20,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {"rotation": (radians(5), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(4), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(13), 0.0, radians(-2))},
                    "thigh_r": {"rotation": (radians(9), 0.0, radians(2))},
                    "calf_l": {"rotation": (radians(22), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(18), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-3), 0.0, radians(-45))},
                    "upperarm_r": {"rotation": (radians(-3), 0.0, radians(45))},
                },
            },
        ],
    )

    create_action(
        export_root,
        "Fall",
        24,
        [
            {
                "frame": 1,
                "bones": {
                    "pelvis": {"rotation": (radians(4), 0.0, radians(-1))},
                    "spine_02": {"rotation": (radians(3), 0.0, radians(1))},
                    "thigh_l": {"rotation": (radians(12), 0.0, radians(-3))},
                    "thigh_r": {"rotation": (radians(8), 0.0, radians(3))},
                    "calf_l": {"rotation": (radians(20), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(14), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-5), 0.0, radians(-48))},
                    "upperarm_r": {"rotation": (radians(-3), 0.0, radians(48))},
                },
            },
            {
                "frame": 12,
                "bones": {
                    "pelvis": {"rotation": (radians(5), 0.0, radians(1))},
                    "spine_02": {"rotation": (radians(2), 0.0, radians(-1))},
                    "thigh_l": {"rotation": (radians(8), 0.0, radians(-3))},
                    "thigh_r": {"rotation": (radians(12), 0.0, radians(3))},
                    "calf_l": {"rotation": (radians(14), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(20), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-3), 0.0, radians(-46))},
                    "upperarm_r": {"rotation": (radians(-5), 0.0, radians(46))},
                },
            },
            {
                "frame": 24,
                "bones": {
                    "pelvis": {"rotation": (radians(4), 0.0, radians(-1))},
                    "spine_02": {"rotation": (radians(3), 0.0, radians(1))},
                    "thigh_l": {"rotation": (radians(12), 0.0, radians(-3))},
                    "thigh_r": {"rotation": (radians(8), 0.0, radians(3))},
                    "calf_l": {"rotation": (radians(20), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(14), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(-5), 0.0, radians(-48))},
                    "upperarm_r": {"rotation": (radians(-3), 0.0, radians(48))},
                },
            },
        ],
    )

    create_action(
        export_root,
        "Land",
        14,
        [
            {
                "frame": 1,
                "bones": {
                    "Root": {"location": (0.0, 0.0, -0.075)},
                    "pelvis": {"rotation": (radians(12), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(13), 0.0, 0.0)},
                    "head": {"rotation": (radians(-8), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(30), 0.0, radians(-2))},
                    "thigh_r": {"rotation": (radians(30), 0.0, radians(2))},
                    "calf_l": {"rotation": (radians(42), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(42), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(12), 0.0, radians(-42))},
                    "upperarm_r": {"rotation": (radians(12), 0.0, radians(42))},
                },
            },
            {
                "frame": 7,
                "bones": {
                    "Root": {"location": (0.0, 0.0, -0.025)},
                    "pelvis": {"rotation": (radians(5), 0.0, 0.0)},
                    "spine_02": {"rotation": (radians(5), 0.0, 0.0)},
                    "head": {"rotation": (radians(-2), 0.0, 0.0)},
                    "thigh_l": {"rotation": (radians(10), 0.0, 0.0)},
                    "thigh_r": {"rotation": (radians(10), 0.0, 0.0)},
                    "calf_l": {"rotation": (radians(14), 0.0, 0.0)},
                    "calf_r": {"rotation": (radians(14), 0.0, 0.0)},
                    "upperarm_l": {"rotation": (radians(2), 0.0, radians(-39))},
                    "upperarm_r": {"rotation": (radians(2), 0.0, radians(39))},
                },
            },
            {
                "frame": 14,
                "bones": {
                    "Root": {"location": (0.0, 0.0, 0.0)},
                    "pelvis": {"rotation": (0.0, 0.0, 0.0)},
                    "spine_02": {"rotation": (0.0, 0.0, 0.0)},
                    "head": {"rotation": (0.0, 0.0, 0.0)},
                    "thigh_l": {"rotation": (0.0, 0.0, 0.0)},
                    "thigh_r": {"rotation": (0.0, 0.0, 0.0)},
                    "calf_l": {"rotation": (0.0, 0.0, 0.0)},
                    "calf_r": {"rotation": (0.0, 0.0, 0.0)},
                    "upperarm_l": {"rotation": (0.0, 0.0, radians(-38))},
                    "upperarm_r": {"rotation": (0.0, 0.0, radians(38))},
                },
            },
        ],
    )

    create_action(
        export_root,
        "Interact",
        42,
        [
            {
                "frame": 1,
                "bones": {
                    "spine_03": {"rotation": (0.0, 0.0, 0.0)},
                    "head": {"rotation": (0.0, 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (0.0, 0.0, radians(-38.0))
                    },
                    "lowerarm_l": {"rotation": (radians(-5.0), 0.0, 0.0)},
                    "upperarm_r": {
                        "rotation": (0.0, 0.0, radians(38.0))
                    },
                    "lowerarm_r": {"rotation": (radians(-5.0), 0.0, 0.0)},
                },
            },
            {
                "frame": 15,
                "bones": {
                    "spine_03": {"rotation": (radians(5), 0.0, 0.0)},
                    "head": {"rotation": (radians(-7), 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (radians(-52), radians(-8), radians(-34))
                    },
                    "lowerarm_l": {"rotation": (radians(-42), 0.0, 0.0)},
                    "upperarm_r": {
                        "rotation": (radians(-52), radians(8), radians(34))
                    },
                    "lowerarm_r": {"rotation": (radians(-42), 0.0, 0.0)},
                },
            },
            {
                "frame": 27,
                "bones": {
                    "spine_03": {"rotation": (radians(3), 0.0, 0.0)},
                    "head": {"rotation": (radians(-5), 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (radians(-45), radians(-6), radians(-35))
                    },
                    "lowerarm_l": {"rotation": (radians(-35), 0.0, 0.0)},
                    "upperarm_r": {
                        "rotation": (radians(-45), radians(6), radians(35))
                    },
                    "lowerarm_r": {"rotation": (radians(-35), 0.0, 0.0)},
                },
            },
            {
                "frame": 42,
                "bones": {
                    "spine_03": {"rotation": (0.0, 0.0, 0.0)},
                    "head": {"rotation": (0.0, 0.0, 0.0)},
                    "upperarm_l": {
                        "rotation": (0.0, 0.0, radians(-38.0))
                    },
                    "lowerarm_l": {"rotation": (radians(-5.0), 0.0, 0.0)},
                    "upperarm_r": {
                        "rotation": (0.0, 0.0, radians(38.0))
                    },
                    "lowerarm_r": {"rotation": (radians(-5.0), 0.0, 0.0)},
                },
            },
        ],
    )

    add_secondary_motion(export_root)

    bpy.context.scene.render.fps = 24
    export_root.animation_data.action = bpy.data.actions["Idle"]
    bpy.context.scene.frame_set(24)


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_preview_stage(export_root):
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0.0, 0.0, 0.0))
    ground = bpy.context.object
    ground.name = "PreviewGround"
    ground_material = bpy.data.materials.new("PreviewGroundMaterial")
    ground_material.diffuse_color = (0.025, 0.045, 0.052, 1.0)
    ground.data.materials.append(ground_material)

    bpy.ops.object.camera_add(location=(0.0, -5.15, 1.35))
    camera = bpy.context.object
    camera.name = "CharacterPreviewCamera"
    camera.data.lens = 64.0
    look_at(camera, (0.0, 0.0, 0.98))
    bpy.context.scene.camera = camera

    for name, location, energy, size, color in [
        (
            "CharacterKey",
            (2.7, -3.2, 3.7),
            620.0,
            3.0,
            (0.72, 0.9, 1.0),
        ),
        (
            "CharacterFill",
            (-2.8, -1.8, 2.4),
            310.0,
            2.6,
            (0.65, 0.82, 0.78),
        ),
        (
            "CharacterRim",
            (0.6, 2.2, 3.1),
            680.0,
            2.0,
            (0.25, 0.9, 0.82),
        ),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        look_at(light, (0.0, 0.0, 1.05))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    scene.world.color = (0.018, 0.035, 0.04)
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


def save_and_export(export_root):
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    EXPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))

    bpy.ops.object.select_all(action="DESELECT")
    selected = [export_root, *export_root.children_recursive]
    for obj in selected:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_tangents=True,
        export_materials="EXPORT",
    )

    meshes = [obj for obj in selected if obj.type == "MESH"]
    armatures = [obj for obj in selected if obj.type == "ARMATURE"]
    vertex_count = sum(len(obj.data.vertices) for obj in meshes)
    bone_count = sum(len(obj.data.bones) for obj in armatures)
    print(
        "REALISTIC_CHARACTER_OK",
        "source=" + str(SOURCE_PATH),
        "export=" + str(EXPORT_PATH),
        "preview=" + str(PREVIEW_PATH),
        "meshes=" + str(len(meshes)),
        "vertices=" + str(vertex_count),
        "bones=" + str(bone_count),
    )


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    configure_character()
    result = bpy.ops.mpfb.create_random_human()
    if "FINISHED" not in result:
        raise RuntimeError("MPFB failed to create the character: " + str(result))
    source_root = bpy.context.object
    source_basemesh = ObjectService.find_object_of_type_amongst_nearest_relatives(
        source_root
    )
    if source_basemesh is None:
        raise RuntimeError("MPFB did not create a detectable basemesh")
    source_root.name = "Ji_Realistic_Source"
    source_basemesh.name = "Ji_Body_Source"
    art_direct_materials(source_root)
    export_root = create_export_copy(source_root)
    art_direct_materials(export_root)
    add_travel_accessories(export_root)
    create_character_actions(export_root)
    add_preview_stage(export_root)
    save_and_export(export_root)


main()
