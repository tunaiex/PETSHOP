extends Node2D
## Cep Akvaryumu — 3. asama: gercek 3B betta, 2,5D derinlik, besleme, kayit ve isik.
## Balik gercek 3B model olarak kucuk bir SubViewport'ta (Balik3D) cizilir;
## akvaryum dekoru 2B katmandir. On/arka etkisi Z ekseni, boyut ve cizim
## sirasi ile saglanir; tam 3B sahneye gore saatte daha az pil tuketir.
##
## Galaxy Watch 8 (Wear OS): 480x480 tasarim, 438x438 icin orantili olcek.
## Dokunma: kisa = yem, 1 sn = isik, >60 px kaydirma = cam silme,
## kenarda tam tur dairesel kaydirma / cerceveyi 12 tik cevirme = su degisimi.
## Bakim (yosun, su, mutluluk, kopuk yuvasi): betikler/bakim.gd

signal cam_temizlendi(baslangic: Vector2, bitis: Vector2)
signal menu_adimi(yon: int)
signal su_degistirildi

const MERKEZ := Vector2(240.0, 240.0)
const KAYIT_YOLU := "user://akvaryum_kaydi.json"
const TOKLUK_BITIS_SANIYE := 10800.0 # 3 saat
const UZUN_BASMA_SANIYE := 1.0
const KAYDIRMA_ESIGI := 60.0
const DOKUNMA_TOLERANSI := 18.0   # bu kadar kayan parmak hala "dokunma / basili tutma"
const DOKUNMA_YARICAPI := 236.0   # ekranin neredeyse tamami dokunmaya acik
const KENAR_YARICAPI := 165.0     # dairesel kaydirma bu halkada baslar
const DAIRE_ADIM := deg_to_rad(30.0)  # her 30 derecelik daire hareketi = 1 menu adimi
const DAIRE_ESIGI := deg_to_rad(45.0) # bundan azsa dairesel kaydirma sayilmaz
# Derinlik (z: 0..1) piksele cevrilirken kullanilir. Boylece balik one / arkaya
# da yuzer, U donusunde kameraya ya da arkaya bakarak 3B doner.
const DERINLIK_PIKSEL := 260.0
const DONUS_HIZI := 2.4        # rad/sn, normal yuzme
const DONUS_HIZI_YEM := 3.6    # rad/sn, yeme giderken
const MAKS_EGIM := 0.55        # yukari / asagi en fazla egim (rad)
const TOK_ESIGI := 95.0        # bundan tokken balik yemi yemez, yem dibe coker
const UYKU_NOKTASI := Vector3(-95.0, 60.0, 0.5)  # isik kapaninca bitkilerin yanina gider
const CERCEVE_SU_TIK := 12     # cerceveyi bu kadar tik cevirmek = su degisimi

@onready var balik: Sprite2D = $Balik
@onready var balik_3d: SubViewport = $Balik3D
@onready var yem_gorseli: Node2D = $Yem
@onready var gosterge: Node2D = $Gosterge
@onready var bakim: Node = $Bakim

# Tokluk: 100 = tok, 0 = ac. Onceki projenin 'aclik' kaydi da okunur.
var aclik := 85.0
var isik_acik := true
var son_hesaplama_zamani := 0.0

# X sag-sol, Y yukari-asagi, Z derinlik: 0 = cam, 1 = arkadaki su.
var balik_konumu := Vector3(0.0, -20.0, 0.35)
var balik_hedefi := Vector3(-103.0, 55.0, 0.88)
var yon := Vector3(-1.0, 0.0, 0.0)   # x saga, y asagi, z derine (piksel olcekli)
var sapma := PI                       # yatay yon acisi: 0 = saga, PI = sola, PI/2 = derine
var egim := 0.0                       # dikey: + = asagi
var yuzme_zamani := 0.0
var bekleme_suresi := 0.0
var anlik_hiz := 0.0
var hedef_sayaci := 0

var yem_var := false
var yem_hedefi := Vector3.ZERO

var basili := false
var baslangic := Vector2.ZERO
var basma_suresi := 0.0
var kaydirildi := false
var uzun_basma_yapildi := false
var etkin_parmak := -1
var son_konum := Vector2.ZERO
var daire_acisi := 0.0         # kenarda toplam donulen aci (rad, isaretli)
var daire_bildirilen := 0      # menuye bildirilen adim sayisi
var kenarda_kaldi := false
var yol := PackedVector2Array()  # parmagin izi (cam silme icin)
var silme_aktif := false
var su_degisti_bu_hareket := false
var cerceve_tik := 0
var cerceve_zaman := 0.0
var su_degisim_ilerleme := 0.0   # 0..1, gostergede halka olarak cizilir
var kameraya_bak := 0.0          # cam parlayinca balik kameraya (cama) bakar
var cama_geliyor := false

var kayit_sayaci := 0.0
var zaman_kontrol_sayaci := 0.0
var sensor_kontrol_sayaci := 0.0
var yer_cekimi_ortalama := Vector3.ZERO
var sensor_ilk_okuma := true
var hareket_siddeti := 0.0
var irkilme_beklemesi := 0.0
var sarsinti_sayaci := 0
var jiroskop_suzgec := Vector3.ZERO
var su_akintisi := 0.0         # bilek donusunden gelen yatay su itmesi (-1..1)
var odakta := true             # uygulama on planda mi (degilse 3B ve sensor durur)
var hazir := false


func _ready() -> void:
	randomize()
	balik.texture = balik_3d.get_texture()
	_kaydi_yukle()
	_zaman_farkini_uygula()
	_fps_ayarla()
	Ayarlar.profil_degisti.connect(_fps_ayarla)
	bakim.cam_parladi.connect(_cama_gel)
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
			if not isik_acik and yem_var:
				# Isik kapanirken suda kalan yem dibe coker.
				yem_var = false
				bakim.artik_ekle(yem_gorseli.position)
			_fps_ayarla()
			_yemi_gorsellestir()
			_kaydet()

	if not odakta:
		return

	cerceve_zaman = maxf(0.0, cerceve_zaman - delta)
	if cerceve_zaman <= 0.0 and not basili:
		cerceve_tik = 0
		su_degisim_ilerleme = 0.0

	if isik_acik:
		yuzme_zamani += delta
		_sensoru_kontrol_et(delta)
		_baligi_hareket_ettir(delta)
		bakim.kare(delta)
		_baligi_gorsellestir()
		_yemi_gorsellestir()
	else:
		# Isik kapali: balik yavasca bitkilerin yanina gidip orada uyur.
		_baligi_hareket_ettir(delta, true)
		_baligi_gorsellestir()
	balik_3d.guncelle(yon, anlik_hiz, delta, not isik_acik)

	kayit_sayaci += delta
	if kayit_sayaci >= 15.0:
		kayit_sayaci = 0.0
		_kaydet()
	gosterge.queue_redraw()


func _fps_ayarla() -> void:
	Engine.max_fps = int(Ayarlar.deger("fps" if isik_acik else "gece_fps"))


func _input(olay: InputEvent) -> void:
	# Not: Konumlar 480x480 tasarim koordinatindadir; 438x438 saatte de
	# Godot olcekleme (canvas_items) sayesinde ayni kalir.
	if olay is InputEventScreenTouch:
		if olay.pressed and not basili:
			etkin_parmak = olay.index
			_basmayi_baslat(olay.position)
		elif not olay.pressed and olay.index == etkin_parmak:
			_basmayi_bitir(olay.position)
			etkin_parmak = -1
	elif olay is InputEventScreenDrag:
		if olay.index == etkin_parmak:
			_surukle(olay.position)
	elif olay is InputEventMouseButton and olay.pressed and olay.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# Galaxy Watch cercevesi (bezel / doner cerceve) Android'de fare
		# tekerlegi olarak gelir: ileride menu secimi icin.
		_menu_adimi(1 if olay.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		_cerceve_tik()
	elif not OS.has_feature("mobile"):
		if olay is InputEventMouseButton and olay.button_index == MOUSE_BUTTON_LEFT:
			if olay.pressed:
				_basmayi_baslat(olay.position)
			else:
				_basmayi_bitir(olay.position)
		elif olay is InputEventMouseMotion and basili:
			_surukle(olay.position)

	# Bilgisayarda derinlik deneyini gostermek icin:
	if olay is InputEventKey and olay.pressed and not olay.echo:
		if olay.keycode == KEY_Z:
			balik_hedefi = Vector3(-104.0, 66.0, 0.90) # tasin arkasi
			bekleme_suresi = 0.0
		elif olay.keycode == KEY_X:
			balik_hedefi = Vector3(25.0, 0.0, 0.10) # kameraya yakin
			bekleme_suresi = 0.0
		elif olay.keycode == KEY_T and not OS.has_feature("mobile"):
			# Test: 1 saat ileri sar
			son_hesaplama_zamani -= 3600.0
			_zaman_farkini_uygula()


func _basmayi_baslat(konum: Vector2) -> void:
	if konum.distance_to(MERKEZ) > DOKUNMA_YARICAPI:
		return
	basili = true
	baslangic = konum
	son_konum = konum
	basma_suresi = 0.0
	kaydirildi = false
	uzun_basma_yapildi = false
	daire_acisi = 0.0
	daire_bildirilen = 0
	kenarda_kaldi = konum.distance_to(MERKEZ) >= KENAR_YARICAPI
	yol = PackedVector2Array([konum])
	silme_aktif = false
	su_degisti_bu_hareket = false


func _surukle(konum: Vector2) -> void:
	if not basili:
		return
	# Parmak biraz kaydiysa artik dokunma / uzun basma sayilmaz.
	if konum.distance_to(baslangic) > DOKUNMA_TOLERANSI:
		kaydirildi = true
	# Kenar halkasinda kalan hareketin merkez etrafindaki acisini topla.
	if konum.distance_to(MERKEZ) < KENAR_YARICAPI - 25.0:
		kenarda_kaldi = false
	daire_acisi += wrapf((konum - MERKEZ).angle() - (son_konum - MERKEZ).angle(), -PI, PI)
	son_konum = konum
	yol.append(konum)
	if kenarda_kaldi and absf(daire_acisi) >= DAIRE_ESIGI:
		var adim := int(daire_acisi / DAIRE_ADIM)
		while daire_bildirilen != adim:
			var y := signi(adim - daire_bildirilen)
			daire_bildirilen += y
			_menu_adimi(y)
		# Kenarda tam tur = su degisimi (pompa). Ilerleme halkada gorunur.
		su_degisim_ilerleme = clampf(absf(daire_acisi) / TAU, 0.0, 1.0)
		if su_degisim_ilerleme >= 1.0 and not su_degisti_bu_hareket:
			su_degisti_bu_hareket = true
			_su_degistir()
	elif not kenarda_kaldi:
		su_degisim_ilerleme = 0.0
		# Cam silme: parmak 60 px'i gecince parmagin altindaki yosun canli silinir.
		if silme_aktif:
			_cam_sil(yol.slice(yol.size() - 2))
		elif konum.distance_to(baslangic) >= KAYDIRMA_ESIGI:
			silme_aktif = true
			_cam_sil(yol)


func _basmayi_bitir(konum: Vector2) -> void:
	if not basili:
		return
	_surukle(konum)
	basili = false
	if uzun_basma_yapildi:
		return  # isik zaten degisti; birakinca yem atilmaz
	if kenarda_kaldi and absf(daire_acisi) >= DAIRE_ESIGI:
		return  # dairesel kaydirma: su degisimi / menu (cam silme ile karismaz)
	if silme_aktif or konum.distance_to(baslangic) >= KAYDIRMA_ESIGI:
		if not silme_aktif:
			_cam_sil(yol)  # kenarda baslayip duz giden kaydirma
		cam_temizlendi.emit(baslangic, konum)
	elif not kaydirildi and basma_suresi < UZUN_BASMA_SANIYE:
		_yem_birak(konum)
	# Aradaki durum (18-60 px kayma): bilincli olarak hicbir sey yapmaz.


func _cam_sil(noktalar: PackedVector2Array) -> void:
	if bakim.cami_sil(noktalar) > 0:
		_titret(20)  # her tamamen silinen lekede minik titresim


func _cerceve_tik() -> void:
	# Cerceveyi 4 sn icinde 12 tik cevirmek su degisimi yapar.
	cerceve_tik += 1
	cerceve_zaman = 4.0
	su_degisim_ilerleme = clampf(float(cerceve_tik) / CERCEVE_SU_TIK, 0.0, 1.0)
	if cerceve_tik >= CERCEVE_SU_TIK:
		cerceve_tik = 0
		_su_degistir()


func _su_degistir() -> void:
	bakim.su_degistir()
	su_degisim_ilerleme = 0.0
	_titret(120)
	su_degistirildi.emit()
	_kaydet()


func _cama_gel() -> void:
	# Tertemiz camda kendi yansimasini gorur: cama gelip sana bakar.
	if not isik_acik or yem_var:
		return
	balik_hedefi = Vector3(0.0, -15.0, 0.07)
	bekleme_suresi = 0.0
	cama_geliyor = true


func _menu_adimi(yon_: int) -> void:
	# Dairesel kaydirma ve cerceve icin ayrildi; menu henuz yok.
	menu_adimi.emit(yon_)


func _yem_birak(ekran_konumu: Vector2) -> void:
	if not isik_acik:
		return
	var nokta := _ekranda_sinirla(ekran_konumu, 143.0)
	if aclik >= TOK_ESIGI:
		# Tok balik yemi umursamaz; yem dibe coker ve suyu kirletir.
		bakim.artik_ekle(nokta)
		return
	# Yemler orta-arka sularda da bulunabilir: baligin Z ekseninde gitmesi gerekir.
	var yeni_derinlik := randf_range(0.23, 0.69)
	yem_hedefi = _sinirla(Vector3(nokta.x - 240.0, nokta.y - 240.0, yeni_derinlik))
	yem_var = true
	balik_hedefi = yem_hedefi
	bekleme_suresi = 0.0
	_yemi_gorsellestir()


func _baligi_hareket_ettir(delta: float, uyku := false) -> void:
	irkilme_beklemesi = maxf(0.0, irkilme_beklemesi - delta)
	anlik_hiz = lerpf(anlik_hiz, 0.0, minf(1.0, delta * 3.0))
	if uyku:
		balik_hedefi = UYKU_NOKTASI
		cama_geliyor = false
		kameraya_bak = 0.0
	elif bekleme_suresi > 0.0 and not yem_var:
		bekleme_suresi -= delta
		if kameraya_bak > 0.0:
			# Cama donup bakar (yuzu kameraya: sapma = -PI/2).
			kameraya_bak -= delta
			var donus := DONUS_HIZI * delta
			sapma = wrapf(sapma + clampf(wrapf(-PI / 2.0 - sapma, -PI, PI), -donus, donus), -PI, PI)
			egim = move_toward(egim, 0.0, donus)
			yon = Vector3(cos(egim) * cos(sapma), sin(egim), cos(egim) * sin(sapma))
		return

	var fark: Vector3 = balik_hedefi - balik_konumu
	fark.z *= DERINLIK_PIKSEL
	var mesafe: float = fark.length()
	if uyku and mesafe < 8.0:
		return  # uyku yerine vardi; yuzgecler yavasca kipirdar
	if mesafe < 8.0:
		if cama_geliyor and not yem_var:
			cama_geliyor = false
			kameraya_bak = 3.0
			bekleme_suresi = 3.0
			return
		if yem_var:
			yem_var = false
			aclik = clampf(aclik + 22.0, 0.0, 100.0)
			_titret(60)
			_kaydet()
		else:
			bekleme_suresi = randf_range(0.35, 1.0)
		_rastgele_hedef_sec()
		return

	# Gercek balik gibi: once burnunu hedefe cevirir (sinirli donus hizi),
	# sonra baktigi yone dogru yuzer. Ters yondeki hedefe anlik ayna
	# cevirmesi yerine kameraya ya da arkaya bakarak U donusu yapar.
	var hedef_sapma := atan2(fark.z, fark.x)
	var hedef_egim := clampf(atan2(fark.y, Vector2(fark.x, fark.z).length()), -MAKS_EGIM, MAKS_EGIM)
	var maks_donus := (DONUS_HIZI_YEM if yem_var else DONUS_HIZI) * delta
	sapma = wrapf(sapma + clampf(wrapf(hedef_sapma - sapma, -PI, PI), -maks_donus, maks_donus), -PI, PI)
	egim += clampf(hedef_egim - egim, -maks_donus * 0.7, maks_donus * 0.7)
	yon = Vector3(cos(egim) * cos(sapma), sin(egim), cos(egim) * sin(sapma))

	# Hedefe bakmiyorsa yavaslar (yerinde doner), boylece hedefin etrafinda
	# daire cizip durmaz.
	var hiz := 66.0 if yem_var else 32.0
	hiz += 7.0 * hareket_siddeti
	if uyku:
		hiz = 16.0
	elif not yem_var:
		hiz *= bakim.hiz_carpani()  # mutsuz balik durgun yuzer
	hiz *= clampf(yon.dot(fark / mesafe), 0.12, 1.0)
	var yol := minf(mesafe, hiz * delta)
	var adim := Vector3(yon.x, yon.y, yon.z / DERINLIK_PIKSEL) * yol
	balik_konumu = _sinirla(balik_konumu + adim)
	anlik_hiz = yol / maxf(delta, 0.001)


func _rastgele_hedef_sec() -> void:
	hedef_sayaci += 1
	# Her birkac hedefte kaya / kutuk arkasindan gecmesini garanti eder.
	if hedef_sayaci % 5 == 1:
		balik_hedefi = Vector3(-102.0, 66.0, 0.88)
	elif hedef_sayaci % 5 == 3:
		balik_hedefi = Vector3(100.0, 84.0, 0.84)
	elif hedef_sayaci % 5 == 4:
		balik_hedefi = Vector3(32.0, -42.0, 0.10)
	elif bakim.yuva > 0.2 and hedef_sayaci % 5 == 2:
		# Mutlu erkek betta kopuk yuvasina ugrar.
		balik_hedefi = Vector3(randf_range(70.0, 110.0), -90.0, 0.35)
	else:
		var y_alt := -88.0
		if bakim.mutluluk < 35.0:
			y_alt = 10.0  # mutsuz balik dipte, durgun kalir
		balik_hedefi = _sinirla(Vector3(
			randf_range(-132.0, 132.0),
			randf_range(y_alt, 85.0),
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
	var boyut: float = lerpf(0.82, 0.54, derinlik)
	var solukluk: float = lerpf(1.0, 0.77, derinlik)
	# Mutsuz balik solgun gorunur.
	solukluk *= lerpf(0.72, 1.0, clampf(bakim.mutluluk / 60.0, 0.0, 1.0))
	balik.modulate = Color(solukluk * 0.91, solukluk * 0.98, 1.0, 1.0)
	balik.position = MERKEZ + Vector2(
		balik_konumu.x,
		balik_konumu.y - derinlik * 14.0 + sin(yuzme_zamani * 2.0) * 1.7
	)
	boyut *= balik_3d.olcek_carpani()
	balik.scale = Vector2(boyut, boyut)
	# Yon ve egim artik 3B modelin kendisinde (betikler/balik_3d.gd).

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
	# Sensorler yalnizca oyun on plandayken ve isik acikken, saniyede ~10 kez
	# okunur. Android'de Godot, uygulama arka plana gecince sensorleri kapatir.
	if not OS.has_feature("mobile"):
		return
	sensor_kontrol_sayaci += delta
	if sensor_kontrol_sayaci < 0.10:
		return
	var aralik := sensor_kontrol_sayaci
	sensor_kontrol_sayaci = 0.0

	# --- Ivmeolcer: yurume ve sarsinti ---
	var olcum := Input.get_accelerometer()
	if olcum.length_squared() > 0.01:
		if sensor_ilk_okuma:
			yer_cekimi_ortalama = olcum
			sensor_ilk_okuma = false
		else:
			yer_cekimi_ortalama = yer_cekimi_ortalama.lerp(olcum, 0.08)
			var sarsinti := (olcum - yer_cekimi_ortalama).length()
			# Yurume: yavasca artan / azalan hareket siddeti (ani tepe etkisiz)
			hareket_siddeti = lerpf(hareket_siddeti, clampf((sarsinti - 0.9) / 4.0, 0.0, 1.0), 0.15)
			# Irkilme: tek bir bilek hareketi degil, art arda 3 olcumde (~0,3 sn)
			# guclu sarsinti gerekir; sonra 10 sn bekleme.
			sarsinti_sayaci = sarsinti_sayaci + 1 if sarsinti > 5.8 else 0
			if sarsinti_sayaci >= 3 and irkilme_beklemesi <= 0.0 and not yem_var:
				balik_hedefi = Vector3(-108.0, 66.0, 0.91)
				bekleme_suresi = 0.0
				irkilme_beklemesi = 10.0
				sarsinti_sayaci = 0

	# --- Jiroskop: bilek donusu suyu hafifce iter ---
	var jiro := Input.get_gyroscope()
	jiroskop_suzgec = jiroskop_suzgec.lerp(jiro, 0.35)
	# Kolun ekseni etrafinda donus (saatte genelde X ekseni). 0,4 rad/sn
	# altindaki kucuk hareketler yok sayilir.
	var donus := jiroskop_suzgec.x
	var itme := 0.0
	if absf(donus) > 0.4:
		itme = clampf((absf(donus) - 0.4) / 3.0, 0.0, 1.0) * signf(donus)
	su_akintisi = clampf(su_akintisi + itme * aralik * 2.0, -1.0, 1.0)
	su_akintisi = move_toward(su_akintisi, 0.0, aralik * 0.5)
	if absf(su_akintisi) > 0.01 and not yem_var:
		# Balik akintiyla birkac piksel suruklenir; hedef / mekanik degismez.
		balik_konumu = _sinirla(balik_konumu + Vector3(su_akintisi * 6.0 * aralik, 0.0, 0.0))


func _titret(sure_ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(sure_ms, 0.6)


func _zaman_farkini_uygula() -> void:
	var simdi := Time.get_unix_time_from_system()
	if son_hesaplama_zamani > 0.0:
		var gecen_saniye := maxf(0.0, simdi - son_hesaplama_zamani)
		aclik = clampf(aclik - gecen_saniye * 100.0 / TOKLUK_BITIS_SANIYE, 0.0, 100.0)
		bakim.zamani_ilerlet(gecen_saniye, aclik)
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
		if kayit.get("bakim") is Dictionary:
			bakim.yukle(kayit["bakim"])


func _kaydet() -> void:
	_zaman_farkini_uygula()
	var dosya := FileAccess.open(KAYIT_YOLU, FileAccess.WRITE)
	if dosya == null:
		push_warning("Kayit yazilamadi: " + KAYIT_YOLU)
		return
	dosya.store_string(JSON.stringify({
		"surum": 3,
		"aclik": aclik,
		"isik_acik": isik_acik,
		"zaman": son_hesaplama_zamani,
		"balik_konumu": [balik_konumu.x, balik_konumu.y, balik_konumu.z],
		"bakim": bakim.sozluk()
	}))
	dosya.flush()


func _notification(bildirim: int) -> void:
	if not hazir:
		return
	match bildirim:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Ekran kapandi / baska uygulamaya gecildi: kaydet, 3B cizimi ve
			# sensor islemeyi durdur.
			_kaydet()
			_on_planda(false)
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			# Geri tusu sistem davranisini korur (uygulamayi kapatir); once kaydet.
			_kaydet()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			# Gecen gercek sure tokluga yansitilir.
			_zaman_farkini_uygula()
			_on_planda(true)
			_kaydet()


func _on_planda(acik: bool) -> void:
	if odakta == acik:
		return
	odakta = acik
	balik_3d.etkinlestir(acik)
	basili = false
	if acik:
		_fps_ayarla()
		sensor_ilk_okuma = true  # yeniden kalibre et, sahte irkilme olmasin
		sarsinti_sayaci = 0
	else:
		Engine.max_fps = 5


func _exit_tree() -> void:
	if hazir:
		_kaydet()
