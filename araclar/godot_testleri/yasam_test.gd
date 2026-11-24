extends SceneTree
var s
var b
var y
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
func ileri_sar(saat):
	s.son_hesaplama_zamani -= saat * 3600.0
	y.zaman_kaydir += saat * 3600.0
	s._zaman_farkini_uygula()
func gun_atla(gun, besle := true):
	# saatlik adimlarla (bakimli) gunler gecir
	for i in int(gun * 24):
		if besle:
			s.aclik = 100.0; b.su = 100.0; y.kakalar.clear()
			for l in b.lekeler: l["l"] = 0.0
			s.isik_acik = not y.gece()
		ileri_sar(1)
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://akvaryum_kaydi.json"))
	s = load("res://sahneler/akvaryum.tscn").instantiate()
	root.add_child(s); await bekle(3)
	b = s.get_node("Bakim"); y = s.get_node("Yasam")
	y.saat_ayari = 12
	var menu = s.get_node("Menu")

	# 1 Yeni oyun: yumurta, balik gorunmez, dokunma yem atmaz
	kontrol("Yeni oyun yumurtayla baslar, balik gizli", y.evre == 0 and not s.get_node("Balik").visible)
	await bekle(3)
	root.get_texture().get_image().save_png("res://arac/p_yumurta.png")
	await tikla(Vector2(240, 250))
	kontrol("Yumurta evresinde dokunma yem atmaz", not s.yem_var)
	# 2 Catlama + isim
	y.yumurta_bitis = y.simdi() - 1.0
	s._zaman_farkini_uygula(); await bekle(5)
	kontrol("Yumurtalar catlar: yavru, isim istenir, menu acik", y.evre == 1 and y.isim_bekliyor and menu.acik and menu.mod == "isim")
	root.get_texture().get_image().save_png("res://arac/p_isim.png")
	await cerceve(2)
	var beklenen: String = y.ISIMLER[menu.secim]
	await tikla(Vector2(240, 240))
	kontrol("Isim secilir (%s)" % y.isim, y.isim == beklenen and not y.isim_bekliyor and not menu.acik)
	await bekle(10)
	kontrol("Yavru kucuk ve soluk (boy=%.2f, doygunluk=%.2f)" % [b.boy, y.gorunum()["doygunluk"]], b.boy < 0.5 and y.gorunum()["doygunluk"] < 0.5)
	root.get_texture().get_image().save_png("res://arac/p_yavru.png")

	# 3 Ihtiyac cagrisi + bakim hatasi
	var cagrilar := []
	y.cagri.connect(func(ad): cagrilar.append(ad))
	s.aclik = 10.0
	await bekle(40)
	kontrol("Ac yavru cagri yapar (%s)" % [cagrilar], "ac" in cagrilar)
	root.get_texture().get_image().save_png("res://arac/p_cagri.png")
	var h0: int = y.bakim_hatasi
	ileri_sar(0.4)  # 24 dk ilgilenmeme
	kontrol("15 dk'dan uzun ilgilenilmeyen ihtiyac bakim hatasi sayilir (%d -> %d)" % [h0, y.bakim_hatasi], y.bakim_hatasi > h0)

	# 4 Kaka
	s.aclik = 50.0; s.yem_var = false; s.bekleme_suresi = 0.0
	y.yem_yendi()
	y.kaka_zamanlari[-1] = y.simdi() - 1.0
	ileri_sar(0.01)
	kontrol("Yemden sonra dipte kaka belirir", y.kakalar.size() >= 1)
	var kp: Vector2 = y.kakalar[0]
	await tikla(kp)
	kontrol("Kakaya dokununca temizlenir, yem atilmaz", y.kakalar.is_empty() and not s.yem_var)

	# 5 Iyi bakimla buyume -> genc -> yetiskin (Halfmoon)
	y.bakim_hatasi = 0; y.toplam_hata = 0
	gun_atla(7.2)
	kontrol("7 gun iyi bakim: yetiskin + Halfmoon (evre=%d form=%d hata=%d boy=%.2f)" % [y.evre, y.form, y.bakim_hatasi, b.boy], y.evre == 3 and y.form == 2 and b.boy > 0.85)
	s.balik_konumu = Vector3(0, -10, 0.2); s.bekleme_suresi = 3.0
	await bekle(20)
	root.get_texture().get_image().save_png("res://arac/p_yetiskin.png")

	# 6 Hastalik: kirli su -> hasta -> beyaz benek, kapali yuzgec -> ilac -> iyilesir
	for i in 4:
		s.aclik = 100.0; b.su = 10.0
		ileri_sar(1)
	kontrol("Kirli suda hastalanir (hasta=%s saglik=%.0f)" % [y.hasta, y.saglik], y.hasta)
	s._gorunumu_uygula(); await bekle(20)
	kontrol("Hasta gorunum: benek + kapali yuzgec", y.gorunum()["benek"] > 0.5 and s.get_node("Balik3D").kapali > 0.5)
	root.get_texture().get_image().save_png("res://arac/p_hasta.png")
	await cerceve(1)
	kontrol("Hastayken menunun ilk ogesi Ilac ver", menu.acik and menu._ogeler()[0][0] == "ilac")
	await tikla(Vector2(240, 240))
	b.su = 100.0
	for i in 7:
		s.aclik = 100.0; b.su = 100.0
		ileri_sar(1)
	kontrol("Ilacla iyilesir (hasta=%s)" % y.hasta, not y.hasta)

	# 7 Gece: isik acikken uyku ihtiyaci, kapaninca mutluluk bonusu
	y.saat_ayari = 23; s.isik_acik = true
	kontrol("Gece isik acikken 'uyku' ihtiyaci", "uyku" in y.ihtiyaclar())
	s.isik_acik = false
	kontrol("Gece isik kapali: uyku ihtiyaci yok", not "uyku" in y.ihtiyaclar())
	y.saat_ayari = 12; s.isik_acik = true; s._fps_ayarla()

	# 8 Oyun
	s.yem_var = false; y.son_oyun = 0.0
	s._oyun_baslat()
	kontrol("Oyun baslar", s.oyun_kalan > 0.0)
	await bekle(60)
	root.get_texture().get_image().save_png("res://arac/p_oyun.png")
	for i in 20:
		s.oyun_noktasi = s.get_node("Balik").position
		await bekle(5)
	s.oyun_kalan = 0.01
	await bekle(3)
	kontrol("Oyun biter, skor > 0, son oyun kaydedilir (skor=%d)" % s.oyun_skor, s.oyun_skor > 0 and y.son_oyun > 0.0)

	# 9 Yaslilik -> yumurta -> yeni nesil (ozellik aktarimi)
	var ton0: float = y.renk_ton
	gun_atla(17.5)
	b.yuva = 1.0; b.mutluluk = 90.0
	ileri_sar(0.05)
	kontrol("Disi yokken yumurta olmaz", not y.yumurta_var)
	s.get_node("Lepistesler").ekle(0.3)
	b.yuva = 1.0; b.mutluluk = 90.0; s.isik_acik = true
	ileri_sar(0.05)
	kontrol("Disi + mutlu + yuva: (yokken) yumurta birakir (evre=%d)" % y.evre, y.evre == 4 and y.yumurta_var)
	await cerceve(1)
	kontrol("Menude Yeni nesil ogesi", menu._ogeler()[0][0] == "nesil")
	await tikla(Vector2(240, 240))
	kontrol("Yeni nesil: yumurta, nesil 2, gecmise yazildi", y.evre == 0 and y.nesil == 2 and y.gecmis.size() == 1 and y.gecmis[0]["form"] == 2)
	kontrol("Yavru rengi anne-baba karisimi (baba %.2f, anne 0.30 -> %.2f)" % [ton0, y.renk_ton], absf(y.renk_ton - (ton0 + 0.3) / 2.0) <= 0.07)

	# 10 Kayit
	s._kaydet()
	s.hazir = false; s.queue_free(); await bekle(2)
	var s2 = load("res://sahneler/akvaryum.tscn").instantiate(); root.add_child(s2); await bekle(2)
	var y2 = s2.get_node("Yasam")
	kontrol("Yasam kayittan yuklenir (nesil=%d gecmis=%d)" % [y2.nesil, y2.gecmis.size()], y2.nesil == 2 and y2.gecmis.size() == 1 and y2.evre == 0)
	for r in sonuc: print(r)
	quit()
