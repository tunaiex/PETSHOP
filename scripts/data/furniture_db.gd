class_name FurnitureDB
extends RefCounted
## Satın alınıp dükkâna yerleştirilebilen eşyalar.
## Tüm eşyalarda yerel +Z "ön yüz"dür (müşterinin durduğu taraf).
## size: zemindeki kaplama alanı (x genişlik, z derinlik), merkez düğüm konumudur.

const ITEMS := {
	"akvaryum_beyaz": {
		"name": "Akvaryum (beyaz dolap)", "price": 900, "cat": "akvaryum",
		"size": Vector2(1.38, 0.58), "height": 1.5,
		"desc": "130 cm cam tank + modern beyaz dolap. Kum, filtre, ısıtıcı, lamba ayrıca alınır.",
	},
	"akvaryum_ceviz": {
		"name": "Akvaryum (ceviz dolap)", "price": 1150, "cat": "akvaryum",
		"size": Vector2(1.38, 0.62), "height": 1.5,
		"desc": "130 cm cam tank + ceviz dolap. Müşteriler ahşabı sever (+çekicilik).",
		"appeal": 5,
	},
	"teraryum": {
		"name": "Kaplumbağa teraryumu", "price": 1300, "cat": "akvaryum",
		"size": Vector2(1.38, 0.58), "height": 1.5,
		"desc": "Az sulu, karası olan cam teraryum + ısı lambası. Su kaplumbağaları için.",
	},
	"tank_rafi": {
		"name": "3 katlı akvaryum rafı", "price": 450, "cat": "akvaryum",
		"size": Vector2(1.1, 0.86), "height": 2.15,
		"rack": {"model": "res://assets/models/props/akvaryum_rafi.glb", "rot": 90.0, "levels": [0.171, 0.835, 1.56], "bays": [0.0],
			"tank": Vector3(0.9, 0.48, 0.45), "slot_price": 420, "slot_cap": 8},
		"desc": "Üst üste 3 ışıklı akvaryum alır. Her kata akvaryumu ayrıca alıp koyarsın (LED lamba dahil, 8 yer).",
	},
	"tank_rafi_2": {
		"name": "İki bölmeli akvaryum rafı", "price": 780, "cat": "akvaryum",
		"size": Vector2(2.14, 0.86), "height": 2.95,
		"rack": {"model": "res://assets/models/props/akvaryum_rafi_ikili.glb", "rot": 90.0, "levels": [0.17, 0.835, 1.559, 2.223], "bays": [-0.525, 0.525],
			"tank": Vector3(0.9, 0.48, 0.45), "slot_price": 420, "slot_cap": 8},
		"desc": "Yan yana iki bölme, 4 kat: 8 ışıklı akvaryum alır. Akvaryumları ayrıca alırsın.",
	},
	"turk_akvaryum_rafi": {
		"name": "18 bölmeli akvaryum duvarı", "price": 1600, "cat": "akvaryum",
		"size": Vector2(4.25, 0.7), "height": 2.3,
		"rack": {"model": "res://assets/models/props/akvaryum_rafi_turk.glb", "rot": 0.0, "levels": [0.37, 1.03, 1.67], "bays": [-1.75, -1.05, -0.35, 0.35, 1.05, 1.75], "z": 0.02,
			"tank": Vector3(0.58, 0.5, 0.42), "slot_price": 180, "slot_cap": 4},
		"desc": "Balıkçı dükkânlarındaki gibi 6 sütun x 3 kat küçük bölmeli akvaryum duvarı. Her bölmeye ucuz küçük tank konur.",
	},
	"hamster_kafesi": {
		"name": "Hamster kafesi", "price": 650, "cat": "kafes",
		"size": Vector2(1.0, 0.58), "height": 1.4, "pen": "hamster", "pen_cap": 8,
		"desc": "Ahşap sehpa üstünde camlı hamster yuvası: talaş, çark, ev, suluk. Sadece hamster konur.",
	},
	"kus_kafesi_yesil": {
		"name": "Kuş kafesi (Yeşil)", "price": 420, "cat": "kafes",
		"size": Vector2(0.8, 0.66), "height": 1.5, "pen": "kus", "pen_cap": 12,
		"renk": [Color(0.054, 0.491, 0.205), Color(0.021, 0.238, 0.091)],
		"desc": "Ahşap sehpa üstünde tünekli kuş kafesi. Muhabbet kuşu ve papağan konur.",
	},
	"kus_kafesi_mor": {
		"name": "Kuş kafesi (Mor)", "price": 420, "cat": "kafes",
		"size": Vector2(0.8, 0.66), "height": 1.5, "pen": "kus", "pen_cap": 12,
		"renk": [Color(0.342, 0.136, 0.672), Color(0.136, 0.051, 0.314)],
		"desc": "Ahşap sehpa üstünde tünekli kuş kafesi. Muhabbet kuşu ve papağan konur.",
	},
	"kus_kafesi_pembe": {
		"name": "Kuş kafesi (Pembe)", "price": 420, "cat": "kafes",
		"size": Vector2(0.8, 0.66), "height": 1.5, "pen": "kus", "pen_cap": 12,
		"renk": [Color(0.888, 0.198, 0.423), Color(0.474, 0.078, 0.205)],
		"desc": "Ahşap sehpa üstünde tünekli kuş kafesi. Muhabbet kuşu ve papağan konur.",
	},
	"kus_kafesi_sari": {
		"name": "Kuş kafesi (Sarı)", "price": 420, "cat": "kafes",
		"size": Vector2(0.8, 0.66), "height": 1.5, "pen": "kus", "pen_cap": 12,
		"renk": [Color(0.888, 0.578, 0.07), Color(0.546, 0.323, 0.022)],
		"desc": "Ahşap sehpa üstünde tünekli kuş kafesi. Muhabbet kuşu ve papağan konur.",
	},
	"kus_kafesi_mavi": {
		"name": "Kuş kafesi (Mavi)", "price": 420, "cat": "kafes",
		"size": Vector2(0.8, 0.66), "height": 1.5, "pen": "kus", "pen_cap": 12,
		"renk": [Color(0.032, 0.202, 0.687), Color(0.015, 0.098, 0.361)],
		"desc": "Ahşap sehpa üstünde tünekli kuş kafesi. Muhabbet kuşu ve papağan konur.",
	},
	"kus_kafesi_turkuaz": {
		"name": "Kuş kafesi (Turkuaz)", "price": 420, "cat": "kafes",
		"size": Vector2(0.8, 0.66), "height": 1.5, "pen": "kus", "pen_cap": 12,
		"renk": [Color(0.025, 0.558, 0.546), Color(0.008, 0.27, 0.287)],
		"desc": "Ahşap sehpa üstünde tünekli kuş kafesi. Muhabbet kuşu ve papağan konur.",
	},
	"civciv_kafesi": {
		"name": "Civciv kafesi", "price": 480, "cat": "kafes",
		"size": Vector2(1.1, 1.1), "height": 0.65, "pen": "civciv", "pen_cap": 14,
		"desc": "Yuvarlak tel kafes, ısı lambalı. Sadece civciv konur.",
	},
	"kasa": {
		"name": "Kasa tezgâhı", "price": 700, "cat": "magaza", "max": 1,
		"size": Vector2(1.8, 0.7), "height": 0.9, "model": "checkout_counter",
		"desc": "Yazar kasalı, barkod okuyuculu tezgâh. Kasa olmadan satış yapılamaz!",
	},
	# Mağaza rafları (Retail Store paketi). shelf: katların üst yüzeyi, kat genişliği/derinliği,
	# yüz sayısı (reyon iki yüzlü) ve soğuk dolap olup olmadığı.
	"duvar_rafi_m": {
		"name": "Duvar rafı (5 kat)", "price": 320, "cat": "raf", "model": "shelf_wall",
		"size": Vector2(1.2, 0.45), "height": 2.0, "capacity": 40,
		"shelf": {"levels": [0.125, 0.475, 0.825, 1.175, 1.525], "width": 1.14, "depth": 0.4, "z": 0.0, "sides": 1, "tanks": true},
		"desc": "Duvar boyu 5 katlı raf, 40 ürün.",
	},
	"reyon": {
		"name": "Çift yüzlü reyon", "price": 420, "cat": "raf", "model": "gondola_double",
		"size": Vector2(1.26, 0.9), "height": 1.6, "capacity": 48,
		"shelf": {"levels": [0.125, 0.475, 0.825, 1.175], "width": 1.14, "depth": 0.4, "z": 0.22, "sides": 2, "tanks": true},
		"desc": "Ortaya konan iki yüzlü reyon: iki tarafına da ürün dizilir. 48 ürün.",
	},
	"reyon_basi": {
		"name": "Reyon başı", "price": 260, "cat": "raf", "model": "gondola_endcap",
		"size": Vector2(0.9, 0.6), "height": 1.7, "capacity": 16,
		"shelf": {"levels": [0.125, 0.475, 0.825, 1.175], "width": 0.84, "depth": 0.4, "z": 0.05, "sides": 1, "tanks": true},
		"desc": "Reyonun ucuna konan vitrin rafı. Kampanya ürünleri için ideal.",
	},
	"sergi_masasi": {
		"name": "Sergi masası", "price": 180, "cat": "raf", "model": "display_table",
		"size": Vector2(1.2, 0.8), "height": 0.75, "capacity": 12,
		"shelf": {"levels": [0.75], "width": 1.1, "depth": 0.6, "z": 0.0, "sides": 1},
		"desc": "Üstüne ürün sergilenen alçak masa.",
	},
	"buzdolabi": {
		"name": "Camlı buzdolabı (2 kapı)", "price": 900, "cat": "raf", "model": "fridge_glass_2door",
		"size": Vector2(1.25, 0.75), "height": 2.0, "capacity": 24,
		"shelf": {"levels": [0.36, 0.76, 1.16, 1.56], "width": 1.1, "depth": 0.45, "z": 0.0, "sides": 1, "cold": true},
		"desc": "Soğuk ve donuk ürünler için. Normal ürün konmaz.",
	},
	"dondurucu_dik": {
		"name": "Camlı dondurucu", "price": 650, "cat": "raf", "model": "upright_freezer_glass",
		"size": Vector2(0.75, 0.8), "height": 2.0, "capacity": 12,
		"shelf": {"levels": [0.36, 0.76, 1.16, 1.56], "width": 0.6, "depth": 0.45, "z": 0.0, "sides": 1, "cold": true},
		"desc": "Dik dondurucu. Donuk yemler buraya.",
	},
	"icecek_dolabi": {
		"name": "Küçük soğutucu", "price": 300, "cat": "raf", "model": "drinks_cooler",
		"size": Vector2(0.45, 0.45), "height": 0.9, "capacity": 4,
		"shelf": {"levels": [0.2, 0.5], "width": 0.32, "depth": 0.3, "z": 0.0, "sides": 1, "cold": true},
		"desc": "Tezgâh boyu küçük soğutucu.",
	},
	"sandik_dondurucu": {
		"name": "Sandık dondurucu", "price": 550, "cat": "raf", "model": "chest_freezer",
		"size": Vector2(1.5, 0.7), "height": 0.85, "capacity": 12,
		"shelf": {"levels": [0.55], "width": 1.3, "depth": 0.5, "z": 0.0, "sides": 1, "cold": true},
		"desc": "Üstten açılan dondurucu.",
	},
	"kedi_agaci": {
		"name": "Kedi tırmalama ağacı", "price": 240, "cat": "dekor", "appeal": 3,
		"product_model": "pet_aksesuar", "part": "cat_tree", "model_h": 1.1,
		"size": Vector2(0.7, 0.7), "height": 1.1,
		"desc": "Vitrinde kedi ağacı: kedi sahiplerini çeker (+itibar).",
	},
	"kose_rafi": {
		"name": "Köşe rafı", "price": 220, "cat": "raf", "model": "shelf_corner",
		"size": Vector2(0.9, 0.9), "height": 2.0, "capacity": 15,
		"shelf": {"levels": [0.125, 0.475, 0.825, 1.175, 1.525], "width": 0.5, "depth": 0.3, "z": 0.1, "sides": 1},
		"desc": "İki duvarın birleştiği köşeye.",
	},
	"kasa_onu_raf": {
		"name": "Kasa önü standı", "price": 120, "cat": "raf", "model": "checkout_impulse_rack",
		"size": Vector2(0.6, 0.3), "height": 1.2, "capacity": 9,
		"shelf": {"levels": [0.3, 0.62, 0.94], "width": 0.5, "depth": 0.2, "z": 0.03, "sides": 1},
		"desc": "Kasa önü küçük stand.",
	},
	"delikli_pano": {
		"name": "Delikli duvar panosu", "price": 150, "cat": "raf", "model": "pegboard_wall",
		"size": Vector2(1.2, 0.2), "height": 1.8, "capacity": 12,
		"shelf": {"levels": [0.55, 0.95, 1.35], "width": 1.0, "depth": 0.12, "z": 0.12, "sides": 1},
		"desc": "Duvara asılan delikli pano.",
	},
	"sepet_standi": {
		"name": "Alışveriş sepeti standı", "price": 90, "cat": "dekor", "model": "basket_stand_a", "appeal": 1,
		"size": Vector2(0.52, 0.4), "height": 0.75,
		"desc": "Müşteriler sepet alsın (+itibar).",
	},
	"kavisli_raf": {
		"name": "Kavisli ürün rafı", "price": 380, "cat": "raf", "hidden": true,
		"size": Vector2(2.4, 0.46), "height": 1.9, "capacity": 24,
		"desc": "3 katlı, 24 ürünlük şık raf.",
	},
	"duvar_rafi": {
		"name": "Metal duvar rafı", "price": 260, "cat": "raf", "hidden": true,
		"size": Vector2(1.02, 0.42), "height": 2.15, "capacity": 20,
		"desc": "4 katlı dar raf, 20 ürün. Duvar kenarına uygun.",
	},
	"saksi_agave": {
		"name": "Saksı bitkisi: Agave", "price": 120, "cat": "dekor",
		"size": Vector2(0.7, 0.7), "height": 1.0, "appeal": 3, "model": "agave", "plant_size": 0.75,
		"desc": "Dükkânın havasını değiştirir (+itibar).",
	},
	"saksi_egrelti": {
		"name": "Saksı bitkisi: Eğrelti", "price": 140, "cat": "dekor",
		"size": Vector2(0.8, 0.8), "height": 1.0, "appeal": 3, "model": "egrelti", "plant_size": 0.85,
		"desc": "Gür yeşil eğrelti otu (+itibar).",
	},
	"saksi_calilik": {
		"name": "Saksı bitkisi: Çalı", "price": 110, "cat": "dekor",
		"size": Vector2(0.65, 0.65), "height": 1.2, "appeal": 2, "model": "calilik", "plant_size": 0.7,
		"desc": "Uzun boylu süs çalısı (+itibar).",
	},
	"jenerator": {
		"name": "Jeneratör", "price": 1800, "cat": "magaza", "max": 1,
		"size": Vector2(1.0, 0.6), "height": 0.8,
		"desc": "Elektrik kesilince ısıtıcı, filtre ve lambalar çalışmaya devam eder.",
	},
	"kamera": {
		"name": "Güvenlik kamerası", "price": 900, "cat": "magaza", "max": 1,
		"size": Vector2(0.4, 0.4), "height": 2.4,
		"desc": "Hırsızları yakalar. Kamera varken çalınan ürün geri alınır.",
	},
	"paspas": {
		"name": "Kapı paspası", "price": 60, "cat": "dekor",
		"size": Vector2(1.8, 1.0), "height": 0.02, "appeal": 1, "walkable": true,
		"desc": "Müşteriler ayağını siler (+itibar).",
	},
}

const CATEGORIES := [["akvaryum", "Akvaryumlar"], ["kafes", "Kafesler"], ["magaza", "Kasa"], ["raf", "Raflar"], ["dekor", "Dekor"]]

## Akvaryum ekipmanı
const EQUIPMENT := {
	"gravel_natural": {"name": "Doğal çakıl", "price": 60, "desc": "Tankın tabanı. Çakılsız tank çıplak ve çirkin görünür."},
	"gravel_white": {"name": "Beyaz mercan kumu", "price": 80, "desc": "Deniz tankları için ideal."},
	"heater": {"name": "Isıtıcı", "price": 150, "desc": "Olmadan su oda sıcaklığında (21°C) kalır. Tropikal balıklar için şart."},
	"light": {"name": "LED lamba", "price": 120, "desc": "Karanlık tankı müşteriler görmez bile."},
	"air": {"name": "Hava motoru", "price": 90, "desc": "Kalabalık tankta oksijen sağlar, kabarcık çıkarır."},
}

## Tank dekorları. salt: null = ikisi de, true = sadece deniz, false = sadece tatlı su
const DECOR := {
	"kaya": {"name": "Dere kayası", "price": 40, "salt": null, "model": "dere_kayasi", "size": 0.22},
	"kirik_kaya": {"name": "Granit kaya", "price": 45, "salt": null, "model": "kirik_kaya", "size": 0.24},
	"amfora": {"name": "Kırık amfora", "price": 70, "salt": false, "model": "amfora", "size": 0.24},
	"kok": {"name": "Akvaryum kökü", "price": 50, "salt": false, "model": "", "size": 0.45},
	"bitki": {"name": "Su bitkisi", "price": 35, "salt": false, "model": "", "size": 0.3},
	"kilic_bitki": {"name": "Kılıç bitkisi", "price": 45, "salt": false, "model": "", "size": 0.2},
	"resif": {"name": "Resif kayası", "price": 90, "salt": true, "model": "resif_kayasi", "size": 0.34},
	"deniz_yildizi": {"name": "Deniz yıldızı", "price": 30, "salt": true, "model": "deniz_yildizi", "size": 0.1},
	"kabuk": {"name": "Deniz kabuğu", "price": 25, "salt": true, "model": "deniz_kabugu", "size": 0.08},
	"kestane": {"name": "Deniz kestanesi", "price": 30, "salt": true, "model": "deniz_kestanesi", "size": 0.08},
}
const MAX_DECOR := 8


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func in_category(cat: String) -> Array:
	return ITEMS.keys().filter(func(k): return ITEMS[k].cat == cat and not ITEMS[k].get("hidden", false))


const STORE_MODEL := "res://assets/models/store/fixtures/%s.glb"


## Mağaza paketindeki eşya modeli (çarpışma kopyaları gizli). Yoksa null.
static func instance_model(id: String) -> Node3D:
	var m: String = str(item(id).get("model", ""))
	if m == "" or not ResourceLoader.exists(STORE_MODEL % m):
		return null
	var n: Node3D = (load(STORE_MODEL % m) as PackedScene).instantiate()
	hide_collision_meshes(n)
	return n


## Paketteki "_colN" çarpışma kopyalarını görünmez yapar.
static func hide_collision_meshes(n: Node) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		if "_col" in str(c.name) or str(c.name).ends_with("-col") or "convcolonly" in str(c.name):
			c.visible = false


## Bu rafa bu ürün konabilir mi? (soğuk ürün sadece soğutucuya, normal ürün soğutucuya konmaz)
static func shelf_accepts(type: String, pid: String) -> bool:
	var cold: bool = bool(item(type).get("shelf", {}).get("cold", false))
	return cold == bool(ProductDB.get_product(pid).get("cold", false))


static func decor_for(salt: bool) -> Array:
	return DECOR.keys().filter(func(k): return DECOR[k].salt == null or DECOR[k].salt == salt)


static func is_tank(id: String) -> bool:
	return id.begins_with("akvaryum") or id == "teraryum"


## Hamster / civciv kafesi (Game.tanks içinde suyu olmayan bölme)
static func is_pen(id: String) -> bool:
	return item(id).has("pen")


static func is_rack(id: String) -> bool:
	return item(id).has("rack")


static func is_shelf(id: String) -> bool:
	return id == "kavisli_raf" or id == "duvar_rafi" or item(id).has("shelf")


## Eşyanın zemindeki dört köşesi (dünya XZ düzleminde)
static func corners(id: String, pos: Vector2, rot_deg: float, pad: float = 0.0) -> PackedVector2Array:
	var s: Vector2 = item(id).get("size", Vector2.ONE) * 0.5 + Vector2(pad, pad)
	var out := PackedVector2Array()
	var a := deg_to_rad(rot_deg)
	for c in [Vector2(-s.x, -s.y), Vector2(s.x, -s.y), Vector2(s.x, s.y), Vector2(-s.x, s.y)]:
		# Godot'da Y ekseni etrafında dönüş: x' = x cos + z sin, z' = -x sin + z cos
		out.append(pos + Vector2(c.x * cos(a) + c.y * sin(a), -c.x * sin(a) + c.y * cos(a)))
	return out


## İki dışbükey çokgen kesişiyor mu (ayırıcı eksen testi)
static func polys_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly in [a, b]:
		for i in poly.size():
			var p1: Vector2 = poly[i]
			var p2: Vector2 = poly[(i + 1) % poly.size()]
			var axis := Vector2(-(p2.y - p1.y), p2.x - p1.x)
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for v in a:
				var d: float = axis.dot(v)
				amin = min(amin, d)
				amax = max(amax, d)
			for v in b:
				var d: float = axis.dot(v)
				bmin = min(bmin, d)
				bmax = max(bmax, d)
			if amax <= bmin or bmax <= amin:
				return false
	return true
