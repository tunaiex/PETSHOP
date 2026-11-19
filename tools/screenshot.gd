extends SceneTree
## Geliştirici aracı: farklı açılardan ekran görüntüsü alır.
##   godot --path . --rendering-method gl_compatibility -s res://tools/screenshot.gd -- <çıktı_klasörü>

var _frame := 0
var _main: Node
var _shots := [
	["genel", Vector3(5.0, 0.05, 4.2), 45.0, -8.0],
	["tank_yakin", Vector3(-3.6, 0.05, -3.55), 0.0, -18.0],
	["tank_orta", Vector3(0.0, 0.05, -3.3), 0.0, -14.0],
	["tank_japon", Vector3(3.4, 0.05, -3.6), 0.0, -18.0],
	["salon", Vector3(3.0, 0.05, 2.0), 60.0, -6.0],
	["kasa", Vector3(2.8, 0.05, 0.6), -60.0, -8.0],
	["raf", Vector3(4.0, 0.05, -2.0), -90.0, -8.0],
]
var _idx := 0
var _out := "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 2:
		root.get_node("Game").new_game()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
	if _frame == 10:
		_main.hud.close_panel()
		root.get_node("Game").open_shop()
		root.get_node("Game").time_scale = 6.0
	if _frame > 10 and _frame % 90 == 0:
		if _idx > 0 and _idx <= _shots.size():
			var img := root.get_viewport().get_texture().get_image()
			img.save_png("%s/%s.png" % [_out, _shots[_idx - 1][0]])
			print(_shots[_idx - 1][0], " pos=", _main.player.global_position, " focus=", _main.player.focus.get_prompt() if _main.player.focus else "-")
		if _idx >= _shots.size():
			if _idx == _shots.size():
				_gallery()
				_idx += 1
				return false
			root.get_viewport().get_texture().get_image().save_png("%s/galeri.png" % _out)
			quit()
			return true
		var s: Array = _shots[_idx]
		var p: Player = _main.player
		p.position = s[1]
		p._yaw = deg_to_rad(s[2])
		p._pitch = deg_to_rad(s[3])
		_idx += 1
	return false


## Tüm balık türlerini yan yana, yakından gösterir.
func _gallery() -> void:
	var g := Node3D.new()
	g.position = Vector3(0, 20, 0)
	root.add_child(g)
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4, 3, 0.05)
	bg.mesh = bm
	bg.material_override = MeshKit.mat(Color(0.03, 0.08, 0.1))
	bg.position = Vector3(0, 0, -0.6)
	g.add_child(bg)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 20, 0)
	g.add_child(light)
	var ids: Array = FishDB.ids()
	for i in ids.size():
		var s: Dictionary = FishDB.get_species(ids[i])
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.fish_mesh(ids[i])
		mi.material_override = MeshKit.shader_mat("res://shaders/fish.gdshader", {
			"body_color": s.body, "belly_color": s.belly, "accent_color": s.accent, "fin_color": s.fin,
			"fin_alpha": s.fin_alpha, "pattern": s.pattern, "fish_len": s.length, "phase": float(i)})
		var k: float = 0.28 / float(s.length)
		mi.scale = Vector3.ONE * k
		mi.rotation_degrees.y = 90
		mi.position = Vector3(-0.6 + (i % 4) * 0.4, 0.2 - (i / 4) * 0.35, 0)
		g.add_child(mi)
		var l := Label3D.new()
		l.text = s.name
		l.font_size = 24
		l.pixel_size = 0.0012
		l.position = mi.position + Vector3(0, -0.14, 0)
		g.add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.02, 1.15)
	cam.fov = 50
	g.add_child(cam)
	cam.current = true
	_main.hud.visible = false
