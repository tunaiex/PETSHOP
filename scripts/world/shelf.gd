class_name Shelf
extends Node3D
## Ürün rafı. İçindeki ürünler Game.furniture kaydındaki "shelf" sözlüğünden çizilir.
## Oyuncu depodan rafa dizer, müşteri raftan alır.

const WALL_MODEL := "res://assets/models/props/duvar_rafi.glb"

var furniture_uid: int = 0
var kind: String = "kavisli_raf"
var _items: Node3D
## Her katın üst yüzey yüksekliği, kat genişliği, kat derinlik merkezi
var _rows: Array = []
var _width: float = 2.0
var _sides: int = 1          ## 2: reyon gibi iki yüzlü (arka yüz -Z)
var _depth_z: float = 0.02   ## ürün sırasının raf merkezine uzaklığı (ön yüz)
var _shelf_depth: float = 0.4


func setup(uid: int, type: String) -> void:
	furniture_uid = uid
	kind = type
	var cfg: Dictionary = FurnitureDB.item(kind).get("shelf", {})
	var model: Node3D = FurnitureDB.instance_model(kind)
	if model and not cfg.is_empty():
		add_child(model)
		_width = float(cfg.width)
		_rows = cfg.levels
		_sides = int(cfg.get("sides", 1))
		_depth_z = float(cfg.get("z", 0.0))
		_shelf_depth = float(cfg.get("depth", 0.4))
	elif kind == "duvar_rafi" and ResourceLoader.exists(WALL_MODEL):
		_build_wall_model()
	else:
		_build_curved()
	var info: Dictionary = FurnitureDB.item(kind)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(info.size.x, info.height, info.size.y)
	cs.shape = shape
	cs.position = Vector3(0, info.height * 0.5, 0)
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)
	_items = Node3D.new()
	add_child(_items)
	refresh()
	Game.stock_changed.connect(refresh)


func entry() -> Dictionary:
	return Game.furniture_by_uid(furniture_uid)


func _build_curved() -> void:
	var cream := MeshKit.mat(Color(0.93, 0.9, 0.84), 0.55)
	var wood := MeshKit.shader_mat("res://shaders/wood_floor.gdshader", {"wood_a": Color(0.5, 0.33, 0.2), "wood_b": Color(0.38, 0.24, 0.14), "plank": Vector2(3.0, 0.4)})
	var sw := 2.4
	var sh := 1.9
	var r := 0.25
	for side in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.1, sh - r, 0.4), Vector3(side * (sw * 0.5 - 0.05), (sh - r) * 0.5, 0), cream)
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
		add_child(corner)
	MeshKit.box(self, Vector3(sw - r * 2, 0.1, 0.4), Vector3(0, sh - 0.05, 0), cream)
	MeshKit.box(self, Vector3(sw - 0.2, sh - 0.12, 0.02), Vector3(0, (sh - 0.12) * 0.5, -0.19), cream)
	for i in 4:
		MeshKit.box(self, Vector3(sw - 0.2, 0.035, 0.36), Vector3(0, 0.18 + i * 0.42, 0.01), wood)
	_width = sw - 0.3
	_rows = [0.18 + 2 * 0.42 + 0.0175, 0.18 + 1 * 0.42 + 0.0175, 0.18 + 0.0175]


func _build_wall_model() -> void:
	var m: Node3D = (load(WALL_MODEL) as PackedScene).instantiate()
	# Modeldeki hazır ürünleri gizle: rafı oyuncu dolduracak.
	for c in m.find_children("*", "MeshInstance3D", true, false):
		var n: String = c.name
		if n.begins_with("Plain carton") or n.begins_with("Original unbranded") or n.begins_with("Original circular"):
			c.visible = false
	add_child(m)
	_width = 0.86
	_rows = [1.93, 1.37, 0.8, 0.23]


## Raftaki ürünleri yeniden çizer.
func refresh() -> void:
	if not is_instance_valid(_items):
		return
	for c in _items.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	var e: Dictionary = entry()
	if e.is_empty():
		return
	var cap: int = int(FurnitureDB.item(kind).get("capacity", 20))
	var rows_total: int = _rows.size() * _sides
	var per_row: int = int(ceil(float(cap) / rows_total))
	var slot := 0
	var ids: Array = ProductDB.ids()
	for pid in ids:
		var n: int = int(e.shelf.get(pid, 0))
		var p: Dictionary = ProductDB.get_product(pid)
		for k in n:
			var row: int = slot / per_row
			var col: int = slot % per_row
			if row >= rows_total:
				break
			# Önce ön yüzün katları (yukarıdan aşağı göz hizası önce), sonra arka yüz
			var side: int = row / _rows.size()
			var lvl: int = row % _rows.size()
			var lvl_order: Array = _level_order()
			var y: float = _rows[lvl_order[lvl]]
			var x: float = -_width * 0.5 + (col + 0.5) * _width / per_row
			var z: float = _depth_z if side == 0 else -_depth_z
			var mesh_parent := Node3D.new()
			mesh_parent.position = Vector3(x if side == 0 else -x, y, z)
			if side == 1:
				mesh_parent.rotation.y = PI
			_items.add_child(mesh_parent)
			_product_mesh(mesh_parent, p, Vector3.ZERO, pid)
			slot += 1


func _product_mesh(parent: Node3D, p: Dictionary, pos: Vector3, pid: String = "") -> void:
	if p.has("model"):
		var model: Node3D = ProductDB.instance_model(pid, float(p.get("h", 0.15)))
		if model:
			model.position = pos
			model.rotation_degrees.y = randf_range(-12.0, 12.0)
			parent.add_child(model)
			return
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
			var b := MeshKit.box(parent, Vector3(0.13, 0.22, 0.07), pos + Vector3(0, 0.11, 0), m)
			b.rotation_degrees.x = -6
			MeshKit.box(parent, Vector3(0.09, 0.07, 0.072), pos + Vector3(0, 0.11, 0), label)
		_:
			MeshKit.box(parent, Vector3(0.13, 0.19, 0.1), pos + Vector3(0, 0.095, 0), m)
			MeshKit.box(parent, Vector3(0.132, 0.05, 0.102), pos + Vector3(0, 0.14, 0), label)


## Ürünlerin dolma sırası: göz hizasındaki kat önce
func _level_order() -> Array:
	var idx: Array = range(_rows.size())
	idx.sort_custom(func(a, b): return abs(float(_rows[a]) - 1.15) < abs(float(_rows[b]) - 1.15))
	return idx


## Müşterinin rafa bakarken durduğu yer
func view_point() -> Vector3:
	return to_global(Vector3(0, 0, FurnitureDB.item(kind).size.y * 0.5 + 0.7))


func look_target() -> Vector3:
	return to_global(Vector3(0, 1.0, 0))


func get_prompt() -> String:
	var e := entry()
	var cap: int = int(FurnitureDB.item(kind).get("capacity", 20))
	if not Game.carrying.is_empty():
		return "Koliden rafa diz (%d/%d)" % [Game.shelf_total(e), cap]
	return "%s: Ürün diz (%d/%d)" % [FurnitureDB.item(kind).name, Game.shelf_total(e), cap]


func interact(player: Node) -> void:
	if not Game.carrying.is_empty():
		var pid: String = Game.carrying.pid
		var n: int = Game.carry_to_shelf(furniture_uid)
		if n > 0:
			Game.notify.emit("%d %s rafa dizildi." % [n, ProductDB.get_product(pid).name], "good")
		return
	player.hud.open_shelf(self)
