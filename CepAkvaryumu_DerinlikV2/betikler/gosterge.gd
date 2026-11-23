extends Node2D
## En son katmanda hem gece karartmasi hem acik yazi yerine yay gosterir.
const MERKEZ := Vector2(240.0, 240.0)
@onready var akvaryum: Node = get_parent()

func _draw() -> void:
	if not bool(akvaryum.get("isik_acik")):
		draw_circle(MERKEZ, 229.0, Color(0.0, 0.02, 0.07, 0.75))
	# Saat cercevesinin solunda tokluk gostergesi, draw_arc() ile.
	var baslangic := deg_to_rad(145.0)
	var bitis := deg_to_rad(215.0)
	draw_arc(MERKEZ, 214.0, baslangic, bitis, 32, Color(0.01, 0.07, 0.11, 0.76), 13.0, true)
	draw_arc(MERKEZ, 214.0, baslangic, lerpf(baslangic, bitis, float(akvaryum.get("aclik")) / 100.0), 32, Color(1.0, 0.43, 0.04), 9.0, true)
	# Sag alt ya da kenarlarda yazi kullanmiyoruz; merkez oyuncak gibi kalmiyor.
	# Minik isik sembolu: basma alani degil, uzun basmaya gorsel ipucu.
	draw_circle(Vector2(240.0, 56.0), 18.0, Color(0.0, 0.08, 0.12, 0.50))
	var renk := Color(1.0, 0.83, 0.35) if bool(akvaryum.get("isik_acik")) else Color(0.45, 0.57, 0.66)
	draw_arc(Vector2(240.0, 53.0), 6.0, PI, TAU, 12, renk, 2.4, true)
	draw_line(Vector2(236.0, 60.0), Vector2(244.0, 60.0), renk, 2.2, true)
	for yon in [Vector2(0,-12),Vector2(-12,0),Vector2(12,0)]:
		draw_line(Vector2(240,53) + yon * 0.75, Vector2(240,53)+yon,renk,1.6,true)
