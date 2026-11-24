extends Node
## Kullanici ayarlari (autoload: "Ayarlar"): grafik profili, ses, FPS gostergesi.
## Varsayilan: DENGELI, ses acik, FPS kapali. user://ayarlar.cfg dosyasinda saklanir.
## Bilgisayarda test icin 1 / 2 / 3 tuslari profili degistirir.

signal profil_degisti
signal ayar_degisti

enum Profil { DUSUK, DENGELI, YUKSEK }

const DOSYA := "user://ayarlar.cfg"
const ADLAR := ["Dusuk", "Dengeli", "Yuksek"]

# fps: isik acikken hedef kare hizi; gece_fps: isik kapaliyken (balik uyur,
# daha az hareket var ama dokunmaya hizli tepki ve akici gorunum korunur)
# balik_boyutu: 3B baligin cizildigi dahili cozunurluk (piksel, kare)
# msaa: 3B kenar yumusatma; normal_harita: balik pullarinin kabartma dokusu
# baloncuk: ayni anda gorunen kabarcik sayisi
# su_dalgasi: ust su yuzeyinin dalgalanmasi (Dusuk'te kapali: resim duragan)
const DEGERLER := {
	Profil.DUSUK: {"fps": 24, "gece_fps": 15, "balik_boyutu": 128, "msaa": Viewport.MSAA_DISABLED, "normal_harita": false, "baloncuk": 8, "su_dalgasi": false},
	Profil.DENGELI: {"fps": 30, "gece_fps": 20, "balik_boyutu": 160, "msaa": Viewport.MSAA_2X, "normal_harita": true, "baloncuk": 14, "su_dalgasi": true},
	Profil.YUKSEK: {"fps": 30, "gece_fps": 24, "balik_boyutu": 224, "msaa": Viewport.MSAA_4X, "normal_harita": true, "baloncuk": 18, "su_dalgasi": true},
}

var profil: int = Profil.DENGELI
var ses_acik := true
var fps_goster := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DOSYA) == OK:
		profil = clampi(int(cfg.get_value("grafik", "profil", Profil.DENGELI)), Profil.DUSUK, Profil.YUKSEK)
		ses_acik = bool(cfg.get_value("genel", "ses", true))
		fps_goster = bool(cfg.get_value("genel", "fps", false))


func _kaydet() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("grafik", "profil", profil)
	cfg.set_value("genel", "ses", ses_acik)
	cfg.set_value("genel", "fps", fps_goster)
	cfg.save(DOSYA)


func ses_ayarla(acik: bool) -> void:
	ses_acik = acik
	_kaydet()
	ayar_degisti.emit()


func fps_ayarla(acik: bool) -> void:
	fps_goster = acik
	_kaydet()
	ayar_degisti.emit()


## Menu icin: profili sirayla degistirir (Dusuk -> Dengeli -> Yuksek -> Dusuk)
func sonraki_profil() -> void:
	profil_ayarla((profil + 1) % 3)


func deger(anahtar: String) -> Variant:
	return DEGERLER[profil][anahtar]


func profil_ayarla(yeni: int) -> void:
	yeni = clampi(yeni, Profil.DUSUK, Profil.YUKSEK)
	if yeni == profil:
		return
	profil = yeni
	_kaydet()
	print("Grafik profili: ", ADLAR[profil])
	profil_degisti.emit()


func _unhandled_key_input(olay: InputEvent) -> void:
	if OS.has_feature("mobile") or not (olay is InputEventKey) or not olay.pressed:
		return
	match olay.keycode:
		KEY_1: profil_ayarla(Profil.DUSUK)
		KEY_2: profil_ayarla(Profil.DENGELI)
		KEY_3: profil_ayarla(Profil.YUKSEK)
