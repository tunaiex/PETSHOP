class_name Player
extends CharacterBody3D
## Birinci şahıs oyuncu. Masaüstünde WASD + fare, telefonda sanal joystick + sağ tarafı sürükleme.

const SPEED := 2.6
const MOUSE_SENS := 0.0025
const TOUCH_SENS := 0.005
const REACH := 2.6

var hud: Node
var camera: Camera3D
var hands: Hands
var ray: RayCast3D
var focus: Object = null

var _yaw: float = 0.0
var _pitch: float = 0.0
var _bob: float = 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.62, 0)
	camera.fov = 72.0
	camera.near = 0.03
	camera.current = true
	add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collide_with_areas = false
	ray.collision_mask = 1 | 2  # 2: kapı tabelası gibi yürümeyi engellemeyen etkileşim alanları
	camera.add_child(ray)
	hands = Hands.new()
	camera.add_child(hands)
	Game.carry_changed.connect(_on_carry)


func _on_carry() -> void:
	if Game.carrying.is_empty():
		hands.clear()
	else:
		hands.hold_box(Game.carrying)
	_yaw = rotation.y
	rotation = Vector3.ZERO


func look(delta_px: Vector2, sens: float) -> void:
	_yaw -= delta_px.x * sens
	_pitch = clamp(_pitch - delta_px.y * sens, deg_to_rad(-80), deg_to_rad(80))


func _building() -> bool:
	return hud != null and hud.builder != null and hud.builder.active


func _unhandled_input(event: InputEvent) -> void:
	if hud and hud.is_blocking():
		return
	if _building():
		var b: Builder = hud.builder
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_R:
					b.rotate_by(Builder.ROT_STEP * (-1.0 if event.shift_pressed else 1.0))
				KEY_ESCAPE:
					b.cancel()
				KEY_E, KEY_ENTER:
					b.confirm()
			if event.keycode in [KEY_R, KEY_ESCAPE, KEY_E, KEY_ENTER]:
				return
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				b.rotate_by(Builder.ROT_STEP)
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				b.rotate_by(-Builder.ROT_STEP)
				return
			if event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				b.confirm()
				return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative, MOUSE_SENS)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not DisplayServer.is_touchscreen_available():
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				try_interact()
	elif event.is_action_pressed("interact"):
		try_interact()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G and not Game.carrying.is_empty():
		Game.carry_to_depot()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if hud:
			hud.open_menu()


func try_interact() -> void:
	if focus and is_instance_valid(focus) and focus.has_method("interact"):
		focus.interact(self)


func _physics_process(delta: float) -> void:
	rotation.y = _yaw
	camera.rotation.x = _pitch
	var input := Vector2.ZERO
	if not (hud and hud.is_blocking()):
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if hud:
			input += hud.joystick_vector()
	if input.length() > 1.0:
		input = input.normalized()
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Hafif yürüme sallantısı
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.1:
		_bob += delta * spd * 3.2
	camera.position.y = 1.62 + sin(_bob * 2.0) * 0.025 * clamp(spd / SPEED, 0.0, 1.0)
	_update_focus()


func _update_focus() -> void:
	focus = null
	ray.force_raycast_update()
	if ray.is_colliding():
		var c: Object = ray.get_collider()
		if c and c.has_meta("interact"):
			focus = c.get_meta("interact")
	if hud:
		if _building():
			focus = null
			hud.set_prompt("")
		else:
			hud.set_prompt(focus.get_prompt() if focus else "")
