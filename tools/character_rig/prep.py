"""Build silhouette mask, inflated mesh, back texture, atlas, and skin weights."""
import numpy as np, cv2, triangle
from PIL import Image
from scipy import ndimage as ndi
from skimage.graph import MCP_Geometric
from skimage import measure


def load(path):
    im = np.array(Image.open(path).convert('RGBA'))
    return im


def silhouette(im):
    a = im[..., 3] > 128
    a = ndi.binary_opening(a, iterations=2)
    lab, n = ndi.label(a)
    sizes = ndi.sum(a, lab, range(1, n + 1))
    m = lab == (np.argmax(sizes) + 1)
    m = ndi.binary_fill_holes(m)
    m = ndi.binary_closing(m, iterations=2)
    m = ndi.binary_fill_holes(m)
    return m


def ell_mask(shape, ell, soft=0.0):
    H, W = shape
    cx, cy, rx, ry = ell
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    if soft <= 0:
        return (r <= 1).astype(np.float32)
    return np.clip((1 + soft - r) / soft, 0, 1).astype(np.float32)


def color_mask(im, kind):
    rgb = im[..., :3].astype(np.uint8)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    h, s, v = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    if kind == 'hair':     # brown
        m = (h >= 8) & (h <= 40) & (s > 0.35) & (v < 0.85)
    elif kind == 'hairgray':
        m = (s < 0.25) & (v > 0.35)
    elif kind == 'hat':    # red cone or white fur
        m = (((h < 15) | (h > 340)) & (s > 0.45)) | ((s < 0.2) & (v > 0.7))
    else:
        m = np.ones(h.shape, bool)
    m = ndi.binary_closing(m, iterations=3)
    m = ndi.binary_opening(m, iterations=1)
    return m.astype(np.float32)


# ------------------------------------------------------------------ back texture
def synth_tile(src_img, src_rect, shape, seed=0):
    """Tile a source patch over the whole canvas with random flips + offsets."""
    x, y, w, h = src_rect
    patch = src_img[y:y + h, x:x + w, :3].astype(np.float32)
    H, W = shape
    out = np.zeros((H, W, 3), np.float32)
    acc = np.zeros((H, W, 1), np.float32)
    rng = np.random.default_rng(seed)
    win = np.outer(np.hanning(h + 2)[1:-1], np.hanning(w + 2)[1:-1])[..., None] + 1e-3
    for ty in range(-h, H + h, h // 2):
        for tx in range(-w, W + w, w // 2):
            p = patch
            if rng.random() < 0.5:
                p = p[:, ::-1]
            if rng.random() < 0.3:
                p = p[::-1]
            ox, oy = tx + rng.integers(-w // 4, w // 4 + 1), ty + rng.integers(-h // 4, h // 4 + 1)
            x0, y0, x1, y1 = max(ox, 0), max(oy, 0), min(ox + w, W), min(oy + h, H)
            if x1 <= x0 or y1 <= y0:
                continue
            sp = p[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
            sw = win[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
            out[y0:y1, x0:x1] += sp * sw
            acc[y0:y1, x0:x1] += sw
    return out / np.maximum(acc, 1e-6)


def hat_mask(im):
    rgb = im[..., :3].astype(np.uint8)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    h, s, v = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    red = (((h < 12) | (h > 345)) & (s > 0.55) & (v > 0.35) & (im[..., 3] > 200))
    red = ndi.binary_opening(red, iterations=2)
    white = (s < 0.18) & (v > 0.8)
    near = ndi.binary_dilation(red, iterations=45)
    m = red | (white & near)
    m = ndi.binary_closing(m, iterations=4)
    lab, n = ndi.label(m)
    if n:
        sizes = ndi.sum(m, lab, range(1, n + 1))
        keep = np.isin(lab, 1 + np.where(sizes > 8000)[0])
        m = ndi.binary_fill_holes(keep)
    return m.astype(np.float32)


def make_back(im, mask, cfg):
    H, W = mask.shape
    im = np.dstack([bleed(im, im[..., 3] > 200, iters=40), im[..., 3]])
    back = im[..., :3].astype(np.float32).copy()
    for (dx, dy, w, h, sx, sy) in cfg['back'].get('patches', []):
        src = im[sy:sy + h, sx:sx + w, :3].astype(np.float32)
        a = np.zeros((h, w), np.float32)
        a[:] = 1
        a = cv2.GaussianBlur(a, (0, 0), 1)
        feather = np.ones((h, w), np.float32)
        f = 8
        ramp_x = np.clip(np.minimum(np.arange(w), np.arange(w)[::-1]) / f, 0, 1)
        ramp_y = np.clip(np.minimum(np.arange(h), np.arange(h)[::-1]) / f, 0, 1)
        feather = np.outer(ramp_y, ramp_x)[..., None]
        back[dy:dy + h, dx:dx + w] = back[dy:dy + h, dx:dx + w] * (1 - feather) + src * feather
    for i, (rx, ry, rw, rh, src) in enumerate(cfg['back'].get('fills', [])):
        tile = synth_tile(im, src, (H, W), seed=10 + i)
        m = np.zeros((H, W), np.float32); m[ry:ry + rh, rx:rx + rw] = 1
        m = cv2.GaussianBlur(m, (0, 0), 4)
        back = back * (1 - m[..., None]) + tile * m[..., None]
    for i, hf in enumerate(cfg['back'].get('hair_fill', [])):
        tile = synth_tile(im, hf['src'], (H, W), seed=i + 1)
        m = ell_mask((H, W), hf['ell'], soft=0.15)
        if 'ymin' in hf:
            m[:hf['ymin']] = 0
            m = cv2.GaussianBlur(m, (0, 0), 6)
        # keep hat in front of the hair on the back side too
        hat = hat_mask(im)
        m = m * (1 - cv2.GaussianBlur(hat, (0, 0), 2))
        # light vertical shading so the hair has volume
        cx, cy, rx, ry = hf['ell']
        shade = 1.0 - 0.18 * np.clip((np.arange(H)[:, None] - (cy - ry)) / (2 * ry), 0, 1)
        tile = tile * shade[..., None]
        back = back * (1 - m[..., None]) + tile * m[..., None]
    out = np.dstack([np.clip(back, 0, 255).astype(np.uint8), im[..., 3]])
    return out


def bleed(rgba, mask, iters=24):
    """Extend colours outward past the silhouette so UV edges never sample black."""
    rgb = rgba[..., :3].astype(np.float32)
    m = mask.astype(np.float32)
    for _ in range(iters):
        k = np.ones((3, 3), np.float32)
        s = cv2.filter2D(rgb * m[..., None], -1, k)
        c = cv2.filter2D(m, -1, k)
        grow = (c > 0) & (m == 0)
        rgb[grow] = s[grow] / c[grow][..., None]
        m = np.where(grow, 1.0, m)
    return np.clip(rgb, 0, 255).astype(np.uint8)


# ------------------------------------------------------------------ mesh
def build_mesh(mask, step=9, depth_scale=0.82):
    H, W = mask.shape
    pad = np.pad(mask, 1)
    contours = measure.find_contours(pad.astype(float), 0.5)
    c = max(contours, key=len) - 1  # (row, col)
    c = measure.approximate_polygon(c, tolerance=0.8)
    # resample to ~step spacing
    pts = []
    for i in range(len(c) - 1):
        a, b = c[i], c[i + 1]
        L = np.linalg.norm(b - a)
        n = max(1, int(np.ceil(L / (step * 0.75))))
        for t in range(n):
            pts.append(a + (b - a) * t / n)
    pts = np.array(pts)[:, ::-1]  # x, y
    n = len(pts)
    segs = np.stack([np.arange(n), (np.arange(n) + 1) % n], 1)
    tri = triangle.triangulate(dict(vertices=pts, segments=segs), f'pq28a{step * step * 0.55:.1f}')
    V, F = tri['vertices'], tri['triangles']
    # boundary vertices = those on segments
    onb = np.zeros(len(V), bool)
    onb[np.unique(tri['segments'])] = True

    # inflation: circular profile using local radius
    d = ndi.distance_transform_edt(mask).astype(np.float32)
    R = ndi.maximum_filter(d, size=41)
    R = cv2.GaussianBlur(R, (0, 0), 12)
    R = np.maximum(R, d + 1e-3)
    z = np.sqrt(np.clip(2 * R * d - d * d, 0, None)) * depth_scale
    z = cv2.GaussianBlur(z, (0, 0), 2.0)
    xi = np.clip(V[:, 0].round().astype(int), 0, W - 1)
    yi = np.clip(V[:, 1].round().astype(int), 0, H - 1)
    zv = ndi.map_coordinates(z, [V[:, 1], V[:, 0]], order=1)
    zv[onb] = 0
    return V, F, onb, zv


# ------------------------------------------------------------------ weights
def seg_points(a, b, n=24):
    a, b = np.array(a[:2], float), np.array(b[:2], float)
    t = np.linspace(0, 1, n)[:, None]
    return a + (b - a) * t


def geodesic_maps(mask, bones, ds=4):
    m = mask[::ds, ::ds]
    m = ndi.binary_dilation(m, iterations=1)
    cost = np.where(m, 1.0, 1e3)
    maps = {}
    for (name, parent, h, t, grp) in bones:
        p = seg_points(h, t)
        seeds = np.unique(np.clip((p / ds).round().astype(int), 0, [m.shape[1] - 1, m.shape[0] - 1]), axis=0)
        mcp = MCP_Geometric(cost)
        dist, _ = mcp.find_costs([(s[1], s[0]) for s in seeds])
        maps[name] = dist * ds
    return maps


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def compute_weights(im, mask, V, zv_sign, cfg, ds=4):
    bones = cfg['bones']
    names = [b[0] for b in bones]
    maps = geodesic_maps(mask, bones, ds)
    H, W = mask.shape
    gx = np.clip((V[:, 0] / ds).round().astype(int), 0, maps[names[0]].shape[1] - 1)
    gy = np.clip((V[:, 1] / ds).round().astype(int), 0, maps[names[0]].shape[0] - 1)
    D = np.stack([maps[n][gy, gx] for n in names], 1)  # (V, B)
    D = np.minimum(D, 5e3)

    cx = cfg['cx']
    ax = np.abs(V[:, 0] - cx)
    Wt = 1.0 / (D + 6.0) ** 4

    groups = [b[4] for b in bones]
    acc_bones = [i for i, g in enumerate(groups) if g.startswith('acc:')]
    body = [i for i, g in enumerate(groups) if not g.startswith('acc:')]

    # torso/limb separation
    arm_gate = sigmoid((ax - cfg['arm_start']) / 18.0)
    leg_gate = sigmoid((V[:, 1] - cfg['leg_start']) / 25.0)
    for i, g in enumerate(groups):
        if g.startswith('arm_'):
            Wt[:, i] *= arm_gate + 1e-6
            side = g[-1]
            Wt[:, i] *= ((V[:, 0] > cx) if side == 'L' else (V[:, 0] < cx)) + 1e-6
        elif g.startswith('clav_'):
            side = g[-1]
            Wt[:, i] *= 0.35 * (((V[:, 0] > cx) if side == 'L' else (V[:, 0] < cx)) + 1e-6)
        elif g.startswith('leg_'):
            Wt[:, i] *= leg_gate + 1e-6
            side = g[-1]
            Wt[:, i] *= ((V[:, 0] > cx) if side == 'L' else (V[:, 0] < cx)) * 1.0 + 0.02
        elif g in ('core', 'head'):
            pass
    # Root never deforms anything directly
    Wb = np.zeros_like(Wt)
    Wb[:, body] = Wt[:, body]
    Wb /= Wb.sum(1, keepdims=True) + 1e-12
    # everything above the head base belongs to the head (big chibi heads sit on the shoulders)
    hi = names.index('Head')
    head_y = [b for b in bones if b[0] == 'Head'][0][2][1]
    hw = sigmoid((head_y - V[:, 1]) / 10.0) * (np.abs(V[:, 0] - cx) < cfg['arm_start'] * 2.2)
    Wb *= (1 - hw)[:, None]
    Wb[:, hi] += hw

    # accessory regions blend on top
    regions = cfg['regions']
    final = Wb.copy()
    reg_names = sorted({groups[i][4:] for i in acc_bones})
    for rn in reg_names:
        rc = regions[rn]
        idx = [i for i in acc_bones if groups[i][4:] == rn]
        if rc.get('skirt'):
            continue
        f = ell_mask((H, W), rc['ell'], soft=0.25)
        if 'color' in rc and not rc.get('back'):
            cm = color_mask(im, rc['color'])
            cm = cv2.GaussianBlur(cm, (0, 0), 3)
            f = f * cm
        if 'ymin' in rc:
            f[:rc['ymin']] = 0
            f = cv2.GaussianBlur(f, (0, 0), 6)
        if 'head_core' in cfg and rn not in ('paci', 'bow', 'bun') and not rc.get('back'):
            core = ell_mask((H, W), cfg['head_core'], soft=0.12)
            f = f * (1 - core)
        fv = ndi.map_coordinates(f, [V[:, 1], V[:, 0]], order=1)
        if rc.get('back'):
            fv *= sigmoid((cfg.get('_head_zc', 0.0) - zv_sign) / 12.0)
        if rn in ('belly',):
            fv *= 0.6
        if rn in ('hat',):
            # hat chain: weights within chain by distance; first segment shared with head
            pass
        sub = 1.0 / (D[:, idx] + 6.0) ** 3
        sub /= sub.sum(1, keepdims=True)
        final *= (1 - fv)[:, None]
        final[:, idx] += sub * fv[:, None]

    # skirt
    if 'skirt' in cfg:
        top, bot = cfg['skirt']['top'], cfg['skirt']['bottom']
        yy = V[:, 1]
        inside = sigmoid((yy - top - 15) / 12.0) * sigmoid((bot + 30 - yy) / 6.0)
        inside *= (np.abs(V[:, 0] - cx) < 300)
        # legs only below skirt
        sk = {k: [i for i in acc_bones if groups[i] == 'acc:' + k] for k in ('skirtR', 'skirtL', 'skirtF', 'skirtB')}
        rel = (V[:, 0] - cx) / 200.0
        wl = np.clip(rel, 0, 1) ** 1.5
        wr = np.clip(-rel, 0, 1) ** 1.5
        wc = np.clip(1 - np.abs(rel), 0, 1) ** 1.5
        front = (zv_sign >= 0).astype(float)
        t = np.clip((yy - top) / (bot - top), 0, 1)
        part = np.zeros_like(final)
        for key, wv in (('skirtR', wr), ('skirtL', wl), ('skirtF', wc * front), ('skirtB', wc * (1 - front))):
            a, b = sk[key]
            part[:, a] += wv * (1 - t)
            part[:, b] += wv * t
        hips = names.index('Hips')
        part[:, hips] += 0.35 * (1 - t) ** 2
        part /= part.sum(1, keepdims=True) + 1e-12
        final = final * (1 - inside)[:, None] + part * inside[:, None]

    # keep top 4 influences
    order = np.argsort(-final, 1)[:, :4]
    W4 = np.take_along_axis(final, order, 1)
    W4 = np.where(W4 < 0.01, 0, W4)
    W4 /= W4.sum(1, keepdims=True) + 1e-12
    return names, order, W4
