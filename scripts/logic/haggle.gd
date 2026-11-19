class_name Haggle
extends RefCounted
## Pazarlık mantığı. Görselden bağımsız, test edilebilir.
## Müşterinin ödemeye razı olduğu en yüksek fiyat (max_pay) gizlidir.
## Oyuncu fiyat söyler; müşteri kabul eder, karşı teklif verir ya da sinirlenip gider.

enum Result { ACCEPT, COUNTER, LEAVE }

var value: int            ## Toplam piyasa değeri
var max_pay: int          ## Gizli tavan
var offer: int            ## Müşterinin şu anki teklifi
var patience: float = 1.0 ## 0'a inerse gider
var rounds: int = 0
var last_line: String = ""
var _rng: RandomNumberGenerator


## stinginess: 0 cömert .. 1 cimri. reputation: 0..100
func _init(total_value: int, stinginess: float = 0.5, reputation: float = 50.0, rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	value = max(1, total_value)
	var rep_bonus: float = (reputation - 50.0) / 50.0 * 0.12
	var top: float = lerp(1.45, 1.05, stinginess) + rep_bonus + _rng.randf_range(-0.06, 0.06)
	max_pay = int(round(value * max(top, 0.9)))
	offer = int(round(value * lerp(0.85, 0.55, stinginess) * _rng.randf_range(0.95, 1.05)))
	offer = min(offer, max_pay)
	last_line = _pick(["Bunlara %d ₺ veririm." , "%d ₺ olur mu?", "Ben %d ₺ düşünüyordum."]) % offer


## Oyuncunun istediği fiyata cevap. {"result": Result, "price": int, "line": String}
func respond(ask: int) -> Dictionary:
	rounds += 1
	if ask <= offer:
		last_line = _pick(["Anlaştık!", "Tamamdır, alıyorum.", "Harika, paketleyin."])
		return {"result": Result.ACCEPT, "price": ask, "line": last_line}
	if ask <= max_pay:
		# Tavanın altında ama müşteri yine de biraz direnir.
		var greed: float = float(ask - offer) / float(max(1, max_pay - offer))
		var accept_chance: float = clamp(1.05 - greed * 0.55 - rounds * 0.04 + patience * 0.15, 0.2, 1.0)
		if _rng.randf() < accept_chance:
			last_line = _pick(["Peki, olsun.", "Pahalı ama tamam.", "Hadi bakalım, anlaştık."])
			return {"result": Result.ACCEPT, "price": ask, "line": last_line}
		patience -= 0.12
	else:
		var over: float = float(ask - max_pay) / float(value)
		patience -= 0.18 + over * 0.9
		if ask > max_pay * 1.6:
			patience -= 0.35
	if patience <= 0.0:
		last_line = _pick(["Siz kendinize başka müşteri bulun!", "Bu fiyata mı? Ben gidiyorum.", "Burası soygun yeri mi?"])
		return {"result": Result.LEAVE, "price": 0, "line": last_line}
	var target: int = min(ask, max_pay)
	var step: float = _rng.randf_range(0.25, 0.5)
	offer = int(round(lerp(float(offer), float(target), step)))
	offer = max(offer, 1)
	if patience < 0.35:
		last_line = _pick(["Son teklifim %d ₺.", "%d ₺, daha fazla olmaz.", "Sabrım tükeniyor... %d ₺."]) % offer
	else:
		last_line = _pick(["%d ₺ yapalım.", "Biraz insaf, %d ₺?", "En fazla %d ₺ verebilirim."]) % offer
	return {"result": Result.COUNTER, "price": offer, "line": last_line}


## Müşterinin teklifini direkt kabul etmek.
func accept_offer() -> int:
	return offer


func mood_text() -> String:
	if patience > 0.7:
		return "Keyfi yerinde"
	if patience > 0.4:
		return "Sabırsızlanıyor"
	return "Sinirli"


func _pick(arr: Array) -> String:
	return arr[_rng.randi_range(0, arr.size() - 1)]
