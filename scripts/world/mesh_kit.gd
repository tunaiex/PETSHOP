class_name MeshKit
extends RefCounted
## Prosedürel mesh üretici. Harici model yokken oyunun düzgün görünmesini sağlar.

static var _cache: Dictionary = {}


# ------------------------------------------------------------------ BALIK

## Balık -Z yönüne bakar. Gövde, kuyruk, sırt/karın yüzgeci ve göğüs yüzgeçleri.
static func fish_mesh(id: String) -> ArrayMesh:
	var key := "fish_" + id
	if _cache.has(key):
		return _cache[key]
	var s: Dictionary = FishDB.get_species(id)
	var L: float = s.length
	var H: float = L * float(s.height)
	var W: float = L * float(s.width)
	var body_len: float = L * 0.78
	var z_nose: float = -L * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Gövde: elips kesitli halkalar
	var rings := 20
	var seg := 16
	var base := 0
	for i in rings + 1:
		var t: float = float(i) / rings
		var shape: float = pow(sin(PI * 0.94 * pow(t, 0.8)), 0.72)
		var hh: float = H * 0.5 * shape
		var ww: float = W * 0.5 * shape
		var z: float = z_nose + t * body_len
		var belly: float = H * 0.06 * shape
		for j in seg + 1:
			var a: float = TAU * float(j) / seg - PI * 0.5
			var ca: float = cos(a)
			var sa: float = sin(a)
			var y: float = sa * hh + (belly if sa < 0.0 else 0.0) * sa
			var n := Vector3(ca / max(ww, 0.0001), sa / max(hh, 0.0001), 0.0).normalized()
			if i == 0:
				n = Vector3(0, 0, -1)
			st.set_normal(n)
			st.set_uv(Vector2(t * 0.78, (sa + 1.0) * 0.5))
			st.set_uv2(Vector2(0, 0))
			st.add_vertex(Vector3(ca * ww, y, z))
	for i in rings:
		for j in seg:
			var a0: int = base + i * (seg + 1) + j
			var a1: int = a0 + seg + 1
			st.add_index(a0); st.add_index(a1); st.add_index(a0 + 1)
			st.add_index(a0 + 1); st.add_index(a1); st.add_index(a1 + 1)
	base += (rings + 1) * (seg + 1)

	var z_tail: float = z_nose + body_len
	var hb: float = H * 0.5 * pow(sin(PI * 0.94), 0.72) * 0.9
	var tl: float = L * 0.32 * float(s.tail_size)
	var ht: float = L * 0.24 * float(s.tail_size) + hb
	var tail_type: String = s.tail
	if tail_type == "double":
		base = _tail(st, base, tail_type, z_tail, hb, ht, tl, 0.35)
		base = _tail(st, base, tail_type, z_tail, hb, ht, tl, -0.35)
	else:
		base = _tail(st, base, tail_type, z_tail, hb, ht, tl, 0.0)

	# Sırt yüzgeci
	var dorsal: float = float(s.dorsal)
	base = _fin_strip(st, base, z_nose, body_len, H, 0.28, 0.72, L * 0.11 * dorsal, 1.0)
	# Karın yüzgeci (melek/diskus/beta'da büyük)
	var anal: float = dorsal * (0.75 if H > L * 0.6 or tail_type == "veil" else 0.35)
	base = _fin_strip(st, base, z_nose, body_len, H, 0.5, 0.82, L * 0.11 * anal, -1.0)
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh


static func _tail(st: SurfaceTool, base: int, type: String, z0: float, hb: float, ht: float, tl: float, tilt: float) -> int:
	var rows := 8
	var cols := 10
	for i in rows + 1:
		var sx: float = float(i) / rows
		for j in cols + 1:
			var v: float = float(j) / cols * 2.0 - 1.0
			var length_f: float = 1.0
			var droop: float = 0.0
			match type:
				"fork":
					length_f = 0.5 + 0.5 * pow(abs(v), 1.2)
				"round":
					length_f = 1.0 - 0.3 * v * v
				"veil":
					length_f = 1.0 - 0.15 * v * v
					droop = -0.35 * sx * sx
				"double":
					length_f = 0.85 + 0.15 * abs(v)
				_:
					length_f = 0.8 + 0.2 * abs(v)
			var hh: float = lerp(hb, ht, pow(sx, 0.6))
			var y: float = v * hh + droop * ht
			var z: float = z0 - tl * 0.04 + sx * tl * length_f
			var x: float = y * tilt
			st.set_normal(Vector3(1, 0, 0))
			st.set_uv(Vector2(lerp(0.78, 1.0, sx), (v + 1.0) * 0.5))
			st.set_uv2(Vector2(1, 0))
			st.add_vertex(Vector3(x, y if tilt == 0.0 else y * 0.9, z))
	for i in rows:
		for j in cols:
			var a0: int = base + i * (cols + 1) + j
			var a1: int = a0 + cols + 1
			st.add_index(a0); st.add_index(a1); st.add_index(a0 + 1)
			st.add_index(a0 + 1); st.add_index(a1); st.add_index(a1 + 1)
	return base + (rows + 1) * (cols + 1)


static func _fin_strip(st: SurfaceTool, base: int, z_nose: float, body_len: float, H: float, t0: float, t1: float, fh: float, dir: float) -> int:
	var cols := 10
	var rows := 4
	for i in cols + 1:
		var s: float = float(i) / cols
		var t: float = lerp(t0, t1, s)
		var shape: float = pow(sin(PI * 0.94 * pow(t, 0.8)), 0.72)
		var edge: float = H * 0.5 * shape * 0.92
		var prof: float = pow(sin(PI * clamp(s * 1.1, 0.0, 1.0)), 0.6)
		for j in rows + 1:
			var v: float = float(j) / rows
			var y: float = dir * (edge + v * fh * prof)
			var z: float = z_nose + t * body_len + v * fh * (0.45 + min(fh / max(H, 0.001), 1.5) * 0.6)
			st.set_normal(Vector3(1, 0, 0))
			st.set_uv(Vector2(lerp(0.3, 0.9, s), v))
			st.set_uv2(Vector2(1, 0))
			st.add_vertex(Vector3(0, y, z))
	for i in cols:
		for j in rows:
			var a0: int = base + i * (rows + 1) + j
			var a1: int = a0 + rows + 1
			st.add_index(a0); st.add_index(a1); st.add_index(a0 + 1)
			st.add_index(a0 + 1); st.add_index(a1); st.add_index(a1 + 1)
	return base + (cols + 1) * (rows + 1)


# ------------------------------------------------------------------ BİTKİ

## Uzun şerit yapraklı bitki (vallisneria benzeri) öbeği.
static func grass_clump(sd: int, blades: int, height: float) -> ArrayMesh:
	var key := "grass_%d_%d_%.2f" % [sd, blades, height]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for b in blades:
		var ang: float = rng.randf() * TAU
		var r: float = rng.randf() * 0.025
		var root := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var h: float = height * rng.randf_range(0.6, 1.0)
		var bend := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.03, 0.09)
		var w: float = rng.randf_range(0.006, 0.011)
		var side := Vector3(-sin(ang), 0, cos(ang)).rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var segs := 8
		for i in segs + 1:
			var t: float = float(i) / segs
			var c: Vector3 = root + Vector3(0, t * h, 0) + bend * t * t
			var ww: float = w * (1.0 - t * 0.6)
			for k in 2:
				var sgn: float = -1.0 if k == 0 else 1.0
				st.set_normal(side.cross(Vector3.UP).normalized())
				st.set_uv(Vector2(float(k), t))
				st.add_vertex(c + side * ww * sgn)
		for i in segs:
			var a: int = base + i * 2
			st.add_index(a); st.add_index(a + 2); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(a + 2); st.add_index(a + 3)
		base += (segs + 1) * 2
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh


## Geniş yapraklı rozet bitki (amazon kılıcı benzeri).
static func sword_plant(sd: int, leaves: int, size: float) -> ArrayMesh:
	var key := "sword_%d_%d_%.2f" % [sd, leaves, size]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for l in leaves:
		var ang: float = TAU * float(l) / leaves + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-sin(ang), 0, cos(ang))
		var leaf_len: float = size * rng.randf_range(0.7, 1.0)
		var lift: float = rng.randf_range(0.9, 1.6)
		var segs := 8
		for i in segs + 1:
			var t: float = float(i) / segs
			# yaprak yukarı çıkar ve dışa doğru kıvrılır
			var c: Vector3 = dir * (t * leaf_len * 0.55) + Vector3(0, sin(t * PI * 0.5) * leaf_len * lift * 0.6, 0) - dir * 0.0
			c += dir * t * t * leaf_len * 0.2 - Vector3(0, t * t * leaf_len * 0.15, 0)
			var ww: float = sin(PI * clamp(t * 0.95 + 0.05, 0.0, 1.0)) * leaf_len * 0.16
			var up := Vector3.UP.lerp(dir, t).normalized()
			var n: Vector3 = side.cross(up).normalized()
			for k in 2:
				var sgn: float = -1.0 if k == 0 else 1.0
				st.set_normal(n)
				st.set_uv(Vector2(float(k), t))
				st.add_vertex(c + side * ww * sgn)
		for i in segs:
			var a: int = base + i * 2
			st.add_index(a); st.add_index(a + 2); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(a + 2); st.add_index(a + 3)
		base += (segs + 1) * 2
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh


# ------------------------------------------------------------------ KAYA / KÖK

static func rock(sd: int, size: Vector3) -> ArrayMesh:
	var key := "rock_%d_%s" % [sd, str(size)]
	if _cache.has(key):
		return _cache[key]
	var sphere := SphereMesh.new()
	sphere.radial_segments = 24
	sphere.rings = 12
	sphere.radius = 0.5
	sphere.height = 1.0
	var arrays: Array = sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = sd
	noise.frequency = 2.2
	noise.fractal_octaves = 4
	for i in verts.size():
		var v: Vector3 = verts[i]
		var d: float = 1.0 + noise.get_noise_3dv(v) * 0.45
		v = v * d
		if v.y < -0.15:
			v.y = -0.15 + (v.y + 0.15) * 0.2
		verts[i] = v * size
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(tmp, 0)
	st.deindex()
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh


## Bir yol boyunca konik boru: akvaryum kökü (driftwood) için.
static func tube(points: Array, radii: Array, sides: int = 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = points.size()
	for i in n:
		var p: Vector3 = points[i]
		var fwd: Vector3
		if i < n - 1:
			fwd = (points[i + 1] - p).normalized()
		else:
			fwd = (p - points[i - 1]).normalized()
		var ref := Vector3.UP if abs(fwd.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var right: Vector3 = fwd.cross(ref).normalized()
		var up: Vector3 = right.cross(fwd).normalized()
		for j in sides + 1:
			var a: float = TAU * float(j) / sides
			var dir: Vector3 = right * cos(a) + up * sin(a)
			st.set_normal(dir)
			st.set_uv(Vector2(float(j) / sides, float(i) / (n - 1)))
			st.add_vertex(p + dir * float(radii[i]))
	for i in n - 1:
		for j in sides:
			var a0: int = i * (sides + 1) + j
			var a1: int = a0 + sides + 1
			st.add_index(a0); st.add_index(a0 + 1); st.add_index(a1)
			st.add_index(a0 + 1); st.add_index(a1 + 1); st.add_index(a1)
	return st.commit()


# ------------------------------------------------------------------ YARDIMCI

static func mat(color: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.position = pos
		parent.add_child(body)
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, sides: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	mi.mesh = cm
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func shader_mat(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m
