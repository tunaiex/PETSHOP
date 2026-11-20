extends SceneTree
## Geliştirici aracı: örnek bir dükkân kurup farklı açılardan ekran görüntüsü alır.
##   godot --path . --rendering-method gl_compatibility -s res://tools/screenshot.gd -- <çıktı_klasörü>

var _frame := 0
var _main: Node
var _game: Node
## ad, oyuncu konumu, bakış (yaw), eğim (pitch), kurulmuş dükkân mı
var _shots := [
	["bos_disari", Vector3(0, 0.05, 8.0), 0.0, -2.0, false],
	["cadde", Vector3(-2.0, 0.05, 15.5), -8.0, 10.0, false],
	["genel", Vector3(5.6, 0.05, 4.5), 42.0, -10.0, true],
	["tank_tatli", Vector3(-3.5, 0.05, -3.25), 0.0, -16.0, true],
	["tank_deniz", Vector3(0.0, 0.05, -3.25), 0.0, -16.0, true],
	["teraryum", Vector3(-1.2, 0.05, 0.2), 30.0, -22.0, true],
	["koliler", Vector3(2.4, 0.05, 2.2), 180.0, -30.0, true],
	["kasa", Vector3(2.2, 0.05, 4.4), -55.0, -10.0, true],
	["kepce", Vector3(2.2, 0.05, 4.4), -55.0, -10.0, true, "kepce"],
	["telefon", Vector3(2.2, 0.05, 4.4), -55.0, -10.0, true, "telefon"],
	["koli_elde", Vector3(3.0, 0.05, 0.5), -90.0, -10.0, true, "koli"],
	["aksam_disari", Vector3(0, 0.05, 8.0), 0.0, 2.0, true, "aksam"],
	["yerlestirme", Vector3(-1.5, 0.05, 1.2), 90.0, -28.0, true, "yerlestir"],
	["akvaryum_rafi", Vector3(-4.0, 0.05, 1.0), 90.0, 4.0, true],
	["raf_yakin", Vector3(-5.3, 0.05, 1.0), 90.0, -8.0, true],
	["yem_rafi", Vector3(4.6, 0.05, -1.6), -90.0, -14.0, true],
	["yem_elde", Vector3(-5.3, 0.05, 1.0), 90.0, -8.0, true, "yem"],
]
var _idx := 0
var _out := "user://shots"
var _built := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		var only: Array = Array(args[1].split(","))
		_shots = _shots.filter(func(s): return only.has(s[0]))
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 2:
		_game = root.get_node("Game")
		_game.new_game()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
	if _frame == 10:
		_main.hud.close_panel()
	if _frame > 10 and _frame % 90 == 0:
		if _idx > 0 and _idx <= _shots.size():
			root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, _shots[_idx - 1][0]])
		if _idx >= _shots.size():
			quit()
			return true
		var s: Array = _shots[_idx]
		if s[4] and not _built:
			_build()
		_main.hud.close_panel()
		var action: String = s[5] if s.size() > 5 else ""
		match action:
			"kepce":
				_main.hud._open_catch(null, 100, "", 0, {"neon": 2})
			"telefon":
				_main.hud.open_phone("finance")
			"koli":
				_game.pick_box(int(_game.boxes[0].uid))
			"aksam":
				_game.carry_to_depot()
				_game.minute = 19 * 60 + 25
				_game.time_changed.emit(int(_game.minute))
			"yem":
				_main.player.hands.hold_food("yem_japon")
				_main.player.hands._anim = 1000.0
			"yerlestir":
				_game.minute = 12 * 60
				_game.time_changed.emit(int(_game.minute))
				_main.builder.start_new("akvaryum_beyaz")
		var p = _main.player
		p.position = s[1]
		p._yaw = deg_to_rad(s[2])
		p._pitch = deg_to_rad(s[3])
		_idx += 1
	return false


## Örnek dükkân: 4 akvaryum (tatlı, deniz, soğuk su, melek), 2 raf, kasa, bitkiler.
func _build() -> void:
	_built = true
	var g := _game
	g.money = 20000
	g.add_furniture("kasa", 4.5, 2.6, 0.0)
	var a: Dictionary = g.add_furniture("akvaryum_ceviz", -3.5, -4.6, 0.0)
	var b: Dictionary = g.add_furniture("akvaryum_ceviz", 0.0, -4.6, 0.0)
	var c: Dictionary = g.add_furniture("akvaryum_ceviz", 3.5, -4.6, 0.0)
	var d: Dictionary = g.add_furniture("akvaryum_beyaz", -6.45, -1.4, 90.0)
	var r1: Dictionary = g.add_furniture("kavisli_raf", 6.72, -1.6, -90.0)
	var r2: Dictionary = g.add_furniture("duvar_rafi", 6.75, 1.0, -90.0)
	g.add_furniture("saksi_agave", -6.3, 4.3, 0.0)
	g.add_furniture("saksi_egrelti", -6.2, 2.4, 0.0)
	var ter: Dictionary = g.add_furniture("teraryum", -2.0, -1.4, 30.0)
	g.add_furniture("jenerator", 6.4, 4.2, -90.0)
	g.add_furniture("kamera", -6.6, -4.6, 45.0)
	g.employees = {"kasiyer": true, "bakimci": true}
	g.add_delivery("yem", 25)
	g.add_delivery("kum", 10)
	g.add_furniture("saksi_calilik", -3.6, 4.4, 0.0)
	g.add_furniture("paspas", 0.0, 3.9, 0.0)
	var setups := [
		[a, false, 25.0, true, ["kaya", "bitki", "bitki", "kok", "kilic_bitki", "bitki"], {"neon": 6, "lepistes": 4}],
		[b, true, 26.0, true, ["resif", "resif", "deniz_yildizi", "kabuk", "kestane"], {"palyaco": 3, "cerrah": 2, "mandarin": 1, "denizati": 1}],
		[c, false, 21.0, false, ["kaya", "amfora", "bitki", "kirik_kaya"], {"japon": 3, "koi": 1}],
		[d, false, 27.0, true, ["kok", "bitki", "bitki", "kilic_bitki", "kaya"], {"melek": 4}],
		[ter, false, 26.0, true, ["kaya"], {"kaplumbaga": 3}],
	]
	for st in setups:
		var t: Dictionary = g.tanks[int(st[0].tank)]
		t.salt = st[1]
		t.heater = st[2]
		t.temp = st[2]
		t.heater_on = st[3]
		t.gravel = "white" if st[1] else "natural"
		t.light = true
		t.air = true
		t.filter = 2
		t.cycle = 100.0
		t.dirt = 5.0
		t.decor = st[4]
		for sp in st[5]:
			for i in st[5][sp]:
				t.fish.append(TankSim.new_fish(sp, 0.85))
	for pid in ProductDB.ids():
		g.add_stock(pid, 20)
	for pid in ["yem", "yem_japon", "su_duzenleyici", "ilac", "kum", "dekor", "filtre"]:
		g.stock_shelf(int(r1.uid), pid, 4)
		g.stock_shelf(int(r2.uid), pid, 3)
	g.tanks[int(a.tank)].fish[0]["rare"] = true
	g.tanks[int(a.tank)].fish[0]["rare_name"] = "Altın"
	# 3 katlı akvaryum rafı: üç kat da dolu
	var rk: Dictionary = g.add_furniture("tank_rafi", -6.5, 1.0, 90.0)
	var rack_fish := [{"neon": 8}, {"japon": 3}, {"palyaco": 2, "mandarin": 1}]
	for lv in 3:
		g.buy_rack_tank(int(rk.uid), lv)
		var rt: Dictionary = g.tanks[int(rk.tanks[lv])]
		rt.salt = lv == 2
		rt.gravel = "white" if lv == 2 else "natural"
		rt.heater_on = lv != 1
		rt.heater = 21.0 if lv == 1 else 26.0
		rt.temp = rt.heater
		rt.filter = 1
		rt.air = lv == 0
		rt.cycle = 100.0
		rt.decor = [["bitki", "kaya", "bitki"], ["kaya", "amfora"], ["resif", "deniz_yildizi"]][lv]
		for sp in rack_fish[lv]:
			for i in rack_fish[lv][sp]:
				rt.fish.append(TankSim.new_fish(sp, 0.85))
	g.weather = "gunesli"
	for t in g.tanks:
		g.tank_changed.emit(t.id)
	g.open_shop()
	_main.sync_employees()
