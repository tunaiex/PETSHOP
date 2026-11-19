class_name Customer
extends Node3D
## Müşteri: içeri girer, tanklara bakar, balık/ürün seçer, sıraya girer, pazarlık eder, çıkar.
## Görünüm: assets/models/characters/*.glb (yürüme/bekleme animasyonlu) yoksa prosedürel insan.

const CHARACTERS := ["res://assets/models/characters/adam.glb", "res://assets/models/characters/kiz.glb"]

enum State { ENTER, BROWSE, LOOK, SHELF, QUEUE, REGISTER, LEAVE, GONE }

const TYPES := [
	{"title": "Emekli Amca", "patience": 1.4, "stingy": 0.7, "picky": 0.4},
	{"title": "Çocuklu Anne", "patience": 0.9, "stingy": 0.35, "picky": 0.3},
	{"title": "Bilgiç Akvaryumcu", "patience": 1.0, "stingy": 0.45, "picky": 0.9},
	{"title": "Pazarlıkçı", "patience": 1.1, "stingy": 0.9, "picky": 0.5},
	{"title": "Öğrenci", "patience": 0.8, "stingy": 0.6, "picky": 0.2},
]

signal left_shop(c: Customer)

var main: Node
var shop: Shop
var state: State = State.ENTER
var profile: Dictionary
var basket: Array = []       ## {"type":"fish","tank":i,"uid":u,"species":s} | {"type":"product","id":p}
var wait_time: float = 0.0   ## Kasada kalan sabır (sn)
var wait_max: float = 1.0
var angry: bool = false
var haggle: Haggle

var _path: Array = []
var _speed: float = 1.25
var _to_visit: Array = []
var _look_timer: float = 0.0
var _current: Node3D           ## Baktığı akvaryum ya da raf
var _walk_anim: String = ""
var _idle_anim: String = ""
var _bubble: Label3D
var _bubble_timer: float = 0.0
var _walk_phase: float = 0.0
var _legs: Array = []
var _arms: Array = []
var _rng := RandomNumberGenerator.new()
var _anim: AnimationPlayer
var _queue_index: int = -1
var inspector: bool = false
var kind: String = "normal"     ## normal | regular | complainer | thief | child | special
var regular_name: String = ""
var complaint: Dictionary = {}
var special_order: Dictionary = {}
var question: Dictionary = {}
var _question_timer: float = 0.0
var _tapping: float = 0.0
var _tap_aq: Aquarium
var _happy_bonus: float = 0.0
var _issues: Array = []


func setup(m: Node, s: Shop, seed_value: int) -> void:
	main = m
	shop = s
	_rng.seed = seed_value
	profile = TYPES[_rng.randi_range(0, TYPES.size() - 1)].duplicate()
	_speed = _rng.randf_range(1.0, 1.4)
	_build_body()
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 36
	_bubble.pixel_size = 0.0028
	_bubble.outline_size = 10
	_bubble.modulate = Color(1, 1, 1)
	_bubble.outline_modulate = Color(0.05, 0.08, 0.1)
	_bubble.position = Vector3(0, 2.05, 0)
	_bubble.no_depth_test = false
	add_child(_bubble)
	position = shop.outside + Vector3(_rng.randf_range(-3, 3), 0, 0)
	# Bakacağı yerler: balıklı tanklar ve dolu raflar
	var targets: Array = []
	for aq in shop.aquariums:
		var tk: Dictionary = Game.tanks[aq.tank_id]
		if not TankSim.living(tk).is_empty() and not tk.get("quarantine", false):
			targets.append(aq)
	for sh in shop.shelves:
		if Game.shelf_total(sh.entry()) > 0:
			targets.append(sh)
	targets.shuffle()
	_to_visit = targets.slice(0, _rng.randi_range(1, max(1, min(3, targets.size()))))
	_path = [shop.entrance + Vector3(_rng.randf_range(-0.4, 0.4), 0, 0)]
	state = State.ENTER


# ------------------------------------------------------------------ Özel müşteri türleri

func make_regular(r: Dictionary) -> void:
	kind = "regular"
	regular_name = r.name
	profile = profile.duplicate()
	profile.title = r.name
	profile.patience = float(profile.patience) * 1.3
	# Sadık müşteri indirim bekler
	if float(r.loyalty) > 60.0:
		profile.stingy = min(1.0, float(profile.stingy) + 0.1)
	r.visits = int(r.get("visits", 0)) + 1
	_bubble.modulate = Color(0.75, 1.0, 0.8)
	say("Merhaba, yine ben! (%s)" % r.name, 3.5)


func make_complainer(c: Dictionary) -> void:
	kind = "complainer"
	complaint = c
	profile = {"title": c.name, "patience": 2.0, "stingy": 0.5, "picky": 0.5}
	_to_visit = []
	_bubble.modulate = Color(1.0, 0.6, 0.5)
	say("Dün aldığım %s öldü!" % FishDB.display_name(c.species), 4.0)


func make_thief() -> void:
	kind = "thief"
	_to_visit = shop.shelves.filter(func(sh): return Game.shelf_total(sh.entry()) > 0)
	_to_visit = _to_visit.slice(0, 1)


func make_child() -> void:
	kind = "child"
	profile = {"title": "Çocuk", "patience": 1.0, "stingy": 1.0, "picky": 0.0}
	scale = Vector3.ONE * 0.62
	_to_visit = shop.aquariums.filter(func(a): return not TankSim.living(Game.tanks[a.tank_id]).is_empty())
	_to_visit.shuffle()
	_to_visit = _to_visit.slice(0, 2)
	_speed *= 1.3
	say("Balıklaaar!", 2.5)


func make_special(o: Dictionary) -> void:
	kind = "special"
	special_order = o
	profile = {"title": o.name, "patience": 2.0, "stingy": 0.2, "picky": 0.4}
	_to_visit = []
	_bubble.modulate = Color(0.8, 0.9, 1.0)
	say("Siparişim hazır mı? %d %s." % [o.qty, FishDB.display_name(o.species)], 4.0)


## Oyuncu müşteriye bakıp ETKİLEŞ dediğinde
func get_prompt() -> String:
	if not question.is_empty():
		return "%s: Soruyu cevapla" % profile.title
	if kind == "child" and _tapping > 0.0:
		return "Çocuğu uyar"
	return ""


func interact(player: Node) -> void:
	if not question.is_empty():
		player.hud.open_question(self)
	elif kind == "child" and _tapping > 0.0:
		_tapping = 0.0
		say("Peki abi, vurmam...", 2.5)
		_to_visit.clear()
		_look_timer = 0.5


func answer_question(idx: int) -> bool:
	var ok: bool = idx == int(question.answer)
	if ok:
		var tip: int = _rng.randi_range(15, 50)
		Game.add_money(tip)
		Game.stats.tips += tip
		Game.change_reputation(1.5)
		_happy_bonus = 0.3
		say("Çok teşekkürler, ne kadar bilgilisiniz! (+%d ₺ bahşiş)" % tip, 3.5)
		if regular_name != "":
			Game.change_loyalty(regular_name, 5.0)
	else:
		Game.change_reputation(-1.0)
		say("Hmm, emin değilim bundan...", 3.0)
	question = {}
	_look_timer = min(_look_timer, 1.0)
	return ok


## Bu müşteriyi belediye müfettişine çevirir: bütün tankları gezer, sorun bulursa ceza keser.
func make_inspector() -> void:
	inspector = true
	profile = {"title": "Müfettiş", "patience": 3.0, "stingy": 1.0, "picky": 1.0}
	_to_visit = shop.aquariums.duplicate()
	_bubble.modulate = Color(1.0, 0.85, 0.4)
	say("Belediye denetimi. Tanklara bakacağım.", 4.0)


func _inspect(aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	var alive: Array = TankSim.living(t)
	var found: Array = []
	if t.dirt > 60.0:
		found.append("kirli su")
	if t.sick:
		found.append("hastalık")
	if TankSim.dead_count(t) > 0:
		found.append("ölü balık")
	if not alive.is_empty() and t.cycle < 60.0:
		found.append("olgunlaşmamış su")
	for sp in TankSim.species_in(t):
		var sd: Dictionary = FishDB.get_species(sp)
		if t.temp < sd.temp_min - 1.0 or t.temp > sd.temp_max + 1.0:
			found.append("yanlış sıcaklık")
			break
	if found.is_empty():
		say("Tank %d uygun." % (aq.tank_id + 1), 2.5)
	else:
		say("Tank %d: %s! Not ediyorum." % [aq.tank_id + 1, ", ".join(found)], 3.5)
		_issues.append_array(found)


func _inspection_result() -> void:
	if _issues.is_empty():
		say("Her şey yönetmeliğe uygun. Tebrikler!", 4.0)
		Game.change_reputation(4.0)
		Game.notify.emit("Müfettiş: Dükkân temiz çıktı! İtibar arttı.", "good")
	else:
		var fine: int = min(250 * _issues.size(), 1500)
		Game.add_money(-fine)
		Game.stats.fines += fine
		Game.change_reputation(-5.0)
		say("Ceza tutanağı: %d ₺." % fine, 4.0)
		Game.notify.emit("Müfettiş %d sorun buldu (%s). Ceza: %d ₺" % [_issues.size(), ", ".join(_issues), fine], "bad")


func _go(target: Vector3) -> void:
	_path = shop.path(position, target)


func _build_body() -> void:
	Shop.add_blob_shadow(self, Vector2(0.8, 0.8), 0.4)
	var avail: Array = CHARACTERS.filter(func(p): return ResourceLoader.exists(p))
	if not avail.is_empty():
		var inst: Node3D = (load(avail[_rng.randi_range(0, avail.size() - 1)]) as PackedScene).instantiate()
		inst.rotation.y = PI  # modeller +Z'ye bakıyor, müşteri -Z yönünde yürür
		inst.scale = Vector3.ONE * _rng.randf_range(0.95, 1.05)
		add_child(inst)
		_add_collider()
		var players := inst.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_anim = players[0]
			for a in _anim.get_animation_list():
				var low: String = a.to_lower()
				if low == "walk" or low.ends_with("|walk"):
					_walk_anim = a
				elif low == "idle" or low.ends_with("|idle"):
					_idle_anim = a
			for a in [_walk_anim, _idle_anim]:
				if a != "":
					_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			if _idle_anim != "":
				_anim.play(_idle_anim)
		return
	var skins := [Color(0.96, 0.8, 0.68), Color(0.87, 0.67, 0.5), Color(0.72, 0.52, 0.38), Color(0.5, 0.35, 0.25)]
	var hairs := [Color(0.08, 0.06, 0.05), Color(0.3, 0.2, 0.12), Color(0.55, 0.4, 0.22), Color(0.75, 0.75, 0.75)]
	var shirt: Color = Color.from_hsv(_rng.randf(), _rng.randf_range(0.3, 0.7), _rng.randf_range(0.3, 0.8))
	var pants: Color = [Color(0.15, 0.18, 0.3), Color(0.25, 0.25, 0.27), Color(0.75, 0.68, 0.55), Color(0.1, 0.1, 0.1)][_rng.randi_range(0, 3)]
	var skin: Color = skins[_rng.randi_range(0, 3)]
	var hair: Color = hairs[_rng.randi_range(0, 3)]
	var skin_m := MeshKit.mat(skin, 0.6)
	var shirt_m := MeshKit.mat(shirt, 0.8)
	var pants_m := MeshKit.mat(pants, 0.85)
	var shoe_m := MeshKit.mat(Color(0.08, 0.08, 0.09), 0.5)
	var hair_m := MeshKit.mat(hair, 0.7)
	var body := Node3D.new()
	body.scale = Vector3.ONE * _rng.randf_range(0.93, 1.06)
	add_child(body)
	# Bacaklar
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.1, 0.9, 0)
		body.add_child(hip)
		var leg := _capsule(0.075, 0.88, pants_m)
		leg.position = Vector3(0, -0.44, 0)
		hip.add_child(leg)
		var shoe := MeshKit.box(hip, Vector3(0.1, 0.07, 0.24), Vector3(0, -0.87, -0.04), shoe_m)
		shoe.name = "Shoe"
		_legs.append(hip)
	# Gövde
	var torso := _capsule(0.19, 0.68, shirt_m)
	torso.position = Vector3(0, 1.22, 0)
	torso.scale = Vector3(1.0, 1.0, 0.68)
	body.add_child(torso)
	var belt := MeshKit.cylinder(body, 0.165, 0.08, Vector3(0, 0.93, 0), pants_m, 20)
	belt.scale = Vector3(1, 1, 0.7)
	# Kollar
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.23, 1.47, 0)
		body.add_child(sh)
		var arm := _capsule(0.05, 0.6, shirt_m)
		arm.position = Vector3(side * 0.015, -0.28, 0)
		sh.add_child(arm)
		var hand := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.045
		hs.height = 0.1
		hand.mesh = hs
		hand.material_override = skin_m
		hand.position = Vector3(side * 0.015, -0.6, 0)
		sh.add_child(hand)
		_arms.append(sh)
	# Boyun ve baş
	MeshKit.cylinder(body, 0.05, 0.1, Vector3(0, 1.58, 0), skin_m, 12)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.11
	hm.height = 0.25
	head.mesh = hm
	head.material_override = skin_m
	head.position = Vector3(0, 1.72, 0)
	body.add_child(head)
	var hair_mi := MeshInstance3D.new()
	var hhm := SphereMesh.new()
	hhm.radius = 0.118
	hhm.height = 0.2
	hhm.is_hemisphere = true
	hair_mi.mesh = hhm
	hair_mi.material_override = hair_m
	hair_mi.position = Vector3(0, 1.75, 0.012)
	hair_mi.rotation_degrees.x = -12
	body.add_child(hair_mi)
	# Burun ve gözler küçük detaylar
	var nose := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = 0.018
	nm.height = 0.04
	nose.mesh = nm
	nose.material_override = skin_m
	nose.position = Vector3(0, 1.71, -0.11)
	body.add_child(nose)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.012
		em.height = 0.024
		eye.mesh = em
		eye.material_override = MeshKit.mat(Color(0.05, 0.05, 0.05), 0.2)
		eye.position = Vector3(side * 0.04, 1.745, -0.1)
		body.add_child(eye)
	_add_collider()


func _add_collider() -> void:
	# Oyuncunun içinden geçmemesi için çarpışma
	var ab := AnimatableBody3D.new()
	ab.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	ab.add_child(cs)
	ab.set_meta("interact", self)
	add_child(ab)


func _capsule(r: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 16
	cm.rings = 6
	mi.mesh = cm
	mi.material_override = m
	return mi


func say(text: String, secs: float = 3.5) -> void:
	_bubble.text = text
	_bubble_timer = secs


# ------------------------------------------------------------------ Davranış

func _process(delta: float) -> void:
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0 and state != State.REGISTER:
			_bubble.text = ""
	var moving := _follow_path(delta * Game.time_scale)
	_animate(delta, moving)
	match state:
		State.ENTER:
			if not moving:
				_next_browse()
		State.BROWSE:
			if not moving:
				state = State.LOOK
				_look_timer = _rng.randf_range(3.0, 6.0)
				if is_instance_valid(_current):
					_face(_current.look_target())
					if inspector and _current is Aquarium:
						_inspect(_current)
					elif _current is Aquarium:
						_evaluate_tank(_current)
					elif _current is Shelf:
						_evaluate_shelf(_current)
		State.LOOK:
			_look_timer -= delta * Game.time_scale
			if _tapping > 0.0 and is_instance_valid(_tap_aq):
				_tapping -= delta * Game.time_scale
				_tap_aq.scare()
				for f in TankSim.living(Game.tanks[_tap_aq.tank_id]):
					f.health = max(1.0, f.health - 0.6 * delta * Game.time_scale)
				if _bubble_timer <= 0.0:
					say("Tık tık tık!", 1.0)
				if _tapping <= 0.0:
					_look_timer = 0.5
			if not question.is_empty():
				_question_timer -= delta * Game.time_scale
				if _bubble_timer <= 0.0:
					say("Bir sorum var! (bana bak)", 1.5)
				if _question_timer <= 0.0:
					question = {}
					say("Neyse, kimse ilgilenmiyor...", 2.5)
					Game.change_reputation(-0.5)
				else:
					return
			if _look_timer <= 0.0 and _tapping <= 0.0:
				_next_browse()
		State.QUEUE:
			if not moving and shop.counter:
				_face(shop.counter.to_global(Vector3(-0.5, 0, 0)))
				wait_time -= delta * Game.time_scale * 0.5
				if wait_time <= 0.0:
					_give_up()
		State.REGISTER:
			if not moving:
				if shop.counter:
					_face(shop.counter.to_global(Vector3(-0.5, 0, 0)))
				if haggle == null:
					wait_time -= delta * Game.time_scale
					var frac: float = wait_time / wait_max
					if frac < 0.3:
						_bubble.text = "Hadi ama!"
					elif frac < 0.6:
						_bubble.text = "Bakar mısınız?"
					else:
						_bubble.text = "Hesap lütfen ✓"
					if wait_time <= 0.0:
						_give_up()
		State.LEAVE:
			if not moving:
				state = State.GONE
				left_shop.emit(self)
				queue_free()


func _next_browse() -> void:
	while not _to_visit.is_empty():
		_current = _to_visit.pop_front()
		if not is_instance_valid(_current):
			continue
		var vp: Vector3 = _current.view_point()
		vp.y = 0
		var off: Vector3 = _current.global_transform.basis.x * _rng.randf_range(-0.4, 0.4)
		_go(vp + off)
		state = State.BROWSE
		return
	_go_queue()


func _evaluate_tank(aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	var alive: Array = TankSim.living(t)
	if kind == "child":
		_tapping = _rng.randf_range(6.0, 10.0)
		_tap_aq = aq
		_look_timer = _tapping + 1.0
		return
	if (kind == "normal" or kind == "regular") and not alive.is_empty() and _rng.randf() < 0.2:
		question = Quiz.make(_rng, TankSim.species_in(t))
		_question_timer = 25.0
		_look_timer = 25.0
		say("Bir sorum var! (bana bak)", 3.0)
	if alive.is_empty():
		say("Bu tank boş...")
		return
	var picky: float = profile.picky
	if t.dirt > 75.0 - picky * 25.0:
		say("Su çok kirli, yazık balıklara.")
		Game.change_reputation(-0.6)
		return
	if t.sick:
		say("Balıklarda beyaz benek var!")
		Game.change_reputation(-1.0)
		return
	var dead: int = TankSim.dead_count(t)
	if dead > 0:
		say("Iyy, ölü balık var!")
		Game.change_reputation(-1.5)
		return
	var appeal: float = TankSim.appeal(t)
	if not t.get("light", false) and _rng.randf() < 0.6:
		say("Bu tank çok karanlık, hiçbir şey görünmüyor.")
		return
	if t.get("decor", []).is_empty() and str(t.get("gravel", "")) == "" and _rng.randf() < 0.4:
		say("Bomboş cam kutu... Hiç özenilmemiş.")
	# Balık seç
	var reserved: Array = main.reserved_uids()
	var choices: Array = alive.filter(func(f): return not reserved.has(int(f.uid)) and f.growth > 0.3)
	if choices.is_empty():
		return
	var rares: Array = choices.filter(func(f): return f.get("rare", false))
	if not rares.is_empty() and _rng.randf() < 0.6:
		var rf: Dictionary = rares[0]
		basket.append({"type": "fish", "tank": aq.tank_id, "uid": int(rf.uid), "species": rf.species})
		say("Vay! Şu %s %s'yı istiyorum, ne kadar?" % [rf.get("rare_name", "Nadir"), FishDB.display_name(rf.species)])
		return
	var sp: String = choices[_rng.randi_range(0, choices.size() - 1)].species
	var same: Array = choices.filter(func(f): return f.species == sp and not f.get("rare", false))
	if same.is_empty():
		return
	var want: int = 1
	var s: Dictionary = FishDB.get_species(sp)
	if float(s.schooling) > 0.6:
		want = _rng.randi_range(3, 6)
	elif s.value < 80:
		want = _rng.randi_range(1, 3)
	want = min(want, same.size())
	var avg_h := 0.0
	for i in want:
		avg_h += same[i].health
	avg_h /= max(1, want)
	if avg_h < 55.0 + picky * 20.0:
		say("Bunlar biraz halsiz görünüyor.")
		return
	if regular_name != "" and float(Game.regular(regular_name).get("loyalty", 0)) > 70.0:
		want = min(want + 1, same.size())
	if _rng.randf() < clamp(0.3 + appeal * 0.0065 + _happy_bonus, 0.2, 0.97):
		for i in want:
			basket.append({"type": "fish", "tank": aq.tank_id, "uid": int(same[i].uid), "species": sp})
		var special := {"palyaco": "Aaa Nemo! Bunu alıyorum!", "cerrah": "Dory'yi buldum!", "arowana": "Vay be, ejderha balığı!", "pirana": "Pirana mı bu? Harika!", "denizati": "Deniz atı! Çok narin..."}
		if special.has(sp) and _rng.randf() < 0.7:
			say(special[sp])
		else:
			say("%d tane %s alayım." % [want, s.name] if want > 1 else "Şu %s çok güzel!" % s.name)
	else:
		say(["Güzelmiş.", "Hmm...", "Çok tatlılar!"][_rng.randi_range(0, 2)], 2.5)
		_maybe_special_order(t)


## Aradığını bulamayan müşteri bazen özel sipariş verir.
func _maybe_special_order(t: Dictionary) -> void:
	if kind != "normal" and kind != "regular":
		return
	if _rng.randf() > 0.12 or Game.special_orders.size() >= 4:
		return
	var pool: Array = FishDB.salt_ids(bool(t.get("salt", false)))
	var sp: String = pool[_rng.randi_range(0, pool.size() - 1)]
	var qty: int = _rng.randi_range(2, 4) if TankSim.space_of(sp) <= 2 else 1
	var o := {"id": Game.rng.randi(), "name": profile.title, "species": sp, "qty": qty, "ready": Game.day + 1, "due": Game.day + 3}
	Game.special_orders.append(o)
	say("Bana %d %s bulabilir misiniz? İki üç güne uğrarım." % [qty, FishDB.display_name(sp)], 4.5)
	Game.notify.emit("Özel sipariş: %s, %d %s istiyor (en geç Gün %d). Getirirsen %%50 fazla öder." % [o.name, qty, FishDB.display_name(sp), o.due], "info")


func _evaluate_shelf(sh: Shelf) -> void:
	var e: Dictionary = sh.entry()
	var ids: Array = []
	for pid in e.get("shelf", {}):
		if int(e.shelf[pid]) > 0:
			ids.append(pid)
	if ids.is_empty():
		say("Raf bomboş!")
		Game.change_reputation(-0.5)
		return
	if kind != "thief" and _rng.randf() < 0.3:
		say(["Fiyatlara bakıyorum sadece.", "Hmm, şimdilik almayayım."][_rng.randi_range(0, 1)], 2.5)
		return
	ids.shuffle()
	for i in min(_rng.randi_range(1, 2), ids.size()):
		var pid: String = ids[i]
		e.shelf[pid] = int(e.shelf[pid]) - 1
		if e.shelf[pid] <= 0:
			e.shelf.erase(pid)
		basket.append({"type": "product", "id": pid, "shelf": sh.furniture_uid})
	Game.stock_changed.emit()
	if kind == "thief":
		_steal()
		return
	say("Bunu da alayım.", 2.0)


func _steal() -> void:
	_to_visit.clear()
	var n: int = basket.size()
	if Game.has_furniture("kamera"):
		Sfx.play("alarm")
		say("Eyvah, kamera!", 2.5)
		Game.notify.emit("HIRSIZ! Güvenlik kamerası yakaladı, %d ürün geri alındı." % n, "good")
		Game.change_reputation(0.5)
		_leave()  # ürünler rafa geri konur
	else:
		Game.stats.stolen += n
		basket.clear()
		state = State.LEAVE
		_speed *= 1.6
		_path = shop.path(position, shop.entrance)
		_path.append(shop.outside + Vector3(_rng.randf_range(-6, 6), 0, 0))


func _go_queue() -> void:
	if kind == "complainer":
		_join_counter()
		return
	if kind == "special":
		_fill_special_basket()
		if basket.is_empty():
			if Game.day >= int(special_order.due):
				say("Sözünüzü tutmadınız! Bir daha gelmem.", 4.0)
				Game.special_orders.erase(special_order)
				Game.change_reputation(-3.0)
			else:
				say("Henüz gelmemiş. Yarın tekrar uğrarım.", 3.5)
			_leave()
			return
		say("Harika, buldunuz!", 2.5)
	if kind == "child":
		_leave()
		return
	if inspector:
		_inspection_result()
		state = State.LEAVE
		_path = shop.path(position, shop.entrance)
		_path.append(shop.outside)
		return
	if not basket.is_empty() and shop.counter == null:
		say("Kasa bile yok, nereye ödeyeceğim?")
		Game.record_lost_customer(true)
		_leave()
		return
	if basket.is_empty():
		say(["Bugünlük bakmaya geldim.", "Sonra uğrarım.", "Aradığımı bulamadım."][_rng.randi_range(0, 2)])
		Game.record_lost_customer(false)
		_leave()
		return
	_join_counter()


func _join_counter() -> void:
	if shop.counter == null:
		_leave()
		return
	wait_max = 60.0 * float(profile.patience)
	wait_time = wait_max
	state = State.QUEUE
	main.join_queue(self)


func _fill_special_basket() -> void:
	var need: int = int(special_order.qty)
	var reserved: Array = main.reserved_uids()
	var found: Array = []
	for aq in shop.aquariums:
		var t: Dictionary = Game.tanks[aq.tank_id]
		if t.get("quarantine", false):
			continue
		for f in TankSim.living(t):
			if f.species == special_order.species and f.health > 50.0 and not reserved.has(int(f.uid)) and found.size() < need:
				found.append({"type": "fish", "tank": aq.tank_id, "uid": int(f.uid), "species": f.species, "mult": 1.5})
	if found.size() >= need:
		basket = found


## main sıra düzenini değiştirdiğinde çağırır.
func set_queue_slot(index: int) -> void:
	_queue_index = index
	if state != State.QUEUE and state != State.REGISTER:
		return
	if shop.counter == null:
		return
	if index == 0:
		state = State.REGISTER
		_go(shop.counter.register_point())
		if wait_time < wait_max * 0.6:
			wait_time = wait_max * 0.6
	else:
		state = State.QUEUE
		_go(shop.counter.queue_point(index - 1))


func basket_value() -> int:
	var total := 0
	for item in basket:
		total += item_value(item)
	return total


func item_value(item: Dictionary) -> int:
	if item.type == "product":
		var pv: int = int(ProductDB.get_product(item.id).price)
		if Game.campaign.get("target", "") == "products":
			pv = int(pv * (1.0 - float(Game.campaign.pct) / 100.0))
		return pv
	var f: Dictionary = main.find_fish(int(item.tank), int(item.uid))
	if f.is_empty() or not f.alive:
		return 0
	var v: float = FishDB.fish_value(f) * float(item.get("mult", 1.0))
	if Game.campaign.get("target", "") == "fish":
		v *= 1.0 - float(Game.campaign.pct) / 100.0
	return int(v)


## Satış öncesi: ölen/satılamayan kalemleri sepetten çıkar.
func validate_basket() -> void:
	var keep: Array = []
	for item in basket:
		if item.type == "product":
			keep.append(item)  # raftan alındı, elinde
		else:
			var f: Dictionary = main.find_fish(int(item.tank), int(item.uid))
			if not f.is_empty() and f.alive:
				keep.append(item)
	basket = keep


func start_haggle() -> Haggle:
	validate_basket()
	if basket.is_empty():
		return null
	haggle = Haggle.new(basket_value(), float(profile.stingy), Game.reputation, _rng)
	return haggle


func finish_sale() -> void:
	if regular_name != "":
		Game.change_loyalty(regular_name, 5.0)
	if kind == "special":
		Game.special_orders.erase(special_order)
		Game.notify.emit("Özel sipariş teslim edildi!", "good")
	haggle = null
	say(["Teşekkürler, iyi günler!", "Kolay gelsin!", "Yine gelirim."][_rng.randi_range(0, 2)])
	basket.clear()
	_leave()


func _give_up() -> void:
	if regular_name != "":
		Game.change_loyalty(regular_name, -10.0)
	angry = true
	say("Bu ne yavaşlık! Gidiyorum.")
	Game.record_lost_customer(true)
	_leave()


func walk_out_calm() -> void:
	haggle = null
	_leave()


func walk_out_angry() -> void:
	haggle = null
	angry = true
	Game.record_lost_customer(true)
	_leave()


func _leave() -> void:
	if state == State.LEAVE or state == State.GONE:
		return
	main.leave_queue(self)
	# Ödenmemiş ürünleri rafa (raf yoksa depoya) geri koy
	for item in basket:
		if item.type == "product":
			var e: Dictionary = Game.furniture_by_uid(int(item.get("shelf", -1)))
			if not e.is_empty() and e.has("shelf"):
				e.shelf[item.id] = int(e.shelf.get(item.id, 0)) + 1
			else:
				Game.stock[item.id] = int(Game.stock.get(item.id, 0)) + 1
	if not basket.is_empty():
		Game.stock_changed.emit()
	basket.clear()
	state = State.LEAVE
	_path = shop.path(position, shop.entrance)
	_path.append(shop.outside + Vector3(_rng.randf_range(-6, 6), 0, 0))


func is_waiting_at_register() -> bool:
	return state == State.REGISTER and _path.is_empty()


# ------------------------------------------------------------------ Hareket

func _follow_path(delta: float) -> bool:
	if _path.is_empty():
		return false
	var target: Vector3 = _path[0]
	var to := target - position
	to.y = 0
	var d := to.length()
	if d < 0.05:
		position = Vector3(target.x, position.y, target.z)
		_path.pop_front()
		return not _path.is_empty()
	var step: float = min(d, _speed * delta)
	position += to / d * step
	var want := Basis.looking_at(to / d, Vector3.UP)
	transform.basis = transform.basis.orthonormalized().slerp(want, clamp(delta * 8.0, 0.0, 1.0))
	return true


func _face(p: Vector3) -> void:
	var to := p - position
	to.y = 0
	if to.length() > 0.01:
		transform.basis = Basis.looking_at(to.normalized(), Vector3.UP)


func _animate(delta: float, moving: bool) -> void:
	if _anim:
		var want_anim: String = _walk_anim if moving else _idle_anim
		if want_anim != "" and _anim.current_animation != want_anim:
			_anim.play(want_anim, 0.25)
		_anim.speed_scale = Game.time_scale if moving else 1.0
		return
	if moving:
		_walk_phase += delta * _speed * 5.5 * Game.time_scale
	else:
		_walk_phase = lerp(_walk_phase, round(_walk_phase / PI) * PI, clamp(delta * 6.0, 0.0, 1.0))
	var swing: float = sin(_walk_phase) * 0.5
	if _legs.size() == 2:
		_legs[0].rotation.x = swing
		_legs[1].rotation.x = -swing
		_arms[0].rotation.x = -swing * 0.7
		_arms[1].rotation.x = swing * 0.7
