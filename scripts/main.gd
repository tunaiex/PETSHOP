extends Node3D
## Oyunun kök sahnesi: dükkânı, oyuncuyu ve arayüzü kurar; müşteri akışını ve satışları yönetir.

const MAX_CUSTOMERS := 6

var shop: Shop
var player: Player
var hud: HUD
var builder: Builder
var customers: Array = []
var queue: Array = []
var _spawn_timer: float = 4.0
var _seed: int = 1
var _report_shown := false


func _ready() -> void:
	shop = Shop.new()
	shop.main = self
	add_child(shop)
	shop.build()
	hud = HUD.new()
	hud.main = self
	add_child(hud)
	shop.hud = hud
	# Oyuna dışarıda, kaldırımda, dükkâna bakarak başlanır.
	player = Player.new()
	player.position = Vector3(0, 0.05, Shop.D * 0.5 + 3.0)
	player.rotation.y = 0.0
	player.hud = hud
	add_child(player)
	hud.player = player
	builder = Builder.new()
	builder.player = player
	builder.shop = shop
	add_child(builder)
	hud.builder = builder
	builder.state_changed.connect(hud.on_build_state)
	Game.furniture_changed.connect(func(): _update_queue.call_deferred())
	Game.phase_changed.connect(_on_phase)
	if Game.day == 1 and Game.phase == "prep":
		hud.show_help.call_deferred()


func _on_phase(p: String) -> void:
	if p == "open":
		_spawn_timer = 3.0
		_report_shown = false
	elif p == "prep":
		_report_shown = false


func _process(delta: float) -> void:
	if Game.phase == "open":
		_spawn_timer -= delta * Game.time_scale
		if _spawn_timer <= 0.0:
			_spawn_timer = _next_spawn_delay()
			if customers.size() < MAX_CUSTOMERS:
				spawn_customer()
	elif Game.phase == "closing" and not customers.is_empty() and Game.minute >= Game.CLOSE_MINUTE + 45:
		# Kapanıştan 45 dk sonra kalan herkes çıkar.
		for c in customers.duplicate():
			if c.state != Customer.State.LEAVE:
				c.say("Kapanmışsınız zaten...")
				c.walk_out_angry()
	elif Game.phase == "closing" and customers.is_empty() and not _report_shown:
		_report_shown = true
		var report := Game.end_day()
		hud.show_report(report)


func _next_spawn_delay() -> float:
	var minutes: float = lerp(55.0, 18.0, Game.reputation / 100.0) * Game.rng.randf_range(0.6, 1.4)
	return minutes * Game.SECONDS_PER_MINUTE


func spawn_customer() -> Customer:
	var c := Customer.new()
	add_child(c)
	_seed += 1
	c.setup(self, shop, Game.rng.randi() + _seed)
	c.left_shop.connect(_on_customer_left)
	customers.append(c)
	return c


func _on_customer_left(c: Customer) -> void:
	customers.erase(c)
	queue.erase(c)


# ------------------------------------------------------------------ Sıra

func join_queue(c: Customer) -> void:
	if not queue.has(c):
		queue.append(c)
	_update_queue()


func leave_queue(c: Customer) -> void:
	queue.erase(c)
	_update_queue()


func _update_queue() -> void:
	for i in queue.size():
		queue[i].set_queue_slot(i)


func customer_at_register() -> Customer:
	if queue.is_empty():
		return null
	var c: Customer = queue[0]
	if c.is_waiting_at_register():
		return c
	return null


func reserved_uids() -> Array:
	var out: Array = []
	for c in customers:
		for item in c.basket:
			if item.type == "fish":
				out.append(int(item.uid))
	return out


func find_fish(tank: int, uid: int) -> Dictionary:
	if tank < 0 or tank >= Game.tanks.size():
		return {}
	for f in Game.tanks[tank].fish:
		if int(f.uid) == uid:
			return f
	return {}


## Satışı tamamlar: balıkları tanktan çıkarır, ürünleri stoktan düşer, parayı ekler.
func complete_sale(c: Customer, price: int) -> void:
	c.validate_basket()
	var fair: int = c.basket_value()
	var sick_sold := false
	var touched := {}
	for item in c.basket:
		if item.type == "fish":
			var t: Dictionary = Game.tanks[int(item.tank)]
			var f: Dictionary = find_fish(int(item.tank), int(item.uid))
			if not f.is_empty() and f.health < 60.0:
				sick_sold = true
			t.fish = t.fish.filter(func(x): return int(x.uid) != int(item.uid))
			touched[int(item.tank)] = true
		# Ürünler müşteri raftan alırken zaten raftan düşüldü.
	Game.stock_changed.emit()
	for id in touched:
		Game.tank_changed.emit(id)
	Game.record_sale(price, fair)
	if sick_sold:
		Game.change_reputation(-3.0)
		Game.notify.emit("Halsiz balık sattın. Müşteri memnun kalmayabilir, itibar düştü.", "warn")
	c.finish_sale()


func someone_near_door() -> bool:
	var door := Vector3(0, 0, Shop.D * 0.5)
	if player and player.global_position.distance_to(door) < 2.6:
		return true
	for c in customers:
		if c.global_position.distance_to(door) < 2.6:
			return true
	return false
