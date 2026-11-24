extends SceneTree
var sonuc := []
func kontrol(ad, kosul):
	sonuc.append(("GECTI  " if kosul else "KALDI  ") + ad)
func bekle(n):
	for i in n: await process_frame
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://akvaryum_kaydi.json"))
	var s = load("res://sahneler/akvaryum.tscn").instantiate()
	root.add_child(s); await bekle(3)
	var y = s.get_node("Yasam"); y.test_yetiskin(); await bekle(2)
	var b = s.get_node("Bakim"); var L = s.get_node("Lepistesler"); var vp = s.get_node("Balik3D")
	b.su = 100.0; for l in b.lekeler: l["l"] = 0.0
	b.degisti.emit(); s.aclik = 100.0
	L.ekle(-0.2)
	b.yuva = 1.0; b.mutluluk = 90.0
	kontrol("Kosullar saglaninca ureme mumkun", y.ureme_mumkun())
	await bekle(40)
	kontrol("Uygulama acikken canli kur sahnesi baslar", s.ureme_kalan > 0.0)
	var kabardi := false
	var sarildi := 0.0
	var yuvada := false
	for i in int(28 * 30):
		await process_frame
		b.mutluluk = 90.0; s.aclik = 100.0
		if vp.kabarma > 0.5: kabardi = true
		sarildi = maxf(sarildi, vp.sarilma)
		if i == 18 * 30:
			root.get_texture().get_image().save_png("res://arac/ureme_sarilma.png")
			var d: Vector3 = L.suru[0]["konum"]
			yuvada = Vector2(d.x - s.YUVA_ALTI.x, d.y - s.YUVA_ALTI.y).length() < 40.0
		if i == 6 * 30:
			root.get_texture().get_image().save_png("res://arac/ureme_kur.png")
	kontrol("Kurda erkek kabarir", kabardi)
	kontrol("Disi yuvanin altina gelir", yuvada)
	kontrol("Yuvanin altinda sarilma (C kivrimi, %.2f)" % sarildi, sarildi > 0.6)
	kontrol("Sonunda yuvada yumurtalar", y.yumurta_var and s.ureme_kalan <= 0.0 and vp.sarilma == 0.0)
	root.get_texture().get_image().save_png("res://arac/ureme_yumurta.png")
	kontrol("3 gun bekleme: hemen tekrar ureme yok", not y.ureme_mumkun())
	for r in sonuc: print(r)
	quit()
