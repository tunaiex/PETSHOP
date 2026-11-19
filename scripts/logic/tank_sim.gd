class_name TankSim
extends RefCounted
## Akvaryum simülasyonu. Tank verisi düz bir Dictionary'dir (kaydetmesi kolay).
## Tüm oranlar "oyun dakikası" başınadır. Bir iş günü 600 oyun dakikasıdır (09:00-19:00).

const CAPACITY := 12 ## "Yer birimi": küçük balık 1, büyük balık daha fazla yer kaplar
const ROOM_TEMP := 21.0
const FILTER_EFF := [0.0, 0.35, 0.55, 0.75]
const FILTER_COST := [0, 200, 450, 900]
const UNLOCK_COST := 1200
const QUARANTINE_MIN := 180.0 ## Karantinada gözlem süresi (oyun dakikası)
const SALT_COST := 300 ## Tankı tuzlu/tatlı suya çevirme (tuz, test kiti, yeni kum)

static var _uid_counter: int = 1000
static var power_on: bool = true ## Elektrik kesintisinde ısıtıcı, filtre, hava motoru çalışmaz


## equipped: true ise tam donanımlı (eski kayıtlar ve testler için), false ise çıplak cam tank.
static func new_tank(id: int, unlocked: bool, heater: float = 25.0, equipped: bool = true) -> Dictionary:
	return {
		"id": id, "unlocked": unlocked, "heater": heater, "temp": heater if equipped else ROOM_TEMP,
		"dirt": 8.0 if equipped else 0.0, "food": 70.0, "sick": false, "sick_level": 0.0,
		"filter": 1 if equipped else 0, "fish": [], "salt": false,
		"heater_on": equipped, "light": equipped, "air": equipped,
		"gravel": "natural" if equipped else "", "decor": [],
		"cycle": 100.0 if equipped else 0.0,
	}


## Eski kayıtlarda olmayan alanları tamamlar.
static func normalize(tank: Dictionary) -> void:
	var d := new_tank(int(tank.get("id", 0)), true)
	for k in d:
		if not tank.has(k):
			tank[k] = d[k]
	tank.filter = int(tank.filter)
	tank.salt = bool(tank.salt)
	tank.heater_on = bool(tank.heater_on)
	tank.light = bool(tank.light)
	tank.air = bool(tank.air)


## Tedarikçiden gelen balık: bazen hastalık taşır, çok nadiren mutasyonlu çıkar.
static func supplier_fish(species: String, rng: RandomNumberGenerator) -> Dictionary:
	var f := new_fish(species, rng.randf_range(0.45, 0.8), rng.randf_range(80.0, 95.0))
	f["new"] = true
	if rng.randf() < 0.15:
		f["carrier"] = true
	if rng.randf() < 0.02:
		f["rare"] = true
		f["rare_name"] = FishDB.RARE_NAMES[rng.randi_range(0, FishDB.RARE_NAMES.size() - 1)]
	return f


## Balıkları bir tanktan diğerine taşır. Taşınan adet.
static func move_fish(src: Dictionary, dst: Dictionary, species: String, count: int) -> int:
	var moved := 0
	for f in src.fish.duplicate():
		if moved >= count:
			break
		if f.species != species or not f.alive:
			continue
		if space_used(dst) + space_of(species) > CAPACITY:
			break
		src.fish.erase(f)
		dst.fish.append(f)
		moved += 1
	return moved


## Bir balığın kapladığı yer birimi (büyük balık daha çok)
static func space_of(species: String) -> int:
	return max(1, int(round(float(FishDB.get_species(species).length) / 0.07)))


static func space_used(tank: Dictionary) -> int:
	var n := 0
	for f in tank.fish:
		n += space_of(f.species)
	return n


## Müşteriler için tankın çekiciliği (0-100)
static func appeal(tank: Dictionary) -> float:
	var a := 0.0
	if tank.get("light", false):
		a += 25.0
	if str(tank.get("gravel", "")) != "":
		a += 15.0
	a += min(tank.get("decor", []).size(), 6) * 7.0
	a += (100.0 - float(tank.dirt)) * 0.18
	return clamp(a, 0.0, 100.0)


static func new_fish(species: String, growth: float = 0.6, health: float = 100.0) -> Dictionary:
	_uid_counter += 1
	return {"uid": _uid_counter, "species": species, "health": health, "growth": growth, "alive": true}


static func set_uid_floor(v: int) -> void:
	_uid_counter = max(_uid_counter, v)


static func living(tank: Dictionary) -> Array:
	return tank.fish.filter(func(f): return f.alive)


static func dead_count(tank: Dictionary) -> int:
	return tank.fish.filter(func(f): return not f.alive).size()


static func species_in(tank: Dictionary) -> Array:
	var out: Array = []
	for f in living(tank):
		if not out.has(f.species):
			out.append(f.species)
	return out


## Bu türü tanka koymak sorun yaratır mı? Sorun metni ya da "".
static func check_add(tank: Dictionary, species: String) -> String:
	var terra: bool = tank.get("kind", "") == "teraryum"
	if terra != FishDB.is_turtle(species):
		return "Teraryuma sadece kaplumbağa konur." if terra else "%s bir teraryum ister." % FishDB.display_name(species)
	if bool(tank.get("salt", false)) != FishDB.is_salt(species):
		return "%s %s ister, bu tank %s." % [FishDB.display_name(species), "tuzlu su" if FishDB.is_salt(species) else "tatlı su", "tuzlu" if tank.get("salt", false) else "tatlı su"]
	if space_used(tank) + space_of(species) > CAPACITY:
		return "Tankta yer yok (%d/%d yer dolu, %s %d yer kaplar)." % [space_used(tank), CAPACITY, FishDB.display_name(species), space_of(species)]
	for other in species_in(tank):
		var r: String = FishDB.conflict_reason(species, other)
		if r != "":
			return r
	return ""


## Simülasyonu ilerletir. Olay metinleri dizisi döner.
static func step(tank: Dictionary, minutes: float, rng: RandomNumberGenerator) -> Array:
	var events: Array = []
	if not tank.unlocked:
		return events
	var alive: Array = living(tank)
	var dead: int = tank.fish.size() - alive.size()

	# Sıcaklık ısıtıcı hedefine yaklaşır (ısıtıcı oda sıcaklığının altına soğutamaz).
	var target: float = max(tank.heater, ROOM_TEMP) if (tank.get("heater_on", true) and power_on) else ROOM_TEMP
	tank.temp = move_toward(tank.temp, target, 0.05 * minutes)

	# Kirlenme
	var bioload: float = 0.0
	for f in alive:
		bioload += float(FishDB.get_species(f.species).dirt_rate) * lerp(0.5, 1.0, f.growth)
	var eff: float = FILTER_EFF[clamp(int(tank.filter), 0, 3)] if power_on else 0.0
	tank.dirt = clamp(tank.dirt + (bioload * 0.012 * (1.0 - eff) + dead * 0.15) * minutes, 0.0, 100.0)

	# Suyun olgunlaşması (yararlı bakteriler). Filtre hızlandırır.
	var cyc: float = float(tank.get("cycle", 100.0))
	if cyc < 100.0:
		tank.cycle = min(100.0, cyc + (0.3 if int(tank.filter) > 0 else 0.05) * minutes)

	# Açlık
	if alive.size() > 0:
		tank.food = clamp(tank.food - 0.15 * minutes, 0.0, 100.0)

	# Hastalık
	if not tank.sick and tank.dirt > 60.0 and alive.size() > 0:
		if rng.randf() < 0.002 * minutes * (tank.dirt - 60.0) / 40.0:
			tank.sick = true
			tank.sick_level = 0.1
			events.append("Tank %d: Beyaz benek hastalığı başladı!" % (tank.id + 1))
	if tank.sick:
		tank.sick_level = min(1.0, tank.sick_level + 0.003 * minutes)

	var present: Array = species_in(tank)
	for f in alive:
		var s: Dictionary = FishDB.get_species(f.species)
		var stress: float = 0.0
		if tank.dirt > 50.0:
			stress += (tank.dirt - 50.0) / 50.0 * 0.08
		if tank.food < 20.0:
			stress += (20.0 - tank.food) / 20.0 * 0.06
		var dt: float = 0.0
		if tank.temp < s.temp_min:
			dt = s.temp_min - tank.temp
		elif tank.temp > s.temp_max:
			dt = tank.temp - s.temp_max
		stress += dt * 0.03
		if tank.sick:
			stress += 0.05 * tank.sick_level
		if bool(tank.get("salt", false)) != bool(s.salt):
			stress += 0.4
		if float(tank.get("cycle", 100.0)) < 60.0:
			stress += (60.0 - float(tank.cycle)) / 60.0 * 0.06
		if (not tank.get("air", true) or not power_on) and alive.size() > 6:
			stress += 0.02 * (alive.size() - 6) / 6.0
		for other in present:
			if other == f.species and other != "beta":
				continue
			if other == "beta" and f.species == "beta" and _count_species(alive, "beta") < 2:
				continue
			var att: Dictionary = FishDB.get_species(other)
			if (att.aggression >= 0.8 and s.long_fins and other != f.species) or (other == "beta" and f.species == "beta"):
				stress += 0.05
			elif att.aggression >= 0.9 and other != f.species:
				stress += 0.05
				if rng.randf() < 0.0005 * minutes:
					f.alive = false
					f.health = 0.0
					f["eaten"] = true
					events.append("Tank %d: %s bir %s balığını parçaladı!" % [tank.id + 1, att.name, s.name])
					break
			elif att.aggression >= 0.5 and s.small and other != f.species:
				stress += 0.03
				if rng.randf() < 0.0008 * minutes:
					f.alive = false
					f.health = 0.0
					f["eaten"] = true
					events.append("Tank %d: %s bir %s balığını yedi!" % [tank.id + 1, att.name, s.name])
					break
		if not f.alive:
			continue
		stress /= max(0.2, float(s.hardiness))
		if stress <= 0.0001:
			f.health = min(100.0, f.health + 0.05 * minutes)
		else:
			f.health -= stress * minutes
		f.growth = min(1.0, f.growth + 0.0004 * minutes)
		if f.health <= 0.0:
			f.health = 0.0
			f.alive = false
			events.append("Tank %d: Bir %s öldü." % [tank.id + 1, s.name])

	# Yenen balıklar tamamen kaybolur.
	tank.fish = tank.fish.filter(func(f): return not f.get("eaten", false))

	# Üreme: sağlıklı, büyümüş en az iki balık + yer varsa. Yavruların %3'ü nadir (mutasyonlu) doğar.
	var adults := {}
	for f in living(tank):
		if f.health > 70.0 and f.growth > 0.5 and FishDB.BREED.has(f.species):
			adults[f.species] = adults.get(f.species, 0) + 1
	for sp in adults:
		if adults[sp] < 2 or space_used(tank) + space_of(sp) > CAPACITY or tank.dirt > 50.0:
			continue
		if rng.randf() < float(FishDB.BREED[sp]) * minutes * (1.3 if tank.get("decor", []).size() >= 4 else 1.0):
			var fry := new_fish(sp, 0.05, 90.0)
			if rng.randf() < 0.03:
				fry["rare"] = true
				fry["rare_name"] = FishDB.RARE_NAMES[rng.randi_range(0, FishDB.RARE_NAMES.size() - 1)]
				events.append("Tank %d: NADİR bir %s %s yavrusu doğdu! (6 kat değerli)" % [tank.id + 1, fry.rare_name, FishDB.display_name(sp)])
			else:
				events.append("Tank %d: %s yavruladı!" % [tank.id + 1, FishDB.display_name(sp)])
			tank.fish.append(fry)

	# Karantina: yeni gelen balıklar gözlemden geçer; taşıyıcılar karantina dışında hastalık yayar.
	var quarantine: bool = tank.get("quarantine", false)
	for f in living(tank):
		if quarantine and f.get("new", false):
			f["q"] = float(f.get("q", 0.0)) + minutes
			if f.q >= QUARANTINE_MIN:
				f.erase("new")
				if f.get("carrier", false):
					f.erase("carrier")
					events.append("Tank %d: Karantinadaki bir %s'nın hastalık taşıdığı anlaşıldı ve tedavi edildi." % [tank.id + 1, FishDB.display_name(f.species)])
		elif not quarantine and f.get("carrier", false) and not tank.sick:
			if rng.randf() < 0.004 * minutes:
				tank.sick = true
				tank.sick_level = 0.15
				events.append("Tank %d: Yeni gelen balıklar hastalık getirdi! (karantinaya koymadın)" % (tank.id + 1))
	return events


static func _count_species(arr: Array, sp: String) -> int:
	var n := 0
	for f in arr:
		if f.species == sp:
			n += 1
	return n


## Yem verir. Fazla yem suyu kirletir. Gerçekleşen kirlenme artışını döner.
static func feed(tank: Dictionary) -> float:
	var before: float = tank.food
	tank.food = min(100.0, tank.food + 40.0)
	var overflow: float = before + 40.0 - 100.0
	if overflow > 0.0:
		var extra: float = overflow * 0.25
		tank.dirt = min(100.0, tank.dirt + extra)
		return extra
	return 0.0


## Boş tankı tuzlu ya da tatlı suya çevirir. Başarılıysa "" döner.
static func set_salt(tank: Dictionary, salt: bool) -> String:
	if not living(tank).is_empty():
		return "Önce tanktaki balıkları sat ya da taşı."
	tank.salt = salt
	tank.fish.clear()
	tank.dirt = 5.0
	tank.sick = false
	tank.sick_level = 0.0
	return ""


static func water_change(tank: Dictionary) -> void:
	tank.dirt = max(0.0, tank.dirt - 55.0)
	tank.temp = move_toward(tank.temp, ROOM_TEMP, 2.0)


static func medicate(tank: Dictionary) -> void:
	tank.sick = false
	tank.sick_level = 0.0


static func remove_dead(tank: Dictionary) -> int:
	var n: int = dead_count(tank)
	tank.fish = tank.fish.filter(func(f): return f.alive)
	return n


static func average_health(tank: Dictionary) -> float:
	var a: Array = living(tank)
	if a.is_empty():
		return 0.0
	var t := 0.0
	for f in a:
		t += f.health
	return t / a.size()
