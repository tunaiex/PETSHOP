class_name FishDB
extends RefCounted
## Balık türleri veritabanı.
## Yeni tür eklemek için SPECIES sözlüğüne bir kayıt eklemek yeterli.
## assets/models/fish/<id>.glb dosyası varsa prosedürel model yerine o kullanılır.

const SPECIES := {
	"lepistes": {
		"name": "Lepistes",
		"latin": "Poecilia reticulata",
		"buy": 12, "value": 30,
		"length": 0.075, "height": 0.30, "width": 0.20,
		"temp_min": 23.0, "temp_max": 28.0,
		"dirt_rate": 0.6, "hardiness": 0.8,
		"aggression": 0.0, "long_fins": true, "small": true,
		"schooling": 0.2, "speed": 0.9,
		"tail": "fan", "tail_size": 1.25, "dorsal": 0.45,
		"body": Color(0.62, 0.66, 0.70), "belly": Color(0.92, 0.90, 0.85),
		"accent": Color(1.0, 0.42, 0.12), "fin": Color(1.0, 0.35, 0.25),
		"pattern": 3, "fin_alpha": 0.85,
		"desc": "Dayanıklı ve renkli. Kendi kendine çoğalır.",
	},
	"neon": {
		"name": "Neon Tetra",
		"latin": "Paracheirodon innesi",
		"buy": 10, "value": 25,
		"length": 0.07, "height": 0.26, "width": 0.18,
		"temp_min": 23.0, "temp_max": 27.0,
		"dirt_rate": 0.4, "hardiness": 0.55,
		"aggression": 0.0, "long_fins": false, "small": true,
		"schooling": 1.0, "speed": 1.1,
		"tail": "fork", "tail_size": 0.7, "dorsal": 0.3,
		"body": Color(0.55, 0.60, 0.62), "belly": Color(0.85, 0.85, 0.88),
		"accent": Color(0.05, 0.65, 1.0), "fin": Color(0.85, 0.9, 0.95),
		"pattern": 2, "fin_alpha": 0.35,
		"desc": "Sürü balığı. En az 6 tane bir arada olmayı sever. Kirli suya hassas.",
	},
	"japon": {
		"name": "Japon Balığı",
		"latin": "Carassius auratus",
		"buy": 25, "value": 65,
		"length": 0.14, "height": 0.45, "width": 0.32,
		"temp_min": 16.0, "temp_max": 22.0,
		"dirt_rate": 2.0, "hardiness": 0.9,
		"aggression": 0.0, "long_fins": true, "small": false,
		"schooling": 0.3, "speed": 0.6,
		"tail": "double", "tail_size": 1.1, "dorsal": 0.55,
		"body": Color(1.0, 0.45, 0.08), "belly": Color(1.0, 0.78, 0.45),
		"accent": Color(1.0, 0.95, 0.85), "fin": Color(1.0, 0.55, 0.2),
		"pattern": 4, "fin_alpha": 0.75,
		"desc": "Soğuk su sever, çok kirletir. Tropikal balıklarla aynı tanka koyma.",
	},
	"beta": {
		"name": "Beta",
		"latin": "Betta splendens",
		"buy": 55, "value": 140,
		"length": 0.09, "height": 0.30, "width": 0.2,
		"temp_min": 24.0, "temp_max": 30.0,
		"dirt_rate": 0.7, "hardiness": 0.75,
		"aggression": 0.9, "long_fins": true, "small": false,
		"schooling": 0.0, "speed": 0.5,
		"tail": "veil", "tail_size": 1.7, "dorsal": 1.8,
		"body": Color(0.08, 0.18, 0.75), "belly": Color(0.15, 0.25, 0.7),
		"accent": Color(0.75, 0.05, 0.2), "fin": Color(0.55, 0.05, 0.35),
		"pattern": 3, "fin_alpha": 0.9,
		"desc": "Kavgacı. Başka betayla ve uzun yüzgeçli balıklarla tutma.",
	},
	"melek": {
		"name": "Melek Balığı",
		"latin": "Pterophyllum scalare",
		"buy": 70, "value": 180,
		"length": 0.12, "height": 0.95, "width": 0.16,
		"temp_min": 24.0, "temp_max": 29.0,
		"dirt_rate": 1.0, "hardiness": 0.65,
		"aggression": 0.5, "long_fins": true, "small": false,
		"schooling": 0.4, "speed": 0.45,
		"tail": "fan", "tail_size": 0.9, "dorsal": 3.4,
		"body": Color(0.82, 0.82, 0.78), "belly": Color(0.95, 0.93, 0.88),
		"accent": Color(0.12, 0.11, 0.1), "fin": Color(0.85, 0.85, 0.8),
		"pattern": 1, "fin_alpha": 0.6,
		"desc": "Zarif ama küçük balıkları (neon) yiyebilir.",
	},
	"moli": {
		"name": "Siyah Moli",
		"latin": "Poecilia sphenops",
		"buy": 15, "value": 40,
		"length": 0.09, "height": 0.36, "width": 0.24,
		"temp_min": 23.0, "temp_max": 28.0,
		"dirt_rate": 1.0, "hardiness": 0.85,
		"aggression": 0.1, "long_fins": false, "small": false,
		"schooling": 0.3, "speed": 0.75,
		"tail": "round", "tail_size": 0.9, "dorsal": 0.6,
		"body": Color(0.05, 0.05, 0.06), "belly": Color(0.12, 0.12, 0.13),
		"accent": Color(0.3, 0.3, 0.32), "fin": Color(0.08, 0.08, 0.09),
		"pattern": 0, "fin_alpha": 0.9,
		"desc": "Sakin ve dayanıklı. Başlangıç için iyi.",
	},
	"zebra": {
		"name": "Zebra Danio",
		"latin": "Danio rerio",
		"buy": 8, "value": 20,
		"length": 0.07, "height": 0.22, "width": 0.16,
		"temp_min": 18.0, "temp_max": 26.0,
		"dirt_rate": 0.4, "hardiness": 0.95,
		"aggression": 0.15, "long_fins": false, "small": true,
		"schooling": 0.9, "speed": 1.4,
		"tail": "fork", "tail_size": 0.75, "dorsal": 0.3,
		"body": Color(0.75, 0.72, 0.55), "belly": Color(0.95, 0.93, 0.85),
		"accent": Color(0.08, 0.12, 0.35), "fin": Color(0.9, 0.88, 0.75),
		"pattern": 5, "fin_alpha": 0.4,
		"desc": "Çok hızlı ve dayanıklı. Hem soğuk hem ılık suda yaşar.",
	},
	"diskus": {
		"name": "Diskus",
		"latin": "Symphysodon discus",
		"buy": 380, "value": 900,
		"length": 0.15, "height": 0.92, "width": 0.14,
		"temp_min": 27.0, "temp_max": 31.0,
		"dirt_rate": 1.2, "hardiness": 0.3,
		"aggression": 0.1, "long_fins": false, "small": false,
		"schooling": 0.5, "speed": 0.35,
		"tail": "round", "tail_size": 0.6, "dorsal": 0.5,
		"body": Color(0.95, 0.35, 0.1), "belly": Color(0.95, 0.55, 0.25),
		"accent": Color(0.15, 0.55, 0.85), "fin": Color(0.9, 0.4, 0.15),
		"pattern": 6, "fin_alpha": 0.85,
		"desc": "Akvaryumun kralı. Çok pahalı, çok hassas. Kirli ve soğuk suda hızla ölür.",
	},
	# ---- Gerçek modelli yeni tatlı su türleri
	"koi": {
		"name": "Koi", "latin": "Cyprinus rubrofuscus",
		"buy": 90, "value": 230, "length": 0.2,
		"temp_min": 15.0, "temp_max": 24.0, "dirt_rate": 2.6, "hardiness": 0.9,
		"aggression": 0.0, "long_fins": false, "small": false, "schooling": 0.4, "speed": 0.45,
		"desc": "Havuz balığı. Çok büyür ve çok kirletir, soğuk su sever.",
	},
	"pirana": {
		"name": "Pirana", "latin": "Pygocentrus nattereri",
		"buy": 120, "value": 290, "length": 0.14,
		"temp_min": 24.0, "temp_max": 28.0, "dirt_rate": 1.6, "hardiness": 0.8,
		"aggression": 0.95, "long_fins": false, "small": false, "schooling": 0.7, "speed": 0.7,
		"desc": "Sürü halinde yaşar. Tankındaki diğer balıkları yer ve yüzgeçlerini koparır.",
	},
	"arowana": {
		"name": "Gümüş Arowana", "latin": "Osteoglossum bicirrhosum",
		"buy": 450, "value": 1100, "length": 0.32,
		"temp_min": 24.0, "temp_max": 30.0, "dirt_rate": 2.0, "hardiness": 0.6,
		"aggression": 0.6, "long_fins": false, "small": false, "schooling": 0.0, "speed": 0.5,
		"desc": "Dükkânın yıldızı. Küçük balıkları avlar, tek başına tutulmalı.",
	},
	# ---- Tuzlu su (deniz) türleri: tuzlu su tankı gerekir
	"palyaco": {
		"name": "Palyaço Balığı", "latin": "Amphiprion ocellaris", "salt": true,
		"buy": 90, "value": 220, "length": 0.08,
		"temp_min": 24.0, "temp_max": 28.0, "dirt_rate": 0.9, "hardiness": 0.7,
		"aggression": 0.1, "long_fins": false, "small": true, "schooling": 0.4, "speed": 0.6,
		"desc": "Herkes Nemo'yu ister! Tuzlu su gerekir.",
	},
	"cerrah": {
		"name": "Mavi Cerrah", "latin": "Paracanthurus hepatus", "salt": true,
		"buy": 160, "value": 390, "length": 0.13,
		"temp_min": 24.0, "temp_max": 27.0, "dirt_rate": 1.2, "hardiness": 0.45,
		"aggression": 0.2, "long_fins": false, "small": false, "schooling": 0.3, "speed": 0.8,
		"desc": "Dory! Kirli suda hemen hastalanır.",
	},
	"mandarin": {
		"name": "Mandarin Balığı", "latin": "Synchiropus splendidus", "salt": true,
		"buy": 140, "value": 340, "length": 0.07,
		"temp_min": 24.0, "temp_max": 27.0, "dirt_rate": 0.6, "hardiness": 0.35,
		"aggression": 0.0, "long_fins": true, "small": true, "schooling": 0.0, "speed": 0.35,
		"desc": "Göz alıcı renkler ama çok hassas.",
	},
	"aslan": {
		"name": "Aslan Balığı", "latin": "Pterois volitans", "salt": true,
		"buy": 220, "value": 520, "length": 0.16,
		"temp_min": 23.0, "temp_max": 28.0, "dirt_rate": 1.4, "hardiness": 0.8,
		"aggression": 0.7, "long_fins": true, "small": false, "schooling": 0.0, "speed": 0.3,
		"desc": "Zehirli dikenleri var, ağzına sığan her balığı yer.",
	},
	"balon": {
		"name": "Balon Balığı", "latin": "Diodon holocanthus", "salt": true,
		"buy": 150, "value": 360, "length": 0.12,
		"temp_min": 24.0, "temp_max": 28.0, "dirt_rate": 1.5, "hardiness": 0.65,
		"aggression": 0.5, "long_fins": false, "small": false, "schooling": 0.0, "speed": 0.3,
		"desc": "Sevimli ama yüzgeç ısırır, küçük balıklara dikkat.",
	},
	"denizati": {
		"name": "Deniz Atı", "latin": "Hippocampus kuda", "salt": true,
		"buy": 200, "value": 480, "length": 0.11,
		"temp_min": 23.0, "temp_max": 26.0, "dirt_rate": 0.5, "hardiness": 0.3,
		"aggression": 0.0, "long_fins": false, "small": true, "schooling": 0.0, "speed": 0.15,
		"model_fwd": Vector3(0, 0, 1), "upright": true,
		"desc": "Çok yavaş ve narin. Saldırgan balıklarla asla tutma.",
	},
	"kaplumbaga": {
		"name": "Hazar Kaplumbağası", "latin": "Mauremys rivulata", "habitat": "turtle",
		"buy": 150, "value": 380, "length": 0.15,
		"temp_min": 22.0, "temp_max": 28.0, "dirt_rate": 3.0, "hardiness": 0.9,
		"aggression": 0.3, "long_fins": false, "small": false, "schooling": 0.0, "speed": 0.25,
		"desc": "Yerli su kaplumbağası. Teraryum, ısı lambası ve bol temiz su ister. Çok kirletir, uzun yaşar.",
	},
	"kedi": {
		"name": "Kedi Balığı", "latin": "Ictalurus punctatus",
		"buy": 60, "value": 150, "length": 0.18,
		"temp_min": 18.0, "temp_max": 27.0, "dirt_rate": 2.2, "hardiness": 0.95,
		"aggression": 0.5, "long_fins": false, "small": false, "schooling": 0.0, "speed": 0.35,
		"desc": "Dipte yaşar, çok dayanıklı. Gece küçük balıkları yutar.",
	},
	"alabalik": {
		"name": "Gökkuşağı Alabalığı", "latin": "Oncorhynchus mykiss",
		"buy": 45, "value": 120, "length": 0.17,
		"temp_min": 12.0, "temp_max": 20.0, "dirt_rate": 1.8, "hardiness": 0.5,
		"aggression": 0.2, "long_fins": false, "small": false, "schooling": 0.6, "speed": 0.9,
		"desc": "Soğuk ve çok temiz su ister. Isıtıcısız tankta mutlu.",
	},
	"fener": {
		"name": "Fener Balığı", "latin": "Melanocetus johnsonii", "salt": true,
		"buy": 700, "value": 1800, "length": 0.14,
		"temp_min": 18.0, "temp_max": 24.0, "dirt_rate": 0.8, "hardiness": 0.35,
		"aggression": 0.8, "long_fins": false, "small": false, "schooling": 0.0, "speed": 0.15,
		"desc": "Koleksiyoncuların rüyası! Derin deniz balığı: soğukça, karanlık ve temiz su ister. Ağzına giren her şeyi yer.",
	},
}

## Eksik alanlar için varsayılanlar (prosedürel modelde ve simülasyonda kullanılır).
const DEFAULTS := {
	"salt": false, "height": 0.4, "width": 0.25, "tail": "fan", "tail_size": 1.0, "dorsal": 0.6,
	"body": Color(0.6, 0.6, 0.62), "belly": Color(0.9, 0.9, 0.88), "accent": Color(0.3, 0.3, 0.3),
	"fin": Color(0.7, 0.7, 0.7), "pattern": 0, "fin_alpha": 0.8,
	"model_fwd": Vector3(0, 0, 1), "upright": false,
}

## Gerçek model dosyalarının baş yönü (+Z dışında olanlar).
const MODEL_FWD := {"melek": Vector3(1, 0, 0)}

static var _merged: Dictionary = {}


static func get_species(id: String) -> Dictionary:
	if _merged.has(id):
		return _merged[id]
	if not SPECIES.has(id):
		return {}
	var d: Dictionary = DEFAULTS.duplicate()
	d.merge(SPECIES[id], true)
	if MODEL_FWD.has(id):
		d.model_fwd = MODEL_FWD[id]
	_merged[id] = d
	return d


## Bu türün gerçek 3D modeli (yoksa "").
static func model_path(id: String) -> String:
	var p := "res://assets/models/fish/%s.glb" % id
	return p if ResourceLoader.exists(p) else ""


## Türün en iyi beslendiği yem çeşidi: "soguk" (Japon balığı yemi) ya da "tropikal".
## Kaplumbağalar ikisini de yer ("hepsi").
static func food_type(id: String) -> String:
	if is_turtle(id):
		return "hepsi"
	return "soguk" if id in ["japon", "koi", "alabalik"] else "tropikal"


static func is_turtle(id: String) -> bool:
	return get_species(id).get("habitat", "") == "turtle"


static func is_salt(id: String) -> bool:
	return bool(get_species(id).get("salt", false))


static func ids() -> Array:
	return SPECIES.keys()


static func display_name(id: String) -> String:
	return SPECIES.get(id, {}).get("name", id)


static func salt_ids(salt: bool) -> Array:
	return ids().filter(func(i): return is_salt(i) == salt and not is_turtle(i))


static func turtle_ids() -> Array:
	return ids().filter(func(i): return is_turtle(i))


## Tek bir balığın piyasa değeri. Sağlık ve büyüklükle değişir.
const RARE_MULT := 6.0
## Türlerin üreme hızı (dakika başına, uygun koşulda). Yoksa üremez.
const BREED := {"lepistes": 0.0006, "moli": 0.0005, "zebra": 0.00025, "neon": 0.00012, "melek": 0.00015, "japon": 0.0001, "palyaco": 0.00012, "beta": 0.0001, "koi": 0.00006}
## Nadir (mutasyonlu) balığın adı
const RARE_NAMES := ["Albino", "Altın", "Platin", "Kızıl", "Gece Mavisi"]


static func market_value(id: String, health: float, growth: float = 1.0, rare: bool = false) -> int:
	var s: Dictionary = get_species(id)
	if s.is_empty():
		return 0
	var h: float = clamp(health, 0.0, 100.0) / 100.0
	var factor: float = lerp(0.25, 1.0, h * h) * lerp(0.7, 1.15, clamp(growth, 0.0, 1.0))
	if rare:
		factor *= RARE_MULT
	return int(round(float(s.value) * factor))


static func fish_value(f: Dictionary) -> int:
	return market_value(f.species, f.health, f.get("growth", 1.0), f.get("rare", false))


## İki tür aynı tankta sorun çıkarır mı? Açıklama döner, sorun yoksa boş string.
static func conflict_reason(a: String, b: String) -> String:
	var sa: Dictionary = get_species(a)
	var sb: Dictionary = get_species(b)
	if sa.is_empty() or sb.is_empty():
		return ""
	if sa.salt != sb.salt:
		return "%s %s, %s %s balığı." % [sa.name, "tuzlu su" if sa.salt else "tatlı su", sb.name, "tuzlu su" if sb.salt else "tatlı su"]
	if a == "beta" and b == "beta":
		return "İki beta aynı tankta kavga eder."
	for pair in [[a, sa, b, sb], [b, sb, a, sa]]:
		var att: Dictionary = pair[1]
		var vic: Dictionary = pair[3]
		if att.aggression >= 0.9 and pair[0] != pair[2]:
			return "%s, %s balıklarına saldırır." % [att.name, vic.name]
		if att.aggression >= 0.8 and vic.long_fins and pair[0] != pair[2]:
			return "%s, %s balığının yüzgeçlerini parçalar." % [att.name, vic.name]
		if att.aggression >= 0.5 and vic.small and pair[0] != pair[2]:
			return "%s, küçük %s balıklarını avlar." % [att.name, vic.name]
	var lo: float = max(sa.temp_min, sb.temp_min)
	var hi: float = min(sa.temp_max, sb.temp_max)
	if lo > hi:
		return "%s ile %s farklı su sıcaklığı ister." % [sa.name, sb.name]
	return ""
