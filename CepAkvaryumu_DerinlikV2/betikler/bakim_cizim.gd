extends Node2D
## Bakim katmanlarindan birini cizer. Veriyi ust dugumdeki Bakim'dan okur ve
## yalnizca bir sey degistiginde yeniden cizer (her karede degil: pil).

enum Katman { YUVA, ARTIK, SU, YOSUN }
@export var katman: Katman = Katman.YOSUN

const MERKEZ := Vector2(240.0, 240.0)
const KABARCIK := preload("res://gorseller/kabarcik.png")
@onready var bakim: Node = get_parent()


func _ready() -> void:
	bakim.degisti.connect(queue_redraw)


func _draw() -> void:
	match katman:
		Katman.YUVA: _yuva()
		Katman.ARTIK: _artiklar()
		Katman.SU: _su()
		Katman.YOSUN: _yosun()


func _yuva() -> void:
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
	# Cam yuzeyindeki yosun lekeleri: duzensiz, ust uste binen yumusak daireler.
	for leke in bakim.lekeler:
		var l: float = leke["l"]
		if l < 0.03:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = leke["t"]
		var p: Vector2 = leke["p"]
		var r: float = leke["r"] * (0.55 + 0.45 * l)
		var renk := Color(0.27, 0.42, 0.10, 0.30 * l)
		draw_circle(p, r, renk)
		for i in 7:
			var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 0.85) * r
			draw_circle(q, r * rng.randf_range(0.25, 0.55), Color(0.25, 0.40, 0.09, 0.32 * l))
		for i in 6:
			var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 1.0) * r
			draw_circle(q, rng.randf_range(0.8, 2.0), Color(0.17, 0.27, 0.05, 0.55 * l))
