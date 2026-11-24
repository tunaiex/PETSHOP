"""Guppy.blend (Blender 2.7, eski malzeme) -> Godot icin GLB (iskelet + yuzme animasyonu).

blender -b --disable-autoexec GUPPY.blend --python lepistes_donustur.py -- CIKTI.glb
Dokular .blend ile ayni klasorde olmali (Guppy Text.png).
"""
import bpy, sys, os

cikti = sys.argv[sys.argv.index("--") + 1]
klasor = os.path.dirname(bpy.data.filepath)

# Kamera / isik disari
for o in list(bpy.data.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o, do_unlink=True)

# Eski (Blender Internal) malzeme yerine dokulu Principled BSDF
doku = bpy.data.images.load(os.path.join(klasor, "Guppy Text.png"), check_existing=True)
m = bpy.data.materials.new("Lepistes")
m.use_nodes = True
n = m.node_tree.nodes
bsdf = n["Principled BSDF"]
t = n.new("ShaderNodeTexImage"); t.image = doku
m.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
m.node_tree.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
bsdf.inputs["Roughness"].default_value = 0.45
m.blend_method = "HASHED"   # yari saydam yuzgecler varsa
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.materials.clear()
        o.data.materials.append(m)

bpy.ops.export_scene.gltf(filepath=cikti, export_format="GLB", export_apply=True,
                          export_animations=True, export_skins=True, export_yup=True)
print("DISA AKTARILDI", cikti)
