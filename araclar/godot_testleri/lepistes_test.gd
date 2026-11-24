extends SceneTree
var s
var sonuc := []
func kontrol(ad, kosul):
	sonuc.append(("GECTI  " if kosul else "KALDI  ") + ad)
func bekle(n):
	for i in n: await process_frame
func dokun(p, basili):
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = p; e.pressed = basili
	Input.parse_input_event(e); await process_frame
func tikla(p):
	await dokun(p, true); await bekle(2); await dokun(p, false)
func cerceve(n):
	for i in n:
		var w := InputEventMouseButton.new(); w.button_index = MOUSE_BUTTON_WHEEL_DOWN; w.pressed = true
		Input.parse_input_event(w); await bekle(1)
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://akvaryum_kaydi.json"))
	s = load("res://sahneler/akvaryum.tscn").instantiate()
	root.add_child(s); await bekle(3)
	var y = s.get_node("Yasam"); y.test_yetiskin(); await bekle(2)
	var b = s.get_node("Bakim"); var L = s.get_node("Lepistesler"); var menu = s.get_node("Menu")
	b.su = 100.0; b.mutluluk = 90.0; for l in b.lekeler: l["l"] = 0.0
	b.degisti.emit()
	# Magazadan al: menu > magaza > (super yem, filtre, lepistes)
	b.inci_sayisi = 20
	await cerceve(2); await tikla(Vector2(240, 240))
	await cerceve(2)
	kontrol("Magazada lepistes ogesi", menu._ogeler()[menu.secim][0] == "lepistes")
	for i in 5: await tikla(Vector2(240, 240))
	kontrol("4 lepistes alinir, 5.'si alinmaz (sayi=%d, inci=%d)" % [L.suru.size(), b.inci_sayisi], L.suru.size() == 4 and b.inci_sayisi == 8 and b.lepistes_sayisi == 4)
	menu.kapat()
	var k0: Vector3 = L.suru[0]["konum"]
	await bekle(90)
	var k1: Vector3 = L.suru[0]["konum"]
	kontrol("Lepistesler yuzer (%.0f px)" % Vector2(k1.x - k0.x, k1.y - k0.y).length(), Vector2(k1.x - k0.x, k1.y - k0.y).length() > 10.0)
	var tonlar := []
	for l in L.suru: tonlar.append(snappedf(l["ton"], 0.01))
	kontrol("Her biri farkli renkte %s" % [tonlar], tonlar.size() == 4)
	root.get_texture().get_image().save_png("res://arac/lepistes_ekran.png")
	# Biyolojik yuk: 4 lepistes ile su 24 saatte daha cok kirlenir
	b.su = 100.0
	s.son_hesaplama_zamani -= 24 * 3600.0; s._zaman_farkini_uygula()
	kontrol("4 lepistesle su 24 saatte ~74 puan kirlenir (%.1f)" % (100.0 - b.su), absf((100.0 - b.su) - 74.0) < 6.0)
	b.su = 100.0; s.aclik = 100.0; y.hasta = false; y.hastalik_riski = 0.0
	# Yem: suru yeme toplanir
	s.kabarma_beklemesi = 99.0
	await tikla(Vector2(180, 260))
	await bekle(60)
	var yakin := 0
	for l in L.suru:
		var k: Vector3 = l["konum"]
		if Vector2(k.x - s.yem_hedefi.x, k.y - s.yem_hedefi.y).length() < 90.0: yakin += 1
	kontrol("Yem dusunce lepistesler toplanir (%d/4 yakin)" % yakin, yakin >= 2)
	# Betta yakinina gelen lepistese kabarir
	await bekle(120)
	s.yem_var = false
	L.kabarma_beklemesi = 0.0; s.kabarma_beklemesi = 0.0
	L.suru[0]["konum"] = s.balik_konumu + Vector3(15, 0, 0)
	await bekle(3)
	kontrol("Betta yakindaki lepistese kabarir", s.get_node("Balik3D").kabarma_suresi > 0.0)
	# Kayit
	s._kaydet()
	s.hazir = false; s.queue_free(); await bekle(2)
	var s2 = load("res://sahneler/akvaryum.tscn").instantiate(); root.add_child(s2); await bekle(3)
	var L2 = s2.get_node("Lepistesler")
	kontrol("Lepistesler kayittan gelir (%d, ayni renkler)" % L2.suru.size(), L2.suru.size() == 4 and absf(L2.suru[0]["ton"] - tonlar[0]) < 0.01)
	for r in sonuc: print(r)
	quit()
