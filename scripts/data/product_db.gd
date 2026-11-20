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
	"kafes_yemi": {
		"name": "Hamster & Civciv Yemi", "buy": 22, "price": 55, "use": true,
		"color": Color(0.85, 0.65, 0.2), "shape": "bag", "food": "kafes",
		"desc": "Tohum karışımı. Hamster ve civcivler için.",
	},
	"kedi_konservesi": {
		"name": "Kedi Konservesi", "buy": 14, "price": 35, "use": false,
		"color": Color(0.9, 0.5, 0.2), "shape": "can", "model": "cat_food_can", "h": -1.0,
		"desc": "Yaş kedi maması. Kedi sahipleri severek alır.",
	},
	"kopek_etli": {
		"name": "Aegeans Eat Köpek Maması Etli 1 kg", "buy": 55, "price": 120, "use": false,
		"color": Color(0.7, 0.2, 0.3), "shape": "bag", "model": "kopek_etli", "h": 0.26,
		"desc": "Yetişkin köpekler için etli kuru mama.",
	},
	"kopek_karidesli": {
		"name": "Aegeans Eat Köpek Maması Karidesli 1 kg", "buy": 58, "price": 125, "use": false,
		"color": Color(0.2, 0.6, 0.6), "shape": "bag", "model": "kopek_karidesli", "h": 0.26,
		"desc": "Yetişkin köpekler için karidesli kuru mama.",
	},
	"kopek_kuzulu": {
		"name": "Aegeans Eat Köpek Maması Kuzulu 1 kg", "buy": 60, "price": 130, "use": false,
		"color": Color(0.5, 0.3, 0.6), "shape": "bag", "model": "kopek_kuzulu", "h": 0.26,
		"desc": "Yetişkin köpekler için kuzu etli kuru mama.",
	},
	"kopek_somonlu": {
		"name": "Aegeans Eat Köpek Maması Somonlu 1 kg", "buy": 60, "price": 130, "use": false,
		"color": Color(0.2, 0.5, 0.8), "shape": "bag", "model": "kopek_somonlu", "h": 0.26,
		"desc": "Yetişkin köpekler için somonlu kuru mama.",
	},
	"kedi_karidesli": {
		"name": "Aegeans Eat Kedi Maması Karidesli 1 kg", "buy": 50, "price": 110, "use": false,
		"color": Color(0.1, 0.55, 0.55), "shape": "bag", "model": "kedi_mamalari", "part": "prisma-m3", "h": 0.26,
		"desc": "Yetişkin kediler için kuru mama.",
	},
	"kedi_etli": {
		"name": "Aegeans Eat Kedi Maması Etli 1 kg", "buy": 48, "price": 105, "use": false,
		"color": Color(0.7, 0.25, 0.3), "shape": "bag", "model": "kedi_mamalari", "part": "prisma-m2", "h": 0.26,
		"desc": "Yetişkin kediler için kuru mama.",
	},
	"kedi_somonlu": {
		"name": "Aegeans Eat Kedi Maması Somonlu 1 kg", "buy": 52, "price": 115, "use": false,
		"color": Color(0.15, 0.55, 0.8), "shape": "bag", "model": "kedi_mamalari", "part": "prisma-m1", "h": 0.26,
		"desc": "Yetişkin kediler için kuru mama.",
	},
	"kedi_kuzulu": {
		"name": "Aegeans Eat Kedi Maması Kuzulu 1 kg", "buy": 52, "price": 115, "use": false,
		"color": Color(0.5, 0.35, 0.7), "shape": "bag", "model": "kedi_mamalari", "part": "prisma-m0", "h": 0.26,
		"desc": "Yetişkin kediler için kuru mama.",
	},
	"konserve_tavuklu": {
		"name": "Aegean Eats Köpek Konservesi Tavuklu", "buy": 16, "price": 40, "use": false,
		"color": Color(0.95, 0.6, 0.2), "shape": "can", "model": "kopek_konserve", "part": "Grup3", "h": 0.11,
		"desc": "Yaş köpek maması.",
	},
	"konserve_somonlu": {
		"name": "Aegean Eats Köpek Konservesi Somonlu", "buy": 18, "price": 42, "use": false,
		"color": Color(0.95, 0.5, 0.3), "shape": "can", "model": "kopek_konserve", "part": "Grup2", "h": 0.11,
		"desc": "Yaş köpek maması.",
	},
	"konserve_karidesli": {
		"name": "Aegean Eats Köpek Konservesi Karidesli", "buy": 18, "price": 42, "use": false,
		"color": Color(0.85, 0.2, 0.25), "shape": "can", "model": "kopek_konserve", "part": "Grup5", "h": 0.11,
		"desc": "Yaş köpek maması.",
	},
	"kopek_kemigi": {
		"name": "Çiğneme Kemiği", "buy": 10, "price": 30, "use": false,
		"color": Color(0.9, 0.85, 0.7), "shape": "box", "model": "kemik", "part": "polySurface1", "h": 0.2,
		"desc": "Köpeklerin diş sağlığı için doğal kemik.",
	},
	"mama_kabi": {
		"name": "Paslanmaz Mama Kabı", "buy": 25, "price": 65, "use": false,
		"color": Color(0.2, 0.2, 0.22), "shape": "box", "model": "mama_kabi", "h": 0.07,
		"desc": "Kaymaz tabanlı çelik mama kabı.",
	},
	"kedi_tuvaleti": {
		"name": "Kedi Tuvaleti", "buy": 60, "price": 140, "use": false,
		"color": Color(0.6, 0.7, 0.8), "shape": "box", "model": "pet_aksesuar", "part": "pCube3", "h": 0.16,
		"desc": "Kapaklı kedi tuvaleti.",
	},
	"kedi_oyuncagi": {
		"name": "Kedi Oyuncağı", "buy": 12, "price": 35, "use": false,
		"color": Color(0.9, 0.5, 0.6), "shape": "box", "model": "pet_aksesuar", "part": "toy_busybuddy", "h": 0.08,
		"desc": "Kedilerin saatlerce oynadığı oyuncak.",
	},
	"tasma": {
		"name": "Tasma", "buy": 15, "price": 45, "use": false,
		"color": Color(0.8, 0.2, 0.2), "shape": "box", "model": "pet_aksesuar", "part": "pCube2", "h": 0.04,
		"desc": "Ayarlanabilir kedi/köpek tasması.",
	},
	"kedi_kumu": {
		"name": "Kedi Kumu 5 L", "buy": 45, "price": 105, "use": false,
		"color": Color(0.5, 0.6, 0.75), "shape": "bag", "model": "cat_litter_bag", "h": -1.0,
		"desc": "Topaklanan kedi kumu.",
	},
	"kus_yemi": {
		"name": "Kuş Yemi", "buy": 20, "price": 50, "use": false,
		"color": Color(0.85, 0.7, 0.3), "shape": "bag", "model": "bird_seed_bag", "h": -1.0,
		"desc": "Muhabbet kuşu ve kanarya için tohum karışımı.",
	},
	"donuk_artemia": {
		"name": "Donuk Artemia", "buy": 30, "price": 75, "use": true, "cold": true,
		"color": Color(0.85, 0.3, 0.35), "shape": "box", "food": "hepsi",
		"desc": "Dondurulmuş canlı yem. Bütün balıklar bayılır. Sadece soğutucuda saklanır.",
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
	var p: Dictionary = get_product(pid)
	return instance_path(str(p.get("model", "")), str(p.get("part", "")), height)


## Ürün klasöründeki bir modeli (isteğe bağlı tek parçasını) verilen boyda örnekler.
static func instance_path(m: String, part: String, height: float) -> Node3D:
	if m == "" or not ResourceLoader.exists(MODEL % m):
		return null
	var n: Node3D = (load(MODEL % m) as PackedScene).instantiate()
	# Birden çok ürün içeren dosyadan sadece istenen parça görünsün
	if part != "":
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var chain := ""
			var q: Node = c
			while q != n and q != null:
				chain = str(q.name) + "/" + chain
				q = q.get_parent()
			if not chain.contains(part):
				c.visible = false
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if not mi.visible:
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var pn: Node = mi
		while pn != n and pn != null:
			xf = (pn as Node3D).transform * xf
			pn = pn.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	# height < 0: modelin gerçek boyu (raf aralığına sığsın diye en fazla 30 cm)
	var k: float = height / max(box.size.y, 0.001) if height > 0.0 else min(1.0, 0.3 / max(box.size.y, 0.001))
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
