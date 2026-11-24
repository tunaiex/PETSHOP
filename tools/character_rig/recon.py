"""3D reconstruction from 4 orthographic-ish views (On / Sag / Arka / Sol).

Coordinates (all in FRONT-image pixel units):
  X = x - cx   (+X = image right = character's LEFT)
  Yup = ground - y
  Z = towards the viewer of the front image (+Z = character's front)
"""
import numpy as np, cv2
from scipy import ndimage as ndi
from skimage import measure
from prep import load, silhouette, bleed


def bbox_rows(m):
    ys = np.where(m.any(1))[0]
    return ys.min(), ys.max()


def row_extent(m):
    """per row (left, right) of silhouette, NaN where empty; smoothed."""
    H = m.shape[0]
    L = np.full(H, np.nan); R = np.full(H, np.nan)
    for y in range(H):
        xs = np.where(m[y])[0]
        if len(xs):
            L[y], R[y] = xs[0], xs[-1]
    ok = ~np.isnan(L)
    idx = np.arange(H)
    L = np.interp(idx, idx[ok], L[ok]); R = np.interp(idx, idx[ok], R[ok])
    L = ndi.median_filter(L, 9); R = ndi.median_filter(R, 9)
    return L, R


class Views:
    def __init__(self, folder, cfg):
        self.cfg = cfg
        self.img = {}
        self.mask = {}
        for v in ('On', 'Sag', 'Arka', 'Sol'):
            im = load(f'{folder}/{v}.png')
            m = silhouette(im)
            self.img[v] = np.dstack([bleed(im, m, iters=120), np.where(m, 255, 0).astype(np.uint8)])
            self.mask[v] = m
        self.H, self.W = self.mask['On'].shape
        self.top, self.ground = bbox_rows(self.mask['On'])
        self.cx = cfg['cx']
        # vertical alignment of every view onto the front
        self.vmap = {}
        for v in self.mask:
            t, b = bbox_rows(self.mask[v])
            s = (b - t) / (self.ground - self.top)  # view px per front px
            self.vmap[v] = (t, s)
        # side centre: legs (bottom 25%) centred at Z=0 in the right view
        self.uc = {}
        for v in ('Sag', 'Sol'):
            m = self.mask[v]
            t, s = self.vmap[v]
            b = bbox_rows(m)[1]
            rows = m[int(b - 0.25 * (b - t)):int(b - 0.08 * (b - t))]
            self.uc[v] = np.where(rows.any(0))[0].mean()
        # per-row extents (in each view's own pixel rows)
        self.ext = {v: row_extent(self.mask[v]) for v in self.mask}
        # dense silhouette registration: front <- mirrored back, right <- mirrored left
        self.flow = {'Arka': self._flow(self.mask['On'], self.mask['Arka'][:, ::-1], self._arm_init()),
                     'Sol': self._flow(self.mask['Sag'], self.mask['Sol'][:, ::-1])}

    @staticmethod
    def _band(m):
        L, R = row_extent(m)
        w = R - L
        rows = np.where(w > 0.7 * w.max())[0]
        yc = rows.mean()
        ys = np.where(m.any(1))[0]
        b = ys.max()
        cxl = np.where(m[int(b - 0.12 * (b - ys.min()))])[0].mean()  # legs centre
        return yc, cxl, L[rows].min(), R[rows].max()

    def _arm_init(self):
        a = self.mask['On']; bm = self.mask['Arka'][:, ::-1]
        yf, cf, lf, rf = self._band(a)
        yb, cb, lb, rb = self._band(bm)
        H, W = a.shape
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        sx = np.where(xx < cf, (cb - lb) / max(cf - lf, 1), (rb - cb) / max(rf - cf, 1))
        xt = cb + (xx - cf) * sx
        g = 1 / (1 + np.exp(-(np.abs(xx - cf) - self.cfg['arm_start']) / 25))
        fl = np.zeros((H, W, 2), np.float32)
        fl[..., 0] = (cb - cf) * (1 - g) + (xt - xx) * g
        fl[..., 1] = (yb - yf) * g
        return fl

    @staticmethod
    def _sdf(m):
        d = ndi.distance_transform_edt(m) - ndi.distance_transform_edt(~m)
        return np.clip(d, -80, 80)

    def _flow(self, a, b, init=None):
        fa = self._sdf(a); fb = self._sdf(b)
        ia = ((fa + 80) / 160 * 255).astype(np.uint8)
        ib = ((fb + 80) / 160 * 255).astype(np.uint8)
        # pad b to a's shape
        H = max(ia.shape[0], ib.shape[0]); W = max(ia.shape[1], ib.shape[1])
        pa = np.zeros((H, W), np.uint8); pa[:ia.shape[0], :ia.shape[1]] = ia
        pb = np.zeros((H, W), np.uint8); pb[:ib.shape[0], :ib.shape[1]] = ib
        Hh, Ww = pa.shape
        yy, xx = np.mgrid[0:Hh, 0:Ww].astype(np.float32)
        fl = np.zeros((Hh, Ww, 2), np.float32)
        if init is not None:
            fl[:init.shape[0], :init.shape[1]] = init
        for win, sig in ((151, 12), (61, 6), (31, 4)):
            wb = cv2.remap(pb, xx + fl[..., 0], yy + fl[..., 1], cv2.INTER_LINEAR, borderValue=0)
            d = cv2.calcOpticalFlowFarneback(pa, wb, None, 0.5, 7, win, 10, 7, 1.5, cv2.OPTFLOW_FARNEBACK_GAUSSIAN)
            d[..., 0] = cv2.GaussianBlur(d[..., 0], (0, 0), sig)
            d[..., 1] = cv2.GaussianBlur(d[..., 1], (0, 0), sig)
            # compose: new(x) = d(x) + fl(x + d(x))
            fx = cv2.remap(fl[..., 0], xx + d[..., 0], yy + d[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            fy = cv2.remap(fl[..., 1], xx + d[..., 0], yy + d[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            fl = np.dstack([d[..., 0] + fx, d[..., 1] + fy])
        return fl

    def warp_pts(self, key, u, v, Wsrc):
        fl = self.flow[key]
        fx = ndi.map_coordinates(fl[..., 0], [v, u], order=1, mode='nearest')
        fy = ndi.map_coordinates(fl[..., 1], [v, u], order=1, mode='nearest')
        um = u + fx; vm = v + fy
        return Wsrc - 1 - um, vm

    # front-row -> view-row
    def vrow(self, v, y):
        t, s = self.vmap[v]
        return t + (np.asarray(y, float) - self.top) * s

    def side_mask_front_coords(self, ds):
        """Right-view silhouette resampled to (y, z) grid in front px units."""
        t, s = self.vmap['Sag']
        m = self.mask['Sag'].astype(np.float32)
        Hs, Ws = m.shape
        zr = (Ws / s)
        zmin = -(self.uc['Sag']) / s
        zmax = (Ws - self.uc['Sag']) / s
        ys = np.arange(0, self.H, ds)
        zs = np.arange(zmin, zmax, ds)
        yy, zz = np.meshgrid(ys, zs, indexing='ij')
        vy = self.vrow('Sag', yy)
        vu = self.uc['Sag'] + zz * s  # +Z (front) -> image right in the right view
        out = ndi.map_coordinates(m, [vy, vu], order=1) > 0.5
        return ys, zs, out

    def build_volume(self, ds=4):
        cfg = self.cfg
        front = self.mask['On']
        ys, zs, side = self.side_mask_front_coords(ds)
        xs = np.arange(0, self.W, ds)
        F = front[np.ix_(ys, xs)]                      # (Y, X)
        vol = F[:, :, None] & side[:, None, :]          # (Y, X, Z)
        # rounded cross-sections: depth profile shape from the front silhouette,
        # depth extent/centre per row from the side silhouette
        d = ndi.distance_transform_edt(front).astype(np.float32)
        Rl = cv2.GaussianBlur(ndi.maximum_filter(d, size=41), (0, 0), 12)
        Rl = np.maximum(Rl, d + 1e-3)
        h = np.sqrt(np.clip(2 * Rl * d - d * d, 0, None))
        h = cv2.GaussianBlur(h, (0, 0), 3)[np.ix_(ys, xs)]
        hmax = ndi.maximum_filter1d(h.max(1), 9) + 1e-3
        z0 = np.full(len(ys), np.nan); z1 = np.full(len(ys), np.nan)
        for i in range(len(ys)):
            occ = np.where(side[i])[0]
            if len(occ):
                z0[i], z1[i] = zs[occ[0]], zs[occ[-1]]
        ok = ~np.isnan(z0); idx = np.arange(len(ys))
        z0 = ndi.median_filter(np.interp(idx, idx[ok], z0[ok]), 5)
        z1 = ndi.median_filter(np.interp(idx, idx[ok], z1[ok]), 5)
        zc = (z0 + z1) / 2; hz = (z1 - z0) / 2
        prof = np.clip(h / hmax[:, None], 0, 1) ** self.cfg.get('profile_pow', 0.9)
        # thin parts (arms) keep a round tube: never thinner than the front width suggests
        half = np.maximum(hz[:, None] * prof, np.minimum(h * 0.95, hz[:, None]))
        tube = np.abs(zs[None, None, :] - zc[:, None, None]) <= half[:, :, None]
        vol &= tube
        self.grid = (ys, xs, zs)
        self.vol = vol
        return vol

    def surface(self):
        ys, xs, zs = self.grid
        v = ndi.gaussian_filter(self.vol.astype(np.float32), 1.0)
        v = np.pad(v, 2)
        verts, faces, normals, _ = measure.marching_cubes(v, 0.5)
        verts -= 2
        ds = xs[1] - xs[0]
        y = ys[0] + verts[:, 0] * ds
        x = xs[0] + verts[:, 1] * ds
        z = zs[0] + verts[:, 2] * ds
        return np.stack([x, y, z], 1), faces

    # -------------------------------------------- depth maps for visibility
    def depth_maps(self):
        ys, xs, zs = self.grid
        vol = self.vol
        big = 1e9
        anyz = vol.any(2)
        zi_max = np.where(anyz, vol.shape[2] - 1 - np.argmax(vol[:, :, ::-1], 2), 0)
        zi_min = np.where(anyz, np.argmax(vol, 2), 0)
        anyx = vol.any(1)
        xi_min = np.where(anyx, np.argmax(vol, 1), 0)
        xi_max = np.where(anyx, vol.shape[1] - 1 - np.argmax(vol[:, ::-1, :], 1), 0)
        self.dm = dict(
            front=np.where(anyz, zs[zi_max], -big), back=np.where(anyz, zs[zi_min], big),
            right=np.where(anyx, xs[xi_min], big), left=np.where(anyx, xs[xi_max], -big))

    def visibility(self, P, tol=10.0):
        ys, xs, zs = self.grid
        ds = xs[1] - xs[0]
        iy = np.clip(np.round((P[:, 1] - ys[0]) / ds).astype(int), 0, len(ys) - 1)
        ix = np.clip(np.round((P[:, 0] - xs[0]) / ds).astype(int), 0, len(xs) - 1)
        iz = np.clip(np.round((P[:, 2] - zs[0]) / ds).astype(int), 0, len(zs) - 1)
        g = lambda a, i, j: np.maximum.reduce([a[np.clip(i + di, 0, a.shape[0] - 1), np.clip(j + dj, 0, a.shape[1] - 1)] for di in (-1, 0, 1) for dj in (-1, 0, 1)])
        gmin = lambda a, i, j: np.minimum.reduce([a[np.clip(i + di, 0, a.shape[0] - 1), np.clip(j + dj, 0, a.shape[1] - 1)] for di in (-1, 0, 1) for dj in (-1, 0, 1)])
        vf = P[:, 2] >= gmin(self.dm['front'], iy, ix) - tol
        vb = P[:, 2] <= g(self.dm['back'], iy, ix) + tol
        vr = P[:, 0] <= g(self.dm['right'], iy, iz) + tol
        vl = P[:, 0] >= gmin(self.dm['left'], iy, iz) - tol
        return dict(On=vf, Arka=vb, Sag=vr, Sol=vl)

    # -------------------------------------------- projection into each view (pixel coords)
    def project(self, P):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        out = {'On': np.stack([x, y], 1)}
        yi = np.clip(np.round(y).astype(int), 0, self.H - 1)
        fL, fR = self.ext['On']
        ub, vb = self.warp_pts('Arka', x, y, self.mask['Arka'].shape[1])
        out['Arka'] = np.stack([ub, vb], 1)
        t_, s = self.vmap['Sag']
        vyR = self.vrow('Sag', y)
        uR = self.uc['Sag'] + z * s
        out['Sag'] = np.stack([uR, vyR], 1)
        ul, vl = self.warp_pts('Sol', uR, vyR, self.mask['Sol'].shape[1])
        out['Sol'] = np.stack([ul, vl], 1)
        return out

    def zmid(self, x, y):
        ys, xs, zs = self.grid
        ds = xs[1] - xs[0]
        iy = int(np.clip(round((y - ys[0]) / ds), 0, len(ys) - 1))
        ix = int(np.clip(round((x - xs[0]) / ds), 0, len(xs) - 1))
        for r in range(0, 12):
            occ = np.where(self.vol[max(iy - r, 0):iy + r + 1, max(ix - r, 0):ix + r + 1].any((0, 1)))[0]
            if len(occ):
                return (zs[occ].min() + zs[occ].max()) / 2
        return 0.0
