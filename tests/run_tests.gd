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
			check(_main.shop.aquariums.size() == 5, "5 akvaryum kuruldu")
			var fish_nodes: int = 0
			for aq in _main.shop.aquariums:
				fish_nodes += aq.fish_nodes().size()
			check(fish_nodes == 13, "Başlangıç balıkları sahnede (%d)" % fish_nodes)
			_main.hud.close_panel()
			_start_money = game.money
			game.day_ended.connect(func(r): _report = r)
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


func _test_meshes() -> void:
	for id in FishDB.ids():
		var m: ArrayMesh = MeshKit.fish_mesh(id)
		check(m != null and m.get_surface_count() == 1 and m.get_aabb().size.z > 0.0, "%s modeli üretildi" % id)
	check(MeshKit.rock(1, Vector3(0.2, 0.1, 0.15)).get_surface_count() == 1, "Kaya modeli üretildi")
	check(MeshKit.grass_clump(1, 6, 0.3).get_surface_count() == 1, "Bitki modeli üretildi")


func _test_save(game: Node) -> void:
	game.new_game()
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
