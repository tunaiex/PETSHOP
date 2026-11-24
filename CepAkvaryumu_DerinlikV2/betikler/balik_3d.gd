extends SubViewport
## Gercek 3B, rig'li betta: GLB modeli bu kucuk SubViewport'ta cizilir, sonuc
## 2B sahnedeki "Balik" Sprite2D'sine doku olarak verilir. Boylece kaya /
## kutuk / yaprak arkasina gecme (z_index) sistemi aynen calismaya devam eder.
##
## Model: "Betta Splendens" - BlueMesh (sketchfab.com/VapTor), CC-BY-4.0.
## 53 kemik + "Take 01" yuzgec animasyonu. Hazir animasyon govdeyi hic
## oynatmaz (omurga kemikleri sabit); bu yuzden ustune kodla bir yuzme katmani
## eklenir: govdede bastan kuyruga S dalgasi, kuyrukta gecikmeli savrulma,
## sirt / karin yuzgeclerinde dalgalanma, gogus yuzgeclerinde kurek cekme.
## Hiz arttikca dalga genisler ve hizlanir; donerken govde ayrica bukulur.
##
## Saat optimizasyonu: dahili cozunurluk, MSAA ve normal harita grafik
## profiline (Ayarlar) gore secilir; oyun arka plandayken cizim durdurulur.

const MODEL := preload("res://modeller/betta_splendens.glb")
const ANIMASYON := "Take 01"
# Modeli ~1 birim boya getirir ve govde merkezini donme noktasina alir.
const OLCEK := 0.165
const MERKEZ := Vector3(0.0, 0.16, -0.15)
# Yuzme katmaninin oynattigi kemikler: [ad, grup, s, isaret]
# s = govde boyunca konum (0 bas, 1 kuyruk yuzgeci); dalga gecikmesi buna gore.
# isaret: +1 yukari uzanan (sirt, kuyrugun ustu), -1 asagi uzanan (karin,
# kuyrugun alti); yuzgeclerin yelpaze gibi acilip kapanmasi icin.
# Gruplar: G govde (omurga), K kuyruk yuzgeci, Y sirt / karin yuzgeci,
# P gogus yuzgeci (kurek), V karin (pelvik) yuzgeci.
const YUZME_KEMIKLERI := [
	["Bone.002", "G", 0.15, 0], ["Bone.003", "G", 0.35, 0], ["Bone.004", "G", 0.55, 0], ["Bone.005", "G", 0.75, 0],
	["Bone.020", "K", 0.90, 1], ["Bone.025", "K", 1.00, 1], ["Bone.026", "K", 1.10, 1],
	["Bone.039", "K", 0.90, 1], ["Bone.040", "K", 1.00, 1], ["Bone.041", "K", 1.10, 1],
	["Bone.042", "K", 1.00, -1], ["Bone.043", "K", 1.10, -1], ["Bone.044", "K", 1.00, -1], ["Bone.045", "K", 1.10, -1],
	["Bone.018", "Y", 0.45, 1], ["Bone.021", "Y", 0.55, 1], ["Bone.019", "Y", 0.60, 1], ["Bone.023", "Y", 0.70, 1],
	["Bone.033", "Y", 0.45, -1], ["Bone.035", "Y", 0.55, -1], ["Bone.034", "Y", 0.60, -1], ["Bone.036", "Y", 0.70, -1],
	["Bone.010", "P", 0.0, 1], ["Bone.011", "P", 0.0, -1],
	["Bone.027", "V", 0.0, 0], ["Bone.028", "V", 0.0, 0],
]
# Balik Sprite2D olcekleri bu dahili boyuta gore ayarlanmisti.
const REFERANS_BOYUT := 192.0

var pivot := Node3D.new()
var iskelet: Skeleton3D
var oynatici: AnimationPlayer
var yuzme: Array = []            # [kemik_no, grup, s], ebeveynler once
var faz := 0.0                   # govde dalgasi
var kurek_faz := 0.0             # gogus yuzgecleri
var bukulme_ekseni := Vector3.UP   # balik govdesinin "yukari"si (yana dalga bunun etrafinda)
var yanal_eksen := Vector3.RIGHT   # balik govdesinin "yan"i (yuzgec acilip kapanmasi)
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
	for e in YUZME_KEMIKLERI:
		var no := iskelet.find_bone(e[0] + "_Armature")
		if no >= 0:
			yuzme.append([no, e[1], e[2], e[3]])
	yuzme.sort_custom(func(a, b): return a[0] < b[0])  # ebeveyn kemik once islenir
	# Dunya "yukari" ekseni iskelet uzayinda (bukulme bunun etrafinda olur)
	bukulme_ekseni = (iskelet.global_transform.basis.inverse() * Vector3.UP).normalized()
	yanal_eksen = (iskelet.global_transform.basis.inverse() * Vector3.RIGHT).normalized()

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
	var oran := 0.35 if uyuyor else lerpf(0.8, 2.0, etkinlik)

	# Yuzme ritmi: dalga frekansi ve genisligi hiza bagli.
	faz += delta * (2.0 if uyuyor else lerpf(5.0, 14.0, etkinlik))
	kurek_faz += delta * (4.0 if uyuyor else lerpf(9.0, 12.0, etkinlik))
	var genlik := 0.02 if uyuyor else lerpf(0.07, 0.20, etkinlik)
	var kurek := 0.15 if uyuyor else lerpf(0.45, 0.30, etkinlik)
	# Yuzgeclerin kendi duzleminde dalgalanmasi (yandan bakinca gorunen hareket).
	# Hizli yuzerken yuzgecler geriye yatar, daha az acilip kapanir.
	var yelpaze := 0.4 if uyuyor else lerpf(1.0, 0.6, etkinlik)

	# Bas, kuyruga ters yonde hafifce salinir (tum govde degil, pivot).
	pivot.rotate_object_local(Vector3.UP, -genlik * 0.35 * sin(faz))

	# Oynatilan kemikleri dinlenme pozuna dondur, hazir animasyonu ilerlet,
	# sonra yuzme katmanini ustune ekle.
	for e in yuzme:
		iskelet.reset_bone_pose(e[0])
	oynatici.advance(delta * oran)
	for e in yuzme:
		var s_: float = e[2]
		var isaret: float = e[3]
		var yana := 0.0   # yukari eksen etrafinda: S dalgasi, kurek
		var dikey := 0.0  # yan eksen etrafinda: yelpaze acilip kapanma, dalgalanma
		match e[1]:
			"G":
				yana = genlik * (0.5 + 1.0 * s_) * sin(faz - s_ * 4.0) + bukulme
			"K":
				yana = genlik * 1.0 * sin(faz - s_ * 4.0)
				dikey = yelpaze * (isaret * 0.10 * sin(faz * 0.45 - s_ * 2.0) + 0.06 * sin(faz * 0.8 - s_ * 3.0))
			"Y":
				yana = genlik * 0.9 * sin(faz - s_ * 4.0 - 0.6)
				dikey = yelpaze * isaret * 0.13 * sin(faz * 0.6 - s_ * 5.0)
			"P":
				yana = kurek * sin(kurek_faz)
				dikey = isaret * kurek * 0.6 * sin(kurek_faz + 1.2)
			"V":
				yana = 0.10 * sin(faz * 0.5)
				dikey = 0.15 * yelpaze * sin(faz * 0.5 + 1.0)
		_kemigi_dondur(e[0], yana, dikey)


## Kemigi balik govdesine gore dondurur: yana (yukari eksen) ve dikey (yan eksen).
func _kemigi_dondur(no: int, yana: float, dikey: float) -> void:
	if absf(yana) < 0.0005 and absf(dikey) < 0.0005:
		return
	var ebeveyn := iskelet.get_bone_parent(no)
	var donusum := Basis.IDENTITY
	if ebeveyn >= 0:
		donusum = iskelet.get_bone_global_pose(ebeveyn).basis.inverse()
	var q := Quaternion((donusum * bukulme_ekseni).normalized(), yana)
	if absf(dikey) >= 0.0005:
		q = Quaternion((donusum * yanal_eksen).normalized(), dikey) * q
	iskelet.set_bone_pose_rotation(no, q * iskelet.get_bone_pose_rotation(no))
