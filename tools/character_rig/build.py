"""Build rigged, animated 2.5D/3D characters with Blender (bpy) and export GLB + FBX."""
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Quaternion, Vector, Matrix
from PIL import Image
from prep import load, silhouette, make_back, bleed, build_mesh, compute_weights
from chars import CHARS

ATLAS = 2048
FPS = 30


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def make_atlas(front, back, mask):
    H, W = mask.shape
    s = min((ATLAS / 2) / W, ATLAS / H)
    atlas = Image.new('RGB', (ATLAS, ATLAS), (128, 128, 128))
    for i, img in enumerate((front, back)):
        rgb = bleed(img, mask, iters=30)
        pim = Image.fromarray(rgb).resize((int(W * s), int(H * s)), Image.LANCZOS)
        atlas.paste(pim, (i * ATLAS // 2, 0))
    return atlas, s


def build_char(name, cfg):
    reset()
    im = load(f'{IN}/{cfg["file"]}')
    mask = silhouette(im)
    H, W = mask.shape
    back = make_back(im, mask, cfg)
    V, F, onb, zv = build_mesh(mask)
    F = F[~onb[F].all(1)]  # drop zero-volume slivers on the rim
    ys = np.where(mask.any(1))[0]
    top, ground = ys.min(), ys.max()
    k = cfg['height'] / (ground - top)
    cx = cfg['cx']

    def to3(p):  # image px (+dz) -> blender
        dz = p[2] if len(p) > 2 else 0
        return Vector(((p[0] - cx) * k, dz * k, (ground - p[1]) * k))

    # ---------------- mesh (front + back sharing the silhouette rim)
    n = len(V)
    back_idx = np.full(n, -1)
    nb = 0
    for i in range(n):
        if onb[i]:
            back_idx[i] = i
        else:
            back_idx[i] = n + nb
            nb += 1
    coords = np.zeros((n + nb, 3))
    coords[:n, 0] = (V[:, 0] - cx) * k
    coords[:n, 2] = (ground - V[:, 1]) * k
    coords[:n, 1] = -zv * k
    inner = ~onb
    bi = back_idx[inner]
    coords[bi, 0] = (V[inner, 0] - cx) * k
    coords[bi, 2] = (ground - V[inner, 1]) * k
    coords[bi, 1] = zv[inner] * k * 0.92
    faces = [tuple(f) for f in F] + [tuple(back_idx[f][::-1]) for f in F]

    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(coords.tolist(), [], faces)
    mesh.update()
    print('mesh.validate fixed:', mesh.validate(verbose=False))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    atlas, s = make_atlas(im, back, mask)
    atlas_path = f'{OUT}/{name}_texture.png'
    atlas.save(atlas_path)
    uvl = mesh.uv_layers.new(name='UVMap')
    nf = len(F)
    uv = np.zeros((len(faces) * 3, 2))
    for fi in range(len(faces)):
        src = F[fi] if fi < nf else F[fi - nf][::-1]
        off = 0 if fi < nf else 0.5
        for j in range(3):
            vx, vy = V[src[j]]
            uv[fi * 3 + j] = (off + vx * s / ATLAS, 1 - vy * s / ATLAS)
    uvl.data.foreach_set('uv', uv.ravel())
    for p in mesh.polygons:
        p.use_smooth = True

    # recalc outward normals
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh); bm.free()

    mat = bpy.data.materials.new(name + '_Mat')
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(atlas_path)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.85
    mesh.materials.append(mat)

    # ---------------- armature
    arm = bpy.data.armatures.new(name + '_Rig')
    rig = bpy.data.objects.new(name + '_Rig', arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    root = arm.edit_bones.new('Root')
    root.head = Vector((0, 0, 0)); root.tail = Vector((0, 0, 0.12 * cfg['height']))
    eb = {'Root': root}
    for (bn, par, h, t, grp) in cfg['bones']:
        b = arm.edit_bones.new(bn)
        b.head, b.tail = to3(h), to3(t)
        if (b.tail - b.head).length < 1e-4:
            b.tail = b.head + Vector((0, -0.03, 0))
        b.parent = eb[par]
        if (eb[par].tail - b.head).length < 1e-5:
            b.use_connect = True
        eb[bn] = b
    root_bone = arm.edit_bones['Root']
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.bones['Root'].use_deform = False

    # ---------------- skin weights
    Vall = np.concatenate([V, V])
    sign = np.concatenate([np.ones(n), -np.ones(n)])
    names, order, W4 = compute_weights(im, mask, Vall, sign, cfg)
    vgs = {bn: obj.vertex_groups.new(name=bn) for bn in names}
    for i in range(n):
        for j in range(4):
            if W4[i, j] > 0:
                vgs[names[order[i, j]]].add([i], float(W4[i, j]), 'REPLACE')
    for i in np.where(inner)[0]:
        vi = int(back_idx[i])
        for j in range(4):
            w = W4[n + i, j]
            if w > 0:
                vgs[names[order[n + i, j]]].add([vi], float(w), 'REPLACE')
    obj.parent = rig
    mod = obj.modifiers.new('Armature', 'ARMATURE')
    mod.object = rig

    make_animations(rig, cfg)
    return obj, rig


# ====================================================================== animations
AX = {'x': Vector((1, 0, 0)), 'y': Vector((0, 1, 0)), 'z': Vector((0, 0, 1))}


def wq(rig, bone, rots):
    """rots: list of (axis, degrees) in armature space -> local quaternion."""
    B = rig.data.bones[bone].matrix_local.to_quaternion()
    q = Quaternion()
    for ax, deg in rots:
        q = Quaternion(AX[ax], math.radians(deg)) @ q
    return B.inverted() @ q @ B


def key_action(rig, name, length, fn, step=2):
    """fn(t in 0..1) -> dict bone -> list[(axis,deg)] ; may include '__loc' for Root."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    bones = set()
    frames = list(range(0, length + 1, step))
    if frames[-1] != length:
        frames.append(length)
    samples = [(f, fn(f / length)) for f in frames]
    for _, p in samples:
        bones |= {b for b in p if b != '__loc'}
    bones = [b for b in bones if b in rig.pose.bones]
    for f, p in samples:
        for b in bones:
            pb = rig.pose.bones[b]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = wq(rig, b, p.get(b, []))
            pb.keyframe_insert('rotation_quaternion', frame=f)
        rp = rig.pose.bones['Root']
        rp.location = Vector(p.get('__loc', (0, 0, 0)))
        rp.keyframe_insert('location', frame=f)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    track.mute = True
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion(); pb.location = Vector()


S = lambda t, ph=0.0, c=1.0: math.sin(2 * math.pi * (t * c + ph))


def secondary(p, t, amp=1.0, speed=1.0):
    """Hat / hair / skirt / scarf follow-through."""
    for i in range(1, 5):
        lag = 0.08 * i
        p.setdefault(f'Hat{i}', []).append(('y', 6 * amp * i * S(t, -lag, speed)))
        for side, sg in (('R', -1), ('L', 1)):
            p.setdefault(f'Skirt.{side}{i}', []).append(('y', sg * 3 * amp * S(t, -lag, speed)))
        p.setdefault(f'Skirt.F{i}', []).append(('x', -3 * amp * S(t, -lag, speed)))
        p.setdefault(f'Skirt.B{i}', []).append(('x', 3 * amp * S(t, -lag, speed)))
        p.setdefault(f'Scarf{i}', []).append(('y', 5 * amp * S(t, -lag, speed)))
    p.setdefault('Pompom', []).append(('y', 12 * amp * S(t, -0.4, speed)))
    p.setdefault('HairBun1', []).append(('y', 6 * amp * S(t, -0.2, speed)))
    hair_wave(p, t, amp, speed)
    p.setdefault('Bow', []).append(('y', 5 * amp * S(t, -0.2, speed)))
    return p


def hair_wave(p, t, amp=1.0, speed=1.0):
    """Soft travelling wave down every hair chain (loops seamlessly)."""
    a = 0.6 + 0.5 * amp           # always a little breeze, more when moving
    c = max(1, int(round(speed)))  # whole cycles per clip -> seamless loop
    chains = [('Hair.R', -1, 0.00), ('Hair.L', 1, 0.13), ('HairSide.R', -1, 0.05),
              ('HairSide.L', 1, 0.18), ('HairPuff.R', -1, 0.07), ('HairPuff.L', 1, 0.21),
              ('HairBack', 1, 0.31)]
    for base, sg, ph in chains:
        for i in range(1, 6):
            lag = 0.11 * i  # each segment trails the previous one -> wave travels down
            side = sg * (2.5 + 1.6 * i) * a * S(t, ph - lag, c)
            fwd = (1.5 + 1.2 * i) * a * S(t, ph - lag + 0.25, c)
            curl = 1.2 * i * a * S(t, ph - 2 * lag, 2 * c)  # small secondary ripple
            p.setdefault(f'{base}{i}', []).extend([('y', side + curl), ('x', fwd)])
    return p


def arms_down(p, down=72, fore=10):
    p.setdefault('UpperArm.R', []).append(('y', -down))
    p.setdefault('UpperArm.L', []).append(('y', down))
    p.setdefault('ForeArm.R', []).append(('x', -fore))
    p.setdefault('ForeArm.L', []).append(('x', -fore))
    return p


def make_animations(rig, cfg):
    H = cfg['height']

    def idle(t):
        p = arms_down({})
        p['Spine1'] = [('x', 1.5 * S(t))]
        p['Spine2'] = [('x', 1.5 * S(t, -0.1))]
        p['Head'] = [('y', 3 * S(t, 0.25)), ('x', 1.5 * S(t, -0.2))]
        p['UpperArm.R'].append(('y', 2 * S(t)))
        p['UpperArm.L'].append(('y', -2 * S(t)))
        p['Belly'] = [('x', 2 * S(t))]
        return secondary(p, t, 0.6)

    def happy(t):
        jump = max(0.0, math.sin(2 * math.pi * t * 2))
        p = {}
        p['UpperArm.R'] = [('y', 45 + 15 * jump)]
        p['UpperArm.L'] = [('y', -45 - 15 * jump)]
        p['ForeArm.R'] = [('y', 20 * jump)]
        p['ForeArm.L'] = [('y', -20 * jump)]
        p['Head'] = [('y', 8 * S(t, 0, 2))]
        p['UpperLeg.R'] = [('x', -15 * (1 - jump))]
        p['UpperLeg.L'] = [('x', -15 * (1 - jump))]
        p['LowerLeg.R'] = [('x', 25 * (1 - jump))]
        p['LowerLeg.L'] = [('x', 25 * (1 - jump))]
        p['__loc'] = (0, 0.18 * H * jump, 0)  # Root local Y == world up
        return secondary(p, t, 2.0, 2.0)

    def wave(t):
        p = arms_down({})
        p['UpperArm.L'] = [('y', -50)]
        p['ForeArm.L'] = [('y', -55 + 25 * S(t, 0, 3))]
        p['Hand.L'] = [('y', 15 * S(t, -0.1, 3))]
        p['Head'] = [('y', 8), ('x', -3)]
        p['Spine2'] = [('y', -3)]
        return secondary(p, t, 0.8, 3)

    def sad(t):
        p = arms_down({}, down=82, fore=4)
        p['Head'] = [('x', 22 + 2 * S(t))]
        p['Neck'] = [('x', 8)]
        p['Spine2'] = [('x', 8)]
        p['Shoulder.R'] = [('y', -6)]
        p['Shoulder.L'] = [('y', 6)]
        p['Hat1'] = [('y', -10)]
        return secondary(p, t, 0.3)

    def eat(t):
        p = arms_down({}, down=60, fore=0)
        bite = max(0.0, S(t, 0, 3))
        p['ForeArm.R'] = [('x', -90 * bite - 20), ('z', 30 * bite)]
        p['Head'] = [('x', 12 * bite)]
        p['Belly'] = [('x', 4 * bite)]
        p['Pacifier'] = [('x', 15 * S(t, 0, 6))]
        return secondary(p, t, 0.8, 3)

    def sleep(t):
        p = arms_down({}, down=78, fore=12)
        p['Head'] = [('y', -18), ('x', 14 + 2 * S(t))]
        p['Spine1'] = [('x', 4 + 2 * S(t))]
        p['Spine2'] = [('x', 5)]
        p['Belly'] = [('x', 4 * S(t))]
        p['Hat1'] = [('y', -15)]
        return secondary(p, t, 0.3)

    def walk(t):
        p = arms_down({}, down=75, fore=10)
        sw = S(t)
        p['UpperLeg.R'] = [('x', -25 * sw)]
        p['UpperLeg.L'] = [('x', 25 * sw)]
        p['LowerLeg.R'] = [('x', 30 * max(0, S(t, 0.25)))]
        p['LowerLeg.L'] = [('x', 30 * max(0, S(t, 0.75)))]
        p['UpperArm.R'].append(('x', 20 * sw))
        p['UpperArm.L'].append(('x', -20 * sw))
        p['Hips'] = [('z', 6 * sw)]
        p['Spine2'] = [('z', -8 * sw)]
        p['__loc'] = (0, 0.02 * H * abs(S(t, 0, 2)), 0)
        return secondary(p, t, 1.2, 2)

    def dance(t):
        p = {}
        p['UpperArm.R'] = [('y', 30 * S(t, 0, 2))]
        p['UpperArm.L'] = [('y', 30 * S(t, 0, 2))]
        p['ForeArm.R'] = [('y', -40 + 30 * S(t, 0.2, 2))]
        p['ForeArm.L'] = [('y', 40 + 30 * S(t, 0.2, 2))]
        p['Hips'] = [('y', 8 * S(t, 0, 2)), ('z', 15 * S(t))]
        p['Spine1'] = [('y', -6 * S(t, 0, 2))]
        p['Head'] = [('y', 10 * S(t, 0.25, 2))]
        p['UpperLeg.R'] = [('x', -10 * max(0, S(t, 0, 2)))]
        p['UpperLeg.L'] = [('x', -10 * max(0, S(t, 0.5, 2)))]
        p['__loc'] = (0, 0.03 * H * abs(S(t, 0, 2)), 0)
        return secondary(p, t, 1.5, 2)

    key_action(rig, 'Idle', 90, idle)
    key_action(rig, 'Happy', 40, happy)
    key_action(rig, 'Wave', 60, wave)
    key_action(rig, 'Sad', 90, sad)
    key_action(rig, 'Eat', 60, eat)
    key_action(rig, 'Sleep', 120, sleep)
    key_action(rig, 'Walk', 32, walk)
    key_action(rig, 'Dance', 60, dance)


def export(name, rig, obj, OUT):
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True); obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/{name}.blend')
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/{name}.glb', export_format='GLB',
                              use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_skins=True,
                              export_yup=True, export_apply=False)
    bpy.ops.export_scene.fbx(filepath=f'{OUT}/{name}.fbx', use_selection=True,
                             add_leaf_bones=False, bake_anim=True,
                             bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False,
                             path_mode='COPY', embed_textures=True,
                             armature_nodetype='NULL', primary_bone_axis='Y', secondary_bone_axis='X')


if __name__ == '__main__':
  IN, OUT = sys.argv[1], sys.argv[2]
  os.makedirs(OUT, exist_ok=True)
  for name in (sys.argv[3:] or list(CHARS)):
    obj, rig = build_char(name, CHARS[name])
    export(name, rig, obj, OUT)
    print('DONE', name, len(obj.data.vertices), 'verts', len(obj.data.polygons), 'tris',
          len(rig.data.bones), 'bones', len(bpy.data.actions), 'actions')
