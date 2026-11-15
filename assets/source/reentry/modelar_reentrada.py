"""Modela no Blender as peças da reentrada do APOLLO6 e exporta para o Godot.

Uso (Blender 4.2+ ou módulo bpy):
    blender --background --python assets/source/reentry/modelar_reentrada.py -- <raiz_do_projeto>

Gera:
    assets/source/reentry/apollo6_reentrada.blend  (peças editáveis)
    assets/models/reentry/reentry_set.glb          (importado pela cena da reentrada)

Convenções (Blender Z para cima = Godot Y para cima):
    - CommandModule: origem no centro da junção com o escudo (z = 0). Ápice em +Z.
      A escotilha e as janelas maiores marcam a FRENTE em -Y do Blender (+Z no Godot).
    - HeatShield: mesma origem do CommandModule. UV planar: centro do escudo em (0,5; 0,5).
    - ServiceModule: origem no topo (junção com o CommandModule), corpo em -Z.
    - HeatEnvelope/HeatEnvelopeOuter/ReentryTrail: mesma origem do CommandModule;
      o rastro sai da borda do escudo e segue para +Z (atrás da cápsula). V do UV = 0 na frente e 1 no fim.
    - MainChute/DrogueChute: origem no centro da saia (borda inferior do tecido), cúpula em +Z, raio 1.
    - EarthSphere/AtmosphereShell: esferas de raio 1, escaladas no Godot.
    - FoamDisc: anel de raio 1 no plano XY. CloudLayer: plano 1 x 1 subdividido.
"""
import math
import sys
from pathlib import Path

import bpy
import bmesh

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [str(Path(__file__).resolve().parents[3])]
project = Path(args[0])
out = project / "assets/models/reentry"
out.mkdir(parents=True, exist_ok=True)
source = project / "assets/source/reentry"
source.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "Reentrada"
scene.unit_settings.system = "METRIC"


# ---------- Materiais ----------

def material(name, color, roughness=0.6, metallic=0.0, emission=None, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
    return mat


def srgb(hex_code):
    value = [int(hex_code[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in value)


def hull_texture():
    """Chapas, juntas e fixadores do casco em uma textura pequena (mapeamento cilíndrico)."""
    w, h = 256, 128
    img = bpy.data.images.new("hull_panels", w, h)
    px = [0.0] * (w * h * 4)
    import random
    rnd = random.Random(1969)
    base = srgb("C9C6BA")
    columns = 16
    rows = [0.0, 0.24, 0.47, 0.70, 1.0]
    tint = {}
    for y in range(h):
        v = y / h
        row = max(i for i, r in enumerate(rows) if r <= v)
        for x in range(w):
            col = int(x / w * columns)
            key = (row, col)
            if key not in tint:
                tint[key] = rnd.uniform(-0.035, 0.035)
            c = [b + tint[key] + rnd.uniform(-0.012, 0.012) for b in base]
            du = (x / w * columns) % 1.0
            on_joint_v = min(du, 1.0 - du) < 0.035
            on_joint_h = any(abs(v - r) < 0.008 for r in rows[1:-1])
            if on_joint_v or on_joint_h:
                c = [ci * 0.62 for ci in c]
            # fixadores ao longo das juntas horizontais
            for r in rows[1:-1]:
                if abs(v - r) < 0.03 and abs(v - r) > 0.014 and int(x) % 8 == 3:
                    c = [ci * 0.78 for ci in c]
            i = (y * w + x) * 4
            px[i:i + 4] = [max(0, min(1, c[0])), max(0, min(1, c[1])), max(0, min(1, c[2])), 1.0]
    img.pixels = px
    img.pack()
    return img


hull_img = hull_texture()
MAT = {
    "Hull": material("Hull", srgb("C9C6BA"), 0.48, 0.35),
    "HullJoint": material("HullJoint", srgb("6E6A60"), 0.7, 0.2),
    "Seam": material("Seam", srgb("8F8B80"), 0.6, 0.3),
    "Frame": material("Frame", srgb("3A3D3E"), 0.55, 0.5),
    "Glass": material("Glass", srgb("0D1418"), 0.08, 0.0),
    "Plate": material("Plate", srgb("A9A699"), 0.55, 0.4),
    "Shield": material("Shield", srgb("3B3029"), 0.92, 0.0),
    "ShieldRim": material("ShieldRim", srgb("54443A"), 0.85, 0.0),
    "SMBody": material("SMBody", srgb("B9B8B2"), 0.5, 0.45),
    "SMRadiator": material("SMRadiator", srgb("E2E0D8"), 0.65, 0.1),
    "Bell": material("Bell", srgb("2E2C2A"), 0.45, 0.7),
    "RCS": material("RCS", srgb("8E8B82"), 0.55, 0.5),
    "ChuteWhite": material("ChuteWhite", srgb("EDE6D6"), 0.95),
    "ChuteOrange": material("ChuteOrange", srgb("D7642E"), 0.95),
    "Envelope": material("Envelope", (1.0, 0.45, 0.12), 1.0, 0, (1.0, 0.45, 0.12), 0.5),
    "Trail": material("Trail", (1.0, 0.6, 0.2), 1.0, 0, (1.0, 0.6, 0.2), 0.5),
    "Earth": material("Earth", srgb("123A66"), 0.4),
    "Atmosphere": material("Atmosphere", srgb("5E9CE0"), 1.0, 0, None, 0.3),
    "Foam": material("Foam", srgb("E8F2F4"), 0.9, 0, None, 0.7),
    "Cloud": material("Cloud", srgb("F2F4F7"), 1.0, 0, None, 0.6),
}
tex_node = MAT["Hull"].node_tree.nodes.new("ShaderNodeTexImage")
tex_node.image = hull_img
tex_node.interpolation = "Closest"
MAT["Hull"].node_tree.links.new(tex_node.outputs["Color"], MAT["Hull"].node_tree.nodes["Principled BSDF"].inputs["Base Color"])


# ---------- Utilidades ----------

collection_cache = {}


def collection(name):
    if name not in collection_cache:
        col = bpy.data.collections.new(name)
        scene.collection.children.link(col)
        collection_cache[name] = col
    return collection_cache[name]


def new_object(name, bm, mats, col="Cápsula"):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(MAT[m])
    obj = bpy.data.objects.new(name, mesh)
    collection(col).objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.set_sharp_from_angle(angle=math.radians(38))
    return obj


def lathe(bm, profile, segments, mat_for=None, scallop=0.0, start_angle=0.0):
    """Gira um perfil [(raio, z)] em torno de Z. Devolve as faces criadas e a matriz de vértices."""
    rings = []
    for (r, z) in profile:
        ring = []
        for s in range(segments):
            a = start_angle + s / segments * math.tau
            rr = r * (1.0 + (scallop if s % 2 else 0.0))
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        for s in range(segments):
            a, b = rings[i][s], rings[i][(s + 1) % segments]
            c, d = rings[i + 1][(s + 1) % segments], rings[i + 1][s]
            if a.co == d.co and b.co == c.co:
                continue
            verts = [a, b, c, d]
            unique = []
            for v in verts:
                if all((v.co - u.co).length > 1e-6 for u in unique):
                    unique.append(v)
            if len(unique) < 3:
                continue
            try:
                f = bm.faces.new(unique)
            except ValueError:
                continue
            if mat_for:
                f.material_index = mat_for(i, s)
            faces.append((f, i, s))
    return faces, rings


def cylindrical_uv(bm, z0, z1):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        us = []
        for loop in f.loops:
            co = loop.vert.co
            us.append(math.atan2(co.y, co.x) / math.tau + 0.5)
        if max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        for loop, u in zip(f.loops, us):
            loop[uv].uv = (u, (loop.vert.co.z - z0) / (z1 - z0))


def planar_uv(bm, radius):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x / (2 * radius) + 0.5, co.y / (2 * radius) + 0.5)


def place_on_cone(obj, angle_deg, z, radius_at, slope_deg, outward=0.0):
    """Coloca um objeto rente à superfície cônica, com +Z do objeto seguindo a normal."""
    a = math.radians(angle_deg)
    r = radius_at(z) + outward
    obj.location = (math.cos(a) * r, math.sin(a) * r, z)
    obj.rotation_euler = (0.0, math.radians(90.0 - slope_deg), a)


# ---------- Módulo de comando ----------

# Perfil cônico com juntas rebaixadas. Meio-ângulo do cone ~31,5° (Apollo CM: ~33°).
CONE_A = (1.90, 0.26)
CONE_B = (0.62, 2.35)


def cone_r(z):
    t = (z - CONE_A[1]) / (CONE_B[1] - CONE_A[1])
    return CONE_A[0] + (CONE_B[0] - CONE_A[0]) * t


CONE_SLOPE = math.degrees(math.atan2(CONE_A[0] - CONE_B[0], CONE_B[1] - CONE_A[1]))


def command_module():
    bm = bmesh.new()
    seams = [0.86, 1.52]
    profile = [(1.955, 0.08), (1.955, 0.20), (1.92, 0.25), CONE_A]
    zones = ["HullJoint", "HullJoint", "HullJoint"]
    for sz in seams:
        for dz, inset in [(-0.025, 0.0), (-0.012, -0.012), (0.012, -0.012), (0.025, 0.0)]:
            z = sz + dz
            profile.append((cone_r(z) + inset, z))
    profile += [CONE_B, (0.57, 2.44), (0.44, 2.49), (0.42, 2.52), (0.42, 2.88), (0.33, 2.98), (0.18, 3.03), (0.0, 3.05)]
    mats = ["Hull", "HullJoint", "Seam", "Frame"]

    def mat_for(i, s):
        z_lo = profile[i][1]
        z_hi = profile[i + 1][1]
        if z_hi <= 0.26:
            return 1
        for sz in seams:
            if sz - 0.026 <= z_lo and z_hi <= sz + 0.026:
                return 2
        if z_lo >= 2.49:
            return 3
        return 0

    lathe(bm, profile, 40, mat_for)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cylindrical_uv(bm, 0.26, 2.35)
    return new_object("CommandModule", bm, mats)


def ring_detail(name, outer, inner, depth, frame_mat="Frame", glass=True, rect=None):
    """Moldura rebaixada (redonda ou retangular) com vidro escuro afundado."""
    bm = bmesh.new()
    segs = 16
    if rect:
        w, h = rect
        shape = [(-w, -h), (w, -h), (w, h), (-w, h)]
        outer_pts = [(x * 1.0, y * 1.0) for x, y in shape]
        inner_pts = [(x * inner / outer, y * inner / outer) for x, y in shape]
    else:
        outer_pts = [(math.cos(i / segs * math.tau) * outer, math.sin(i / segs * math.tau) * outer) for i in range(segs)]
        inner_pts = [(math.cos(i / segs * math.tau) * inner, math.sin(i / segs * math.tau) * inner) for i in range(segs)]
    n = len(outer_pts)
    ob = [bm.verts.new((x, y, 0.0)) for x, y in outer_pts]
    ot = [bm.verts.new((x, y, depth)) for x, y in outer_pts]
    it = [bm.verts.new((x, y, depth)) for x, y in inner_pts]
    ib = [bm.verts.new((x, y, depth * 0.2)) for x, y in inner_pts]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([ob[i], ob[j], ot[j], ot[i]]).material_index = 0
        bm.faces.new([ot[i], ot[j], it[j], it[i]]).material_index = 0
        bm.faces.new([it[i], it[j], ib[j], ib[i]]).material_index = 0
    mats = [frame_mat]
    if glass:
        g = bm.faces.new(list(reversed(ib)))
        g.material_index = 1
        mats.append("Glass" if frame_mat == "Frame" else "Plate")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    planar_uv(bm, outer)
    obj = new_object(name, bm, mats)
    return obj


def box(name, size, mats=("Plate",), col="Cápsula"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(size) * 0.18, segments=1, affect="EDGES")
    planar_uv(bm, max(size))
    return new_object(name, bm, list(mats), col)


def capsule_details(cm):
    """Escotilha, janelas, placas técnicas e portas do RCS, unidas ao casco."""
    parts = []
    front = -90.0  # -Y do Blender: frente da cápsula (escotilha voltada para a câmera)
    hatch = ring_detail("Hatch", 0.42, 0.36, 0.035, "Plate", True, rect=(0.36, 0.42))
    place_on_cone(hatch, front, 1.18, cone_r, CONE_SLOPE, -0.018)
    parts.append(hatch)
    hw = ring_detail("HatchWindow", 0.12, 0.08, 0.05)
    place_on_cone(hw, front, 1.30, cone_r, CONE_SLOPE, 0.03)
    parts.append(hw)
    for ang, z, size in [(front - 34, 1.98, 0.11), (front + 34, 1.98, 0.11), (front - 92, 1.32, 0.15), (front + 92, 1.32, 0.15)]:
        w = ring_detail("Window", size, size * 0.66, 0.05)
        place_on_cone(w, ang, z, cone_r, CONE_SLOPE, 0.0)
        parts.append(w)
    for ang, z in [(front + 180, 1.25), (front + 140, 0.62), (front - 140, 0.62)]:
        p = box("TechPlate", (0.3, 0.22, 0.012))
        place_on_cone(p, ang, z, cone_r, CONE_SLOPE, 0.0)
        parts.append(p)
    for ang in (front + 45, front + 135, front - 45, front - 135):
        q = box("RCSPort", (0.09, 0.07, 0.03), ("RCS",))
        place_on_cone(q, ang, 2.1, cone_r, CONE_SLOPE, 0.0)
        parts.append(q)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    cm.select_set(True)
    bpy.context.view_layer.objects.active = cm
    bpy.ops.object.join()
    return cm


def heat_shield():
    bm = bmesh.new()
    profile = [(0.0, -0.34), (0.45, -0.33), (0.9, -0.29), (1.35, -0.22), (1.72, -0.13),
               (1.90, -0.06), (1.975, 0.0), (1.99, 0.06), (1.965, 0.11), (1.90, 0.12)]

    def mat_for(i, s):
        return 1 if i >= 5 else 0

    lathe(bm, profile, 40, mat_for)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    planar_uv(bm, 2.0)
    return new_object("HeatShield", bm, ["Shield", "ShieldRim"])


def heat_envelopes():
    objs = []
    for name, profile in [
        ("HeatEnvelope", [(0.0, -0.62), (0.9, -0.55), (1.75, -0.36), (2.22, 0.0), (2.5, 0.8), (2.75, 2.2), (2.9, 4.0), (2.95, 6.0)]),
        ("HeatEnvelopeOuter", [(0.0, -0.95), (1.3, -0.85), (2.4, -0.45), (2.9, 0.4), (3.3, 2.4), (3.6, 5.0), (3.8, 8.5)]),
    ]:
        bm = bmesh.new()
        lathe(bm, profile, 32)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        cylindrical_uv(bm, profile[0][1], profile[-1][1])
        objs.append(new_object(name, bm, ["Envelope"], "Efeitos"))
    return objs


def trail():
    """Filamentos cruzados que saem da borda do escudo e afinam para trás."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    import random
    rnd = random.Random(11)
    count = 10
    for k in range(count):
        a = k / count * math.tau + rnd.uniform(-0.15, 0.15)
        length = rnd.uniform(9.0, 16.0)
        drift = rnd.uniform(0.15, 0.45)
        steps = 10
        for cross in (0, 1):
            left, right = [], []
            for i in range(steps + 1):
                t = i / steps
                r = 2.05 + drift * length * t * 0.25
                z = -0.05 + length * t
                cx, cy = math.cos(a) * r, math.sin(a) * r
                width = 0.42 * (1.0 - t) + 0.04
                if cross == 0:
                    tx, ty = -math.sin(a), math.cos(a)
                    off = (tx * width, ty * width, 0.0)
                else:
                    off = (math.cos(a) * width, math.sin(a) * width, 0.0)
                left.append((bm.verts.new((cx - off[0], cy - off[1], z - off[2])), t))
                right.append((bm.verts.new((cx + off[0], cy + off[1], z + off[2])), t))
            for i in range(steps):
                f = bm.faces.new([left[i][0], right[i][0], right[i + 1][0], left[i + 1][0]])
                for loop in f.loops:
                    is_right = any(loop.vert is v for v, _ in right)
                    t = next(tt for v, tt in (right if is_right else left) if v is loop.vert)
                    loop[uv].uv = (1.0 if is_right else 0.0, t)
    return new_object("ReentryTrail", bm, ["Trail"], "Efeitos")


def service_module():
    bm = bmesh.new()
    profile = [(0.0, 0.0), (1.90, 0.0), (1.955, -0.06), (1.955, -4.45), (1.80, -4.55), (0.75, -4.62), (0.0, -4.62)]

    def mat_for(i, s):
        if i == 3 and (s // 3) % 2 == 1:
            return 1
        return 0

    lathe(bm, profile, 36, mat_for)
    bell_profile = [(0.32, -4.6), (0.42, -4.75), (0.62, -5.2), (0.85, -5.75), (1.0, -6.15)]
    lathe(bm, bell_profile, 24, lambda i, s: 2)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cylindrical_uv(bm, -6.15, 0.0)
    sm = new_object("ServiceModule", bm, ["SMBody", "SMRadiator", "Bell"], "Módulo de serviço")
    quads = []
    for ang in (45, 135, 225, 315):
        q = box("RCSQuad", (0.22, 0.16, 0.34), ("RCS",), "Módulo de serviço")
        a = math.radians(ang)
        q.location = (math.cos(a) * 2.02, math.sin(a) * 2.02, -0.95)
        q.rotation_euler = (0, 0, a)
        quads.append(q)
    bpy.ops.object.select_all(action="DESELECT")
    for q in quads:
        q.select_set(True)
    sm.select_set(True)
    bpy.context.view_layer.objects.active = sm
    bpy.ops.object.join()
    return sm


def chute(name, profile, gores, orange_rule):
    bm = bmesh.new()
    lathe(bm, profile, gores * 2, lambda i, s: 1 if orange_rule(i, s // 2) else 0, scallop=0.05)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cylindrical_uv(bm, 0.0, profile[0][1])
    return new_object(name, bm, ["ChuteWhite", "ChuteOrange"], "Paraquedas")


def sphere(name, segments, rings, mat, col):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0, calc_uvs=True)
    obj = new_object(name, bm, [mat], col)
    return obj


def foam_disc():
    bm = bmesh.new()
    segs = 48
    inner = [bm.verts.new((math.cos(i / segs * math.tau) * 0.15, math.sin(i / segs * math.tau) * 0.15, 0)) for i in range(segs)]
    outer = [bm.verts.new((math.cos(i / segs * math.tau), math.sin(i / segs * math.tau), 0)) for i in range(segs)]
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new([inner[i], inner[j], outer[j], outer[i]])
    planar_uv(bm, 1.0)
    return new_object("FoamDisc", bm, ["Foam"], "Oceano")


def cloud_layer():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=8, y_segments=8, size=0.5, calc_uvs=True)
    return new_object("CloudLayer", bm, ["Cloud"], "Céu")


# ---------- Montagem ----------

cm = capsule_details(command_module())
shield = heat_shield()
heat_envelopes()
trail()
sm = service_module()
chute("MainChute",
      [(0.10, 0.70), (0.38, 0.66), (0.62, 0.56), (0.82, 0.40), (0.95, 0.20), (1.0, 0.04), (0.98, 0.0)],
      12, lambda ring, gore: ring >= 3 and gore % 2 == 0)
chute("DrogueChute",
      [(0.08, 0.95), (0.35, 0.80), (0.62, 0.52), (0.85, 0.22), (1.0, 0.0)],
      8, lambda ring, gore: ring % 2 == 1)
sphere("EarthSphere", 128, 64, "Earth", "Terra")
sphere("AtmosphereShell", 96, 48, "Atmosphere", "Terra")
foam_disc()
cloud_layer()

# Vista de revisão no .blend: módulo de serviço afastado e paraquedas acima.
sm.location = (0, 0, -0.4)
for name, loc, scale in [("MainChute", (0, 0, 9.0), 4.0), ("DrogueChute", (0, 0, 6.0), 1.0)]:
    obj = bpy.data.objects[name]
    obj.location = loc
    obj.scale = (scale, scale, scale)
for name in ("EarthSphere", "AtmosphereShell", "FoamDisc", "CloudLayer"):
    bpy.data.objects[name].hide_set(True)

# Exporta com transformações zeradas (a cena do Godot posiciona cada peça).
saved = {}
for obj in scene.objects:
    saved[obj.name] = (obj.location.copy(), obj.scale.copy())
    obj.location = (0, 0, 0)
    obj.scale = (1, 1, 1)
    obj.hide_set(False)
bpy.ops.object.select_all(action="SELECT")
result = bpy.ops.export_scene.gltf(
    filepath=str(out / "reentry_set.glb"), export_format="GLB", use_selection=True,
    export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
    export_animations=False, export_apply=True)
assert result == {"FINISHED"}, result
for obj in scene.objects:
    obj.location, obj.scale = saved[obj.name]
for name in ("EarthSphere", "AtmosphereShell", "FoamDisc", "CloudLayer"):
    bpy.data.objects[name].hide_set(True)

(source / ".gdignore").write_text("", encoding="utf-8")
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source / "apollo6_reentrada.blend"), compress=True)
print("REENTRY EXPORT OK", [o.name for o in scene.objects])
