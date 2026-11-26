import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
W, D = 2.44, 0.62
LV = [0.52, 1.15, 1.78]; TH = 0.45; TOP = LV[-1] + TH + 0.2
FRONT = -D / 2  # Blender -Y = Godot +Z (ön)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def mat(name, col, rough, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

M = {
 "boya": mat("SiyahBoya", (0.012, 0.012, 0.013), 0.38),       # saten siyah boyalı MDF
 "mat": mat("SiyahMat", (0.008, 0.008, 0.009), 0.7),          # iç yüzeyler, tablalar
 "alu": mat("Aluminyum", (0.72, 0.73, 0.75), 0.32, 1.0),       # fırçalanmış alüminyum çıta/kulp
 "led": mat("LedSerit", (1, 1, 1), 0.4, 0.0, (0.92, 0.96, 1.0), 6.0),
 "lastik": mat("Lastik", (0.02, 0.02, 0.02), 0.85),
}
objs = []
def box(name, size, loc, m, bev=0.004, seg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bev > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bev, min(size) * 0.45), segments=seg, affect='EDGES', profile=0.5)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    me.materials.append(M[m])
    o = bpy.data.objects.new(name, me); o.location = loc; sc.collection.objects.link(o); objs.append(o)
    return o

# Gövde: yanlar, arka, orta dikme
for sx in (-1, 1):
    box("Yan", (0.03, D, TOP), (sx * (W / 2 - 0.015), 0, TOP / 2), "boya", 0.006)
box("Arka", (W - 0.06, 0.02, TOP), (0, D / 2 - 0.01, TOP / 2), "mat", 0.0)
box("OrtaDikme", (0.05, 0.06, TOP - LV[0] - 0.005), (0, FRONT + 0.027, LV[0] + (TOP - LV[0] - 0.005) / 2), "boya", 0.006)
# Alt dolap: süpürgelik geride, kapaklar önde
base_h = LV[0] - 0.03
box("Supurgelik", (W - 0.08, D - 0.08, 0.078), (0, 0.02, 0.039), "lastik", 0.002)
box("DolapGovde", (W - 0.064, D - 0.05, base_h - 0.08), (0, 0.005, 0.08 + (base_h - 0.08) / 2), "mat", 0.0)
doors = 4; gap = 0.004; dw = (W - 0.06 - gap * (doors + 1)) / doors; dh = base_h - 0.08 - 0.01
for i in range(doors):
    x = -W / 2 + 0.03 + gap + dw / 2 + i * (dw + gap)
    box("Kapak", (dw, 0.018, dh), (x, FRONT + 0.009 + 0.02, 0.085 + dh / 2), "boya", 0.003)
    hx = x + (dw / 2 - 0.04) * (1 if i % 2 == 0 else -1)
    box("Kulp", (0.012, 0.022, 0.16), (hx, FRONT + 0.004, 0.085 + dh - 0.12), "alu", 0.004, 3)
# Kat tablaları ve öndeki kalın ışık bantları
for li, y in enumerate(LV):
    box("Tabla", (W - 0.064, D - 0.03, 0.03), (0, -0.005, y - 0.015), "mat", 0.002)
    if li == 0: box("TablaOnBant", (W - 0.06, 0.02, 0.03), (0, FRONT + 0.01, y - 0.018), "boya", 0.003)
    band_y = (LV[li + 1] if li + 1 < len(LV) else TOP) - 0.075
    box("IsikBandi", (W - 0.062, 0.045, 0.148), (0, FRONT + 0.0225, band_y - 0.001), "boya", 0.006)
    box("AluCita", (W - 0.08, 0.004, 0.008), (0, FRONT - 0.0005, band_y - 0.06), "alu", 0.0015)
    box("Led", (W - 0.14, 0.05, 0.003), (0, FRONT + 0.075, band_y - 0.0775), "led", 0.0)
    box("LedKanal", (W - 0.12, 0.06, 0.012), (0, FRONT + 0.076, band_y - 0.069), "alu", 0.002)
# Üst korniş (hafif taşkın)
box("UstKapak", (W + 0.02, D + 0.02, 0.035), (0, -0.0, TOP + 0.0175), "boya", 0.008, 3)
box("Korniş", (W + 0.03, 0.03, 0.06), (0, FRONT - 0.005, TOP - 0.01), "boya", 0.008, 3)

# Tek nesnede birleştir (az draw call), malzemeler slot olarak kalır
bpy.ops.object.select_all(action='DESELECT')
for o in objs: o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.join()
ob = bpy.context.active_object; ob.name = "AkvaryumKabin"; ob.data.name = "AkvaryumKabin"
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
# Orijin: alt-orta
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.002); bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
bpy.ops.wm.save_as_mainfile(filepath=sys.argv[-1])
print("tris", sum(len(p.vertices) - 2 for p in ob.data.polygons), "top", TOP)
