class_name ProductDB
extends RefCounted
## Raf ürünleri ve bakım malzemeleri.
## "use" alanı: oyuncu bakım için kullanır mı (yem, ilaç, su düzenleyici).

const PRODUCTS := {
	"yem": {
		"name": "Tropikal Balık Yemi", "buy": 18, "price": 45, "use": true,
		"color": Color(0.1, 0.45, 0.3), "shape": "can", "model": "yem_tropikal", "food": "tropikal",
		"desc": "Pul yem. Tropikal tatlı su ve deniz balıkları için.",
	},
	"yem_japon": {
		"name": "Japon Balığı Yemi", "buy": 20, "price": 50, "use": true,
		"color": Color(0.75, 0.1, 0.12), "shape": "can", "model": "yem_japon", "food": "soguk",
		"desc": "Pul yem. Japon balığı, koi ve alabalık gibi soğuk su balıkları için.",
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


const MODEL := "res://assets/models/products/%s.glb"


## Ürünün hazır modeli varsa, yüksekliği `height` olacak, tabanı y=0'da ve
## ortalanmış biçimde örnekler. Model yoksa null.
static func instance_model(pid: String, height: float) -> Node3D:
	var m: String = str(get_product(pid).get("model", ""))
	if m == "" or not ResourceLoader.exists(MODEL % m):
		return null
	var n: Node3D = (load(MODEL % m) as PackedScene).instantiate()
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var xf: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != n and p != null:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k: float = height / max(box.size.y, 0.001)
	var wrap := Node3D.new()
	n.scale = Vector3.ONE * k
	n.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	wrap.add_child(n)
	return wrap


## Yem ürünleri (depoda bulunan ve tanka verilebilen)
static func food_ids() -> Array:
	return PRODUCTS.keys().filter(func(k): return PRODUCTS[k].has("food"))


static func ids() -> Array:
	return PRODUCTS.keys()
