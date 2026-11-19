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
	"kasa": {
		"name": "Kasa tezgâhı", "price": 700, "cat": "magaza", "max": 1,
		"size": Vector2(2.64, 0.74), "height": 1.05,
		"desc": "Yazar kasalı tezgâh. Kasa olmadan satış yapılamaz!",
	},
	"kavisli_raf": {
		"name": "Kavisli ürün rafı", "price": 380, "cat": "raf",
		"size": Vector2(2.4, 0.46), "height": 1.9, "capacity": 24,
		"desc": "3 katlı, 24 ürünlük şık raf.",
	},
	"duvar_rafi": {
		"name": "Metal duvar rafı", "price": 260, "cat": "raf",
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
	"paspas": {
		"name": "Kapı paspası", "price": 60, "cat": "dekor",
		"size": Vector2(1.8, 1.0), "height": 0.02, "appeal": 1, "walkable": true,
		"desc": "Müşteriler ayağını siler (+itibar).",
	},
}

const CATEGORIES := [["akvaryum", "Akvaryumlar"], ["magaza", "Kasa"], ["raf", "Raflar"], ["dekor", "Dekor"]]

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
	return ITEMS.keys().filter(func(k): return ITEMS[k].cat == cat)


static func decor_for(salt: bool) -> Array:
	return DECOR.keys().filter(func(k): return DECOR[k].salt == null or DECOR[k].salt == salt)


static func is_tank(id: String) -> bool:
	return id.begins_with("akvaryum")


static func is_shelf(id: String) -> bool:
	return id == "kavisli_raf" or id == "duvar_rafi"


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
