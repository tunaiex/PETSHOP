extends Node
## Oyunun genel durumu: para, zaman, itibar, stok, tanklar, kayıt.

signal money_changed(value: int)
signal time_changed(minute: int)
signal phase_changed(phase: String)
signal notify(text: String, kind: String)
signal tank_changed(id: int)
signal stock_changed()
signal day_ended(report: Dictionary)

const SAVE_PATH := "user://kayit.json"
const OPEN_MINUTE := 9 * 60
const CLOSE_MINUTE := 19 * 60
const PREP_MINUTE := 8 * 60 + 30
const SECONDS_PER_MINUTE := 0.5
const RENT := 300
const RENT_GROWTH := 25 ## Kira her gün artar (enflasyon!)
const TANK_COUNT := 5

var money: int = 1000
var day: int = 1
var minute: float = PREP_MINUTE
var phase: String = "prep" ## prep | open | closing | report | over
var reputation: float = 50.0
var debt_days: int = 0
var stock: Dictionary = {}
var tanks: Array = []
var stats: Dictionary = {}
var time_scale: float = 1.0
var rng := RandomNumberGenerator.new()

var _accum: float = 0.0


func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_game()


func new_game() -> void:
	money = 1000
	day = 1
	minute = PREP_MINUTE
	phase = "prep"
	reputation = 50.0
	debt_days = 0
	stock = {"yem": 6, "su_duzenleyici": 3, "ilac": 1, "filtre": 2, "dekor": 3, "kum": 3}
	tanks.clear()
	for i in TANK_COUNT:
		tanks.append(TankSim.new_tank(i, i <= 2, 25.0))
	tanks[1].heater = 21.0
	tanks[1].temp = 21.0
	for i in 6:
		tanks[0].fish.append(TankSim.new_fish("neon", rng.randf_range(0.5, 0.9)))
	for i in 4:
		tanks[0].fish.append(TankSim.new_fish("lepistes", rng.randf_range(0.5, 0.9)))
	for i in 3:
		tanks[1].fish.append(TankSim.new_fish("japon", rng.randf_range(0.5, 0.9)))
	tanks[2].heater = 21.0
	tanks[2].temp = 21.0
	_reset_stats()


func _reset_stats() -> void:
	stats = {"sales": 0, "revenue": 0, "purchases": 0, "deaths": 0, "lost_customers": 0, "happy": 0}


func _process(delta: float) -> void:
	if phase != "open" and phase != "closing":
		return
	_accum += delta * time_scale
	while _accum >= SECONDS_PER_MINUTE:
		_accum -= SECONDS_PER_MINUTE
		advance_minute()


func advance_minute() -> void:
	minute += 1.0
	for t in tanks:
		var before: int = TankSim.dead_count(t)
		var events: Array = TankSim.step(t, 1.0, rng)
		var after: int = TankSim.dead_count(t)
		if after > before:
			stats.deaths += after - before
		for e in events:
			notify.emit(e, "warn")
		if not events.is_empty():
			tank_changed.emit(t.id)
	if phase == "open" and minute >= CLOSE_MINUTE:
		set_phase("closing")
		notify.emit("Saat 19:00. Dükkân kapanıyor, içerideki müşterileri hallet.", "info")
	time_changed.emit(int(minute))


func set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)


func open_shop() -> void:
	if phase != "prep":
		return
	minute = OPEN_MINUTE
	set_phase("open")
	notify.emit("Dükkân açıldı! Kolay gelsin.", "good")


func clock_text() -> String:
	var m: int = int(minute)
	return "%02d:%02d" % [m / 60, m % 60]


## Gün içinde ne kadar zaman geçti (0..1)
func day_progress() -> float:
	return clamp((minute - OPEN_MINUTE) / float(CLOSE_MINUTE - OPEN_MINUTE), 0.0, 1.0)


func add_money(v: int) -> void:
	money += v
	money_changed.emit(money)


func can_afford(v: int) -> bool:
	return money >= v


func spend(v: int) -> bool:
	if money < v:
		notify.emit("Yeterli paran yok.", "bad")
		return false
	add_money(-v)
	stats.purchases += v
	return true


func use_stock(id: String, n: int = 1) -> bool:
	if stock.get(id, 0) < n:
		notify.emit("Stokta %s kalmadı. Tabletten sipariş ver." % ProductDB.get_product(id).name, "bad")
		return false
	stock[id] -= n
	stock_changed.emit()
	return true


func add_stock(id: String, n: int) -> void:
	stock[id] = stock.get(id, 0) + n
	stock_changed.emit()


func change_reputation(d: float) -> void:
	reputation = clamp(reputation + d, 0.0, 100.0)


func record_sale(amount: int, fair_value: int) -> void:
	add_money(amount)
	stats.sales += 1
	stats.revenue += amount
	stats.happy += 1
	# Değerinin çok üstünde satış itibarı biraz düşürür, makul satış artırır.
	var ratio: float = float(amount) / float(max(1, fair_value))
	if ratio > 1.35:
		change_reputation(-1.5)
	elif ratio < 1.15:
		change_reputation(1.0)
	else:
		change_reputation(0.4)


func record_lost_customer(angry: bool) -> void:
	stats.lost_customers += 1
	change_reputation(-3.0 if angry else -1.0)


func daily_expenses() -> Dictionary:
	var elec := 0
	for t in tanks:
		if t.unlocked:
			elec += 12 + int(max(0.0, t.heater - TankSim.ROOM_TEMP) * 4.0) + int(t.filter) * 3
	var rent: int = RENT + RENT_GROWTH * (day - 1)
	return {"rent": rent, "electric": elec, "total": rent + elec}


func end_day() -> Dictionary:
	var costs: Dictionary = daily_expenses()
	add_money(-costs.total)
	if money < 0:
		debt_days += 1
	else:
		debt_days = 0
	var report := stats.duplicate()
	report["day"] = day
	report["rent"] = costs.rent
	report["electric"] = costs.electric
	report["money"] = money
	report["reputation"] = reputation
	report["debt_days"] = debt_days
	if debt_days >= 3:
		set_phase("over")
		report["over"] = true
	else:
		set_phase("report")
		report["over"] = false
	day_ended.emit(report)
	return report


func next_day() -> void:
	day += 1
	minute = PREP_MINUTE
	_reset_stats()
	set_phase("prep")
	save_game()
	time_changed.emit(int(minute))


# ---------------------------------------------------------------- Kayıt

func to_dict() -> Dictionary:
	return {
		"version": 1, "money": money, "day": day, "reputation": reputation,
		"debt_days": debt_days, "stock": stock, "tanks": tanks,
	}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != 1:
		return false
	money = int(d.money)
	day = int(d.day)
	reputation = float(d.reputation)
	debt_days = int(d.debt_days)
	stock = {}
	for k in d.stock:
		stock[k] = int(d.stock[k])
	tanks = []
	var max_uid := 0
	for t in d.tanks:
		var tank: Dictionary = t
		tank.id = int(tank.id)
		tank.filter = int(tank.filter)
		for f in tank.fish:
			f.uid = int(f.uid)
			max_uid = max(max_uid, f.uid)
		tanks.append(tank)
	TankSim.set_uid_floor(max_uid)
	minute = PREP_MINUTE
	phase = "prep"
	_reset_stats()
	return true


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return from_dict(data)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
