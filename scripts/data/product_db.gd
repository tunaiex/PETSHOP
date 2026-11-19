class_name ProductDB
extends RefCounted
## Raf ürünleri ve bakım malzemeleri.
## "use" alanı: oyuncu bakım için kullanır mı (yem, ilaç, su düzenleyici).

const PRODUCTS := {
	"yem": {
		"name": "Pul Yem", "buy": 18, "price": 45, "use": true,
		"color": Color(0.85, 0.35, 0.15), "shape": "can",
		"desc": "Balıkları beslemek için. Müşteriler de satın alır.",
	},
	"su_duzenleyici": {
		"name": "Su Düzenleyici", "buy": 25, "price": 60, "use": true,
		"color": Color(0.15, 0.45, 0.8), "shape": "bottle",
		"desc": "Su değişiminde gerekir. Klor ve ağır metalleri giderir.",
	},
	"ilac": {
		"name": "Beyaz Benek İlacı", "buy": 40, "price": 95, "use": true,
		"color": Color(0.85, 0.15, 0.2), "shape": "bottle",
		"desc": "Hastalıklı tanka uygulanır.",
	},
	"filtre": {
		"name": "İç Filtre", "buy": 120, "price": 260, "use": false,
		"color": Color(0.2, 0.2, 0.22), "shape": "box",
		"desc": "Müşterilere satılır.",
	},
	"dekor": {
		"name": "Dekor Taş Seti", "buy": 35, "price": 85, "use": false,
		"color": Color(0.55, 0.5, 0.45), "shape": "box",
		"desc": "Müşterilere satılır.",
	},
	"kum": {
		"name": "Akvaryum Kumu 5kg", "buy": 30, "price": 70, "use": false,
		"color": Color(0.85, 0.78, 0.6), "shape": "bag",
		"desc": "Müşterilere satılır.",
	},
}


static func get_product(id: String) -> Dictionary:
	return PRODUCTS.get(id, {})


static func ids() -> Array:
	return PRODUCTS.keys()
