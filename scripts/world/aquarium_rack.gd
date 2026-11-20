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
	var dark := MeshKit.mat(Color(0.12, 0.12, 0.13), 0.4, 0.6)
	var wood := MeshKit.mat(Color(0.75, 0.58, 0.38), 0.7)
	for x in [-size.x * 0.5 + 0.02, size.x * 0.5 - 0.02]:
		for z in [-size.y * 0.5 + 0.02, size.y * 0.5 - 0.02]:
			MeshKit.box(self, Vector3(0.03, 1.6, 0.04), Vector3(x, 0.8, z), dark)
	for y in levels():
		MeshKit.box(self, Vector3(size.x - 0.04, 0.012, size.y - 0.04), Vector3(0, y - 0.006, 0), wood)


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
			aq.setup_rack(int(ids[i]), i, p.y, slot_footprint(), tank_size())
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
