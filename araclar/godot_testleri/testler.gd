extends SceneTree
var s
var temiz := 0
var menu := []
var sonuc := []
func kontrol(ad, kosul):
	sonuc.append(("GECTI  " if kosul else "KALDI  ") + ad)
func bekle(n):
	for i in n: await process_frame
func dokun(p, basili):
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = p; e.pressed = basili
	Input.parse_input_event(e)
	await process_frame
func surukle(p):
	var e := InputEventScreenDrag.new(); e.index = 0; e.position = p
	Input.parse_input_event(e)
	await process_frame
func sifirla():
	s.get_node("Menu").kapat()
	s.kabarma_beklemesi = 99.0
	s.yem_var = false; s.isik_acik = true; s.bekleme_suresi = 5.0
	temiz = 0; menu.clear()
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://akvaryum_kaydi.json"))
	s = load("res://sahneler/akvaryum.tscn").instantiate()
	root.add_child(s)
	await bekle(3)
	s.get_node("Yasam").test_yetiskin()
	await bekle(2)
	s.cam_temizlendi.connect(func(a, b): temiz += 1)
	s.menu_adimi.connect(func(y): menu.append(y))

	# 1 kisa dokunma = yem
	sifirla()
	await dokun(Vector2(300, 250), true); await bekle(3); await dokun(Vector2(300, 250), false)
	kontrol("Kisa dokunma yem atar", s.yem_var and s.isik_acik and temiz == 0)

	# 2 bir saniye basili tutma = isik (yem atmaz)
	sifirla()
	await dokun(Vector2(240, 200), true); await bekle(36); await dokun(Vector2(240, 200), false)
	kontrol("1 sn basma isigi kapatir, yem atmaz", not s.isik_acik and not s.yem_var)
	await dokun(Vector2(240, 200), true); await bekle(36); await dokun(Vector2(240, 200), false)
	kontrol("1 sn basma isigi tekrar acar", s.isik_acik)

	# 3 kaydirma >60 px = cam temizleme
	sifirla()
	await dokun(Vector2(150, 260), true)
	for i in 10: await surukle(Vector2(150 + i * 18, 260))
	await dokun(Vector2(330, 260), false)
	kontrol("180 px kaydirma cam temizler (yem/isik yok)", temiz == 1 and not s.yem_var and s.isik_acik)

	# 4 30 px kayma: hicbir sey
	sifirla()
	await dokun(Vector2(200, 260), true); await surukle(Vector2(215, 260)); await surukle(Vector2(230, 260)); await dokun(Vector2(230, 260), false)
	kontrol("30 px kayma hicbir sey yapmaz", temiz == 0 and not s.yem_var)

	# 5 kenarda dairesel kaydirma = menu adimi (cam temizleme degil)
	sifirla()
	var M := Vector2(240, 240)
	await dokun(M + Vector2(200, 0).rotated(0.0), true)
	for i in range(1, 25): await surukle(M + Vector2(200, 0).rotated(deg_to_rad(i * 5.0)))
	await dokun(M + Vector2(200, 0).rotated(deg_to_rad(120.0)), false)
	kontrol("Kenarda 120 derece daire = 4 menu adimi, cam temizlemez (adim=%d, temiz=%d)" % [menu.size(), temiz], menu.size() == 4 and temiz == 0 and not s.yem_var)

	# 6 uzun basma sirasinda parmak kayarsa isik degismez
	sifirla()
	await dokun(Vector2(240, 300), true)
	for i in 6: await surukle(Vector2(240 + i * 8, 300))
	await bekle(36); await dokun(Vector2(280, 300), false)
	kontrol("Kayan parmakla basili tutma isigi degistirmez", s.isik_acik)

	# 7 cerceve (tekerlek) = menu adimi
	sifirla()
	var w := InputEventMouseButton.new(); w.button_index = MOUSE_BUTTON_WHEEL_DOWN; w.pressed = true
	Input.parse_input_event(w); await bekle(2)
	kontrol("Cerceve/tekerlek menu adimi verir", menu == [1])

	# 8 arka plan: 3B durur, kayit yazilir
	sifirla()
	s.aclik = 50.0
	s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var vp = s.get_node("Balik3D")
	kontrol("Arka planda 3B cizim durur ve FPS 5", vp.render_target_update_mode == SubViewport.UPDATE_DISABLED and Engine.max_fps == 5)
	kontrol("Arka plana gecince kayit yazilir", FileAccess.file_exists("user://akvaryum_kaydi.json"))
	s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	kontrol("Geri gelince 3B ve 30 FPS doner", vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS and Engine.max_fps == 30)

	# 9 kayit yukleme + gecen gercek sure
	s.balik_konumu = Vector3(50, 20, 0.4); s.aclik = 60.0; s._kaydet()
	var f := FileAccess.open("user://akvaryum_kaydi.json", FileAccess.READ)
	var k = JSON.parse_string(f.get_as_text()); f.close()
	k["zaman"] = float(k["zaman"]) - 3600.0  # 1 saat once kaydedilmis gibi
	f = FileAccess.open("user://akvaryum_kaydi.json", FileAccess.WRITE); f.store_string(JSON.stringify(k)); f.close()
	s.hazir = false
	s.queue_free(); await bekle(2)
	var s2 = load("res://sahneler/akvaryum.tscn").instantiate(); root.add_child(s2); await bekle(2)
	kontrol("Kayit yuklenir ve 1 saatte tokluk ~33 duser (60 -> %.1f)" % s2.aclik, absf(s2.aclik - (60.0 - 100.0/3.0)) < 0.5)
	kontrol("Balik konumu kayittan gelir (%s)" % s2.balik_konumu, s2.balik_konumu.distance_to(Vector3(50, 20, 0.4)) < 3.0)

	for r in sonuc: print(r)
	quit()
