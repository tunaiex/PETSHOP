class_name Shop
extends Node3D
## Dükkânın tüm statik yapısı: oda, aydınlatma, akvaryumlar, kasa, raf, kapı, dış mekân.
## Müşteri yolları için önemli noktaları da tutar.

const W := 14.0
const D := 10.0
const H := 3.2
const WALL := 0.2

var entrance := Vector3(1.2, 0, 2.9)
var outside := Vector3(1.2, 0, 7.0)
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
	nm.filter_baking_aabb = AABB(Vector3(-8.0, -0.5, -5.0), Vector3(16.0, 3.0, 17.5))
	_geo.navigation_mesh = nm
	add_child(_geo)
	_furn_root = Node3D.new()
	_geo.add_child(_furn_root)
	_environment()
	_store_shell()
	_store_sign()
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


const SHELL := "res://assets/models/store/magaza.glb"
const SIGN_BAND := "res://assets/models/store/tabela_bandi.glb"
## Satış alanının iç sınırları (x0, z0, x1, z1) ve otomatik kapının ortası
const ROOM := Rect2(-4.7, -2.3, 9.4, 5.8)
const DOOR := Vector3(1.2, 0, 3.6)
const H_IN := 3.0

## Binanın parçalarından hangilerine ne tür çarpışma verileceği
const NO_COLLIDE := ["floor_", "ceiling", "roof_", "parapet", "sidewalk", "decal", "light", "speaker", "smoke", "exit_sign", "wall_clock", "poster", "bunting", "balloon", "convex_mirror", "security_camera", "wall_ac", "neon", "open_sign", "parking_space", "parking_curb", "speed_bump", "awning", "rooftop", "roof_hatch", "clipboard", "calculator", "price_gun", "box_cutter", "desk_radio", "cash_drawer", "first_aid", "cctv"]
const TRIMESH := ["wall_", "shopfront", "pillar", "stockroom_door"]


## Mağaza paketinin binası: zemin, duvarlar, vitrin, depo, tavan, çatı, otopark ve süsler.
func _store_shell() -> void:
	if not ResourceLoader.exists(SHELL):
		push_warning("Mağaza modeli yok: " + SHELL)
		return
	var shell: Node3D = (load(SHELL) as PackedScene).instantiate()
	FurnitureDB.hide_collision_meshes(shell)
	_geo.add_child(shell)
	# Zemin: içerisi, kaldırım ve otopark tek düz çarpışma
	_collider(_geo, Vector3(22, 0.1, 22), Vector3(0, -0.05, 3.0))
	for root in shell.get_children():
		_shell_collision(root)
		if str(root.name).begins_with("shopfront_entrance"):
			for c in root.find_children("slide_door*", "Node3D", true, false):
				if str(c.name).contains("left"):
					_door_l = c
				else:
					_door_r = c
	if _door_l:
		_door_l.set_meta("x0", _door_l.position.x)
	if _door_r:
		_door_r.set_meta("x0", _door_r.position.x)
	# Oyuncu otoparktan ileri gitmesin
	_collider(_geo, Vector3(0.2, 3, 9), Vector3(-8.2, 1.5, 8.5))
	_collider(_geo, Vector3(0.2, 3, 9), Vector3(8.2, 1.5, 8.5))
	_collider(_geo, Vector3(16.6, 3, 0.2), Vector3(0, 1.5, 12.8))
	# Yansıma probu: cam, su ve parlak zemin içeriyi yansıtsın
	var probe := ReflectionProbe.new()
	probe.size = Vector3(ROOM.size.x, H_IN, ROOM.size.y)
	probe.position = Vector3(ROOM.get_center().x, H_IN * 0.5, ROOM.get_center().y)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 0.6
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.42, 0.4, 0.37)
	add_child(probe)


func _shell_collision(root: Node) -> void:
	var nm: String = str(root.name)
	for k in NO_COLLIDE:
		if nm.begins_with(k) or nm.contains(k):
			return
	var trimesh := false
	for k in TRIMESH:
		if nm.begins_with(k):
			trimesh = true
	if trimesh:
		# Kapı ve pencere boşlukları açık kalsın: görünen mesh'ten üçgen çarpışma
		for c in root.find_children("*", "MeshInstance3D", true, false):
			var cn: String = str(c.name)
			if cn.contains("door") or cn.contains("shutter") or not c.visible:
				continue
			(c as MeshInstance3D).create_trimesh_collision()
		if root is MeshInstance3D and root.visible:
			(root as MeshInstance3D).create_trimesh_collision()
		return
	# Diğer eşyalar (dolap, masa, araba, bank...): sınır kutusu
	if not root is Node3D:
		return
	var n3: Node3D = root
	var box: AABB = MeshKit.model_aabb(n3)
	if root is MeshInstance3D:
		box = (root as MeshInstance3D).get_aabb()
	if box.size.y < 0.25 or box.size.x * box.size.z < 0.02:
		return
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position = box.get_center()
	b.add_child(cs)
	n3.add_child(b)


## Vitrin üstündeki tabela bandı ve dükkânın adı
func _store_sign() -> void:
	if ResourceLoader.exists(SIGN_BAND):
		var band: Node3D = (load(SIGN_BAND) as PackedScene).instantiate()
		band.position = Vector3(DOOR.x, 2.4, DOOR.z)
		band.rotation_degrees.y = 180
		add_child(band)
	var lbl := Label3D.new()
	_sign_lbl = lbl
	lbl.text = str(Game.settings.name)
	lbl.font_size = 64
	lbl.pixel_size = 0.0035
	lbl.modulate = Color(1.6, 1.7, 1.8)
	lbl.outline_size = 0
	lbl.position = Vector3(DOOR.x, 2.62, DOOR.z + 0.2)
	lbl.width = 600
	add_child(lbl)
	# Kapıda AÇIK/KAPALI tabelası ve dükkânı açma etkileşimi
	var door_h := 2.25
	var sign_lbl := Label3D.new()
	sign_lbl.font_size = 40
	sign_lbl.pixel_size = 0.004
	sign_lbl.position = Vector3(DOOR.x, door_h + 0.05, DOOR.z - 0.15)
	sign_lbl.rotation_degrees.y = 180
	sign_lbl.modulate = Color(0.85, 0.15, 0.1)
	sign_lbl.outline_size = 0
	sign_lbl.text = "KAPALI"
	add_child(sign_lbl)
	Game.phase_changed.connect(func(p): sign_lbl.text = "AÇIK" if p == "open" else "KAPALI"; sign_lbl.modulate = Color(0.1, 0.6, 0.2) if p == "open" else Color(0.85, 0.15, 0.1))
	Interactable.create(self, Vector3(1.9, 2.2, 0.3), Vector3(DOOR.x, 1.1, DOOR.z - 0.3), _door_prompt, _door_action)


## Duvar rengi / zemin ayarları bu binada sabit; sadece tabela adı değişir.
func apply_settings() -> void:
	if _sign_lbl:
		_sign_lbl.text = str(Game.settings.name)


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
	var stocked := false
	for sh in shelves:
		if Game.shelf_total(sh.entry()) > 0:
			stocked = true
	if not stocked and aquariums.filter(func(a): return not TankSim.living(Game.tanks[a.tank_id]).is_empty()).is_empty():
		Game.notify.emit("Satacak hiçbir şeyin yok! Rafları doldur ya da akvaryuma balık koy.", "bad")
		return
	Game.open_shop()
	Sfx.play("chime")


## İç aydınlatma: tavan panellerinin altında ılık nokta ışıklar + depo lambaları.
func _lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, -25, 0)  # güneş vitrinden içeri vursun
	_sun.light_energy = 1.1
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 30.0
	add_child(_sun)
	_panel_mat = StandardMaterial3D.new()
	for x in [-3.6, -1.2, 1.2, 3.6]:
		for z in [-1.4, 0.9, 2.9]:
			var l := OmniLight3D.new()
			l.position = Vector3(x, 2.75, z)
			l.omni_range = 4.2
			l.omni_attenuation = 1.2
			l.light_energy = 1.15
			l.light_color = Color(1.0, 0.95, 0.88)
			l.light_specular = 0.25
			l.shadow_enabled = false
			add_child(l)
			_room_lights.append(l)
	for x in [-3.0, 0.0, 3.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 2.7, -3.6)
		l.omni_range = 3.5
		l.light_energy = 0.9
		l.light_color = Color(1.0, 0.96, 0.9)
		add_child(l)
		_room_lights.append(l)
	# Dış mekân: gece sokak lambaları ve vitrin ışığı
	for lp in [Vector3(4.4, 3.6, 5.25), Vector3(-4.4, 3.6, 5.25), Vector3(-5.4, 5.5, 8.4)]:
		var sp := SpotLight3D.new()
		sp.position = lp
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.spot_range = 7.0
		sp.spot_angle = 60.0
		sp.light_energy = 2.5
		sp.light_color = Color(1.0, 0.82, 0.6)
		sp.visible = false
		add_child(sp)
		_street_lights.append([sp, null])
	_build_rain()
	Game.power_changed.connect(_on_power)
	Game.time_changed.connect(func(_m): _update_daylight())
	_update_daylight()


func _on_power(on: bool) -> void:
	for l in _room_lights:
		if not l.has_meta("e"):
			l.set_meta("e", l.light_energy)
		l.light_energy = float(l.get_meta("e")) if on else 0.05


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
	_rain.position = Vector3(0, 7, 8.0)
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
	_clock.position = Vector3(4.66, 2.45, 2.4)
	_clock.rotation_degrees.y = -90
	_clock.text = Game.clock_text()
	add_child(_clock)
	MeshKit.box(self, Vector3(0.04, 0.4, 0.9), Vector3(4.69, 2.45, 2.4), MeshKit.mat(Color(0.05, 0.05, 0.05), 0.3))


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
		if n is AquariumRack:
			n.refresh()
	for uid in nodes.keys():
		if not seen.has(uid):
			nodes[uid].queue_free()
			nodes.erase(uid)
	_index()
	request_bake()


func spawn(e: Dictionary) -> Node3D:
	var n: Node3D
	if FurnitureDB.is_pen(e.type):
		var pn := Aquarium.new()
		pn.furniture_uid = int(e.uid)
		_furn_root.add_child(pn)
		pn.setup_pen(int(e.tank), str(FurnitureDB.item(e.type).pen))
		n = pn
	elif FurnitureDB.is_tank(e.type):
		var aq := Aquarium.new()
		aq.furniture_uid = int(e.uid)
		_furn_root.add_child(aq)
		aq.setup(int(e.tank), e.type == "akvaryum_ceviz", e.type == "teraryum")
		n = aq
	elif FurnitureDB.is_rack(e.type):
		var rk := AquariumRack.new()
		_furn_root.add_child(rk)
		rk.setup(int(e.uid))
		n = rk
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
		elif n is AquariumRack:
			aquariums.append_array(n.aquariums())
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
		box.position = Vector3(-1.45 + col * 0.5, stack * 0.36, 4.1 + row * 0.5)
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
		_door_l.position.x = float(_door_l.get_meta("x0")) - _door_open * 0.9
	if _door_r:
		_door_r.position.x = float(_door_r.get_meta("x0")) + _door_open * 0.9
