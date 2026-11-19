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
			print("== Entegrasyon testi (tam bir iş günü) ==")
			game.delete_save()
			game.new_game()
			_main = load("res://scenes/main.tscn").instantiate()
			root.add_child(_main)
			_stage = "boot"
		"boot":
			if _frame < 6:
				return false
			check(_main.shop.aquariums.is_empty() and _main.shop.counter == null, "Oyun boş dükkânla başlar")
			check(_main.player.global_position.z > 5.0, "Oyuncu dışarıda başlar")
			_main.hud.close_panel()
			_build_shop(game)
			_stage = "built"
		"built":
			if _frame < 12:
				return false
			check(_main.shop.aquariums.size() == 2, "2 akvaryum yerleştirildi")
			check(_main.shop.counter != null, "Kasa yerleştirildi")
			check(_main.shop.shelves.size() == 1, "Raf yerleştirildi")
			var fish_nodes: int = 0
			for aq in _main.shop.aquariums:
				fish_nodes += aq.fish_nodes().size()
			check(fish_nodes == 13, "Balıklar sahnede (%d)" % fish_nodes)
			var p: Array = _main.shop.path(Vector3(0, 0, 8), _main.shop.counter.register_point())
			print("  yol: ", p)
			check(p.size() >= 2 and p[-1].distance_to(_main.shop.counter.register_point()) < 0.5, "Dışarıdan kasaya yol bulunur (%d nokta)" % p.size())
			_start_money = game.money
			game.day_ended.connect(func(r): _report = r)
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
	var d := FurnitureDB.corners("kasa", Vector2(1.5, 0.0), 90.0)
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
	check(game.furniture.size() == 1 and abs(game.furniture[0].rot - 45.0) < 0.01, "Mobilya konumu kaydedildi")
	check(game.sell_furniture(int(e.uid)) != "", "Dolu tank satılamaz")
	game.tanks[0].fish.clear()
	var m0: int = game.money
	check(game.sell_furniture(int(e.uid)) == "" and game.money == m0 + 450, "Boş tank yarı fiyatına satılır")


## Entegrasyon testi için dükkânı kurar: kasa, 2 akvaryum (tam donanım), raf.
func _build_shop(game: Node) -> void:
	var b = _main.builder
	# Yerleştirme kuralları
	b.start_new("kasa")
	b.pos = Vector2(4.5, 2.5)
	b.rot = 0.0
	b._validate()
	check(b.valid, "Kasa boş alana konabilir")
	b.pos = Vector2(0.0, 4.4)
	b._validate()
	check(not b.valid, "Kapının önüne eşya konamaz")
	b.pos = Vector2(7.5, 0.0)
	b._validate()
	check(not b.valid, "Duvarın dışına eşya konamaz")
	b.cancel()
	var money0: int = game.money
	game.add_furniture("kasa", 4.5, 2.5, 0.0)
	var t1: Dictionary = game.add_furniture("akvaryum_ceviz", -3.0, -4.4, 0.0)
	var t2: Dictionary = game.add_furniture("akvaryum_beyaz", -6.45, 0.0, 90.0)
	var sh: Dictionary = game.add_furniture("kavisli_raf", 6.7, -1.5, -90.0)
	b.start_new("akvaryum_beyaz")
	b.pos = Vector2(-3.0, -4.4)
	b._validate()
	check(not b.valid, "Eşyalar üst üste konamaz")
	b.cancel()
	check(game.money == money0, "Doğrudan ekleme para harcamaz (test)")
	b.start_new("saksi_agave")
	b.pos = Vector2(-6.2, 4.2)
	b.rot = 30.0
	b._validate()
	var n0: int = game.furniture.size()
	check(b.confirm() and game.money == money0 - 120 and game.furniture.size() == n0 + 1, "Yerleştirince eşya parası ödenir")
	var plant: Dictionary = game.furniture[-1]
	b.start_move(int(plant.uid))
	b.pos = Vector2(-6.2, 3.0)
	b._validate()
	check(b.confirm() and abs(float(plant.z) - 3.0) < 0.01 and game.money == money0 - 120, "Eşya ücretsiz taşınır")
	b.start_new("kasa")
	b.pos = Vector2(2.0, -2.0)
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
	for t in game.tanks:
		game.tank_changed.emit(t.id)
