extends Node2D
## Cep Akvaryumu — 3. asama: gercek 3B betta, 2,5D derinlik, besleme, kayit ve isik.
## Balik gercek 3B model olarak kucuk bir SubViewport'ta (Balik3D) cizilir;
## akvaryum dekoru 2B katmandir. On/arka etkisi Z ekseni, boyut ve cizim
## sirasi ile saglanir; tam 3B sahneye gore saatte daha az pil tuketir.
##
## Galaxy Watch 8 (Wear OS): 480x480 tasarim, 438x438 icin orantili olcek.
## Dokunma: kisa = yem (incinin ustune = inci topla, baligin ustune = kabarma),
## 1 sn = isik, >60 px kaydirma = cam silme, cerceveyi cevirme / kenarda
## dairesel kaydirma = menu (su degisimi, magaza, bilgi, ses, grafik, FPS).
## Bilek egimi = parallax (katmanlar farkli miktarda kayar).
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
const PARALAKS_PX := 7.0      # bilek egiminde en one katmanin en fazla kaymasi
# Katman -> parallax carpani (uzak 0.35 ... cam 1.15). Balik derinligine gore.
const PARALAKS_KATMANLAR := {"ArkaPlan": 0.35, "Baloncuklar": 0.4, "Bakim/Yuva": 0.35,
	"Tas": 0.65, "Kutuk": 0.65, "Bakim/Artiklar": 0.8, "Bakim/Inciler": 0.8,
	"Yapraklar": 0.95, "Bakim/CamYosunu": 1.15, "Yasam/Kakalar": 0.8}

@onready var balik: Sprite2D = $Balik
@onready var balik_3d: SubViewport = $Balik3D
@onready var yem_gorseli: Node2D = $Yem
@onready var gosterge: Node2D = $Gosterge
@onready var bakim: Node = $Bakim
@onready var menu: Node2D = $Menu
@onready var yasam: Node = $Yasam
@onready var arka_plan: Sprite2D = $ArkaPlan
@onready var su_yuzeyi_malzeme: ShaderMaterial = $ArkaPlan.material
var kostik_gucu := 0.35          # ekrandaki guc; hedefe yumusakca yaklasir
var bitki_akintisi := 0.0

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
var kabarma_beklemesi := 0.0
var oyun_kalan := 0.0            # parmak kovalama oyunu (sn)
var oyun_noktasi := Vector2(240.0, 220.0)
var oyun_skor := 0
const OYUN_SURE := 20.0
var bakis_hedefi := -PI / 2.0   # kameraya_bak sirasinda donulecek yon
var paralaks := Vector2.ZERO     # -1..1, bilek egimi (yumusatilmis)
var paralaks_hedef := Vector2.ZERO
var egim_taban := Vector3.ZERO
var egim_paralaks := Vector2.ZERO    # yercekiminden (yavas, egim)
var jiro_paralaks := Vector2.ZERO    # jiroskoptan (aninda, sonra soner)
var calkanti := 0.0                  # 0..1 saat sallaninca su calkalanir
var _yuzey_calkanti := -1.0
var paralaks_tabanlari := {}     # dugum -> asil konum
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
	yasam.olay.connect(gosterge.bildirim)
	yasam.cagri.connect(func(_ad): _titret(90))
	yasam.evre_degisti.connect(_gorunumu_uygula)
	_kaydi_yukle()
	_zaman_farkini_uygula()
	_fps_ayarla()
	Ayarlar.profil_degisti.connect(_fps_ayarla)
	bakim.cam_parladi.connect(_cama_gel)
	menu.secildi.connect(_menu_komutu)
	for yol_ in PARALAKS_KATMANLAR:
		var d: Node2D = get_node(yol_)
		paralaks_tabanlari[d] = d.position
	# Arka plan kayinca yuvarlak ekranin kenarinda bosluk olmasin
	arka_plan.scale = Vector2.ONE * 1.02
	_gorunumu_uygula()
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
			if menu.acik:
				menu.kapat()  # menude uzun basma: menuyu kapatir
				return
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
	_kostigi_guncelle(delta)

	kabarma_beklemesi = maxf(0.0, kabarma_beklemesi - delta)
	_paralaksi_uygula(delta)

	balik.visible = yasam.evre != yasam.Evre.YUMURTA
	if yasam.isim_bekliyor and not menu.acik:
		menu.isim_sec_ac()
	if oyun_kalan > 0.0:
		oyun_kalan -= delta
		if oyun_kalan <= 0.0:
			_oyun_bitti()

	if not balik.visible:
		bakim.kare(delta)  # yumurta: balik yok, yalnizca akvaryum
	elif isik_acik:
		yuzme_zamani += delta
		_sensoru_kontrol_et(delta)
		_baligi_hareket_ettir(delta, yasam.kritik())
		bakim.kare(delta)
		_baligi_gorsellestir()
		_yemi_gorsellestir()
	else:
		# Isik kapali: balik yavasca bitkilerin yanina gidip orada uyur.
		_baligi_hareket_ettir(delta, true)
		_baligi_gorsellestir()
	if balik.visible:
		balik_3d.guncelle(yon, anlik_hiz, delta, not isik_acik)

	kayit_sayaci += delta
	if kayit_sayaci >= 15.0:
		kayit_sayaci = 0.0
		_kaydet()
	gosterge.queue_redraw()


func _kostigi_guncelle(delta: float) -> void:
	# Calkanti yavasca sakinlesir; yuzey dalgasi ve bitki sallanmasi buyur.
	calkanti = move_toward(calkanti, 0.0, delta * 0.35)
	if absf(calkanti - _yuzey_calkanti) > 0.01:
		_yuzey_calkanti = calkanti
		su_yuzeyi_malzeme.set_shader_parameter("guc", 0.0045 * (1.0 + 2.5 * calkanti))
		su_yuzeyi_malzeme.set_shader_parameter("sallanma", 0.016 * (1.0 + 1.5 * calkanti))
	# Bilek donusunden gelen akinti bitkileri o yone eger.
	if absf(su_akintisi - bitki_akintisi) > 0.01:
		bitki_akintisi = su_akintisi
		su_yuzeyi_malzeme.set_shader_parameter("akinti", bitki_akintisi)
	# Isik kapaliyken gunes yok: kostik soner. Kirli su isigi dagitir: zayiflar.
	var hedef := 0.0
	if isik_acik:
		hedef = 0.35 * lerpf(0.25, 1.0, bakim.su / 100.0)
	var yeni := move_toward(kostik_gucu, hedef, delta * 0.5)
	if absf(yeni - kostik_gucu) < 0.0001 and absf(yeni - hedef) < 0.0001 and hazir:
		return
	kostik_gucu = yeni
	su_yuzeyi_malzeme.set_shader_parameter("kostik_guc", kostik_gucu)


func _fps_ayarla() -> void:
	# Su yuzeyi dalgasi ve kostikler ayni ayara bagli (Dusuk profilde kapali).
	var efekt := bool(Ayarlar.deger("su_dalgasi"))
	arka_plan.material = su_yuzeyi_malzeme if efekt else null
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
		elif olay.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not OS.has_feature("mobile"):
			# Test: ok tuslari bilek egimini taklit eder (parallax)
			var e := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
			paralaks_hedef = (paralaks_hedef + e[olay.keycode] * 0.5).limit_length(1.0)
		elif olay.keycode == KEY_T and not OS.has_feature("mobile"):
			# Test: 1 saat ileri sar
			son_hesaplama_zamani -= 3600.0
			yasam.zaman_kaydir += 3600.0
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
	elif oyun_kalan > 0.0:
		oyun_noktasi = _ekranda_sinirla(konum, 140.0)
	elif not kenarda_kaldi and not menu.acik:
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
		return  # dairesel kaydirma: menu (cam silme ile karismaz)
	if menu.acik:
		if not kaydirildi:
			menu.sec()  # menude dokunma = sec
		return
	if oyun_kalan > 0.0:
		oyun_noktasi = _ekranda_sinirla(konum, 140.0)
		return
	if silme_aktif or konum.distance_to(baslangic) >= KAYDIRMA_ESIGI:
		if not silme_aktif:
			_cam_sil(yol)  # kenarda baslayip duz giden kaydirma
		cam_temizlendi.emit(baslangic, konum)
	elif not kaydirildi and basma_suresi < UZUN_BASMA_SANIYE:
		_dokunma(konum)
	# Aradaki durum (18-60 px kayma): bilincli olarak hicbir sey yapmaz.


## Kisa dokunma: once inci, sonra balik (kabarma), yoksa yem.
func _dokunma(konum: Vector2) -> void:
	if oyun_kalan > 0.0:
		oyun_noktasi = _ekranda_sinirla(konum, 140.0)
		return
	if bakim.inci_topla(konum):
		Ses.cal("inci")
		_titret(40)
		_kaydet()
		return
	if yasam.kaka_temizle(konum):
		Ses.cal("silme")
		_titret(25)
		_kaydet()
		return
	if not balik.visible:
		gosterge.bildirim("Yumurtalar çatlamak üzere...")
		return
	if isik_acik and not yem_var and kabarma_beklemesi <= 0.0 and _baliga_mi(konum):
		_kabar(2.5)
		return
	_yem_birak(konum)


func _baliga_mi(konum: Vector2) -> bool:
	var yaricap := balik_3d.size.x * balik.scale.x * 0.32
	return konum.distance_to(balik.position) < maxf(yaricap, 26.0)


## Kabarma (flare): balik sana doner, solungac ve yuzgeclerini acar.
func _kabar(sure: float) -> void:
	kabarma_beklemesi = sure + 2.0
	balik_3d.kabar(sure)
	# Gercek betta kabarirken yan doner: yuzgecler gorunsun diye 3/4 yan aci
	bakis_hedefi = -PI / 2.0 + (1.15 if cos(sapma) >= 0.0 else -1.15)
	kameraya_bak = sure
	bekleme_suresi = sure
	Ses.cal("kabarma")
	_titret(40)


func _cam_sil(noktalar: PackedVector2Array) -> void:
	if bakim.cami_sil(noktalar) > 0:
		_titret(20)  # her tamamen silinen lekede minik titresim
		Ses.cal("silme")


func _menu_komutu(komut: String) -> void:
	match komut:
		"su":
			_su_degistir()
			menu.kapat()
		"ilac":
			yasam.ilac_ver()
			menu.kapat()
		"nesil":
			yasam.yeni_nesil()
			menu.kapat()
		"oyna":
			menu.kapat()
			_oyun_baslat()
		"super_yem":
			if bakim.satin_al("super_yem"):
				aclik = 100.0
				Ses.cal("inci")
				_titret(40)
		"filtre":
			if bakim.satin_al("filtre"):
				Ses.cal("inci")
				_titret(40)
		"renk_0", "renk_1", "renk_2":
			var i := int(komut.substr(5))
			if bakim.renkler[i]:
				bakim.renk_sec(i)
			elif bakim.satin_al(komut):
				Ses.cal("inci")
				_titret(40)
	_kaydet()


func _oyun_baslat() -> void:
	if not balik.visible or not isik_acik:
		gosterge.bildirim("Şimdi oynayamaz")
		return
	if yasam.kritik():
		gosterge.bildirim("%s oynayamayacak kadar halsiz" % yasam.isim)
		return
	yem_var = false
	oyun_kalan = OYUN_SURE
	oyun_skor = 0
	oyun_noktasi = MERKEZ + Vector2(60.0, -30.0)
	gosterge.bildirim("Parmağını gezdir, %s ışığı kovalasın!" % yasam.isim)


func _oyun_bitti() -> void:
	oyun_kalan = 0.0
	yasam.oyun_oynandi()
	bakim.mutluluk = minf(100.0, bakim.mutluluk + 5.0)
	gosterge.bildirim("Harika! %d kez yakaladı" % oyun_skor)
	_kabar(2.5)
	_kaydet()


## Yasam durumuna gore baligin gorunusu (form, renk, hastalik, yuzgecler).
func _gorunumu_uygula() -> void:
	var g: Dictionary = yasam.gorunum()
	balik_3d.yuzgec_olcek = g["yuzgec"]
	balik_3d.kapali = g["kapali"]
	var m := balik.material as ShaderMaterial
	m.set_shader_parameter("doygunluk", g["doygunluk"])
	m.set_shader_parameter("parlaklik", g["parlaklik"])
	m.set_shader_parameter("ton", g["ton"])
	m.set_shader_parameter("benek", g["benek"])


func _su_degistir() -> void:
	bakim.su_degistir()
	Ses.cal("su")
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
	# Cerceve / kenarda dairesel kaydirma: menu kapaliysa acar, aciksa gezinir.
	menu_adimi.emit(yon_)
	if menu.acik:
		menu.adim(yon_)
	else:
		menu.ac()


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
	kameraya_bak = 0.0
	bakis_hedefi = -PI / 2.0
	Ses.cal("yem")
	_yemi_gorsellestir()


func _baligi_hareket_ettir(delta: float, uyku := false) -> void:
	irkilme_beklemesi = maxf(0.0, irkilme_beklemesi - delta)
	anlik_hiz = lerpf(anlik_hiz, 0.0, minf(1.0, delta * 3.0))
	if oyun_kalan > 0.0 and not uyku:
		balik_hedefi = _sinirla(Vector3(oyun_noktasi.x - 240.0, oyun_noktasi.y - 240.0, 0.22))
		bekleme_suresi = 0.0
		kameraya_bak = 0.0
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
			sapma = wrapf(sapma + clampf(wrapf(bakis_hedefi - sapma, -PI, PI), -donus, donus), -PI, PI)
			egim = move_toward(egim, 0.0, donus)
			yon = Vector3(cos(egim) * cos(sapma), sin(egim), cos(egim) * sin(sapma))
		return

	var fark: Vector3 = balik_hedefi - balik_konumu
	fark.z *= DERINLIK_PIKSEL
	var mesafe: float = fark.length()
	if uyku and mesafe < 8.0:
		return  # uyku yerine vardi; yuzgecler yavasca kipirdar
	if mesafe < 10.0 and oyun_kalan > 0.0:
		# Oyunda noktayi yakaladi: puan, nokta baska yere ziplar
		oyun_skor += 1
		bakim.mutluluk = minf(100.0, bakim.mutluluk + 1.5)
		Ses.cal("tik")
		_titret(20)
		oyun_noktasi = MERKEZ + Vector2(randf_range(-120.0, 120.0), randf_range(-90.0, 70.0))
		return
	if mesafe < 8.0:
		if cama_geliyor and not yem_var:
			cama_geliyor = false
			_kabar(3.0)  # yansimasini gorup kabarir
			return
		if yem_var:
			yem_var = false
			aclik = clampf(aclik + 22.0, 0.0, 100.0)
			yasam.yem_yendi()
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
	var hiz := 66.0 if (yem_var or oyun_kalan > 0.0) else 32.0
	hiz += 7.0 * hareket_siddeti
	if uyku:
		hiz = 16.0
	elif not yem_var and oyun_kalan <= 0.0:
		hiz *= bakim.hiz_carpani()  # mutsuz balik durgun yuzer
	if yasam.hasta:
		hiz *= 0.6
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
	) + paralaks * PARALAKS_PX * lerpf(0.95, 0.4, derinlik)
	boyut *= balik_3d.olcek_carpani() * bakim.boy  # yavru balik kucuk
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
		yem_gorseli.position = MERKEZ + Vector2(yem_hedefi.x, yem_hedefi.y - yem_hedefi.z * 14.0) + paralaks * PARALAKS_PX * lerpf(0.95, 0.4, yem_hedefi.z)
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

	# --- Parallax: yercekimi yonu (bilek egimi). Taban yavasca uyum saglar;
	# boylece sabit tutus her zaman ortada, yalnizca egme hareketi derinlik verir.
	var yercekimi := Input.get_gravity()
	if yercekimi.length_squared() < 0.01:
		yercekimi = yer_cekimi_ortalama
	if yercekimi.length_squared() > 0.01:
		if egim_taban == Vector3.ZERO:
			egim_taban = yercekimi
		egim_taban = egim_taban.lerp(yercekimi, minf(1.0, aralik * 0.25))
		var fark := (yercekimi - egim_taban) / 2.5
		egim_paralaks = Vector2(-fark.x, fark.y).limit_length(1.0)

	# --- Jiroskop: bilegi cevirdigin anda katmanlar o yone kayar, sonra soner.
	# Kucuk titremeler (0,15 rad/sn alti) yok sayilir.
	var j := Input.get_gyroscope()
	var jv := Vector2(j.y, j.x)
	if jv.length() > 0.15:
		jiro_paralaks += jv * aralik * 0.9
	jiro_paralaks = jiro_paralaks.lerp(Vector2.ZERO, minf(1.0, aralik * 1.6)).limit_length(1.0)
	paralaks_hedef = (egim_paralaks + jiro_paralaks).limit_length(1.0)

	# --- Calkanti: saat sallaninca su yuzeyi ve bitkiler daha cok dalgalanir
	if absf(hareket_siddeti) > 0.05:
		calkanti = maxf(calkanti, clampf(hareket_siddeti * 1.4, 0.0, 1.0))

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


## Bilek egimi -> katmanlar farkli miktarda kayar (uzak az, yakin cok).
func _paralaksi_uygula(delta: float) -> void:
	var yeni := paralaks.lerp(paralaks_hedef, minf(1.0, delta * 6.0))
	if yeni.distance_to(paralaks) < 0.002 and hazir:
		return
	paralaks = yeni
	for d in paralaks_tabanlari:
		d.position = paralaks_tabanlari[d] + paralaks * PARALAKS_PX * PARALAKS_KATMANLAR[_katman_yolu(d)]


func _katman_yolu(d: Node) -> String:
	return str(get_path_to(d))


func _titret(sure_ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(sure_ms, 0.6)


func _zaman_farkini_uygula() -> void:
	var simdi := Time.get_unix_time_from_system()
	if son_hesaplama_zamani > 0.0:
		var gecen_saniye := maxf(0.0, simdi - son_hesaplama_zamani)
		aclik = clampf(aclik - gecen_saniye * 100.0 / TOKLUK_BITIS_SANIYE, 0.0, 100.0)
		bakim.zamani_ilerlet(gecen_saniye, aclik)
		yasam.ilerlet(gecen_saniye)
		if gecen_saniye > 1800.0:
			_yokken_ozeti(gecen_saniye)
		elif hazir:
			_gorunumu_uygula()
	son_hesaplama_zamani = simdi


func _yokken_ozeti(gecen: float) -> void:
	if yasam.evre == yasam.Evre.YUMURTA:
		return
	var saat := int(gecen / 3600.0)
	var sure := ("%d saat" % saat) if saat >= 1 else ("%d dk" % int(gecen / 60.0))
	var ist: Array = yasam.ihtiyaclar()
	var metin := "%s yokken geçti. " % sure
	if ist.is_empty():
		metin += "%s iyi görünüyor" % yasam.isim
	else:
		var l := []
		for ad in ist.slice(0, 2):
			l.append(yasam.IHTIYAC_METNI[ad])
		metin += "%s: %s" % [yasam.isim, ", ".join(l)]
	gosterge.bildirim(metin)
	if hazir:
		_gorunumu_uygula()


func _kaydi_yukle() -> void:
	son_hesaplama_zamani = Time.get_unix_time_from_system()
	if not FileAccess.file_exists(KAYIT_YOLU):
		yasam.yeni_oyun()  # ilk acilis: yumurtadan baslar
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
		if kayit.get("yasam") is Dictionary:
			yasam.yukle(kayit["yasam"])
		else:
			yasam.eski_kayittan()  # yasam sistemi oncesi kayit: yetiskin balik
	else:
		yasam.yeni_oyun()


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
		"bakim": bakim.sozluk(),
		"yasam": yasam.sozluk()
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
