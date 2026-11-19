class_name Aquarium
extends Node3D
## Dolap üstünde akvaryum: cam, su, çakıl, bitki, kaya, kök, ışık, kabarcık ve balıklar.
## Verisi Game.tanks[tank_id] içinde. Görsel, veriyle düzenli aralıklarla eşitlenir.

const TW := 1.3
const TH := 0.55
const TD := 0.5
const STAND_H := 0.82
const GRAVEL := 0.07

var tank_id: int = 0
var _fish: Dictionary = {}  ## uid -> Fish
var _water_mat: ShaderMaterial
var _surface_mat: ShaderMaterial
var _glass_mat: ShaderMaterial
var _gravel_mat: ShaderMaterial
var _food_particles: CPUParticles3D
var _food_timer: float = 0.0
var _food_point: Vector3
var _label: Label3D
var _sign: Label3D
var _content: Node3D
var _light: SpotLight3D
var _built_unlocked: bool = false
var _sync_timer: float = 0.0
var _y0: float = STAND_H + 0.025
var _water_h: float = TH - 0.06


func setup(id: int) -> void:
	tank_id = id
	_build_static()
	_rebuild_content()
	Game.tank_changed.connect(_on_tank_changed)


func data() -> Dictionary:
	return Game.tanks[tank_id]


func _on_tank_changed(id: int) -> void:
	if id == tank_id:
		sync()


# ------------------------------------------------------------------ İnşa

func _build_static() -> void:
	var cabinet := MeshKit.mat(Color(0.87, 0.87, 0.85), 0.45)
	var dark := MeshKit.mat(Color(0.05, 0.05, 0.055), 0.35)
	var seam := MeshKit.mat(Color(0.55, 0.55, 0.53), 0.6)
	MeshKit.box(self, Vector3(TW + 0.04, STAND_H - 0.06, TD + 0.04), Vector3(0, STAND_H * 0.5 + 0.03, 0), cabinet)
	MeshKit.box(self, Vector3(TW, 0.06, TD), Vector3(0, 0.03, -0.01), dark)
	# Dolap kapakları
	for i in 2:
		var x: float = -TW / 6.0 + i * TW / 3.0
		MeshKit.box(self, Vector3(0.004, STAND_H - 0.1, 0.004), Vector3(x, STAND_H * 0.5 + 0.03, TD * 0.5 + 0.021), seam)
	for i in 3:
		var x: float = -TW / 3.0 + i * TW / 3.0
		MeshKit.box(self, Vector3(0.012, 0.12, 0.012), Vector3(x + 0.12, STAND_H * 0.62, TD * 0.5 + 0.028), MeshKit.mat(Color(0.7, 0.7, 0.72), 0.25, 0.9))
	MeshKit.box(self, Vector3(TW + 0.05, 0.025, TD + 0.05), Vector3(0, STAND_H + 0.0125, 0), dark)

	# Cam kenar çerçeveleri (siyah silikon görünümü)
	var y0 := _y0
	MeshKit.box(self, Vector3(TW + 0.012, 0.022, TD + 0.012), Vector3(0, y0 + 0.011, 0), dark)
	for z in [-TD * 0.5, TD * 0.5]:
		MeshKit.box(self, Vector3(TW + 0.012, 0.012, 0.014), Vector3(0, y0 + TH - 0.006, z), dark)
	for x in [-TW * 0.5, TW * 0.5]:
		MeshKit.box(self, Vector3(0.014, 0.012, TD + 0.012), Vector3(x, y0 + TH - 0.006, 0), dark)
		for z in [-TD * 0.5, TD * 0.5]:
			MeshKit.box(self, Vector3(0.012, TH, 0.012), Vector3(x, y0 + TH * 0.5, z), dark)

	# Arka fon (koyu lacivert, gerçek akvaryumlardaki gibi)
	var bg := StandardMaterial3D.new()
	bg.albedo_color = Color(0.02, 0.05, 0.07)
	bg.roughness = 0.9
	MeshKit.box(self, Vector3(TW - 0.01, TH - 0.01, 0.004), Vector3(0, y0 + TH * 0.5, -TD * 0.5 - 0.004), bg)

	# Kapak / lamba
	var hood := MeshKit.box(self, Vector3(TW + 0.03, 0.07, TD + 0.03), Vector3(0, y0 + TH + 0.035, 0), dark)
	hood.name = "Hood"
	var led := StandardMaterial3D.new()
	led.albedo_color = Color(0.9, 0.95, 1.0)
	led.emission_enabled = true
	led.emission = Color(0.85, 0.95, 1.0)
	led.emission_energy_multiplier = 3.0
	MeshKit.box(self, Vector3(TW - 0.12, 0.004, 0.05), Vector3(0, y0 + TH - 0.002, 0), led)
	# Küçük dijital gösterge
	var lcd := StandardMaterial3D.new()
	lcd.albedo_color = Color(0.1, 0.2, 0.35)
	lcd.emission_enabled = true
	lcd.emission = Color(0.3, 0.6, 1.0)
	lcd.emission_energy_multiplier = 1.5
	MeshKit.box(self, Vector3(0.09, 0.025, 0.004), Vector3(0, y0 + TH + 0.04, TD * 0.5 + 0.017), lcd)

	# Cam paneller
	_glass_mat = MeshKit.shader_mat("res://shaders/glass.gdshader")
	MeshKit.box(self, Vector3(TW, TH, 0.008), Vector3(0, y0 + TH * 0.5, TD * 0.5), _glass_mat)
	MeshKit.box(self, Vector3(0.008, TH, TD), Vector3(-TW * 0.5, y0 + TH * 0.5, 0), _glass_mat)
	MeshKit.box(self, Vector3(0.008, TH, TD), Vector3(TW * 0.5, y0 + TH * 0.5, 0), _glass_mat)

	# Etiket
	_label = Label3D.new()
	_label.font_size = 26
	_label.pixel_size = 0.0011
	_label.outline_size = 0
	_label.modulate = Color(0.15, 0.15, 0.17)
	_label.position = Vector3(0, STAND_H - 0.1, TD * 0.5 + 0.022)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.double_sided = false
	add_child(_label)

	# Çarpışma + etkileşim
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TW + 0.06, y0 + TH + 0.08, TD + 0.06)
	cs.shape = shape
	cs.position = Vector3(0, shape.size.y * 0.5, 0)
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)


func _rebuild_content() -> void:
	if _content:
		_content.queue_free()
	_fish.clear()
	_content = Node3D.new()
	add_child(_content)
	var d: Dictionary = data()
	_built_unlocked = d.unlocked
	var y0 := _y0
	if not d.unlocked:
		_sign = Label3D.new()
		_sign.text = "KİRALIK TANK\n%s ₺" % _fmt(TankSim.UNLOCK_COST)
		_sign.font_size = 64
		_sign.pixel_size = 0.0012
		_sign.modulate = Color(0.9, 0.2, 0.15)
		_sign.outline_size = 8
		_sign.outline_modulate = Color(1, 1, 1)
		_sign.position = Vector3(0, y0 + TH * 0.5, TD * 0.5 + 0.01)
		_content.add_child(_sign)
		var bed := MeshKit.mat(Color(0.2, 0.2, 0.2), 0.9)
		MeshKit.box(_content, Vector3(TW - 0.02, 0.01, TD - 0.02), Vector3(0, y0 + 0.005, 0), bed)
		_label.text = "TANK %d" % (tank_id + 1)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + tank_id * 131

	# Çakıl
	_gravel_mat = MeshKit.shader_mat("res://shaders/gravel.gdshader")
	if rng.randf() < 0.5:
		_gravel_mat.set_shader_parameter("color_a", Color(0.78, 0.7, 0.55))
		_gravel_mat.set_shader_parameter("color_b", Color(0.45, 0.38, 0.28))
	MeshKit.box(_content, Vector3(TW - 0.016, GRAVEL, TD - 0.016), Vector3(0, y0 + GRAVEL * 0.5, 0), _gravel_mat)

	# Su
	_water_mat = MeshKit.shader_mat("res://shaders/water.gdshader")
	MeshKit.box(_content, Vector3(TW - 0.016, _water_h - GRAVEL, TD - 0.016), Vector3(0, y0 + GRAVEL + (_water_h - GRAVEL) * 0.5, 0), _water_mat)
	_surface_mat = MeshKit.shader_mat("res://shaders/water.gdshader", {"is_surface": true})
	var surf := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TW - 0.016, TD - 0.016)
	pm.subdivide_width = 24
	pm.subdivide_depth = 10
	surf.mesh = pm
	surf.material_override = _surface_mat
	surf.position = Vector3(0, y0 + _water_h, 0)
	_content.add_child(surf)

	# Işık
	_light = SpotLight3D.new()
	_light.position = Vector3(0, y0 + TH - 0.02, 0)
	_light.rotation_degrees = Vector3(-90, 0, 0)
	_light.spot_range = 1.2
	_light.spot_angle = 65.0
	_light.light_energy = 2.2
	_light.light_color = Color(0.85, 0.95, 1.0)
	_light.shadow_enabled = false
	_content.add_child(_light)

	_build_decor(rng)
	_build_particles()
	sync()


func _build_decor(rng: RandomNumberGenerator) -> void:
	var y0 := _y0 + GRAVEL
	var rock_mat := MeshKit.mat(Color(0.5, 0.5, 0.48), 0.85)
	if rng.randf() < 0.5:
		rock_mat.albedo_color = Color(0.42, 0.36, 0.3)
	# Kayalar
	for i in rng.randi_range(2, 3):
		var mi := MeshInstance3D.new()
		var sz := Vector3(rng.randf_range(0.12, 0.22), rng.randf_range(0.08, 0.16), rng.randf_range(0.1, 0.16))
		mi.mesh = MeshKit.rock(rng.randi(), sz)
		mi.material_override = rock_mat
		mi.position = Vector3(rng.randf_range(-TW * 0.38, TW * 0.38), y0 + sz.y * 0.1, rng.randf_range(-TD * 0.3, 0.0))
		mi.rotation.y = rng.randf() * TAU
		_content.add_child(mi)
	# Kök
	var pts: Array = []
	var radii: Array = []
	var sx: float = rng.randf_range(-0.35, -0.1)
	var dir: float = 1.0 if rng.randf() < 0.5 else -1.0
	for i in 8:
		var t: float = i / 7.0
		pts.append(Vector3(sx * dir + t * 0.45 * dir, y0 + sin(t * PI) * 0.22 + t * 0.08, -0.08 + sin(t * 5.0) * 0.04))
		radii.append(lerp(0.03, 0.008, t))
	var wood := MeshInstance3D.new()
	wood.mesh = MeshKit.tube(pts, radii)
	wood.material_override = MeshKit.mat(Color(0.28, 0.2, 0.13), 0.9)
	_content.add_child(wood)
	# Bitkiler
	var greens := [
		[Color(0.06, 0.25, 0.06), Color(0.35, 0.75, 0.2)],
		[Color(0.08, 0.3, 0.1), Color(0.55, 0.85, 0.3)],
		[Color(0.2, 0.08, 0.05), Color(0.75, 0.3, 0.2)],
	]
	for i in rng.randi_range(5, 7):
		var pal: Array = greens[rng.randi_range(0, 1)]
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.grass_clump(rng.randi() % 1000, rng.randi_range(6, 10), rng.randf_range(0.25, _water_h - GRAVEL - 0.05))
		mi.material_override = MeshKit.shader_mat("res://shaders/plant.gdshader", {"base_color": pal[0], "tip_color": pal[1]})
		mi.position = Vector3(rng.randf_range(-TW * 0.45, TW * 0.45), y0 - 0.01, rng.randf_range(-TD * 0.42, -TD * 0.2))
		_content.add_child(mi)
	for i in rng.randi_range(1, 2):
		var pal: Array = greens[2] if rng.randf() < 0.3 else greens[1]
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.sword_plant(rng.randi() % 1000, rng.randi_range(7, 11), rng.randf_range(0.14, 0.22))
		mi.material_override = MeshKit.shader_mat("res://shaders/plant.gdshader", {"base_color": pal[0], "tip_color": pal[1], "sway": 0.4})
		mi.position = Vector3(rng.randf_range(-TW * 0.35, TW * 0.35), y0 - 0.005, rng.randf_range(-TD * 0.15, TD * 0.1))
		_content.add_child(mi)


func _build_particles() -> void:
	var bubble_mat := StandardMaterial3D.new()
	bubble_mat.albedo_color = Color(0.9, 0.97, 1.0, 0.45)
	bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_mat.roughness = 0.05
	bubble_mat.metallic_specular = 1.0
	var bm := SphereMesh.new()
	bm.radius = 0.004
	bm.height = 0.008
	bm.radial_segments = 8
	bm.rings = 4
	bm.material = bubble_mat
	var bubbles := CPUParticles3D.new()
	bubbles.mesh = bm
	bubbles.amount = 40
	bubbles.lifetime = 2.6
	bubbles.position = Vector3(TW * 0.42, _y0 + GRAVEL + 0.01, -TD * 0.35)
	bubbles.direction = Vector3.UP
	bubbles.spread = 6.0
	bubbles.gravity = Vector3(0, 0.05, 0)
	bubbles.initial_velocity_min = 0.14
	bubbles.initial_velocity_max = 0.2
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.6
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.01
	_content.add_child(bubbles)
	# Hava taşı
	MeshKit.cylinder(_content, 0.018, 0.02, bubbles.position, MeshKit.mat(Color(0.3, 0.3, 0.32), 0.9), 12)

	var flake := QuadMesh.new()
	flake.size = Vector2(0.008, 0.008)
	var flake_mat := StandardMaterial3D.new()
	flake_mat.albedo_color = Color(0.85, 0.45, 0.2)
	flake_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flake.material = flake_mat
	_food_particles = CPUParticles3D.new()
	_food_particles.mesh = flake
	_food_particles.amount = 60
	_food_particles.lifetime = 6.0
	_food_particles.one_shot = true
	_food_particles.emitting = false
	_food_particles.explosiveness = 0.85
	_food_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_food_particles.emission_box_extents = Vector3(0.08, 0.002, 0.06)
	_food_particles.gravity = Vector3(0, -0.012, 0)
	_food_particles.initial_velocity_max = 0.01
	_food_particles.angular_velocity_min = -90
	_food_particles.angular_velocity_max = 90
	_food_particles.particle_flag_rotate_y = true
	_content.add_child(_food_particles)


# ------------------------------------------------------------------ Eşitleme

func swim_bounds() -> AABB:
	var lo := Vector3(-TW * 0.5 + 0.07, _y0 + GRAVEL + 0.06, -TD * 0.5 + 0.07)
	var hi := Vector3(TW * 0.5 - 0.07, _y0 + _water_h - 0.04, TD * 0.5 - 0.07)
	return AABB(lo, hi - lo)


func sync() -> void:
	var d: Dictionary = data()
	if d.unlocked != _built_unlocked:
		_rebuild_content()
		return
	if not d.unlocked:
		return
	var seen := {}
	for f in d.fish:
		var uid: int = int(f.uid)
		seen[uid] = true
		if not _fish.has(uid):
			var node := Fish.new()
			_content.add_child(node)
			node.setup(f, self, swim_bounds())
			_fish[uid] = node
		else:
			_fish[uid].apply_state(f)
		_fish[uid].set_sick(d.sick_level if d.sick else 0.0)
	for uid in _fish.keys():
		if not seen.has(uid):
			_fish[uid].queue_free()
			_fish.erase(uid)
	var dirt: float = d.dirt
	_water_mat.set_shader_parameter("dirt", dirt)
	_surface_mat.set_shader_parameter("dirt", dirt)
	_gravel_mat.set_shader_parameter("dirt", dirt)
	_glass_mat.set_shader_parameter("algae", clamp((dirt - 40.0) / 60.0, 0.0, 1.0))
	_update_label()


func _update_label() -> void:
	var d: Dictionary = data()
	var counts := {}
	for f in TankSim.living(d):
		counts[f.species] = counts.get(f.species, 0) + 1
	var lines: Array = ["TANK %d   %.1f°C" % [tank_id + 1, d.temp]]
	for sp in counts:
		lines.append("%s ×%d" % [FishDB.display_name(sp), counts[sp]])
	if counts.is_empty():
		lines.append("(boş)")
	_label.text = "\n".join(lines)


func _process(delta: float) -> void:
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 1.0
		if Game.tanks.size() > tank_id:
			sync()
	if _food_timer > 0.0:
		_food_timer -= delta


func fish_nodes() -> Array:
	return _fish.values()


func fish_node(uid: int) -> Fish:
	return _fish.get(uid)


func get_food_point() -> Vector3:
	if _food_timer > 0.0:
		return _food_point
	return Vector3.INF


func play_feed() -> void:
	if not _food_particles:
		return
	_food_point = Vector3(randf_range(-0.3, 0.3), _y0 + _water_h - 0.06, randf_range(-0.05, 0.1))
	_food_particles.position = _food_point + Vector3(0, 0.05, 0)
	_food_particles.restart()
	_food_particles.emitting = true
	_food_timer = 7.0


## Müşterinin baktığı nokta (dünya uzayında)
func view_point() -> Vector3:
	return to_global(Vector3(0, 0, TD * 0.5 + 0.9))


func look_target() -> Vector3:
	return to_global(Vector3(0, _y0 + TH * 0.5, 0))


func get_prompt() -> String:
	if not data().unlocked:
		return "Tank %d: Kirala (%s ₺)" % [tank_id + 1, _fmt(TankSim.UNLOCK_COST)]
	return "Tank %d: İncele" % (tank_id + 1)


func interact(player: Node) -> void:
	player.hud.open_tank(self)


static func _fmt(v: int) -> String:
	var s := str(abs(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
