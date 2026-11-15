"""Build the lunar EVA terrain and equipment props in Blender background mode."""
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector, noise

rng = random.Random(68011)
root = Path(__file__).resolve().parents[3]
output = root / "assets/models/lunar_surface"
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def collection(name):
    group = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(group)
    return group


def material(name, color, roughness=0.9, vertex_color=False, luminous=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    if vertex_color:
        attribute = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        attribute.layer_name = "Tint"
        mat.node_tree.links.new(attribute.outputs["Color"], shader.inputs["Base Color"])
        if luminous:
            mat.node_tree.links.new(attribute.outputs["Color"], shader.inputs["Emission Color"])
            shader.inputs["Emission Strength"].default_value = 0.75
    return mat


def mesh(name, group, vertices, faces, shader, colors=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    group.objects.link(obj)
    data.materials.append(shader)
    if colors:
        tint = data.color_attributes.new("Tint", "FLOAT_COLOR", "POINT")
        for entry, color in zip(tint.data, colors):
            entry.color = (*color, 1)
    return obj


terrain = collection("01 Terrain and horizon")
props = collection("02 Surface landmarks")
sky = collection("03 Earth")
animation = collection("04 EVA glove")
gray = material("Regolith", (0.33, 0.31, 0.29), vertex_color=True)
rocks = material("Basalt and breccia", (0.36, 0.33, 0.30), vertex_color=True)
earth = material("Oceans, continents and cloud cover", (0.16, 0.36, 0.54), vertex_color=True, luminous=True)
fabric = material("EVA pressure glove", (0.74, 0.70, 0.58), 0.78)
cuff = material("EVA cuff seal", (0.29, 0.25, 0.22), 0.58)

sites = [(0, 0, 12), (-34, 43, 8), (7, 57, 8), (46, 42, 6), (6, -3, 5)]
craters = [(-42, 56, 13, 2.3), (58, 54, 16, 3.0), (1, 92, 23, 5.5),
           (-59, 9, 19, 3.7), (62, -14, 17, 3.1), (-81, 99, 28, 5.8)]


def height(x, y):
    broad = noise.fractal(Vector((x * 0.022, y * 0.022, 6.67)), 1.0, 2.0, 3)
    fine = noise.noise(Vector((x * 0.135, y * 0.135, 2.17)))
    z = 1.9 * broad + 0.16 * fine
    for cx, cy, radius, depth in craters:
        d = math.hypot(x - cx, y - cy) / radius
        z += 0.27 * depth * math.exp(-((d - 1.03) / 0.23) ** 2)
        z -= depth * max(1 - d * d, 0) ** 2
    for cx, cy, radius in sites:
        d = min(1.0, math.hypot(x - cx, y - cy) / radius)
        z *= d * d * (3.0 - 2.0 * d)
    return z


def grid():
    points, faces, colors = [], [], []
    count = 151
    for row in range(count):
        for col in range(count):
            x, y = (col - 75) * 1.8, (row - 75) * 1.8
            z = height(x, y)
            points.append((x, y, z))
            ash = 0.32 + 0.075 * noise.fractal(Vector((x * 0.1, y * 0.1, 3.71)), 1.0, 2.0, 3)
            ash += z * 0.005 + rng.uniform(-0.018, 0.018)
            colors.append((ash * 1.07, ash, ash * 0.94))
            if row and col:
                k = row * count + col
                faces.extend([(k - count - 1, k - count, k), (k - count - 1, k, k - 1)])
    obj = mesh("Walkable", terrain, points, faces, gray, colors)
    for face in obj.data.polygons:
        face.use_smooth = True


def field(name, entries):
    points, faces, colors = [], [], []
    for x, y, size in entries:
        start = len(points)
        z = height(x, y) - size * 0.05
        turn = rng.uniform(0, math.tau)
        palette = rng.uniform(0.24, 0.42)
        for ring, elevation in [(0.78, -0.09), (0.95, 0.16), (0.60, 0.52)]:
            for side in range(7):
                a = turn + math.tau * side / 7
                r = rng.uniform(0.72, 1.25) * ring * size
                points.append((x + math.cos(a) * r, y + math.sin(a) * r * 0.83,
                               z + (elevation + rng.uniform(-0.1, 0.1)) * size))
                level = palette * rng.uniform(0.79, 1.26)
                colors.append((level * 1.12, level, level * 0.91))
        top = len(points)
        points.append((x + size * 0.06, y - size * 0.1, z + size * 0.65))
        colors.append((palette * 1.25, palette * 1.13, palette))
        for side in range(7):
            nxt = (side + 1) % 7
            for ring in (0, 7):
                faces.append((start + ring + side, start + ring + nxt,
                              start + ring + nxt + 7, start + ring + side + 7))
            faces.append((start + 14 + side, start + 14 + nxt, top))
    result = mesh(name, props, points, faces, rocks, colors)
    return result


grid()
background = []
for _ in range(730):
    x, y = rng.uniform(-113, 113), rng.uniform(-113, 113)
    if any(math.hypot(x - cx, y - cy) < r + 1 for cx, cy, r in sites):
        continue
    background.append((x, y, rng.uniform(0.08, 0.42) if abs(x) < 58 and abs(y) < 60
                       else rng.uniform(0.27, 1.75)))
field("RegolithFragments", background)
field("SampleLandmarks", [(-31,49,1.6),(-39,49,2.2),(-40,41,1.3),(-37,46,0.42),(-33,46,0.22)])
field("SurveyRidge", [(44,51,0.9),(48,51,1.3),(51,52,1.7),(43,54,1.1),(52,55,0.6),(42,50,0.6),(39,49,0.4)])
field("BearingRocks", [(-14,29,1.25),(18,29,1.6),(3,39,0.7),(14,59,1.45),(-3,64,1.25)])
sample = field("SampleRock", [(0, 0, 0.38)])
sample.location = (-34, 43, height(-34, 43) + 0.012)

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=12.0, location=(41, 236, 77))
planet = bpy.context.object
planet.name = "Earth"
for old in list(planet.users_collection):
    old.objects.unlink(planet)
sky.objects.link(planet)
planet.data.materials.append(earth)
tint = planet.data.color_attributes.new("Tint", "FLOAT_COLOR", "POINT")
for vertex, entry in zip(planet.data.vertices, tint.data):
    v = vertex.co.normalized()
    land = noise.fractal(v * 2.43 + Vector((1.1, 4.92, 5.9)), 0.95, 2.2, 4)
    cloud = max(0, noise.fractal(v * 5.6 + Vector((6, 19, 1)), 1.0, 2.0, 3) - 0.12)
    color = (0.16, 0.24, 0.105) if land > 0.23 else (0.029, 0.125, 0.35)
    if abs(v.z) > 0.87:
        color = (0.55, 0.65, 0.75)
    haze = min(0.89, cloud * 2.9)
    entry.color = (*(a * (1 - haze) + 0.75 * haze for a in color), 1)
for face in planet.data.polygons:
    face.use_smooth = True


def glove_part(name, position, scale, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    for group in list(obj.users_collection):
        group.objects.unlink(obj)
    animation.objects.link(obj)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True


glove_part("Palm", (0, 0, 0), (0.083, 0.116, 0.047), fabric)
glove_part("Thumb", (0.069, 0.037, 0.016), (0.041, 0.067, 0.034), fabric)
glove_part("Fingers", (0.006, 0.096, 0.021), (0.074, 0.053, 0.035), fabric)
glove_part("Cuff", (0, -0.096, 0), (0.083, 0.040, 0.052), cuff)
glove_part("Sleeve", (0, -0.374, 0), (0.091, 0.262, 0.062), fabric)
glove_part("Sleeve ring", (0, -0.194, 0), (0.094, 0.024, 0.064), cuff)

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name("lunar_surface.blend")))
for name, groups in [("lunar_surface", [terrain, props, sky]), ("eva_glove", [animation])]:
    bpy.ops.object.select_all(action="DESELECT")
    for group in groups:
        for obj in group.objects:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), use_selection=True,
                              export_format="GLB", export_vertex_color="ACTIVE")
