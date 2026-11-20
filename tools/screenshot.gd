extends SceneTree
## Geliştirici aracı: örnek bir dükkân kurup farklı açılardan ekran görüntüsü alır.
##   godot --path . --rendering-method gl_compatibility -s res://tools/screenshot.gd -- <çıktı_klasörü>

var _frame := 0
const SHOT_EVERY := 24
var _main: Node
var _game: Node
## ad, oyuncu konumu, bakış (yaw), eğim (pitch), kurulmuş dükkân mı
var _shots := [
	["genel", Vector3(5.6, 0.05, 4.0), 55.0, -10.0, true],
	["sol_duvar", Vector3(-3.5, 0.05, 1.0), 75.0, -6.0, true],
	["arka_duvar", Vector3(-1.0, 0.05, 2.6), 0.0, -4.0, true],
	["kasa", Vector3(3.6, 0.05, 3.6), -90.0, -14.0, true],
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
	if _frame > 10 and _frame % SHOT_EVERY == 0:
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
			"kargo":
				for b in _game.boxes:
					if b.has("species") and b.species == "hamster":
						_game.pick_box(int(b.uid))
						break
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
	var a: Dictionary = g.add_furniture("akvaryum_ceviz", 2.6, 0.3, 0.0)
	var rk: Dictionary = g.add_furniture("tank_rafi", 4.3, -1.9, 0.0)
	var hk: Dictionary = g.add_furniture("hamster_kafesi", 0.4, -0.2, 0.0)
	var ck: Dictionary = g.add_furniture("civciv_kafesi", 0.5, 2.2, 0.0)
	g.add_furniture("kedi_agaci", -0.4, 3.9, 0.0)
	g.employees = {"kasiyer": true, "bakimci": false}
	var t: Dictionary = g.tanks[int(a.tank)]
	t.gravel = "natural"; t.light = true; t.air = true; t.filter = 2
	t.heater_on = true; t.heater = 25.0; t.temp = 25.0; t.cycle = 100.0
	t.decor = ["kaya", "bitki", "bitki", "kok", "kilic_bitki", "bitki"]
	for sp in {"neon": 6, "lepistes": 4, "melek": 2}:
		for i in {"neon": 6, "lepistes": 4, "melek": 2}[sp]:
			t.fish.append(TankSim.new_fish(sp, 0.85))
	var rack_fish := [{"japon": 3}, {"palyaco": 2}, {"orumcek": 2}]
	for lv in 3:
		g.buy_rack_tank(int(rk.uid), lv)
		var rt: Dictionary = g.tanks[int(rk.tanks[lv])]
		rt.salt = lv == 1
		rt.gravel = "white" if lv == 1 else "natural"
		if lv == 2:
			rt.kind = "kuru"
			rt.gravel = "toprak"
		rt.heater_on = lv == 1; rt.heater = 26.0; rt.temp = 21.0 if lv == 0 else 26.0
		rt.filter = 1; rt.cycle = 100.0
		rt.decor = [["bitki", "kaya"], ["resif", "deniz_yildizi"], ["kok", "kaya"]][lv]
		for sp in rack_fish[lv]:
			for i in rack_fish[lv][sp]:
				rt.fish.append(TankSim.new_fish(sp, 0.85))
	for i in 3:
		g.tanks[int(hk.tank)].fish.append(TankSim.new_fish("hamster", 0.9))
	for i in 7:
		g.tanks[int(ck.tank)].fish.append(TankSim.new_fish("civciv", 0.9))
	for pid in ProductDB.ids():
		g.add_stock(pid, 80)
	var first_wall := true
	for f in g.furniture:
		if f.has("shelf"):
			if f.type == "duvar_rafi_m" and first_wall:
				first_wall = false
				g.place_shelf_tank(int(f.uid), 2)
				var stt: Dictionary = g.tanks[int(f.shelf_tanks["2"])]
				stt.gravel = "natural"; stt.cycle = 100.0; stt.heater_on = true; stt.temp = 25.0
				for i in 5:
					stt.fish.append(TankSim.new_fish("neon", 0.85))
			for pid in ProductDB.ids():
				g.stock_shelf(int(f.uid), pid, 4)
	# Akvaryum duvarlarına balık
	var sps := ["lepistes", "neon", "moli", "zebra", "melek", "japon", "palyaco", "beta"]
	var k := 0
	for f in g.furniture:
		if f.type == "akvaryum_kabin":
			for id in f.tanks:
				var tk: Dictionary = g.tanks[int(id)]
				var sp: String = sps[k % sps.size()]
				k += 1
				if sp == "palyaco":
					continue
				tk.heater_on = sp != "japon"
				tk.temp = 21.0 if sp == "japon" else 25.0
				for i in (3 if sp in ["melek", "beta"] else 7):
					tk.fish.append(TankSim.new_fish(sp, 0.8))
	g.order_animals("neon", 6)
	g.add_delivery("kedi_kumu", 10)
	g.weather = "gunesli"
	for tk in g.tanks:
		g.tank_changed.emit(tk.id)
	g.furniture_changed.emit()
	g.open_shop()
	_main.sync_employees()
