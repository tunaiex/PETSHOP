extends SceneTree
## Otomatik testler. Çalıştırma:
##   godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## Çıkış kodu 0 = tüm testler geçti.

var failures: int = 0
var passed: int = 0
var _frame: int = 0
var _main: Node
var _stage: String = "unit"
var _sales: int = 0
var _start_money: int = 0
var _report: Dictionary = {}


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  ✓ ", name)
	else:
		failures += 1
		printerr("  ✗ ", name)


func _initialize() -> void:
	print("== Mantık testleri ==")
	_test_fishdb()
	_test_furniture()
	_test_haggle()
	_test_tank_sim()
	_test_meshes()


func _process(_delta: float) -> bool:
	_frame += 1
	var game: Node = root.get_node_or_null("Game")
	match _stage:
		"unit":
			if _frame < 2:
				return false
			print("== Kayıt testi ==")
			_test_save(game)
			print("== Dükkân sistemleri ==")
			_test_shop_systems(game)
			print("== Balık sistemleri ==")
			_test_fish_systems(game)
			print("== Entegrasyon testi (tam bir iş günü) ==")
			game.delete_save()
			game.new_game()
			_main = load("res://scenes/main.tscn").instantiate()
			root.add_child(_main)
			_stage = "boot"
		"boot":
			if _frame < 6:
				return false
			check(_main.shop.aquariums.is_empty() and _main.shop.counter != null, "Oyun hazır kasalı dükkânla başlar")
			var empty_shelves := true
			for shx in _main.shop.shelves:
				if game.shelf_total(shx.entry()) > 0:
					empty_shelves = false
			check(_main.shop.shelves.size() >= 10 and empty_shelves, "Hazır raflar bomboş gelir (%d raf)" % _main.shop.shelves.size())
			check(_main.player.global_position.z > 5.0, "Oyuncu dışarıda başlar")
			_main.hud.close_panel()
			_build_shop(game)
			_stage = "built"
		"built":
			if _frame < 12:
				return false
			check(_main.shop.aquariums.size() == 3, "2 akvaryum + 1 raf akvaryumu yerleştirildi (%d)" % _main.shop.aquariums.size())
			var rack_aq: Array = _main.shop.aquariums.filter(func(a): return a.rack_level >= 0)
			check(rack_aq.size() == 1 and rack_aq[0].rack_level == 1, "Raf akvaryumu doğru katta")
			check(rack_aq.size() == 1 and rack_aq[0].look_target().y > 1.0, "Orta kat akvaryumu yerden yüksekte")
			check(_main.shop.counter != null, "Kasa yerleştirildi")
			check(_main.shop.shelves.size() == 1, "Raf yerleştirildi")
			var fish_nodes: int = 0
			for aq in _main.shop.aquariums:
				fish_nodes += aq.fish_nodes().size()
			check(fish_nodes == 16, "Balıklar sahnede (%d)" % fish_nodes)
			var p: Array = _main.shop.path(Vector3(0, 0, 8), _main.shop.counter.register_point())
			print("  yol: ", p)
			check(p.size() >= 2 and p[-1].distance_to(_main.shop.counter.register_point()) < 0.5, "Dışarıdan kasaya yol bulunur (%d nokta)" % p.size())
			_start_money = game.money
			game.day_ended.connect(func(r): _report = r)
			_test_customer_kinds(game)
			_start_money = game.money
			game.open_shop()
			check(game.phase == "open", "Dükkân açıldı")
			game.time_scale = 12.0
			_stage = "day"
		"day":
			# Kasaya gelen müşteriyle otomatik pazarlık: değerinin %110'u ile başla, karşı teklifte kabul et
			var c = _main.customer_at_register()
			if c:
				var h: Haggle = c.haggle if c.haggle else c.start_haggle()
				if h:
					var r: Dictionary = h.respond(int(h.value * 1.1))
					if r.result == Haggle.Result.ACCEPT:
						_main.complete_sale(c, r.price)
						_sales += 1
					elif r.result == Haggle.Result.COUNTER:
						_main.complete_sale(c, h.accept_offer())
						_sales += 1
				else:
					c.walk_out_angry()
			# Bakım: tokluk düşükse yem ver
			for t in game.tanks:
				if t.unlocked and t.food < 30.0 and game.stock.get("yem", 0) > 0:
					game.use_stock("yem")
					TankSim.feed(t)
			if not _report.is_empty():
				_stage = "report"
			elif _frame > 60 * 60 * 3:
				check(false, "Gün zaman aşımına uğramadan bitmeli")
				_stage = "done"
		"report":
			print("  Rapor: ", _report)
			check(_sales > 0, "En az bir satış yapıldı (%d)" % _sales)
			check(int(_report.revenue) > 0, "Ciro pozitif")
			check(_main.customers.is_empty(), "Gün sonunda dükkân boş")
			check(game.phase == "report" or game.phase == "over", "Gün raporu aşamasına geçildi")
			game.next_day()
			check(game.day == 2 and game.phase == "prep", "Ertesi güne geçildi")
			game.delete_save()
			_stage = "done"
		"done":
			print("\nSONUÇ: %d geçti, %d başarısız" % [passed, failures])
			quit(1 if failures > 0 else 0)
			return true
	return false


func _test_fishdb() -> void:
	check(FishDB.conflict_reason("beta", "lepistes") != "", "Beta + lepistes uyumsuz")
	check(FishDB.conflict_reason("japon", "neon") != "", "Japon + neon sıcaklık uyumsuz")
	check(FishDB.conflict_reason("melek", "neon") != "", "Melek neonları avlar")
	check(FishDB.conflict_reason("neon", "lepistes") == "", "Neon + lepistes uyumlu")
	check(FishDB.conflict_reason("beta", "beta") != "", "İki beta kavga eder")
	check(FishDB.market_value("diskus", 100, 1.0) > FishDB.market_value("diskus", 40, 1.0), "Sağlıklı balık daha değerli")
	check(FishDB.market_value("neon", 100, 1.0) > FishDB.market_value("neon", 100, 0.1), "Büyük balık daha değerli")
	for id in FishDB.ids():
		var s: Dictionary = FishDB.get_species(id)
		check(s.value > s.buy, "%s kârlı satılabilir" % s.name)
	check(FishDB.conflict_reason("palyaco", "neon") != "", "Tuzlu ve tatlı su balığı birlikte olmaz")
	check(FishDB.conflict_reason("palyaco", "cerrah") == "", "Palyaço + mavi cerrah uyumlu")
	check(FishDB.conflict_reason("pirana", "japon") != "", "Pirana diğer balıklara saldırır")
	check(FishDB.conflict_reason("aslan", "palyaco") != "", "Aslan balığı palyaçoyu yer")
	check(FishDB.get_species("koi").has("tail"), "Yeni türler varsayılan alanları alır")


func _test_furniture() -> void:
	var a := FurnitureDB.corners("kasa", Vector2.ZERO, 0.0)
	var b := FurnitureDB.corners("kasa", Vector2(0, 0.5), 0.0)
	var c := FurnitureDB.corners("kasa", Vector2(0, 3.0), 0.0)
	var d := FurnitureDB.corners("kasa", Vector2(1.0, 0.0), 90.0)
	check(FurnitureDB.polys_overlap(a, b), "Çakışan eşyalar algılanır")
	check(not FurnitureDB.polys_overlap(a, c), "Uzak eşyalar çakışmaz")
	check(FurnitureDB.polys_overlap(a, d), "Döndürülmüş eşya çakışması algılanır")
	check(TankSim.space_of("arowana") > TankSim.space_of("neon"), "Büyük balık daha çok yer kaplar")


func _test_haggle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var h := Haggle.new(100, 0.5, 50.0, rng)
	check(h.offer < h.max_pay, "İlk teklif tavanın altında")
	var r: Dictionary = h.respond(h.offer)
	check(r.result == Haggle.Result.ACCEPT, "Teklif fiyatı söylenince kabul")
	# Aşırı fiyat sonunda müşteriyi kaçırır
	rng.seed = 2
	h = Haggle.new(100, 0.9, 50.0, rng)
	var left := false
	for i in 10:
		r = h.respond(400)
		if r.result == Haggle.Result.LEAVE:
			left = true
			break
	check(left, "Fahiş fiyatta müşteri gider")
	# Makul fiyatta çoğunlukla satış olur
	var accepted := 0
	for i in 50:
		rng.seed = 100 + i
		h = Haggle.new(100, 0.5, 50.0, rng)
		for k in 6:
			r = h.respond(105)
			if r.result != Haggle.Result.COUNTER:
				break
		if r.result == Haggle.Result.ACCEPT:
			accepted += 1
	check(accepted >= 35, "Değere yakın fiyatlar çoğunlukla kabul edilir (%d/50)" % accepted)
	# Karşı teklif artar
	rng.seed = 7
	h = Haggle.new(200, 0.6, 50.0, rng)
	var first: int = h.offer
	r = h.respond(400)
	check(r.result != Haggle.Result.COUNTER or h.offer >= first, "Karşı teklif düşmez")


func _test_tank_sim() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t := TankSim.new_tank(0, true, 25.0)
	for i in 6:
		t.fish.append(TankSim.new_fish("neon", 0.8))
	# Temiz ve tok tank: balıklar sağlıklı kalır
	for m in 120:
		TankSim.step(t, 1.0, rng)
	check(TankSim.average_health(t) > 95.0, "Bakımlı tankta sağlık korunur")
	check(t.dirt > 8.0, "Balıklar suyu zamanla kirletir")
	# Çok kirli su sağlığı düşürür
	t.dirt = 95.0
	var h0: float = TankSim.average_health(t)
	for m in 60:
		TankSim.step(t, 1.0, rng)
	check(TankSim.average_health(t) < h0, "Kirli su sağlığı düşürür")
	TankSim.water_change(t)
	check(t.dirt < 50.0, "Su değişimi kiri azaltır")
	t.food = 90.0
	var extra := TankSim.feed(t)
	check(extra > 0.0, "Fazla yem suyu kirletir")
	# Yem çeşitleri: neonlar tropikal yemle tam, Japon balığı yemiyle yarım doyar
	t.food = 20.0
	TankSim.feed(t, "tropikal")
	check(abs(t.food - 60.0) < 0.01, "Uygun yem tam doyurur")
	t.food = 20.0
	TankSim.feed(t, "soguk")
	check(abs(t.food - 40.0) < 0.01, "Uygun olmayan yem az doyurur")
	check(FishDB.food_type("koi") == "soguk" and FishDB.food_type("palyaco") == "tropikal", "Türlerin yem tercihi")
	check(TankSim.best_food(t, {"yem": 1, "yem_japon": 5}) == "yem", "En uygun yem seçilir")
	check(TankSim.best_food(t, {"yem_japon": 2}) == "yem_japon", "Uygun yem yoksa eldeki verilir")
	check(TankSim.best_food(t, {}) == "", "Depoda yem yoksa boş döner")
	# Soğuk suda tropikal balık zorlanır
	var cold := TankSim.new_tank(1, true, 18.0)
	cold.temp = 18.0
	cold.fish.append(TankSim.new_fish("diskus", 0.8))
	for m in 120:
		TankSim.step(cold, 1.0, rng)
	check(TankSim.average_health(cold) < 80.0 or TankSim.living(cold).is_empty(), "Diskus soğuk suda zayıflar")
	# Kapasite
	var full := TankSim.new_tank(2, true)
	for i in TankSim.CAPACITY:
		full.fish.append(TankSim.new_fish("zebra"))
	check(TankSim.check_add(full, "zebra") != "", "Dolu tanka balık eklenemez")
	# Ölü balık kaldırma
	full.fish[0].alive = false
	check(TankSim.remove_dead(full) == 1, "Ölü balık çıkarılır")
	# Olgunlaşmamış su
	var raw := TankSim.new_tank(5, true, 25.0, false)
	raw.heater_on = true
	raw.fish.append(TankSim.new_fish("neon", 0.8))
	for m in 60:
		TankSim.step(raw, 1.0, rng)
	check(TankSim.average_health(raw) < 100.0, "Olgunlaşmamış suda balık zorlanır")
	check(raw.cycle > 0.0, "Su zamanla olgunlaşır")
	# Tuzlu su
	var sea := TankSim.new_tank(3, true, 26.0)
	check(TankSim.check_add(sea, "palyaco") != "", "Tatlı su tankına deniz balığı konmaz")
	check(TankSim.set_salt(sea, true) == "", "Boş tank tuzlu suya çevrilir")
	check(TankSim.check_add(sea, "palyaco") == "", "Tuzlu tanka palyaço konur")
	check(TankSim.check_add(sea, "neon") != "", "Tuzlu tanka neon konmaz")
	sea.fish.append(TankSim.new_fish("palyaco", 0.8))
	check(TankSim.set_salt(sea, false) != "", "Dolu tankın suyu değiştirilemez")
	var wrong := TankSim.new_tank(4, true, 26.0)
	wrong.fish.append(TankSim.new_fish("cerrah", 0.8))
	for m in 120:
		TankSim.step(wrong, 1.0, rng)
	check(TankSim.living(wrong).is_empty(), "Deniz balığı tatlı suda yaşayamaz")


func _test_meshes() -> void:
	for id in FishDB.ids():
		var m: ArrayMesh = MeshKit.fish_mesh(id)
		check(m != null and m.get_surface_count() == 1 and m.get_aabb().size.z > 0.0, "%s modeli üretildi" % id)
	check(MeshKit.rock(1, Vector3(0.2, 0.1, 0.15)).get_surface_count() == 1, "Kaya modeli üretildi")
	for id in ["beta", "japon", "melek", "koi", "pirana", "arowana", "palyaco", "cerrah", "mandarin", "aslan", "balon", "denizati"]:
		var t: Dictionary = Fish._model_template(id)
		var ok: bool = not t.is_empty() and t.mesh != null
		if ok:
			var size: Vector3 = (t.xf * t.mesh.get_aabb()).size
			ok = abs(size.z - float(FishDB.get_species(id).length)) < 0.02 or id == "denizati"
		check(ok, "%s gerçek modeli yüklendi ve boyu doğru" % id)
	for prop in ["props/akvaryum_dolabi", "props/kasa_tezgahi", "props/duvar_rafi", "props/agave", "decor/resif_kayasi", "decor/amfora"]:
		check(ResourceLoader.exists("res://assets/models/%s.glb" % prop), "%s modeli var" % prop)
	check(MeshKit.grass_clump(1, 6, 0.3).get_surface_count() == 1, "Bitki modeli üretildi")


func _test_save(game: Node) -> void:
	game.new_game()
	var e: Dictionary = game.add_furniture("akvaryum_beyaz", 1.0, 1.0, 45.0)
	game.tanks[0].fish.append(TankSim.new_fish("neon"))
	game.money = 4321
	game.tanks[0].dirt = 33.0
	var n: int = game.tanks[0].fish.size()
	game.save_game()
	game.money = 0
	game.tanks[0].fish.clear()
	check(game.load_game(), "Kayıt yüklendi")
	check(game.money == 4321, "Para kaydedildi")
	check(game.tanks[0].fish.size() == n, "Balıklar kaydedildi")
	check(abs(float(game.tanks[0].dirt) - 33.0) < 0.01, "Su durumu kaydedildi")
	check(typeof(game.tanks[0].fish[0].uid) == TYPE_INT, "UID tam sayı olarak yüklendi")
	check(abs(float(game.furniture_by_uid(int(e.uid)).rot) - 45.0) < 0.01, "Mobilya konumu kaydedildi")
	check(game.sell_furniture(int(e.uid)) != "", "Dolu tank satılamaz")
	game.tanks[0].fish.clear()
	var m0: int = game.money
	check(game.sell_furniture(int(e.uid)) == "" and game.money == m0 + 450, "Boş tank yarı fiyatına satılır")


## Entegrasyon testi için dükkânı kurar: kasa, 2 akvaryum (tam donanım), raf.
func _build_shop(game: Node) -> void:
	var b = _main.builder
	# Hazır yerleşimi kaldır: test kendi düzenini kurar
	game.furniture.clear()
	game.furniture_changed.emit()
	# Yerleştirme kuralları
	b.start_new("kasa")
	b.pos = Vector2(3.6, 2.4)
	b.rot = 270.0
	b._validate()
	check(b.valid, "Kasa boş alana konabilir")
	b.pos = Vector2(1.2, 3.0)
	b._validate()
	check(not b.valid, "Kapının önüne eşya konamaz")
	b.pos = Vector2(5.6, 0.0)
	b._validate()
	check(not b.valid, "Duvarın dışına eşya konamaz")
	b.cancel()
	var money0: int = game.money
	game.add_furniture("kasa", 3.6, 2.4, 270.0)
	var t1: Dictionary = game.add_furniture("akvaryum_ceviz", -2.6, -1.95, 0.0)
	var t2: Dictionary = game.add_furniture("akvaryum_beyaz", -4.35, 0.6, 90.0)
	var sh: Dictionary = game.add_furniture("duvar_rafi_m", 4.5, -1.0, 270.0)
	b.start_new("akvaryum_beyaz")
	b.pos = Vector2(-2.6, -1.95)
	b._validate()
	check(not b.valid, "Eşyalar üst üste konamaz")
	b.cancel()
	check(game.money == money0, "Doğrudan ekleme para harcamaz (test)")
	b.start_new("saksi_agave")
	b.pos = Vector2(-4.2, 3.0)
	b.rot = 30.0
	b._validate()
	var n0: int = game.furniture.size()
	check(b.confirm() and game.money == money0 - 120 and game.furniture.size() == n0 + 1, "Yerleştirince eşya parası ödenir")
	var plant: Dictionary = game.furniture[-1]
	b.start_move(int(plant.uid))
	b.pos = Vector2(-4.2, 2.0)
	b._validate()
	check(b.confirm() and abs(float(plant.z) - 2.0) < 0.01 and game.money == money0 - 120, "Eşya ücretsiz taşınır")
	b.start_new("kasa")
	b.pos = Vector2(0.0, 0.5)
	b._validate()
	check(not b.confirm(), "İkinci kasa alınamaz")
	b.cancel()
	for e in [t1, t2]:
		var t: Dictionary = game.tanks[int(e.tank)]
		check(t.cycle == 0.0 and str(t.gravel) == "" and not t.light, "Yeni tank çıplak gelir")
		t.gravel = "natural"
		t.heater_on = true
		t.light = true
		t.air = true
		t.filter = 2
		t.cycle = 100.0
		t.decor = ["kaya", "bitki", "bitki", "kok"]
	game.tanks[int(t2.tank)].heater = 21.0
	game.tanks[int(t2.tank)].heater_on = false
	var a: Dictionary = game.tanks[int(t1.tank)]
	for i in 6:
		a.fish.append(TankSim.new_fish("neon", 0.8))
	for i in 4:
		a.fish.append(TankSim.new_fish("lepistes", 0.8))
	for i in 3:
		game.tanks[int(t2.tank)].fish.append(TankSim.new_fish("japon", 0.8))
	game.add_stock("yem", 10)
	game.add_stock("filtre", 4)
	check(game.stock_shelf(int(sh.uid), "yem", 6) == 6, "Depodan rafa ürün dizilir")
	check(game.stock_shelf(int(sh.uid), "filtre", 4) == 4, "Rafa ikinci ürün dizilir")
	check(game.stock_shelf(int(sh.uid), "ilac", 3) == 0, "Depoda olmayan ürün dizilemez")
	# 3 katlı akvaryum rafı: orta kata akvaryum alınır, içine 3 neon
	var rk: Dictionary = game.add_furniture("tank_rafi", 0.6, -1.85, 0.0)
	check(game.buy_rack_tank(int(rk.uid), 1) == "", "Raf katına akvaryum alınır (sahne)")
	var rt: Dictionary = game.tanks[int(rk.tanks[1])]
	rt.gravel = "natural"
	rt.cycle = 100.0
	for i in 3:
		rt.fish.append(TankSim.new_fish("neon", 0.8))
	for t in game.tanks:
		game.tank_changed.emit(t.id)


func _test_shop_systems(game: Node) -> void:
	game.new_game()
	# Koliler
	game.add_delivery("yem", 23)
	check(game.boxes.size() == 3, "23 ürün 3 koli olarak gelir")
	var sh: Dictionary = game.add_furniture("duvar_rafi", 6.5, 0.0, -90.0)
	check(game.pick_box(int(game.boxes[0].uid)), "Koli alınır")
	check(not game.pick_box(int(game.boxes[0].uid)), "Aynı anda iki koli taşınamaz")
	check(game.carry_to_shelf(int(sh.uid)) == 10 and game.carrying.is_empty(), "Koli rafa dizilir")
	game.pick_box(int(game.boxes[0].uid))
	game.carry_to_depot()
	check(int(game.stock.get("yem", 0)) == 4 + 10, "Koli depoya konur")
	# Akvaryum rafı
	var rk: Dictionary = game.add_furniture("tank_rafi", 0.0, -4.4, 0.0)
	check(rk.tanks.size() == 3, "Raf 3 kat tank kaydı açar")
	check(not game.tanks[int(rk.tanks[0])].unlocked, "Raf katları boş gelir")
	var rack_m0: int = game.money
	check(game.buy_rack_tank(int(rk.uid), 0) == "" and game.money == rack_m0 - game.RACK_TANK_PRICE, "Raf katına akvaryum alınır")
	var rt: Dictionary = game.tanks[int(rk.tanks[0])]
	check(rt.unlocked and rt.light and TankSim.capacity(rt) == game.RACK_TANK_CAP, "Raf akvaryumu ışıklı ve küçük")
	check(game.buy_rack_tank(int(rk.uid), 0) != "", "Dolu kata ikinci akvaryum konamaz")
	rt.fish.append(TankSim.new_fish("neon", 0.8))
	check(game.remove_rack_tank(int(rk.uid), 0) != "", "Balıklı raf akvaryumu kaldırılamaz")
	check(game.sell_furniture(int(rk.uid)) != "", "Balıklı raf satılamaz")
	rt.fish.clear()
	var saved: Dictionary = game.to_dict()
	check(game.from_dict(JSON.parse_string(JSON.stringify(saved))), "Raflı kayıt yüklenir")
	var rk2: Dictionary = game.furniture_by_uid(int(rk.uid))
	check(rk2.tanks.size() == 3 and typeof(rk2.tanks[0]) == TYPE_INT and game.tanks[int(rk2.tanks[0])].unlocked, "Raf katları kayıttan döner")
	rack_m0 = game.money
	check(game.sell_furniture(int(rk.uid)) == "" and game.money == rack_m0 + 450 / 2 + game.RACK_TANK_PRICE / 2, "Raf, üstündeki akvaryumla birlikte satılır")
	# Elektrik kesintisi
	var t: Dictionary = TankSim.new_tank(0, true, 28.0)
	t.temp = 28.0
	TankSim.power_on = false
	for m in 60:
		TankSim.step(t, 1.0, game.rng)
	TankSim.power_on = true
	check(t.temp < 28.0, "Elektrik kesilince su soğur")
	# Maaş ve genişleme
	var base: int = game.daily_expenses().total
	game.employees.kasiyer = true
	check(game.daily_expenses().total == base + game.SALARY.kasiyer, "Maaş giderlere eklenir")
	check(game.MAX_LEVEL == 0 and game.room_min_x() < -4.0, "Mağaza binası sabit (genişletme yok)")
	# Fiyatlar ve hava
	check(game.buy_price("neon") > 0 and game.price_mult.size() > 10, "Günlük fiyatlar hesaplanır")
	check(["gunesli", "bulutlu", "yagmurlu"].has(game.weather), "Hava durumu belirlenir")
	# Yarışma
	var tank: Dictionary = game.add_furniture("akvaryum_ceviz", 0, -4.4, 0)
	var tk: Dictionary = game.tanks[int(tank.tank)]
	tk.light = true
	tk.gravel = "natural"
	tk.decor = ["kaya", "bitki", "bitki", "kok", "amfora", "kilic_bitki"]
	tk.cycle = 100.0
	for sp in ["neon", "lepistes", "moli"]:
		tk.fish.append(TankSim.new_fish(sp, 0.9))
	var res: Dictionary = game.run_contest()
	check(res.score > 50 and res.place >= 1 and res.place <= 4, "Yarışma puanlanır (%d puan, %d.)" % [res.score, res.place])
	# Kredi ve şube
	var m0: int = game.money
	game.loan = {"days_left": 2, "daily": 600}
	game.branches = 1
	game.reputation = 70.0
	var exp_total: int = game.daily_expenses().total
	check(exp_total >= 600, "Kredi taksiti giderlere eklenir")
	game.end_day()
	check(int(game.loan.days_left) == 1, "Her akşam bir taksit ödenir")
	game.next_day()
	game.end_day()
	check(game.loan.is_empty(), "Taksitler bitince kredi kapanır")
	game.loan = {}
	game.branches = 0
	# Kampanya müşteri bekleme süresini kısaltır (daha çok müşteri)
	game.campaign = {}
	game.followers = 0
	# Kayıt
	game.settings.name = "NEMO PETSHOP"
	game.save_game()
	game.settings.name = "x"
	game.load_game()
	check(game.settings.name == "NEMO PETSHOP" and game.employees.kasiyer, "Dükkân ayarları kaydedilir")
	game.delete_save()


func _test_fish_systems(game: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Üreme ve nadir yavru
	var t := TankSim.new_tank(0, true, 25.0)
	t.decor = ["kaya", "bitki", "bitki", "kok"]
	for i in 2:
		t.fish.append(TankSim.new_fish("lepistes", 0.9))
	var births := 0
	var rares := 0
	for day in 30:
		for m in 600:
			TankSim.step(t, 1.0, rng)
			t.food = 80.0
			t.dirt = 5.0
		births = t.fish.size() - 2
		if births >= 8:
			break
	for f in t.fish:
		if f.get("rare", false):
			rares += 1
	check(births > 0, "Bakımlı tankta balıklar yavrular (%d yavru)" % births)
	var rf := TankSim.new_fish("neon", 1.0)
	rf["rare"] = true
	check(FishDB.fish_value(rf) >= FishDB.market_value("neon", 100, 1.0) * 5, "Nadir balık çok daha değerli")
	# Karantina
	var shop_tank := TankSim.new_tank(1, true, 25.0)
	var carrier := TankSim.new_fish("neon", 0.8)
	carrier["carrier"] = true
	carrier["new"] = true
	shop_tank.fish.append(carrier)
	for m in 600:
		TankSim.step(shop_tank, 1.0, rng)
	check(shop_tank.sick, "Karantinasız taşıyıcı balık hastalık yayar")
	var q := TankSim.new_tank(2, true, 25.0)
	q.quarantine = true
	var c2 := TankSim.new_fish("neon", 0.8)
	c2["carrier"] = true
	c2["new"] = true
	q.fish.append(c2)
	for m in 200:
		TankSim.step(q, 1.0, rng)
	check(not q.sick and not c2.has("carrier") and not c2.has("new"), "Karantinada taşıyıcı tedavi edilir")
	# Taşıma
	var dst := TankSim.new_tank(3, true, 25.0)
	check(TankSim.move_fish(q, dst, "neon", 5) == 1 and dst.fish.size() == 1 and q.fish.is_empty(), "Balık tanklar arası taşınır")
	# Tedarikçi riskleri
	var carriers := 0
	for i in 400:
		if TankSim.supplier_fish("neon", rng).get("carrier", false):
			carriers += 1
	check(carriers > 20 and carriers < 120, "Tedarikçi balıklarının bir kısmı hastalık taşır (%d/400)" % carriers)
	# Teraryum
	var terra := TankSim.new_tank(5, true, 25.0)
	terra["kind"] = "teraryum"
	check(TankSim.check_add(terra, "kaplumbaga") == "", "Kaplumbağa teraryuma konur")
	check(TankSim.check_add(terra, "neon") != "", "Teraryuma balık konmaz")
	check(TankSim.check_add(TankSim.new_tank(6, true), "kaplumbaga") != "", "Akvaryuma kaplumbağa konmaz")
	# Kepçe oyunu: hedeflere tıklayınca başarı
	var tank := TankSim.new_tank(4, true, 25.0)
	for i in 3:
		tank.fish.append(TankSim.new_fish("neon", 0.8))
	for i in 3:
		tank.fish.append(TankSim.new_fish("lepistes", 0.8))
	var cg = ResourceLoader.load("res://scripts/ui/catch_game.gd", "", ResourceLoader.CACHE_MODE_IGNORE).new()
	root.add_child(cg)
	cg.size = Vector2(800, 360)
	cg.setup(tank, {"neon": 2})
	var result := [null]
	cg.finished.connect(func(ok): result[0] = ok)
	var wrong_time: float = cg.time_left
	for sp in cg._sprites:
		if sp.species == "lepistes":
			cg._try_catch(sp.pos)
			break
	check(cg.time_left < wrong_time, "Yanlış balık süre kaybettirir")
	for k in 2:
		for sp in cg._sprites:
			if sp.species == "neon":
				cg._try_catch(sp.pos)
				break
	check(result[0] == true, "Doğru balıkları yakalayınca kepçe oyunu kazanılır")
	cg.queue_free()


func _test_customer_kinds(game: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Sorular doğru cevaplanabilir
	var ok_all := true
	for i in 30:
		var q: Dictionary = Quiz.make(rng, ["neon", "japon"])
		if q.answer < 0 or q.answer >= q.options.size():
			ok_all = false
	check(ok_all, "Bilgi sorularının doğru cevabı seçenekler içinde")
	var c = _main.spawn_customer()
	c.question = {"text": "x", "options": ["a", "b"], "answer": 1, "explain": ""}
	var m0: int = game.money
	check(c.answer_question(1) and game.money > m0, "Doğru cevap bahşiş kazandırır")
	# Hırsız: kamera yokken ürün kaybolur
	var sh = _main.shop.shelves[0]
	var before: int = game.shelf_total(sh.entry())
	var th = _main.spawn_customer()
	th.make_thief()
	th._evaluate_shelf(sh)
	check(game.shelf_total(sh.entry()) < before and game.stats.stolen > 0, "Kamerasız dükkânda hırsız ürün çalar")
	# Şikâyet: iade para düşürür
	var cm = _main.spawn_customer()
	cm.make_complainer({"name": "Mert", "amount": 50, "species": "neon"})
	var m1: int = game.money
	_main.resolve_complaint(cm, true)
	check(game.money == m1 - 50, "Şikâyette iade parası ödenir")
	# Müdavim ziyaret sayısı artar
	var reg: Dictionary = game.regulars[0]
	var v0: int = int(reg.visits)
	var rc = _main.spawn_customer()
	rc.make_regular(reg)
	check(int(reg.visits) == v0 + 1 and rc.profile.title == reg.name, "Müdavim tanınır")
	# Çocuk tanka vurunca balıklar strese girer
	var kid = _main.spawn_customer()
	kid.make_child()
	var aq = _main.shop.aquariums[0]
	var t: Dictionary = game.tanks[aq.tank_id]
	var h0: float = TankSim.average_health(t)
	kid._evaluate_tank(aq)
	kid.state = 2  # LOOK
	for i in 30:
		kid._process(0.1)
	check(TankSim.average_health(t) < h0, "Çocuk cama vurunca balıklar strese girer")
	kid.interact(_main.player)
	check(kid._tapping <= 0.0, "Çocuk uyarılınca durur")
	for cc in [c, th, cm, rc, kid]:
		if is_instance_valid(cc):
			_main.customers.erase(cc)
			_main.queue.erase(cc)
			cc.queue_free()
	for tk in game.tanks:
		for f in tk.fish:
			f.health = 100.0
