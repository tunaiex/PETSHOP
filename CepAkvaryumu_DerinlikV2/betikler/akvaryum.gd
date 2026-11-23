extends Node2D
## Cep Akvaryumu — 2. asama: 2,5D derinlik, besleme, kayit ve isik.
## Bu gercek bir 3D fizik dunyasi degil; Z ekseni, boyut ve cizim sirasi ile
## saatte cok daha az pil tuketen on/arka etkisi olusturur.

const MERKEZ := Vector2(240.0, 240.0)
const KAYIT_YOLU := "user://akvaryum_kaydi.json"
const TOKLUK_BITIS_SANIYE := 10800.0 # 3 saat
const UZUN_BASMA_SANIYE := 1.0
const KAYDIRMA_ESIGI := 60.0

@onready var balik: Sprite2D = $Balik
@onready var yem_gorseli: Node2D = $Yem
@onready var gosterge: Node2D = $Gosterge

# Tokluk: 100 = tok, 0 = ac. Onceki projenin 'aclik' kaydi da okunur.
var aclik := 85.0
var isik_acik := true
var son_hesaplama_zamani := 0.0

# X sag-sol, Y yukari-asagi, Z derinlik: 0 = cam, 1 = arkadaki su.
var balik_konumu := Vector3(0.0, -20.0, 0.35)
var balik_hedefi := Vector3(-103.0, 55.0, 0.88)
var yon := Vector3(-1.0, 0.0, 0.0)
var yuzme_zamani := 0.0
var bekleme_suresi := 0.0
var hedef_sayaci := 0

var yem_var := false
var yem_hedefi := Vector3.ZERO

var basili := false
var baslangic := Vector2.ZERO
var basma_suresi := 0.0
var kaydirildi := false
var uzun_basma_yapildi := false
var etkin_parmak := -1

var kayit_sayaci := 0.0
var zaman_kontrol_sayaci := 0.0
var sensor_kontrol_sayaci := 0.0
var yer_cekimi_ortalama := Vector3.ZERO
var sensor_ilk_okuma := true
var hareket_siddeti := 0.0
var irkilme_beklemesi := 0.0
var hazir := false


func _ready() -> void:
	randomize()
	_kaydi_yukle()
	_zaman_farkini_uygula()
	Engine.max_fps = 20 if isik_acik else 6
	_baligi_gorsellestir()
	_yemi_gorsellestir()
	hazir = true


func _process(delta: float) -> void:
	zaman_kontrol_sayaci += delta
	if zaman_kontrol_sayaci >= 1.0:
		zaman_kontrol_sayaci = 0.0
		_zaman_farkini_uygula()

	if basili and not kaydirildi and not uzun_basma_yapildi:
		basma_suresi += delta
		if basma_suresi >= UZUN_BASMA_SANIYE:
			uzun_basma_yapildi = true
			isik_acik = not isik_acik
			Engine.max_fps = 20 if isik_acik else 6
			_yemi_gorsellestir()
			_kaydet()

	if isik_acik:
		yuzme_zamani += delta
		_sensoru_kontrol_et(delta)
		_baligi_hareket_ettir(delta)
		_baligi_gorsellestir()
		_yemi_gorsellestir()
	else:
		# Isik kapaliyken yuzme ve sensor okumasi durur.
		_baligi_gorsellestir()

	kayit_sayaci += delta
	if kayit_sayaci >= 15.0:
		kayit_sayaci = 0.0
		_kaydet()
	gosterge.queue_redraw()


func _input(olay: InputEvent) -> void:
	if olay is InputEventScreenTouch:
		if olay.pressed and not basili:
			etkin_parmak = olay.index
			_basmayi_baslat(olay.position)
		elif not olay.pressed and olay.index == etkin_parmak:
			_basmayi_bitir(olay.position)
			etkin_parmak = -1
	elif olay is InputEventScreenDrag:
		if olay.index == etkin_parmak:
			_kaydirma_kontrol(olay.position)
	elif not OS.has_feature("mobile"):
		if olay is InputEventMouseButton and olay.button_index == MOUSE_BUTTON_LEFT:
			if olay.pressed:
				_basmayi_baslat(olay.position)
			else:
				_basmayi_bitir(olay.position)
		elif olay is InputEventMouseMotion and basili:
			_kaydirma_kontrol(olay.position)

	# Bilgisayarda derinlik deneyini gostermek icin:
	if olay is InputEventKey and olay.pressed and not olay.echo:
		if olay.keycode == KEY_Z:
			balik_hedefi = Vector3(-104.0, 55.0, 0.90) # tasin arkasi
			bekleme_suresi = 0.0
		elif olay.keycode == KEY_X:
			balik_hedefi = Vector3(25.0, 0.0, 0.10) # kameraya yakin
			bekleme_suresi = 0.0


func _basmayi_baslat(konum: Vector2) -> void:
	if konum.distance_to(MERKEZ) > 205.0:
		return
	basili = true
	baslangic = konum
	basma_suresi = 0.0
	kaydirildi = false
	uzun_basma_yapildi = false


func _kaydirma_kontrol(konum: Vector2) -> void:
	if basili and konum.distance_to(baslangic) >= KAYDIRMA_ESIGI:
		kaydirildi = true
		# Cam silme sonraki asamada eklenecek.


func _basmayi_bitir(konum: Vector2) -> void:
	if not basili:
		return
	_kaydirma_kontrol(konum)
	if not kaydirildi and not uzun_basma_yapildi and basma_suresi < UZUN_BASMA_SANIYE:
		_yem_birak(konum)
	basili = false


func _yem_birak(ekran_konumu: Vector2) -> void:
	if not isik_acik:
		return
	var nokta := _ekranda_sinirla(ekran_konumu, 143.0)
	# Yemler orta-arka sularda da bulunabilir: baligin Z ekseninde gitmesi gerekir.
	var yeni_derinlik := randf_range(0.23, 0.69)
	yem_hedefi = _sinirla(Vector3(nokta.x - 240.0, nokta.y - 240.0, yeni_derinlik))
	yem_var = true
	balik_hedefi = yem_hedefi
	bekleme_suresi = 0.0
	_yemi_gorsellestir()


func _baligi_hareket_ettir(delta: float) -> void:
	irkilme_beklemesi = maxf(0.0, irkilme_beklemesi - delta)
	if bekleme_suresi > 0.0 and not yem_var:
		bekleme_suresi -= delta
		return

	var fark: Vector3 = balik_hedefi - balik_konumu
	var mesafe: float = fark.length()
	if mesafe < 8.0:
		if yem_var:
			yem_var = false
			aclik = clampf(aclik + 22.0, 0.0, 100.0)
			_kaydet()
		else:
			bekleme_suresi = randf_range(0.35, 1.0)
		_rastgele_hedef_sec()
		return

	# 3B koordinatta gercekten ilerler: yana, yukariya ve derine.
	var hiz := 66.0 if yem_var else 32.0
	hiz += 7.0 * hareket_siddeti
	var adim := fark.normalized() * minf(mesafe, hiz * delta)
	balik_konumu = _sinirla(balik_konumu + adim)
	yon = yon.lerp(fark.normalized(), minf(1.0, delta * 2.4)).normalized()


func _rastgele_hedef_sec() -> void:
	hedef_sayaci += 1
	# Her birkac hedefte kaya / kutuk arkasindan gecmesini garanti eder.
	if hedef_sayaci % 5 == 1:
		balik_hedefi = Vector3(-102.0, 56.0, 0.88)
	elif hedef_sayaci % 5 == 3:
		balik_hedefi = Vector3(103.0, 56.0, 0.82)
	elif hedef_sayaci % 5 == 4:
		balik_hedefi = Vector3(32.0, -42.0, 0.10)
	else:
		balik_hedefi = _sinirla(Vector3(
			randf_range(-132.0, 132.0),
			randf_range(-88.0, 85.0),
			randf_range(0.10, 0.94)
		))


func _sinirla(nokta: Vector3) -> Vector3:
	var sonuc := Vector3(clampf(nokta.x,-138.0,138.0), clampf(nokta.y,-94.0,87.0), clampf(nokta.z,0.07,0.97))
	var xy := Vector2(sonuc.x, sonuc.y)
	if xy.length() > 145.0:
		xy = xy.normalized() * 145.0
		sonuc.x = xy.x
		sonuc.y = xy.y
	return sonuc


func _ekranda_sinirla(nokta: Vector2, yaricap: float) -> Vector2:
	var fark := nokta - MERKEZ
	if fark.length() > yaricap:
		return MERKEZ + fark.normalized() * yaricap
	return nokta


func _baligi_gorsellestir() -> void:
	# Arkadaki balik daha kucuk ve mavimsi gozukur.
	var derinlik := balik_konumu.z
	var boyut: float = lerpf(0.66, 0.43, derinlik)
	var solukluk: float = lerpf(1.0, 0.77, derinlik)
	balik.modulate = Color(solukluk * 0.91, solukluk * 0.98, 1.0, 1.0)
	balik.position = MERKEZ + Vector2(
		balik_konumu.x,
		balik_konumu.y - derinlik * 14.0 + sin(yuzme_zamani * 2.0) * 1.7
	)
	balik.scale = Vector2(boyut, boyut * (1.0 + sin(yuzme_zamani * 3.7) * 0.01))
	# 16 farkli turntable acisi: sadece yatay cevirme degil, on/arka yonu da var.
	var aci := atan2(yon.z, yon.x)
	balik.frame = posmod(int(round((aci + PI) / TAU * 16.0)), 16)
	balik.rotation = clampf(yon.y * 0.16, -0.15, 0.15)

	# Cizim sirasi = Z. Z>0.64: tasin/kutugun arkasinda;
	# ortada: tasin onunde ama kutugun ve yapraklarin arkasinda;
	# onde: butun dekorun onunde.
	if derinlik > 0.64:
		balik.z_index = 0
	elif derinlik > 0.33:
		balik.z_index = 3
	else:
		balik.z_index = 7


func _yemi_gorsellestir() -> void:
	yem_gorseli.visible = yem_var and isik_acik
	if yem_var:
		# Yemin de derinlikte tasin/kutugun arkasinda kalmasini saglariz.
		yem_gorseli.z_index = 0 if yem_hedefi.z > 0.64 else (3 if yem_hedefi.z > 0.33 else 8)
		yem_gorseli.position = MERKEZ + Vector2(yem_hedefi.x, yem_hedefi.y - yem_hedefi.z * 14.0)
		yem_gorseli.scale = Vector2.ONE * lerpf(1.0, 0.65, yem_hedefi.z)


func _sensoru_kontrol_et(delta: float) -> void:
	# Sensor yalnizca oyun gorunurken, yaklasik saniyede bes kez okunur.
	if not OS.has_feature("mobile"):
		return
	sensor_kontrol_sayaci += delta
	if sensor_kontrol_sayaci < 0.20:
		return
	sensor_kontrol_sayaci = 0.0
	var olcum := Input.get_accelerometer()
	if olcum.length_squared() < 0.01:
		return
	if sensor_ilk_okuma:
		yer_cekimi_ortalama = olcum
		sensor_ilk_okuma = false
		return
	yer_cekimi_ortalama = yer_cekimi_ortalama.lerp(olcum, 0.13)
	var sarsinti := (olcum - yer_cekimi_ortalama).length()
	hareket_siddeti = lerpf(hareket_siddeti, clampf((sarsinti - 0.9) / 4.0, 0.0, 1.0), 0.30)
	if sarsinti > 5.8 and irkilme_beklemesi <= 0.0 and not yem_var:
		# Ani hareket: canli bitkilerin ve kayanin arkasina saklanir.
		balik_hedefi = Vector3(-108.0, 54.0, 0.91)
		bekleme_suresi = 0.0
		irkilme_beklemesi = 10.0


func _zaman_farkini_uygula() -> void:
	var simdi := Time.get_unix_time_from_system()
	if son_hesaplama_zamani > 0.0:
		var gecen_saniye := maxf(0.0, simdi - son_hesaplama_zamani)
		aclik = clampf(aclik - gecen_saniye * 100.0 / TOKLUK_BITIS_SANIYE, 0.0, 100.0)
	son_hesaplama_zamani = simdi


func _kaydi_yukle() -> void:
	son_hesaplama_zamani = Time.get_unix_time_from_system()
	if not FileAccess.file_exists(KAYIT_YOLU):
		return
	var dosya := FileAccess.open(KAYIT_YOLU, FileAccess.READ)
	if dosya == null:
		return
	var kayit = JSON.parse_string(dosya.get_as_text())
	if kayit is Dictionary:
		aclik = clampf(float(kayit.get("aclik", 85.0)), 0.0, 100.0)
		isik_acik = bool(kayit.get("isik_acik", true))
		son_hesaplama_zamani = float(kayit.get("zaman", son_hesaplama_zamani))
		if kayit.has("balik_konumu") and kayit["balik_konumu"] is Array:
			var dizi: Array = kayit["balik_konumu"]
			if dizi.size() == 3:
				balik_konumu = _sinirla(Vector3(float(dizi[0]), float(dizi[1]), float(dizi[2])))


func _kaydet() -> void:
	_zaman_farkini_uygula()
	var dosya := FileAccess.open(KAYIT_YOLU, FileAccess.WRITE)
	if dosya == null:
		push_warning("Kayit yazilamadi: " + KAYIT_YOLU)
		return
	dosya.store_string(JSON.stringify({
		"surum": 2,
		"aclik": aclik,
		"isik_acik": isik_acik,
		"zaman": son_hesaplama_zamani,
		"balik_konumu": [balik_konumu.x, balik_konumu.y, balik_konumu.z]
	}))
	dosya.flush()


func _notification(bildirim: int) -> void:
	if not hazir:
		return
	if bildirim == NOTIFICATION_APPLICATION_PAUSED or bildirim == NOTIFICATION_WM_CLOSE_REQUEST or bildirim == NOTIFICATION_WM_GO_BACK_REQUEST:
		_kaydet()
	elif bildirim == NOTIFICATION_APPLICATION_RESUMED:
		_zaman_farkini_uygula()
		Engine.max_fps = 20 if isik_acik else 6
		_kaydet()


func _exit_tree() -> void:
	if hazir:
		_kaydet()
