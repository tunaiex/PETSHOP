@tool
class_name SatisAlani
extends Node3D
## Mağaza sahnesinde oyuncunun eşya koyabildiği ve müşterilerin dolaştığı satış alanı.
## Konumu alanın ortası (zeminde), "boyut" x genişlik / z derinlik. Duvarları taşırsan bunu da uydur.

@export var boyut: Vector2 = Vector2(14.2, 8.2):
	set(v):
		boyut = v
		_ciz()


func _ready() -> void:
	if Engine.is_editor_hint():
		_ciz()


## Dünya koordinatında alan (x, z) — oyun bunu kullanır
func alan() -> Rect2:
	var p: Vector3 = global_position if is_inside_tree() else position
	return Rect2(p.x - boyut.x * 0.5, p.z - boyut.y * 0.5, boyut.x, boyut.y)


func _ciz() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("onizleme"):
			remove_child(c)
			c.queue_free()
	var mi := MeshInstance3D.new()
	mi.set_meta("onizleme", true)
	var pm := PlaneMesh.new()
	pm.size = boyut
	mi.mesh = pm
	mi.position.y = 0.02
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)
