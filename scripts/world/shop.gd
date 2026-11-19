class_name Shop
extends Node3D
## Dükkânın tüm statik yapısı: oda, aydınlatma, akvaryumlar, kasa, raf, kapı, dış mekân.
## Müşteri yolları için önemli noktaları da tutar.

const W := 14.0
const D := 10.0
const H := 3.2
const WALL := 0.2

var entrance := Vector3(0, 0, 3.4)
var outside := Vector3(0, 0, 7.6)
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
var _floor_chunks: Array = []
var _street_lights: Array = []


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
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX: daha doğal, sinematik renk ve parlaklık geçişi
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Sadece masaüstünde (Forward+) çalışan efektler; telefonda otomatik kapalı kalır
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.72, 0.78, 0.86)
	env.fog_density = 0.4
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 120.0
	env.fog_sky_affect = 0.0
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ------------------------------------------------------------------ Malzemeler

static var _mat_cache: Dictionary = {}


## Dokulu PBR malzeme (dünya koordinatlı: büyük yüzeylerde dikiş olmaz)
static func pbr(kind: String) -> Material:
	if _mat_cache.has(kind):
		return _mat_cache[kind]
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var city := "res://assets/models/city/%s"
	match kind:
		"terrazzo":
			m.albedo_texture = load("res://assets/textures/terrazzo_color.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/terrazzo_normal.png")
			m.normal_scale = 0.8
			m.roughness_texture = load("res://assets/textures/terrazzo_rough.jpg")
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.roughness = 0.75
			m.uv1_scale = Vector3.ONE * 0.4
		"marble", "concrete", "paver", "asphalt", "brick", "metal":
			var base: String = {"marble": "T_MarbleFloor", "concrete": "T_Concrete", "paver": "T_Concrete", "asphalt": "T_Concrete_Asphalt", "brick": "T_RedBrick", "metal": "T_MetalConcrete"}[kind]
			m.albedo_texture = load(city % (base + "_BaseColor.png"))
			if kind != "asphalt":
				m.normal_enabled = true
				m.normal_texture = load(city % (base + "_Normal.png"))
				m.roughness_texture = load(city % (base + "_ORM.png"))
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				m.ao_enabled = true
				m.ao_texture = load(city % (base + "_ORM.png"))
				m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			else:
				m.roughness = 0.9
			m.uv1_scale = Vector3.ONE * {"marble": 0.35, "concrete": 0.3, "paver": 0.45, "asphalt": 0.15, "brick": 0.5, "metal": 0.4}[kind]
			if kind == "metal":
				m.albedo_color = Color(0.42, 0.44, 0.46)
	_mat_cache[kind] = m
	return m


## Büyük bir yüzeyi 2 m'lik parçalara böler: telefonda (Mobile) her parça yalnızca
## yakınındaki lambalardan etkilenir, böylece nesne başına ışık sınırına takılmaz.
func _tiles(parent: Node3D, mat: Material, x0: float, x1: float, z0: float, z1: float, y: float, thick: float, step: float = 2.0) -> Array:
	var out: Array = []
	var x := x0
	while x < x1 - 0.001:
		var w: float = min(step, x1 - x)
		var z := z0
		while z < z1 - 0.001:
			var d: float = min(step, z1 - z)
			var mi := MeshKit.box(parent, Vector3(w, thick, d), Vector3(x + w * 0.5, y, z + d * 0.5), mat)
			out.append(mi)
			z += d
		x += w
	return out


## Dikey duvarı parçalara böler. axis: "x" (duvar x boyunca) ya da "z"
func _wall_strip(parent: Node3D, mat: Material, axis: String, a0: float, a1: float, fixed: float, h: float, thick: float) -> void:
	var a := a0
	while a < a1 - 0.001:
		var w: float = min(2.0, a1 - a)
		if axis == "x":
			MeshKit.box(parent, Vector3(w, h, thick), Vector3(a + w * 0.5, h * 0.5, fixed), mat)
		else:
			MeshKit.box(parent, Vector3(thick, h, w), Vector3(fixed, h * 0.5, a + w * 0.5), mat)
		a += w


func _collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)


func _room() -> void:
	var x0: float = Game.room_min_x()
	var x1: float = W * 0.5
	var rw: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	# Zemin (görsel parçalar + tek çarpışma kutusu)
	_floor_chunks = _tiles(_geo, pbr("terrazzo"), x0, x1, -D * 0.5, D * 0.5, -0.05, 0.1)
	_collider(_geo, Vector3(rw, 0.1, D), Vector3(cx, -0.05, 0))
	# Duvarlar: dokulu sıva + lambri
	_wall_mat = MeshKit.shader_mat("res://shaders/wall.gdshader", {
		"plaster_tex": load("res://assets/textures/plaster_color.jpg"),
		"plaster_nrm": load("res://assets/textures/plaster_normal.png"),
		"plaster_rgh": load("res://assets/textures/plaster_rough.jpg"),
	})
	_wall_strip(_geo, _wall_mat, "x", x0 - WALL, x1 + WALL, -D * 0.5 - WALL * 0.5, H, WALL)
	_wall_strip(_geo, _wall_mat, "z", -D * 0.5, D * 0.5, x0 - WALL * 0.5, H, WALL)
	_wall_strip(_geo, _wall_mat, "z", -D * 0.5, D * 0.5, x1 + WALL * 0.5, H, WALL)
	_collider(_geo, Vector3(rw + WALL * 2, H, WALL), Vector3(cx, H * 0.5, -D * 0.5 - WALL * 0.5))
	_collider(_geo, Vector3(WALL, H, D), Vector3(x0 - WALL * 0.5, H * 0.5, 0))
	_collider(_geo, Vector3(WALL, H, D), Vector3(x1 + WALL * 0.5, H * 0.5, 0))
	# Asma tavan
	var ceil_mat := MeshKit.shader_mat("res://shaders/ceiling.gdshader")
	_tiles(_geo, ceil_mat, x0 - WALL, x1 + WALL, -D * 0.5 - WALL, D * 0.5 + WALL, H + 0.06, 0.12)
	# Tavan pervazı (gölge çizgisi)
	var trim := MeshKit.mat(Color(0.95, 0.95, 0.93), 0.5)
	MeshKit.box(_geo, Vector3(rw, 0.1, 0.04), Vector3(cx, H - 0.05, -D * 0.5 + 0.02), trim)
	for x in [x0 + 0.02, x1 - 0.02]:
		MeshKit.box(_geo, Vector3(0.04, 0.1, D), Vector3(x, H - 0.05, 0), trim)
	# Yansıma probu: cam, su ve parlak zemin odayı yansıtsın
	var probe := ReflectionProbe.new()
	probe.size = Vector3(rw, H, D)
	probe.position = Vector3(cx, H * 0.5, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 0.7
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.42, 0.39, 0.35)
	probe.ambient_color_energy = 1.0
	add_child(probe)
	apply_settings()


## Duvar rengi, zemin ve tabela adı
func apply_settings() -> void:
	var wc: Array = Game.WALL_COLORS[clamp(int(Game.settings.wall), 0, Game.WALL_COLORS.size() - 1)]
	_wall_mat.set_shader_parameter("paint", wc[1])
	_wall_mat.set_shader_parameter("panel", wc[2])
	var fc: Array = Game.FLOOR_TYPES[clamp(int(Game.settings.floor), 0, Game.FLOOR_TYPES.size() - 1)]
	var fm: Material
	if str(fc[3]) != "":
		fm = pbr(fc[3])
	else:
		fm = MeshKit.shader_mat("res://shaders/wood_floor.gdshader", {"wood_a": fc[1], "wood_b": fc[2]})
	for c in _floor_chunks:
		c.material_override = fm
	if _sign_lbl:
		_sign_lbl.text = str(Game.settings.name)


func _front_wall() -> void:
	var z := D * 0.5 + WALL * 0.5
	var wall_mat: Material = pbr("metal")
	var frame := MeshKit.mat(Color(0.08, 0.08, 0.09), 0.35, 0.7)
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


const CITY := "res://assets/models/city/%s.gltf"


func _city(id: String, pos: Vector3, rot_deg: float = 0.0, parent: Node3D = null) -> Node3D:
	var path := CITY % id
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_deg
	_fix_city_materials(n)
	(parent if parent else self).add_child(n)
	return n


## Kitin köşe aşınma maskesi köşe renklerinde (vertex color) saklı; özel shader olmadan
## kırmızı leke gibi göründüğü için kapatılır.
static var _fixed_mats: Dictionary = {}


func _fix_city_materials(n: Node) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(si)
			if m is BaseMaterial3D:
				if not _fixed_mats.has(m):
					var d: BaseMaterial3D = m.duplicate()
					d.vertex_color_use_as_albedo = false
					_fixed_mats[m] = d
				mi.set_surface_override_material(si, _fixed_mats[m])


func _outside() -> void:
	var x0: float = Game.room_min_x()
	var zf: float = D * 0.5 + WALL  # dükkân cephesinin dış yüzü
	# Kaldırım (karo), bordür, asfalt yol, şerit çizgileri, karşı kaldırım
	MeshKit.box(_geo, Vector3(80, 0.1, 3.4), Vector3(0, -0.06, zf + 1.5), pbr("paver"), true)
	var curb := MeshKit.mat(Color(0.62, 0.62, 0.6), 0.85)
	MeshKit.box(_geo, Vector3(80, 0.16, 0.22), Vector3(0, -0.09, zf + 3.3), curb)
	MeshKit.box(_geo, Vector3(80, 0.1, 6.0), Vector3(0, -0.2, zf + 6.4), pbr("asphalt"), true)
	var paint := MeshKit.mat(Color(0.92, 0.92, 0.88), 0.6)
	var x := -38.0
	while x < 38.0:
		MeshKit.box(_geo, Vector3(1.6, 0.01, 0.12), Vector3(x, -0.145, zf + 6.4), paint)
		x += 3.6
	MeshKit.box(_geo, Vector3(80, 0.16, 0.22), Vector3(0, -0.09, zf + 9.5), curb)
	MeshKit.box(_geo, Vector3(80, 0.1, 3.4), Vector3(0, -0.06, zf + 11.2), pbr("paver"), true)
	# Oyuncu dükkânın önündeki kaldırımda kalır
	_collider(_geo, Vector3(0.2, 3, 3.4), Vector3(x0 - 0.3, 1.5, zf + 1.5))
	_collider(_geo, Vector3(0.2, 3, 3.4), Vector3(W * 0.5 + 0.4, 1.5, zf + 1.5))
	_collider(_geo, Vector3(W - x0 + 2.0, 3, 0.2), Vector3((x0 + W * 0.5) * 0.5, 1.5, zf + 3.1))
	# Karşı sıra binalar (dükkâna bakar)
	var far_z: float = zf + 12.9
	var row := [["Building_Small_1", -7.23, 5.23], ["Building_Large_2", -9.32, 11.32], ["Building_Medium_2_001", -7.53, 7.53], ["Building_Small_1", -7.23, 5.23], ["Building_Large_2", -9.32, 11.32], ["Building_Medium_2_001", -7.53, 7.53]]
	var left := -40.0
	for b in row:
		# 180° dönünce yerel x aralığı [a,b] dünyada [pos.x - b, pos.x - a] olur
		_city(b[0], Vector3(left + float(b[2]), 0, far_z), 180.0)
		left += float(b[2]) - float(b[1]) + 0.3
	# Dükkânın iki yanındaki komşu binalar
	_city("Building_Large_2", Vector3(W * 0.5 + WALL + 9.32, 0, zf), 0.0)
	_city("Building_Medium_2_001", Vector3(x0 - WALL - 7.53, 0, zf), 0.0)
	# Dükkânın üst katları: tuğla cephe + pencereler + korniş
	var px := x0 - WALL + 1.0
	var i := 0
	while px < W * 0.5 + WALL:
		for floor_i in 2:
			var id := "Brick_Plain_3" if (i % 3 == 1) else "Brick_Window_Square_Single"
			_city(id, Vector3(px, H + 0.1 + floor_i * 3.0, zf), 0.0)
		_city("Cornice_Brick_Center", Vector3(px, H + 6.1, zf), 0.0)
		px += 2.0
		i += 1
	# Vitrin üstünde kumaş tente
	var awning := MeshKit.mat(Color(0.08, 0.36, 0.4), 0.8)
	for side in [-1.0, 1.0]:
		var edge: float = -x0 if side < 0 else W * 0.5
		var w: float = edge - 1.3
		var a := MeshKit.box(_geo, Vector3(w, 0.04, 1.1), Vector3(side * (1.3 + w * 0.5), 2.85, zf + 0.5), awning)
		a.rotation_degrees.x = 18
		MeshKit.box(_geo, Vector3(w, 0.18, 0.02), Vector3(side * (1.3 + w * 0.5), 2.62, zf + 1.02), awning)
	# Tente altı gece spotları ve tabela ışığı
	for sx in [-4.5, -2.0, 2.0, 4.5]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(sx, 2.7, zf + 0.6)
		sp.rotation_degrees = Vector3(-80, 0, 0)
		sp.spot_range = 4.0
		sp.spot_angle = 50.0
		sp.light_energy = 2.0
		sp.light_color = Color(1.0, 0.86, 0.66)
		sp.visible = false
		add_child(sp)
		_street_lights.append([sp, null])
	var sign_light := OmniLight3D.new()
	sign_light.position = Vector3(0, H - 0.1, zf + 0.9)
	sign_light.omni_range = 4.0
	sign_light.light_energy = 1.2
	sign_light.light_color = Color(0.7, 0.9, 1.0)
	sign_light.visible = false
	add_child(sign_light)
	_street_lights.append([sign_light, null])
	# Sokak eşyaları
	for bx in [-6.0, -4.0, -2.4, 2.4, 4.0, 6.0]:
		_city("Prop_Bollard", Vector3(bx, -0.01, zf + 3.0))
	for lx in [-6.8, 6.8]:
		_street_lamp(Vector3(lx, 0, zf + 2.9))
	_city("Prop_Planter_Single", Vector3(W * 0.5 + 4.0, -0.01, zf + 1.5))
	_city("Prop_Planter_Single", Vector3(x0 - 4.0, -0.01, zf + 1.5))
	_city("Prop_ManholeCover", Vector3(3.0, -0.149, zf + 5.0))
	_city("Prop_ACUnit", Vector3(-3.0, H + 2.0, zf + 0.02))
	# Dış tabela (koyu panel, aydınlatmalı yazı)
	var board := MeshKit.box(_geo, Vector3(6.4, 0.75, 0.14), Vector3(0, H - 0.08, zf + 0.08), MeshKit.mat(Color(0.04, 0.12, 0.15), 0.35, 0.3))
	board.name = "SignBoard"
	var lbl := Label3D.new()
	_sign_lbl = lbl
	lbl.text = str(Game.settings.name)
	lbl.font_size = 96
	lbl.pixel_size = 0.005
	lbl.modulate = Color(1.6, 1.7, 1.8)
	lbl.outline_size = 0
	lbl.position = Vector3(0, H - 0.08, zf + 0.16)
	add_child(lbl)


func _street_lamp(pos: Vector3) -> void:
	var dark := MeshKit.mat(Color(0.08, 0.09, 0.1), 0.4, 0.7)
	MeshKit.cylinder(self, 0.06, 4.2, pos + Vector3(0, 2.1, 0), dark, 12)
	MeshKit.cylinder(self, 0.12, 0.3, pos + Vector3(0, 0.15, 0), dark, 12)
	var arm := MeshKit.box(self, Vector3(0.06, 0.06, 0.9), pos + Vector3(0, 4.15, -0.4), dark)
	arm.name = "Arm"
	MeshKit.box(self, Vector3(0.3, 0.1, 0.5), pos + Vector3(0, 4.1, -0.85), dark)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.9, 0.7)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.85, 0.6)
	bulb_mat.emission_energy_multiplier = 0.0
	MeshKit.box(self, Vector3(0.24, 0.02, 0.42), pos + Vector3(0, 4.04, -0.85), bulb_mat)
	var l := SpotLight3D.new()
	l.position = pos + Vector3(0, 4.0, -0.85)
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.spot_angle = 60
	l.spot_range = 7.0
	l.light_energy = 3.0
	l.light_color = Color(1.0, 0.82, 0.6)
	l.visible = false
	add_child(l)
	_street_lights.append([l, bulb_mat])


func _lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-62, -28, 0)  # güneş cepheye ve vitrinden içeri vursun
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
	# Gömme spot lambalar: zeminde ışık havuzları oluşturur
	var rim := MeshKit.mat(Color(0.85, 0.85, 0.86), 0.3, 0.7)
	var x0: float = Game.room_min_x()
	var cols: int = int(round((W * 0.5 - x0) / 3.5))
	var dx: float = (W * 0.5 - x0) / cols
	for ci in cols:
		var x: float = x0 + dx * (ci + 0.5)
		for z in [-3.3, 0.0, 3.3]:
			MeshKit.cylinder(self, 0.11, 0.02, Vector3(x, H - 0.005, z), rim, 20)
			var disc := MeshKit.cylinder(self, 0.085, 0.01, Vector3(x, H - 0.012, z), _panel_mat, 20)
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var l := SpotLight3D.new()
			l.position = Vector3(x, H - 0.03, z)
			l.rotation_degrees = Vector3(-90, 0, 0)
			l.spot_range = 4.6
			l.spot_angle = 58.0
			l.spot_angle_attenuation = 0.8
			l.light_energy = 3.2
			l.light_color = Color(1.0, 0.91, 0.8)
			l.shadow_enabled = false
			add_child(l)
			_room_lights.append(l)
	# Sıcak dolgu ışıkları: duvar ve tavandan seken ışığı taklit eder
	for ci in range(0, cols, 2):
		var fx: float = x0 + dx * (ci + 1.0)
		for fz in [-2.0, 2.2]:
			var f := OmniLight3D.new()
			f.position = Vector3(fx, H - 0.6, fz)
			f.omni_range = 7.5
			f.light_energy = 0.55
			f.light_color = Color(1.0, 0.9, 0.78)
			f.light_specular = 0.1
			f.shadow_enabled = false
			add_child(f)
			_room_lights.append(f)
	_build_rain()
	Game.power_changed.connect(_on_power)
	Game.time_changed.connect(func(_m): _update_daylight())
	_update_daylight()


func _on_power(on: bool) -> void:
	for l in _room_lights:
		if not l.has_meta("e"):
			l.set_meta("e", l.light_energy)
		l.light_energy = float(l.get_meta("e")) if on else 0.05
	_panel_mat.emission_energy_multiplier = 2.5 if on else 0.0


## Gün ışığı saate ve havaya göre değişir; akşam dışarısı kararır.
func _update_daylight() -> void:
	var m: float = Game.minute
	# 08:00 tam gün, 17:00'den sonra batmaya başlar, 20:00 gece
	var day_f: float = 1.0 - smoothstep(17.0 * 60.0, 20.0 * 60.0, m)
	var weather_f: float = {"gunesli": 1.0, "bulutlu": 0.7, "yagmurlu": 0.4}.get(Game.weather, 1.0)
	# Gece de hafif soğuk bir ay ışığı kalır
	_sun.light_energy = max(1.1 * day_f * weather_f, 0.12)
	var dusk: float = smoothstep(16.5 * 60.0, 19.0 * 60.0, m) * (1.0 - smoothstep(19.0 * 60.0, 20.5 * 60.0, m))
	_sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.55, 0.3), dusk).lerp(Color(0.55, 0.65, 0.9), 1.0 - day_f)
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
	var lamps_on: bool = day_f < 0.7 or Game.weather == "yagmurlu" and day_f < 0.95
	for sl in _street_lights:
		sl[0].visible = lamps_on
		if sl[1]:
			sl[1].emission_energy_multiplier = 4.0 if lamps_on else 0.0
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
	var info: Dictionary = FurnitureDB.item(e.type)
	if not info.get("walkable", false):
		add_blob_shadow(n, info.size + Vector2(0.35, 0.35))
	return n


## Yumuşak temas gölgesi: eşyanın zemine "oturduğunu" hissettirir
static func add_blob_shadow(parent: Node3D, size: Vector2, strength: float = 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = Vector3(0, 0.012, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = MeshKit.shader_mat("res://shaders/blob_shadow.gdshader", {"strength": strength})
	parent.add_child(mi)
	return mi


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
