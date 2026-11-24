"""Gercekci akvaryum arka plani: Poly Haven (CC0) modelleriyle Blender/Cycles sahnesi.

Kullanim:
  blender -b --disable-autoexec --python akvaryum_sahne.py -- VARLIK_DIZINI CIKTI_DIZINI [ornek] [mod]
mod: "guzel" (tam render) | "maske" (katman maskeleri) | "hepsi"
Ciktilar: guzel.png (tum sahne), maske_tas.png, maske_kutuk.png, maske_on.png
"""
import bpy, sys, os, math, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
VARLIK, CIKTI = args[0], args[1]
ORNEK = int(args[2]) if len(args) > 2 else 32
MOD = args[3] if len(args) > 3 else "hepsi"
COZ = int(args[4]) if len(args) > 4 else 480
os.makedirs(CIKTI, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
V = mathutils.Vector


def koleksiyon(ad):
    k = bpy.data.collections.new(ad)
    sc.collection.children.link(k)
    return k


K_ARKA, K_TAS, K_KUTUK, K_ON, K_ISIK = (koleksiyon(a) for a in ("arka", "tas", "kutuk", "on", "isik"))


def blend_yukle(ad, filtre=None):
    yol = os.path.join(VARLIK, ad, ad + ".blend")
    with bpy.data.libraries.load(yol, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if ("_LOD" not in n or n.endswith("_LOD0"))]
    nes = [o for o in dst.objects if o and o.type == "MESH" and (filtre is None or filtre(o.name))]
    return nes


def gltf_yukle(yol):
    once = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=yol)
    yeni = [o for o in bpy.data.objects if o not in once]
    for o in yeni:
        for k in list(o.users_collection):
            k.objects.unlink(o)
    return [o for o in yeni if o.type == "MESH"]


EGIM = math.radians(7.0)  # zemin arkaya dogru yukselir (akvaryum terasi)


def zemin_z(y):
    return math.tan(EGIM) * y


def yerlestir(nes, hedef_kol, konum, olcek=1.0, donus=0.0, zemin=None):
    """Nesne grubunu XY merkezi 'konum'a, tabani zemine oturtur."""
    bos = bpy.data.objects.new("grup", None)
    hedef_kol.objects.link(bos)
    for o in nes:
        hedef_kol.objects.link(o)
        o.parent = bos
    bos.scale = (olcek,) * 3
    bos.rotation_euler = (0, 0, math.radians(donus))
    bpy.context.view_layer.update()
    mn = V((1e9,) * 3); mx = V((-1e9,) * 3)
    for o in nes:
        for c in o.bound_box:
            w = o.matrix_world @ V(c)
            mn = V(map(min, mn, w)); mx = V(map(max, mx, w))
    if zemin is None:
        zemin = zemin_z(konum[1]) - 0.05
    bos.location = V((konum[0] - (mn.x + mx.x) / 2, konum[1] - (mn.y + mx.y) / 2, zemin - mn.z))
    bpy.context.view_layer.update()
    return bos


# ------------------------------------------------------------------ nesneler
tas = yerlestir(blend_yukle("boulder_01_4k"), K_TAS, (-1.45, 0.9), olcek=1.35, donus=25)
kutuk = yerlestir(blend_yukle("namaqualand_boulder_02_4k"), K_KUTUK, (1.65, 1.1), olcek=1.05, donus=-160)
sirt = yerlestir(blend_yukle("coast_land_rocks_02_4k"), K_ARKA, (0.0, 6.8), olcek=1.3, donus=0, zemin=zemin_z(6.8) - 0.35)
yosunlu = yerlestir(blend_yukle("rock_moss_set_02_4k"), K_ARKA, (0.2, 3.4), olcek=0.5, donus=8)
kabuk = yerlestir(blend_yukle("lambis_shell_4k"), K_ON, (0.55, -0.95), olcek=2.2, donus=-30)

# Bitkiler: buz bitkisi kumelerini on koselere, calathea'yi arkaya
buz = blend_yukle("crystalline_iceplant_4k")
for i, o in enumerate(buz):
    x = (-1.95 + i * 0.32) if i < 4 else (1.0 + (i - 4) * 0.32)
    yerlestir([o], K_ON, (x, -1.35 + (i % 2) * 0.25), olcek=3.2, donus=i * 47, zemin=zemin_z(-1.3) + 0.02)
cal = gltf_yukle(os.path.join(VARLIK, "calathea_orbifolia_01_4k", "calathea_orbifolia_01_4k.gltf"))
cal_yer = [(-2.2, 2.4), (-0.9, 3.6), (0.9, 3.9), (2.5, 2.7), (-0.1, 4.8)]
for o, p in zip(cal, cal_yer):
    yerlestir([o], K_ARKA, p, olcek=2.4, donus=p[0] * 40)

# ------------------------------------------------------------------ uretilen bitkiler
import random


def bitki_malzeme(ad, renk1, renk2):
    m = bpy.data.materials.new(ad); m.use_nodes = True
    n = m.node_tree.nodes; l = m.node_tree.links
    bsdf = n["Principled BSDF"]
    gc = n.new("ShaderNodeTexCoord")
    sep = n.new("ShaderNodeSeparateXYZ"); l.new(gc.outputs["UV"], sep.inputs[0])
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = renk1; ramp.color_ramp.elements[1].color = renk2
    l.new(sep.outputs["Y"], ramp.inputs["Fac"])
    l.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    # Yapraklar isigi icinden gecirir (arkadan aydinlanma)
    yari = n.new("ShaderNodeBsdfTranslucent"); l.new(ramp.outputs["Color"], yari.inputs["Color"])
    kar = n.new("ShaderNodeMixShader"); kar.inputs["Fac"].default_value = 0.35
    l.new(bsdf.outputs[0], kar.inputs[1]); l.new(yari.outputs[0], kar.inputs[2])
    l.new(kar.outputs[0], n["Material Output"].inputs["Surface"])
    return m


def yaprak_kumesi(ad, kol, merkez, yaricap, adet, boy, genislik, egrilik, malzeme, tohum):
    """Serit yapraklardan bir kume (vallisneria / sac otu) tek mesh olarak."""
    rnd = random.Random(tohum)
    noktalar, yuzler, uvlar = [], [], []
    BOL = 10
    for b in range(adet):
        a = rnd.random() * math.tau; r = yaricap * math.sqrt(rnd.random())
        x0 = merkez[0] + math.cos(a) * r; y0 = merkez[1] + math.sin(a) * r
        z0 = zemin_z(y0) - 0.05
        h = boy * rnd.uniform(0.55, 1.0)
        g = genislik * rnd.uniform(0.7, 1.2)
        yon = rnd.random() * math.tau
        egik = rnd.uniform(0.3, 1.0) * egrilik
        bukum = rnd.uniform(-1.5, 1.5)
        dx, dy = math.cos(yon), math.sin(yon)
        bas = len(noktalar)
        for i in range(BOL + 1):
            t = i / BOL
            # yukari cikarken bir yone egilir ve hafif S yapar
            ox = dx * egik * h * t * t + math.sin(t * 3 + b) * 0.04 * h
            oy = dy * egik * h * t * t
            z = z0 + h * t * (1 - 0.25 * egik * t)
            aci = yon + math.pi / 2 + bukum * t
            gw = g * (1 - 0.85 * t ** 2) / 2
            px, py = math.cos(aci) * gw, math.sin(aci) * gw
            noktalar += [(x0 + ox - px, y0 + oy - py, z), (x0 + ox + px, y0 + oy + py, z)]
            uvlar += [(0, t), (1, t)]
        for i in range(BOL):
            k = bas + i * 2
            yuzler.append((k, k + 1, k + 3, k + 2))
    me = bpy.data.meshes.new(ad); me.from_pydata(noktalar, [], yuzler)
    uv = me.uv_layers.new(name="UV")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = uvlar[me.loops[li].vertex_index]
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(malzeme)
    ob = bpy.data.objects.new(ad, me); kol.objects.link(ob)
    return ob


val_m = bitki_malzeme("vallisneria", (0.06, 0.20, 0.04, 1), (0.30, 0.55, 0.12, 1))
ot_m = bitki_malzeme("sac_otu", (0.08, 0.25, 0.05, 1), (0.35, 0.65, 0.15, 1))
# Arka sol ve arka sag: uzun vallisneria; tam arka: seyrek
yaprak_kumesi("val_sol", K_ARKA, (-2.4, 3.0), 1.0, 110, 4.4, 0.16, 0.40, val_m, 1)
yaprak_kumesi("val_sag", K_ARKA, (2.6, 3.2), 1.1, 110, 4.2, 0.16, 0.40, val_m, 2)
yaprak_kumesi("val_arka", K_ARKA, (0.2, 5.8), 2.6, 120, 4.0, 0.14, 0.30, val_m, 3)
# Kayalarin dibinde orta boy
yaprak_kumesi("val_tasdibi", K_ARKA, (-0.9, 2.1), 0.45, 18, 1.5, 0.12, 0.55, val_m, 4)
# On: kisa sac otu halisi (on katman)
yaprak_kumesi("ot_sol", K_ON, (-1.5, -1.1), 0.55, 160, 0.28, 0.018, 0.5, ot_m, 5)
yaprak_kumesi("ot_sag", K_ON, (1.35, -1.0), 0.6, 160, 0.30, 0.018, 0.5, ot_m, 6)
yaprak_kumesi("ot_orta", K_ARKA, (0.1, 0.4), 0.9, 140, 0.22, 0.016, 0.5, ot_m, 7)

# ------------------------------------------------------------------ kum zemin
def kum_malzeme():
    m = bpy.data.materials.new("kum"); m.use_nodes = True
    n = m.node_tree.nodes; l = m.node_tree.links
    bsdf = n["Principled BSDF"]
    tc = n.new("ShaderNodeTexCoord")
    gur = n.new("ShaderNodeTexNoise"); gur.inputs["Scale"].default_value = 6; gur.inputs["Detail"].default_value = 8
    l.new(tc.outputs["Object"], gur.inputs["Vector"])
    renk = n.new("ShaderNodeValToRGB")
    renk.color_ramp.elements[0].color = (0.36, 0.28, 0.18, 1)
    renk.color_ramp.elements[1].color = (0.72, 0.60, 0.42, 1)
    l.new(gur.outputs["Fac"], renk.inputs["Fac"])
    cakil = n.new("ShaderNodeTexVoronoi"); cakil.inputs["Scale"].default_value = 55
    l.new(tc.outputs["Object"], cakil.inputs["Vector"])
    karis = n.new("ShaderNodeMix"); karis.data_type = "RGBA"; karis.inputs["Factor"].default_value = 0.35
    l.new(renk.outputs["Color"], karis.inputs[6]); l.new(cakil.outputs["Color"], karis.inputs[7])
    l.new(karis.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    kab = n.new("ShaderNodeBump"); kab.inputs["Strength"].default_value = 0.6
    ince = n.new("ShaderNodeTexNoise"); ince.inputs["Scale"].default_value = 140
    l.new(tc.outputs["Object"], ince.inputs["Vector"])
    top = n.new("ShaderNodeMath"); top.operation = "ADD"
    l.new(ince.outputs["Fac"], top.inputs[0]); l.new(cakil.outputs["Distance"], top.inputs[1])
    l.new(top.outputs[0], kab.inputs["Height"])
    l.new(kab.outputs["Normal"], bsdf.inputs["Normal"])
    return m

bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 4, zemin_z(4)), rotation=(EGIM, 0, 0))
zemin = bpy.context.active_object; zemin.name = "zemin"
for k in list(zemin.users_collection): k.objects.unlink(zemin)
K_ARKA.objects.link(zemin)
zemin.data.materials.append(kum_malzeme())
# hafif dalgali zemin
mod = zemin.modifiers.new("alt", "SUBSURF"); mod.levels = mod.render_levels = 5; mod.subdivision_type = "SIMPLE"
dis = zemin.modifiers.new("dalga", "DISPLACE")
tx = bpy.data.textures.new("kum_dalga", "CLOUDS"); tx.noise_scale = 2.5
dis.texture = tx; dis.strength = 0.12

# ------------------------------------------------------------------ su, isik
# Su hacmi: derinlikte maviye kayan bulaniklik + isik huzmeleri
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 4, 2.6))
su = bpy.context.active_object; su.name = "su"; su.scale = (24, 22, 5.2)
for k in list(su.users_collection): k.objects.unlink(su)
K_ISIK.objects.link(su)
sm = bpy.data.materials.new("su_hacmi"); sm.use_nodes = True
sn = sm.node_tree.nodes; sn.remove(sn["Principled BSDF"])
pv = sn.new("ShaderNodeVolumePrincipled")
pv.inputs["Color"].default_value = (0.20, 0.75, 0.88, 1)
pv.inputs["Density"].default_value = 0.075
pv.inputs["Anisotropy"].default_value = 0.65
pv.inputs["Absorption Color"].default_value = (0.75, 0.95, 0.97, 1)
pv.inputs["Emission Color"].default_value = (0.05, 0.35, 0.45, 1)
pv.inputs["Emission Strength"].default_value = 0.03  # ortam sacilmasi: uzaklar koyu degil turkuaz
sm.node_tree.links.new(pv.outputs[0], sn["Material Output"].inputs["Volume"])
su.data.materials.append(sm)

# Kostik golgelik (gobo): gunes isigini su yuzeyi deseninden gecirir
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 4, 5.0))
gobo = bpy.context.active_object; gobo.name = "kostik_gobo"
for k in list(gobo.users_collection): k.objects.unlink(gobo)
K_ISIK.objects.link(gobo)
gobo.visible_camera = False; gobo.visible_diffuse = False; gobo.visible_glossy = False
gm = bpy.data.materials.new("kostik"); gm.use_nodes = True
gn = gm.node_tree.nodes; gl = gm.node_tree.links; gn.remove(gn["Principled BSDF"])
tc = gn.new("ShaderNodeTexCoord")
bozma = gn.new("ShaderNodeTexNoise"); bozma.inputs["Scale"].default_value = 1.5
vb = gn.new("ShaderNodeVectorMath"); vb.operation = "ADD"
gl.new(tc.outputs["Object"], vb.inputs[0]); gl.new(bozma.outputs["Color"], vb.inputs[1])
gl.new(tc.outputs["Object"], bozma.inputs["Vector"])
vor = gn.new("ShaderNodeTexVoronoi"); vor.feature = "DISTANCE_TO_EDGE"; vor.inputs["Scale"].default_value = 5
gl.new(vb.outputs[0], vor.inputs["Vector"])
esik = gn.new("ShaderNodeMapRange")
esik.inputs["From Min"].default_value = 0.0; esik.inputs["From Max"].default_value = 0.05
esik.inputs["To Min"].default_value = 1.0; esik.inputs["To Max"].default_value = 0.07
gl.new(vor.outputs["Distance"], esik.inputs["Value"])
saydam = gn.new("ShaderNodeBsdfTransparent"); siyah = gn.new("ShaderNodeBsdfDiffuse")
siyah.inputs["Color"].default_value = (0, 0, 0, 1)
karis = gn.new("ShaderNodeMixShader")
gl.new(esik.outputs["Result"], karis.inputs["Fac"])
gl.new(siyah.outputs[0], karis.inputs[1]); gl.new(saydam.outputs[0], karis.inputs[2])
gl.new(karis.outputs[0], gn["Material Output"].inputs["Surface"])
gobo.data.materials.append(gm)

gun = bpy.data.objects.new("gunes", bpy.data.lights.new("gunes", "SUN"))
K_ISIK.objects.link(gun)
gun.rotation_euler = (math.radians(12), math.radians(-8), 0)
gun.data.energy = 10.0; gun.data.color = (1.0, 0.97, 0.88); gun.data.angle = math.radians(1.5)

# Su yuzeyi: asagidan bakinca kirilan / tam ic yansima yapan dalgali yuzey
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 4, 5.15))
yuz = bpy.context.active_object; yuz.name = "su_yuzeyi"
for k in list(yuz.users_collection): k.objects.unlink(yuz)
K_ARKA.objects.link(yuz)
yuz.visible_shadow = False
ym = bpy.data.materials.new("yuzey"); ym.use_nodes = True
yn = ym.node_tree.nodes; yl = ym.node_tree.links; yn.remove(yn["Principled BSDF"])
cam_bsdf = yn.new("ShaderNodeBsdfGlass"); cam_bsdf.inputs["IOR"].default_value = 1.33
cam_bsdf.inputs["Roughness"].default_value = 0.04
cam_bsdf.inputs["Color"].default_value = (0.85, 0.97, 1.0, 1)
ytc = yn.new("ShaderNodeTexCoord")
ydal = yn.new("ShaderNodeTexNoise"); ydal.inputs["Scale"].default_value = 2.2; ydal.inputs["Detail"].default_value = 4
yl.new(ytc.outputs["Object"], ydal.inputs["Vector"])
ykab = yn.new("ShaderNodeBump"); ykab.inputs["Strength"].default_value = 0.35
yl.new(ydal.outputs["Fac"], ykab.inputs["Height"])
yl.new(ykab.outputs["Normal"], cam_bsdf.inputs["Normal"])
yl.new(cam_bsdf.outputs[0], yn["Material Output"].inputs["Surface"])
yuz.data.materials.append(ym)

# Arka cam fonu: gercek akvaryumlardaki gibi koyu mavi fon; sisle turkuaza kaybolur
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 8.2, 2.6), rotation=(math.radians(90), 0, 0))
fon = bpy.context.active_object; fon.name = "arka_fon"; fon.scale = (30, 6, 1)
for k in list(fon.users_collection): k.objects.unlink(fon)
K_ARKA.objects.link(fon)
fm = bpy.data.materials.new("fon"); fm.use_nodes = True
fnn = fm.node_tree.nodes; fnn.remove(fnn["Principled BSDF"])
fe = fnn.new("ShaderNodeEmission"); fe.inputs["Color"].default_value = (0.01, 0.07, 0.10, 1); fe.inputs["Strength"].default_value = 1.0
fm.node_tree.links.new(fe.outputs[0], fnn["Material Output"].inputs["Surface"])
fon.data.materials.append(fm)

# Dunya: derin su rengi (uzak arka plan)
w = bpy.data.worlds.new("su_dunya"); sc.world = w; w.use_nodes = True
wn = w.node_tree.nodes; wl = w.node_tree.links
wtc = wn.new("ShaderNodeTexCoord")
wsep = wn.new("ShaderNodeSeparateXYZ"); wl.new(wtc.outputs["Generated"], wsep.inputs[0])
wramp = wn.new("ShaderNodeValToRGB")
wramp.color_ramp.elements[0].position = 0.0; wramp.color_ramp.elements[0].color = (0.01, 0.10, 0.14, 1)
wramp.color_ramp.elements[1].position = 0.6; wramp.color_ramp.elements[1].color = (0.75, 0.92, 1.0, 1)
wl.new(wsep.outputs["Z"], wramp.inputs["Fac"])
wl.new(wramp.outputs["Color"], wn["Background"].inputs[0])
wn["Background"].inputs[1].default_value = 1.2

# ------------------------------------------------------------------ kamera
cam = bpy.data.objects.new("kamera", bpy.data.cameras.new("kamera")); sc.collection.objects.link(cam)
cam.location = (0, -2.7, 1.35)
hedef = V((0, 2.0, 1.75))
cam.rotation_euler = (hedef - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 24
cam.data.dof.use_dof = True
cam.data.dof.focus_distance = 3.6
cam.data.dof.aperture_fstop = 2.2
sc.camera = cam

# ------------------------------------------------------------------ render
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = ORNEK
sc.cycles.use_denoising = False
try:
    sc.cycles.denoiser = "OPENIMAGEDENOISE"
except Exception:
    pass
sc.cycles.volume_step_rate = 4.0
sc.cycles.sample_clamp_indirect = 1.5
sc.cycles.caustics_reflective = False
sc.cycles.caustics_refractive = False
sc.cycles.max_bounces = 6
sc.render.resolution_x = sc.render.resolution_y = COZ
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"


def render(ad):
    sc.render.filepath = os.path.join(CIKTI, ad)
    bpy.ops.render.render(write_still=True)


if MOD in ("guzel", "hepsi"):
    render("guzel.png")

if MOD in ("maske", "hepsi"):
    # Katman maskeleri: katmandaki nesneler beyaz, diger her sey siyah (ortucu).
    beyaz = bpy.data.materials.new("beyaz"); beyaz.use_nodes = True
    bn = beyaz.node_tree.nodes; bn.remove(bn["Principled BSDF"])
    be = bn.new("ShaderNodeEmission"); be.inputs["Color"].default_value = (1, 1, 1, 1)
    beyaz.node_tree.links.new(be.outputs[0], bn["Material Output"].inputs["Surface"])
    siyahm = bpy.data.materials.new("siyah"); siyahm.use_nodes = True
    sn2 = siyahm.node_tree.nodes; sn2.remove(sn2["Principled BSDF"])
    se = sn2.new("ShaderNodeEmission"); se.inputs["Color"].default_value = (0, 0, 0, 1)
    siyahm.node_tree.links.new(se.outputs[0], sn2["Material Output"].inputs["Surface"])
    K_ISIK.hide_render = True
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.0  # dunya isigi kapali
    sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
    sc.cycles.samples = 16; sc.cycles.use_denoising = False
    katmanlar = {"tas": K_TAS, "kutuk": K_KUTUK, "on": K_ON}
    tum = [o for o in sc.objects if o.type == "MESH" and not o.users_collection[0] is K_ISIK]
    for ad, kol in katmanlar.items():
        for o in tum:
            mat = beyaz if kol in o.users_collection else siyahm
            o.data.materials.clear() if False else None
            o.material_slots and None
            o["_asil"] = 1
            for i in range(len(o.material_slots)):
                o.material_slots[i].link = "OBJECT"; o.material_slots[i].material = mat
            if not o.material_slots:
                o.data.materials.append(mat)
        render("maske_%s.png" % ad)
print("BITTI")
