extends SceneTree
## Duman testi: dolu bir dükkânda bütün panelleri açıp her butona basar.
## Hata/çökme olursa çıktıda SCRIPT ERROR / ERROR görünür.
##   godot --headless --path . -s res://tests/smoke_ui.gd

var f := 0
var m
var g
var pressed := 0
var _jobs: Array = []

func _process(_d):
	f += 1
	if f == 2:
		g = root.get_node("Game")
		g.new_game()
		g.money = 999999
		m = load("res://scenes/main.tscn").instantiate()
		root.add_child(m)
	if f == 6:
		m.hud.close_panel()
		g.add_furniture("kasa", 4.5, 2.6, 0.0)
		var a: Dictionary = g.add_furniture("akvaryum_beyaz", -3.0, -4.4, 0.0)
		var b: Dictionary = g.add_furniture("akvaryum_ceviz", 0.5, -4.4, 0.0)
		g.add_furniture("teraryum", -6.4, 0.0, 90.0)
		g.add_furniture("kavisli_raf", 6.7, -1.5, -90.0)
		g.add_furniture("saksi_agave", -6.2, 4.2, 0.0)
		var t: Dictionary = g.tanks[int(a.tank)]
		t.cycle = 100.0
		for sp in ["neon", "neon", "lepistes"]:
			t.fish.append(TankSim.supplier_fish(sp, g.rng))
		g.tanks[int(b.tank)].fish.append(TankSim.new_fish("japon"))
		g.add_stock("yem", 20)
		g.add_stock("su_duzenleyici", 5)
		g.add_stock("ilac", 3)
		g.add_delivery("kum", 12)
		_jobs = [
			["tank", func(): m.hud.open_tank(m.shop.aquariums[0])],
			["tank2", func(): m.hud.open_tank(m.shop.aquariums[1])],
			["raf", func(): m.hud.open_shelf(m.shop.shelves[0])],
			["kasa", func(): m.hud.open_furniture(m.shop.counter)],
			["menu", func(): m.hud.open_menu()],
			["yardim", func(): m.hud.show_help()],
		]
		for tab in ["furniture", "fish", "products", "shop", "staff", "customers", "finance"]:
			_jobs.append(["tel_" + tab, func(): m.hud.open_phone(tab)])
	if f > 10 and f % 3 == 0 and not _jobs.is_empty():
		var job: Array = _jobs[0]
		job[1].call()
		var btns: Array = []
		if m.hud._panel:
			for bt in m.hud._panel.find_children("*", "Button", true, false):
				if not bt.disabled and bt.is_visible_in_tree():
					btns.append(bt.text)
		var idx: int = job.size() - 2 if job.size() > 2 else 0
		if job.size() == 2:
			job.append(0)
		var i: int = job[2]
		if i >= btns.size():
			_jobs.pop_front()
			m.hud.close_panel()
			if m.builder.active:
				m.builder.cancel()
			return false
		job[2] = i + 1
		var txt: String = btns[i]
		if txt.contains("Yeni oyun") or txt.contains("Genişlet") or txt.begins_with("Sat"):
			return false
		for bt in m.hud._panel.find_children("*", "Button", true, false):
			if bt.text == txt and not bt.disabled:
				print("[", job[0], "] ", txt)
				bt.pressed.emit()
				pressed += 1
				break
		if m.builder.active:
			m.builder.cancel()
	if _jobs.is_empty() and f > 20:
		print("BASILAN BUTON: ", pressed)
		quit()
	return false
