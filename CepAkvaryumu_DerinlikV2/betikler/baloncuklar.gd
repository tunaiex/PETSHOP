extends Node2D
## Gercekci hava kabarciklari (parcacik sistemi yok, tek doku, az sayida).
## - Sag kayanin dibinden ince bir hava akisi (cogu kabarcik buradan)
## - Bitki yapraklarindan ara ara yukselen kucuk oksijen kabarciklari
## Buyuk kabarcik daha hizli yukselir ve daha cok yalpalar; yuzeye
## varinca soner. Bilek donusunden gelen su akintisi hafifce yana iter.
## Adet grafik profiline gore (Dusuk 6 / Dengeli 9 / Yuksek 11).

const DOKU := preload("res://gorseller/kabarcik.png")
const YUZEY_Y := 92.0
const AKIS_KAYNAGI := Vector2(352.0, 318.0)   # sag kayanin arkasi
# Bitkilerden oksijen kabarcigi cikabilecek yerler (yaprak uclari civari)
const BITKI_NOKTALARI := [Vector2(70, 200), Vector2(118, 165), Vector2(165, 230),
	Vector2(300, 190), Vector2(372, 175), Vector2(420, 215), Vector2(230, 255)]

# Her kabarcik: p konum, r yaricap, v yukselme hizi, f yalpalama fazi, a omur
var kabarciklar: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_adedi_ayarla()
	Ayarlar.profil_degisti.connect(_adedi_ayarla)


func _adedi_ayarla() -> void:
	var adet: int = Ayarlar.deger("baloncuk")
	while kabarciklar.size() > adet:
		kabarciklar.pop_back()
	while kabarciklar.size() < adet:
		var k := _yeni()
		# Baslangicta su kolonuna dagit (hepsi ayni anda dipten cikmasin)
		k["p"].y = rng.randf_range(YUZEY_Y + 10.0, k["p"].y)
		kabarciklar.append(k)


func _yeni() -> Dictionary:
	var p: Vector2
	var r: float
	if rng.randf() < 0.7:
		# Hava akisi: ayni noktadan, cesitli boyutta
		p = AKIS_KAYNAGI + Vector2(rng.randf_range(-3.0, 3.0), 0.0)
		r = rng.randf_range(1.3, 3.6)
	else:
		# Bitkiden kopan minik oksijen kabarcigi
		p = BITKI_NOKTALARI[rng.randi() % BITKI_NOKTALARI.size()] + Vector2(rng.randf_range(-12, 12), rng.randf_range(-10, 10))
		r = rng.randf_range(0.9, 1.7)
	return {
		"p": p,
		"r": r,
		"v": 18.0 + r * 11.0,                 # buyuk kabarcik daha hizli
		"f": rng.randf() * TAU,
		"y": 0.6 + r * 0.45,                  # yalpalama genligi (px)
		"a": 0.0,                             # dogarken yavasca belirir
	}


func _process(delta: float) -> void:
	var akvaryum := get_parent()
	if not bool(akvaryum.get("isik_acik")) or not bool(akvaryum.get("odakta")):
		return
	var akinti: float = akvaryum.get("su_akintisi")
	for i in kabarciklar.size():
		var k: Dictionary = kabarciklar[i]
		k["f"] += delta * (5.0 + k["r"])
		k["p"].y -= delta * k["v"]
		k["p"].x += cos(k["f"]) * k["y"] * delta * 6.0 + akinti * delta * 25.0
		k["a"] = minf(1.0, k["a"] + delta * 3.0)
		# Yuzeye yaklasinca soner ve yeniden dogar
		if k["p"].y < YUZEY_Y:
			kabarciklar[i] = _yeni()
	queue_redraw()


func _draw() -> void:
	for k in kabarciklar:
		var r: float = k["r"]
		# Yuzeye yakin son 30 px'te sonumlenme
		var son := clampf((k["p"].y - YUZEY_Y) / 30.0, 0.0, 1.0)
		var renk := Color(1, 1, 1, 0.85 * k["a"] * son)
		# Yalpalarken hafif yassilasma (gercek kabarciklar gibi)
		var yass := 1.0 + sin(k["f"] * 2.0) * 0.08 * clampf(r / 3.0, 0.0, 1.0)
		var boyut := Vector2(r * 2.0 * yass, r * 2.0 / yass)
		draw_texture_rect(DOKU, Rect2(k["p"] - boyut * 0.5, boyut), false, renk)
