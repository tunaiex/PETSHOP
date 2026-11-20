class_name DeliveryBox
extends Node3D
## Kapıya gelen sipariş kolisi. Oyuncu alıp rafa dizer ya da depoya bırakır.

var data: Dictionary


func setup(d: Dictionary) -> void:
	data = d
	build_mesh(self, d)
	var body := StaticBody3D.new()
	body.collision_layer = 2  # yürümeyi engellemez, sadece bakış ışını görür
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.46, 0.35, 0.4)
	cs.shape = sh
	cs.position = Vector3(0, 0.17, 0)
	body.add_child(cs)
	body.set_meta("interact", self)
	add_child(body)


## Koli görünümü (yerdeki ve eldeki için ortak)
static func build_mesh(parent: Node3D, d: Dictionary) -> void:
	if d.has("species"):
		parent.add_child(AnimalBag.new().setup(str(d.species), int(d.get("n", 1))))
		return
	var card := MeshKit.mat(Color(0.72, 0.55, 0.36), 0.85)
	MeshKit.box(parent, Vector3(0.45, 0.34, 0.38), Vector3(0, 0.17, 0), card)
	MeshKit.box(parent, Vector3(0.452, 0.012, 0.06), Vector3(0, 0.341, 0), MeshKit.mat(Color(0.85, 0.75, 0.5), 0.4))
	var p: Dictionary = ProductDB.get_product(d.get("pid", ""))
	if not p.is_empty():
		MeshKit.box(parent, Vector3(0.16, 0.1, 0.004), Vector3(0.1, 0.2, 0.191), MeshKit.mat(p.color, 0.5))
		var l := Label3D.new()
		l.text = "%s\n×%d" % [p.name, int(d.n)]
		l.font_size = 26
		l.pixel_size = 0.0011
		l.modulate = Color(0.1, 0.08, 0.06)
		l.outline_size = 0
		l.position = Vector3(-0.08, 0.2, 0.192)
		parent.add_child(l)


func get_prompt() -> String:
	if data.has("species"):
		return "Kargo: %s ×%d (%s) — al" % [FishDB.display_name(data.species), int(data.n), "poşet" if AnimalBag.is_bag_species(data.species) else "taşıma kutusu"]
	var p: Dictionary = ProductDB.get_product(data.pid)
	return "Koli: %s ×%d (al)" % [p.get("name", "?"), int(data.n)]


func interact(_player: Node) -> void:
	if data.has("species") and Game.pick_box(int(data.uid)):
		Game.notify.emit("Canlıları aldın. Uygun bir %s bakıp ETKİLEŞ: içine bırak." % FishDB.habitat_name(FishDB.habitat(data.species)), "info")
	elif Game.pick_box(int(data.uid)):
		Game.notify.emit("Koliyi aldın. Bir rafa bakıp ETKİLEŞ: rafa diz. Ya da DEPOYA KOY.", "info")
