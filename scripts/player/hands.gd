class_name Hands
extends Node3D
## Birinci şahıs eller. Bir şey tutarken görünür: koli, kepçe, yem kutusu, telefon (fotoğraf).

var _arms: Node3D
var _item: Node3D
var _t: float = 0.0
var _anim: float = 0.0   ## kısa hareket (yem atma, fotoğraf) için
var _kind: String = ""


func _ready() -> void:
	position = Vector3(0, 0, 0)
	_arms = Node3D.new()
	add_child(_arms)
	var skin := MeshKit.mat(Color(0.93, 0.74, 0.6), 0.6)
	var sleeve := MeshKit.mat(Color(0.12, 0.42, 0.48), 0.8)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "Arm%s" % ("L" if side < 0 else "R")
		arm.position = Vector3(side * 0.24, -0.3, -0.25)
		arm.rotation_degrees = Vector3(-62, side * -12, 0)
		_arms.add_child(arm)
		var fore := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.045
		cm.height = 0.42
		fore.mesh = cm
		fore.material_override = sleeve
		fore.position = Vector3(0, -0.12, 0)
		arm.add_child(fore)
		var hand := MeshInstance3D.new()
		var hm := CapsuleMesh.new()
		hm.radius = 0.038
		hm.height = 0.14
		hand.mesh = hm
		hand.material_override = skin
		hand.position = Vector3(0, 0.13, 0)
		hand.scale = Vector3(1.15, 1.0, 0.6)
		arm.add_child(hand)
		var thumb := MeshInstance3D.new()
		var tm := CapsuleMesh.new()
		tm.radius = 0.014
		tm.height = 0.07
		thumb.mesh = tm
		thumb.material_override = skin
		thumb.position = Vector3(-side * 0.035, 0.11, -0.02)
		thumb.rotation_degrees = Vector3(0, 0, side * 35)
		arm.add_child(thumb)
	for c in _arms.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _clear_item() -> void:
	if _item:
		_item.queue_free()
		_item = null


func hold_box(d: Dictionary) -> void:
	_clear_item()
	_kind = "box"
	_item = Node3D.new()
	DeliveryBox.build_mesh(_item, d)
	_item.position = Vector3(0, -0.42, -0.55)
	_item.scale = Vector3.ONE * 0.9
	add_child(_item)
	_arms.get_node("ArmL").position = Vector3(-0.2, -0.32, -0.42)
	_arms.get_node("ArmR").position = Vector3(0.2, -0.32, -0.42)
	visible = true


func hold_net() -> void:
	_clear_item()
	_kind = "net"
	_item = Node3D.new()
	var metal := MeshKit.mat(Color(0.7, 0.72, 0.75), 0.3, 0.8)
	var handle := MeshKit.cylinder(_item, 0.008, 0.45, Vector3(0, 0, 0), metal, 8)
	handle.rotation_degrees.x = 70
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.07
	tm.outer_radius = 0.08
	ring.mesh = tm
	ring.material_override = metal
	ring.position = Vector3(0, 0.08, -0.22)
	_item.add_child(ring)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.2, 0.5, 0.35, 0.6)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bag := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.075
	sm.height = 0.1
	sm.is_hemisphere = true
	bag.mesh = sm
	bag.rotation_degrees.x = 180
	bag.material_override = mesh_mat
	bag.position = Vector3(0, 0.08, -0.22)
	_item.add_child(bag)
	_item.position = Vector3(0.2, -0.25, -0.45)
	add_child(_item)
	visible = true


func hold_food() -> void:
	_clear_item()
	_kind = "food"
	_item = Node3D.new()
	MeshKit.cylinder(_item, 0.04, 0.11, Vector3.ZERO, MeshKit.mat(Color(0.85, 0.35, 0.15), 0.4), 14)
	MeshKit.cylinder(_item, 0.041, 0.04, Vector3(0, 0.0, 0), MeshKit.mat(Color(0.95, 0.95, 0.9), 0.5), 14)
	_item.position = Vector3(0.22, -0.26, -0.45)
	add_child(_item)
	visible = true
	_anim = 1.0


func hold_phone() -> void:
	_clear_item()
	_kind = "phone"
	_item = Node3D.new()
	MeshKit.box(_item, Vector3(0.075, 0.15, 0.01), Vector3.ZERO, MeshKit.mat(Color(0.05, 0.05, 0.06), 0.2))
	var scr := StandardMaterial3D.new()
	scr.albedo_color = Color(0.5, 0.8, 1.0)
	scr.emission_enabled = true
	scr.emission = Color(0.5, 0.8, 1.0)
	MeshKit.box(_item, Vector3(0.065, 0.135, 0.002), Vector3(0, 0, 0.006), scr)
	_item.position = Vector3(0.15, -0.2, -0.4)
	_item.rotation_degrees = Vector3(10, -10, 0)
	add_child(_item)
	visible = true
	_anim = 1.2


func clear() -> void:
	_clear_item()
	_kind = ""
	visible = false
	_arms.get_node("ArmL").position = Vector3(-0.24, -0.3, -0.25)
	_arms.get_node("ArmR").position = Vector3(0.24, -0.3, -0.25)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var sp: float = 0.0
	var p := get_parent().get_parent() as CharacterBody3D
	if p:
		sp = Vector2(p.velocity.x, p.velocity.z).length()
	position.y = sin(_t * 9.0) * 0.008 * clamp(sp / 2.6, 0.0, 1.0)
	if _anim > 0.0:
		_anim -= delta
		if _item:
			_item.rotation.x = sin((1.0 - _anim) * PI * 2.0) * 0.5
		if _anim <= 0.0 and (_kind == "food" or _kind == "phone"):
			clear()
			if not Game.carrying.is_empty():
				hold_box(Game.carrying)
