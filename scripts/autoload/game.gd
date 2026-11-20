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
signal boxes_changed()
signal carry_changed()
signal settings_changed()
signal power_changed(on: bool)

const SAVE_PATH := "user://kayit.json"
const OPEN_MINUTE := 9 * 60
const CLOSE_MINUTE := 19 * 60
const PREP_MINUTE := 8 * 60 + 30
const SECONDS_PER_MINUTE := 0.5
const RENT := 300
const RENT_GROWTH := 25 ## Kira her gün artar (enflasyon!)
const START_MONEY := 4000
const SALARY := {"kasiyer": 180, "bakimci": 140}
const EXPAND_COST := [6000, 9000]
const MAX_LEVEL := 0 ## Mağaza binası sabit: genişletme yok
const BOX_SIZE := 10
const BRANCH_COST := 25000
const LOANS := [[5000, 10, 600], [15000, 10, 1750]] ## tutar, gün, günlük taksit
const WALL_COLORS := [
	["Kırık beyaz", Color(0.86, 0.88, 0.84), Color(0.50, 0.36, 0.24)],
	["Okyanus mavisi", Color(0.62, 0.78, 0.86), Color(0.22, 0.32, 0.42)],
	["Nane yeşili", Color(0.72, 0.86, 0.76), Color(0.42, 0.33, 0.24)],
	["Kum beji", Color(0.9, 0.83, 0.7), Color(0.45, 0.3, 0.2)],
	["Antrasit", Color(0.32, 0.34, 0.37), Color(0.18, 0.18, 0.2)],
]
## Zemin seçenekleri: tex = dokulu PBR malzeme, yoksa prosedürel ahşap (a/b renkleri)
const FLOOR_TYPES := [
	["Terrazzo karo", Color(1, 1, 1), Color(1, 1, 1), "terrazzo"],
	["Beyaz mermer", Color(1, 1, 1), Color(1, 1, 1), "marble"],
	["Meşe parke", Color(0.62, 0.45, 0.30), Color(0.48, 0.33, 0.21), ""],
	["Koyu ceviz", Color(0.36, 0.24, 0.16), Color(0.26, 0.17, 0.11), ""],
	["Endüstriyel beton", Color(1, 1, 1), Color(1, 1, 1), "concrete"],
]
const REGULAR_NAMES := ["Hüseyin Amca", "Ayşe Hanım", "Mert", "Zeynep", "Kemal Usta", "Elif Teyze"]

var money: int = START_MONEY
var day: int = 1
var minute: float = PREP_MINUTE
var phase: String = "prep" ## prep | open | closing | report | over
var reputation: float = 50.0
var debt_days: int = 0
var stock: Dictionary = {}   ## Depo (arka oda). Raftaki ürünler mobilya kaydında durur.
const RACK_TANK_PRICE := 420 ## Raf katına konan ışıklı akvaryum
const RACK_TANK_CAP := 8      ## Raf akvaryumunun yer kapasitesi
const SHELF_TANK_PRICE := 260 ## Mağaza rafının bir katına konan küçük ışıklı akvaryum
const SHELF_TANK_CAP := 5
var tanks: Array = []        ## Satılan tanklar silinmez, "unlocked=false" olur (id'ler sabit kalsın)
var furniture: Array = []    ## {"uid","type","x","z","rot", "tank"?, "shelf"?}
var _fuid: int = 1

# --- Dükkân
var settings: Dictionary = {"wall": 0, "floor": 0, "name": "PETSHOP", "catch_game": true}
var shop_level: int = 0
var employees: Dictionary = {"kasiyer": false, "bakimci": false}
var boxes: Array = []        ## Kapıya gelen koliler {"uid","pid","n"}
var carrying: Dictionary = {}## Oyuncunun elindeki koli
var _buid: int = 1
# --- Günlük durum
var weather: String = "gunesli" ## gunesli | bulutlu | yagmurlu
var power_out: bool = false
var events_today: Dictionary = {}
var price_mult: Dictionary = {}
var campaign: Dictionary = {}    ## {"target": "fish"|"products", "pct": 20}
var photos_today: Array = []
# --- Müşteriler
var regulars: Array = []         ## {"name","loyalty","visits"}
var complaints: Array = []       ## {"name","amount","species"}
var special_orders: Array = []   ## {"id","name","species","qty","due","done"}
# --- Ekonomi
var followers: int = 0
var loan: Dictionary = {}        ## {"days_left","daily"}
var branches: int = 0
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
	settings = {"wall": 0, "floor": 0, "name": "PETSHOP", "catch_game": true}
	shop_level = 0
	employees = {"kasiyer": false, "bakimci": false}
	boxes = []
	carrying = {}
	_buid = 1
	regulars = []
	for n in REGULAR_NAMES:
		regulars.append({"name": n, "loyalty": 30, "visits": 0})
	complaints = []
	special_orders = []
	followers = 0
	loan = {}
	branches = 0
	_reset_stats()
	for f in starter_layout():
		add_furniture(f[0], f[1], f[2], f[3])
	roll_day()


## Hazır eşyalar: mağaza sahnesindeki (scenes/magaza.tscn) "Esyalar" altındaki EsyaYeri düğümleri.
## Sahne yoksa ya da eşya yeri yoksa aşağıdaki varsayılan liste kullanılır.
func starter_layout() -> Array:
	var path := "res://scenes/magaza.tscn"
	if not ResourceLoader.exists(path):
		return STARTER_LAYOUT
	var st: SceneState = (load(path) as PackedScene).get_state()
	var out: Array = []
	for i in st.get_node_count():
		var tip := ""
		var xf := Transform3D.IDENTITY
		for k in st.get_node_property_count(i):
			match str(st.get_node_property_name(i, k)):
				"tip":
					tip = str(st.get_node_property_value(i, k))
				"transform":
					xf = st.get_node_property_value(i, k)
		if tip != "" and FurnitureDB.ITEMS.has(tip) and str(st.get_node_path(i)).contains("Esyalar"):
			out.append([tip, xf.origin.x, xf.origin.z, rad_to_deg(xf.basis.get_euler().y)])
	return out if not out.is_empty() else STARTER_LAYOUT


## Hazır dükkân: rafları, dolapları ve kasası yerinde ama bomboş gelir (ürünleri oyuncu dizer).
const STARTER_LAYOUT := [
	# Sol duvar boyunca 5 duvar rafı
	["duvar_rafi_m", -6.88, 2.9, 90.0], ["duvar_rafi_m", -6.88, 1.7, 90.0], ["duvar_rafi_m", -6.88, 0.5, 90.0],
	["duvar_rafi_m", -6.88, -0.7, 90.0], ["kose_rafi", -6.66, -3.05, 90.0],
	# İki reyon sırası, aralarda geniş koridor
	["reyon", -4.0, 0.0, 90.0], ["reyon", -4.0, 1.3, 90.0], ["reyon_basi", -4.0, 2.25, 0.0],
	["reyon", -1.6, 0.0, 90.0], ["reyon", -1.6, 1.3, 90.0], ["reyon_basi", -1.6, 2.25, 0.0],
	# Arka duvarda soğutucular
	["buzdolabi", -5.6, -3.08, 0.0], ["buzdolabi", -4.25, -3.08, 0.0],
	["dondurucu_dik", -3.1, -3.06, 0.0], ["dondurucu_dik", -2.3, -3.06, 0.0], ["icecek_dolabi", -1.5, -3.2, 0.0],
	["sandik_dondurucu", 1.0, -2.9, 0.0],
	# Sağ duvar rafları (kasanın gerisinde değil)
	["duvar_rafi_m", 6.88, -2.8, 270.0], ["duvar_rafi_m", 6.88, -1.6, 270.0], ["duvar_rafi_m", 6.88, -0.4, 270.0],
	["sergi_masasi", 3.2, 2.0, 0.0],
	# Kasa: arkasında 1 m geçit
	["kasa", 5.6, 3.3, 270.0], ["kasa_onu_raf", 5.6, 1.9, 270.0], ["delikli_pano", 7.08, 3.3, 270.0],
	["sepet_standi", -0.6, 4.35, 180.0],
]


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
	if FurnitureDB.is_pen(type):
		var info: Dictionary = FurnitureDB.item(type)
		var pen := TankSim.new_pen(tanks.size(), str(info.pen), int(info.pen_cap))
		tanks.append(pen)
		e["tank"] = pen.id
	elif FurnitureDB.is_tank(type):
		var t := TankSim.new_tank(tanks.size(), true, 25.0, false)
		if type == "teraryum":
			t["kind"] = "teraryum"
		tanks.append(t)
		e["tank"] = t.id
	if FurnitureDB.is_shelf(type):
		e["shelf"] = {}
	if FurnitureDB.is_rack(type):
		# Raf katları boş gelir: tanklar kilitli açılır, oyuncu katlara akvaryum alır.
		var ids: Array = []
		var filled: bool = bool(FurnitureDB.item(type).get("rack", {}).get("prefilled", false))
		for i in rack_slots(type):
			var t := TankSim.new_tank(tanks.size(), filled, 25.0, false)
			t["cap"] = rack_cap(type)
			if filled:
				# Hazır dolu bölme: kum, ışık, filtre ve olgun su
				t.light = true
				t.gravel = "natural"
				t.filter = 1
				t.cycle = 100.0
				t.air = true
			tanks.append(t)
			ids.append(t.id)
		e["tanks"] = ids
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


## Mağaza rafının bir katına küçük akvaryum koyar. O katın ürünleri depoya döner.
func place_shelf_tank(uid: int, lvl: int) -> String:
	var e := furniture_by_uid(uid)
	if e.is_empty() or not FurnitureDB.item(e.type).get("shelf", {}).get("tanks", false):
		return "Bu rafa akvaryum konmaz."
	var st: Dictionary = e.get("shelf_tanks", {})
	if st.has(str(lvl)):
		return "Bu katta zaten akvaryum var."
	if not spend(SHELF_TANK_PRICE):
		return "Yeterli paran yok (%d ₺)." % SHELF_TANK_PRICE
	var t := TankSim.new_tank(tanks.size(), true, 25.0, false)
	t["cap"] = SHELF_TANK_CAP
	t.light = true
	tanks.append(t)
	st[str(lvl)] = t.id
	e["shelf_tanks"] = st
	# Kapasite azaldı: sığmayan ürünler depoya
	var cap: int = shelf_capacity(e)
	for pid in e.shelf.keys():
		while shelf_total(e) > cap and int(e.shelf[pid]) > 0:
			e.shelf[pid] = int(e.shelf[pid]) - 1
			add_stock(pid, 1)
		if int(e.shelf.get(pid, 0)) <= 0:
			e.shelf.erase(pid)
	furniture_changed.emit()
	stock_changed.emit()
	tank_changed.emit(t.id)
	return ""


func remove_shelf_tank(uid: int, lvl: int) -> String:
	var e := furniture_by_uid(uid)
	var st: Dictionary = e.get("shelf_tanks", {})
	if not st.has(str(lvl)):
		return "Bu katta akvaryum yok."
	var t: Dictionary = tanks[int(st[str(lvl)])]
	if not t.fish.is_empty():
		return "Önce içindeki balıkları sat ya da taşı."
	t.unlocked = false
	st.erase(str(lvl))
	add_money(SHELF_TANK_PRICE / 2)
	furniture_changed.emit()
	return ""


## Raf kapasitesi: akvaryum konan katlar ürün almaz.
func shelf_capacity(e: Dictionary) -> int:
	var info: Dictionary = FurnitureDB.item(e.type)
	var cap: int = int(info.get("capacity", 20))
	var cfg: Dictionary = info.get("shelf", {})
	var rows: int = cfg.get("levels", []).size() * int(cfg.get("sides", 1))
	var used: int = e.get("shelf_tanks", {}).size()
	if rows <= 0 or used == 0:
		return cap
	return int(floor(float(cap) * float(rows - used) / float(rows)))


## Akvaryum rafının bölme sayısı, bölme fiyatı ve bölme akvaryumunun kapasitesi
func rack_slots(type: String) -> int:
	var r: Dictionary = FurnitureDB.item(type).get("rack", {})
	return r.get("levels", [0, 0, 0]).size() * r.get("bays", [0]).size()


func rack_price(type: String) -> int:
	return int(FurnitureDB.item(type).get("rack", {}).get("slot_price", RACK_TANK_PRICE))


func rack_cap(type: String) -> int:
	return int(FurnitureDB.item(type).get("rack", {}).get("slot_cap", RACK_TANK_CAP))


## Raf katına ışıklı akvaryum koyar. Başarılıysa "" döner.
func buy_rack_tank(uid: int, level: int) -> String:
	var e := furniture_by_uid(uid)
	if e.is_empty() or not e.has("tanks") or level < 0 or level >= e.tanks.size():
		return "Raf bulunamadı."
	var id: int = int(e.tanks[level])
	if tanks[id].unlocked:
		return "Bu katta zaten akvaryum var."
	if not spend(rack_price(e.type)):
		return "Yeterli paran yok (%d ₺)." % rack_price(e.type)
	var t := TankSim.new_tank(id, true, 25.0, false)
	t["cap"] = rack_cap(e.type)
	t.light = true
	tanks[id] = t
	furniture_changed.emit()
	tank_changed.emit(id)
	return ""


## Raf katındaki boş akvaryumu kaldırır (%50 iade).
func remove_rack_tank(uid: int, level: int) -> String:
	var e := furniture_by_uid(uid)
	if e.is_empty() or not e.has("tanks") or level < 0 or level >= e.tanks.size():
		return "Raf bulunamadı."
	var t: Dictionary = tanks[int(e.tanks[level])]
	if not t.unlocked:
		return "Bu kat zaten boş."
	if not t.fish.is_empty():
		return "Önce tanktaki balıkları sat ya da taşı."
	t.unlocked = false
	add_money(rack_price(e.type) / 2)
	furniture_changed.emit()
	return ""


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
	var refund: int = int(FurnitureDB.item(e.type).price) / 2
	for k in e.get("shelf_tanks", {}):
		if not tanks[int(e.shelf_tanks[k])].fish.is_empty():
			return "Önce raftaki akvaryumların balıklarını sat ya da taşı."
	for k in e.get("shelf_tanks", {}):
		tanks[int(e.shelf_tanks[k])].unlocked = false
		refund += SHELF_TANK_PRICE / 2
	if e.has("tanks"):
		for id in e.tanks:
			if not tanks[int(id)].fish.is_empty():
				return "Önce raftaki tanklardaki balıkları sat ya da çıkar."
		for id in e.tanks:
			if tanks[int(id)].unlocked:
				tanks[int(id)].unlocked = false
				refund += rack_price(e.type) / 2
	if e.has("shelf"):
		for pid in e.shelf:
			add_stock(pid, int(e.shelf[pid]))
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
	if e.is_empty() or not e.has("shelf") or not FurnitureDB.shelf_accepts(e.type, pid):
		return 0
	var cap: int = shelf_capacity(e)
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
	stats = {"sales": 0, "revenue": 0, "purchases": 0, "deaths": 0, "lost_customers": 0, "happy": 0, "stolen": 0, "fines": 0, "refunds": 0, "tips": 0}


# ---------------------------------------------------------------- Günlük olaylar

## Her sabah: hava, fiyatlar, rastgele olaylar.
func roll_day() -> void:
	var r: float = rng.randf()
	weather = "gunesli" if r < 0.55 else ("bulutlu" if r < 0.8 else "yagmurlu")
	price_mult = {}
	for id in FishDB.ids():
		price_mult[id] = snapped(rng.randf_range(0.75, 1.35), 0.05)
	for id in ProductDB.ids():
		price_mult[id] = snapped(rng.randf_range(0.8, 1.25), 0.05)
	events_today = {}
	if rng.randf() < 0.18:
		events_today["power_at"] = rng.randi_range(OPEN_MINUTE + 60, CLOSE_MINUTE - 120)
		events_today["power_len"] = rng.randi_range(40, 90)
	if day > 1 and rng.randf() < 0.15:
		events_today["inspector_at"] = rng.randi_range(OPEN_MINUTE + 60, CLOSE_MINUTE - 120)
	if day % 7 == 0:
		events_today["contest"] = true
	campaign = {}
	photos_today = []
	power_out = false
	for o in special_orders.duplicate():
		if int(o.due) < day:
			special_orders.erase(o)
			change_reputation(-2.0)
			notify.emit("%s'in özel siparişini zamanında getiremedin. İtibar düştü." % o.name, "bad")


func buy_price(id: String) -> int:
	var base: int = int(FishDB.get_species(id).buy) if FishDB.SPECIES.has(id) else int(ProductDB.get_product(id).buy)
	return max(1, int(round(base * float(price_mult.get(id, 1.0)))))


func room_min_x() -> float:
	return Shop.ROOM.position.x


func has_furniture(type: String) -> bool:
	return count_furniture(type) > 0


# ---------------------------------------------------------------- Koliler

func add_delivery(pid: String, n: int) -> void:
	while n > 0:
		var k: int = min(n, BOX_SIZE)
		boxes.append({"uid": _buid, "pid": pid, "n": k})
		_buid += 1
		n -= k
	boxes_changed.emit()


## Canlı hayvan siparişi: hepsi tek bir poşet / taşıma kutusu olarak kapıya gelir.
## Oyuncu kutuyu alıp uygun tanka/kafese koyar. Nadir çıkan sayısını döner.
func order_animals(sp: String, qty: int) -> int:
	var fish: Array = []
	var rare := 0
	for i in qty:
		var nf: Dictionary = TankSim.supplier_fish(sp, rng)
		if nf.get("rare", false):
			rare += 1
		fish.append(nf)
	boxes.append({"uid": _buid, "species": sp, "fish": fish, "n": qty})
	_buid += 1
	boxes_changed.emit()
	return rare


func is_animal_box(b: Dictionary) -> bool:
	return b.has("species")


## Elindeki canlıları tanka/kafese bırakır. Hata metni ya da "" döner.
## Yer yetmezse sığanlar konur, kalanlar elde kalır.
func release_to_tank(tank_id: int) -> String:
	if carrying.is_empty() or not is_animal_box(carrying):
		return "Elinde canlı yok."
	var t: Dictionary = tanks[tank_id]
	var sp: String = carrying.species
	var err: String = TankSim.check_add(t, sp)
	var home_ok: bool = TankSim.habitat_of(t) == FishDB.habitat(sp) and bool(t.get("salt", false)) == FishDB.is_salt(sp)
	if not home_ok:
		return err
	if err.begins_with("Tankta yer yok"):
		err = ""
	var moved := 0
	for f in carrying.fish.duplicate():
		if TankSim.space_used(t) + TankSim.space_of(sp) > TankSim.capacity(t):
			break
		t.fish.append(f)
		carrying.fish.erase(f)
		moved += 1
	if moved == 0:
		return "Yer yok (%d/%d)." % [TankSim.space_used(t), TankSim.capacity(t)]
	carrying.n = carrying.fish.size()
	if carrying.fish.is_empty():
		carrying = {}
	carry_changed.emit()
	tank_changed.emit(tank_id)
	if err != "":
		notify.emit("Dikkat: " + err, "warn")
	return ""


func pick_box(uid: int) -> bool:
	if not carrying.is_empty():
		notify.emit("Elinde zaten bir koli var.", "bad")
		return false
	for b in boxes:
		if int(b.uid) == uid:
			carrying = b
			boxes.erase(b)
			boxes_changed.emit()
			carry_changed.emit()
			return true
	return false


## Elindeki koliden rafa dizer. Dizilen adet.
func carry_to_shelf(shelf_uid: int) -> int:
	if carrying.is_empty():
		return 0
	if is_animal_box(carrying):
		notify.emit("Canlılar rafa dizilmez, bir tanka/kafese koy.", "bad")
		return 0
	var e := furniture_by_uid(shelf_uid)
	if not FurnitureDB.shelf_accepts(e.type, carrying.pid):
		notify.emit("Bu ürün buraya konmaz (%s)." % ("soğutucuya sadece donuk/soğuk ürün" if FurnitureDB.item(e.type).get("shelf", {}).get("cold", false) else "soğuk ürün soğutucuda durmalı"), "bad")
		return 0
	var cap: int = shelf_capacity(e)
	var move: int = min(int(carrying.n), cap - shelf_total(e))
	if move <= 0:
		notify.emit("Raf dolu.", "bad")
		return 0
	e.shelf[carrying.pid] = int(e.shelf.get(carrying.pid, 0)) + move
	carrying.n = int(carrying.n) - move
	if carrying.n <= 0:
		carrying = {}
	carry_changed.emit()
	stock_changed.emit()
	return move


## Elindeki koliyi/poşeti olduğun yere, yere bırakır (sonra tekrar alınabilir).
func drop_carrying(x: float, z: float, rot: float) -> void:
	if carrying.is_empty():
		return
	carrying["pos"] = [x, z, rot]
	boxes.append(carrying)
	carrying = {}
	boxes_changed.emit()
	carry_changed.emit()


func carry_to_depot() -> void:
	if carrying.is_empty():
		return
	if is_animal_box(carrying):
		notify.emit("Canlılar depoya konmaz! Uygun bir tanka/kafese bakıp bırak.", "bad")
		return
	add_stock(carrying.pid, int(carrying.n))
	carrying = {}
	carry_changed.emit()


# ---------------------------------------------------------------- Müşteri kayıtları

func regular(name_: String) -> Dictionary:
	for r in regulars:
		if r.name == name_:
			return r
	return {}


func change_loyalty(name_: String, d: float) -> void:
	var r := regular(name_)
	if not r.is_empty():
		r.loyalty = clamp(float(r.loyalty) + d, 0.0, 100.0)


func _process(delta: float) -> void:
	if phase != "open" and phase != "closing":
		return
	_accum += delta * time_scale
	while _accum >= SECONDS_PER_MINUTE:
		_accum -= SECONDS_PER_MINUTE
		advance_minute()


func advance_minute() -> void:
	minute += 1.0
	if events_today.has("power_at") and not has_furniture("jenerator"):
		var start: int = int(events_today.power_at)
		var out: bool = minute >= start and minute < start + int(events_today.power_len)
		if out != power_out:
			power_out = out
			power_changed.emit(not out)
			notify.emit("ELEKTRİK KESİLDİ! Isıtıcılar, filtreler ve lambalar durdu." if out else "Elektrik geldi.", "bad" if out else "good")
	TankSim.power_on = not power_out
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
	var rent: int = RENT + RENT_GROWTH * (day - 1) + 150 * shop_level
	var salary := 0
	for k in employees:
		if employees[k]:
			salary += int(SALARY[k])
	var loan_pay: int = int(loan.get("daily", 0)) if not loan.is_empty() else 0
	return {"rent": rent, "electric": elec, "salary": salary, "loan": loan_pay, "total": rent + elec + salary + loan_pay}


func end_day() -> Dictionary:
	var costs: Dictionary = daily_expenses()
	add_money(-costs.total)
	if not loan.is_empty():
		loan.days_left = int(loan.days_left) - 1
		if loan.days_left <= 0:
			loan = {}
			notify.emit("Kredi borcu bitti!", "good")
	var branch_income := 0
	for i in branches:
		branch_income += 250 + int(reputation * 7.0) + rng.randi_range(-200, 300) - 250
	if branch_income != 0:
		add_money(branch_income)
	var contest: Dictionary = {}
	if events_today.get("contest", false):
		contest = run_contest()
	if money < 0:
		debt_days += 1
	else:
		debt_days = 0
	var report := stats.duplicate()
	report["day"] = day
	report["rent"] = costs.rent
	report["electric"] = costs.electric
	report["salary"] = costs.salary
	report["loan"] = costs.loan
	report["branch"] = branch_income
	report["contest"] = contest
	report["followers"] = followers
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


## Yarışma: en iyi tankın puanı rakiplerle karşılaştırılır.
func run_contest() -> Dictionary:
	var best := 0.0
	var best_id := -1
	for t in tanks:
		if not t.unlocked or TankSim.living(t).is_empty():
			continue
		var sc: float = TankSim.appeal(t) * 0.6 + TankSim.species_in(t).size() * 5.0 + TankSim.average_health(t) * 0.2
		for f in TankSim.living(t):
			if f.get("rare", false):
				sc += 10.0
		if sc > best:
			best = sc
			best_id = t.id
	var rivals: Array = [rng.randf_range(45, 70), rng.randf_range(55, 80), rng.randf_range(65, 95)]
	var place: int = 1
	for r in rivals:
		if r > best:
			place += 1
	var prizes := {1: [2500, 8.0], 2: [1000, 4.0], 3: [400, 2.0]}
	var res := {"score": int(best), "tank": best_id, "place": place, "prize": 0}
	if prizes.has(place):
		res.prize = prizes[place][0]
		add_money(prizes[place][0])
		change_reputation(prizes[place][1])
	return res


func next_day() -> void:
	day += 1
	minute = PREP_MINUTE
	_reset_stats()
	roll_day()
	set_phase("prep")
	save_game()
	time_changed.emit(int(minute))


# ---------------------------------------------------------------- Kayıt

func to_dict() -> Dictionary:
	return {
		"version": 3, "money": money, "day": day, "reputation": reputation,
		"debt_days": debt_days, "stock": stock, "tanks": tanks,
		"furniture": furniture, "fuid": _fuid,
		"settings": settings, "shop_level": shop_level, "employees": employees,
		"boxes": boxes + ([carrying] if not carrying.is_empty() else []), "buid": _buid,
		"regulars": regulars, "complaints": complaints, "special_orders": special_orders,
		"followers": followers, "loan": loan, "branches": branches,
	}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != 3:
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
		if e.has("tanks"):
			e.tanks = e.tanks.map(func(v): return int(v))
		if e.has("shelf_tanks"):
			for k in e.shelf_tanks:
				e.shelf_tanks[k] = int(e.shelf_tanks[k])
		if e.has("shelf"):
			for pid in e.shelf:
				e.shelf[pid] = int(e.shelf[pid])
		furniture.append(e)
	_fuid = int(d.get("fuid", furniture.size() + 1))
	var st: Dictionary = d.get("settings", {})
	settings = {"wall": int(st.get("wall", 0)), "floor": int(st.get("floor", 0)), "name": str(st.get("name", "AKVARYUM DÜKKÂNI")), "catch_game": bool(st.get("catch_game", true))}
	shop_level = int(d.get("shop_level", 0))
	var em: Dictionary = d.get("employees", {})
	employees = {"kasiyer": bool(em.get("kasiyer", false)), "bakimci": bool(em.get("bakimci", false))}
	boxes = []
	for b in d.get("boxes", []):
		if b.has("species"):
			var fl: Array = []
			for f in b.fish:
				f.uid = int(f.uid)
				TankSim.set_uid_floor(f.uid)
				fl.append(f)
			boxes.append({"uid": int(b.uid), "species": str(b.species), "fish": fl, "n": fl.size()})
		else:
			boxes.append({"uid": int(b.uid), "pid": str(b.pid), "n": int(b.n)})
		if b.has("pos"):
			boxes[-1]["pos"] = [float(b.pos[0]), float(b.pos[1]), float(b.pos[2])]
	carrying = {}
	_buid = int(d.get("buid", boxes.size() + 1))
	regulars = d.get("regulars", [])
	if regulars.is_empty():
		for n in REGULAR_NAMES:
			regulars.append({"name": n, "loyalty": 30, "visits": 0})
	complaints = d.get("complaints", [])
	special_orders = []
	for o in d.get("special_orders", []):
		o.qty = int(o.qty)
		o.due = int(o.due)
		special_orders.append(o)
	followers = int(d.get("followers", 0))
	loan = d.get("loan", {})
	branches = int(d.get("branches", 0))
	roll_day()
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
