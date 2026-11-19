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
		"paspas":
			MeshKit.box(self, Vector3(info.size.x, 0.012, info.size.y), Vector3(0, 0.006, 0), MeshKit.mat(Color(0.2, 0.22, 0.24), 0.95))
		_:
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


func _build_counter() -> void:
	var counter := _prop("kasa_tezgahi")
	if counter:
		# Model 0..2.62 x, -0.66..0.03 z aralığında; ortala. Müşteri yüzü modelde +Z.
		counter.position = Vector3(-1.31, 0, 0.315)
		add_child(counter)
	else:
		MeshKit.box(self, Vector3(2.6, 1.0, 0.7), Vector3(0, 0.5, 0), MeshKit.mat(Color(0.93, 0.92, 0.9), 0.5))


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
	return to_global(Vector3(-0.5, 0, 1.05))


## Sıradaki i. müşterinin yeri: kasadan dışarı doğru bir çizgi
func queue_point(i: int) -> Vector3:
	return to_global(Vector3(-0.5 + 0.35 * (i % 2), 0, 1.05 + 0.85 * (i + 1)))


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
