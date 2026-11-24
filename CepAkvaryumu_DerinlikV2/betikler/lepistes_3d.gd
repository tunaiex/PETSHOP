extends SubViewport
## Tek bir lepistesin (guppy) 3B cizimi: kucuk SubViewport, sonuc bir Sprite2D'ye
## doku olarak verilir (betta ile ayni yontem). Model zaten rig'li ve kendi yuzme
## animasyonu var (kuyruk S dalgasi); hiz arttikca animasyon hizlanir, donuste
## govde yana yatar. Cok hafif: ~1.500 ucgen, 43 kemik.
##
## Model: kullanicinin sagladigi "guppy-fish" (Guppy.blend), GLB'ye donusturuldu:
## ../araclar/blender/lepistes_donustur.py

const MODEL := preload("res://modeller/lepistes.glb")
# Modeli ~1 birim boya getirir ve govde merkezini donme noktasina alir.
const OLCEK := 0.165
const MERKEZ := Vector3(0.0, 0.12, -0.76)
const CERCEVE := 1.45   # uc pozlarda kesilmesin diye kamera payi (betta ile ayni)

var pivot := Node3D.new()
var oynatici: AnimationPlayer
var yalpa := 0.0
var onceki_sapma := 0.0
var etkin := true


func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var ortam := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.75, 0.9)
	env.ambient_light_energy = 0.8
	ortam.environment = env
	add_child(ortam)
	var isik := DirectionalLight3D.new()
	isik.rotation_degrees = Vector3(-62.0, 20.0, 0.0)
	isik.light_energy = 1.1
	isik.light_color = Color(1.0, 0.97, 0.9)
	isik.shadow_enabled = false
	add_child(isik)
	var kamera := Camera3D.new()
	kamera.fov = 25.0
	kamera.position = Vector3(0.0, 0.0, 2.9 * CERCEVE)
	add_child(kamera)

	add_child(pivot)
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * OLCEK
	model.position = -MERKEZ * OLCEK
	pivot.add_child(model)
	oynatici = model.find_child("AnimationPlayer", true, false)
	var ad: String = oynatici.get_animation_list()[0]
	oynatici.get_animation(ad).loop_mode = Animation.LOOP_LINEAR
	oynatici.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	oynatici.play(ad)
	oynatici.seek(randf() * oynatici.current_animation_length, true)  # hepsi ayni anda cirpmasin


func boyut_ayarla(piksel: int) -> void:
	var b := int(round(piksel * CERCEVE / 8.0)) * 8
	size = Vector2i(b, b)


## Sprite olcegi bununla carpilir (dahili cozunurluk ne olursa olsun ayni boy).
func olcek_carpani(referans: float) -> float:
	return referans * CERCEVE / float(size.x)


func etkinlestir(acik: bool) -> void:
	etkin = acik
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if acik else SubViewport.UPDATE_DISABLED


## yon: oyunun koordinatinda (x saga, y asagi, z derine). hiz: piksel/sn.
func guncelle(yon: Vector3, hiz: float, delta: float, uyuyor: bool) -> void:
	if not etkin:
		return
	var d := Vector3(yon.x, -yon.y, -yon.z)
	if d.length_squared() < 0.0001:
		d = Vector3.LEFT
	d = d.normalized()
	var sapma := atan2(-d.x, -d.z)
	var egim := clampf(asin(clampf(d.y, -1.0, 1.0)), -0.45, 0.45)
	var donus := wrapf(sapma - onceki_sapma, -PI, PI) / maxf(delta, 0.001)
	onceki_sapma = sapma
	yalpa = lerpf(yalpa, clampf(-donus * 0.10, -0.35, 0.35), minf(1.0, delta * 5.0))
	pivot.rotation = Vector3(egim, sapma, yalpa)
	var etkinlik := clampf(hiz / 70.0, 0.0, 1.0)
	oynatici.advance(delta * (0.3 if uyuyor else lerpf(0.7, 2.4, etkinlik)))
