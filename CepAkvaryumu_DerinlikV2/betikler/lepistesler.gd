extends Node2D
## Lepistes (guppy) surusu: bettanin akvaryum arkadaslari. Magazadan incilerle
## alinir (en fazla 4). Her biri kendi renk tonunda ve boyunda; gevsek bir suru
## halinde gezinir, yem dusunce toplanir, gece bitkilerin dibinde dinlenir.
## Betta yakinlarina gelen lepistese ara ara kabarir (gercek betta davranisi).
## Her lepistes suyu biraz daha hizli kirletir (biyolojik yuk).

const EN_FAZLA := 4
const LEP3D := preload("res://betikler/lepistes_3d.gd")
const BALIK_SHADER := preload("res://golgeler/balik.gdshader")
const DERINLIK_PIKSEL := 260.0
const REFERANS := 80.0          # dahili boyut referansi (piksel)
# Profil -> dahili cozunurluk
const BOYUTLAR := [64, 80, 112]

@onready var akvaryum: Node = get_parent()

# Her lepistes: {ton, boy, konum: Vector3, hedef: Vector3, yon: Vector3, sapma, egim,
#                hiz, bekle, vp: SubViewport, sprite: Sprite2D}
var suru: Array[Dictionary] = []
var suru_merkezi := Vector3(40.0, -20.0, 0.5)
var merkez_hedefi := Vector3(40.0, -20.0, 0.5)
var kabarma_beklemesi := 30.0


func _ready() -> void:
	Ayarlar.profil_degisti.connect(_profili_uygula)


func ekle(ton := INF, boy := -1.0) -> void:
	if suru.size() >= EN_FAZLA:
		return
	if ton == INF:
		ton = randf_range(-0.5, 0.5)
	if boy < 0.0:
		boy = randf_range(0.85, 1.1)
	var vp: SubViewport = LEP3D.new()
	add_child(vp)
	vp.boyut_ayarla(BOYUTLAR[Ayarlar.profil])
	var sp := Sprite2D.new()
	sp.texture = vp.get_texture()
	var m := ShaderMaterial.new()
	m.shader = BALIK_SHADER
	m.set_shader_parameter("ton", ton)
	m.set_shader_parameter("doygunluk", 1.1)
	sp.material = m
	add_child(sp)
	var k: Vector3 = akvaryum._sinirla(suru_merkezi + Vector3(randf_range(-40, 40), randf_range(-30, 30), randf_range(-0.2, 0.2)))
	suru.append({"ton": ton, "boy": boy, "konum": k, "hedef": k, "yon": Vector3(-1, 0, 0),
		"sapma": PI, "egim": 0.0, "hiz": 0.0, "bekle": 0.0, "vp": vp, "sprite": sp})
	_bakima_bildir()


func _profili_uygula() -> void:
	for l in suru:
		l["vp"].boyut_ayarla(BOYUTLAR[Ayarlar.profil])


func _bakima_bildir() -> void:
	akvaryum.bakim.lepistes_sayisi = suru.size()


func etkinlestir(acik: bool) -> void:
	for l in suru:
		l["vp"].etkinlestir(acik)


func kare(delta: float, isik_acik: bool, uyku_noktasi: Vector3) -> void:
	if suru.is_empty():
		return
	kabarma_beklemesi = maxf(0.0, kabarma_beklemesi - delta)
	# Suru merkezi yavasca gezinir; yem varsa yeme, gece bitkilere
	if not isik_acik:
		merkez_hedefi = uyku_noktasi + Vector3(30.0, 5.0, 0.1)
	elif akvaryum.yem_var:
		merkez_hedefi = akvaryum.yem_hedefi
	elif suru_merkezi.distance_to(merkez_hedefi) < 15.0 or randf() < delta * 0.05:
		merkez_hedefi = akvaryum._sinirla(Vector3(randf_range(-110, 110), randf_range(-70, 60), randf_range(0.2, 0.85)))
	var fark := merkez_hedefi - suru_merkezi
	fark.z *= DERINLIK_PIKSEL
	if fark.length() > 1.0:
		var adim := fark.normalized() * minf(fark.length(), 18.0 * delta)
		suru_merkezi += Vector3(adim.x, adim.y, adim.z / DERINLIK_PIKSEL)

	var betta: Vector3 = akvaryum.balik_konumu
	for i in suru.size():
		var l: Dictionary = suru[i]
		_hareket(l, i, delta, isik_acik, betta)
		_gorsellestir(l)
		l["vp"].guncelle(l["yon"], l["hiz"], delta, not isik_acik)


func _hareket(l: Dictionary, i: int, delta: float, isik_acik: bool, betta: Vector3) -> void:
	l["bekle"] = maxf(0.0, l["bekle"] - delta)
	var k: Vector3 = l["konum"]
	# Yeni kisisel hedef: suru merkezi etrafinda, birbirinden uzak
	var hk: Vector3 = l["hedef"]
	if (l["bekle"] <= 0.0 and Vector2(k.x - hk.x, k.y - hk.y).length() < 12.0) or randf() < delta * 0.15:
		var yay := 45.0 if isik_acik else 20.0
		l["hedef"] = akvaryum._sinirla(suru_merkezi + Vector3(randf_range(-yay, yay), randf_range(-yay * 0.6, yay * 0.6), randf_range(-0.15, 0.15)))
		l["bekle"] = randf_range(0.2, 1.2)
	var hedef: Vector3 = l["hedef"]
	# Ayrisma: diger lepisteslere cok yaklasma
	for j in suru.size():
		if j == i:
			continue
		var o: Vector3 = suru[j]["konum"]
		var dd := Vector2(k.x - o.x, k.y - o.y)
		if dd.length() < 22.0 and absf(k.z - o.z) < 0.15:
			hedef += Vector3(dd.x, dd.y, 0.0).normalized() * 25.0
	# Bettadan kac (yakindaysa); bazen betta kabarir
	var bd := Vector2(k.x - betta.x, k.y - betta.y)
	if bd.length() < 45.0 and absf(k.z - betta.z) < 0.25:
		hedef += Vector3(bd.x, bd.y, 0.0).normalized() * 60.0
		if kabarma_beklemesi <= 0.0 and isik_acik and akvaryum.balik.visible and not akvaryum.yem_var:
			kabarma_beklemesi = randf_range(45.0, 90.0)
			akvaryum._kabar(2.0)
	hedef = akvaryum._sinirla(hedef)

	var f := hedef - k
	f.z *= DERINLIK_PIKSEL
	var mesafe := f.length()
	if mesafe < 3.0:
		l["hiz"] = lerpf(l["hiz"], 0.0, minf(1.0, delta * 3.0))
		return
	var hedef_sapma := atan2(f.z, f.x)
	var hedef_egim := clampf(atan2(f.y, Vector2(f.x, f.z).length()), -0.5, 0.5)
	var maks := 3.2 * delta
	l["sapma"] = wrapf(l["sapma"] + clampf(wrapf(hedef_sapma - l["sapma"], -PI, PI), -maks, maks), -PI, PI)
	l["egim"] += clampf(hedef_egim - l["egim"], -maks * 0.7, maks * 0.7)
	var yon := Vector3(cos(l["egim"]) * cos(l["sapma"]), sin(l["egim"]), cos(l["egim"]) * sin(l["sapma"]))
	l["yon"] = yon
	var hiz := 40.0 if isik_acik else 10.0
	if akvaryum.yem_var:
		hiz = 60.0
	hiz *= clampf(yon.dot(f / mesafe), 0.15, 1.0)
	var yol := minf(mesafe, hiz * delta)
	l["konum"] = akvaryum._sinirla(k + Vector3(yon.x, yon.y, yon.z / DERINLIK_PIKSEL) * yol)
	l["hiz"] = yol / maxf(delta, 0.001)


func _gorsellestir(l: Dictionary) -> void:
	var k: Vector3 = l["konum"]
	var sp: Sprite2D = l["sprite"]
	var derinlik := k.z
	var p: Vector2 = akvaryum.paralaks * akvaryum.PARALAKS_PX * lerpf(0.95, 0.4, derinlik)
	sp.position = Vector2(240.0 + k.x, 240.0 + k.y - derinlik * 14.0) + p
	var boyut: float = lerpf(0.70, 0.45, derinlik) * l["boy"] * l["vp"].olcek_carpani(REFERANS)
	sp.scale = Vector2(boyut, boyut)
	var soluk := lerpf(1.0, 0.77, derinlik)
	sp.modulate = Color(soluk * 0.91, soluk * 0.98, 1.0, 1.0)
	sp.z_index = 0 if derinlik > 0.64 else (3 if derinlik > 0.33 else 7)


func sozluk() -> Array:
	var a := []
	for l in suru:
		a.append([l["ton"], l["boy"]])
	return a


func yukle(a: Array) -> void:
	for e in a:
		if e is Array and e.size() == 2:
			ekle(float(e[0]), float(e[1]))
