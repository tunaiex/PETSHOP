extends Node2D
## Az sayida cember: shader, parcacik sistemi veya asiri animasyon yok.
const ADET := 11
var baloncuklar: Array[Vector3] = []

func _ready() -> void:
	for sira in range(ADET):
		baloncuklar.append(Vector3(
			randf_range(324.0, 371.0),
			randf_range(60.0, 395.0),
			randf_range(2.0, 6.0)
		))

func _process(delta: float) -> void:
	if not bool(get_parent().get("isik_acik")):
		return
	for sira in range(baloncuklar.size()):
		var b: Vector3 = baloncuklar[sira]
		b.y -= delta * (10.0 + b.z * 3.0)
		b.x += sin(b.y * 0.05 + float(sira)) * delta * 2.0
		if b.y < 69.0:
			b.y = randf_range(345.0, 406.0)
			b.x = randf_range(326.0, 371.0)
		baloncuklar[sira] = b
	queue_redraw()

func _draw() -> void:
	for b in baloncuklar:
		draw_arc(Vector2(b.x,b.y), b.z, 0.0, TAU, 12, Color(0.7,0.98,1.0,0.34), 1.05, true)
		draw_circle(Vector2(b.x-b.z*0.27,b.y-b.z*0.28), 0.9, Color(1.0,1.0,1.0,0.37))
