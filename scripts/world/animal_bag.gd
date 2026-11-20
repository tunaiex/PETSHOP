class_name AnimalBag
extends Node3D
## Canlı taşıma: balıklar su dolu şeffaf poşette (içinde o türün balıkları döner),
## kaplumbağa / örümcek / hamster / civciv havalandırma delikli taşıma kutusunda.
## Kargo kolisinde, oyuncunun elinde, müşterinin elinde ve kasa tezgâhında aynı görünüm.
## Kök noktası poşetin/kutunun tabanıdır.

const BAG_MODEL := "res://assets/models/props/balik_posedi.glb"
const BAG_HEIGHT := 0.3   ## poşetin gerçek boyu (m)

var species: String = ""
var _fish: Array = []      ## [düğüm, açı, yarıçap, yükseklik, hız]
var _t: float = 0.0


static func is_bag_species(sp: String) -> bool:
	return FishDB.habitat(sp) == "su"


func setup(sp: String, count: int = 1) -> AnimalBag:
	species = sp
	if is_bag_species(sp):
		_build_bag(clamp(count, 1, 4))
	else:
		_build_carrier(count)
	return self


## Boyu (m). Elde tutma ve tezgâha koyma hesapları için.
func height() -> float:
	return BAG_HEIGHT if is_bag_species(species) else 0.2


func _build_bag(count: int) -> void:
	var water_y := 0.09
	var water_r := 0.07
	if ResourceLoader.exists(BAG_MODEL):
		var m: Node3D = (load(BAG_MODEL) as PackedScene).instantiate()
		# Modelin içindeki hazır balığı gizle: yerine satılan tür konacak
		for c in m.find_children("*", "MeshInstance3D", true, false):
			if c.name.begins_with("Fish"):
				c.visible = false
			else:
				(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for ap in m.find_children("*", "AnimationPlayer", true, false):
			ap.queue_free()
		var box: AABB = MeshKit.model_aabb(m)
		var k: float = BAG_HEIGHT / max(box.size.y, 0.001)
		m.scale = Vector3.ONE * k
		m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
		add_child(m)
		water_y = BAG_HEIGHT * 0.3
		water_r = min(box.size.x, box.size.z) * k * 0.22
	else:
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.7, 0.85, 1.0, 0.35)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.18
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = water
		mi.position.y = 0.09
		add_child(mi)
	var t: Dictionary = Fish._model_template(species)
	var data: Dictionary = FishDB.get_species(species)
	for i in count:
		var n := Node3D.new()
		add_child(n)
		var vis: MeshInstance3D = MeshInstance3D.new()
		if not t.is_empty():
			vis.mesh = t.mesh
			vis.transform = t.xf
			var mat: ShaderMaterial = t.mat.duplicate()
			mat.set_shader_parameter("swim", 1.0)
			mat.set_shader_parameter("health", 1.0)
			vis.material_override = mat
		else:
			vis.mesh = MeshKit.fish_mesh(species)
			vis.material_override = MeshKit.mat(data.get("accent", Color(1, 0.5, 0.2)), 0.4)
		vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(vis)
		# Poşete sığsın: en fazla 7 cm görünsün
		n.scale = Vector3.ONE * min(1.0, 0.07 / max(float(data.get("length", 0.07)), 0.01))
		_fish.append([n, TAU * i / count, water_r * (0.6 + 0.15 * i), water_y + 0.012 * (i % 2), 1.4 + 0.25 * i])


## Taşıma kutusu: karton, havalandırma delikleri, ön yüzde tür adı.
func _build_carrier(count: int) -> void:
	var card := MeshKit.mat(Color(0.78, 0.62, 0.42), 0.85)
	var w := 0.26
	var h := 0.18
	var d := 0.18
	MeshKit.box(self, Vector3(w, h, d), Vector3(0, h * 0.5, 0), card)
	# Sap
	var handle := MeshKit.mat(Color(0.7, 0.55, 0.36), 0.8)
	MeshKit.box(self, Vector3(0.012, 0.06, d * 0.6), Vector3(-0.05, h + 0.03, 0), handle)
	MeshKit.box(self, Vector3(0.012, 0.06, d * 0.6), Vector3(0.05, h + 0.03, 0), handle)
	MeshKit.box(self, Vector3(0.11, 0.012, d * 0.6), Vector3(0, h + 0.06, 0), handle)
	# Hava delikleri
	var hole := MeshKit.mat(Color(0.12, 0.08, 0.05), 0.9)
	for side in [-1.0, 1.0]:
		for i in 3:
			for j in 2:
				var c := MeshKit.cylinder(self, 0.008, 0.004, Vector3(side * (w * 0.5 + 0.001), 0.06 + j * 0.05, -0.04 + i * 0.04), hole, 8)
				c.rotation_degrees.z = 90
	var l := Label3D.new()
	l.text = "CANLI HAYVAN\n%s ×%d" % [FishDB.display_name(species), count]
	l.font_size = 22
	l.pixel_size = 0.0009
	l.modulate = Color(0.15, 0.1, 0.05)
	l.outline_size = 0
	l.position = Vector3(0, h * 0.55, d * 0.5 + 0.002)
	add_child(l)
	var arrow := Label3D.new()
	arrow.text = "↑ ↑"
	arrow.font_size = 28
	arrow.pixel_size = 0.001
	arrow.modulate = Color(0.75, 0.1, 0.1)
	arrow.outline_size = 0
	arrow.position = Vector3(w * 0.32, h * 0.8, d * 0.5 + 0.002)
	add_child(arrow)


func _process(delta: float) -> void:
	if _fish.is_empty() or not is_visible_in_tree():
		return
	_t += delta
	for f in _fish:
		var n: Node3D = f[0]
		var a: float = f[1] + _t * f[4]
		n.position = Vector3(cos(a) * f[2], f[3] + sin(_t * 2.0 + f[1]) * 0.006, sin(a) * f[2])
		# Dairenin teğeti yönünde yüz (balık -Z'ye bakar)
		var tangent := Vector3(-sin(a), 0, cos(a))
		n.basis = Basis.looking_at(tangent, Vector3.UP).scaled(Vector3.ONE * n.scale.x)
