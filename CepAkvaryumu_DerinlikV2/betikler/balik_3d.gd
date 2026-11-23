extends SubViewport
## Gercek 3B, rig'li betta: GLB modeli bu kucuk SubViewport'ta cizilir, sonuc
## 2B sahnedeki "Balik" Sprite2D'sine doku olarak verilir. Boylece kaya /
## kutuk / yaprak arkasina gecme (z_index) sistemi aynen calismaya devam eder.
##
## Model: "Betta Splendens" - BlueMesh (sketchfab.com/VapTor), CC-BY-4.0.
## 53 kemik + "Take 01" yuzgec animasyonu. Animasyon hizi yuzme hizina
## baglanir; donerken omurga kemikleri ek olarak kodla bukulur.
##
## Saat optimizasyonu: dahili cozunurluk, MSAA ve normal harita grafik
## profiline (Ayarlar) gore secilir; oyun arka plandayken cizim durdurulur.

const MODEL := preload("res://modeller/betta_splendens.glb")
const ANIMASYON := "Take 01"
# Modeli ~1 birim boya getirir ve govde merkezini donme noktasina alir.
const OLCEK := 0.165
const MERKEZ := Vector3(0.0, 0.16, -0.15)
# Omurga: govdeden kuyruga (Bone.002 -> Bone.005)
const OMURGA := ["Bone.002_Armature", "Bone.003_Armature", "Bone.004_Armature", "Bone.005_Armature"]
# Balik Sprite2D olcekleri bu dahili boyuta gore ayarlanmisti.
const REFERANS_BOYUT := 192.0

var pivot := Node3D.new()
var iskelet: Skeleton3D
var oynatici: AnimationPlayer
var omurga_kemikleri: Array[int] = []
var bukulme_ekseni := Vector3.UP
var yalpa := 0.0
var bukulme := 0.0
var onceki_sapma := 0.0
var malzemeler: Array[BaseMaterial3D] = []
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

	# Yukaridan gelen gunes isigi (arka plandaki isik huzmeleriyle uyumlu).
	# Gercek zamanli golge yok: saatte en pahali 3B islemlerinden biri.
	var isik := DirectionalLight3D.new()
	isik.shadow_enabled = false
	isik.rotation_degrees = Vector3(-62.0, 20.0, 0.0)
	isik.light_energy = 1.1
	isik.light_color = Color(1.0, 0.97, 0.9)
	add_child(isik)

	var kamera := Camera3D.new()
	kamera.fov = 25.0
	kamera.position = Vector3(0.0, 0.0, 2.9)
	add_child(kamera)

	add_child(pivot)
	var model: Node3D = MODEL.instantiate()
	# Model +Z'ye bakiyor; Godot'un "ileri"si -Z oldugu icin 180 derece cevrilir.
	model.rotation = Vector3(0.0, PI, 0.0)
	model.scale = Vector3.ONE * OLCEK
	model.position = Vector3(MERKEZ.x, -MERKEZ.y, MERKEZ.z) * OLCEK
	pivot.add_child(model)

	# Sketchfab sahnesindeki yardimci kup cizilmesin.
	var kup := model.find_child("Cube_0", true, false)
	if kup is VisualInstance3D:
		kup.visible = false
	for ad in ["BODY_0", "EYES_0"]:
		var parca := model.find_child(ad, true, false)
		if parca is MeshInstance3D:
			parca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i in parca.mesh.get_surface_count():
				var m: Material = (parca as MeshInstance3D).get_active_material(i)
				if m is BaseMaterial3D:
					malzemeler.append(m)

	iskelet = model.find_child("Skeleton3D", true, false)
	oynatici = model.find_child("AnimationPlayer", true, false)
	for ad in OMURGA:
		var no := iskelet.find_bone(ad)
		if no >= 0:
			omurga_kemikleri.append(no)
	# Dunya "yukari" ekseni iskelet uzayinda (bukulme bunun etrafinda olur)
	bukulme_ekseni = (iskelet.global_transform.basis.inverse() * Vector3.UP).normalized()

	var anim := oynatici.get_animation(ANIMASYON)
	anim.loop_mode = Animation.LOOP_LINEAR
	oynatici.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	oynatici.play(ANIMASYON)

	_profili_uygula()
	Ayarlar.profil_degisti.connect(_profili_uygula)


func _profili_uygula() -> void:
	var boyut: int = Ayarlar.deger("balik_boyutu")
	size = Vector2i(boyut, boyut)
	msaa_3d = Ayarlar.deger("msaa")
	var normal: bool = Ayarlar.deger("normal_harita")
	for m in malzemeler:
		# Dusuk profilde pul kabartmasi (normal harita) ve AO dokusu kapanir:
		# piksel basina 2 doku okumasi daha az.
		m.normal_enabled = normal and m.normal_texture != null
		m.ao_enabled = normal and m.ao_texture != null


## Balik Sprite2D'sinin olcegi bununla carpilir (dahili cozunurluk ne olursa
## olsun balik ekranda ayni boyda gorunur).
func olcek_carpani() -> float:
	return REFERANS_BOYUT / float(size.x)


## Oyun arka plandayken / ekran kapaliyken 3B cizimi tamamen durdurur.
func etkinlestir(acik: bool) -> void:
	etkin = acik
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if acik else SubViewport.UPDATE_DISABLED


## yon: oyunun koordinatinda (x saga, y asagi, z derine). hiz: piksel/sn.
func guncelle(yon: Vector3, hiz: float, delta: float, uyuyor: bool) -> void:
	if not etkin:
		return
	# Oyun -> 3B: ekran asagisi = -Y, derinlik (cama uzak) = -Z
	var d := Vector3(yon.x, -yon.y, -yon.z)
	if d.length_squared() < 0.0001:
		d = Vector3.LEFT
	d = d.normalized()
	var sapma := atan2(-d.x, -d.z)
	var egim := clampf(asin(clampf(d.y, -1.0, 1.0)), -0.45, 0.45)

	# Donus hizi: govde C seklinde bukulur ve hafifce yana yatar
	var donus := wrapf(sapma - onceki_sapma, -PI, PI) / maxf(delta, 0.001)
	onceki_sapma = sapma
	var yumusat := minf(1.0, delta * 5.0)
	yalpa = lerpf(yalpa, clampf(-donus * 0.10, -0.30, 0.30), yumusat)
	# 4 omurga kemigi x bukulme = toplam govde kivrimi (en fazla ~1,4 rad)
	bukulme = lerpf(bukulme, clampf(-donus * 0.14, -0.35, 0.35), yumusat)
	pivot.rotation = Vector3(egim, sapma, yalpa)

	# Animasyon hizi: uyurken cok yavas, yeme giderken hizli
	var etkinlik := clampf(hiz / 66.0, 0.0, 1.0)
	var oran := 0.35 if uyuyor else lerpf(0.8, 2.6, etkinlik)

	# Omurgayi dinlenme pozuna dondur, animasyonu ilerlet, sonra bukulmeyi ekle
	for no in omurga_kemikleri:
		iskelet.reset_bone_pose(no)
	oynatici.advance(delta * oran)
	if absf(bukulme) > 0.002:
		for no in omurga_kemikleri:
			var ebeveyn := iskelet.get_bone_parent(no)
			var eksen := bukulme_ekseni
			if ebeveyn >= 0:
				eksen = (iskelet.get_bone_global_pose(ebeveyn).basis.inverse() * bukulme_ekseni).normalized()
			var poz := iskelet.get_bone_pose_rotation(no)
			iskelet.set_bone_pose_rotation(no, Quaternion(eksen, bukulme) * poz)
