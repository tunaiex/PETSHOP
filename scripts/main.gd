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
var employees: Dictionary = {}  ## rol -> Employee
var _inspector_spawned := false


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
	Game.furniture_changed.connect(sync_employees)
	sync_employees()
	Game.phase_changed.connect(_on_phase)
	if Game.day == 1 and Game.phase == "prep":
		hud.show_help.call_deferred()
	_morning_news.call_deferred()


func _on_phase(p: String) -> void:
	if p == "open":
		_spawn_timer = 3.0
		_report_shown = false
	elif p == "prep":
		_report_shown = false
		_inspector_spawned = false
		_morning_news()


func _process(delta: float) -> void:
	if Game.phase == "open" and not _inspector_spawned and Game.events_today.has("inspector_at") and Game.minute >= int(Game.events_today.inspector_at):
		_inspector_spawned = true
		var ins := spawn_customer()
		ins.make_inspector()
		Game.notify.emit("Belediye müfettişi geldi! Tanklarını inceleyecek.", "warn")
	if Game.phase == "open":
		_spawn_timer -= delta * Game.time_scale
		if _spawn_timer <= 0.0:
			_spawn_timer = _next_spawn_delay()
			if customers.size() < MAX_CUSTOMERS:
				_spawn_varied()
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
	if Game.weather == "yagmurlu":
		minutes *= 1.4
	elif Game.weather == "bulutlu":
		minutes *= 1.1
	if not Game.campaign.is_empty():
		minutes *= 1.0 - float(Game.campaign.pct) / 100.0 * 1.5
	minutes *= 1.0 - min(Game.followers / 2500.0, 0.4)
	var dusk: float = smoothstep(17.5 * 60.0, 19.0 * 60.0, Game.minute)
	minutes *= 1.0 + dusk * 0.5
	return minutes * Game.SECONDS_PER_MINUTE


## Sabah haberleri: hava, yarışma, fiyatlar
func _morning_news() -> void:
	var w: String = {"gunesli": "Güneşli bir gün, müşteri bol olabilir.", "bulutlu": "Hava bulutlu.", "yagmurlu": "Yağmur yağıyor, bugün az müşteri gelir."}.get(Game.weather, "")
	Game.notify.emit("Gün %d: %s" % [Game.day, w], "info")
	if Game.events_today.get("contest", false):
		Game.notify.emit("BUGÜN AKVARYUM YARIŞMASI! Kapanışta en güzel tankın puanlanacak.", "warn")
	var cheap: Array = []
	for id in FishDB.ids():
		if float(Game.price_mult.get(id, 1.0)) <= 0.8:
			cheap.append(FishDB.display_name(id))
	if not cheap.is_empty():
		Game.notify.emit("Toptancıda indirim: " + ", ".join(cheap.slice(0, 3)), "good")


## Çalışanları işe alım durumuna göre sahneye koyar ya da çıkarır.
func sync_employees() -> void:
	for role in ["kasiyer", "bakimci"]:
		var want: bool = Game.employees.get(role, false) and (role != "kasiyer" or shop.counter != null)
		var have: bool = employees.has(role) and is_instance_valid(employees[role])
		if want and not have:
			var e := Employee.new()
			add_child(e)
			e.setup(role, self, shop)
			e.global_position = shop.counter.to_global(Vector3(-0.5, 0, -0.9)) if (role == "kasiyer" and shop.counter) else Vector3(-1.0, 0, 2.5)
			employees[role] = e
		elif not want and have:
			employees[role].queue_free()
			employees.erase(role)


var _special_spawned := {}

## Bugün gelmesi gereken şikâyetçi/özel siparişçi varsa önce onlar, yoksa rastgele bir tür.
func _spawn_varied() -> void:
	if not Game.complaints.is_empty():
		var comp: Dictionary = Game.complaints.pop_front()
		spawn_customer().make_complainer(comp)
		return
	for o in Game.special_orders:
		if Game.day >= int(o.get("ready", 0)) and not _special_spawned.has(str(o.id) + "_" + str(Game.day)):
			_special_spawned[str(o.id) + "_" + str(Game.day)] = true
			spawn_customer().make_special(o)
			return
	var c := spawn_customer()
	var r: float = Game.rng.randf()
	if r < 0.06 and not shop.shelves.is_empty():
		c.make_thief()
	elif r < 0.16:
		c.make_child()
	elif r < 0.45:
		var reg: Dictionary = Game.regulars[Game.rng.randi_range(0, Game.regulars.size() - 1)]
		# Sadakati çok düşük müdavim gelmez
		if float(reg.loyalty) > 10.0:
			c.make_regular(reg)


func spawn_customer() -> Customer:
	Sfx.play("chime", -12.0)
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
				if Game.rng.randf() < 0.7:
					Game.complaints.append({"name": c.profile.title, "amount": c.item_value(item), "species": item.species})
			t.fish = t.fish.filter(func(x): return int(x.uid) != int(item.uid))
			touched[int(item.tank)] = true
		# Ürünler müşteri raftan alırken zaten raftan düşüldü.
	Game.stock_changed.emit()
	for id in touched:
		Game.tank_changed.emit(id)
	Game.record_sale(price, fair)
	Sfx.play("kaching")
	if sick_sold:
		Game.change_reputation(-3.0)
		Game.notify.emit("Halsiz balık sattın. Müşteri memnun kalmayabilir, itibar düştü.", "warn")
	c.finish_sale()


## Şikâyet: iade edersen para gider ama itibar korunur; reddedersen itibar düşer.
func resolve_complaint(c: Customer, refund: bool) -> void:
	var amt: int = int(c.complaint.get("amount", 0))
	if refund:
		Game.add_money(-amt)
		Game.stats.refunds += amt
		Game.change_reputation(1.0)
		c.say("Teşekkürler, anlayışlısınız.", 3.0)
	else:
		Game.change_reputation(-4.0)
		Game.change_loyalty(c.complaint.get("name", ""), -20.0)
		c.say("Bir daha buradan alışveriş yapmam! Herkese anlatacağım!", 4.0)
	c.complaint = {}
	c.walk_out_calm()


func someone_near_door() -> bool:
	var door := Vector3(0, 0, Shop.D * 0.5)
	if player and player.global_position.distance_to(door) < 2.6:
		return true
	for c in customers:
		if c.global_position.distance_to(door) < 2.6:
			return true
	return false
