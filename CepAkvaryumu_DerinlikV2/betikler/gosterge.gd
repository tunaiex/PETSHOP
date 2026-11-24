extends Node2D
## En son katmanda hem gece karartmasi hem acik yazi yerine yay gosterir.
## Guvenli bolge: tum gostergeler merkezden en fazla ~221 px uzakta (yuvarlak
## ekranin kenarindan >=19 px iceride); 438x438 saatte orantili kuculur.
const MERKEZ := Vector2(240.0, 240.0)
@onready var akvaryum: Node = get_parent()
var bildirimler: Array[String] = []
var bildirim_suresi := 0.0
const BILDIRIM_SURE := 3.8


## Ustte kisa bilgi seridi (kuyruklu: ust uste gelirse sirayla gosterilir).
func bildirim(metin: String) -> void:
	if bildirimler.size() < 4 and (bildirimler.is_empty() or bildirimler[-1] != metin):
		bildirimler.append(metin)
		if bildirimler.size() == 1:
			bildirim_suresi = BILDIRIM_SURE


func _process(delta: float) -> void:
	if bildirimler.is_empty():
		return
	bildirim_suresi -= delta
	if bildirim_suresi <= 0.0:
		bildirimler.pop_front()
		bildirim_suresi = BILDIRIM_SURE

func _draw() -> void:
	if not bool(akvaryum.get("isik_acik")):
		draw_circle(MERKEZ, 241.0, Color(0.0, 0.02, 0.07, 0.75))
	# Saat cercevesinin solunda tokluk gostergesi, draw_arc() ile.
	var baslangic := deg_to_rad(145.0)
	var bitis := deg_to_rad(215.0)
	draw_arc(MERKEZ, 214.0, baslangic, bitis, 32, Color(0.01, 0.07, 0.11, 0.76), 13.0, true)
	draw_arc(MERKEZ, 214.0, baslangic, lerpf(baslangic, bitis, float(akvaryum.get("aclik")) / 100.0), 32, Color(1.0, 0.43, 0.04), 9.0, true)
	# Sagda su kalitesi (ayna simetrik, mavi). Kirlendikce sari-yesile doner.
	var bakim: Node = akvaryum.get_node("Bakim")
	var su: float = bakim.su_gorunen / 100.0
	var sag_bas := deg_to_rad(35.0)
	var sag_bit := deg_to_rad(-35.0)
	draw_arc(MERKEZ, 214.0, sag_bas, sag_bit, 32, Color(0.01, 0.07, 0.11, 0.76), 13.0, true)
	var su_renk := Color(0.75, 0.78, 0.2).lerp(Color(0.25, 0.85, 1.0), clampf((su - 0.3) / 0.5, 0.0, 1.0))
	if su > 0.005:
		draw_arc(MERKEZ, 214.0, sag_bas, lerpf(sag_bas, sag_bit, su), 32, su_renk, 9.0, true)
	# Performans gostergesi (menu > FPS): saatte akicilik / yuk olcumu icin
	if Ayarlar.fps_goster:
		var yazi := ThemeDB.fallback_font
		var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var cizim := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var bellek := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var satir1 := "%d FPS  ·  %.1f ms" % [Engine.get_frames_per_second(), ms]
		var satir2 := "%d çizim  ·  %.0f MB" % [cizim, bellek]
		draw_rect(Rect2(160, 392, 160, 40), Color(0, 0, 0, 0.55))
		draw_string(yazi, Vector2(160, 409), satir1, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(0.6, 1.0, 0.6))
		draw_string(yazi, Vector2(160, 426), satir2, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.8, 0.9, 1.0))
	# Sag alt ya da kenarlarda yazi kullanmiyoruz; merkez oyuncak gibi kalmiyor.
	# Minik isik sembolu: basma alani degil, uzun basmaya gorsel ipucu.
	draw_circle(Vector2(240.0, 56.0), 18.0, Color(0.0, 0.08, 0.12, 0.50))
	var renk := Color(1.0, 0.83, 0.35) if bool(akvaryum.get("isik_acik")) else Color(0.45, 0.57, 0.66)
	draw_arc(Vector2(240.0, 53.0), 6.0, PI, TAU, 12, renk, 2.4, true)
	draw_line(Vector2(236.0, 60.0), Vector2(244.0, 60.0), renk, 2.2, true)
	for yon in [Vector2(0,-12),Vector2(-12,0),Vector2(12,0)]:
		draw_line(Vector2(240,53) + yon * 0.75, Vector2(240,53)+yon,renk,1.6,true)

	_ihtiyac_ikonu()
	_oyun_noktasi()
	_bildirim_ciz()


func _bildirim_ciz() -> void:
	if bildirimler.is_empty():
		return
	var yazi := ThemeDB.fallback_font
	var a := clampf(minf(bildirim_suresi, BILDIRIM_SURE - bildirim_suresi) * 4.0, 0.0, 1.0)
	var metin: String = bildirimler[0]
	var boyut := 15
	var g := yazi.get_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, -1, boyut).x
	if g > 300.0:
		boyut = 13
		g = yazi.get_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, -1, boyut).x
	var w := minf(g + 28.0, 330.0)
	var r := Rect2(240.0 - w / 2.0, 82.0, w, 28.0)
	draw_rect(r, Color(0.0, 0.05, 0.09, 0.78 * a))
	draw_string(yazi, Vector2(r.position.x, 101.0), metin, HORIZONTAL_ALIGNMENT_CENTER, w, boyut, Color(1, 1, 1, a))


## Baligin ustunde, en onemli ihtiyacin kucuk ikonu (yanip soner).
func _ihtiyac_ikonu() -> void:
	var yasam: Node = akvaryum.get_node("Yasam")
	if akvaryum.menu.acik or akvaryum.oyun_kalan > 0.0 or not akvaryum.balik.visible:
		return
	var ist: Array = yasam.ihtiyaclar()
	if ist.is_empty():
		return
	var ad: String = ist[0]
	var t := Time.get_ticks_msec() / 1000.0
	var a := 0.6 + 0.4 * sin(t * 4.0)
	var p: Vector2 = akvaryum.balik.position + Vector2(0, -48.0 * akvaryum.balik.scale.y / maxf(akvaryum.balik_3d.olcek_carpani(), 0.01))
	p.y = maxf(p.y, 125.0)
	# Konusma balonu
	draw_circle(p, 13.0, Color(1, 1, 1, 0.88 * a))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 10), p + Vector2(4, 10), p + Vector2(0, 18)]), Color(1, 1, 1, 0.88 * a))
	match ad:
		"ac":  # yem tanesi
			draw_circle(p, 4.5, Color(0.55, 0.3, 0.12, a)); draw_circle(p + Vector2(-1.5, -1.5), 1.6, Color(0.95, 0.65, 0.3, a))
		"su":  # su damlasi (bulanik)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(5, 2), p + Vector2(0, 6), p + Vector2(-5, 2)]), Color(0.5, 0.6, 0.2, a))
		"cam":  # yosun lekesi
			draw_circle(p, 5.5, Color(0.3, 0.5, 0.12, a)); draw_circle(p + Vector2(3, -2), 3.0, Color(0.25, 0.42, 0.1, a))
		"kaka":
			draw_circle(p + Vector2(-2, 1), 3.2, Color(0.3, 0.2, 0.1, a)); draw_circle(p + Vector2(2, -1), 2.6, Color(0.3, 0.2, 0.1, a))
		"hasta":  # kirmizi arti
			draw_rect(Rect2(p + Vector2(-2, -6), Vector2(4, 12)), Color(0.9, 0.15, 0.15, a)); draw_rect(Rect2(p + Vector2(-6, -2), Vector2(12, 4)), Color(0.9, 0.15, 0.15, a))
		"uyku":  # hilal
			draw_circle(p, 6.0, Color(0.95, 0.8, 0.3, a)); draw_circle(p + Vector2(3, -2), 5.2, Color(1, 1, 1, 0.88 * a))
		"sikildi":  # top
			draw_circle(p, 5.5, Color(0.2, 0.6, 0.95, a)); draw_arc(p, 5.5, -0.5, 1.5, 8, Color(1, 1, 1, a), 1.5)


## Oyun: lazer gibi parlayan nokta + kalan sure halkasi
func _oyun_noktasi() -> void:
	if akvaryum.oyun_kalan <= 0.0:
		return
	var p: Vector2 = akvaryum.oyun_noktasi
	var t := Time.get_ticks_msec() / 1000.0
	draw_circle(p, 11.0 + sin(t * 9.0) * 1.5, Color(1.0, 0.25, 0.2, 0.18))
	draw_circle(p, 6.0, Color(1.0, 0.3, 0.25, 0.55))
	draw_circle(p, 2.8, Color(1.0, 0.9, 0.85, 0.95))
	var oran: float = akvaryum.oyun_kalan / akvaryum.OYUN_SURE
	draw_arc(MERKEZ, 229.0, -PI / 2.0, -PI / 2.0 + TAU * oran, 64, Color(1.0, 0.45, 0.35, 0.8), 4.0, true)
