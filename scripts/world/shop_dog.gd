class_name ShopDog
extends Node3D
## Dükkânın maskotu: Labrador "Karamel". Mağazada dolaşır, koklar, oturur, yatar.
## Oyuncu severse kuyruk sallar (silkinir / oyun daveti), müşteriler onu sever (+itibar, günde bir).

const MODEL := "res://assets/modeller/hayvan/labrador.glb"
const SCALE := 0.5        ## model gerçeğin iki katı büyüklükte geliyor
const WALK_SPEED := 0.98 * SCALE   ## yürüme animasyonuna uyan hız (m/sn)
const NAME := "Karamel"

var shop: Shop
var _ap: AnimationPlayer
var _path: Array = []
var _state: String = "idle"   ## idle | walk | sit | lie | trick
var _timer: float = 2.0
var _rng := RandomNumberGenerator.new()
var _petted_day: int = -1


func setup(s: Shop) -> void:
	shop = s
	_rng.randomize()
	if not ResourceLoader.exists(MODEL):
		return
	var m: Node3D = (load(MODEL) as PackedScene).instantiate()
	m.rotation.y = PI  # model +Z'ye bakar, bu düğüm -Z yönünde yürür
	m.scale = Vector3.ONE * SCALE
	add_child(m)
	for c in m.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for a in m.find_children("*", "AnimationPlayer", true, false):
		_ap = a
		break
	if _ap:
		for n in ["Idle", "Walk", "Sniff", "Sit_Idle", "Lie_Idle", "Bark"]:
			if _ap.has_animation(n):
				_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_ap.animation_finished.connect(_on_anim_done)
		_play("Idle")
	Shop.add_blob_shadow(self, Vector2(0.4, 0.8), 0.45)
	# Bakınca etkileşim: yürümeyi engellemeyen 2. katman alanı
	Interactable.create(self, Vector3(0.4, 0.7, 0.9), Vector3(0, 0.35, 0), get_prompt, interact)


func get_prompt() -> String:
	return "%s'i sev" % NAME


func interact(_p: Node) -> void:
	_path.clear()
	_state = "trick"
	_play(["Shake", "Play_Bow"][_rng.randi_range(0, 1)])
	Sfx.play("good")
	if _petted_day != Game.day:
		_petted_day = Game.day
		Game.change_reputation(0.5)
		Game.notify.emit("%s kuyruk sallıyor! Müşteriler dükkân köpeğini çok seviyor (+itibar)." % NAME, "good")


func _play(n: String, blend: float = 0.3) -> void:
	if _ap and _ap.has_animation(n) and _ap.current_animation != n:
		_ap.play(n, blend)


func _on_anim_done(n: StringName) -> void:
	match str(n):
		"Sit":
			_play("Sit_Idle", 0.0)
		"Lie_Down":
			_play("Lie_Idle", 0.0)
		"Shake", "Play_Bow":
			_state = "idle"
			_timer = _rng.randf_range(1.0, 3.0)
			_play("Idle")


## Satış alanında rastgele bir nokta
func _random_spot() -> Vector3:
	var r: Rect2 = Shop.ROOM
	return Vector3(_rng.randf_range(r.position.x + 0.6, r.end.x - 0.6), 0, _rng.randf_range(r.position.y + 0.6, r.end.y - 0.8))


func _process(delta: float) -> void:
	if shop == null:
		return
	var dt: float = delta * clamp(Game.time_scale, 1.0, 3.0)
	match _state:
		"walk":
			if _path.is_empty():
				_state = "idle"
				_timer = _rng.randf_range(2.0, 5.0)
				_play("Idle")
			else:
				var target: Vector3 = _path[0]
				var to: Vector3 = target - position
				to.y = 0.0
				var d: float = to.length()
				if d < 0.08:
					_path.pop_front()
				else:
					var sp: float = WALK_SPEED * (0.95 if _ap and _ap.current_animation == "Walk" else 0.9)
					position += to / d * min(d, sp * dt)
					var want := Basis.looking_at(to / d, Vector3.UP)
					transform.basis = transform.basis.orthonormalized().slerp(want, clamp(dt * 5.0, 0.0, 1.0))
			if _ap:
				_ap.speed_scale = clamp(Game.time_scale, 1.0, 3.0)
		"trick":
			pass
		_:
			_timer -= dt
			if _timer <= 0.0:
				_next()


func _next() -> void:
	var roll: float = _rng.randf()
	if _state == "sit" or _state == "lie" or roll < 0.55:
		var p: Array = shop.path(position, _random_spot())
		if p.size() >= 2:
			_path = p.slice(1)
			_state = "walk"
			_play("Sniff" if _rng.randf() < 0.35 else "Walk")
			return
	if roll < 0.75:
		_state = "sit"
		_timer = _rng.randf_range(6.0, 12.0)
		_play("Sit")
	elif roll < 0.9:
		_state = "lie"
		_timer = _rng.randf_range(10.0, 20.0)
		_play("Lie_Down")
	else:
		_state = "idle"
		_timer = _rng.randf_range(2.0, 4.0)
		_play("Bark" if _rng.randf() < 0.3 else "Idle")
