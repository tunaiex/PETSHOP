extends Node2D
## Dokunulan noktaya yem birakir. Balik ulasinca ana betik yemi gizler.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(0.43,0.21,0.09))
	draw_circle(Vector2(-2.0,-1.6), 2.0, Color(0.96,0.62,0.27))
	draw_circle(Vector2(5.0,4.0), 2.2, Color(0.78,0.41,0.18))
