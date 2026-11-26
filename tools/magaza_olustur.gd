extends SceneTree
## Geliştirici aracı: mağaza sahnesini (scenes/magaza.tscn) sıfırdan üretir.
## Sahne bir kez üretildikten sonra Godot editöründe elle düzenlenir; bu aracı tekrar
## çalıştırırsan yaptığın düzenlemelerin üzerine yazar!
##   godot --headless --path . -s res://tools/magaza_olustur.gd

const OUT := "res://scenes/magaza.tscn"
const PIECE := "res://assets/modeller/magaza/bina/%s.glb"
const H_IN := 3.0
const X0 := -7.2
const X1 := 7.2
const Z_FRONT := 4.8
const Z_PART := -3.6
const Z_BACK := -7.2
const DOOR_X := 1.2

var mroot: Node3D
var _cache := {}


func _grp(name: String, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	(parent if parent else mroot).add_child(n)
	n.owner = mroot
	return n


func _piece(parent: Node3D, name: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var path := PIECE % name
	if not ResourceLoader.exists(path):
		push_warning("yok: " + path)
		return null
	if not _cache.has(path):
		_cache[path] = load(path)
	var n: Node3D = (_cache[path] as PackedScene).instantiate()
	n.position = pos
	n.rotation_degrees.y = yaw
	parent.add_child(n, true)
	n.owner = mroot
	return n


func _marker(name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	mroot.add_child(m)
	m.owner = mroot
	return m


func _initialize() -> void:
	mroot = Node3D.new()
	mroot.name = "Magaza"
	var bina := _grp("Bina")
	var zemin := _grp("Zemin", bina)
	var tavan := _grp("Tavan", bina)
	var cati := _grp("Cati", bina)
	var duvar := _grp("Duvarlar", bina)
	var vitrin := _grp("Vitrin", bina)
	var dis := _grp("DisMekan", bina)
	var sus := _grp("Susler", bina)
	var depo := _grp("Depo", bina)
	var x := X0 + 0.6
	while x < X1:
		var z := Z_PART + 0.6
		while z < Z_FRONT:
			_piece(zemin, "floor_store_120", Vector3(x, 0, z))
			z += 1.2
		z = Z_BACK + 0.6
		while z < Z_PART:
			_piece(zemin, "floor_concrete_120", Vector3(x, 0, z))
			z += 1.2
		z = Z_BACK + 0.6
		var i := 0
		while z < Z_FRONT:
			var lit: bool = (int(round((x - X0 - 0.6) / 1.2)) % 3 == 1) and (i % 2 == 1)
			_piece(tavan, "ceiling_light_120" if lit else "ceiling_tile_120", Vector3(x, H_IN, z))
			_piece(cati, "roof_flat_120", Vector3(x, H_IN + 0.03, z))
			z += 1.2
			i += 1
		x += 1.2
	var cx := X0 + 1.2
	while cx < X1:
		_piece(duvar, "wall_240", Vector3(cx, 0, Z_BACK), 0.0)
		_piece(cati, "parapet_120", Vector3(cx - 0.6, H_IN, Z_BACK))
		_piece(cati, "parapet_120", Vector3(cx + 0.6, H_IN, Z_BACK))
		cx += 2.4
	var cz := Z_BACK + 1.2
	while cz < Z_FRONT:
		_piece(duvar, "wall_240", Vector3(X0, 0, cz), 90.0)
		_piece(duvar, "wall_240", Vector3(X1, 0, cz), 270.0)
		for side in [[X0, 90.0], [X1, 270.0]]:
			_piece(cati, "parapet_120", Vector3(side[0], H_IN, cz - 0.6), side[1])
			_piece(cati, "parapet_120", Vector3(side[0], H_IN, cz + 0.6), side[1])
		cz += 2.4
	for c in [[X0, Z_BACK, 90.0], [X1, Z_BACK, 0.0], [X0, Z_FRONT, 180.0], [X1, Z_FRONT, 270.0]]:
		_piece(duvar, "wall_corner", Vector3(c[0], 0, c[1]), c[2])
		_piece(cati, "parapet_corner", Vector3(c[0], H_IN, c[1]), c[2])
	cx = X0 + 1.2
	while cx < X1 - 2.0:
		_piece(duvar, "wall_240", Vector3(cx, 0, Z_PART), 0.0)
		cx += 2.4
	_piece(duvar, "wall_swing_door_120", Vector3(X1 - 1.8, 0, Z_PART), 0.0)
	_piece(duvar, "wall_120", Vector3(X1 - 0.6, 0, Z_PART), 0.0)
	cx = X0 + 1.2
	while cx < X1:
		if abs(cx - DOOR_X) < 0.1:
			_piece(vitrin, "shopfront_entrance_240", Vector3(cx, 0, Z_FRONT), 180.0)
		else:
			_piece(vitrin, "shopfront_glass_240", Vector3(cx, 0, Z_FRONT), 180.0)
			_piece(vitrin, "awning_240", Vector3(cx, 2.4, Z_FRONT), 180.0)
		_piece(cati, "parapet_120", Vector3(cx - 0.6, H_IN, Z_FRONT), 180.0)
		_piece(cati, "parapet_120", Vector3(cx + 0.6, H_IN, Z_FRONT), 180.0)
		cx += 2.4
	x = -10.2
	while x < 10.3:
		_piece(dis, "sidewalk_120", Vector3(x, 0, Z_FRONT + 0.6), 180.0)
		_piece(dis, "sidewalk_120", Vector3(x, 0, Z_FRONT + 1.8), 180.0)
		_piece(dis, "sidewalk_curb_120", Vector3(x, 0, Z_FRONT + 3.0), 180.0)
		x += 1.2
	var asphalt := MeshInstance3D.new()
	asphalt.name = "Asfalt"
	var bm := BoxMesh.new()
	bm.size = Vector3(24, 0.05, 10)
	asphalt.mesh = bm
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.2, 0.2, 0.22)
	am.roughness = 0.9
	asphalt.material_override = am
	asphalt.position = Vector3(0, -0.03, Z_FRONT + 8.6)
	dis.add_child(asphalt)
	asphalt.owner = mroot
	for i in 6:
		_piece(dis, "parking_space", Vector3(-6.0 + i * 2.6, 0.0, Z_FRONT + 6.4), 0.0)
		_piece(dis, "parking_curb_stop", Vector3(-6.0 + i * 2.6, 0.0, Z_FRONT + 4.2), 0.0)
	_piece(dis, "car_hatchback", Vector3(-3.4, 0, Z_FRONT + 6.4), 180.0)
	_piece(dis, "cart_corral", Vector3(6.6, 0, Z_FRONT + 6.0), 90.0)
	for lp in [-8.4, 8.4]:
		_piece(dis, "street_lamp", Vector3(lp, 0, Z_FRONT + 2.6), 180.0)
	_piece(dis, "light_pole_double", Vector3(1.2, 0, Z_FRONT + 9.2), 0.0)
	_piece(dis, "tree_garden", Vector3(-9.0, 0, Z_FRONT + 1.6), 0.0)
	_piece(dis, "planter_box", Vector3(-4.6, 0, Z_FRONT + 1.0), 0.0)
	_piece(dis, "planter_box", Vector3(4.6, 0, Z_FRONT + 1.0), 0.0)
	_piece(dis, "outdoor_bench", Vector3(-2.6, 0, Z_FRONT + 1.4), 180.0)
	_piece(dis, "shop_trash_bin_a", Vector3(3.2, 0, Z_FRONT + 1.0), 180.0)
	_piece(dis, "a_frame_sign_a", Vector3(-0.4, 0, Z_FRONT + 1.6), 160.0)
	_piece(sus, "doormat", Vector3(DOOR_X, 0.002, Z_FRONT - 0.7))
	_piece(sus, "wall_clock", Vector3(-1.2, 2.35, Z_PART + 0.075))
	_piece(sus, "exit_sign", Vector3(X1 - 1.8, 2.45, Z_PART + 0.075))
	_piece(sus, "poster_fox", Vector3(X0 + 0.08, 1.7, -2.6), 90.0)
	_piece(sus, "poster_robot", Vector3(X1 - 0.08, 1.7, 0.6), 270.0)
	_piece(sus, "security_camera_a", Vector3(X1 - 0.2, 2.7, Z_FRONT - 0.3), 225.0)
	_piece(sus, "convex_mirror", Vector3(X0 + 0.1, 2.3, Z_PART + 0.2), 45.0)
	_piece(sus, "neon_open", Vector3(-1.2, 1.9, Z_FRONT - 0.12), 180.0)
	_piece(sus, "fire_extinguisher_a", Vector3(X1 - 0.15, 0, Z_PART + 0.6), 270.0)
	_piece(sus, "potted_plant_tall_a", Vector3(X0 + 0.5, 0, Z_FRONT - 0.5), 0.0)
	for i in 4:
		_piece(depo, "backroom_rack", Vector3(X0 + 1.6 + i * 1.25, 0, Z_BACK + 0.35), 0.0)
	_piece(depo, "staff_lockers", Vector3(X1 - 0.35, 0, Z_BACK + 1.2), 270.0)
	_piece(depo, "office_desk", Vector3(X1 - 1.6, 0, Z_BACK + 0.6), 0.0)
	_piece(depo, "safe", Vector3(X1 - 0.4, 0, Z_BACK + 2.6), 270.0)
	_piece(depo, "pallet", Vector3(0.8, 0, -5.4), 0.0)
	for i in 3:
		_piece(depo, "shipping_box", Vector3(0.5 + (i % 2) * 0.45, 0.14 + (i / 2) * 0.35, -5.4), 10.0 * i)
	_piece(depo, "hand_truck_a", Vector3(2.2, 0, -5.0), 30.0)

	# Işıklar: "Sokak" ile başlayanlar sadece gece yanar
	var isik := _grp("Isiklar")
	for lx in [-5.4, -1.8, 1.8, 5.4]:
		for lz in [-2.2, 0.7, 3.5]:
			var l := OmniLight3D.new()
			l.name = "Tavan"
			l.position = Vector3(lx, 2.75, lz)
			l.omni_range = 5.2
			l.omni_attenuation = 1.2
			l.light_energy = 1.25
			l.light_color = Color(1.0, 0.95, 0.88)
			l.light_specular = 0.25
			isik.add_child(l, true)
			l.owner = mroot
	for lx in [-4.8, 0.0, 4.8]:
		var l := OmniLight3D.new()
		l.name = "Depo"
		l.position = Vector3(lx, 2.7, -5.4)
		l.omni_range = 4.0
		l.light_energy = 0.9
		l.light_color = Color(1.0, 0.96, 0.9)
		isik.add_child(l, true)
		l.owner = mroot
	for lp in [Vector3(8.4, 3.6, Z_FRONT + 2.4), Vector3(-8.4, 3.6, Z_FRONT + 2.4), Vector3(1.2, 5.5, Z_FRONT + 9.0)]:
		var sp := SpotLight3D.new()
		sp.name = "Sokak"
		sp.position = lp
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.spot_range = 7.0
		sp.spot_angle = 60.0
		sp.light_energy = 2.5
		sp.light_color = Color(1.0, 0.82, 0.6)
		isik.add_child(sp, true)
		sp.owner = mroot

	# Hazır eşyalar (yeni oyunda boş gelir)
	var esya := _grp("Esyalar")
	var EsyaYeriS = load("res://scripts/world/esya_yeri.gd")
	var game_s = load("res://scripts/autoload/game.gd")
	for f in game_s.STARTER_LAYOUT:
		var e: Node3D = EsyaYeriS.new()
		e.name = str(f[0])
		e.set("tip", f[0])
		e.position = Vector3(f[1], 0, f[2])
		e.rotation_degrees.y = f[3]
		esya.add_child(e, true)
		e.owner = mroot

	var alan: Node3D = load("res://scripts/world/satis_alani.gd").new()
	alan.name = "SatisAlani"
	alan.set("boyut", Vector2(14.2, 8.2))
	alan.position = Vector3(0, 0, 0.6)
	mroot.add_child(alan)
	alan.owner = mroot
	_marker("Kapi", Vector3(DOOR_X, 0, Z_FRONT))
	_marker("Giris", Vector3(DOOR_X, 0, Z_FRONT - 0.7))
	_marker("Disari", Vector3(DOOR_X, 0, Z_FRONT + 3.8))
	_marker("OyuncuBaslangic", Vector3(DOOR_X, 0.05, Z_FRONT + 3.2))
	_marker("KopekBaslangic", Vector3(3.0, 0, 3.6))
	_marker("KoliAlani", Vector3(-1.45, 0, Z_FRONT + 0.6))
	var saat := _marker("DijitalSaat", Vector3(X1 - 0.09, 2.45, 2.8))
	saat.rotation_degrees.y = -90

	var ps := PackedScene.new()
	var err := ps.pack(mroot)
	print("pack ", err)
	print("save ", ResourceSaver.save(ps, OUT))
	quit()
