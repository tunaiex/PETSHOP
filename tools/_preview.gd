extends SceneTree
var f := 0
func _process(_d) -> bool:
	f += 1
	if f == 2:
		var g = root.get_node("Game")
		g.new_game()
		g.furniture.clear()
		var env := WorldEnvironment.new(); env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.85,0.86,0.88)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(1,1,1); env.environment.ambient_light_energy = 0.8
		root.add_child(env)
		var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 25, 0); root.add_child(l)
		var e: Dictionary = g.add_furniture("akvaryum_beyaz", 0, 0, 0.0)
		var t: Dictionary = g.tanks[int(e.tank)]
		t.kind = "kuru"; t.gravel = "toprak"; t.light = true; t.decor = ["kok", "kaya"]
		var TS = load("res://scripts/logic/tank_sim.gd")
		for i in 2: t.fish.append(TS.new_fish("orumcek", 0.95))
		var aq = load("res://scripts/world/aquarium.gd").new(); root.add_child(aq); aq.setup(int(e.tank))
		var dog = load("res://scripts/world/shop_dog.gd").new(); root.add_child(dog); dog.position = Vector3(1.4, 0, 0.9); dog.rotation_degrees.y = -70
		dog.setup(null)
		var cam := Camera3D.new(); root.add_child(cam); cam.current = true
		cam.look_at_from_position(Vector3(0.0, 1.4, 1.3), Vector3(0.0, 0.9, 0))
	if f == 40:
		root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); quit()
	return false
