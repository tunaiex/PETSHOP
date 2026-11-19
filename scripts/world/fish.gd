class_name Fish
extends Node3D

const VISUAL_SCALE := 1.35 ## Küçük balıkların ekranda seçilebilmesi için hafif büyütme
## Tek bir balığın görseli ve hareketi. Veri Game.tanks içindedir; bu sadece görünüş.

var uid: int = 0
var species: String = ""
var aquarium: Node3D
var bounds: AABB              ## Akvaryumun yerel uzayında yüzme alanı
var velocity: Vector3 = Vector3.ZERO
var health: float = 100.0
var alive: bool = true
var sick: float = 0.0
var growth: float = 1.0

var _data: Dictionary
var _target: Vector3
var _retarget: float = 0.0
var _speed: float = 0.05
var _mat: ShaderMaterial
var _visual: Node3D
var _rng := RandomNumberGenerator.new()
var _phase: float = 0.0
var _burst: float = 0.0


func setup(fish_data: Dictionary, aq: Node3D, swim_bounds: AABB) -> void:
	uid = int(fish_data.uid)
	species = fish_data.species
	aquarium = aq
	bounds = swim_bounds
	_data = FishDB.get_species(species)
	_rng.seed = uid * 7919
	_phase = _rng.randf() * TAU
	_speed = float(_data.speed) * float(_data.length) * 1.4 + 0.02
	_build_visual()
	position = _random_point()
	_target = _random_point()
	velocity = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _speed
	apply_state(fish_data)


func _build_visual() -> void:
	var model: Dictionary = _model_template(species)
	if not model.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = model.mesh
		mi.transform = model.xf
		_mat = model.mat.duplicate()
		_mat.set_shader_parameter("phase", _phase)
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_visual = mi
		return
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.fish_mesh(species)
	_mat = MeshKit.shader_mat("res://shaders/fish.gdshader", {
		"body_color": _data.body, "belly_color": _data.belly, "accent_color": _data.accent,
		"fin_color": _data.fin, "fin_alpha": _data.fin_alpha, "pattern": _data.pattern,
		"fish_len": _data.length, "phase": _phase,
	})
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_visual = mi


static var _templates: Dictionary = {}

## Gerçek modeli bir kez yükler: mesh, yönlendirme/ölçek dönüşümü ve yüzme materyali.
## Model, burnu -Z'ye bakacak ve boyu tür uzunluğuna eşit olacak şekilde yerleştirilir.
static func _model_template(sp: String) -> Dictionary:
	if _templates.has(sp):
		return _templates[sp]
	var path: String = FishDB.model_path(sp)
	if path == "":
		_templates[sp] = {}
		return {}
	var data: Dictionary = FishDB.get_species(sp)
	var root: Node3D = (load(path) as PackedScene).instantiate()
	var src: MeshInstance3D = null
	for c in root.find_children("*", "MeshInstance3D", true, false):
		src = c
		break
	if src == null:
		root.free()
		_templates[sp] = {}
		return {}
	# Mesh'in sahne köküne göre dönüşümü
	var rel := Transform3D.IDENTITY
	var cur: Node = src
	while cur != root and cur != null:
		if cur is Node3D:
			rel = (cur as Node3D).transform * rel
		cur = cur.get_parent()
	var mesh: Mesh = src.mesh
	var src_mat: Material = src.get_active_material(0)
	root.free()
	var fwd: Vector3 = data.model_fwd
	# Modelin baş yönünü -Z'ye çeviren dönüş
	var orient := Basis.IDENTITY
	if fwd.is_equal_approx(Vector3(0, 0, 1)):
		orient = Basis(Vector3.UP, PI)
	elif fwd.is_equal_approx(Vector3(1, 0, 0)):
		orient = Basis(Vector3.UP, PI * 0.5)
	elif fwd.is_equal_approx(Vector3(-1, 0, 0)):
		orient = Basis(Vector3.UP, -PI * 0.5)
	var aabb: AABB = rel * mesh.get_aabb()
	var along: float = abs(aabb.size.dot(fwd.abs()))
	var k: float = float(data.length) / max(along, 0.0001)
	var xf := Transform3D(orient.scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -aabb.get_center()) * rel
	# Shader için eksenler mesh uzayında
	var inv: Basis = rel.basis.inverse()
	var tail_mesh: Vector3 = (inv * -fwd).normalized()
	var side_model: Vector3 = Vector3.UP.cross(fwd).normalized()
	var side_mesh: Vector3 = (inv * side_model).normalized()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fish_tex.gdshader")
	var tex: Texture2D = null
	var col := Color.WHITE
	var rough := 0.45
	if src_mat is BaseMaterial3D:
		tex = (src_mat as BaseMaterial3D).albedo_texture
		col = (src_mat as BaseMaterial3D).albedo_color
		rough = clamp((src_mat as BaseMaterial3D).roughness, 0.25, 0.8)
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("has_tex", tex != null)
	mat.set_shader_parameter("albedo_color", col)
	mat.set_shader_parameter("roughness", rough)
	mat.set_shader_parameter("tail_axis", tail_mesh)
	mat.set_shader_parameter("side_axis", side_mesh)
	mat.set_shader_parameter("center", mesh.get_aabb().get_center())
	mat.set_shader_parameter("half_len", along * 0.5 / max(rel.basis.get_scale().x, 0.0001))
	mat.set_shader_parameter("upright", 1.0 if data.upright else 0.0)
	var t := {"mesh": mesh, "xf": xf, "mat": mat}
	_templates[sp] = t
	return t


func apply_state(fish_data: Dictionary) -> void:
	if _mat:
		_mat.set_shader_parameter("rare", 1.0 if fish_data.get("rare", false) else 0.0)
	health = float(fish_data.health)
	alive = bool(fish_data.alive)
	growth = float(fish_data.get("growth", 1.0))
	var sc: float = lerp(0.45, 1.0, clamp(growth, 0.0, 1.0)) * VISUAL_SCALE
	if _visual:
		scale = Vector3.ONE * sc


## Cama vurulunca ürküp arkaya kaçar
func scare() -> void:
	if _burst > 0.2 or not alive:
		return
	_burst = 0.8
	_target = Vector3(_lo().x + _rng.randf() * (_hi().x - _lo().x), _lo().y + _rng.randf() * (_hi().y - _lo().y) * 0.5, _lo().z)
	_retarget = 2.0


func set_sick(level: float) -> void:
	sick = level
	if _mat:
		_mat.set_shader_parameter("sick", level)


## Balığın "kişisel alan" yarıçapı (boyuna göre)
func radius() -> float:
	return float(_data.length) * scale.x * 0.45


func _margin() -> Vector3:
	var half: float = float(_data.length) * scale.x * 0.5
	var m := Vector3(half, half * 0.5, half) + Vector3.ONE * 0.04
	return m.min(bounds.size * 0.45)


func _lo() -> Vector3:
	return bounds.position + _margin()


func _hi() -> Vector3:
	return bounds.end - _margin()


func _random_point() -> Vector3:
	var p := _lo()
	var s := _hi() - _lo()
	var y_bias: float = _rng.randf()
	# Sürü balıkları ortada, diğerleri her yerde
	if float(_data.schooling) > 0.7:
		y_bias = _rng.randf_range(0.3, 0.8)
	return Vector3(p.x + _rng.randf() * s.x, p.y + y_bias * s.y, p.z + _rng.randf() * s.z)


func _process(delta: float) -> void:
	if not alive:
		_process_dead(delta)
		return
	var vigor: float = clamp(health / 100.0, 0.25, 1.0)
	var spd: float = _speed * vigor
	_retarget -= delta
	var feed_point: Vector3 = aquarium.get_food_point() if aquarium and aquarium.has_method("get_food_point") else Vector3.INF
	if feed_point != Vector3.INF:
		_target = feed_point + Vector3(_rng.randf_range(-0.08, 0.08), -0.02, _rng.randf_range(-0.05, 0.05))
		spd *= 2.2
	elif _retarget <= 0.0 or position.distance_to(_target) < 0.05:
		_target = _random_point()
		_retarget = _rng.randf_range(2.0, 6.0)
		if _rng.randf() < 0.15:
			_burst = 0.6
	if _burst > 0.0:
		_burst -= delta
		spd *= 2.5

	var desired: Vector3 = (_target - position).normalized() * spd
	# Sürü davranışı + kişisel alan: hiçbir balık diğerinin içine girmez
	var school: float = float(_data.schooling)
	var my_r: float = radius()
	var center := Vector3.ZERO
	var align := Vector3.ZERO
	var sep := Vector3.ZERO
	var n := 0
	if aquarium:
		for other in aquarium.fish_nodes():
			if other == self or not is_instance_valid(other) or not other.alive:
				continue
			var off: Vector3 = position - other.position
			var d: float = off.length()
			var min_d: float = (my_r + other.radius()) * 1.15
			if d < min_d:
				var push: float = (1.0 - d / min_d)
				sep += (off / max(d, 0.001) if d > 0.001 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()) * push
			if school > 0.0 and other.species == species and d < 0.3:
				center += other.position
				align += other.velocity
				n += 1
	if n > 0 and feed_point == Vector3.INF:
		center /= n
		desired += ((center - position) * 0.35 + align / n * 0.8) * school
	if sep != Vector3.ZERO:
		desired += sep * spd * 4.0
		# İç içe geçmiş balıkları anında biraz ayır
		position += sep * min(my_r, 0.03) * delta * 6.0
	# Duvarlardan uzak dur (büyük balıklar için daha geniş pay)
	var lo: Vector3 = _lo()
	var hi: Vector3 = _hi()
	for axis in 3:
		if position[axis] < lo[axis]:
			desired[axis] += spd * 2.0
		elif position[axis] > hi[axis]:
			desired[axis] -= spd * 2.0
	desired.y *= 0.6
	if desired.length() > spd * 1.5:
		desired = desired.normalized() * spd * 1.5
	velocity = velocity.lerp(desired, clamp(delta * 2.0, 0.0, 1.0))
	position += velocity * delta
	position = position.clamp(_lo() - Vector3.ONE * 0.03, _hi() + Vector3.ONE * 0.03)

	if velocity.length() > 0.002:
		var flat := velocity
		flat.y = clamp(flat.y, -flat.length() * 0.4, flat.length() * 0.4)
		var want := Basis.looking_at(flat.normalized(), Vector3.UP)
		var q := Quaternion(transform.basis.orthonormalized()).slerp(Quaternion(want), clamp(delta * 4.0, 0.0, 1.0))
		transform.basis = Basis(q).scaled(scale)
	if _mat:
		_mat.set_shader_parameter("swim", clamp(velocity.length() / max(_speed, 0.001), 0.35, 2.5))
		_mat.set_shader_parameter("health", clamp(health / 100.0, 0.15, 1.0))


func _process_dead(delta: float) -> void:
	if _mat:
		_mat.set_shader_parameter("health", 0.0)
		_mat.set_shader_parameter("swim", 0.0)
	var top: float = bounds.end.y + 0.02
	position.y = move_toward(position.y, top, delta * 0.03)
	position.y += sin(Time.get_ticks_msec() * 0.001 + _phase) * 0.0005
	var flat := Vector3(velocity.x, 0, velocity.z)
	var dir: Vector3 = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	var want := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.FORWARD, PI * 0.85)
	var q := Quaternion(transform.basis.orthonormalized()).slerp(Quaternion(want.orthonormalized()), clamp(delta * 1.5, 0.0, 1.0))
	transform.basis = Basis(q).scaled(scale)
