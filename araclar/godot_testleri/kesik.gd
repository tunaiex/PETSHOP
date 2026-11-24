extends SceneTree
# Halfmoon + kabarma + 16 yon: dahili goruntunun kenarlarinda balik pikseli var mi?
func _initialize():
	var vp = load("res://betikler/balik_3d.gd").new()
	root.add_child(vp)
	await process_frame
	print("dahili boyut ", vp.size, " olcek carpani ", vp.olcek_carpani())
	var en_kotu := 0.0
	var sayi := 0
	for durum in [[1.15, false, 0.0], [1.15, true, 0.0], [1.15, false, 0.5], [1.15, true, 0.4]]:
		vp.yuzgec_olcek = durum[0]
		vp.kabarma_suresi = 99.0 if durum[1] else 0.0
		vp.kabarma = 1.0 if durum[1] else 0.0
		for i in 16:
			var a := i * TAU / 16.0
			var y := Vector3(cos(a), durum[2] * (1 if i % 2 == 0 else -1), sin(a))
			for f in 8:
				vp.guncelle(y, 66.0, 1.0 / 30.0, false)
				await process_frame
			var im: Image = vp.get_texture().get_image()
			var w := im.get_width(); var h := im.get_height()
			var kenar := 0.0
			for x in w:
				kenar = maxf(kenar, maxf(im.get_pixel(x, 0).a, im.get_pixel(x, h - 1).a))
			for yy in h:
				kenar = maxf(kenar, maxf(im.get_pixel(0, yy).a, im.get_pixel(w - 1, yy).a))
			en_kotu = maxf(en_kotu, kenar)
			if kenar > 0.02: sayi += 1
			if i == 2 and durum[1]: im.save_png("res://arac/kesik_ornek.png")
	print("kenarda en fazla alfa: %.3f, kenara degen poz: %d / 64" % [en_kotu, sayi])
	quit()
