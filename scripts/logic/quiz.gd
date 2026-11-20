class_name Quiz
extends RefCounted
## Müşterilerin sorduğu bilgi soruları. Cevaplar balık verisinden hesaplanır.
## Soru: {"text", "options": [..], "answer": index}


static func make(rng: RandomNumberGenerator, near: Array) -> Dictionary:
	## near: müşterinin baktığı tanktaki türler (soruyu ilgili yapmak için)
	var all: Array = FishDB.ids()
	var a: String = near[rng.randi_range(0, near.size() - 1)] if not near.is_empty() else all[rng.randi_range(0, all.size() - 1)]
	match rng.randi_range(0, 2):
		0:
			var b: String = all[rng.randi_range(0, all.size() - 1)]
			while b == a:
				b = all[rng.randi_range(0, all.size() - 1)]
			var ok: bool = FishDB.conflict_reason(a, b) == ""
			return {
				"text": "%s ile %s aynı tankta yaşayabilir mi?" % [FishDB.display_name(a), FishDB.display_name(b)],
				"options": ["Evet, sorun olmaz", "Hayır, olmaz"], "answer": 0 if ok else 1,
				"explain": "Sorunsuz yaşarlar." if ok else FishDB.conflict_reason(a, b),
			}
		1:
			var s: Dictionary = FishDB.get_species(a)
			var lo: int = int(s.temp_min)
			var hi: int = int(s.temp_max)
			var right := "%d-%d°C" % [lo, hi]
			var wrongs: Array = ["%d-%d°C" % [lo - 7, hi - 7], "%d-%d°C" % [lo + 6, hi + 6], "%d-%d°C" % [lo - 4, lo]]
			var opts: Array = [right, wrongs[0], wrongs[1]]
			opts.shuffle()
			return {
				"text": "%s için su kaç derece olmalı?" % s.name,
				"options": opts, "answer": opts.find(right),
				"explain": "%s %s ister." % [s.name, right],
			}
		_:
			var salt: bool = FishDB.is_salt(a)
			return {
				"text": "%s tuzlu suda mı yaşar, tatlı suda mı?" % FishDB.display_name(a),
				"options": ["Tatlı su", "Tuzlu su (deniz)"], "answer": 1 if salt else 0,
				"explain": "%s %s balığıdır." % [FishDB.display_name(a), "deniz" if salt else "tatlı su"],
			}
