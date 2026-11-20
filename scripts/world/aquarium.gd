class_name Aquarium
extends Node3D
## Dolap üstünde akvaryum: cam, su, çakıl, bitki, kaya, kök, ışık, kabarcık ve balıklar.
## Verisi Game.tanks[tank_id] içinde. Görsel, veriyle düzenli aralıklarla eşitlenir.

const TW := 1.3
const TH := 0.55
const TD := 0.5
const STAND_H := 0.82
const GRAVEL := 0.07
const CABINET_MODEL := "res://assets/models/props/akvaryum_dolabi.glb"
const RACK_TANK_MODEL := "res://assets/models/props/isikli_akvaryum.glb"
## Raf akvaryumu iç ölçüleri (yaklaşık 95 × 50 × 52 cm cam tank)
const RACK_TW := 0.9
const RACK_TH := 0.48
const RACK_TD := 0.45

var tank_id: int = 0
var wood_stand: bool = false ## true: hazır ceviz dolap modeli, false: beyaz modern dolap
var _built_salt: bool = false
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
var _light: Light3D
var _built_unlocked: bool = false
var _sync_timer: float = 0.0
var _tw: float = TW
var _th: float = TH
var _td: float = TD
var _y0: float = STAND_H + 0.025
var _water_h: float = TH - 0.06
## Raf akvaryumu ise kat numarası (0 alt kat), değilse -1
var rack_level: int = -1
## "hamster" / "civciv": suyu olmayan hayvan kafesi. "" ise akvaryum.
var pen: String = ""
const PEN_MODEL_CHICK := "res://assets/models/props/civciv_kafesi.glb"
const CHICK_D := 1.05      ## civciv kafesi çapı
const CHICK_FLOOR := 0.07  ## kafes tabanı yüksekliği
var _rack_size: Vector2 = Vector2.ZERO


var terrarium: bool = false


func setup(id: int, wood: bool = false, terra: bool = false) -> void:
	tank_id = id
	terrarium = terra
	if terra:
		_water_h = _th * 0.42
	wood_stand = wood and ResourceLoader.exists(CABINET_MODEL)
	_build_static()
	_rebuild_content()
	Game.tank_changed.connect(_on_tank_changed)
	Game.power_changed.connect(func(on):
		if is_instance_valid(_light):
			_light.visible = on)


## 3 katlı rafın bir katındaki küçük ışıklı akvaryum. Düğüm kökü zemindedir,
## tank `y0` yüksekliğindeki raf tablasına oturur.
func setup_rack(id: int, level: int, y0: float, rack_size: Vector2, dims: Vector3 = Vector3.ZERO) -> void:
	rack_level = level
	_rack_size = rack_size
	if dims == Vector3.ZERO:
		dims = Vector3(RACK_TW, RACK_TH, RACK_TD)
	_tw = dims.x
	_th = dims.y
	_td = dims.z
	_y0 = y0 + 0.012
	_water_h = _th - 0.05
	setup(id)


## Mağaza rafının bir katına konan küçük ışıklı akvaryum (kök: raf ön yüzü, zeminde)
var shelf_level: int = -1


func setup_shelf(id: int, level: int, y0: float, size: Vector2, height: float) -> void:
	shelf_level = level
	rack_level = level   # ince çerçeveli raf akvaryumu görünümü ve tek satır etiket
	_rack_size = Vector2(size.x + 0.04, size.y + 0.04)
	_tw = size.x
	_td = size.y
	_th = clamp(height, 0.2, 0.4)
	_y0 = y0 + 0.01
	_water_h = _th - 0.04
	setup(id)


## Hamster / civciv kafesi kurulumu
var _pen_colors: Array = []
const BIRD_CAGE_MODEL := "res://assets/models/props/kus_kafesi.glb"
const BIRD_STAND := 0.75   ## kuş kafesi sehpasının üst yüzeyi
const BIRD_W := 0.72       ## kafes tabanı genişliği


func setup_pen(id: int, kind: String, colors: Array = []) -> void:
	pen = kind
	_pen_colors = colors
	if kind == "kus":
		_tw = BIRD_W - 0.08
		_td = BIRD_W * 0.8 - 0.08
		_th = 0.55
		_y0 = BIRD_STAND + 0.105
	elif kind == "hamster":
		_tw = RACK_TW
		_th = RACK_TH
		_td = RACK_TD
		_y0 = 0.78
	else:
		_tw = CHICK_D * 0.62
		_td = CHICK_D * 0.62
		_th = 0.42
		_y0 = CHICK_FLOOR
	_water_h = 0.06
	setup(id)


func _is_dry() -> bool:
	return pen != "" or TankSim.is_dry(data())


func data() -> Dictionary:
	return Game.tanks[tank_id]


func _on_tank_changed(id: int) -> void:
	if id == tank_id:
		sync()


# ------------------------------------------------------------------ İnşa

func _build_static() -> void:
	if pen == "hamster":
		_build_hamster_stand()
		_build_rack_tank()
		return
	if pen == "civciv":
		_build_chick_cage()
		return
	if pen == "kus":
		_build_bird_cage()
		return
	if rack_level >= 0:
		_build_rack_tank()
		return
	var dark := MeshKit.mat(Color(0.05, 0.05, 0.055), 0.35)
	if wood_stand:
		# Hazır model: 1.304 x 0.894 x 0.62 (üst tabla). Tank ölçüsüne uydur.
		var cab: Node3D = (load(CABINET_MODEL) as PackedScene).instantiate()
		cab.scale = Vector3((_tw + 0.04) / 1.304, (STAND_H + 0.025) / 0.894, (_td + 0.04) / 0.62)
		add_child(cab)
	else:
		var cabinet := MeshKit.mat(Color(0.87, 0.87, 0.85), 0.45)
		var seam := MeshKit.mat(Color(0.55, 0.55, 0.53), 0.6)
		MeshKit.box(self, Vector3(_tw + 0.04, STAND_H - 0.06, _td + 0.04), Vector3(0, STAND_H * 0.5 + 0.03, 0), cabinet)
		MeshKit.box(self, Vector3(_tw, 0.06, _td), Vector3(0, 0.03, -0.01), dark)
		# Dolap kapakları
		for i in 2:
			var x: float = -_tw / 6.0 + i * _tw / 3.0
			MeshKit.box(self, Vector3(0.004, STAND_H - 0.1, 0.004), Vector3(x, STAND_H * 0.5 + 0.03, _td * 0.5 + 0.021), seam)
		for i in 3:
			var x: float = -_tw / 3.0 + i * _tw / 3.0
			MeshKit.box(self, Vector3(0.012, 0.12, 0.012), Vector3(x + 0.12, STAND_H * 0.62, _td * 0.5 + 0.028), MeshKit.mat(Color(0.7, 0.7, 0.72), 0.25, 0.9))
		MeshKit.box(self, Vector3(_tw + 0.05, 0.025, _td + 0.05), Vector3(0, STAND_H + 0.0125, 0), dark)

	# Cam kenar çerçeveleri (siyah silikon görünümü)
	var y0 := _y0
	MeshKit.box(self, Vector3(_tw + 0.012, 0.022, _td + 0.012), Vector3(0, y0 + 0.011, 0), dark)
	for z in [-_td * 0.5, _td * 0.5]:
		MeshKit.box(self, Vector3(_tw + 0.012, 0.012, 0.014), Vector3(0, y0 + _th - 0.006, z), dark)
	for x in [-_tw * 0.5, _tw * 0.5]:
		MeshKit.box(self, Vector3(0.014, 0.012, _td + 0.012), Vector3(x, y0 + _th - 0.006, 0), dark)
		for z in [-_td * 0.5, _td * 0.5]:
			MeshKit.box(self, Vector3(0.012, _th, 0.012), Vector3(x, y0 + _th * 0.5, z), dark)

	# Arka fon (koyu lacivert, gerçek akvaryumlardaki gibi)
	var bg := StandardMaterial3D.new()
	bg.albedo_color = Color(0.02, 0.05, 0.07)
	bg.roughness = 0.9
	MeshKit.box(self, Vector3(_tw - 0.01, _th - 0.01, 0.004), Vector3(0, y0 + _th * 0.5, -_td * 0.5 - 0.004), bg)

	# Kapak / lamba
	var hood := MeshKit.box(self, Vector3(_tw + 0.03, 0.07, _td + 0.03), Vector3(0, y0 + _th + 0.035, 0), dark)
	hood.name = "Hood"
	# Küçük dijital gösterge
	var lcd := StandardMaterial3D.new()
	lcd.albedo_color = Color(0.1, 0.2, 0.35)
	lcd.emission_enabled = true
	lcd.emission = Color(0.3, 0.6, 1.0)
	lcd.emission_energy_multiplier = 1.5
	MeshKit.box(self, Vector3(0.09, 0.025, 0.004), Vector3(0, y0 + _th + 0.04, _td * 0.5 + 0.017), lcd)

	# Cam paneller
	_glass_mat = MeshKit.shader_mat("res://shaders/glass.gdshader")
	MeshKit.box(self, Vector3(_tw, _th, 0.008), Vector3(0, y0 + _th * 0.5, _td * 0.5), _glass_mat)
	MeshKit.box(self, Vector3(0.008, _th, _td), Vector3(-_tw * 0.5, y0 + _th * 0.5, 0), _glass_mat)
	MeshKit.box(self, Vector3(0.008, _th, _td), Vector3(_tw * 0.5, y0 + _th * 0.5, 0), _glass_mat)

	# Etiket
	_label = Label3D.new()
	_label.font_size = 26
	_label.pixel_size = 0.0011
	_label.outline_size = 0
	_label.modulate = Color(0.15, 0.15, 0.17)
	_label.position = Vector3(0, STAND_H - 0.1, _td * 0.5 + (0.045 if wood_stand else 0.022))
	if wood_stand:
		_label.modulate = Color(0.95, 0.9, 0.8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.double_sided = false
	add_child(_label)

	# Çarpışma + etkileşim
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_tw + 0.06, y0 + _th + 0.08, _td + 0.06)
	cs.shape = shape
	cs.position = Vector3(0, shape.size.y * 0.5, 0)
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)


## Raf akvaryumu: oyuncunun tasarladığı siyah çerçeveli model + oyunun cam, su ve LED'i.
func _build_rack_tank() -> void:
	var y0 := _y0
	if ResourceLoader.exists(RACK_TANK_MODEL):
		var m: Node3D = (load(RACK_TANK_MODEL) as PackedScene).instantiate()
		# Modelin kumunu ve camlarını gizle: kum, cam ve su oyunda çiziliyor.
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c
			var mat = mi.get_active_material(0)
			if mat is BaseMaterial3D and (mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_texture != null):
				mi.visible = false
		var box: AABB = MeshKit.model_aabb(m)
		# Model uzun kenarı Z'de: 90° döndürüp tank ölçüsüne uydur.
		var holder := Node3D.new()
		holder.rotation_degrees.y = 90.0
		m.scale = Vector3((_td + 0.03) / box.size.x, (_th + 0.025) / box.size.y, (_tw + 0.03) / box.size.z)
		m.position = -Vector3(box.get_center().x * m.scale.x, box.position.y * m.scale.y, box.get_center().z * m.scale.z)
		holder.position = Vector3(0, y0 - 0.012, 0)
		holder.add_child(m)
		add_child(holder)
	else:
		var dark := MeshKit.mat(Color(0.05, 0.05, 0.055), 0.35)
		for x in [-_tw * 0.5, _tw * 0.5]:
			for z in [-_td * 0.5, _td * 0.5]:
				MeshKit.box(self, Vector3(0.02, _th, 0.02), Vector3(x, y0 + _th * 0.5, z), dark)

	# Arka fon
	var bg := StandardMaterial3D.new()
	bg.albedo_color = Color(0.02, 0.05, 0.07)
	bg.roughness = 0.9
	MeshKit.box(self, Vector3(_tw - 0.01, _th - 0.01, 0.004), Vector3(0, y0 + _th * 0.5, -_td * 0.5 - 0.004), bg)

	# Cam paneller
	_glass_mat = MeshKit.shader_mat("res://shaders/glass.gdshader")
	MeshKit.box(self, Vector3(_tw, _th, 0.006), Vector3(0, y0 + _th * 0.5, _td * 0.5), _glass_mat)
	MeshKit.box(self, Vector3(0.006, _th, _td), Vector3(-_tw * 0.5, y0 + _th * 0.5, 0), _glass_mat)
	MeshKit.box(self, Vector3(0.006, _th, _td), Vector3(_tw * 0.5, y0 + _th * 0.5, 0), _glass_mat)

	# Dahili LED bar: ön üst kenarda ince ışık şeridi (lamba her zaman takılı gelir)
	var bar := MeshKit.mat(Color(0.08, 0.08, 0.09), 0.3, 0.6)
	MeshKit.box(self, Vector3(_tw - 0.04, 0.018, 0.05), Vector3(0, y0 + _th + 0.022, _td * 0.18), bar)
	var led := StandardMaterial3D.new()
	led.albedo_color = Color(0.85, 0.95, 1.0)
	led.emission_enabled = true
	led.emission = Color(0.7, 0.88, 1.0)
	led.emission_energy_multiplier = 4.0
	var strip := MeshKit.box(self, Vector3(_tw - 0.06, 0.004, 0.035), Vector3(0, y0 + _th + 0.011, _td * 0.18), led)
	strip.name = "LedStrip"
	for side in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.02, 0.03, _td * 0.6), Vector3(side * (_tw * 0.5 - 0.05), y0 + _th + 0.02, _td * 0.05), bar)

	# Etiket: ön camın alt kenarında, tek satır
	_label = Label3D.new()
	_label.font_size = 22
	_label.pixel_size = 0.001
	_label.outline_size = 5
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.modulate = Color(0.95, 0.95, 0.92)
	_label.position = Vector3(0, y0 + 0.012, _td * 0.5 + 0.008)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.double_sided = false
	_label.no_depth_test = false
	add_child(_label)

	# Çarpışma + etkileşim: bu katın tamamı
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var fp: Vector2 = _rack_size if _rack_size != Vector2.ZERO else Vector2(_tw + 0.06, _td + 0.06)
	shape.size = Vector3(fp.x, _th + 0.07, fp.y)
	cs.shape = shape
	cs.position = Vector3(0, y0 + shape.size.y * 0.5 - 0.02, 0)
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)


## Hamster kafesinin altındaki ahşap sehpa
func _build_hamster_stand() -> void:
	var wood := MeshKit.shader_mat("res://shaders/wood_floor.gdshader", {"wood_a": Color(0.62, 0.45, 0.28), "wood_b": Color(0.5, 0.35, 0.2), "plank": Vector2(4.0, 0.5)})
	var top_y: float = _y0 - 0.012
	MeshKit.box(self, Vector3(_tw + 0.1, 0.04, _td + 0.12), Vector3(0, top_y - 0.02, 0), wood)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			MeshKit.box(self, Vector3(0.05, top_y - 0.04, 0.05), Vector3(x * (_tw * 0.5 - 0.0), (top_y - 0.04) * 0.5, z * (_td * 0.5 - 0.0)), wood)
	MeshKit.box(self, Vector3(_tw, 0.025, _td), Vector3(0, 0.18, 0), wood)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_tw + 0.1, top_y, _td + 0.12)
	cs.shape = shape
	cs.position.y = top_y * 0.5
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)
	# Altta yedek talaş paketleri
	var bag := MeshKit.mat(Color(0.9, 0.82, 0.55), 0.8)
	for i in 2:
		var b := MeshKit.box(self, Vector3(0.22, 0.26, 0.14), Vector3(-0.2 + i * 0.26, 0.32, 0), bag)
		b.rotation_degrees.y = 8 - i * 14


## Kuş kafesi: ahşap sehpa + oyuncunun modelinin tabanı, kabı, tünekleri (renkli) + hafif tel
func _build_bird_cage() -> void:
	var wood := MeshKit.shader_mat("res://shaders/wood_floor.gdshader", {"wood_a": Color(0.55, 0.38, 0.22), "wood_b": Color(0.45, 0.3, 0.17), "plank": Vector2(4.0, 0.5)})
	var sw: float = BIRD_W + 0.08
	var sd: float = BIRD_W * 0.8 + 0.08
	MeshKit.box(self, Vector3(sw, 0.04, sd), Vector3(0, BIRD_STAND - 0.02, 0), wood)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			MeshKit.box(self, Vector3(0.04, BIRD_STAND - 0.04, 0.04), Vector3(x * (sw * 0.5 - 0.04), (BIRD_STAND - 0.04) * 0.5, z * (sd * 0.5 - 0.04)), wood)
	MeshKit.box(self, Vector3(sw - 0.08, 0.02, sd - 0.08), Vector3(0, 0.2, 0), wood)
	var top_h := 0.62
	if ResourceLoader.exists(BIRD_CAGE_MODEL):
		var m: Node3D = (load(BIRD_CAGE_MODEL) as PackedScene).instantiate()
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c
			var mat = mi.get_active_material(0)
			var mn: String = str(mat.resource_name) if mat else ""
			if mn == "cage_bar_mat":
				mi.visible = false   # teller: aşağıda hafif tel ile çizilir
			elif mat is BaseMaterial3D and _pen_colors.size() == 2 and (mn == "Base_Mat" or mn == "Bowl_Mat"):
				var d: BaseMaterial3D = mat.duplicate()
				d.albedo_color = _pen_colors[0] if mn == "Base_Mat" else _pen_colors[1]
				mi.material_override = d
		var box: AABB = MeshKit.model_aabb(m)
		var k: float = BIRD_W / max(box.size.x, 0.001)
		m.scale = Vector3.ONE * k
		m.position = Vector3(-box.get_center().x * k, BIRD_STAND - box.position.y * k, -box.get_center().z * k)
		add_child(m)
	# Teller: dikey çubuklu dört yüz ve üst
	var bars := MeshKit.shader_mat("res://shaders/wire_net.gdshader", {"wire_color": Color(0.92, 0.92, 0.9), "cells_u": 40.0, "cells_v": 3.0, "thickness": 0.12})
	var y_lo: float = _y0 - 0.01
	var w: float = BIRD_W - 0.02
	var d: float = BIRD_W * 0.8 - 0.02
	for face in [[Vector3(w, top_h, 0.002), Vector3(0, y_lo + top_h * 0.5, d * 0.5)], [Vector3(w, top_h, 0.002), Vector3(0, y_lo + top_h * 0.5, -d * 0.5)],
			[Vector3(0.002, top_h, d), Vector3(w * 0.5, y_lo + top_h * 0.5, 0)], [Vector3(0.002, top_h, d), Vector3(-w * 0.5, y_lo + top_h * 0.5, 0)],
			[Vector3(w, 0.002, d), Vector3(0, y_lo + top_h, 0)]]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var sz: Vector3 = face[0]
		if sz.y < 0.01:
			qm.size = Vector2(sz.x, sz.z)
			q.rotation_degrees.x = -90
		elif sz.x < 0.01:
			qm.size = Vector2(sz.z, sz.y)
			q.rotation_degrees.y = 90
		else:
			qm.size = Vector2(sz.x, sz.y)
		q.mesh = qm
		q.material_override = bars
		q.position = face[1]
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
	MeshKit.box(self, Vector3(0.03, 0.03, 0.03), Vector3(0, y_lo + top_h + 0.02, 0), MeshKit.mat(Color(0.9, 0.9, 0.88), 0.3, 0.6))
	_glass_mat = null
	_label = Label3D.new()
	_label.font_size = 22
	_label.pixel_size = 0.001
	_label.outline_size = 5
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, y_lo + top_h + 0.15, 0)
	add_child(_label)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(sw, y_lo + top_h, sd)
	cs.shape = shape
	cs.position.y = shape.size.y * 0.5
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)


## Yuvarlak tel civciv kafesi: oyuncunun modeli (ahşap taban + kapak) + hafif tel örgü
func _build_chick_cage() -> void:
	var h := 0.5
	if ResourceLoader.exists(PEN_MODEL_CHICK):
		var m: Node3D = (load(PEN_MODEL_CHICK) as PackedScene).instantiate()
		var box: AABB = MeshKit.model_aabb(m)
		var k: float = CHICK_D / max(box.size.x, box.size.z)
		m.scale = Vector3.ONE * k
		# Ahşap kapağın ortasını aç: içerideki civcivler görünsün
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c
			var ma: AABB = mi.get_aabb()
			if ma.size.x < 1.5:
				mi.visible = false   # yanlış yere düşen kapı parçaları
				continue
			var src = mi.get_active_material(0)
			var cut := MeshKit.shader_mat("res://shaders/cut_top.gdshader", {
				"cut_y": ma.position.y + ma.size.y * 0.88,
				"keep_r": ma.size.x * 0.5 * 0.86,
				"center": Vector2(ma.get_center().x, ma.get_center().z),
				"core_r": ma.size.x * 0.5 * 0.3,
				"core_y": ma.position.y + ma.size.y * 0.12,
			})
			if src is BaseMaterial3D:
				cut.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
				cut.set_shader_parameter("has_tex", (src as BaseMaterial3D).albedo_texture != null)
				cut.set_shader_parameter("albedo_color", (src as BaseMaterial3D).albedo_color)
			mi.material_override = cut
		m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
		add_child(m)
		h = box.size.y * k
	var net := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = CHICK_D * 0.5 - 0.02
	cm.bottom_radius = CHICK_D * 0.5 - 0.02
	cm.height = h - CHICK_FLOOR - 0.03
	cm.radial_segments = 40
	cm.cap_top = false
	cm.cap_bottom = false
	net.mesh = cm
	net.material_override = MeshKit.shader_mat("res://shaders/wire_net.gdshader")
	net.position.y = CHICK_FLOOR + cm.height * 0.5
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)
	_glass_mat = null
	_label = Label3D.new()
	_label.font_size = 22
	_label.pixel_size = 0.001
	_label.outline_size = 5
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, h + 0.12, 0)
	add_child(_label)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = CHICK_D * 0.5
	shape.height = h + 0.05
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)


## Suyu olmayan bölmelerin içi: talaş / toprak zemin, eşyalar, ışık
func _rebuild_dry_content(d: Dictionary) -> void:
	var y0 := _y0
	var gh := 0.03
	_gravel_mat = MeshKit.shader_mat("res://shaders/gravel.gdshader")
	if pen != "":
		# Talaş
		_gravel_mat.set_shader_parameter("color_a", Color(0.93, 0.82, 0.58))
		_gravel_mat.set_shader_parameter("color_b", Color(0.82, 0.66, 0.4))
		_gravel_mat.set_shader_parameter("scale", 60.0)
	else:
		# Toprak
		_gravel_mat.set_shader_parameter("color_a", Color(0.36, 0.26, 0.17))
		_gravel_mat.set_shader_parameter("color_b", Color(0.25, 0.18, 0.12))
		_gravel_mat.set_shader_parameter("scale", 40.0)
	if pen == "civciv":
		var floor_mi := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = CHICK_D * 0.5 - 0.03
		fm.bottom_radius = fm.top_radius
		fm.height = gh
		floor_mi.mesh = fm
		floor_mi.material_override = _gravel_mat
		floor_mi.position.y = y0 + gh * 0.5
		_content.add_child(floor_mi)
	else:
		MeshKit.box(_content, Vector3(_tw - 0.016, gh, _td - 0.016), Vector3(0, y0 + gh * 0.5, 0), _gravel_mat)
	var yf: float = y0 + gh
	match pen:
		"hamster":
			_build_hamster_props(yf)
		"civciv":
			_build_chick_props(yf)
		"kus":
			pass   # tünek, kap: kafes modelinde
		_:
			_build_decor(RandomNumberGenerator.new())
	# Işık (hamster kafesinde LED, kuru teraryumda lamba alınmışsa)
	if pen == "" and d.get("light", false) or pen == "hamster":
		_light = SpotLight3D.new()
		_light.position = Vector3(0, y0 + _th - 0.02, 0)
		_light.rotation_degrees = Vector3(-90, 0, 0)
		_light.spot_range = _th + 0.3
		_light.spot_angle = 70.0
		_light.light_energy = 1.6
		_light.light_color = Color(1.0, 0.95, 0.85)
		_light.shadow_enabled = false
		_light.visible = not Game.power_out
		_content.add_child(_light)
	_build_food_particles()


func _build_hamster_props(yf: float) -> void:
	var white := MeshKit.mat(Color(0.92, 0.92, 0.9), 0.4)
	var blue := MeshKit.mat(Color(0.3, 0.6, 0.9), 0.35)
	var red := MeshKit.mat(Color(0.85, 0.25, 0.2), 0.45)
	# Çark (sağ arka)
	var wheel := Node3D.new()
	wheel.position = Vector3(_tw * 0.5 - 0.14, yf + 0.13, -_td * 0.5 + 0.12)
	_content.add_child(wheel)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.105
	tm.outer_radius = 0.12
	tm.rings = 24
	ring.mesh = tm
	ring.material_override = blue
	ring.rotation_degrees.x = 90
	wheel.add_child(ring)
	var back := MeshKit.cylinder(wheel, 0.115, 0.01, Vector3(0, 0, -0.04), blue, 24)
	back.rotation_degrees.x = 90
	MeshKit.box(wheel, Vector3(0.03, 0.14, 0.03), Vector3(0, -0.07, -0.05), white)
	# Ev (sol)
	var house := Node3D.new()
	house.position = Vector3(-_tw * 0.5 + 0.13, yf, -0.05)
	_content.add_child(house)
	MeshKit.box(house, Vector3(0.16, 0.1, 0.14), Vector3(0, 0.05, 0), MeshKit.mat(Color(0.95, 0.85, 0.6), 0.6))
	var roof := MeshKit.box(house, Vector3(0.1, 0.012, 0.16), Vector3(-0.035, 0.12, 0), red)
	roof.rotation_degrees.z = 32
	var roof2 := MeshKit.box(house, Vector3(0.1, 0.012, 0.16), Vector3(0.035, 0.12, 0), red)
	roof2.rotation_degrees.z = -32
	MeshKit.box(house, Vector3(0.05, 0.05, 0.004), Vector3(0, 0.03, 0.071), MeshKit.mat(Color(0.15, 0.1, 0.06), 0.9))
	# Suluk (arka cama asılı)
	MeshKit.cylinder(_content, 0.025, 0.14, Vector3(0.05, yf + 0.2, -_td * 0.5 + 0.03), MeshKit.mat(Color(0.7, 0.85, 1.0), 0.1), 12)
	var spout := MeshKit.cylinder(_content, 0.005, 0.06, Vector3(0.05, yf + 0.11, -_td * 0.5 + 0.045), white, 6)
	spout.rotation_degrees.x = 25
	# Yem kabı
	MeshKit.cylinder(_content, 0.045, 0.025, Vector3(-0.05, yf + 0.012, 0.1), red, 16)
	MeshKit.cylinder(_content, 0.038, 0.012, Vector3(-0.05, yf + 0.022, 0.1), MeshKit.mat(Color(0.7, 0.55, 0.25), 0.9), 16)


func _build_chick_props(yf: float) -> void:
	var red := MeshKit.mat(Color(0.8, 0.2, 0.18), 0.45)
	# Yemlik ve suluk
	MeshKit.cylinder(_content, 0.07, 0.03, Vector3(-0.18, yf + 0.015, 0.05), red, 18)
	MeshKit.cylinder(_content, 0.05, 0.1, Vector3(-0.18, yf + 0.08, 0.05), MeshKit.mat(Color(0.9, 0.9, 0.85, 1.0), 0.3), 14)
	MeshKit.cylinder(_content, 0.07, 0.025, Vector3(0.2, yf + 0.012, -0.1), MeshKit.mat(Color(0.25, 0.5, 0.85), 0.3), 18)
	# Isı lambası (kapağın altında kırmızı ampul)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.35, 0.2)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.3, 0.15)
	bulb_mat.emission_energy_multiplier = 3.0
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	bulb.mesh = sm
	bulb.material_override = bulb_mat
	bulb.position = Vector3(0, _y0 + _th, 0)
	_content.add_child(bulb)
	var heat := OmniLight3D.new()
	heat.position = bulb.position - Vector3(0, 0.06, 0)
	heat.light_color = Color(1.0, 0.55, 0.3)
	heat.light_energy = 1.2
	heat.omni_range = 0.7
	heat.visible = not Game.power_out
	_content.add_child(heat)
	_light = heat


var furniture_uid: int = 0
var _equip_sig: String = ""


## Ekipman/dekor değişince görünümün yeniden kurulması gerekir.
func _signature() -> String:
	var d: Dictionary = data()
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [d.get("kind", ""), d.get("salt", false), d.get("gravel", ""), d.get("light", false), d.get("air", false), d.get("heater_on", false), d.filter, ",".join(PackedStringArray(d.get("decor", [])))]


func _gravel_h() -> float:
	return GRAVEL if str(data().get("gravel", "")) != "" else 0.008


func _rebuild_content() -> void:
	if _content:
		_content.queue_free()
	_fish.clear()
	_content = Node3D.new()
	add_child(_content)
	var d: Dictionary = data()
	_built_unlocked = d.unlocked
	_built_salt = bool(d.get("salt", false))
	_equip_sig = _signature()
	if _is_dry():
		_water_mat = null
		_surface_mat = null
		_rebuild_dry_content(d)
		sync()
		return
	var y0 := _y0
	var gh := _gravel_h()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + tank_id * 131

	# Taban: çakıl / kum ya da çıplak cam
	_gravel_mat = MeshKit.shader_mat("res://shaders/gravel.gdshader")
	match str(d.get("gravel", "")):
		"white":
			_gravel_mat.set_shader_parameter("color_a", Color(0.95, 0.92, 0.85))
			_gravel_mat.set_shader_parameter("color_b", Color(0.84, 0.81, 0.74))
			_gravel_mat.set_shader_parameter("scale", 95.0)
		"natural":
			pass
		_:
			_gravel_mat.set_shader_parameter("color_a", Color(0.12, 0.14, 0.15))
			_gravel_mat.set_shader_parameter("color_b", Color(0.08, 0.09, 0.1))
			_gravel_mat.set_shader_parameter("scale", 2.0)
	MeshKit.box(_content, Vector3(_tw - 0.016, gh, _td - 0.016), Vector3(0, y0 + gh * 0.5, 0), _gravel_mat)

	# Su
	_water_mat = MeshKit.shader_mat("res://shaders/water.gdshader")
	_surface_mat = MeshKit.shader_mat("res://shaders/water.gdshader", {"is_surface": true})
	if _built_salt:
		_water_mat.set_shader_parameter("clean_color", Color(0.35, 0.7, 0.95))
		_surface_mat.set_shader_parameter("clean_color", Color(0.35, 0.7, 0.95))
	MeshKit.box(_content, Vector3(_tw - 0.016, _water_h - gh, _td - 0.016), Vector3(0, y0 + gh + (_water_h - gh) * 0.5, 0), _water_mat)
	var surf := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(_tw - 0.016, _td - 0.016)
	pm.subdivide_width = 24
	pm.subdivide_depth = 10
	surf.mesh = pm
	surf.material_override = _surface_mat
	surf.position = Vector3(0, y0 + _water_h, 0)
	_content.add_child(surf)

	# Lamba
	if d.get("light", false):
		var led := StandardMaterial3D.new()
		led.albedo_color = Color(0.9, 0.95, 1.0)
		led.emission_enabled = true
		led.emission = Color(0.85, 0.95, 1.0)
		led.emission_energy_multiplier = 3.0
		MeshKit.box(_content, Vector3(_tw - 0.12, 0.004, 0.05), Vector3(0, y0 + _th - 0.002, 0), led)
		_light = SpotLight3D.new()
		_light.position = Vector3(0, y0 + _th - 0.02, 0)
		_light.rotation_degrees = Vector3(-90, 0, 0)
		_light.spot_range = 1.2 if rack_level < 0 else _th + 0.25
		_light.spot_angle = 65.0
		_light.light_energy = 2.2
		_light.light_color = Color(0.85, 0.95, 1.0)
		_light.shadow_enabled = false
		_light.visible = not Game.power_out
		_content.add_child(_light)
		# Suya süzülen ışık hüzmeleri
		for k in 3:
			var shaft := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.38 * _tw / TW, _water_h - _gravel_h())
			shaft.mesh = qm
			shaft.material_override = MeshKit.shader_mat("res://shaders/lightshaft.gdshader", {"seed": float(tank_id * 7 + k * 3), "strength": 0.16 if not _built_salt else 0.2})
			shaft.position = Vector3((-0.38 + k * 0.38) * _tw / TW, y0 + _gravel_h() + (_water_h - _gravel_h()) * 0.5, -0.05 + k * 0.05)
			shaft.rotation_degrees = Vector3(0, 12.0 * (k - 1), 8.0 * (k - 1))
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_content.add_child(shaft)
	_gravel_mat.set_shader_parameter("caustic_strength", 0.35 if d.get("light", false) else 0.0)

	# Görünür ekipman: ısıtıcı (sol arka), filtre (sağ arka)
	var black := MeshKit.mat(Color(0.06, 0.06, 0.07), 0.3)
	if d.get("heater_on", false):
		var h := MeshKit.cylinder(_content, 0.012, 0.3, Vector3(-_tw * 0.5 + 0.04, y0 + gh + 0.18, -_td * 0.5 + 0.03), MeshKit.mat(Color(0.75, 0.85, 0.9, 1.0), 0.1), 12)
		h.rotation_degrees.z = 8
		MeshKit.box(_content, Vector3(0.03, 0.03, 0.02), Vector3(-_tw * 0.5 + 0.04, y0 + _water_h + 0.01, -_td * 0.5 + 0.03), black)
	var fl: int = int(d.filter)
	if fl > 0:
		var fh: float = 0.12 + fl * 0.05
		MeshKit.box(_content, Vector3(0.07, fh, 0.05), Vector3(_tw * 0.5 - 0.06, y0 + _water_h - fh * 0.5 - 0.02, -_td * 0.5 + 0.04), black)

	if terrarium:
		_build_island()
	_build_decor(rng)
	if d.get("air", false):
		_build_particles()
	else:
		_build_food_particles()
	sync()


const DECOR_MODEL := "res://assets/models/decor/%s.glb"
## Dekor yuvaları (tank yerel x,z). Bitkiler arka sıraya dizilir.
const SLOTS := [Vector2(-0.38, -0.08), Vector2(0.36, -0.06), Vector2(-0.02, -0.1), Vector2(0.16, 0.08), Vector2(-0.22, 0.1), Vector2(0.48, 0.12), Vector2(-0.5, 0.06), Vector2(0.04, 0.13)]


## Hazır dekor modelini en uzun kenarı `size` olacak şekilde zemine koyar. Model yoksa false.
func _place_decor(name_id: String, size: float, pos: Vector3, rot: float) -> bool:
	var path := DECOR_MODEL % name_id
	if not ResourceLoader.exists(path):
		return false
	var n: Node3D = (load(path) as PackedScene).instantiate()
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var b: AABB = mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k: float = size / max(box.size.x, max(box.size.y, box.size.z))
	n.scale = Vector3.ONE * k
	n.rotation.y = rot
	var c := Vector3(box.get_center().x, 0, box.get_center().z) * k
	n.position = pos - c.rotated(Vector3.UP, rot) - Vector3(0, box.position.y * k + 0.005, 0)
	_content.add_child(n)
	return true


func _build_decor(rng: RandomNumberGenerator) -> void:
	var y0 := _y0 + _gravel_h()
	var decor: Array = data().get("decor", [])
	var plant_i := 0
	var greens := [
		[Color(0.06, 0.25, 0.06), Color(0.35, 0.75, 0.2)],
		[Color(0.08, 0.3, 0.1), Color(0.55, 0.85, 0.3)],
		[Color(0.2, 0.08, 0.05), Color(0.75, 0.3, 0.2)],
	]
	for i in decor.size():
		var id: String = decor[i]
		var info: Dictionary = FurnitureDB.DECOR.get(id, {})
		if info.is_empty():
			continue
		var slot: Vector2 = SLOTS[i % SLOTS.size()]
		var rot: float = rng.randf() * TAU
		match id:
			"bitki", "kilic_bitki":
				var x: float = -_tw * 0.42 + fmod(plant_i * 0.37 + 0.1, _tw * 0.84)
				plant_i += 1
				var pal: Array = greens[2] if (id == "kilic_bitki" and rng.randf() < 0.4) else greens[rng.randi_range(0, 1)]
				var mi := MeshInstance3D.new()
				if id == "bitki":
					mi.mesh = MeshKit.grass_clump(rng.randi() % 1000, rng.randi_range(7, 11), rng.randf_range(0.28, _water_h - 0.12))
					mi.material_override = MeshKit.shader_mat("res://shaders/plant.gdshader", {"base_color": pal[0], "tip_color": pal[1]})
					mi.position = Vector3(x, y0 - 0.01, -_td * 0.3 + rng.randf_range(-0.04, 0.04))
				else:
					mi.mesh = MeshKit.sword_plant(rng.randi() % 1000, rng.randi_range(8, 11), rng.randf_range(0.16, 0.22))
					mi.material_override = MeshKit.shader_mat("res://shaders/plant.gdshader", {"base_color": pal[0], "tip_color": pal[1], "sway": 0.4})
					mi.position = Vector3(x, y0 - 0.005, -_td * 0.12)
				_content.add_child(mi)
			"kok":
				var pts: Array = []
				var radii: Array = []
				var dir: float = 1.0 if rng.randf() < 0.5 else -1.0
				for k in 8:
					var t: float = k / 7.0
					pts.append(Vector3(slot.x - 0.2 * dir + t * 0.42 * dir, y0 + sin(t * PI) * 0.2 + t * 0.07, -0.08 + sin(t * 5.0) * 0.04))
					radii.append(lerp(0.028, 0.008, t))
				var wood := MeshInstance3D.new()
				wood.mesh = MeshKit.tube(pts, radii)
				wood.material_override = MeshKit.mat(Color(0.28, 0.2, 0.13), 0.9)
				_content.add_child(wood)
			_:
				var size: float = float(info.size) * rng.randf_range(0.85, 1.15)
				size = min(size, _td * 0.7)
				# Küçük tanklarda dekor camdan taşmasın
				slot.x = clamp(slot.x, -_tw * 0.5 + size * 0.6 + 0.02, _tw * 0.5 - size * 0.6 - 0.02)
				slot.y = clamp(slot.y, -_td * 0.5 + size * 0.5 + 0.02, _td * 0.5 - size * 0.5 - 0.02)
				if not _place_decor(info.model, size, Vector3(slot.x, y0, slot.y), rot):
					var mi := MeshInstance3D.new()
					mi.mesh = MeshKit.rock(rng.randi(), Vector3(size, size * 0.6, size * 0.7))
					mi.material_override = MeshKit.mat(Color(0.5, 0.5, 0.48), 0.85)
					mi.position = Vector3(slot.x, y0, slot.y)
					_content.add_child(mi)


const ISLAND_W := 0.42


## Teraryum: sağ tarafta kara parçası ve üstünde ısı lambası
func _build_island() -> void:
	var gh := _gravel_h()
	var top: float = _water_h + 0.05
	var stone := MeshKit.mat(Color(0.42, 0.38, 0.33), 0.9)
	MeshKit.box(_content, Vector3(ISLAND_W, top - gh, _td - 0.03), Vector3(_tw * 0.5 - ISLAND_W * 0.5 - 0.012, _y0 + gh + (top - gh) * 0.5, 0), stone)
	# Rampa
	var ramp := MeshKit.box(_content, Vector3(0.3, 0.02, 0.22), Vector3(_tw * 0.5 - ISLAND_W - 0.1, _y0 + gh + (top - gh) * 0.55, 0.05), stone)
	ramp.rotation.z = deg_to_rad(-28)
	_place_decor("kirik_kaya", 0.2, Vector3(_tw * 0.5 - 0.18, _y0 + top, -0.12), 0.7)
	# Isı lambası (kapağın altında, turuncu)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.6, 0.3)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.5, 0.2)
	lamp_mat.emission_energy_multiplier = 4.0
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	bulb.mesh = sm
	bulb.material_override = lamp_mat
	bulb.position = Vector3(_tw * 0.5 - ISLAND_W * 0.5, _y0 + _th - 0.06, 0)
	_content.add_child(bulb)
	var heat := OmniLight3D.new()
	heat.position = bulb.position - Vector3(0, 0.05, 0)
	heat.light_color = Color(1.0, 0.6, 0.3)
	heat.light_energy = 1.5
	heat.omni_range = 0.7
	heat.visible = not Game.power_out
	_content.add_child(heat)


## Kaplumbağanın dinlendiği nokta (kara üstü, yerel uzay)
func island_point() -> Vector3:
	return Vector3(_tw * 0.5 - ISLAND_W * 0.5 - 0.03, _y0 + _water_h + 0.05 + 0.04, 0.05)


func _build_food_particles() -> void:
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
	_content.add_child(_food_particles)


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
	bubbles.position = Vector3(_tw * 0.3, _y0 + _gravel_h() + 0.01, -_td * 0.35)
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
	if _is_dry():
		var floor_y: float = _y0 + 0.03
		var m := 0.05
		return AABB(Vector3(-_tw * 0.5 + m, floor_y, -_td * 0.5 + m), Vector3(_tw - 2 * m, 0.08, _td - 2 * m))
	var lo := Vector3(-_tw * 0.5 + 0.07, _y0 + _gravel_h() + 0.06, -_td * 0.5 + 0.07)
	var hi := Vector3(_tw * 0.5 - 0.07 - (ISLAND_W if terrarium else 0.0), _y0 + _water_h - 0.04, _td * 0.5 - 0.07)
	return AABB(lo, hi - lo)


func sync() -> void:
	var d: Dictionary = data()
	if not d.unlocked:
		return
	if _signature() != _equip_sig:
		_rebuild_content()
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
	if _water_mat:
		_water_mat.set_shader_parameter("dirt", dirt)
		_surface_mat.set_shader_parameter("dirt", dirt)
	if _gravel_mat:
		_gravel_mat.set_shader_parameter("dirt", dirt)
	if _glass_mat:
		_glass_mat.set_shader_parameter("algae", clamp((dirt - 40.0) / 60.0, 0.0, 1.0) * (0.0 if _is_dry() else 1.0))
	_update_label()


func _update_label() -> void:
	var d: Dictionary = data()
	var counts := {}
	for f in TankSim.living(d):
		counts[f.species] = counts.get(f.species, 0) + 1
	var lines: Array = ["TANK %d %s  %.1f°C" % [tank_id + 1, "(TUZLU)" if d.get("salt", false) else "", d.temp]]
	for sp in counts:
		lines.append("%s ×%d" % [FishDB.display_name(sp), counts[sp]])
	if counts.is_empty():
		lines.append("(boş)")
	if pen != "":
		lines[0] = "%s %d" % [{"hamster": "HAMSTER", "civciv": "CİVCİV", "kus": "KUŞ"}.get(pen, "KAFES"), tank_id + 1]
		_label.text = "  •  ".join(lines) if pen == "hamster" else "\n".join(lines)
		return
	if rack_level >= 0:
		lines[0] = "TANK %d%s %.1f°C" % [tank_id + 1, " TUZLU" if d.get("salt", false) else "", d.temp]
		_label.text = "  •  ".join(lines)
		return
	_label.text = "\n".join(lines)


func _process(delta: float) -> void:
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 1.0
		if Game.tanks.size() > tank_id:
			sync()
	if _food_timer > 0.0:
		_food_timer -= delta


func scare() -> void:
	for f in _fish.values():
		f.scare()


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
	_food_point = Vector3(randf_range(-0.3, 0.3) * _tw / TW, _y0 + _water_h - 0.06, randf_range(-0.05, 0.1))
	if _is_dry():
		_food_point.y = _y0 + 0.035
	_food_particles.position = _food_point + Vector3(0, 0.05, 0)
	_food_particles.restart()
	_food_particles.emitting = true
	_food_timer = 7.0


## Müşterinin baktığı nokta (dünya uzayında)
func view_point() -> Vector3:
	return to_global(Vector3(0, 0, _td * 0.5 + 0.9))


func look_target() -> Vector3:
	return to_global(Vector3(0, _y0 + _th * 0.5, 0))


func get_prompt() -> String:
	var d := data()
	if Game.is_animal_box(Game.carrying):
		return "Tank %d: %s ×%d içine bırak" % [tank_id + 1, FishDB.display_name(Game.carrying.species), int(Game.carrying.n)]
	if pen != "":
		return "%s %d: İncele" % [{"hamster": "Hamster kafesi", "civciv": "Civciv kafesi", "kus": "Kuş kafesi"}.get(pen, "Kafes"), tank_id + 1]
	if TankSim.living(d).is_empty() and str(d.get("gravel", "")) == "":
		return "Tank %d: Kur (kum, filtre, ısıtıcı, lamba...)" % (tank_id + 1)
	return "Tank %d: İncele" % (tank_id + 1)


func interact(player: Node) -> void:
	if Game.is_animal_box(Game.carrying):
		var sp: String = Game.carrying.species
		var n0: int = int(Game.carrying.n)
		var err: String = Game.release_to_tank(tank_id)
		if err != "":
			Game.notify.emit(err, "bad")
			Sfx.play("bad")
			return
		var left: int = int(Game.carrying.get("n", 0)) if Game.is_animal_box(Game.carrying) else 0
		Game.notify.emit("%d %s bırakıldı%s." % [n0 - left, FishDB.display_name(sp), (", %d tanesi sığmadı" % left) if left > 0 else ""], "good")
		Sfx.play("splash" if not TankSim.is_dry(data()) else "click")
		return
	player.hud.open_tank(self)


static func _fmt(v: int) -> String:
	var s := str(abs(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
