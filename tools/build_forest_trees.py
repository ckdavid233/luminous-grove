#!/usr/bin/env python3
"""Build three deterministic, game-ready deciduous tree variants in Blender."""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


PLAN_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PLAN_ROOT / "art_source" / "forest_trees"
OUTPUT_DIR = PLAN_ROOT / "game" / "content" / "environments" / "forest"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def make_material(name: str, color: tuple[float, float, float, float], roughness: float):
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    material.use_backface_culling = False
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in principled.inputs:
        principled.inputs["Specular IOR Level"].default_value = 0.28
    return material


def add_tapered_segment(
    start: Vector,
    end: Vector,
    radius_start: float,
    radius_end: float,
    material,
    vertices: int = 9,
):
    direction = end - start
    length = direction.length
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_start,
        radius2=radius_end,
        depth=length,
        end_fill_type="NGON",
        location=(start + end) * 0.5,
    )
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_leaf_cluster(location: Vector, scale: Vector, rotation: Vector, material, seed: int):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=location)
    obj = bpy.context.object
    obj.scale = scale
    obj.rotation_euler = rotation
    obj.data.materials.append(material)
    local_rng = random.Random(seed)
    for vertex in obj.data.vertices:
        coordinate = vertex.co.normalized()
        variation = 1.0 + local_rng.uniform(-0.16, 0.16)
        variation += math.sin(coordinate.x * 5.7 + coordinate.z * 3.9) * 0.055
        vertex.co *= variation
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_leaf_cards(centers: list[Vector], material, rng: random.Random):
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int]] = []
    uv_values: list[tuple[float, float]] = []
    for center in centers:
        for _index in range(52):
            card_center = center + Vector(
                (
                    rng.uniform(-0.85, 0.85),
                    rng.uniform(-0.85, 0.85),
                    rng.uniform(-0.55, 0.75),
                )
            )
            normal = Vector(
                (
                    rng.uniform(-1.0, 1.0),
                    rng.uniform(-1.0, 1.0),
                    rng.uniform(-0.2, 0.8),
                )
            ).normalized()
            right = normal.cross(Vector((0.0, 0.0, 1.0)))
            if right.length < 0.1:
                right = Vector((1.0, 0.0, 0.0))
            right.normalize()
            up = right.cross(normal).normalized()
            width = rng.uniform(0.052, 0.092)
            length = rng.uniform(0.13, 0.23)
            ridge_depth = rng.uniform(0.012, 0.026)
            base = len(vertices)
            # A six-sided, slightly folded lanceolate leaf reads as a leaf at
            # close range instead of the old diamond-shaped card. The center
            # ridge gives the shader a stable normal break for soft highlights.
            vertices.extend(
                [
                    tuple(card_center - up * length),
                    tuple(card_center - up * length * 0.32 - right * width),
                    tuple(card_center + up * length * 0.42 - right * width * 0.68),
                    tuple(card_center + up * length),
                    tuple(card_center + up * length * 0.42 + right * width * 0.68),
                    tuple(card_center - up * length * 0.32 + right * width),
                    tuple(card_center + normal * ridge_depth),
                ]
            )
            faces.extend(
                [
                    (base, base + 1, base + 6),
                    (base + 1, base + 2, base + 6),
                    (base + 2, base + 3, base + 6),
                    (base + 3, base + 4, base + 6),
                    (base + 4, base + 5, base + 6),
                    (base + 5, base, base + 6),
                ]
            )
            uv_values.extend(
                [
                    (0.5, 0.0),
                    (0.08, 0.28),
                    (0.22, 0.68),
                    (0.5, 1.0),
                    (0.78, 0.68),
                    (0.92, 0.28),
                    (0.5, 0.52),
                ]
            )
    mesh = bpy.data.meshes.new("IndividualLeaves")
    mesh.from_pydata(vertices, [], faces)
    mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            mesh.uv_layers[0].data[loop_index].uv = uv_values[mesh.loops[loop_index].vertex_index]
    mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new("IndividualLeaves", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def join_objects(objects: list, name: str):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    result.data.name = name + "Mesh"
    return result


def build_tree(variant_index: int) -> None:
    clear_scene()
    rng = random.Random(0xF07E57 + variant_index * 7919)
    bark = make_material(
        "TreeBark",
        (0.19 + variant_index * 0.012, 0.145, 0.105, 1.0),
        0.96,
    )
    leaves = make_material(
        "TreeLeaves",
        (0.12, 0.31 + variant_index * 0.018, 0.17, 1.0),
        0.82,
    )

    wood_objects = []
    leaf_objects = []
    crown_centers: list[Vector] = []
    trunk_height = 7.2 + variant_index * 0.55
    trunk_points = [Vector((0.0, 0.0, 0.0))]
    for index in range(1, 9):
        t = index / 8.0
        trunk_points.append(
            Vector(
                (
                    math.sin(t * 2.7 + variant_index) * 0.12 * t,
                    math.cos(t * 2.1 + variant_index * 0.7) * 0.09 * t,
                    trunk_height * t,
                )
            )
        )
    for index in range(8):
        t = index / 8.0
        wood_objects.append(
            add_tapered_segment(
                trunk_points[index],
                trunk_points[index + 1],
                0.46 * (1.0 - t * 0.68),
                0.46 * (1.0 - (index + 1) / 8.0 * 0.68),
                bark,
                11,
            )
        )

    for root_index in range(9):
        angle = root_index / 9.0 * math.tau + rng.uniform(-0.12, 0.12)
        start = Vector((0.0, 0.0, 0.22))
        end = Vector(
            (
                math.cos(angle) * rng.uniform(0.75, 1.35),
                math.sin(angle) * rng.uniform(0.75, 1.35),
                rng.uniform(-0.08, 0.08),
            )
        )
        wood_objects.append(add_tapered_segment(start, end, 0.24, 0.035, bark, 8))

    branch_count = 11 + variant_index * 2
    for branch_index in range(branch_count):
        height_ratio = 0.31 + branch_index / max(1, branch_count - 1) * 0.52
        angle = branch_index * 2.399963 + variant_index * 0.73 + rng.uniform(-0.2, 0.2)
        start = Vector(
            (
                math.sin(height_ratio * 2.7 + variant_index) * 0.1 * height_ratio,
                math.cos(height_ratio * 2.1 + variant_index * 0.7) * 0.08 * height_ratio,
                trunk_height * height_ratio,
            )
        )
        length = rng.uniform(1.75, 3.15) * (1.05 - max(0.0, height_ratio - 0.62) * 0.75)
        horizontal = Vector((math.cos(angle), math.sin(angle), 0.0))
        end = start + horizontal * length + Vector((0.0, 0.0, rng.uniform(0.65, 1.55)))
        radius = 0.19 * (1.15 - height_ratio * 0.58)
        wood_objects.append(add_tapered_segment(start, end, radius, 0.045, bark, 8))

        side_angle = angle + rng.choice([-0.58, 0.58])
        side_direction = Vector((math.cos(side_angle), math.sin(side_angle), 0.0))
        secondary_start = start.lerp(end, 0.58)
        secondary_end = secondary_start + side_direction * length * 0.48 + Vector(
            (0.0, 0.0, rng.uniform(0.35, 0.85))
        )
        wood_objects.append(
            add_tapered_segment(secondary_start, secondary_end, radius * 0.5, 0.025, bark, 7)
        )

        for center_index, center in enumerate([end, secondary_end]):
            crown_center = center + Vector(
                (rng.uniform(-0.24, 0.24), rng.uniform(-0.24, 0.24), rng.uniform(0.05, 0.5))
            )
            crown_centers.append(crown_center)
    leaf_objects.append(add_leaf_cards(crown_centers, leaves, rng))
    tree = join_objects([*wood_objects, *leaf_objects], f"ForestTree{variant_index + 1}")

    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.ops.object.select_all(action="DESELECT")
    tree.select_set(True)
    bpy.context.view_layer.objects.active = tree

    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    blend_path = SOURCE_DIR / f"forest_tree_{variant_index + 1}.blend"
    glb_path = OUTPUT_DIR / f"forest_tree_{variant_index + 1}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
        export_yup=True,
        export_apply=True,
    )
    print(
        f"FOREST_TREE_OK variant={variant_index + 1} "
        f"vertices={len(tree.data.vertices)} polygons={len(tree.data.polygons)} "
        f"output={glb_path}"
    )


def main() -> None:
    for variant_index in range(3):
        build_tree(variant_index)


if __name__ == "__main__":
    main()
