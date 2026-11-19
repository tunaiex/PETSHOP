extends Node
## Oyunun genel durumu: para, zaman, itibar, stok, tanklar, kayıt.

signal money_changed(value: int)
signal time_changed(minute: int)
signal phase_changed(phase: String)
signal notify(text: String, kind: String)
signal tank_changed(id: int)
signal stock_changed()
signal day_ended(report: Dictionary)
signal furniture_changed()

const SAVE_PATH := "user://kayit.json"
const OPEN_MINUTE := 9 * 60
const CLOSE_MINUTE := 19 * 60
const PREP_MINUTE := 8 * 60 + 30
const SECONDS_PER_MINUTE := 0.5
const RENT := 300
const RENT_GROWTH := 25 ## Kira her gün artar (enflasyon!)
const START_MONEY := 4000

var money: int = START_MONEY
var day: int = 1
var minute: float = PREP_MINUTE
var phase: String = "prep" ## prep | open | closing | report | over
var reputation: float = 50.0
var debt_days: int = 0
var stock: Dictionary = {}   ## Depo (arka oda). Raftaki ürünler mobilya kaydında durur.
var tanks: Array = []        ## Satılan tanklar silinmez, "unlocked=false" olur (id'ler sabit kalsın)
var furniture: Array = []    ## {"uid","type","x","z","rot", "tank"?, "shelf"?}
var _fuid: int = 1
var stats: Dictionary = {}
var time_scale: float = 1.0
var rng := RandomNumberGenerator.new()

var _accum: float = 0.0


func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_game()


func new_game() -> void:
	money = START_MONEY
	day = 1
	minute = PREP_MINUTE
	phase = "prep"
	reputation = 50.0
	debt_days = 0
	stock = {"yem": 4, "su_duzenleyici": 2}
	tanks.clear()
	furniture.clear()
	_fuid = 1
	_reset_stats()


# ---------------------------------------------------------------- Mobilya

func furniture_by_uid(uid: int) -> Dictionary:
	for f in furniture:
		if int(f.uid) == uid:
			return f
	return {}


func count_furniture(type: String) -> int:
	return furniture.filter(func(f): return f.type == type).size()


## Satın alınmış bir eşyayı kaydeder. Akvaryumsa yeni (çıplak) bir tank oluşturur.
func add_furniture(type: String, x: float, z: float, rot: float) -> Dictionary:
	var e := {"uid": _fuid, "type": type, "x": x, "z": z, "rot": rot}
	_fuid += 1
	if FurnitureDB.is_tank(type):
		var t := TankSim.new_tank(tanks.size(), true, 25.0, false)
		tanks.append(t)
		e["tank"] = t.id
	if FurnitureDB.is_shelf(type):
		e["shelf"] = {}
	furniture.append(e)
	furniture_changed.emit()
	return e


func move_furniture(uid: int, x: float, z: float, rot: float) -> void:
	var e := furniture_by_uid(uid)
	if e.is_empty():
		return
	e.x = x
	e.z = z
	e.rot = rot
	furniture_changed.emit()


## Eşyayı satar (%50 iade). Dolu tank satılamaz, raftaki ürünler depoya döner.
func sell_furniture(uid: int) -> String:
	var e := furniture_by_uid(uid)
	if e.is_empty():
		return "Eşya bulunamadı."
	if e.has("tank"):
		var t: Dictionary = tanks[int(e.tank)]
		if not t.fish.is_empty():
			return "Önce tanktaki balıkları sat ya da çıkar."
		t.unlocked = false
	if e.has("shelf"):
		for pid in e.shelf:
			add_stock(pid, int(e.shelf[pid]))
	var refund: int = int(FurnitureDB.item(e.type).price) / 2
	add_money(refund)
	furniture.erase(e)
	furniture_changed.emit()
	return ""


func shelf_total(e: Dictionary) -> int:
	var n := 0
	for pid in e.get("shelf", {}):
		n += int(e.shelf[pid])
	return n


## Depodan rafa ürün koyar. Gerçekten taşınan adedi döner.
func stock_shelf(uid: int, pid: String, n: int) -> int:
	var e := furniture_by_uid(uid)
	if e.is_empty() or not e.has("shelf"):
		return 0
	var cap: int = int(FurnitureDB.item(e.type).get("capacity", 20))
	var move: int = min(n, int(stock.get(pid, 0)), cap - shelf_total(e))
	if move <= 0:
		return 0
	stock[pid] -= move
	e.shelf[pid] = int(e.shelf.get(pid, 0)) + move
	stock_changed.emit()
	return move


## Raftan depoya geri alır.
func unstock_shelf(uid: int, pid: String, n: int) -> int:
	var e := furniture_by_uid(uid)
	if e.is_empty() or not e.has("shelf"):
		return 0
	var move: int = min(n, int(e.shelf.get(pid, 0)))
	if move <= 0:
		return 0
	e.shelf[pid] -= move
	if e.shelf[pid] <= 0:
		e.shelf.erase(pid)
	add_stock(pid, move)
	return move


## Dükkân dekorunun itibara katkısı
func decor_appeal() -> float:
	var a := 0.0
	for f in furniture:
		a += float(FurnitureDB.item(f.type).get("appeal", 0))
	return a


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
		notify.emit("Depoda %s kalmadı. Telefondan sipariş ver." % ProductDB.get_product(id).name, "bad")
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
			elec += 5 + int(t.filter) * 3
			if t.get("light", false):
				elec += 6
			if t.get("air", false):
				elec += 3
			if t.get("heater_on", false):
				elec += int(max(0.0, t.heater - TankSim.ROOM_TEMP) * 4.0)
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
		"version": 2, "money": money, "day": day, "reputation": reputation,
		"debt_days": debt_days, "stock": stock, "tanks": tanks,
		"furniture": furniture, "fuid": _fuid,
	}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != 2:
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
		TankSim.normalize(tank)
		for f in tank.fish:
			f.uid = int(f.uid)
			max_uid = max(max_uid, f.uid)
		tanks.append(tank)
	TankSim.set_uid_floor(max_uid)
	furniture = []
	for f in d.get("furniture", []):
		var e: Dictionary = f
		e.uid = int(e.uid)
		e.x = float(e.x)
		e.z = float(e.z)
		e.rot = float(e.rot)
		if e.has("tank"):
			e.tank = int(e.tank)
		if e.has("shelf"):
			for pid in e.shelf:
				e.shelf[pid] = int(e.shelf[pid])
		furniture.append(e)
	_fuid = int(d.get("fuid", furniture.size() + 1))
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
