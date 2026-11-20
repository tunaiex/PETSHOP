@tool
class_name EsyaYeri
extends Node3D
## Mağaza sahnesinde (scenes/magaza.tscn) hazır gelen bir eşyanın yeri.
## Yeni oyunda bu konumda ve bu yönde "tip" eşyası kurulu (ve boş) gelir; oyuncu sonra taşıyabilir.
## Editörde modelin önizlemesi görünür. Taşı, döndür (sadece Y ekseni), çoğalt, sil: hepsi serbest.
## Not: "Esyalar" düğümünü taşıma/döndürme; eşyaları tek tek düzenle.

@export var tip: String = "":
	set(v):
		tip = v
		_onizle()


func _validate_property(property: Dictionary) -> void:
	if property.name == "tip":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PackedStringArray(FurnitureDB.ITEMS.keys().filter(func(k): return not FurnitureDB.ITEMS[k].get("hidden", false))))


func _ready() -> void:
	if Engine.is_editor_hint():
		_onizle()
	else:
		# Oyunda sadece işaret: eşyanın kendisini Game kurar
		visible = false


func _onizle() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("onizleme"):
			remove_child(c)
			c.queue_free()
	var info: Dictionary = FurnitureDB.item(tip)
	if info.is_empty():
		return
	var m: Node3D = FurnitureDB.instance_model(tip)
	if m == null and info.has("product_model"):
		m = ProductDB.instance_path(info.product_model, str(info.get("part", "")), float(info.get("model_h", 1.0)))
	if m == null:
		# Modeli olmayan eşyalar (akvaryum, kafes...): kaplama alanı kadar yarı saydam kutu
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz: Vector2 = info.get("size", Vector2.ONE)
		bm.size = Vector3(sz.x, float(info.get("height", 1.0)), sz.y)
		mi.mesh = bm
		mi.position.y = bm.size.y * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.8, 1.0, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		m = mi
	m.set_meta("onizleme", true)
	add_child(m)   # sahibi yok: sahneye kaydedilmez
	# Ön yüz oku (müşteri tarafı +Z)
	var lbl := Label3D.new()
	lbl.set_meta("onizleme", true)
	lbl.text = "%s ▼ ön" % info.get("name", tip)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 48
	lbl.pixel_size = 0.004
	lbl.position = Vector3(0, float(info.get("height", 1.0)) + 0.25, 0)
	add_child(lbl)
