extends Node
## Sanal evcil hayvan (Tamagotchi) cekirdegi: yasam evreleri, bakim hatalari,
## saglik / hastalik, ihtiyac cagrilari, kaka, gece uykusu, oyun, nesiller.
##
## Olum yok (yumusak sistem): bakilmazsa balik hastalanir ve "kritik" olur;
## ilac ve iyi bakimla toparlanir. Omur ~1 ay: 7. gun yetiskin, 24. gunden
## sonra yasli. Yasli ve mutlu balik kopuk yuvasina yumurta birakir; yeni
## nesil ebeveynin rengini ve yuzgecini kismen tasir.
## Tum hesaplar gercek zamanla ilerler (uygulama kapaliyken de).

signal olay(metin: String)     # ekranda kisa bildirim seridi
signal cagri(ihtiyac: String)  # balik yeni bir sey istiyor (titresim)
signal evre_degisti

enum Evre { YUMURTA, YAVRU, GENC, YETISKIN, YASLI }
const EVRE_ADLARI := ["Yumurta", "Yavru", "Genç", "Yetişkin", "Yaşlı"]
const FORM_ADLARI := ["Kısa yüzgeçli", "Normal", "Halfmoon"]   # kotu / orta / iyi

const GUN := 86400.0
const SAAT := 3600.0
const YAVRU_SON := 2.0          # gun
const GENC_SON := 7.0
const YASLI_BAS := 24.0
const YUMURTA_SURE := 180.0     # yumurtalarin catlamasi (sn)
const HATA_SURE := 900.0        # 15 dk ilgilenilmeyen ihtiyac = bakim hatasi
const KAKA_EN_FAZLA := 8
const ILAC_SURE := 6.0 * 3600.0
const ISIMLER := ["Mavi", "Alev", "Bulut", "Mercan", "Dalga", "Fırtına", "İnci", "Kıvılcım",
	"Boncuk", "Pamuk", "Zeytin", "Safir", "Lokum", "Duman", "Gece", "Şimşek"]
# Ihtiyaclar (oncelik sirasiyla) ve kisa aciklamalari
const IHTIYACLAR := ["hasta", "ac", "su", "uyku", "kaka", "cam", "sikildi"]
const IHTIYAC_METNI := {"hasta": "hasta", "ac": "aç", "su": "su kirli", "uyku": "uykusu var",
	"kaka": "dip kirli", "cam": "cam kirli", "sikildi": "sıkıldı"}

@onready var akvaryum: Node = get_parent()
@onready var bakim: Node = get_parent().get_node("Bakim")

var evre: int = Evre.YUMURTA
var dogum := 0.0                # yumurtadan cikis (unix)
var yumurta_bitis := 0.0
var isim := ""
var isim_bekliyor := false
var nesil := 1
var form := -1                  # -1 henuz yok, 0 kotu, 1 orta, 2 iyi
var bakim_hatasi := 0           # yavru + genc donemindeki hatalar (formu belirler)
var toplam_hata := 0
var saglik := 100.0
var hasta := false
var hastalik_riski := 0.0
var ilac_kalan := 0.0
var kakalar: Array[Vector2] = []
var kaka_zamanlari: Array[float] = []   # yem yendikten sonra kaka zamanlari (unix)
var son_oyun := 0.0
var ihtiyac_bas := {}           # ihtiyac -> basladigi zaman
var ihtiyac_sayildi := {}       # ihtiyac -> bu seferlik hata sayildi mi
var yumurta_var := false        # yasli balik yuvaya yumurta birakti
var renk_ton := 0.0             # nesilden nesile kayan renk tonu (-0.5..0.5)
var yuzgec_gen := 1.0           # nesilden gelen yuzgec uzunlugu egilimi
var gecmis: Array = []          # onceki nesiller
var saat_ayari := -1            # test: gece / gunduz zorlamak icin (-1 = gercek saat)
var zaman_kaydir := 0.0         # test / T tusu: saati ileri sarmak icin (sn)
var kaka_cizici := Node2D.new()


func _ready() -> void:
	kaka_cizici.name = "Kakalar"
	kaka_cizici.z_index = 6
	add_child(kaka_cizici)
	kaka_cizici.draw.connect(_kakalari_ciz)


# ------------------------------------------------------------------ zaman

func simdi() -> float:
	return Time.get_unix_time_from_system() + zaman_kaydir


func gece() -> bool:
	var saat: int = saat_ayari if saat_ayari >= 0 else Time.get_datetime_dict_from_system()["hour"]
	return saat >= 22 or saat < 8


func yas_gun() -> float:
	if evre == Evre.YUMURTA:
		return 0.0
	return maxf(0.0, simdi() - dogum) / GUN


func kritik() -> bool:
	return evre != Evre.YUMURTA and saglik < 15.0


## Gecen gercek sure (sn). Ana betik her saniye ve acilista cagirir.
func ilerlet(saniye: float) -> void:
	var t := simdi()
	if evre == Evre.YUMURTA:
		if t >= yumurta_bitis:
			_yumurtadan_cik()
		return

	_evreyi_guncelle()
	bakim.boy = boy()

	# Kaka: yem yendikten 20-40 dk sonra dipte belirir, suyu kirletir
	var kalan: Array[float] = []
	for z in kaka_zamanlari:
		if z <= t and kakalar.size() < KAKA_EN_FAZLA:
			kakalar.append(bakim._kumda_yer())
		elif z > t:
			kalan.append(z)
	kaka_zamanlari = kalan
	bakim.su = maxf(0.0, bakim.su - kakalar.size() * 3.0 * saniye / SAAT)

	# Hastalik: kirli su ya da uzun aclik riski biriktirir
	if bakim.su < 25.0 or akvaryum.aclik < 5.0:
		hastalik_riski += saniye / (2.0 * SAAT)
	else:
		hastalik_riski = maxf(0.0, hastalik_riski - saniye / (4.0 * SAAT))
	if hastalik_riski >= 1.0 and not hasta:
		hasta = true
		hastalik_riski = 0.0
		olay.emit("%s hastalandı! Menü > İlaç ver" % isim)

	# Ilac: 6 saatte iyilestirir
	if ilac_kalan > 0.0:
		ilac_kalan -= saniye
		if ilac_kalan <= 0.0 and hasta:
			hasta = false
			olay.emit("%s iyileşti!" % isim)

	# Saglik
	var d := 0.0
	if hasta and ilac_kalan <= 0.0:
		d -= 100.0 / 36.0
	if akvaryum.aclik < 5.0:
		d -= 100.0 / 48.0
	if bakim.su < 20.0:
		d -= 100.0 / 72.0
	if d == 0.0:
		d = 100.0 / 24.0
	var once_kritik := kritik()
	saglik = clampf(saglik + d * saniye / SAAT, 0.0, 100.0)
	if kritik() and not once_kritik:
		olay.emit("%s çok halsiz! Bakıma ihtiyacı var" % isim)

	# Yasli ve mutlu: yuvaya yumurta birakir
	if evre == Evre.YASLI and not yumurta_var and bakim.yuva >= 0.8 and bakim.mutluluk >= 70.0:
		yumurta_var = true
		olay.emit("%s yuvaya yumurta bıraktı! Menü > Yeni nesil" % isim)

	_ihtiyaclari_denetle(saniye, t)
	kaka_cizici.queue_redraw()


func _evreyi_guncelle() -> void:
	var a := yas_gun()
	var yeni: int = Evre.YAVRU
	if a >= YASLI_BAS:
		yeni = Evre.YASLI
	elif a >= GENC_SON:
		yeni = Evre.YETISKIN
	elif a >= YAVRU_SON:
		yeni = Evre.GENC
	if yeni == evre:
		return
	evre = yeni
	match evre:
		Evre.GENC:
			olay.emit("%s büyüyor: artık genç" % isim)
		Evre.YETISKIN:
			# Yavru + genc donemindeki bakim yetiskin formunu belirler
			form = 2 if bakim_hatasi <= 2 else (1 if bakim_hatasi <= 6 else 0)
			olay.emit("%s yetişkin oldu: %s" % [isim, FORM_ADLARI[form]])
		Evre.YASLI:
			olay.emit("%s artık yaşlı ve bilge" % isim)
	evre_degisti.emit()


func _yumurtadan_cik() -> void:
	evre = Evre.YAVRU
	dogum = yumurta_bitis
	isim_bekliyor = true
	saglik = 100.0
	bakim.boy = boy()
	olay.emit("Yumurtalar çatladı!")
	evre_degisti.emit()


func ihtiyaclar() -> Array:
	if evre == Evre.YUMURTA:
		return []
	var l := []
	if hasta: l.append("hasta")
	if akvaryum.aclik < 25.0: l.append("ac")
	if bakim.su < 35.0: l.append("su")
	if gece() and akvaryum.isik_acik: l.append("uyku")
	if kakalar.size() >= 3: l.append("kaka")
	if bakim.cam_temizligi() < 0.5: l.append("cam")
	if son_oyun > 0.0 and simdi() - son_oyun > GUN: l.append("sikildi")
	return l


func _ihtiyaclari_denetle(saniye: float, t: float) -> void:
	var aktif := ihtiyaclar()
	for ad in aktif:
		if not ihtiyac_bas.has(ad):
			# Uygulama kapaliyken basladiysa, boslugun basinda basladigini varsay
			ihtiyac_bas[ad] = t - (saniye if saniye > 60.0 else 0.0)
			ihtiyac_sayildi[ad] = false
			if saniye <= 60.0:
				cagri.emit(ad)
		if not ihtiyac_sayildi[ad] and t - ihtiyac_bas[ad] > HATA_SURE:
			ihtiyac_sayildi[ad] = true
			toplam_hata += 1
			if evre == Evre.YAVRU or evre == Evre.GENC:
				bakim_hatasi += 1
	for ad in ihtiyac_bas.keys():
		if not ad in aktif:
			ihtiyac_bas.erase(ad)
			ihtiyac_sayildi.erase(ad)


## Mutluluk hedefine yasam etkileri (bakim.gd cagirir)
func mutluluk_duzeltme() -> float:
	if evre == Evre.YUMURTA:
		return 0.0
	var m := 0.0
	if hasta: m -= 25.0
	if gece() and akvaryum.isik_acik: m -= 15.0
	if gece() and not akvaryum.isik_acik: m += 5.0
	m -= maxf(0.0, kakalar.size() - 2) * 5.0
	if son_oyun > 0.0 and simdi() - son_oyun < 6.0 * SAAT: m += 8.0
	if kritik(): m -= 20.0
	return m


# ------------------------------------------------------------------ gorunum

func boy() -> float:
	var a := yas_gun()
	var b := 0.45
	if a < YAVRU_SON:
		b = lerpf(0.45, 0.6, a / YAVRU_SON)
	elif a < GENC_SON:
		b = lerpf(0.6, 0.85, (a - YAVRU_SON) / (GENC_SON - YAVRU_SON))
	else:
		b = lerpf(0.85, 1.0, clampf((a - GENC_SON) / 3.0, 0.0, 1.0))
		if form == 0:
			b = minf(b, 0.9)  # kotu bakilmis balik tam boyuna ulasamaz
	return b


## Baligin gorunusu: boy, renk doygunlugu, parlaklik, ton, yuzgec boyu,
## kapali yuzgec (hasta / mutsuz), beyaz benek (hastalik).
func gorunum() -> Dictionary:
	var doyg := 1.0
	var yuzgec := 1.0
	match evre:
		Evre.YAVRU: doyg = 0.35; yuzgec = 0.6
		Evre.GENC: doyg = lerpf(0.5, 0.85, clampf((yas_gun() - YAVRU_SON) / 5.0, 0.0, 1.0)); yuzgec = 0.85
		Evre.YETISKIN, Evre.YASLI:
			doyg = [0.6, 0.92, 1.15][maxi(form, 0)]
			yuzgec = [0.8, 1.0, 1.15][maxi(form, 0)]
	yuzgec *= yuzgec_gen
	var parlak := 1.0
	if evre == Evre.YAVRU:
		parlak = 1.35  # yavru soluk ve yari saydam gibi acik renkli
	elif evre == Evre.GENC:
		parlak = 1.12
	if evre == Evre.YASLI:
		doyg *= 0.85; parlak = 0.92
	var kapali := 0.0
	if hasta:
		doyg *= 0.65; kapali = 0.7
	if bakim.mutluluk < 35.0:
		kapali = maxf(kapali, 0.5)
	if kritik():
		kapali = 1.0; doyg *= 0.6; parlak *= 0.8
	return {"doygunluk": doyg, "parlaklik": parlak, "ton": renk_ton, "yuzgec": yuzgec,
		"kapali": kapali, "benek": 1.0 if hasta else 0.0}


# ------------------------------------------------------------------ eylemler

func yem_yendi() -> void:
	if kaka_zamanlari.size() < KAKA_EN_FAZLA:
		kaka_zamanlari.append(simdi() + randf_range(1200.0, 2400.0))


func kaka_temizle(konum: Vector2) -> bool:
	for i in kakalar.size():
		if kakalar[i].distance_to(konum) < 24.0:
			kakalar.remove_at(i)
			kaka_cizici.queue_redraw()
			return true
	return false


func ilac_ver() -> void:
	if hasta:
		ilac_kalan = ILAC_SURE
		olay.emit("İlaç verildi. %s birkaç saatte iyileşir" % isim)


func oyun_oynandi() -> void:
	son_oyun = simdi()


func isim_koy(ad: String) -> void:
	isim = ad
	isim_bekliyor = false
	olay.emit("Merhaba %s!" % isim)


## Yeni nesil: yasli balik "emekli olur", yumurtalardan yavru cikar.
## Yavru ebeveynin renk tonunu ve yuzgec egilimini kismen tasir.
func yeni_nesil() -> void:
	gecmis.append({"isim": isim, "nesil": nesil, "gun": int(yas_gun()),
		"form": form, "hata": toplam_hata})
	if gecmis.size() > 12:
		gecmis.pop_front()
	var ebeveyn_form := maxi(form, 0)
	nesil += 1
	evre = Evre.YUMURTA
	yumurta_bitis = simdi() + YUMURTA_SURE
	renk_ton = wrapf(renk_ton + randf_range(-0.08, 0.08), -0.5, 0.5)
	yuzgec_gen = clampf(lerpf(yuzgec_gen, [0.92, 1.0, 1.08][ebeveyn_form], 0.5) + randf_range(-0.04, 0.04), 0.85, 1.15)
	form = -1
	bakim_hatasi = 0
	toplam_hata = 0
	saglik = 100.0
	hasta = false
	ilac_kalan = 0.0
	hastalik_riski = 0.0
	yumurta_var = false
	isim = ""
	ihtiyac_bas.clear()
	ihtiyac_sayildi.clear()
	bakim.yuva = 0.6
	olay.emit("Yeni nesil! Yumurtalar birkaç dakikada çatlar")
	evre_degisti.emit()


## Hic kayit yokken: yumurtadan baslar.
func yeni_oyun() -> void:
	evre = Evre.YUMURTA
	yumurta_bitis = simdi() + YUMURTA_SURE
	bakim.yuva = 0.6
	evre_degisti.emit()


## Eski kayit (yasam sistemi oncesi): balik iyi bakilmis bir yetiskin.
func eski_kayittan() -> void:
	evre = Evre.YETISKIN
	dogum = simdi() - 8.0 * GUN
	form = 2
	isim = "Mavi"
	bakim.boy = 1.0


## Testler icin: dogrudan iyi bakilmis yetiskin.
func test_yetiskin() -> void:
	eski_kayittan()
	isim = "Test"
	isim_bekliyor = false
	saat_ayari = 12
	evre_degisti.emit()


# ------------------------------------------------------------------ cizim

func _kakalari_ciz() -> void:
	for p in kakalar:
		# Kucuk, kivrik, koyu kahverengi
		kaka_cizici.draw_circle(p + Vector2(1.5, 1.5), 3.6, Color(0, 0, 0, 0.25))
		kaka_cizici.draw_circle(p, 3.2, Color(0.26, 0.17, 0.08))
		kaka_cizici.draw_circle(p + Vector2(3.5, -1.2), 2.4, Color(0.30, 0.20, 0.10))
		kaka_cizici.draw_circle(p + Vector2(6.0, -0.2), 1.6, Color(0.24, 0.16, 0.07))
		kaka_cizici.draw_circle(p + Vector2(-0.8, -1.0), 0.9, Color(0.45, 0.33, 0.18))


# ------------------------------------------------------------------ kayit

func sozluk() -> Dictionary:
	var k := []
	for p in kakalar:
		k.append([p.x, p.y])
	return {"evre": evre, "dogum": dogum, "yumurta_bitis": yumurta_bitis, "isim": isim,
		"isim_bekliyor": isim_bekliyor, "nesil": nesil, "form": form, "bakim_hatasi": bakim_hatasi,
		"toplam_hata": toplam_hata, "saglik": saglik, "hasta": hasta, "hastalik_riski": hastalik_riski,
		"ilac_kalan": ilac_kalan, "kakalar": k, "kaka_zamanlari": kaka_zamanlari, "son_oyun": son_oyun,
		"yumurta_var": yumurta_var, "renk_ton": renk_ton, "yuzgec_gen": yuzgec_gen, "gecmis": gecmis}


func yukle(d: Dictionary) -> void:
	evre = clampi(int(d.get("evre", Evre.YETISKIN)), 0, 4)
	dogum = float(d.get("dogum", simdi()))
	yumurta_bitis = float(d.get("yumurta_bitis", 0.0))
	isim = str(d.get("isim", "Mavi"))
	isim_bekliyor = bool(d.get("isim_bekliyor", false))
	nesil = int(d.get("nesil", 1))
	form = int(d.get("form", -1))
	bakim_hatasi = int(d.get("bakim_hatasi", 0))
	toplam_hata = int(d.get("toplam_hata", 0))
	saglik = float(d.get("saglik", 100.0))
	hasta = bool(d.get("hasta", false))
	hastalik_riski = float(d.get("hastalik_riski", 0.0))
	ilac_kalan = float(d.get("ilac_kalan", 0.0))
	kakalar.clear()
	for e in d.get("kakalar", []):
		kakalar.append(Vector2(e[0], e[1]))
	kaka_zamanlari.clear()
	for z in d.get("kaka_zamanlari", []):
		kaka_zamanlari.append(float(z))
	son_oyun = float(d.get("son_oyun", 0.0))
	yumurta_var = bool(d.get("yumurta_var", false))
	renk_ton = float(d.get("renk_ton", 0.0))
	yuzgec_gen = float(d.get("yuzgec_gen", 1.0))
	gecmis = d.get("gecmis", [])
	evre_degisti.emit()
