class_name Builder
extends Node3D
## Yerleştirme modu: satın alınan ya da taşınan eşya imlecin baktığı yere gelir.
## Döndürülebilir, çakışırsa kırmızı olur. Onaylanınca Game.furniture'a yazılır.

signal state_changed()

const ROOM_MIN := Vector2(-6.95, -4.95) ## x sınırı dükkân büyüdükçe sola kayar (Game.room_min_x)
const ROOM_MAX := Vector2(6.95, 4.95)
## Kapı önü boş kalmalı (müşteri girişi)
const DOOR_ZONE := [Vector2(-1.4, 3.6), Vector2(1.4, 3.6), Vector2(1.4, 5.1), Vector2(-1.4, 5.1)]
const SNAP := 0.05
const ROT_STEP := 15.0

var player: Player
var shop: Shop
var active: bool = false
var type: String = ""
var moving_uid: int = -1
var rot: float = 0.0
var pos := Vector2.ZERO
var valid: bool = false
var reason: String = ""

var _ghost: Node3D
var _ghost_mat: StandardMaterial3D
var _foot_mat: StandardMaterial3D
var _orig: Dictionary = {}


func start_new(t: String) -> void:
	cancel()
	type = t
	moving_uid = -1
	rot = 0.0
	_begin()


func start_move(uid: int) -> void:
	cancel()
	var e: Dictionary = Game.furniture_by_uid(uid)
	if e.is_empty():
		return
	type = e.type
	moving_uid = uid
	rot = float(e.rot)
	_orig = e.duplicate()
	var n: Node3D = shop.node_for(uid)
	if n:
		n.visible = false
		_set_collision(n, false)
	_begin()


func _begin() -> void:
	active = true
	var info: Dictionary = FurnitureDB.item(type)
	_ghost = Node3D.new()
	add_child(_ghost)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.5, 0.25)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_foot_mat = _ghost_mat.duplicate()
	_foot_mat.albedo_color = Color(0.3, 1.0, 0.5, 0.55)
	var h: float = max(0.05, float(info.height))
	MeshKit.box(_ghost, Vector3(info.size.x, h, info.size.y), Vector3(0, h * 0.5, 0), _ghost_mat)
	MeshKit.box(_ghost, Vector3(info.size.x + 0.04, 0.01, info.size.y + 0.04), Vector3(0, 0.006, 0), _foot_mat)
	# Ön yüz oku (müşteri tarafı)
	var arrow := MeshKit.box(_ghost, Vector3(0.12, 0.02, 0.35), Vector3(0, 0.02, info.size.y * 0.5 + 0.22), _foot_mat)
	arrow.name = "Arrow"
	var lbl := Label3D.new()
	lbl.text = "%s\nön yüz ↓" % info.name
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 32
	lbl.pixel_size = 0.004
	lbl.position = Vector3(0, h + 0.25, 0)
	lbl.no_depth_test = true
	_ghost.add_child(lbl)
	state_changed.emit()


func rotate_by(deg: float) -> void:
	rot = fposmod(rot + deg, 360.0)


func _process(_delta: float) -> void:
	if not active or player == null:
		return
	var cam: Camera3D = player.camera
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var hit := Vector3.ZERO
	if dir.y < -0.05:
		var t: float = -origin.y / dir.y
		t = clamp(t, 1.0, 6.0)
		hit = origin + dir * t
	else:
		hit = origin + Vector3(dir.x, 0, dir.z).normalized() * 3.0
	pos = Vector2(snapped(hit.x, SNAP), snapped(hit.z, SNAP))
	_ghost.position = Vector3(pos.x, 0.0, pos.y)
	_ghost.rotation = Vector3(0, deg_to_rad(rot), 0)
	_validate()
	var col := Color(0.3, 1.0, 0.5) if valid else Color(1.0, 0.3, 0.25)
	_ghost_mat.albedo_color = Color(col, 0.22)
	_foot_mat.albedo_color = Color(col, 0.6)


func _validate() -> void:
	valid = false
	var info: Dictionary = FurnitureDB.item(type)
	var mine: PackedVector2Array = FurnitureDB.corners(type, pos, rot)
	for c in mine:
		if c.x < Game.room_min_x() + 0.05 or c.y < ROOM_MIN.y or c.x > ROOM_MAX.x or c.y > ROOM_MAX.y:
			reason = "Dükkânın içine sığmıyor"
			return
	if not info.get("walkable", false) and FurnitureDB.polys_overlap(mine, PackedVector2Array(DOOR_ZONE)):
		reason = "Kapının önünü kapatma"
		return
	for e in Game.furniture:
		if int(e.uid) == moving_uid:
			continue
		var other: Dictionary = FurnitureDB.item(e.type)
		if other.get("walkable", false) or info.get("walkable", false):
			continue
		if FurnitureDB.polys_overlap(mine, FurnitureDB.corners(e.type, Vector2(e.x, e.z), e.rot)):
			reason = "Başka bir eşyaya çarpıyor"
			return
	# Oyuncunun içine koyma
	var pp := Vector2(player.global_position.x, player.global_position.z)
	if not info.get("walkable", false) and FurnitureDB.polys_overlap(mine, _player_square(pp)):
		reason = "Üstünde duruyorsun"
		return
	reason = ""
	valid = true


func _player_square(p: Vector2) -> PackedVector2Array:
	var r := 0.3
	return PackedVector2Array([p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(r, r), p + Vector2(-r, r)])


## Onayla. Yeni eşyaysa parayı öder. Başarılıysa true.
func confirm() -> bool:
	if not active:
		return false
	if not valid:
		Game.notify.emit("Buraya konamaz: " + reason, "bad")
		return false
	if moving_uid < 0:
		var info: Dictionary = FurnitureDB.item(type)
		if info.has("max") and Game.count_furniture(type) >= int(info.max):
			Game.notify.emit("Bundan en fazla %d tane olabilir." % int(info.max), "bad")
			return false
		if not Game.spend(int(info.price)):
			return false
		Game.add_furniture(type, pos.x, pos.y, rot)
		Game.notify.emit("%s yerleştirildi." % info.name, "good")
	else:
		var n: Node3D = shop.node_for(moving_uid)
		if n:
			n.visible = true
			_set_collision(n, true)
		Game.move_furniture(moving_uid, pos.x, pos.y, rot)
	_end()
	return true


func cancel() -> void:
	if not active:
		return
	if moving_uid >= 0:
		var n: Node3D = shop.node_for(moving_uid)
		if n:
			n.visible = true
			_set_collision(n, true)
	_end()


func _end() -> void:
	active = false
	moving_uid = -1
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	state_changed.emit()


func _set_collision(n: Node, on: bool) -> void:
	for b in n.find_children("*", "CollisionObject3D", true, false):
		var co: CollisionObject3D = b
		if on:
			co.collision_layer = co.get_meta("_layer", co.collision_layer)
		else:
			co.set_meta("_layer", co.collision_layer)
			co.collision_layer = 0
