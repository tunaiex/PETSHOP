class_name AquariumRack
extends Node3D
## 3 katlı metal akvaryum rafı. Her katta bir ışıklı akvaryum olabilir.
## Katların tank kimlikleri Game.furniture kaydındaki "tanks" dizisindedir;
## kilitli tank = o kat boş (oyuncu akvaryumu satın alıp koyar).

const MODEL := "res://assets/models/props/akvaryum_rafi.glb"
## Raf tablalarının üst yüzey yükseklikleri (zeminden, modelden ölçüldü)
const LEVEL_Y := [0.171, 0.835, 1.56]
const SIZE := Vector2(1.1, 0.86)
const HEIGHT := 1.6

var furniture_uid: int = 0
var _levels: Array = []   ## kat başına: Aquarium ya da boş kat düğümü


func setup(uid: int) -> void:
	furniture_uid = uid
	_build_frame()
	_build_blocker()
	refresh()


func entry() -> Dictionary:
	return Game.furniture_by_uid(furniture_uid)


func _build_frame() -> void:
	if ResourceLoader.exists(MODEL):
		var m: Node3D = (load(MODEL) as PackedScene).instantiate()
		var box: AABB = MeshKit.model_aabb(m)
		# Modelin uzun kenarı Z'de: 90° döndür, tabanı zemine, ortası merkeze gelsin.
		var holder := Node3D.new()
		holder.rotation_degrees.y = 90.0
		m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
		holder.add_child(m)
		add_child(holder)
		return
	# Model yoksa: basit siyah metal raf
	var dark := MeshKit.mat(Color(0.12, 0.12, 0.13), 0.4, 0.6)
	var wood := MeshKit.mat(Color(0.75, 0.58, 0.38), 0.7)
	for x in [-SIZE.x * 0.5 + 0.02, SIZE.x * 0.5 - 0.02]:
		for z in [-SIZE.y * 0.5 + 0.02, SIZE.y * 0.5 - 0.02]:
			MeshKit.box(self, Vector3(0.03, HEIGHT, 0.04), Vector3(x, HEIGHT * 0.5, z), dark)
	for y in LEVEL_Y:
		MeshKit.box(self, Vector3(SIZE.x - 0.04, 0.012, SIZE.y - 0.04), Vector3(0, y - 0.006, 0), wood)


## Zemin ile alt kat arası: yürünemez gövde (katların üstünü akvaryum/boş kat gövdeleri kaplar).
func _build_blocker() -> void:
	var low := StaticBody3D.new()
	var lcs := CollisionShape3D.new()
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(SIZE.x, LEVEL_Y[0], SIZE.y)
	lcs.shape = lshape
	lcs.position = Vector3(0, LEVEL_Y[0] * 0.5, 0)
	low.add_child(lcs)
	add_child(low)


## Katları kayıtla eşitler: açılan kata akvaryum kurar, kaldırılanı söker.
func refresh() -> void:
	var e := entry()
	var ids: Array = e.get("tanks", [])
	while _levels.size() < LEVEL_Y.size():
		_levels.append(null)
	for i in LEVEL_Y.size():
		var has_tank: bool = i < ids.size() and int(ids[i]) < Game.tanks.size() and Game.tanks[int(ids[i])].unlocked
		var cur = _levels[i]
		if cur != null and not is_instance_valid(cur):
			cur = null
		var ok: bool = cur != null and ((cur is Aquarium) == has_tank)
		if ok:
			continue
		if cur != null:
			remove_child(cur)
			cur.queue_free()
		var n: Node3D
		if has_tank:
			var aq := Aquarium.new()
			aq.furniture_uid = furniture_uid
			add_child(aq)
			aq.setup_rack(int(ids[i]), i, LEVEL_Y[i], SIZE)
			n = aq
		else:
			var slot := RackSlot.new()
			add_child(slot)
			slot.setup(self, i)
			n = slot
		_levels[i] = n


func aquariums() -> Array:
	return _levels.filter(func(n): return n is Aquarium and is_instance_valid(n))


## Boş raf katı: bakınca "akvaryum koy" seçeneği çıkar.
class RackSlot extends Node3D:
	var rack: AquariumRack
	var level: int = 0

	func setup(r: AquariumRack, lv: int) -> void:
		rack = r
		level = lv
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(AquariumRack.SIZE.x, Aquarium.RACK_TH + 0.06, AquariumRack.SIZE.y)
		cs.shape = shape
		cs.position = Vector3(0, AquariumRack.LEVEL_Y[lv] + shape.size.y * 0.5, 0)
		body.add_child(cs)
		body.set_meta("interact", self)
		add_child(body)

	func get_prompt() -> String:
		return "Raf %d. kat: Işıklı akvaryum koy (%d ₺)" % [level + 1, Game.RACK_TANK_PRICE]

	func interact(_player: Node) -> void:
		var err: String = Game.buy_rack_tank(rack.furniture_uid, level)
		if err != "":
			Game.notify.emit(err, "bad")
		else:
			Sfx.play("kaching")
			Game.notify.emit("Rafa ışıklı akvaryum kondu. Kum, filtre, ısıtıcı ekleyip balık koyabilirsin.", "good")
