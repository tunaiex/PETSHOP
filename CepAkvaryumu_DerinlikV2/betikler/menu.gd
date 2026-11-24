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

var acik := false
var mod := "ana"        # "ana", "magaza", "bilgi"
var secim := 0
var bos_sure := 0.0
var gecis := 0.0        # acilma animasyonu 0..1


func _ready() -> void:
	visible = false


func _ogeler() -> Array:
	# Her oge: [komut, baslik, alt yazi]
	match mod:
		"ana":
			return [
				["su", "Su değiştir", "Temiz su, dipteki yem alınır"],
				["magaza", "Mağaza", "%d inci" % bakim.inci_sayisi],
				["bilgi", "Bilgi", "Balığın durumu"],
				["ses", "Ses", "Açık" if Ayarlar.ses_acik else "Kapalı"],
				["grafik", "Grafik", ["Düşük", "Dengeli", "Yüksek"][Ayarlar.profil]],
				["fps", "FPS göstergesi", "Açık" if Ayarlar.fps_goster else "Kapalı"],
				["kapat", "Kapat", ""],
			]
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
	acik = false
	visible = false


func adim(yon: int) -> void:
	if not acik:
		return
	bos_sure = 0.0
	if mod == "bilgi":
		mod = "ana"; secim = 2
	else:
		secim = posmod(secim + yon, _ogeler().size())
	Ses.cal("tik")
	queue_redraw()


func sec() -> void:
	if not acik:
		return
	bos_sure = 0.0
	if mod == "bilgi":
		mod = "ana"; secim = 2
		queue_redraw()
		return
	var komut: String = _ogeler()[secim][0]
	Ses.cal("tik")
	match komut:
		"magaza":
			mod = "magaza"; secim = 0
		"bilgi":
			mod = "bilgi"
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


func _process(delta: float) -> void:
	if not acik:
		return
	bos_sure += delta
	if bos_sure > KENDILIGINDEN_KAPANMA:
		kapat()
		return
	if gecis < 1.0:
		gecis = minf(1.0, gecis + delta * 5.0)
		queue_redraw()


func _draw() -> void:
	var yazi := ThemeDB.fallback_font
	var g := gecis
	draw_circle(MERKEZ, 241.0, Color(0.0, 0.03, 0.06, 0.72 * g))
	var baslik: String = {"ana": "MENÜ", "magaza": "MAĞAZA", "bilgi": "BİLGİ"}[mod]
	draw_string(yazi, Vector2(0, 118), baslik, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, Color(0.55, 0.85, 1.0, g))

	if mod == "bilgi":
		var satirlar := [
			"Yaş: %d gün" % int(bakim.yas_gun()),
			"Boy: %%%d" % int(round(bakim.boy * 100.0)),
			"Mutluluk: %%%d" % int(bakim.mutluluk),
			"Tokluk: %%%d" % int(akvaryum.aclik),
			"Su: %%%d" % int(bakim.su),
			"Cam: %%%d temiz" % int(bakim.cam_temizligi() * 100.0),
			"İnci: %d" % bakim.inci_sayisi,
			"Filtre: %s" % ("var" if bakim.filtre else "yok"),
		]
		for i in satirlar.size():
			draw_string(yazi, Vector2(0, 160 + i * 28), satirlar[i], HORIZONTAL_ALIGNMENT_CENTER, 480, 21, Color(1, 1, 1, g))
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
