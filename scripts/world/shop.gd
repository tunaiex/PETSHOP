class_name Shop
extends Node3D
## Dükkânın tüm statik yapısı: oda, aydınlatma, akvaryumlar, kasa, raf, kapı, dış mekân.
## Müşteri yolları için önemli noktaları da tutar.

const W := 14.0
const D := 10.0
const H := 3.2
const WALL := 0.2

var aquariums: Array = []
var register_point := Vector3(4.3, 0, 2.05)   ## Kasada bekleyen müşterinin yeri
var queue_points: Array = [Vector3(3.2, 0, 1.4), Vector3(2.2, 0, 1.4), Vector3(1.2, 0, 1.4), Vector3(0.2, 0, 1.4)]
var entrance := Vector3(0, 0, 3.6)
var outside := Vector3(0, 0, 8.5)
var shelf_point := Vector3(5.4, 0, -2.0)
var shelf_look := Vector3(7.0, 1.0, -2.0)
var hub := Vector3(0, 0, 0.8)

var _door_l: Node3D
var _door_r: Node3D
var _door_open: float = 0.0
var _clock: Label3D
var _shelf_root: Node3D
var hud: Node  ## main tarafından atanır


func build() -> void:
	_environment()
	_room()
	_front_wall()
	_outside()
	_lights()
	_place_aquariums()
	_counter()
	_shelf()
	_decor()
	Game.stock_changed.connect(_fill_shelf)
	Game.time_changed.connect(func(_m): _clock.text = Game.clock_text())


# ------------------------------------------------------------------ Ortam

func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
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
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _room() -> void:
	var floor_mat := MeshKit.shader_mat("res://shaders/wood_floor.gdshader")
	var fl := MeshKit.box(self, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), floor_mat, true)
	fl.name = "Floor"
	var wall_mat := MeshKit.shader_mat("res://shaders/wall.gdshader")
	# Arka, sol, sağ duvar
	MeshKit.box(self, Vector3(W + WALL * 2, H, WALL), Vector3(0, H * 0.5, -D * 0.5 - WALL * 0.5), wall_mat, true)
	MeshKit.box(self, Vector3(WALL, H, D), Vector3(-W * 0.5 - WALL * 0.5, H * 0.5, 0), wall_mat, true)
	MeshKit.box(self, Vector3(WALL, H, D), Vector3(W * 0.5 + WALL * 0.5, H * 0.5, 0), wall_mat, true)
	# Tavan
	var ceil_mat := MeshKit.mat(Color(0.93, 0.93, 0.91), 0.95)
	MeshKit.box(self, Vector3(W + WALL * 2, 0.12, D + WALL * 2), Vector3(0, H + 0.06, 0), ceil_mat)
	# Süpürgelik ve tavan pervazı
	var trim := MeshKit.mat(Color(0.95, 0.95, 0.93), 0.5)
	for z in [-D * 0.5 + 0.01]:
		MeshKit.box(self, Vector3(W, 0.08, 0.02), Vector3(0, H - 0.04, z), trim)
	for x in [-W * 0.5 + 0.01, W * 0.5 - 0.01]:
		MeshKit.box(self, Vector3(0.02, 0.08, D), Vector3(x, H - 0.04, 0), trim)


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
		var cx: float = side * (door_w * 0.5 + (W * 0.5 - door_w * 0.5) * 0.5)
		var w: float = W * 0.5 - door_w * 0.5
		MeshKit.box(self, Vector3(w, win_lo, WALL), Vector3(cx, win_lo * 0.5, z), wall_mat, true)
		MeshKit.box(self, Vector3(w, H - win_hi, WALL), Vector3(cx, (H + win_hi) * 0.5, z), wall_mat)
		# Cam
		var glass := MeshKit.shader_mat("res://shaders/glass.gdshader", {"tint": Color(0.85, 0.92, 0.95)})
		MeshKit.box(self, Vector3(w, win_hi - win_lo, 0.02), Vector3(cx, (win_lo + win_hi) * 0.5, z), glass, true)
		# Kayıtlar
		MeshKit.box(self, Vector3(w, 0.06, 0.12), Vector3(cx, win_lo, z), frame)
		MeshKit.box(self, Vector3(w, 0.06, 0.12), Vector3(cx, win_hi, z), frame)
		var n := 3
		for i in n + 1:
			var x: float = cx - w * 0.5 + w * float(i) / n
			MeshKit.box(self, Vector3(0.06, win_hi - win_lo, 0.12), Vector3(x, (win_lo + win_hi) * 0.5, z), frame)
	MeshKit.box(self, Vector3(door_w, H - door_h, WALL), Vector3(0, (H + door_h) * 0.5, z), wall_mat)
	MeshKit.box(self, Vector3(door_w + 0.1, 0.08, 0.14), Vector3(0, door_h, z), frame)
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
			return "Dükkânı aç (saat 09:00 başlar)"
		"open":
			return "Dükkân açık. Kapanış 19:00"
		"closing":
			return "Kapanıyor... son müşteriler"
	return ""


func _door_action(_p: Node) -> void:
	if Game.phase == "prep":
		Game.open_shop()


func _outside() -> void:
	var walk := MeshKit.mat(Color(0.62, 0.6, 0.58), 0.9)
	MeshKit.box(self, Vector3(60, 0.1, 6), Vector3(0, -0.06, D * 0.5 + 3.1), walk, true)
	var road := MeshKit.mat(Color(0.18, 0.18, 0.2), 0.85)
	MeshKit.box(self, Vector3(60, 0.1, 8), Vector3(0, -0.2, D * 0.5 + 10), road)
	# Karşı binalar
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := -28.0
	while x < 28.0:
		var bw: float = rng.randf_range(5, 9)
		var bh: float = rng.randf_range(7, 16)
		var col := Color.from_hsv(rng.randf_range(0.05, 0.12), rng.randf_range(0.1, 0.35), rng.randf_range(0.6, 0.85))
		MeshKit.box(self, Vector3(bw - 0.3, bh, 6), Vector3(x + bw * 0.5, bh * 0.5 - 0.2, D * 0.5 + 17), MeshKit.mat(col, 0.9))
		var win := MeshKit.mat(Color(0.25, 0.32, 0.4), 0.15, 0.3)
		var fy := 1.5
		while fy < bh - 1.0:
			var fx := x + 1.0
			while fx < x + bw - 1.0:
				MeshKit.box(self, Vector3(0.9, 1.2, 0.05), Vector3(fx + 0.45, fy, D * 0.5 + 13.98), win)
				fx += 1.8
			fy += 2.6
		x += bw
	# Dış tabela
	var board := MeshKit.box(self, Vector3(6.0, 0.7, 0.12), Vector3(0, H - 0.1, D * 0.5 + WALL + 0.08), MeshKit.mat(Color(0.06, 0.25, 0.32), 0.4))
	board.name = "SignBoard"
	var lbl := Label3D.new()
	lbl.text = "AKVARYUM DÜKKÂNI"
	lbl.font_size = 96
	lbl.pixel_size = 0.005
	lbl.modulate = Color(0.95, 0.97, 1.0)
	lbl.outline_size = 0
	lbl.position = Vector3(0, H - 0.1, D * 0.5 + WALL + 0.15)
	add_child(lbl)


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 160, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color(1, 1, 1)
	panel.emission_enabled = true
	panel.emission = Color(1.0, 0.96, 0.88)
	panel.emission_energy_multiplier = 2.5
	var rim := MeshKit.mat(Color(0.8, 0.8, 0.8), 0.4, 0.5)
	for x in [-4.0, 0.0, 4.0]:
		for z in [-2.5, 1.5]:
			MeshKit.cylinder(self, 0.2, 0.03, Vector3(x, H - 0.005, z), rim)
			MeshKit.cylinder(self, 0.17, 0.02, Vector3(x, H - 0.02, z), panel)
			var l := OmniLight3D.new()
			l.position = Vector3(x, H - 0.4, z)
			l.omni_range = 6.5
			l.light_energy = 0.75
			l.light_color = Color(1.0, 0.95, 0.86)
			l.shadow_enabled = false
			add_child(l)
	# Kasa üstünde sarkıt lambalar
	for x in [3.8, 5.2]:
		var cord := MeshKit.cylinder(self, 0.006, 1.0, Vector3(x, H - 0.5, 3.0), MeshKit.mat(Color(0.05, 0.05, 0.05)), 6)
		cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shade := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.2
		cm.height = 0.22
		shade.mesh = cm
		shade.position = Vector3(x, H - 1.1, 3.0)
		shade.material_override = MeshKit.mat(Color(0.08, 0.2, 0.22), 0.35, 0.3)
		add_child(shade)
		var bulb := MeshKit.cylinder(self, 0.06, 0.02, Vector3(x, H - 1.21, 3.0), panel)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sl := SpotLight3D.new()
		sl.position = Vector3(x, H - 1.2, 3.0)
		sl.rotation_degrees = Vector3(-90, 0, 0)
		sl.spot_range = 3.0
		sl.spot_angle = 50
		sl.light_energy = 1.4
		sl.light_color = Color(1.0, 0.9, 0.75)
		add_child(sl)


func _place_aquariums() -> void:
	var spots := [
		[Vector3(-3.6, 0, -D * 0.5 + 0.32), 0.0],
		[Vector3(0.0, 0, -D * 0.5 + 0.32), 0.0],
		[Vector3(3.6, 0, -D * 0.5 + 0.32), 0.0],
		[Vector3(-W * 0.5 + 0.32, 0, -1.6), 90.0],
		[Vector3(-W * 0.5 + 0.32, 0, 1.6), 90.0],
	]
	for i in spots.size():
		var aq := Aquarium.new()
		aq.position = spots[i][0]
		aq.rotation_degrees.y = spots[i][1]
		add_child(aq)
		aq.setup(i)
		aquariums.append(aq)


func _counter() -> void:
	var base_mat := MeshKit.mat(Color(0.93, 0.92, 0.9), 0.5)
	var wood := MeshKit.shader_mat("res://shaders/wood_floor.gdshader", {"wood_a": Color(0.7, 0.52, 0.34), "wood_b": Color(0.55, 0.38, 0.24), "plank": Vector2(3.0, 0.6)})
	MeshKit.box(self, Vector3(3.0, 0.98, 0.6), Vector3(4.7, 0.49, 3.0), base_mat, true)
	MeshKit.box(self, Vector3(3.1, 0.05, 0.7), Vector3(4.7, 1.0, 3.0), wood)
	# Ön panelde şerit ve yazı
	MeshKit.box(self, Vector3(3.0, 0.12, 0.01), Vector3(4.7, 0.75, 2.695), MeshKit.mat(Color(0.06, 0.45, 0.52), 0.4))
	var lbl := Label3D.new()
	lbl.text = "KASA"
	lbl.font_size = 64
	lbl.pixel_size = 0.0025
	lbl.modulate = Color(1, 1, 1)
	lbl.outline_size = 0
	lbl.position = Vector3(4.3, 0.75, 2.685)
	add_child(lbl)
	# Yazar kasa
	var dark := MeshKit.mat(Color(0.12, 0.12, 0.13), 0.35)
	MeshKit.box(self, Vector3(0.4, 0.1, 0.35), Vector3(4.3, 1.075, 3.05), dark)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.05, 0.1, 0.15)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.3, 0.75, 0.9)
	screen_mat.emission_energy_multiplier = 0.8
	var scr := MeshKit.box(self, Vector3(0.3, 0.2, 0.02), Vector3(4.3, 1.25, 3.12), screen_mat)
	scr.rotation_degrees.x = -15
	MeshKit.box(self, Vector3(0.04, 0.15, 0.04), Vector3(4.3, 1.15, 3.15), dark)
	Interactable.create(self, Vector3(0.6, 0.5, 0.6), Vector3(4.3, 1.2, 3.05), _register_prompt, func(p): p.hud.open_register())
	# Tedarik tableti
	var tab := MeshKit.box(self, Vector3(0.32, 0.015, 0.22), Vector3(5.5, 1.04, 3.0), dark)
	tab.rotation_degrees.x = 12
	var tscr := StandardMaterial3D.new()
	tscr.albedo_color = Color(0.1, 0.2, 0.3)
	tscr.emission_enabled = true
	tscr.emission = Color(0.4, 0.8, 1.0)
	tscr.emission_energy_multiplier = 0.7
	var ts := MeshKit.box(self, Vector3(0.28, 0.004, 0.18), Vector3(5.5, 1.05, 3.0), tscr)
	ts.rotation_degrees.x = 12
	Interactable.create(self, Vector3(0.5, 0.3, 0.4), Vector3(5.5, 1.1, 3.0), func(): return "Tedarik tableti: Sipariş ver", func(p): p.hud.open_supplier())
	# Duvar saati
	_clock = Label3D.new()
	_clock.font_size = 96
	_clock.pixel_size = 0.003
	_clock.modulate = Color(0.9, 0.25, 0.2)
	_clock.outline_size = 0
	_clock.position = Vector3(W * 0.5 - 0.02, 2.5, 2.8)
	_clock.rotation_degrees.y = -90
	_clock.text = Game.clock_text()
	add_child(_clock)
	MeshKit.box(self, Vector3(0.04, 0.4, 0.9), Vector3(W * 0.5 - 0.02, 2.5, 2.8), MeshKit.mat(Color(0.05, 0.05, 0.05), 0.3))
	_clock.position.x -= 0.03


func _register_prompt() -> String:
	var c: Node = hud.main.customer_at_register() if hud and hud.main else null
	if c:
		return "Kasa: Müşteriyle pazarlık yap"
	return "Kasa: Bekleyen müşteri yok"


func _shelf() -> void:
	_shelf_root = Node3D.new()
	_shelf_root.position = Vector3(W * 0.5 - 0.25, 0, -2.0)
	_shelf_root.rotation_degrees.y = -90
	add_child(_shelf_root)
	var cream := MeshKit.mat(Color(0.93, 0.9, 0.84), 0.55)
	var wood := MeshKit.shader_mat("res://shaders/wood_floor.gdshader", {"wood_a": Color(0.5, 0.33, 0.2), "wood_b": Color(0.38, 0.24, 0.14), "plank": Vector2(3.0, 0.4)})
	var sw := 2.4
	var sh := 1.9
	var r := 0.25
	for side in [-1.0, 1.0]:
		MeshKit.box(_shelf_root, Vector3(0.1, sh - r, 0.4), Vector3(side * (sw * 0.5 - 0.05), (sh - r) * 0.5, 0), cream)
		var corner := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.4
		cm.radial_segments = 32
		corner.mesh = cm
		corner.material_override = cream
		corner.rotation_degrees.x = 90
		corner.position = Vector3(side * (sw * 0.5 - r), sh - r, 0)
		_shelf_root.add_child(corner)
	MeshKit.box(_shelf_root, Vector3(sw - r * 2, 0.1, 0.4), Vector3(0, sh - 0.05, 0), cream)
	# İç kısmı kapatan ince arka panel (köşe silindirlerinin iç yarısını gizler)
	MeshKit.box(_shelf_root, Vector3(sw - 0.2, sh - 0.12, 0.02), Vector3(0, (sh - 0.12) * 0.5, -0.19), cream)
	for i in 4:
		MeshKit.box(_shelf_root, Vector3(sw - 0.2, 0.035, 0.36), Vector3(0, 0.18 + i * 0.42, 0.01), wood)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(sw, sh, 0.45)
	cs.shape = shape
	cs.position = Vector3(0, sh * 0.5, 0)
	body.add_child(cs)
	_shelf_root.add_child(body)
	var it := Interactable.create(_shelf_root, Vector3(sw, sh, 0.5), Vector3(0, sh * 0.5, 0.05), func(): return "Ürün rafı: Stok", func(p): p.hud.open_stock())
	it.collision_layer = 1
	_fill_shelf()


func _fill_shelf() -> void:
	var holder: Node3D = _shelf_root.get_node_or_null("Items")
	if holder:
		holder.free()
	holder = Node3D.new()
	holder.name = "Items"
	_shelf_root.add_child(holder)
	var ids: Array = ProductDB.ids()
	for idx in ids.size():
		var pid: String = ids[idx]
		var p: Dictionary = ProductDB.get_product(pid)
		var row: int = 2 - idx / 2
		var half: int = idx % 2
		var y: float = 0.18 + row * 0.42 + 0.0175
		var count: int = min(int(Game.stock.get(pid, 0)), 8)
		for k in count:
			var x: float = -1.0 + half * 1.08 + (k % 4) * 0.24
			var z: float = 0.06 - (k / 4) * 0.14
			_product_mesh(holder, p, Vector3(x, y, z))


func _product_mesh(parent: Node3D, p: Dictionary, pos: Vector3) -> void:
	var col: Color = p.color
	var m := MeshKit.mat(col, 0.45)
	var label := MeshKit.mat(Color(0.95, 0.95, 0.92), 0.6)
	match p.shape:
		"can":
			MeshKit.cylinder(parent, 0.045, 0.13, pos + Vector3(0, 0.065, 0), m, 16)
			MeshKit.cylinder(parent, 0.046, 0.05, pos + Vector3(0, 0.07, 0), label, 16)
			MeshKit.cylinder(parent, 0.046, 0.01, pos + Vector3(0, 0.135, 0), MeshKit.mat(Color(0.8, 0.8, 0.82), 0.25, 0.9), 16)
		"bottle":
			MeshKit.cylinder(parent, 0.035, 0.16, pos + Vector3(0, 0.08, 0), m, 14)
			MeshKit.cylinder(parent, 0.036, 0.06, pos + Vector3(0, 0.07, 0), label, 14)
			MeshKit.cylinder(parent, 0.018, 0.04, pos + Vector3(0, 0.18, 0), MeshKit.mat(Color(0.95, 0.95, 0.95), 0.4), 10)
		"bag":
			var b := MeshKit.box(parent, Vector3(0.17, 0.24, 0.07), pos + Vector3(0, 0.12, 0), m)
			b.rotation_degrees.x = -6
			MeshKit.box(parent, Vector3(0.12, 0.08, 0.072), pos + Vector3(0, 0.12, 0), label)
		_:
			MeshKit.box(parent, Vector3(0.17, 0.2, 0.1), pos + Vector3(0, 0.1, 0), m)
			MeshKit.box(parent, Vector3(0.172, 0.05, 0.102), pos + Vector3(0, 0.15, 0), label)


func _decor() -> void:
	# Saksı bitkileri
	for pos in [Vector3(-6.3, 0, 4.3), Vector3(6.4, 0, -4.4), Vector3(-6.4, 0, -4.4)]:
		var pot := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.16
		cm.height = 0.45
		pot.mesh = cm
		pot.position = pos + Vector3(0, 0.225, 0)
		pot.material_override = MeshKit.mat(Color(0.85, 0.83, 0.8), 0.6)
		add_child(pot)
		var plant := MeshInstance3D.new()
		plant.mesh = MeshKit.sword_plant(int(pos.x * 10 + pos.z), 14, 0.3)
		plant.scale = Vector3.ONE * 2.6
		plant.position = pos + Vector3(0, 0.42, 0)
		plant.material_override = MeshKit.shader_mat("res://shaders/plant.gdshader", {"base_color": Color(0.08, 0.28, 0.08), "tip_color": Color(0.35, 0.65, 0.2), "sway": 0.0})
		add_child(plant)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.3
		sh.height = 1.2
		cs.shape = sh
		cs.position = Vector3(0, 0.6, 0)
		body.add_child(cs)
		body.position = pos
		add_child(body)
	# Posterler: çerçevede tür tanıtımı
	_poster(Vector3(-1.8, 2.15, -D * 0.5 + 0.02), 0.0, "diskus", "Diskus\nSymphysodon discus")
	_poster(Vector3(1.8, 2.15, -D * 0.5 + 0.02), 0.0, "melek", "Melek Balığı\nPterophyllum scalare")
	_poster(Vector3(-W * 0.5 + 0.02, 2.15, 0.0), 90.0, "beta", "Beta\nBetta splendens")
	# Paspas
	MeshKit.box(self, Vector3(1.8, 0.012, 1.0), Vector3(0, 0.006, 4.3), MeshKit.mat(Color(0.2, 0.22, 0.24), 0.95))


func _poster(pos: Vector3, rot_y: float, species: String, text: String) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	MeshKit.box(root, Vector3(0.75, 0.95, 0.03), Vector3(0, 0, 0.015), MeshKit.mat(Color(0.08, 0.07, 0.06), 0.4))
	MeshKit.box(root, Vector3(0.65, 0.85, 0.01), Vector3(0, 0, 0.032), MeshKit.mat(Color(0.95, 0.93, 0.87), 0.8))
	var s: Dictionary = FishDB.get_species(species)
	var fish := MeshInstance3D.new()
	fish.mesh = MeshKit.fish_mesh(species)
	fish.material_override = MeshKit.shader_mat("res://shaders/fish.gdshader", {
		"body_color": s.body, "belly_color": s.belly, "accent_color": s.accent, "fin_color": s.fin,
		"fin_alpha": 1.0, "pattern": s.pattern, "fish_len": s.length, "swim": 0.15,
	})
	fish.rotation_degrees.y = 90
	var k: float = 0.42 / float(s.length)
	fish.scale = Vector3(k * 0.12, k, k)
	fish.position = Vector3(0, 0.08, 0.05)
	root.add_child(fish)
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 28
	lbl.pixel_size = 0.0018
	lbl.modulate = Color(0.12, 0.12, 0.12)
	lbl.outline_size = 0
	lbl.position = Vector3(0, -0.32, 0.04)
	root.add_child(lbl)


func _process(delta: float) -> void:
	# Kapı, yakında müşteri ya da oyuncu varsa açılır.
	var want: float = 0.0
	if hud and hud.main and hud.main.someone_near_door():
		want = 1.0
	_door_open = move_toward(_door_open, want, delta * 2.0)
	if _door_l:
		_door_l.position.x = -0.5 - _door_open * 0.95
		_door_r.position.x = 0.5 + _door_open * 0.95
