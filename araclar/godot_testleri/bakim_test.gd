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
func surukle(p):
	var e := InputEventScreenDrag.new(); e.index = 0; e.position = p
	Input.parse_input_event(e); await process_frame
func ileri_sar(saat):
	s.son_hesaplama_zamani -= saat * 3600.0
	s._zaman_farkini_uygula()
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://akvaryum_kaydi.json"))
	s = load("res://sahneler/akvaryum.tscn").instantiate()
	root.add_child(s)
	await bekle(3); s.get_node("Yasam").test_yetiskin(); await bekle(2)
	b = s.get_node("Bakim")

	# 1 Zamanla kirlenme
	b.su = 100.0
	for l in b.lekeler: l["l"] = 0.0
	s.aclik = 100.0
	ileri_sar(24)
	kontrol("24 saatte su ~50'ye iner (%.1f)" % b.su, absf(b.su - 50.0) < 2.0)
	kontrol("24 saatte camda yosun birikir (temizlik %.2f)" % b.cam_temizligi(), b.cam_temizligi() < 0.2)
	kontrol("Ac balik + kirli su = mutluluk duser (%.0f)" % b.mutluluk, b.mutluluk < 40.0)
	await bekle(3)
	root.get_texture().get_image().save_png("res://arac/kirli.png")

	# 2 Cami silme: ortadan gecen bir kaydirma lekeleri azaltir
	var once: float = b.cam_temizligi()
	s.basili = false
	await dokun(Vector2(60, 240), true)
	for i in 1: pass
	for i in range(1, 19): await surukle(Vector2(60 + i * 20, 240))
	await dokun(Vector2(420, 240), false)
	kontrol("Yatay kaydirma yosunu siler (%.2f -> %.2f)" % [once, b.cam_temizligi()], b.cam_temizligi() > once + 0.03)

	var _yy = s.get_node("Yasam"); _yy.hasta = false; _yy.hastalik_riski = 0.0; _yy.saglik = 100.0
	# 3 Menu: cerceve ile ac, "Su degistir" (ilk oge) dokunarak sec
	var degisti := [0]
	s.su_degistirildi.connect(func(): degisti[0] += 1)
	b.su = 40.0
	var w := InputEventMouseButton.new(); w.button_index = MOUSE_BUTTON_WHEEL_DOWN; w.pressed = true
	Input.parse_input_event(w); await bekle(2)
	kontrol("Cerceve menuyu acar", s.get_node("Menu").acik)
	await dokun(Vector2(240, 240), true); await bekle(2); await dokun(Vector2(240, 240), false)
	kontrol("Menuden su degisimi (su=%.0f, sinyal=%d, menu kapandi=%s)" % [b.su, degisti[0], not s.get_node("Menu").acik], b.su > 99.5 and degisti[0] == 1 and not s.get_node("Menu").acik)
	await bekle(80)

	# 4 Kenarda dairesel kaydirma da menuyu acar ve gezinir
	var M := Vector2(240, 240)
	await dokun(M + Vector2(200, 0), true)
	for i in range(1, 25): await surukle(M + Vector2(200, 0).rotated(deg_to_rad(i * 5.0)))
	await dokun(M + Vector2(200, 0).rotated(deg_to_rad(120.0)), false)
	var mn = s.get_node("Menu")
	kontrol("Kenarda kaydirma menuyu acar ve gezinir (secim=%d)" % mn.secim, mn.acik and mn.secim == 3)
	mn.kapat()

	# 5 Tok balik yemi yemez, yem dibe coker ve suyu kirletir
	s.aclik = 98.0; s.yem_var = false; s.isik_acik = true
	await dokun(Vector2(250, 200), true); await bekle(2); await dokun(Vector2(250, 200), false)
	kontrol("Tok balik yemi yemez, yem dibe coker (artik=%d)" % b.artiklar.size(), not s.yem_var and b.artiklar.size() == 1)
	await bekle(320)
	kontrol("Yem dipte durur (y=%.0f)" % b.artiklar[0]["p"].y, b.artiklar[0]["p"].y > 395.0)
	var su_once: float = b.su
	ileri_sar(1)
	kontrol("Dipteki yem suyu ekstra kirletir (1 saatte %.1f puan)" % (su_once - b.su), su_once - b.su > 7.5)
	ileri_sar(3)
	kontrol("Yem 3 saatte cozunur", b.artiklar.is_empty())

	s.get_node("Yasam").hasta = false; s.get_node("Yasam").hastalik_riski = -99.0
	# 6 Mutluluk ve yuva
	b.su = 100.0; for l in b.lekeler: l["l"] = 0.0
	b.mutluluk = 90.0; b.yuva = 0.0
	s.aclik = 100.0
	for i in 6:
		s.aclik = 100.0
		b.su = 100.0
		for l in b.lekeler: l["l"] = 0.0
		ileri_sar(1)
	kontrol("Mutlu balik 6 saatte kopuk yuvasi yapar (yuva=%.2f, mutluluk=%.0f)" % [b.yuva, b.mutluluk], b.yuva > 0.9)
	await bekle(5)
	root.get_texture().get_image().save_png("res://arac/temiz.png")

	# 7 Isik kapaninca balik uyku noktasina gider
	s.isik_acik = false; s._fps_ayarla()
	s.balik_konumu = Vector3(80, -40, 0.3)
	for i in 650: await process_frame
	var mesafe = Vector3(s.balik_konumu.x - s.UYKU_NOKTASI.x, s.balik_konumu.y - s.UYKU_NOKTASI.y, (s.balik_konumu.z - s.UYKU_NOKTASI.z) * 260.0).length()
	kontrol("Isik kapali: balik bitkilerin yanina gider (kalan %.0f px)" % mesafe, mesafe < 10.0)
	root.get_texture().get_image().save_png("res://arac/uyku.png")

	# 8 Kayit: bakim verisi saklanir
	s.isik_acik = true
	b.su = 63.0; b.yuva = 0.4
	s._kaydet()
	s.hazir = false; s.queue_free(); await bekle(2)
	var s2 = load("res://sahneler/akvaryum.tscn").instantiate(); root.add_child(s2); await bekle(2)
	var b2 = s2.get_node("Bakim")
	kontrol("Bakim kayittan yuklenir (su=%.1f yuva=%.2f)" % [b2.su, b2.yuva], absf(b2.su - 63.0) < 0.5 and absf(b2.yuva - 0.4) < 0.01)
	for r in sonuc: print(r)
	quit()
