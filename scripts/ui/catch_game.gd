class_name CatchGame
extends Control
## Kepçe mini oyunu: tankın 2D görünümünde istenen balıkları süre bitmeden yakala.
## Hızlı türler zor yakalanır. Yanlış balığa dokunmak süre kaybettirir.

signal finished(success: bool)

const UI_COLORS := {
	"neon": Color(0.2, 0.6, 1.0), "lepistes": Color(1.0, 0.5, 0.2), "japon": Color(1.0, 0.55, 0.1),
	"beta": Color(0.2, 0.25, 0.9), "melek": Color(0.85, 0.85, 0.8), "moli": Color(0.1, 0.1, 0.12),
	"zebra": Color(0.8, 0.78, 0.6), "diskus": Color(0.95, 0.4, 0.15), "koi": Color(0.95, 0.3, 0.2),
	"pirana": Color(0.55, 0.55, 0.6), "arowana": Color(0.8, 0.82, 0.85), "palyaco": Color(1.0, 0.45, 0.05),
	"cerrah": Color(0.15, 0.3, 0.95), "mandarin": Color(0.2, 0.7, 0.6), "aslan": Color(0.7, 0.4, 0.3),
	"balon": Color(0.75, 0.65, 0.4), "denizati": Color(1.0, 0.55, 0.15), "kedi": Color(0.4, 0.4, 0.3),
	"alabalik": Color(0.6, 0.65, 0.5), "fener": Color(0.3, 0.2, 0.2), "kaplumbaga": Color(0.3, 0.5, 0.2),
}

var wanted: Dictionary = {}   ## tür -> kalan adet
var time_left: float = 15.0
var time_max: float = 15.0
var _sprites: Array = []
var _rng := RandomNumberGenerator.new()
var _done := false
var _mouse := Vector2(-100, -100)
var _flash: float = 0.0
var _flash_col := Color.WHITE


func setup(tank: Dictionary, want: Dictionary) -> void:
	wanted = want.duplicate()
	_rng.randomize()
	custom_minimum_size = Vector2(800, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var need := 0
	for k in wanted:
		need += int(wanted[k])
	time_max = 9.0 + need * 3.0
	time_left = time_max
	var fish: Array = TankSim.living(tank)
	fish.shuffle()
	for f in fish.slice(0, 16):
		var s: Dictionary = FishDB.get_species(f.species)
		var size: float = clamp(float(s.length) * 160.0, 14.0, 42.0)
		var spd: float = 60.0 + float(s.speed) * 140.0
		var ang: float = _rng.randf() * TAU
		_sprites.append({
			"species": f.species, "rare": f.get("rare", false),
			"pos": Vector2(_rng.randf_range(60, 740), _rng.randf_range(50, 300)),
			"vel": Vector2(cos(ang), sin(ang) * 0.5) * spd, "speed": spd, "size": size,
			"turn": _rng.randf_range(1.0, 3.0),
		})


func _process(delta: float) -> void:
	if _done:
		return
	time_left -= delta
	_flash = max(0.0, _flash - delta * 3.0)
	var r := Rect2(Vector2(20, 30), size - Vector2(40, 70))
	for s in _sprites:
		s.turn -= delta
		if s.turn <= 0.0:
			s.turn = _rng.randf_range(0.8, 2.5)
			var ang: float = _rng.randf() * TAU
			s.vel = Vector2(cos(ang), sin(ang) * 0.5) * s.speed
		# Kepçe yaklaşınca kaçarlar
		var away: Vector2 = s.pos - _mouse
		if away.length() < 90.0:
			s.vel = s.vel.lerp(away.normalized() * s.speed * 1.3, delta * 3.0)
		s.pos += s.vel * delta
		if s.pos.x < r.position.x or s.pos.x > r.end.x:
			s.vel.x = -s.vel.x
		if s.pos.y < r.position.y or s.pos.y > r.end.y:
			s.vel.y = -s.vel.y
		s.pos = s.pos.clamp(r.position, r.end)
	if time_left <= 0.0:
		_finish(false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		_try_catch(event.position)
		accept_event()


func _try_catch(p: Vector2) -> void:
	var best = null
	var best_d := 1e9
	for s in _sprites:
		var d: float = s.pos.distance_to(p)
		if d < s.size + 22.0 and d < best_d:
			best = s
			best_d = d
	if best == null:
		Sfx.play("splash", -16.0)
		return
	if int(wanted.get(best.species, 0)) > 0:
		wanted[best.species] -= 1
		_sprites.erase(best)
		Sfx.play("splash", -8.0)
		_flash = 1.0
		_flash_col = Color(0.4, 1.0, 0.5)
		var left := 0
		for k in wanted:
			left += int(wanted[k])
		if left <= 0:
			_finish(true)
	else:
		time_left -= 2.0
		Sfx.play("bad", -8.0)
		_flash = 1.0
		_flash_col = Color(1.0, 0.3, 0.3)
		best.vel = -best.vel * 1.5


func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(ok)


func wanted_text() -> String:
	var parts: Array = []
	for k in wanted:
		if int(wanted[k]) > 0:
			parts.append("%d %s" % [wanted[k], FishDB.display_name(k)])
	return ", ".join(parts)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.05, 0.25, 0.32))
	draw_rect(Rect2(0, size.y * 0.45, size.x, size.y * 0.55), Color(0.03, 0.17, 0.24, 0.6))
	draw_rect(Rect2(0, size.y - 34, size.x, 34), Color(0.45, 0.42, 0.36))
	for i in 40:
		draw_circle(Vector2(fmod(i * 97.0, size.x), size.y - 20 + fmod(i * 37.0, 14.0)), 4 + fmod(i * 13.0, 4.0), Color(0.6, 0.57, 0.5))
	for s in _sprites:
		var c: Color = UI_COLORS.get(s.species, Color(0.7, 0.7, 0.7))
		var dir: float = 1.0 if s.vel.x >= 0.0 else -1.0
		var p: Vector2 = s.pos
		var sz: float = s.size
		var is_target: bool = int(wanted.get(s.species, 0)) > 0
		if is_target:
			draw_arc(p, sz + 8, 0, TAU, 24, Color(1, 1, 1, 0.35), 2.0)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, sz, c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tail := PackedVector2Array([p + Vector2(-dir * sz * 0.8, 0), p + Vector2(-dir * sz * 1.6, -sz * 0.5), p + Vector2(-dir * sz * 1.6, sz * 0.5)])
		draw_colored_polygon(tail, c.darkened(0.15))
		draw_circle(p + Vector2(dir * sz * 0.55, -sz * 0.1), max(2.0, sz * 0.12), Color(0.02, 0.02, 0.02))
		if s.rare:
			draw_arc(p, sz + 3, 0, TAU, 20, Color(1.0, 0.85, 0.3), 2.0)
	# Kepçe
	draw_arc(_mouse, 26, 0, TAU, 28, Color(0.9, 0.9, 0.95, 0.9), 3.0)
	draw_line(_mouse + Vector2(18, 18), _mouse + Vector2(70, 70), Color(0.8, 0.8, 0.85), 4.0)
	# Süre çubuğu
	var frac: float = clamp(time_left / time_max, 0.0, 1.0)
	draw_rect(Rect2(10, 8, size.x - 20, 10), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(10, 8, (size.x - 20) * frac, 10), Color(0.4, 0.9, 0.5) if frac > 0.35 else Color(1.0, 0.4, 0.3))
	if _flash > 0.0:
		draw_rect(r, Color(_flash_col, _flash * 0.18))
