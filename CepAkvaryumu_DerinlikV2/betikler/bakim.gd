extends Node
## Akvaryum bakimi: cam yosunu, su kalitesi, artan yem, mutluluk, kopuk yuvasi.
## Tum degerler gercek zamanla ilerler (uygulama kapaliyken de); ana betik
## her saniye ve acilista gecen sureyi zamani_ilerlet() ile verir.
##
## Cizim, z_index'leri farkli dort kucuk Node2D ile yapilir (bakim_cizim.gd):
##   Yuva (yuzeyde kopuk yuvasi), Artiklar (dipteki yem), SuRengi (bulaniklik),
##   CamYosunu (en onde, camin ustunde).

signal cam_parladi        # kirli cam tamamen temizlendi
signal degisti            # cizimlerin yenilenmesi gerekiyor

const MERKEZ := Vector2(240.0, 240.0)
const SAAT := 3600.0

# --- Ayarlar (oyun dengesi) ---
const SU_BITIS_SAAT := 48.0          # temiz su 48 saatte tamamen kirlenir
const ARTIK_KIRLETME_SAAT := 6.0     # dipteki her yem tanesi saatte 6 puan kirletir
const ARTIK_OMUR_SAAT := 3.0         # dipteki yem 3 saatte cozunur
const ARTIK_EN_FAZLA := 6
const YOSUN_LEKE := 12
const YUVA_BUYUME_SAAT := 6.0        # mutluyken yuva 6 saatte tamamlanir
const YUVA_SONME_SAAT := 3.0         # mutsuzken 3 saatte kaybolur
const MUTLULUK_ZAMAN_SABITI := 1800.0  # mutluluk hedefe ~30 dk'da yaklasir

var su := 85.0                       # 100 = berrak, 0 = cok kirli
var su_gorunen := 85.0               # su degisiminde yumusak gecis icin
var gecis := false
var cam_kirliydi := false            # cam bir kez belirgin kirlendiyse true
var yuva := 0.0                      # 0..1 kopuk yuvasi buyuklugu
var mutluluk := 70.0                 # 0..100
var lekeler: Array[Dictionary] = []  # {p: Vector2, r: float, l: 0..1, h: buyume/sn, t: tohum}
var artiklar: Array[Dictionary] = [] # {p: Vector2 (ekran), dip: float, yas: sn}


func _ready() -> void:
	if lekeler.is_empty():
		for i in YOSUN_LEKE:
			lekeler.append(_yeni_leke(randf_range(0.0, 0.2)))


func _yeni_leke(seviye: float) -> Dictionary:
	# Cam kenarlarina yakin yerlerde daha cok yosun olur.
	var aci := randf() * TAU
	var uzaklik := sqrt(randf_range(0.15, 1.0)) * 185.0
	return {
		"p": MERKEZ + Vector2.from_angle(aci) * uzaklik,
		"r": randf_range(16.0, 38.0),
		"l": seviye,
		"h": 1.0 / (randf_range(8.0, 20.0) * SAAT),
		"t": randi() % 100000,
	}


# ---------------------------------------------------------------- zaman

## Gecen gercek sure (saniye). Bir saniyelik adimlar da, saatlerce kapali
## kalma da ayni formullerle hesaplanir.
func zamani_ilerlet(saniye: float, tokluk: float) -> void:
	if saniye <= 0.0:
		return
	# Dipteki yemler suyu kirletir, zamanla cozunur.
	var artik_kiri := 0.0
	for a in artiklar:
		var kalan := maxf(0.0, ARTIK_OMUR_SAAT * SAAT - a["yas"])
		artik_kiri += minf(saniye, kalan) * ARTIK_KIRLETME_SAAT / SAAT
		a["yas"] += saniye
	artiklar = artiklar.filter(func(a): return a["yas"] < ARTIK_OMUR_SAAT * SAAT)
	su = clampf(su - saniye * 100.0 / (SU_BITIS_SAAT * SAAT) - artik_kiri, 0.0, 100.0)
	if not gecis:
		su_gorunen = su

	# Yosun: kirli suda daha hizli buyur.
	var hiz_carpani := lerpf(1.7, 1.0, su / 100.0)
	for leke in lekeler:
		leke["l"] = minf(1.0, leke["l"] + saniye * leke["h"] * hiz_carpani)
	if cam_temizligi() < 0.85:
		cam_kirliydi = true

	# Mutluluk hedefe yavasca yaklasir.
	var hedef := mutluluk_hedefi(tokluk)
	mutluluk = lerpf(mutluluk, hedef, 1.0 - exp(-saniye / MUTLULUK_ZAMAN_SABITI))

	# Kopuk yuvasi: mutluyken buyur, mutsuzken soner.
	if mutluluk >= 75.0:
		yuva = minf(1.0, yuva + saniye / (YUVA_BUYUME_SAAT * SAAT))
	elif mutluluk < 50.0:
		yuva = maxf(0.0, yuva - saniye / (YUVA_SONME_SAAT * SAAT))
	degisti.emit()


func mutluluk_hedefi(tokluk: float) -> float:
	var h := 0.40 * tokluk + 0.35 * su + 0.25 * cam_temizligi() * 100.0
	if tokluk < 15.0:
		h = minf(h, 30.0)  # cok acken baska hicbir sey mutlu etmez
	return clampf(h, 0.0, 100.0)


func cam_temizligi() -> float:
	var toplam := 0.0
	for leke in lekeler:
		toplam += leke["l"]
	return 1.0 - toplam / float(lekeler.size())


## Balik ne kadar istekli yuzer (mutsuz balik yavas ve durgundur).
func hiz_carpani() -> float:
	return lerpf(0.6, 1.0, clampf(mutluluk / 70.0, 0.0, 1.0))


# ---------------------------------------------------------------- eylemler

## Parmagin gectigi yol (ekran koordinati). Silinen leke sayisini dondurur.
func cami_sil(noktalar: PackedVector2Array) -> int:
	if noktalar.size() < 2:
		return 0
	if cam_temizligi() < 0.85:
		cam_kirliydi = true
	var biten := 0
	for i in lekeler.size():
		var leke: Dictionary = lekeler[i]
		if leke["l"] <= 0.0:
			continue
		var en_yakin := INF
		for j in range(1, noktalar.size()):
			var q := Geometry2D.get_closest_point_to_segment(leke["p"], noktalar[j - 1], noktalar[j])
			en_yakin = minf(en_yakin, q.distance_to(leke["p"]))
		if en_yakin < leke["r"] + 22.0:
			leke["l"] = maxf(0.0, leke["l"] - 0.55)
			if leke["l"] <= 0.0:
				lekeler[i] = _yeni_leke(0.0)  # baska yerde sifirdan buyumeye baslar
				biten += 1
	if cam_kirliydi and cam_temizligi() >= 0.97:
		cam_kirliydi = false
		cam_parladi.emit()
	degisti.emit()
	return biten


## Balik tokken atilan yem dibe coker.
func artik_ekle(ekran_konumu: Vector2) -> void:
	if artiklar.size() >= ARTIK_EN_FAZLA:
		artiklar.pop_front()
	var dip := randf_range(398.0, 418.0)
	var x := clampf(ekran_konumu.x, 150.0, 400.0)
	artiklar.append({"p": Vector2(x, ekran_konumu.y), "dip": dip, "yas": 0.0})
	degisti.emit()


## Su degisimi: berrak su, dipteki yemler alinir. Yosun camda kalir.
func su_degistir() -> void:
	su = 100.0
	artiklar.clear()
	gecis = true
	var tw := create_tween()
	tw.tween_method(_su_gecisi, su_gorunen, 100.0, 2.5).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(func(): gecis = false)


func _su_gecisi(v: float) -> void:
	su_gorunen = v
	degisti.emit()


## Her karede: dibe dusmekte olan yemleri hareket ettirir.
func kare(delta: float) -> void:
	var hareket := false
	for a in artiklar:
		if a["p"].y < a["dip"]:
			a["p"].y = minf(a["dip"], a["p"].y + delta * 28.0)
			a["p"].x += sin(a["p"].y * 0.08) * delta * 6.0
			hareket = true
	if hareket:
		degisti.emit()


# ---------------------------------------------------------------- kayit

func sozluk() -> Dictionary:
	var l := []
	for leke in lekeler:
		l.append([leke["p"].x, leke["p"].y, leke["r"], leke["l"], leke["h"], leke["t"]])
	var a := []
	for artik in artiklar:
		a.append([artik["p"].x, artik["dip"], artik["yas"]])
	return {"su": su, "yuva": yuva, "mutluluk": mutluluk, "lekeler": l, "artiklar": a}


func yukle(d: Dictionary) -> void:
	su = clampf(float(d.get("su", su)), 0.0, 100.0)
	su_gorunen = su
	yuva = clampf(float(d.get("yuva", yuva)), 0.0, 1.0)
	mutluluk = clampf(float(d.get("mutluluk", mutluluk)), 0.0, 100.0)
	var l = d.get("lekeler", [])
	if l is Array and l.size() == YOSUN_LEKE:
		lekeler.clear()
		for e in l:
			lekeler.append({"p": Vector2(e[0], e[1]), "r": float(e[2]), "l": float(e[3]), "h": float(e[4]), "t": int(e[5])})
	artiklar.clear()
	for e in d.get("artiklar", []):
		# Kayittan gelen yem zaten dipte durur.
		artiklar.append({"p": Vector2(e[0], e[1]), "dip": float(e[1]), "yas": float(e[2])})
	degisti.emit()
