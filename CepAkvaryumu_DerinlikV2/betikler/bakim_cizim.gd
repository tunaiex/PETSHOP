extends Node2D
## Bakim katmanlarindan birini cizer. Veriyi ust dugumdeki Bakim'dan okur ve
## yalnizca bir sey degistiginde yeniden cizer (her karede degil: pil).

enum Katman { YUVA, ARTIK, SU, YOSUN, INCI, RENK }
@export var katman: Katman = Katman.YOSUN

const MERKEZ := Vector2(240.0, 240.0)
const KABARCIK := preload("res://gorseller/kabarcik.png")
const YOSUN := preload("res://gorseller/yosun.png")  # 3 cesit leke, yan yana 96 px
@onready var bakim: Node = get_parent()


const RENKLER := [Color(1, 1, 1), Color(1.0, 0.80, 0.62), Color(0.62, 0.74, 1.0)]


func _ready() -> void:
	bakim.degisti.connect(queue_redraw)
	set_process(katman == Katman.INCI)
	if katman == Katman.RENK:
		# Isik rengi: tum sahneyi carparak renklendirir (HUD haric, o daha ustte)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		material = m


func _process(_delta: float) -> void:
	# Incilerin parlamasi icin (yalnizca kumda inci varken)
	if not bakim.inciler.is_empty():
		queue_redraw()


func _draw() -> void:
	match katman:
		Katman.YUVA: _yuva()
		Katman.ARTIK: _artiklar()
		Katman.SU: _su()
		Katman.YOSUN: _yosun()
		Katman.INCI: _inciler()
		Katman.RENK: _renk()


func _inciler() -> void:
	var zaman := Time.get_ticks_msec() / 1000.0
	for i in bakim.inciler.size():
		var p: Vector2 = bakim.inciler[i]
		draw_circle(p + Vector2(1.5, 2.0), 5.0, Color(0, 0, 0, 0.30))         # golge
		draw_circle(p, 4.6, Color(0.86, 0.84, 0.88))                           # inci
		draw_circle(p + Vector2(0.9, 1.0), 3.4, Color(0.74, 0.70, 0.78))       # alt golgelenme
		draw_circle(p + Vector2(-0.6, -0.7), 3.0, Color(0.97, 0.94, 0.97))
		draw_circle(p + Vector2(0.5, -0.2), 2.2, Color(1.0, 0.86, 0.92, 0.35)) # sedef pembesi
		draw_circle(p + Vector2(-1.6, -1.8), 1.1, Color(1, 1, 1, 0.95))        # parlama
		# Ara ara yildiz gibi parildar
		var parilti := pow(maxf(0.0, sin(zaman * 1.7 + i * 2.1)), 12.0)
		if parilti > 0.02:
			var k := 7.0 * parilti
			var r := Color(1, 1, 1, parilti)
			draw_line(p + Vector2(-1.6 - k, -1.8), p + Vector2(-1.6 + k, -1.8), r, 1.0, true)
			draw_line(p + Vector2(-1.6, -1.8 - k), p + Vector2(-1.6, -1.8 + k), r, 1.0, true)


func _renk() -> void:
	if bakim.isik_rengi != 0:
		draw_circle(MERKEZ, 241.0, RENKLER[bakim.isik_rengi])


func _yuva() -> void:
	# Yumurtalar (yeni oyun / yeni nesil): kopuklerin arasinda sarimsi taneler
	var yasam := bakim.get_node_or_null("../Yasam")
	if yasam and (yasam.evre == yasam.Evre.YUMURTA or yasam.yumurta_var):
		var r2 := RandomNumberGenerator.new()
		r2.seed = 99
		for i in 14:
			var e := Vector2(330.0, 108.0) + Vector2(r2.randf_range(-22.0, 22.0), r2.randf_range(-3.0, 5.0))
			draw_circle(e, 2.3, Color(0.98, 0.93, 0.75, 0.95))
			draw_circle(e + Vector2(-0.6, -0.6), 0.8, Color(1, 1, 1, 0.9))
	# Yuzeyde, sag ustte kopuk kabarciklarindan olusan yuva.
	var adet := int(bakim.yuva * 46.0)
	if adet <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in adet:
		var p := Vector2(330.0, 104.0) + Vector2(rng.randf_range(-38.0, 38.0) * (0.4 + 0.6 * bakim.yuva), rng.randf_range(-5.0, 6.0))
		var r := rng.randf_range(1.6, 3.8)
		draw_texture_rect(KABARCIK, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, 0.9))


func _artiklar() -> void:
	for a in bakim.artiklar:
		# Zamanla kararir ve kuculur (cozunme)
		var omur: float = clampf(1.0 - a["yas"] / (bakim.ARTIK_OMUR_SAAT * bakim.SAAT), 0.0, 1.0)
		var p: Vector2 = a["p"]
		draw_circle(p, 3.2 * (0.5 + 0.5 * omur), Color(0.30, 0.17, 0.07, 0.9))
		draw_circle(p + Vector2(-1.2, -1.0), 1.4 * (0.5 + 0.5 * omur), Color(0.62, 0.38, 0.16, 0.8 * omur))


func _su() -> void:
	# Kirli su: tum akvaryuma sari-yesil bir bulaniklik ve suzulen tanecikler.
	var kir: float = 1.0 - bakim.su_gorunen / 100.0
	if kir < 0.04:
		return
	draw_circle(MERKEZ, 241.0, Color(0.40, 0.45, 0.10, kir * 0.42))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in int(kir * 40.0):
		var p := MERKEZ + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 200.0
		draw_circle(p, rng.randf_range(0.8, 1.8), Color(0.55, 0.5, 0.25, 0.35 + kir * 0.3))


func _yosun() -> void:
	# Cam yuzeyindeki yosun lekeleri: her leke tek doku cizimi (saat icin ucuz).
	for leke in bakim.lekeler:
		var l: float = leke["l"]
		if l < 0.03:
			continue
		var t: int = leke["t"]
		var r: float = leke["r"] * (0.55 + 0.45 * l) * 1.25
		var kaynak := Rect2((t % 3) * 96, 0, 96, 96)
		draw_set_transform(leke["p"], float(t % 628) / 100.0, Vector2.ONE)
		draw_texture_rect_region(YOSUN, Rect2(-r, -r, r * 2.0, r * 2.0), kaynak, Color(1, 1, 1, minf(1.0, l * 1.3)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
