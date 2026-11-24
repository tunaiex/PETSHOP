extends Node
## Ses yoneticisi (autoload: "Ses"). Tum sesler kodla uretildi
## (../araclar/ses_uret.py). Ortam su sesi kisik bir dongudur; efektler kisa.
## Ayarlar.ses_acik kapaliysa hicbir sey calmaz. Uygulama arka plandayken
## ortam sesi durur (pil).

const SESLER := {
	"yem": preload("res://sesler/yem.wav"),
	"silme": preload("res://sesler/silme.wav"),
	"su": preload("res://sesler/su_degisimi.wav"),
	"inci": preload("res://sesler/inci.wav"),
	"tik": preload("res://sesler/tik.wav"),
	"kabarma": preload("res://sesler/kabarma.wav"),
}
const SES_DUZEYI := {"yem": -6.0, "silme": -14.0, "su": -6.0, "inci": -6.0, "tik": -12.0, "kabarma": -10.0}
const ORTAM_DUZEYI := -20.0

var ortam := AudioStreamPlayer.new()
var oynaticilar: Array[AudioStreamPlayer] = []
var son_silme := 0.0


func _ready() -> void:
	var dongu: AudioStreamWAV = preload("res://sesler/ortam.wav").duplicate()
	dongu.loop_mode = AudioStreamWAV.LOOP_FORWARD
	dongu.loop_begin = 0
	dongu.loop_end = dongu.data.size() / 2  # 16 bit mono: ornek sayisi
	ortam.stream = dongu
	ortam.volume_db = ORTAM_DUZEYI
	add_child(ortam)
	for i in 4:
		var o := AudioStreamPlayer.new()
		add_child(o)
		oynaticilar.append(o)
	Ayarlar.ayar_degisti.connect(_ortami_guncelle)
	_ortami_guncelle()


func cal(ad: String) -> void:
	if not Ayarlar.ses_acik or not SESLER.has(ad):
		return
	if ad == "silme":
		# Parmak hizla birden cok leke silerse ses ust uste binmesin
		var simdi := Time.get_ticks_msec() / 1000.0
		if simdi - son_silme < 0.15:
			return
		son_silme = simdi
	for o in oynaticilar:
		if not o.playing:
			o.stream = SESLER[ad]
			o.volume_db = SES_DUZEYI[ad]
			o.pitch_scale = randf_range(0.95, 1.05)
			o.play()
			return


func _ortami_guncelle() -> void:
	if Ayarlar.ses_acik and not ortam.playing:
		ortam.play()
	elif not Ayarlar.ses_acik:
		ortam.stop()


func _notification(bildirim: int) -> void:
	if bildirim == NOTIFICATION_APPLICATION_PAUSED or bildirim == NOTIFICATION_APPLICATION_FOCUS_OUT:
		ortam.stream_paused = true
	elif bildirim == NOTIFICATION_APPLICATION_RESUMED or bildirim == NOTIFICATION_APPLICATION_FOCUS_IN:
		ortam.stream_paused = false
