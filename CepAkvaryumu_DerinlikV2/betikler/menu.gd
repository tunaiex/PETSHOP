extends Node2D
## Saat cercevesiyle (bezel) / kenarda dairesel kaydirmayla acilan menu.
## Tek oge ortada buyuk gosterilir (kucuk yuvarlak ekran icin "carousel");
## cerceveyi cevirmek / kenarda kaydirmak secimi degistirir, ortaya dokunmak
## secer. 8 sn dokunulmazsa kendiliginden kapanir.

signal secildi(komut: String)

const MERKEZ := Vector2(240.0, 240.0)
const KENDILIGINDEN_KAPANMA := 8.0

@onready var akvaryum: Node = get_parent()
@onready var bakim: Node = get_parent().get_node("Bakim")
@onready var yasam: Node = get_parent().get_node("Yasam")

var acik := false
var mod := "ana"        # "ana", "magaza", "bilgi", "soy", "isim"
var secim := 0
var bos_sure := 0.0
var gecis := 0.0        # acilma animasyonu 0..1


func _ready() -> void:
	visible = false


func _ogeler() -> Array:
	# Her oge: [komut, baslik, alt yazi]
	match mod:
		"ana":
			var l := []
			# Acil durumlar en basta
			if yasam.hasta:
				l.append(["ilac", "İlaç ver", "%s hasta" % yasam.isim if yasam.ilac_kalan <= 0.0 else "İlaç etkili, iyileşiyor"])
			if yasam.yumurta_var:
				l.append(["nesil", "Yeni nesil", "Yumurtaları çatlat"])
			l.append_array([
				["su", "Su değiştir", "Temiz su, dipteki yem alınır"],
				["magaza", "Mağaza", "%d inci" % bakim.inci_sayisi],
				["bilgi", "Bilgi", "%s nasıl?" % yasam.isim if yasam.isim != "" else "Akvaryum"],
				["oyna", "Oyna", "Işığı kovalama oyunu"],
				["ses", "Ses", "Açık" if Ayarlar.ses_acik else "Kapalı"],
				["grafik", "Grafik", ["Düşük", "Dengeli", "Yüksek"][Ayarlar.profil]],
				["fps", "FPS göstergesi", "Açık" if Ayarlar.fps_goster else "Kapalı"],
				["soy", "Soy ağacı", "%d. nesil" % yasam.nesil],
				["kapat", "Kapat", ""],
			])
			return l
		"isim":
			var l := []
			for ad in yasam.ISIMLER:
				l.append(["isim:" + ad, ad, "Dokun: bu isim olsun"])
			return l
		"magaza":
			var l := [["super_yem", "Süper yem", "1 inci · tam tok, mutlu"]]
			l.append(["filtre", "Filtre", "Alındı ✓" if bakim.filtre else "5 inci · su 2 kat geç kirlenir"])
			for i in [1, 2]:
				var ad: String = bakim.RENK_ADLARI[i]
				if bakim.renkler[i]:
					l.append(["renk_%d" % i, ad, "Seçili" if bakim.isik_rengi == i else "Dokun: seç"])
				else:
					l.append(["renk_%d" % i, ad, "3 inci"])
			l.append(["renk_0", "Normal ışık", "Seçili" if bakim.isik_rengi == 0 else "Dokun: seç"])
			l.append(["geri", "Geri", ""])
			return l
	return [["geri", "Geri", ""]]


func ac() -> void:
	if acik:
		return
	acik = true
	mod = "ana"
	secim = 0
	bos_sure = 0.0
	gecis = 0.0
	visible = true
	Ses.cal("tik")
	queue_redraw()


func kapat() -> void:
	if mod == "isim" and yasam.isim_bekliyor:
		return  # isim secilmeden kapanmaz
	acik = false
	visible = false


## Yumurtadan cikan yavru icin isim secimi (cerceve / kenar ile gez, dokun: sec)
func isim_sec_ac() -> void:
	acik = true
	mod = "isim"
	secim = randi() % yasam.ISIMLER.size()
	bos_sure = 0.0
	gecis = 0.0
	visible = true
	queue_redraw()


func adim(yon: int) -> void:
	if not acik:
		return
	bos_sure = 0.0
	if mod == "bilgi" or mod == "soy":
		_anaya_don(mod)
	else:
		secim = posmod(secim + yon, _ogeler().size())
	Ses.cal("tik")
	queue_redraw()


func sec() -> void:
	if not acik:
		return
	bos_sure = 0.0
	if mod == "bilgi" or mod == "soy":
		_anaya_don(mod)
		queue_redraw()
		return
	var komut: String = _ogeler()[secim][0]
	if komut.begins_with("isim:"):
		yasam.isim_koy(komut.substr(5))
		Ses.cal("inci")
		mod = "ana"
		kapat()
		return
	Ses.cal("tik")
	match komut:
		"magaza":
			mod = "magaza"; secim = 0
		"bilgi":
			mod = "bilgi"
		"soy":
			mod = "soy"
		"geri":
			mod = "ana"; secim = 1
		"kapat":
			kapat()
		"ses":
			Ayarlar.ses_ayarla(not Ayarlar.ses_acik)
		"grafik":
			Ayarlar.sonraki_profil()
		"fps":
			Ayarlar.fps_ayarla(not Ayarlar.fps_goster)
		_:
			secildi.emit(komut)  # su, super_yem, filtre, renk_N: ana betik uygular
	queue_redraw()


## Bilgi / soy ekranindan ana menuye, ayni ogenin uzerine don
func _anaya_don(onceki: String) -> void:
	mod = "ana"
	secim = 0
	var l := _ogeler()
	for i in l.size():
		if l[i][0] == onceki:
			secim = i


func _process(delta: float) -> void:
	if not acik:
		return
	bos_sure += delta
	if bos_sure > KENDILIGINDEN_KAPANMA and mod != "isim":
		kapat()
		return
	if gecis < 1.0:
		gecis = minf(1.0, gecis + delta * 5.0)
		queue_redraw()


func _draw() -> void:
	var yazi := ThemeDB.fallback_font
	var g := gecis
	draw_circle(MERKEZ, 241.0, Color(0.0, 0.03, 0.06, 0.72 * g))
	var baslik: String = {"ana": "MENÜ", "magaza": "MAĞAZA", "bilgi": "BİLGİ", "soy": "SOY AĞACI", "isim": "YAVRUNA İSİM VER"}[mod]
	draw_string(yazi, Vector2(0, 118), baslik, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, Color(0.55, 0.85, 1.0, g))

	if mod == "bilgi":
		var evre_metni: String = yasam.EVRE_ADLARI[yasam.evre]
		if yasam.form >= 0:
			evre_metni += " · " + yasam.FORM_ADLARI[yasam.form]
		var satirlar := [
			"%s · %d. nesil" % [yasam.isim, yasam.nesil],
			evre_metni,
			"Yaş: %d gün · Boy: %%%d" % [int(yasam.yas_gun()), int(round(bakim.boy * 100.0))],
			"Sağlık: %%%d%s" % [int(yasam.saglik), " · hasta" if yasam.hasta else ""],
			"Mutluluk: %%%d" % int(bakim.mutluluk),
			"Tokluk %%%d · Su %%%d" % [int(akvaryum.aclik), int(bakim.su)],
			"Cam %%%d · İnci %d" % [int(bakim.cam_temizligi() * 100.0), bakim.inci_sayisi],
			"Bakım hatası: %d" % yasam.toplam_hata,
		]
		for i in satirlar.size():
			draw_string(yazi, Vector2(0, 158 + i * 27), satirlar[i], HORIZONTAL_ALIGNMENT_CENTER, 480, 20 if i > 0 else 22, Color(1, 1, 1, g) if i > 0 else Color(0.55, 0.9, 1.0, g))
		draw_string(yazi, Vector2(0, 400), "Dokun: geri", HORIZONTAL_ALIGNMENT_CENTER, 480, 14, Color(0.7, 0.8, 0.85, g))
		return

	if mod == "soy":
		var satirlar := []
		for e in yasam.gecmis:
			var f: String = yasam.FORM_ADLARI[e["form"]] if int(e["form"]) >= 0 else "?"
			satirlar.append("%d. %s · %d gün · %s" % [e["nesil"], e["isim"], e["gun"], f])
		satirlar.append("%d. %s · şimdi" % [yasam.nesil, yasam.isim if yasam.isim != "" else "yumurta"])
		var bas := maxi(0, satirlar.size() - 8)
		for i in range(bas, satirlar.size()):
			draw_string(yazi, Vector2(0, 165 + (i - bas) * 27), satirlar[i], HORIZONTAL_ALIGNMENT_CENTER, 480, 18, Color(1, 1, 1, g))
		draw_string(yazi, Vector2(0, 400), "Dokun: geri", HORIZONTAL_ALIGNMENT_CENTER, 480, 14, Color(0.7, 0.8, 0.85, g))
		return

	var ogeler := _ogeler()
	var oge: Array = ogeler[secim]
	draw_string(yazi, Vector2(0, 248), oge[1], HORIZONTAL_ALIGNMENT_CENTER, 480, 32, Color(1, 1, 1, g))
	draw_string(yazi, Vector2(0, 285), oge[2], HORIZONTAL_ALIGNMENT_CENTER, 480, 17, Color(0.75, 0.88, 0.95, g))
	draw_string(yazi, Vector2(0, 345), "Çevir: seç · Dokun: tamam", HORIZONTAL_ALIGNMENT_CENTER, 480, 13, Color(0.6, 0.72, 0.8, g))
	# Inci sayaci
	draw_circle(Vector2(222, 380), 5.0, Color(0.92, 0.9, 0.95, g))
	draw_circle(Vector2(220.5, 378.5), 1.4, Color(1, 1, 1, g))
	draw_string(yazi, Vector2(232, 386), "%d" % bakim.inci_sayisi, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, g))
	# Kenarda konum noktalari (cerceve hissi)
	var n := ogeler.size()
	for i in n:
		var a := -PI / 2.0 + (float(i) - float(n - 1) / 2.0) * 0.16
		var p := MERKEZ + Vector2.from_angle(a) * 222.0
		var sec_mi := i == secim
		draw_circle(p, 6.0 if sec_mi else 3.5, Color(0.45, 0.9, 1.0, g) if sec_mi else Color(1, 1, 1, 0.45 * g))
