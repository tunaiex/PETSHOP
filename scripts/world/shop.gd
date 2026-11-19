class_name Shop
extends Node3D
## Dükkânın tüm statik yapısı: oda, aydınlatma, akvaryumlar, kasa, raf, kapı, dış mekân.
## Müşteri yolları için önemli noktaları da tutar.

const W := 14.0
const D := 10.0
const H := 3.2
const WALL := 0.2

var entrance := Vector3(0, 0, 3.4)
var outside := Vector3(0, 0, 8.5)
var hud: Node   ## main tarafından atanır
var main: Node

## Yerleştirilmiş eşyalar (uid -> düğüm)
var nodes: Dictionary = {}
var aquariums: Array = []
var shelves: Array = []
var counter: FurnitureItem = null

var _geo: NavigationRegion3D   ## Duvarlar, zemin ve eşyalar: müşteri yol haritası bundan çıkarılır
var _furn_root: Node3D
var _door_l: Node3D
var _door_r: Node3D
var _door_open: float = 0.0
var _clock: Label3D
var _bake_pending: bool = false
var _floor_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _sign_lbl: Label3D
var _sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _panel_mat: StandardMaterial3D
var _room_lights: Array = []
var _rain: CPUParticles3D
var _boxes_root: Node3D


func build() -> void:
	_geo = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.3
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.15
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.filter_baking_aabb = AABB(Vector3(Game.room_min_x() - 2.5, -0.5, -5.5), Vector3(W * 0.5 - Game.room_min_x() + 5.0, 3.0, 17))
	_geo.navigation_mesh = nm
	add_child(_geo)
	_furn_root = Node3D.new()
	_geo.add_child(_furn_root)
	_environment()
	_room()
	_front_wall()
	_outside()
	_lights()
	_build_clock()
	sync_furniture()
	Game.furniture_changed.connect(sync_furniture)
	Game.settings_changed.connect(apply_settings)
	_boxes_root = Node3D.new()
	add_child(_boxes_root)
	sync_boxes()
	Game.boxes_changed.connect(sync_boxes)
	Game.time_changed.connect(func(_m): _clock.text = Game.clock_text())


# ------------------------------------------------------------------ Ortam

func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	_sky_mat = sm
	sm.sky_top_color = Color(0.35, 0.55, 0.85)
	sm.sky_horizon_color = Color(0.75, 0.82, 0.9)
	sm.ground_horizon_color = Color(0.7, 0.72, 0.75)
	sm.ground_bottom_color = Color(0.3, 0.3, 0.32)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _room() -> void:
	var x0: float = Game.room_min_x()
	var x1: float = W * 0.5
	var rw: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	_floor_mat = MeshKit.shader_mat("res://shaders/wood_floor.gdshader")
	var fl := MeshKit.box(_geo, Vector3(rw, 0.1, D), Vector3(cx, -0.05, 0), _floor_mat, true)
	fl.name = "Floor"
	_wall_mat = MeshKit.shader_mat("res://shaders/wall.gdshader")
	# Arka, sol, sağ duvar
	MeshKit.box(_geo, Vector3(rw + WALL * 2, H, WALL), Vector3(cx, H * 0.5, -D * 0.5 - WALL * 0.5), _wall_mat, true)
	MeshKit.box(_geo, Vector3(WALL, H, D), Vector3(x0 - WALL * 0.5, H * 0.5, 0), _wall_mat, true)
	MeshKit.box(_geo, Vector3(WALL, H, D), Vector3(x1 + WALL * 0.5, H * 0.5, 0), _wall_mat, true)
	# Tavan
	var ceil_mat := MeshKit.mat(Color(0.93, 0.93, 0.91), 0.95)
	MeshKit.box(_geo, Vector3(rw + WALL * 2, 0.12, D + WALL * 2), Vector3(cx, H + 0.06, 0), ceil_mat)
	# Tavan pervazı
	var trim := MeshKit.mat(Color(0.95, 0.95, 0.93), 0.5)
	MeshKit.box(_geo, Vector3(rw, 0.08, 0.02), Vector3(cx, H - 0.04, -D * 0.5 + 0.01), trim)
	for x in [x0 + 0.01, x1 - 0.01]:
		MeshKit.box(_geo, Vector3(0.02, 0.08, D), Vector3(x, H - 0.04, 0), trim)
	apply_settings()


## Duvar rengi, zemin ve tabela adı
func apply_settings() -> void:
	var wc: Array = Game.WALL_COLORS[clamp(int(Game.settings.wall), 0, Game.WALL_COLORS.size() - 1)]
	_wall_mat.set_shader_parameter("paint", wc[1])
	_wall_mat.set_shader_parameter("panel", wc[2])
	var fc: Array = Game.FLOOR_TYPES[clamp(int(Game.settings.floor), 0, Game.FLOOR_TYPES.size() - 1)]
	_floor_mat.set_shader_parameter("wood_a", fc[1])
	_floor_mat.set_shader_parameter("wood_b", fc[2])
	if _sign_lbl:
		_sign_lbl.text = str(Game.settings.name)


func _front_wall() -> void:
	var z := D * 0.5 + WALL * 0.5
	var wall_mat := MeshKit.mat(Color(0.86, 0.88, 0.84), 0.9)
	var frame := MeshKit.mat(Color(0.12, 0.12, 0.13), 0.4, 0.6)
	# Kapı: x -1..1, yükseklik 2.3. Vitrin camları: 0.6m'den 2.6m'ye.
	var door_w := 2.0
	var door_h := 2.3
	var win_lo := 0.6
	var win_hi := 2.6
	# Alt bölümler (pencere altı)
	for side in [-1.0, 1.0]:
		var edge: float = -Game.room_min_x() if side < 0 else W * 0.5
		var w: float = edge - door_w * 0.5
		var cx: float = side * (door_w * 0.5 + w * 0.5)
		MeshKit.box(_geo, Vector3(w, win_lo, WALL), Vector3(cx, win_lo * 0.5, z), wall_mat, true)
		MeshKit.box(_geo, Vector3(w, H - win_hi, WALL), Vector3(cx, (H + win_hi) * 0.5, z), wall_mat)
		# Cam
		var glass := MeshKit.shader_mat("res://shaders/glass.gdshader", {"tint": Color(0.85, 0.92, 0.95)})
		MeshKit.box(_geo, Vector3(w, win_hi - win_lo, 0.02), Vector3(cx, (win_lo + win_hi) * 0.5, z), glass, true)
		# Kayıtlar
		MeshKit.box(_geo, Vector3(w, 0.06, 0.12), Vector3(cx, win_lo, z), frame)
		MeshKit.box(_geo, Vector3(w, 0.06, 0.12), Vector3(cx, win_hi, z), frame)
		var n: int = max(2, int(round(w / 2.0)))
		for i in n + 1:
			var x: float = cx - w * 0.5 + w * float(i) / n
			MeshKit.box(_geo, Vector3(0.06, win_hi - win_lo, 0.12), Vector3(x, (win_lo + win_hi) * 0.5, z), frame)
	MeshKit.box(_geo, Vector3(door_w, H - door_h, WALL), Vector3(0, (H + door_h) * 0.5, z), wall_mat)
	MeshKit.box(_geo, Vector3(door_w + 0.1, 0.08, 0.14), Vector3(0, door_h, z), frame)
	# Otomatik kayar kapı
	var door_glass := MeshKit.shader_mat("res://shaders/glass.gdshader", {"tint": Color(0.85, 0.92, 0.95)})
	_door_l = Node3D.new()
	_door_r = Node3D.new()
	for pair in [[_door_l, -0.5], [_door_r, 0.5]]:
		var dn: Node3D = pair[0]
		dn.position = Vector3(pair[1], 0, z + 0.05)
		add_child(dn)
		MeshKit.box(dn, Vector3(1.0, door_h - 0.04, 0.02), Vector3(0, door_h * 0.5, 0), door_glass)
		MeshKit.box(dn, Vector3(1.0, 0.05, 0.04), Vector3(0, 0.025, 0), frame)
		MeshKit.box(dn, Vector3(1.0, 0.05, 0.04), Vector3(0, door_h - 0.05, 0), frame)
		MeshKit.box(dn, Vector3(0.04, door_h - 0.04, 0.04), Vector3(-0.48 * sign(pair[1]), door_h * 0.5, 0), frame)
	# Kapıda AÇIK/KAPALI tabelası ile etkileşim
	var sign_lbl := Label3D.new()
	sign_lbl.font_size = 48
	sign_lbl.pixel_size = 0.004
	sign_lbl.position = Vector3(0, door_h + 0.3, z - 0.12)
	sign_lbl.rotation_degrees.y = 180
	sign_lbl.modulate = Color(0.85, 0.15, 0.1)
	sign_lbl.outline_size = 0
	sign_lbl.text = "KAPALI"
	add_child(sign_lbl)
	Game.phase_changed.connect(func(p): sign_lbl.text = "AÇIK" if p == "open" else "KAPALI"; sign_lbl.modulate = Color(0.1, 0.6, 0.2) if p == "open" else Color(0.85, 0.15, 0.1))
	Interactable.create(self, Vector3(2.0, 2.3, 0.3), Vector3(0, 1.15, z - 0.25), _door_prompt, _door_action)


func _door_prompt() -> String:
	match Game.phase:
		"prep":
			return "Dükkânı aç (saat 09:00 başlar)" if counter else "Dükkânı açmak için önce kasa tezgâhı kur"
		"open":
			return "Dükkân açık. Kapanış 19:00"
		"closing":
			return "Kapanıyor... son müşteriler"
	return ""


func _door_action(_p: Node) -> void:
	if Game.phase != "prep":
		return
	Sfx.play("click")
	if counter == null:
		Game.notify.emit("Önce bir kasa tezgâhı kur (TELEFON > Mobilya). Kasa olmadan satış yapılamaz.", "bad")
		return
	if aquariums.is_empty() and shelves.is_empty():
		Game.notify.emit("Satacak hiçbir şeyin yok! Akvaryum ya da raf kur.", "bad")
		return
	Game.open_shop()
	Sfx.play("chime")


func _outside() -> void:
	var walk := MeshKit.mat(Color(0.62, 0.6, 0.58), 0.9)
	MeshKit.box(_geo, Vector3(60, 0.1, 6.2), Vector3(0, -0.06, D * 0.5 + 3.0), walk, true)
	for wall in [[Vector3(0.2, 3, 7), Vector3(Game.room_min_x() - 2.0, 1.5, D * 0.5 + 3.5)], [Vector3(0.2, 3, 7), Vector3(9, 1.5, D * 0.5 + 3.5)], [Vector3(30, 3, 0.2), Vector3(0, 1.5, D * 0.5 + 6.2)]]:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = wall[0]
		cs.shape = sh
		b.add_child(cs)
		b.position = wall[1]
		_geo.add_child(b)
	var road := MeshKit.mat(Color(0.18, 0.18, 0.2), 0.85)
	MeshKit.box(_geo, Vector3(60, 0.1, 8), Vector3(0, -0.2, D * 0.5 + 10), road)
	# Karşı binalar
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := -28.0
	while x < 28.0:
		var bw: float = rng.randf_range(5, 9)
		var bh: float = rng.randf_range(7, 16)
		var col := Color.from_hsv(rng.randf_range(0.05, 0.12), rng.randf_range(0.1, 0.35), rng.randf_range(0.6, 0.85))
		MeshKit.box(_geo, Vector3(bw - 0.3, bh, 6), Vector3(x + bw * 0.5, bh * 0.5 - 0.2, D * 0.5 + 17), MeshKit.mat(col, 0.9))
		var win := MeshKit.mat(Color(0.25, 0.32, 0.4), 0.15, 0.3)
		var fy := 1.5
		while fy < bh - 1.0:
			var fx := x + 1.0
			while fx < x + bw - 1.0:
				MeshKit.box(_geo, Vector3(0.9, 1.2, 0.05), Vector3(fx + 0.45, fy, D * 0.5 + 13.98), win)
				fx += 1.8
			fy += 2.6
		x += bw
	# Dış tabela
	var board := MeshKit.box(_geo, Vector3(6.0, 0.7, 0.12), Vector3(0, H - 0.1, D * 0.5 + WALL + 0.08), MeshKit.mat(Color(0.06, 0.25, 0.32), 0.4))
	board.name = "SignBoard"
	var lbl := Label3D.new()
	_sign_lbl = lbl
	lbl.text = str(Game.settings.name)
	lbl.font_size = 96
	lbl.pixel_size = 0.005
	lbl.modulate = Color(0.95, 0.97, 1.0)
	lbl.outline_size = 0
	lbl.position = Vector3(0, H - 0.1, D * 0.5 + WALL + 0.15)
	add_child(lbl)


func _lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-40, 160, 0)
	_sun.light_energy = 1.1
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 30.0
	add_child(_sun)
	_panel_mat = StandardMaterial3D.new()
	_panel_mat.albedo_color = Color(1, 1, 1)
	_panel_mat.emission_enabled = true
	_panel_mat.emission = Color(1.0, 0.96, 0.88)
	_panel_mat.emission_energy_multiplier = 2.5
	var rim := MeshKit.mat(Color(0.8, 0.8, 0.8), 0.4, 0.5)
	var x := Game.room_min_x() + 3.0
	while x < W * 0.5 - 1.0:
		for z in [-2.5, 1.5]:
			MeshKit.cylinder(self, 0.2, 0.03, Vector3(x, H - 0.005, z), rim)
			MeshKit.cylinder(self, 0.17, 0.02, Vector3(x, H - 0.02, z), _panel_mat)
			var l := OmniLight3D.new()
			l.position = Vector3(x, H - 0.4, z)
			l.omni_range = 6.5
			l.light_energy = 0.75
			l.light_color = Color(1.0, 0.95, 0.86)
			l.shadow_enabled = false
			add_child(l)
			_room_lights.append(l)
		x += 4.0
	_build_rain()
	Game.power_changed.connect(_on_power)
	Game.time_changed.connect(func(_m): _update_daylight())
	_update_daylight()


func _on_power(on: bool) -> void:
	for l in _room_lights:
		l.light_energy = 0.75 if on else 0.08
	_panel_mat.emission_energy_multiplier = 2.5 if on else 0.0


## Gün ışığı saate ve havaya göre değişir; akşam dışarısı kararır.
func _update_daylight() -> void:
	var m: float = Game.minute
	# 08:00 tam gün, 17:00'den sonra batmaya başlar, 20:00 gece
	var day_f: float = 1.0 - smoothstep(17.0 * 60.0, 20.0 * 60.0, m)
	var weather_f: float = {"gunesli": 1.0, "bulutlu": 0.7, "yagmurlu": 0.4}.get(Game.weather, 1.0)
	_sun.light_energy = 1.1 * day_f * weather_f
	var dusk: float = smoothstep(16.5 * 60.0, 19.0 * 60.0, m) * (1.0 - smoothstep(19.0 * 60.0, 20.5 * 60.0, m))
	_sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.55, 0.3), dusk)
	if _sky_mat:
		var top := Color(0.35, 0.55, 0.85)
		var hor := Color(0.75, 0.82, 0.9)
		if Game.weather == "yagmurlu":
			top = Color(0.42, 0.45, 0.5)
			hor = Color(0.6, 0.62, 0.65)
		elif Game.weather == "bulutlu":
			top = Color(0.5, 0.6, 0.72)
			hor = Color(0.72, 0.76, 0.8)
		top = top.lerp(Color(0.95, 0.5, 0.35), dusk * 0.6).lerp(Color(0.02, 0.03, 0.08), 1.0 - day_f)
		hor = hor.lerp(Color(1.0, 0.6, 0.35), dusk * 0.8).lerp(Color(0.05, 0.06, 0.12), 1.0 - day_f)
		_sky_mat.sky_top_color = top
		_sky_mat.sky_horizon_color = hor
		_sky_mat.ground_horizon_color = hor.darkened(0.1)
	if _env:
		_env.ambient_light_energy = lerp(0.25, 0.55, day_f * weather_f)
	if _rain:
		_rain.emitting = Game.weather == "yagmurlu"
	Sfx.set_rain(Game.weather == "yagmurlu")
	Sfx.set_hum(aquariums.size(), not Game.power_out)


func _build_rain() -> void:
	var drop := QuadMesh.new()
	drop.size = Vector2(0.015, 0.35)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.8, 0.85, 0.95, 0.45)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = dm
	_rain = CPUParticles3D.new()
	_rain.mesh = drop
	_rain.amount = 900
	_rain.lifetime = 0.8
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(16, 0.5, 6)
	_rain.position = Vector3(0, 7, D * 0.5 + 6.5)
	_rain.direction = Vector3(0, -1, 0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 9.0
	_rain.initial_velocity_max = 11.0
	_rain.gravity = Vector3(0, -9.8, 0)
	_rain.emitting = false
	add_child(_rain)


func _build_clock() -> void:
	_clock = Label3D.new()
	_clock.font_size = 96
	_clock.pixel_size = 0.003
	_clock.modulate = Color(0.9, 0.25, 0.2)
	_clock.outline_size = 0
	_clock.position = Vector3(W * 0.5 - 0.05, 2.6, 2.8)
	_clock.rotation_degrees.y = -90
	_clock.text = Game.clock_text()
	add_child(_clock)
	MeshKit.box(self, Vector3(0.04, 0.4, 0.9), Vector3(W * 0.5 - 0.02, 2.6, 2.8), MeshKit.mat(Color(0.05, 0.05, 0.05), 0.3))


# ------------------------------------------------------------------ Eşyalar

## Game.furniture ile sahnedeki düğümleri eşitler, sonra yol haritasını yeniden çıkarır.
func sync_furniture() -> void:
	var seen := {}
	for e in Game.furniture:
		var uid: int = int(e.uid)
		seen[uid] = true
		var n: Node3D = nodes.get(uid)
		if n == null or not is_instance_valid(n):
			n = spawn(e)
			nodes[uid] = n
		n.position = Vector3(e.x, 0, e.z)
		n.rotation = Vector3(0, deg_to_rad(e.rot), 0)
	for uid in nodes.keys():
		if not seen.has(uid):
			nodes[uid].queue_free()
			nodes.erase(uid)
	_index()
	request_bake()


func spawn(e: Dictionary) -> Node3D:
	var n: Node3D
	if FurnitureDB.is_tank(e.type):
		var aq := Aquarium.new()
		aq.furniture_uid = int(e.uid)
		_furn_root.add_child(aq)
		aq.setup(int(e.tank), e.type == "akvaryum_ceviz", e.type == "teraryum")
		n = aq
	elif FurnitureDB.is_shelf(e.type):
		var sh := Shelf.new()
		_furn_root.add_child(sh)
		sh.setup(int(e.uid), e.type)
		n = sh
	else:
		var it := FurnitureItem.new()
		_furn_root.add_child(it)
		it.setup(int(e.uid), e.type, main)
		n = it
	n.position = Vector3(e.x, 0, e.z)
	n.rotation = Vector3(0, deg_to_rad(e.rot), 0)
	return n


func _index() -> void:
	aquariums.clear()
	shelves.clear()
	counter = null
	for uid in nodes:
		var n: Node = nodes[uid]
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if n is Aquarium:
			aquariums.append(n)
		elif n is Shelf:
			shelves.append(n)
		elif n is FurnitureItem and n.type == "kasa":
			counter = n


## Kapıya gelen kolileri, girişin sağına yığar.
func sync_boxes() -> void:
	for c in _boxes_root.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	for i in Game.boxes.size():
		var b: Dictionary = Game.boxes[i]
		var box := DeliveryBox.new()
		box.setup(b)
		var col: int = i % 4
		var stack: int = (i / 4) % 3
		var row: int = i / 12
		box.position = Vector3(1.75 + col * 0.5, stack * 0.36, 4.35 - row * 0.5)
		box.rotation.y = (i % 3) * 0.08
		_boxes_root.add_child(box)


func node_for(uid: int) -> Node3D:
	return nodes.get(uid)


func request_bake() -> void:
	if _bake_pending:
		return
	_bake_pending = true
	_bake.call_deferred()


func _bake() -> void:
	_bake_pending = false
	if is_inside_tree():
		_geo.bake_navigation_mesh(false)


## Müşteri için iki nokta arası yürüme yolu (bulunamazsa düz çizgi)
func path(from: Vector3, to: Vector3) -> Array:
	var map: RID = get_world_3d().navigation_map
	var pts: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	if pts.size() < 2:
		return [to]
	var out: Array = []
	for i in range(1, pts.size()):
		out.append(Vector3(pts[i].x, 0, pts[i].z))
	return out


func _process(delta: float) -> void:
	# Kapı, yakında müşteri ya da oyuncu varsa açılır.
	var want: float = 0.0
	if main and main.someone_near_door():
		want = 1.0
	_door_open = move_toward(_door_open, want, delta * 2.0)
	if _door_l:
		_door_l.position.x = -0.5 - _door_open * 0.95
		_door_r.position.x = 0.5 + _door_open * 0.95
