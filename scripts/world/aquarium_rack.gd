class_name AquariumRack
extends Node3D
## Akvaryum rafı: her bölmesine (sütun x kat) bir ışıklı akvaryum konabilir.
## Ayarlar FurnitureDB eşyasının "rack" sözlüğünde: model, dönüş, kat yükseklikleri,
## sütun konumları, tank ölçüsü, bölme fiyatı ve kapasitesi.
## Bölmelerin tank kimlikleri Game.furniture kaydındaki "tanks" dizisindedir
## (sıra: sütun 0'ın katları, sonra sütun 1'in katları...). Kilitli tank = bölme boş.

var furniture_uid: int = 0
var kind: String = "tank_rafi"
var cfg: Dictionary = {}
var size := Vector2(1.1, 0.86)
var _slots: Array = []   ## bölme başına: Aquarium ya da boş bölme düğümü


func setup(uid: int, type: String = "tank_rafi") -> void:
	furniture_uid = uid
	kind = type
	cfg = FurnitureDB.item(kind).get("rack", {})
	size = FurnitureDB.item(kind).get("size", size)
	_build_frame()
	_build_blocker()
	refresh()


func entry() -> Dictionary:
	return Game.furniture_by_uid(furniture_uid)


func levels() -> Array:
	return cfg.get("levels", [0.171, 0.835, 1.56])


func bays() -> Array:
	return cfg.get("bays", [0.0])


func slot_count() -> int:
	return levels().size() * bays().size()


func slot_pos(i: int) -> Vector3:
	var lv: Array = levels()
	return Vector3(float(bays()[i / lv.size()]), float(lv[i % lv.size()]), float(cfg.get("z", 0.0)))


func _build_frame() -> void:
	var path: String = str(cfg.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate()
		# Modelin kendi cam kutuları varsa gizle: camı ve suyu oyun çiziyor
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mat = (c as MeshInstance3D).get_active_material(0)
			if mat is BaseMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				c.visible = false
		var box: AABB = MeshKit.model_aabb(m)
		var holder := Node3D.new()
		holder.rotation_degrees.y = float(cfg.get("rot", 90.0))
		m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
		holder.add_child(m)
		add_child(holder)
		return
	if cfg.has("frame"):
		_build_shop_frame()
		return
	var dark := MeshKit.mat(Color(0.12, 0.12, 0.13), 0.4, 0.6)
	var wood := MeshKit.mat(Color(0.75, 0.58, 0.38), 0.7)
	for x in [-size.x * 0.5 + 0.02, size.x * 0.5 - 0.02]:
		for z in [-size.y * 0.5 + 0.02, size.y * 0.5 - 0.02]:
			MeshKit.box(self, Vector3(0.03, 1.6, 0.04), Vector3(x, 0.8, z), dark)
	for y in levels():
		MeshKit.box(self, Vector3(size.x - 0.04, 0.012, size.y - 0.04), Vector3(0, y - 0.006, 0), wood)


## Balıkçı tipi raf: kolonlar, kat tablaları, her katın altında ışık bandı (kodla çizilir)
func _build_shop_frame() -> void:
	if str(cfg.frame) == "kabin":
		_build_cabinet_frame()
		return
	var white: bool = str(cfg.frame) == "beyaz"
	var col: Color = Color(0.93, 0.93, 0.92) if white else Color(0.08, 0.08, 0.09)
	var frame := MeshKit.mat(col, 0.5 if white else 0.35, 0.0 if white else 0.6)
	var post_w: float = 0.1 if white else 0.04
	var lv: Array = levels()
	var top: float = float(lv[-1]) + tank_size().y + 0.16
	var bx: Array = bays()
	var half: float = size.x * 0.5
	var xs: Array = [-half + post_w * 0.5, half - post_w * 0.5]
	for i in range(1, bx.size()):
		xs.append((float(bx[i - 1]) + float(bx[i])) * 0.5)
	for x in xs:
		for z in [-size.y * 0.5 + post_w * 0.5, size.y * 0.5 - post_w * 0.5]:
			MeshKit.box(self, Vector3(post_w, top, post_w), Vector3(x, top * 0.5, z), frame)
	# Kat tablaları ve üst kapak
	var shelf_ys: Array = lv.duplicate()
	shelf_ys.append(top - 0.02)
	for y in shelf_ys:
		MeshKit.box(self, Vector3(size.x, 0.04, size.y), Vector3(0, float(y) - 0.02, 0), frame)
		# Ön kenar bandı (beyaz rafta kalın)
		MeshKit.box(self, Vector3(size.x, 0.08 if white else 0.04, 0.02), Vector3(0, float(y) - 0.04, size.y * 0.5), frame)
	# Her kat tablasının altında ve üst kapakta ışıklı tüp (fotoğraflardaki gibi)
	var led_col: Color = cfg.get("style", {}).get("led", Color(0.85, 0.95, 1.0))
	var tube := StandardMaterial3D.new()
	tube.albedo_color = led_col
	tube.emission_enabled = true
	tube.emission = led_col
	tube.emission_energy_multiplier = 3.5
	for y in shelf_ys.slice(1):
		for b in bx:
			var t := MeshKit.cylinder(self, 0.018, tank_size().x * 0.9, Vector3(float(b), float(y) - 0.07, size.y * 0.3), tube, 10)
			t.rotation_degrees.z = 90
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Taban süpürgeliği
	MeshKit.box(self, Vector3(size.x, float(lv[0]) - 0.04, size.y - 0.04), Vector3(0, (float(lv[0]) - 0.04) * 0.5, 0), frame)


## Siyah kabinli akvaryum duvarı: altta kapaklı dolap, kapalı yanlar ve arka, katlar arasında kalın
## siyah bantlar (ışık bandı), üstte kornişli kapak. Fotoğraftaki mağaza akvaryum sistemleri gibi.
const CABINET_MODEL := "res://assets/modeller/akvaryum/akvaryum_kabin.glb"


func _build_cabinet_frame() -> void:
	# Blender'da yapılmış gerçekçi model (assets/modeller/akvaryum/akvaryum_kabin.glb); yoksa kutularla çiz
	if ResourceLoader.exists(CABINET_MODEL):
		var m: Node3D = (load(CABINET_MODEL) as PackedScene).instantiate()
		add_child(m)
		for c in m.find_children("*", "MeshInstance3D", true, false):
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return
	var black := MeshKit.mat(Color(0.035, 0.035, 0.04), 0.3, 0.2)
	var seam := MeshKit.mat(Color(0.12, 0.12, 0.13), 0.4)
	var lv: Array = levels()
	var th: float = tank_size().y
	var top: float = float(lv[-1]) + th + 0.2
	var w: float = size.x
	var d: float = size.y
	# Yan paneller ve arka
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.03, top, d), Vector3(sx * (w * 0.5 - 0.015), top * 0.5, 0), black)
	MeshKit.box(self, Vector3(w, top, 0.02), Vector3(0, top * 0.5, -d * 0.5 + 0.01), black)
	# Ortadaki dikme
	for i in range(1, bays().size()):
		var bx: float = (float(bays()[i - 1]) + float(bays()[i])) * 0.5
		MeshKit.box(self, Vector3(0.04, top, 0.06), Vector3(bx, top * 0.5, d * 0.5 - 0.03), black)
	# Alt dolap ve kapakları
	var base_h: float = float(lv[0]) - 0.02
	MeshKit.box(self, Vector3(w, base_h, d), Vector3(0, base_h * 0.5, 0), black)
	var doors: int = bays().size() * 2
	for i in range(1, doors):
		var x: float = -w * 0.5 + w * float(i) / doors
		MeshKit.box(self, Vector3(0.006, base_h - 0.08, 0.004), Vector3(x, base_h * 0.5, d * 0.5 + 0.002), seam)
	# Kat tablaları + üstlerindeki kalın bant (bir alt tankın ışık kapağı gibi)
	var light := StandardMaterial3D.new()
	light.albedo_color = Color(0.95, 0.97, 1.0)
	light.emission_enabled = true
	light.emission = Color(0.9, 0.95, 1.0)
	light.emission_energy_multiplier = 2.5
	for li in lv.size():
		var y: float = float(lv[li])
		MeshKit.box(self, Vector3(w, 0.03, d), Vector3(0, y - 0.015, 0), black)
		var band_y: float = (float(lv[li + 1]) if li + 1 < lv.size() else top) - 0.075
		var band := MeshKit.box(self, Vector3(w, 0.15, 0.04), Vector3(0, band_y, d * 0.5 - 0.02), black)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# Bandın altından tanka vuran ince ışık şeridi
		var strip := MeshKit.box(self, Vector3(w - 0.1, 0.008, 0.06), Vector3(0, band_y - 0.08, d * 0.5 - 0.08), light)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.box(self, Vector3(w + 0.02, 0.03, d + 0.02), Vector3(0, top, 0), black)


## Zemin ile alt kat arası: yürünemez gövde (bölmelerin üstünü akvaryum/boş bölme gövdeleri kaplar).
func _build_blocker() -> void:
	var h: float = float(levels()[0])
	var low := StaticBody3D.new()
	var lcs := CollisionShape3D.new()
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(size.x, h, size.y)
	lcs.shape = lshape
	lcs.position = Vector3(0, h * 0.5, 0)
	low.add_child(lcs)
	add_child(low)


func tank_size() -> Vector3:
	return cfg.get("tank", Vector3(Aquarium.RACK_TW, Aquarium.RACK_TH, Aquarium.RACK_TD))


func slot_footprint() -> Vector2:
	var t: Vector3 = tank_size()
	return Vector2(min(size.x / bays().size(), t.x + 0.12), size.y)


## Bölmeleri kayıtla eşitler: açılan bölmeye akvaryum kurar, kaldırılanı söker.
func refresh() -> void:
	var e := entry()
	var ids: Array = e.get("tanks", [])
	while _slots.size() < slot_count():
		_slots.append(null)
	for i in slot_count():
		var has_tank: bool = i < ids.size() and int(ids[i]) < Game.tanks.size() and Game.tanks[int(ids[i])].unlocked
		var cur = _slots[i]
		if cur != null and not is_instance_valid(cur):
			cur = null
		if cur != null and ((cur is Aquarium) == has_tank):
			continue
		if cur != null:
			remove_child(cur)
			cur.queue_free()
		var p: Vector3 = slot_pos(i)
		var n: Node3D
		if has_tank:
			var aq := Aquarium.new()
			aq.furniture_uid = furniture_uid
			aq.position = Vector3(p.x, 0, p.z)
			add_child(aq)
			aq.setup_rack(int(ids[i]), i, p.y, slot_footprint(), tank_size(), cfg.get("style", {}))
			n = aq
		else:
			var slot := RackSlot.new()
			slot.position = Vector3(p.x, 0, p.z)
			add_child(slot)
			slot.setup(self, i)
			n = slot
		_slots[i] = n


func aquariums() -> Array:
	return _slots.filter(func(n): return n is Aquarium and is_instance_valid(n))


func slot_price() -> int:
	return int(cfg.get("slot_price", Game.RACK_TANK_PRICE))


## Boş bölme: bakınca "akvaryum koy" seçeneği çıkar.
class RackSlot extends Node3D:
	var rack: AquariumRack
	var level: int = 0

	func setup(r: AquariumRack, lv: int) -> void:
		rack = r
		level = lv
		var fp: Vector2 = r.slot_footprint()
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(fp.x, r.tank_size().y + 0.06, fp.y)
		cs.shape = shape
		cs.position = Vector3(0, r.slot_pos(lv).y + shape.size.y * 0.5, 0)
		body.add_child(cs)
		body.set_meta("interact", self)
		add_child(body)

	func get_prompt() -> String:
		return "Rafa ışıklı akvaryum koy (%d ₺)" % rack.slot_price()

	func interact(_player: Node) -> void:
		var err: String = Game.buy_rack_tank(rack.furniture_uid, level)
		if err != "":
			Game.notify.emit(err, "bad")
		else:
			Sfx.play("kaching")
			Game.notify.emit("Rafa ışıklı akvaryum kondu. Kum, filtre, ısıtıcı ekleyip balık koyabilirsin.", "good")
