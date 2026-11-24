extends SceneTree
var s
var b
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
func cerceve(y):
	var w := InputEventMouseButton.new(); w.button_index = MOUSE_BUTTON_WHEEL_DOWN if y > 0 else MOUSE_BUTTON_WHEEL_UP; w.pressed = true
	Input.parse_input_event(w); await bekle(1)
func ileri_sar(saat):
	s.son_hesaplama_zamani -= saat * 3600.0
	s._zaman_farkini_uygula()
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://akvaryum_kaydi.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ayarlar.cfg"))
	s = load("res://sahneler/akvaryum.tscn").instantiate()
	root.add_child(s)
	await bekle(3); s.get_node("Yasam").test_yetiskin(); await bekle(2)
	b = s.get_node("Bakim")
	var menu = s.get_node("Menu")
	var vp = s.get_node("Balik3D")

	# --- Ilerleme ---
	b.su = 100.0; for l in b.lekeler: l["l"] = 0.0
	b.mutluluk = 90.0
	for i in 168:  # 7 gun, saatte bir besleyerek
		s.aclik = 100.0; b.su = 100.0
		for l in b.lekeler: l["l"] = 0.0
		ileri_sar(1)
	kontrol("Mutluyken kumda inci cikar, en fazla 3 (%d)" % b.inciler.size(), b.inciler.size() == 3)
	if b.inciler.is_empty():
		for r in sonuc: print(r)
		quit(); return
	var p0: Vector2 = b.inciler[0]
	s.kabarma_beklemesi = 99.0; s.yem_var = false; s.isik_acik = true
	await tikla(p0)
	kontrol("Inciye dokununca toplanir (sayi=%d, kumda=%d, yem atilmadi=%s)" % [b.inci_sayisi, b.inciler.size(), not s.yem_var], b.inci_sayisi == 1 and b.inciler.size() == 2 and not s.yem_var)

	var _yy = s.get_node("Yasam"); _yy.hasta = false; _yy.hastalik_riski = 0.0; _yy.saglik = 100.0
	# --- Magaza ---
	b.inci_sayisi = 10; s.aclik = 30.0
	await cerceve(1)                       # menu acilir (secim 0: su)
	await cerceve(1)                       # secim 1: magaza
	await tikla(Vector2(240, 240))         # magazaya gir
	kontrol("Magazaya girilir", menu.acik and menu.mod == "magaza")
	await tikla(Vector2(240, 240))         # super yem
	kontrol("Super yem: tam tok, 1 inci (tokluk=%.0f, inci=%d)" % [s.aclik, b.inci_sayisi], s.aclik > 99.0 and b.inci_sayisi == 9)
	await cerceve(1); await tikla(Vector2(240, 240))   # filtre
	kontrol("Filtre alinir (5 inci)", b.filtre and b.inci_sayisi == 4)
	await cerceve(1); await tikla(Vector2(240, 240))   # gun batimi isigi
	kontrol("Gun batimi isigi alinir ve secilir", b.renkler[1] and b.isik_rengi == 1 and b.inci_sayisi == 1)
	await cerceve(1); await tikla(Vector2(240, 240))   # ay isigi: inci yetmez
	kontrol("Inci yetmezse alinmaz", not b.renkler[2] and b.inci_sayisi == 1)
	await bekle(3)
	root.get_texture().get_image().save_png("res://arac/ekran_magaza.png")
	await cerceve(1); await tikla(Vector2(240, 240))   # normal isik
	kontrol("Normal isiga donulur", b.isik_rengi == 0)
	b.isik_rengi = 1; b.degisti.emit()
	menu.kapat()
	b.su = 100.0
	var su0: float = b.su
	ileri_sar(24)
	kontrol("Filtreyle su 24 saatte ~25 puan kirlenir (%.1f)" % (su0 - b.su), absf((su0 - b.su) - 25.0) < 2.0)

	_yy.hasta = false; _yy.hastalik_riski = 0.0; _yy.saglik = 100.0
	# --- Menu: bilgi, ses, grafik, fps, otomatik kapanma ---
	await cerceve(1); await cerceve(1); await cerceve(1)  # ac, magaza, bilgi
	await tikla(Vector2(240, 240))
	kontrol("Bilgi ekrani acilir", menu.mod == "bilgi")
	await bekle(3)
	root.get_texture().get_image().save_png("res://arac/ekran_bilgi.png")
	await tikla(Vector2(240, 240))
	await cerceve(1); await cerceve(1)  # oyna, ses
	await tikla(Vector2(240, 240))
	kontrol("Ses kapatilir", not root.get_node("Ayarlar").ses_acik)
	await tikla(Vector2(240, 240))
	await cerceve(1); await tikla(Vector2(240, 240))  # grafik: Dengeli -> Yuksek
	kontrol("Grafik profili degisir (%d)" % root.get_node("Ayarlar").profil, root.get_node("Ayarlar").profil == 2)
	await tikla(Vector2(240, 240)); await tikla(Vector2(240, 240))  # Dusuk -> Dengeli
	await cerceve(1); await tikla(Vector2(240, 240))  # fps
	kontrol("FPS gostergesi acilir", root.get_node("Ayarlar").fps_goster)
	await bekle(3)
	root.get_texture().get_image().save_png("res://arac/ekran_menu.png")
	await bekle(int(8.5 * 30))
	kontrol("Menu 8 sn sonra kendiliginden kapanir", not menu.acik)

	# --- Kabarma: baliga dokununca ---
	s.kabarma_beklemesi = 0.0; s.yem_var = false; s.isik_acik = true; s.bekleme_suresi = 0.0
	s.balik_konumu = Vector3(0, -20, 0.2); s.balik_hedefi = s.balik_konumu
	await bekle(5)
	await tikla(s.get_node("Balik").position)
	await bekle(25)
	kontrol("Baliga dokununca kabarir, yem atilmaz (kabarma=%.2f)" % vp.kabarma, vp.kabarma > 0.9 and not s.yem_var)
	root.get_texture().get_image().save_png("res://arac/ekran_kabarma.png")

	# --- Parallax ---
	var tas0: Vector2 = s.get_node("Tas").position
	var arka0: Vector2 = s.get_node("ArkaPlan").position
	s.paralaks_hedef = Vector2(1, 0)
	await bekle(40)
	var dt: float = s.get_node("Tas").position.x - tas0.x
	var da: float = s.get_node("ArkaPlan").position.x - arka0.x
	kontrol("Parallax: kaya arka plandan cok kayar (kaya %.1f px, arka %.1f px)" % [dt, da], dt > 3.5 and da > 1.0 and dt > da * 1.5)
	root.get_texture().get_image().save_png("res://arac/ekran_paralaks.png")
	s.paralaks_hedef = Vector2.ZERO
	await bekle(40)

	# --- Kayit ---
	s._kaydet()
	s.hazir = false; s.queue_free(); await bekle(2)
	var s2 = load("res://sahneler/akvaryum.tscn").instantiate(); root.add_child(s2); await bekle(2)
	var b2 = s2.get_node("Bakim")
	kontrol("Ilerleme kayittan yuklenir (boy=%.2f inci=%d filtre=%s renk=%d)" % [b2.boy, b2.inci_sayisi, b2.filtre, b2.isik_rengi], b2.boy > 0.85 and b2.filtre and b2.isik_rengi == 1 and b2.inciler.size() >= 2)
	root.get_node("Ayarlar").ses_ayarla(true); root.get_node("Ayarlar").fps_ayarla(false)
	for r in sonuc: print(r)
	quit()
