extends Node
## Grafik kalite profilleri (autoload: "Ayarlar").
## Varsayilan: DENGELI. Secim user://ayarlar.cfg dosyasinda saklanir.
## Bilgisayarda test icin 1 / 2 / 3 tuslari profili degistirir.

signal profil_degisti

enum Profil { DUSUK, DENGELI, YUKSEK }

const DOSYA := "user://ayarlar.cfg"
const ADLAR := ["Dusuk", "Dengeli", "Yuksek"]

# fps: isik acikken hedef kare hizi
# balik_boyutu: 3B baligin cizildigi dahili cozunurluk (piksel, kare)
# msaa: 3B kenar yumusatma; normal_harita: balik pullarinin kabartma dokusu
# baloncuk: ayni anda gorunen kabarcik sayisi
const DEGERLER := {
	Profil.DUSUK: {"fps": 24, "balik_boyutu": 128, "msaa": Viewport.MSAA_DISABLED, "normal_harita": false, "baloncuk": 6},
	Profil.DENGELI: {"fps": 30, "balik_boyutu": 160, "msaa": Viewport.MSAA_2X, "normal_harita": true, "baloncuk": 9},
	Profil.YUKSEK: {"fps": 30, "balik_boyutu": 224, "msaa": Viewport.MSAA_4X, "normal_harita": true, "baloncuk": 11},
}
const ISIK_KAPALI_FPS := 6

var profil: int = Profil.DENGELI


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DOSYA) == OK:
		profil = clampi(int(cfg.get_value("grafik", "profil", Profil.DENGELI)), Profil.DUSUK, Profil.YUKSEK)


func deger(anahtar: String) -> Variant:
	return DEGERLER[profil][anahtar]


func profil_ayarla(yeni: int) -> void:
	yeni = clampi(yeni, Profil.DUSUK, Profil.YUKSEK)
	if yeni == profil:
		return
	profil = yeni
	var cfg := ConfigFile.new()
	cfg.set_value("grafik", "profil", profil)
	cfg.save(DOSYA)
	print("Grafik profili: ", ADLAR[profil])
	profil_degisti.emit()


func _unhandled_key_input(olay: InputEvent) -> void:
	if OS.has_feature("mobile") or not (olay is InputEventKey) or not olay.pressed:
		return
	match olay.keycode:
		KEY_1: profil_ayarla(Profil.DUSUK)
		KEY_2: profil_ayarla(Profil.DENGELI)
		KEY_3: profil_ayarla(Profil.YUKSEK)
