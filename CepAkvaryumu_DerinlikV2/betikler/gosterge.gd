extends Node2D
## En son katmanda hem gece karartmasi hem acik yazi yerine yay gosterir.
## Guvenli bolge: tum gostergeler merkezden en fazla ~221 px uzakta (yuvarlak
## ekranin kenarindan >=19 px iceride); 438x438 saatte orantili kuculur.
const MERKEZ := Vector2(240.0, 240.0)
@onready var akvaryum: Node = get_parent()

func _draw() -> void:
	if not bool(akvaryum.get("isik_acik")):
		draw_circle(MERKEZ, 241.0, Color(0.0, 0.02, 0.07, 0.75))
	# Saat cercevesinin solunda tokluk gostergesi, draw_arc() ile.
	var baslangic := deg_to_rad(145.0)
	var bitis := deg_to_rad(215.0)
	draw_arc(MERKEZ, 214.0, baslangic, bitis, 32, Color(0.01, 0.07, 0.11, 0.76), 13.0, true)
	draw_arc(MERKEZ, 214.0, baslangic, lerpf(baslangic, bitis, float(akvaryum.get("aclik")) / 100.0), 32, Color(1.0, 0.43, 0.04), 9.0, true)
	# Sagda su kalitesi (ayna simetrik, mavi). Kirlendikce sari-yesile doner.
	var bakim: Node = akvaryum.get_node("Bakim")
	var su: float = bakim.su_gorunen / 100.0
	var sag_bas := deg_to_rad(35.0)
	var sag_bit := deg_to_rad(-35.0)
	draw_arc(MERKEZ, 214.0, sag_bas, sag_bit, 32, Color(0.01, 0.07, 0.11, 0.76), 13.0, true)
	var su_renk := Color(0.75, 0.78, 0.2).lerp(Color(0.25, 0.85, 1.0), clampf((su - 0.3) / 0.5, 0.0, 1.0))
	if su > 0.005:
		draw_arc(MERKEZ, 214.0, sag_bas, lerpf(sag_bas, sag_bit, su), 32, su_renk, 9.0, true)
	# Su degisimi ilerlemesi: kenarda donen ince halka
	var ilerleme: float = akvaryum.get("su_degisim_ilerleme")
	if ilerleme > 0.01:
		draw_arc(MERKEZ, 229.0, -PI / 2.0, -PI / 2.0 + TAU * ilerleme, 64, Color(0.45, 0.9, 1.0, 0.9), 5.0, true)
	# Sag alt ya da kenarlarda yazi kullanmiyoruz; merkez oyuncak gibi kalmiyor.
	# Minik isik sembolu: basma alani degil, uzun basmaya gorsel ipucu.
	draw_circle(Vector2(240.0, 56.0), 18.0, Color(0.0, 0.08, 0.12, 0.50))
	var renk := Color(1.0, 0.83, 0.35) if bool(akvaryum.get("isik_acik")) else Color(0.45, 0.57, 0.66)
	draw_arc(Vector2(240.0, 53.0), 6.0, PI, TAU, 12, renk, 2.4, true)
	draw_line(Vector2(236.0, 60.0), Vector2(244.0, 60.0), renk, 2.2, true)
	for yon in [Vector2(0,-12),Vector2(-12,0),Vector2(12,0)]:
		draw_line(Vector2(240,53) + yon * 0.75, Vector2(240,53)+yon,renk,1.6,true)
