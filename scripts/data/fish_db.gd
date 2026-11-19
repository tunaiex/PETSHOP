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
}


static func get_species(id: String) -> Dictionary:
	return SPECIES.get(id, {})


static func ids() -> Array:
	return SPECIES.keys()


static func display_name(id: String) -> String:
	return SPECIES.get(id, {}).get("name", id)


## Tek bir balığın piyasa değeri. Sağlık ve büyüklükle değişir.
static func market_value(id: String, health: float, growth: float = 1.0) -> int:
	var s: Dictionary = get_species(id)
	if s.is_empty():
		return 0
	var h: float = clamp(health, 0.0, 100.0) / 100.0
	var factor: float = lerp(0.25, 1.0, h * h) * lerp(0.7, 1.15, clamp(growth, 0.0, 1.0))
	return int(round(float(s.value) * factor))


## İki tür aynı tankta sorun çıkarır mı? Açıklama döner, sorun yoksa boş string.
static func conflict_reason(a: String, b: String) -> String:
	var sa: Dictionary = get_species(a)
	var sb: Dictionary = get_species(b)
	if sa.is_empty() or sb.is_empty():
		return ""
	if a == "beta" and b == "beta":
		return "İki beta aynı tankta kavga eder."
	for pair in [[a, sa, b, sb], [b, sb, a, sa]]:
		var att: Dictionary = pair[1]
		var vic: Dictionary = pair[3]
		if att.aggression >= 0.8 and vic.long_fins and pair[0] != pair[2]:
			return "%s, %s balığının yüzgeçlerini parçalar." % [att.name, vic.name]
		if att.aggression >= 0.5 and vic.small and pair[0] != pair[2]:
			return "%s, küçük %s balıklarını avlar." % [att.name, vic.name]
	var lo: float = max(sa.temp_min, sb.temp_min)
	var hi: float = min(sa.temp_max, sb.temp_max)
	if lo > hi:
		return "%s ile %s farklı su sıcaklığı ister." % [sa.name, sb.name]
	return ""
