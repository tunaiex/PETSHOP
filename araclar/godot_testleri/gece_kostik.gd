extends SceneTree
func _initialize():
	var s = load("res://sahneler/akvaryum.tscn").instantiate()
	root.add_child(s); for i in 3: await process_frame
	s.get_node("Bakim").su = 100.0
	for i in 30: await process_frame
	var gunduz = s.kostik_gucu
	s.isik_acik = false; s._fps_ayarla()
	for i in 60: await process_frame
	var gece = s.kostik_gucu
	s.isik_acik = true; s._fps_ayarla(); s.get_node("Bakim").su = 20.0
	for i in 90: await process_frame
	print("kostik gunduz=%.3f gece=%.3f kirli_su=%.3f" % [gunduz, gece, s.kostik_gucu])
	root.get_node("Ayarlar").profil_ayarla(0)
	await process_frame
	print("Dusuk profil: arka plan malzemesi ", s.get_node("ArkaPlan").material, " kaya ", s.get_node("Tas").material)
	root.get_node("Ayarlar").profil_ayarla(1)
	quit()
