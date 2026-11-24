"""Full 3D characters from 4 views: visual hull + 4-view projection bake + rig + animations."""
import sys, os, math, time
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from PIL import Image
from chars import CHARS
from prep import compute_weights
from recon import Views
from build import make_animations, FPS

FOLDERS = {'Bebek': '01_Bebek', 'Genc': '02_Genc', 'Yasli': '03_Yasli'}
TEX = 2048
TARGET_FACES = 36000


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def build(name, IN, OUT):
    t0 = time.time()
    cfg = CHARS[name]
    reset()
    V = Views(f'{IN}/{FOLDERS[name]}', cfg)
    V.build_volume(ds=4)
    V.depth_maps()
    P, Fc = V.surface()
    k = cfg['height'] / (V.ground - V.top)
    cx, ground = V.cx, V.ground
    print(name, 'hull verts', len(P), 'faces', len(Fc), f'{time.time() - t0:.1f}s')

    def tob(p):  # front-px (x, y, z) -> blender
        return np.stack([(p[:, 0] - cx) * k, -p[:, 2] * k, (ground - p[:, 1]) * k], 1)

    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(tob(P).tolist(), [], Fc[:, ::-1].tolist())
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # clean + decimate
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh); bm.free()
    mod = obj.modifiers.new('dec', 'DECIMATE')
    mod.ratio = min(1.0, TARGET_FACES / max(len(mesh.polygons), 1))
    bpy.ops.object.modifier_apply(modifier='dec')
    sm = obj.modifiers.new('sm', 'CORRECTIVE_SMOOTH')
    sm.iterations = 4; sm.use_only_smooth = True
    bpy.ops.object.modifier_apply(modifier='sm')
    for p in mesh.polygons:
        p.use_smooth = True
    print(name, 'decimated', len(mesh.vertices), 'verts', len(mesh.polygons), 'faces')

    # main UVs
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh.uv_layers[0].name = 'UVMap'

    # back to front-px coordinates for projection
    nv = len(mesh.vertices)
    co = np.zeros(nv * 3); mesh.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
    mesh.calc_normals_split() if hasattr(mesh, 'calc_normals_split') else None
    nrm = np.zeros(nv * 3); mesh.vertices.foreach_get('normal', nrm); nrm = nrm.reshape(-1, 3)
    Pf = np.stack([co[:, 0] / k + cx, ground - co[:, 2] / k, -co[:, 1] / k], 1)
    Nf = np.stack([nrm[:, 0], -nrm[:, 2], -nrm[:, 1]], 1)  # (x right, y down, z front)
    vis = V.visibility(Pf)
    proj = V.project(Pf)
    from scipy import ndimage as _ndi
    for v in ('On', 'Arka', 'Sag', 'Sol'):
        mm = _ndi.binary_erosion(V.mask[v], iterations=3).astype(np.float32)
        inside = _ndi.map_coordinates(mm, [proj[v][:, 1], proj[v][:, 0]], order=1, cval=0) > 0.5
        vis[v] = vis[v] & inside
    dirs = {'On': (0, 0, 1), 'Arka': (0, 0, -1), 'Sag': (-1, 0, 0), 'Sol': (1, 0, 0)}
    boost = {'On': 1.4, 'Arka': 1.1, 'Sag': 1.0, 'Sol': 1.0}
    order = ['On', 'Arka', 'Sag', 'Sol']
    expo = {'On': 2.5, 'Arka': 2.5, 'Sag': 5, 'Sol': 5}
    Wv = np.stack([np.clip(Nf @ np.array(dirs[v], float), 0, None) ** expo[v] * boost[v] * vis[v] for v in order], 1)
    fallback = np.stack([np.clip(Nf @ np.array(dirs[v], float), 0, None) ** 3 + 1e-4 for v in order], 1)
    side_gate = np.clip((np.abs(Nf[:, 0]) - 0.45) / 0.3, 0, 1) ** 2
    Wv[:, 2] *= side_gate; Wv[:, 3] *= side_gate
    bad = Wv.sum(1) < 1e-3
    Wv[bad] = fallback[bad]
    Wv /= Wv.sum(1, keepdims=True)
    print('weights mean', Wv.mean(0), 'vis', {v: vis[v].mean() for v in order})

    # per-view UV maps + weight colour attribute
    loops_v = np.zeros(len(mesh.loops), int); mesh.loops.foreach_get('vertex_index', loops_v)
    for v in order:
        im = V.img[v]
        h, w = im.shape[:2]
        uvl = mesh.uv_layers.new(name='P_' + v)
        uv = np.stack([proj[v][:, 0] / w, 1 - proj[v][:, 1] / h], 1)[loops_v]
        uvl.data.foreach_set('uv', uv.ravel())
        chk = np.zeros(len(mesh.loops) * 2); uvl.data.foreach_get('uv', chk)
        print('uv', v, uv.min(0), uv.max(0), 'readback', chk.reshape(-1, 2).mean(0))
    mesh.uv_layers.active = mesh.uv_layers['UVMap']
    ca = mesh.color_attributes.new('ViewW', 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set('color', Wv.ravel())

    # bake material
    mat = bpy.data.materials.new(name + '_Bake')
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    outn = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(em.outputs[0], outn.inputs['Surface'])
    attr = nt.nodes.new('ShaderNodeAttribute'); attr.attribute_name = 'ViewW'
    sep = nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(attr.outputs['Color'], sep.inputs[0])
    wsock = [sep.outputs[0], sep.outputs[1], sep.outputs[2], attr.outputs['Alpha']]
    acc = None
    for i, v in enumerate(order):
        img = bpy.data.images.new(f'{name}_{v}', V.img[v].shape[1], V.img[v].shape[0], alpha=True)
        img.colorspace_settings.name = 'sRGB'
        img.pixels.foreach_set((np.flipud(V.img[v]).astype(np.float32) / 255).ravel())
        img.update()
        print('img', v, np.array(img.pixels[:]).reshape(-1, 4).mean(0))
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img; tex.extension = 'EXTEND'
        uvn = nt.nodes.new('ShaderNodeUVMap'); uvn.uv_map = 'P_' + v
        nt.links.new(uvn.outputs[0], tex.inputs['Vector'])
        sc = nt.nodes.new('ShaderNodeVectorMath'); sc.operation = 'SCALE'
        nt.links.new(tex.outputs['Color'], sc.inputs[0])
        nt.links.new(wsock[i], sc.inputs['Scale'])
        if acc is None:
            acc = sc
        else:
            ad = nt.nodes.new('ShaderNodeVectorMath'); ad.operation = 'ADD'
            nt.links.new(acc.outputs[0], ad.inputs[0]); nt.links.new(sc.outputs[0], ad.inputs[1])
            acc = ad
    nt.links.new(acc.outputs[0], em.inputs['Color'])
    bake_img = bpy.data.images.new(name + '_texture', TEX, TEX, alpha=False)
    bt = nt.nodes.new('ShaderNodeTexImage'); bt.image = bake_img
    nt.nodes.active = bt
    mesh.materials.append(mat)
    sc_ = bpy.context.scene
    sc_.render.engine = 'CYCLES'
    sc_.cycles.device = 'CPU'
    sc_.cycles.samples = 1
    sc_.render.bake.margin = 16
    sc_.render.bake.use_selected_to_active = False
    if os.environ.get('DBG') == 'const':
        nt.links.remove(em.inputs['Color'].links[0]); em.inputs['Color'].default_value = (0, 1, 0, 1)
    if os.environ.get('DBG') == 'w':
        nt.links.remove(em.inputs['Color'].links[0]); nt.links.new(attr.outputs['Color'], em.inputs['Color'])
    bpy.ops.object.bake(type='EMIT', margin=16)
    print('bake mean', np.array(bake_img.pixels[:]).reshape(-1, 4).mean(0))
    tex_path = f'{OUT}/{name}_texture.png'
    bake_img.filepath_raw = tex_path; bake_img.file_format = 'PNG'; bake_img.save()
    print(name, 'baked', f'{time.time() - t0:.1f}s')

    # final material
    mesh.materials.clear()
    for v in order:
        mesh.uv_layers.remove(mesh.uv_layers['P_' + v])
    mesh.color_attributes.remove(mesh.color_attributes['ViewW'])
    fm = bpy.data.materials.new(name + '_Mat'); fm.use_nodes = True
    bsdf = fm.node_tree.nodes['Principled BSDF']
    ft = fm.node_tree.nodes.new('ShaderNodeTexImage')
    ft.image = bpy.data.images.load(tex_path)
    fm.node_tree.links.new(ft.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.85
    mesh.materials.append(fm)

    # ---------------- armature
    def b3(p):
        dz = p[2] if len(p) > 2 else 0
        z = V.zmid(p[0], p[1]) - dz
        return Vector(((p[0] - cx) * k, -z * k, (ground - p[1]) * k))

    arm = bpy.data.armatures.new(name + '_Rig')
    rig = bpy.data.objects.new(name + '_Rig', arm)
    sc_.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    root = arm.edit_bones.new('Root')
    root.head = Vector((0, 0, 0)); root.tail = Vector((0, 0, 0.12 * cfg['height']))
    eb = {'Root': root}
    # keep chains straight: a bone head reuses its parent's tail when they share a 2D point
    pos = {}
    for (bn, par, h, t, grp) in cfg['bones']:
        b = arm.edit_bones.new(bn)
        hh = b3(h)
        if par in eb and par != 'Root' and abs(eb[par].tail.x - hh.x) < 1e-4 and abs(eb[par].tail.z - hh.z) < 1e-4:
            hh = eb[par].tail.copy()
        b.head, b.tail = hh, b3(t)
        if (b.tail - b.head).length < 1e-4:
            b.tail = b.head + Vector((0, -0.03, 0))
        b.parent = eb[par]
        if (eb[par].tail - b.head).length < 1e-5:
            b.use_connect = True
        eb[bn] = b
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.bones['Root'].use_deform = False

    # ---------------- weights (front projection + front/back side for skirt)
    im_front = V.img['On']
    Vxy = Pf[:, :2]
    sign = Pf[:, 2]
    cfg['_head_zc'] = V.zmid(cx, [bb for bb in cfg['bones'] if bb[0] == 'Head'][0][2][1] - 120)
    names, order_b, W4 = compute_weights(im_front, V.mask['On'], Vxy, sign, cfg)
    vgs = {bn: obj.vertex_groups.new(name=bn) for bn in names}
    for i in range(nv):
        for j in range(4):
            if W4[i, j] > 0:
                vgs[names[order_b[i, j]]].add([i], float(W4[i, j]), 'REPLACE')
    obj.parent = rig
    am = obj.modifiers.new('Armature', 'ARMATURE'); am.object = rig
    make_animations(rig, cfg)
    print(name, 'rigged', f'{time.time() - t0:.1f}s')
    return obj, rig


def export(name, rig, obj, OUT):
    bpy.ops.object.select_all(action='DESELECT')
    for im in list(bpy.data.images):
        if im.name.startswith(name + '_') and not im.name.startswith(name + '_texture'):
            bpy.data.images.remove(im)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    rig.select_set(True); obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/{name}.blend')
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/{name}.glb', export_format='GLB',
                              use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_skins=True, export_yup=True)
    bpy.ops.export_scene.fbx(filepath=f'{OUT}/{name}.fbx', use_selection=True,
                             add_leaf_bones=False, bake_anim=True,
                             bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False,
                             path_mode='COPY', embed_textures=True)


if __name__ == '__main__':
    IN, OUT = sys.argv[1], sys.argv[2]
    os.makedirs(OUT, exist_ok=True)
    for name in (sys.argv[3:] or list(CHARS)):
        obj, rig = build(name, IN, OUT)
        export(name, rig, obj, OUT)
        print('DONE', name, len(obj.data.vertices), 'verts', len(obj.data.polygons), 'faces',
              len(rig.data.bones), 'bones', len(bpy.data.actions), 'actions')
