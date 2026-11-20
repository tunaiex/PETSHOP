class_name FurnitureItem
extends Node3D
## Kasa tezgâhı, saksı bitkileri ve paspas gibi genel eşyalar.

const PROPS := "res://assets/models/props/%s.glb"

var furniture_uid: int = 0
var type: String = ""
var main: Node


func setup(uid: int, t: String, m: Node) -> void:
	furniture_uid = uid
	type = t
	main = m
	var info: Dictionary = FurnitureDB.item(type)
	match type:
		"kasa":
			_build_counter()
		"jenerator":
			_build_generator()
		"kamera":
			_build_camera()
		"paspas":
			MeshKit.box(self, Vector3(info.size.x, 0.012, info.size.y), Vector3(0, 0.006, 0), MeshKit.mat(Color(0.2, 0.22, 0.24), 0.95))
		_:
			var sm: Node3D = FurnitureDB.instance_model(type)
			if sm:
				add_child(sm)
			else:
				_build_plant(info)
	if not info.get("walkable", false):
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(info.size.x, info.height, info.size.y)
		cs.shape = shape
		cs.position = Vector3(0, info.height * 0.5, 0)
		body.add_child(cs)
		body.set_meta("interact", self)
		add_child(body)
	else:
		# Üzerinden yürünebilir: sadece etkileşim için ince bir alan (2. katman, yolu kapatmaz)
		var it := Interactable.create(self, Vector3(info.size.x, 0.1, info.size.y), Vector3(0, 0.05, 0), get_prompt, interact)
		it.set_meta("interact", self)


func _prop(id: String) -> Node3D:
	var path := PROPS % id
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate()


## Kasa üstü cihazlar (tezgâha göre yerel konum, Y dönüşü) — mağaza paketinin yerleşiminden
const COUNTER_PROPS := [
	["cash_register_smart", Vector3(0.45, 0.9, -0.1), 180.0],
	["barcode_scanner_smart", Vector3(0.2, 0.9, 0.05), 180.0],
	["payment_terminal_smart", Vector3(0.6, 0.9, 0.25), 0.0],
	["receipt_printer_smart", Vector3(0.75, 0.9, -0.25), 180.0],
]


func _build_counter() -> void:
	var store_counter: Node3D = FurnitureDB.instance_model("kasa")
	if store_counter:
		add_child(store_counter)
		for pr in COUNTER_PROPS:
			var path := FurnitureDB.STORE_MODEL % pr[0]
			if ResourceLoader.exists(path):
				var n: Node3D = (load(path) as PackedScene).instantiate()
				FurnitureDB.hide_collision_meshes(n)
				n.position = pr[1]
				n.rotation_degrees.y = pr[2]
				add_child(n)
		return
	var counter := _prop("kasa_tezgahi")
	if counter:
		# Model 0..2.62 x, -0.66..0.03 z aralığında; ortala. Müşteri yüzü modelde +Z.
		counter.position = Vector3(-1.31, 0, 0.315)
		add_child(counter)
	else:
		MeshKit.box(self, Vector3(2.6, 1.0, 0.7), Vector3(0, 0.5, 0), MeshKit.mat(Color(0.93, 0.92, 0.9), 0.5))


func _build_generator() -> void:
	var yellow := MeshKit.mat(Color(0.95, 0.75, 0.1), 0.45)
	var dark := MeshKit.mat(Color(0.12, 0.12, 0.13), 0.4)
	MeshKit.box(self, Vector3(0.9, 0.55, 0.5), Vector3(0, 0.38, 0), yellow)
	for x in [-0.4, 0.4]:
		for z in [-0.2, 0.2]:
			MeshKit.box(self, Vector3(0.05, 0.12, 0.05), Vector3(x, 0.06, z), dark)
	MeshKit.box(self, Vector3(0.6, 0.06, 0.06), Vector3(0, 0.7, 0.2), dark)
	MeshKit.box(self, Vector3(0.6, 0.06, 0.06), Vector3(0, 0.7, -0.2), dark)
	MeshKit.cylinder(self, 0.05, 0.25, Vector3(0.35, 0.75, 0), dark, 10)
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color(0.1, 0.3, 0.1)
	panel.emission_enabled = true
	panel.emission = Color(0.2, 1.0, 0.3)
	MeshKit.box(self, Vector3(0.15, 0.08, 0.01), Vector3(-0.2, 0.45, 0.255), panel)


func _build_camera() -> void:
	var grey := MeshKit.mat(Color(0.85, 0.85, 0.87), 0.35)
	var dark := MeshKit.mat(Color(0.1, 0.1, 0.11), 0.3)
	MeshKit.cylinder(self, 0.04, 2.3, Vector3(0, 1.15, 0), grey, 10)
	MeshKit.cylinder(self, 0.16, 0.03, Vector3(0, 0.015, 0), grey, 16)
	var head := MeshKit.box(self, Vector3(0.12, 0.1, 0.24), Vector3(0, 2.3, 0.08), grey)
	head.rotation_degrees.x = 15
	MeshKit.cylinder(self, 0.035, 0.02, Vector3(0, 2.27, 0.21), dark, 12).rotation_degrees.x = 90
	var led := StandardMaterial3D.new()
	led.emission_enabled = true
	led.emission = Color(1, 0.1, 0.1)
	led.albedo_color = Color(1, 0.1, 0.1)
	MeshKit.box(self, Vector3(0.015, 0.015, 0.01), Vector3(0.04, 2.33, 0.2), led)


func _build_plant(info: Dictionary) -> void:
	var pot := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.16
	cm.height = 0.45
	pot.mesh = cm
	pot.position = Vector3(0, 0.225, 0)
	pot.material_override = MeshKit.mat(Color(0.85, 0.83, 0.8), 0.6)
	add_child(pot)
	var model := _prop(info.get("model", ""))
	if model:
		var box := AABB()
		var first := true
		for c in model.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
		var k: float = float(info.get("plant_size", 0.7)) / max(box.size.x, box.size.z)
		model.scale = Vector3.ONE * k
		model.position = Vector3(-box.get_center().x * k, 0.43 - box.position.y * k, -box.get_center().z * k)
		add_child(model)


## Kasada sırası gelen müşterinin durduğu yer (yazar kasanın önü)
func register_point() -> Vector3:
	return to_global(Vector3(0.45, 0, 0.8))


## Müşterinin kasada baktığı nokta
func register_face() -> Vector3:
	return to_global(Vector3(0.45, 0, 0))


## Kasiyerin durduğu yer (tezgâhın arkası)
func cashier_point() -> Vector3:
	return to_global(Vector3(0.45, 0, -0.75))


## Sıradaki i. müşterinin yeri: tezgâh boyunca bir çizgi
func queue_point(i: int) -> Vector3:
	return to_global(Vector3(0.45 - 0.75 * (i + 1), 0, 0.85 + 0.12 * (i % 2)))


func get_prompt() -> String:
	if type == "kasa":
		if main and main.customer_at_register():
			return "Kasa: Müşteriyle pazarlık yap"
		return "Kasa tezgâhı (bekleyen müşteri yok)"
	return FurnitureDB.item(type).name


func interact(player: Node) -> void:
	if type == "kasa" and main and main.customer_at_register():
		player.hud.open_register()
	else:
		player.hud.open_furniture(self)
