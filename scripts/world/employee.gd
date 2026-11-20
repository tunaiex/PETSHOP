class_name Employee
extends Node3D
## Çalışan: kasiyer kasada bekleyen müşteriye satış yapar,
## bakımcı tankları dolaşıp yem verir, ölü balıkları çıkarır, kirli suyu değiştirir.

const CHARACTERS := ["res://assets/models/characters/musteri_2.glb", "res://assets/models/characters/musteri_6.glb"]

var role: String = "kasiyer"
var main: Node
var shop: Shop
var _anim: AnimationPlayer
var _walk: String = ""
var _idle: String = ""
var _path: Array = []
var _wait: float = 0.0
var _work_timer: float = 3.0
var _target: Aquarium
var _label: Label3D


func setup(r: String, m: Node, s: Shop) -> void:
	role = r
	main = m
	shop = s
	var path: String = CHARACTERS[0 if role == "kasiyer" else 1]
	if ResourceLoader.exists(path):
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		inst.rotation.y = PI
		add_child(inst)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 if role == "kasiyer" else 23
		_anim = MixamoAnim.setup(inst, rng)
		if _anim:
			_walk = "walk"
			_idle = "idle"
	Shop.add_blob_shadow(self, Vector2(0.8, 0.8), 0.4)
	# Personel önlüğü (müşterilerden ayırt etmek için)
	var apron := MeshKit.box(self, Vector3(0.36, 0.55, 0.03), Vector3(0, 1.05, -0.16), MeshKit.mat(Color(0.12, 0.5, 0.55), 0.7))
	apron.name = "Apron"
	_label = Label3D.new()
	_label.text = "Kasiyer" if role == "kasiyer" else "Bakımcı"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 30
	_label.pixel_size = 0.0028
	_label.modulate = Color(0.6, 1.0, 0.95)
	_label.outline_size = 8
	_label.position = Vector3(0, 1.95, 0)
	add_child(_label)


func _station() -> Vector3:
	if shop.counter:
		return shop.counter.cashier_point()
	return Vector3(3, 0, 3)


func _process(delta: float) -> void:
	var dt: float = delta * Game.time_scale
	var moving := _follow(dt)
	if _anim:
		var want: String = _walk if moving else _idle
		if want != "" and _anim.current_animation != want:
			_anim.play(want, 0.25)
	if role == "kasiyer":
		_cashier(dt, moving)
	else:
		_keeper(dt, moving)


func _cashier(dt: float, moving: bool) -> void:
	if shop.counter == null:
		return
	if not moving and global_position.distance_to(_station()) > 0.3:
		_path = shop.path(global_position, _station())
		return
	if not moving and shop.counter:
		_face(shop.counter.register_point())
	var c: Customer = main.customer_at_register()
	if c == null or c.haggle != null or (main.hud and main.hud.is_blocking()):
		_wait = 0.0
		return
	# Oyuncuya önce bir şans tanır, sonra kendisi satar.
	_wait += dt
	if _wait > 6.0:
		_wait = 0.0
		if c.kind == "complainer":
			main.resolve_complaint(c, true)
			Game.notify.emit("Kasiyer şikâyetçi müşteriye para iadesi yaptı.", "info")
			return
		c.validate_basket()
		if c.basket.is_empty():
			c.walk_out_angry()
			return
		var price: int = int(round(c.basket_value() * 1.05))
		main.complete_sale(c, price)
		Game.notify.emit("Kasiyer sattı: +%d ₺" % price, "good")


func _keeper(dt: float, moving: bool) -> void:
	if moving:
		return
	if _target and is_instance_valid(_target):
		_wait -= dt
		_face(_target.look_target())
		if _wait <= 0.0:
			_care(_target)
			_target = null
		return
	_work_timer -= dt
	if _work_timer > 0.0:
		return
	_work_timer = 8.0
	for aq in shop.aquariums:
		var t: Dictionary = Game.tanks[aq.tank_id]
		if TankSim.dead_count(t) > 0 or (not TankSim.living(t).is_empty() and t.food < 35.0) or t.dirt > 60.0:
			_target = aq
			_wait = 2.5
			var vp: Vector3 = aq.view_point()
			_path = shop.path(global_position, Vector3(vp.x, 0, vp.z))
			return


func _care(aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	var did: Array = []
	var dead := TankSim.remove_dead(t)
	if dead > 0:
		did.append("%d ölü balığı çıkardı" % dead)
	var food_pid: String = TankSim.best_food(t, Game.stock)
	if not TankSim.living(t).is_empty() and t.food < 35.0 and food_pid != "":
		Game.use_stock(food_pid)
		TankSim.feed(t, ProductDB.get_product(food_pid).food)
		aq.play_feed()
		did.append("yem verdi")
	if t.dirt > 60.0 and Game.stock.get("su_duzenleyici", 0) > 0:
		Game.use_stock("su_duzenleyici")
		TankSim.water_change(t)
		did.append("suyu değiştirdi")
	if not did.is_empty():
		Game.tank_changed.emit(aq.tank_id)
		Game.notify.emit("Bakımcı (Tank %d): %s." % [aq.tank_id + 1, ", ".join(did)], "info")
	elif TankSim.best_food(t, Game.stock) == "":
		Game.notify.emit("Bakımcı: Depoda yem kalmadı!", "warn")


func _follow(dt: float) -> bool:
	if _path.is_empty():
		return false
	var target: Vector3 = _path[0]
	var to := target - global_position
	to.y = 0
	var d := to.length()
	if d < 0.05:
		_path.pop_front()
		return not _path.is_empty()
	global_position += to / d * min(d, 1.3 * dt)
	transform.basis = transform.basis.orthonormalized().slerp(Basis.looking_at(to / d, Vector3.UP), clamp(dt * 8.0, 0.0, 1.0))
	return true


func _face(p: Vector3) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() > 0.01:
		transform.basis = Basis.looking_at(to.normalized(), Vector3.UP)
