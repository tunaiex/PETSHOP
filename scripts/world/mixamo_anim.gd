class_name MixamoAnim
extends RefCounted
## Mixamo iskeletli karakterler için animasyon kurulumu.
## Hazır animasyon dosyası yoksa yürüme ve bekleme animasyonları kodla üretilir:
## her anahtar karede kemiklerin model uzayındaki hedef dönüşleri hesaplanır,
## sonra hiyerarşi sırasıyla yerel poz dönüşüne çevrilir.
##
## Model +Z'ye bakar, Y yukarı. Mixamo dinlenme pozu T-pozdur (kollar yanlara açık).

const PHONE_ANIM := "res://assets/models/characters/anim_telefon.res"
const WALK_LEN := 1.0

static var _phone: Animation = null


## Modelin altına AnimationPlayer ekler: "walk", "idle", varsa "phone".
static func setup(model: Node3D, rng: RandomNumberGenerator) -> AnimationPlayer:
	var sk: Skeleton3D = null
	for c in model.find_children("*", "Skeleton3D", true, false):
		sk = c
		break
	if sk == null:
		return null
	var prefix: String = sk.get_bone_name(0).trim_suffix("Hips")
	var skel_path: String = str(model.get_path_to(sk))
	var lib := AnimationLibrary.new()
	var style := {
		"stride": rng.randf_range(0.85, 1.15),
		"arm": rng.randf_range(0.8, 1.2),
		"bounce": rng.randf_range(0.8, 1.2),
		"lower": rng.randf_range(68.0, 76.0),
	}
	lib.add_animation("walk", _build(sk, prefix, skel_path, true, style))
	lib.add_animation("idle", _build(sk, prefix, skel_path, false, style))
	var phone := _retarget_phone(prefix, skel_path)
	if phone:
		lib.add_animation("phone", phone)
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", lib)
	ap.play("idle")
	ap.seek(rng.randf() * 3.0, true)
	return ap


static func _retarget_phone(prefix: String, skel_path: String) -> Animation:
	if _phone == null:
		if not ResourceLoader.exists(PHONE_ANIM):
			return null
		_phone = load(PHONE_ANIM)
	var a: Animation = _phone.duplicate(true)
	for i in a.get_track_count():
		var p: String = str(a.track_get_path(i))
		var parts: PackedStringArray = p.split(":")
		if parts.size() < 2:
			continue
		var bone: String = parts[1]
		var idx: int = bone.find("_")
		if bone.begins_with("mixamorig") and idx >= 0:
			bone = prefix + bone.substr(idx + 1)
		a.track_set_path(i, NodePath("%s:%s" % [skel_path, bone]))
	a.loop_mode = Animation.LOOP_LINEAR
	return a


static func _q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))


## Bir anahtar karede kemiklerin model uzayındaki ek dönüşleri (dinlenme pozuna göre).
static func _pose(name: String, ph: float, walk: bool, st: Dictionary) -> Quaternion:
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var s: float = sin(ph)
	var lower: float = st.lower
	if walk:
		var swing: float = 24.0 * st.stride
		var arm_sw: float = 20.0 * st.arm
		match name:
			"Hips":
				return _q(Y, 5.0 * s)
			"Spine":
				return _q(Y, -4.0 * s) * _q(X, 3.0)
			"Spine2":
				return _q(Y, -3.0 * s)
			"Neck":
				return _q(Y, 3.5 * s)
			"LeftUpLeg":
				return _q(X, -swing * s)
			"RightUpLeg":
				return _q(X, swing * s)
			"LeftLeg":
				return _q(X, -swing * s + _knee(ph))
			"RightLeg":
				return _q(X, swing * s + _knee(ph + PI))
			"LeftFoot":
				return _q(X, -swing * s + _knee(ph) - _knee(ph) * 0.6 + 6.0 * max(0.0, s))
			"RightFoot":
				return _q(X, swing * s + _knee(ph + PI) - _knee(ph + PI) * 0.6 + 6.0 * max(0.0, -s))
			"LeftArm":
				return _q(X, arm_sw * s) * _q(Z, -lower)
			"RightArm":
				return _q(X, -arm_sw * s) * _q(Z, lower)
			"LeftForeArm":
				return _q(X, arm_sw * s - 18.0 - 8.0 * max(0.0, -s)) * _q(Z, -lower)
			"RightForeArm":
				return _q(X, -arm_sw * s - 18.0 - 8.0 * max(0.0, s)) * _q(Z, lower)
			"LeftHand":
				return _q(X, arm_sw * s - 22.0) * _q(Z, -lower)
			"RightHand":
				return _q(X, -arm_sw * s - 22.0) * _q(Z, lower)
	else:
		var breath: float = sin(ph)
		match name:
			"Hips":
				return _q(Z, 2.0 * sin(ph * 0.5))
			"Spine":
				return _q(X, 1.5 * breath) * _q(Z, -2.0 * sin(ph * 0.5))
			"Spine2":
				return _q(X, 1.0 * breath)
			"Neck":
				return _q(Y, 6.0 * sin(ph * 0.5 + 1.0))
			"LeftUpLeg":
				return _q(Z, -2.0 * sin(ph * 0.5))
			"RightUpLeg":
				return _q(Z, -2.0 * sin(ph * 0.5))
			"LeftArm":
				return _q(X, 2.0 * breath) * _q(Z, -lower - 1.5 * breath)
			"RightArm":
				return _q(X, -2.0 * breath) * _q(Z, lower + 1.5 * breath)
			"LeftForeArm":
				return _q(X, -10.0) * _q(Z, -lower)
			"RightForeArm":
				return _q(X, -10.0) * _q(Z, lower)
			"LeftHand":
				return _q(X, -14.0) * _q(Z, -lower)
			"RightHand":
				return _q(X, -14.0) * _q(Z, lower)
	return Quaternion.IDENTITY


## Diz bükümü: bacak geriden öne gelirken (salınım evresi) bükülür
static func _knee(ph: float) -> float:
	var c: float = sin(ph + 1.2)
	return 8.0 + 42.0 * max(0.0, c) * max(0.0, c)


static func _build(sk: Skeleton3D, prefix: String, skel_path: String, walk: bool, st: Dictionary) -> Animation:
	var a := Animation.new()
	var length: float = WALK_LEN if walk else 6.0
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var names := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
		"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
	var bones := {}
	for n in names:
		var b: int = sk.find_bone(prefix + n)
		if b >= 0:
			bones[n] = b
	var tracks := {}
	for n in bones:
		var t: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("%s:%s" % [skel_path, prefix + n]))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		tracks[n] = t
	var hip_track := -1
	if bones.has("Hips"):
		hip_track = a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(hip_track, NodePath("%s:%s" % [skel_path, prefix + "Hips"]))
		a.track_set_interpolation_type(hip_track, Animation.INTERPOLATION_CUBIC)
	var keys: int = 16 if walk else 24
	for k in keys + 1:
		var tm: float = length * float(k) / keys
		var ph: float = TAU * float(k) / keys
		# Hiyerarşi sırasında global dönüşleri hesapla
		var glob := {}
		for b in sk.get_bone_count():
			var parent: int = sk.get_bone_parent(b)
			var bname: String = sk.get_bone_name(b).trim_prefix(prefix)
			var rest_local: Quaternion = sk.get_bone_rest(b).basis.get_rotation_quaternion()
			var parent_g: Quaternion = glob[parent] if parent >= 0 else Quaternion.IDENTITY
			var rest_g: Quaternion = sk.get_bone_global_rest(b).basis.get_rotation_quaternion()
			if tracks.has(bname):
				var want_g: Quaternion = _pose(bname, ph, walk, st) * rest_g
				var local: Quaternion = parent_g.inverse() * want_g
				a.rotation_track_insert_key(tracks[bname], tm, local.normalized())
				glob[b] = want_g
			else:
				glob[b] = parent_g * rest_local
		if hip_track >= 0:
			var rest_pos: Vector3 = sk.get_bone_rest(bones["Hips"]).origin
			var bob: float = (0.022 * st.bounce * abs(cos(ph))) - 0.02 if walk else 0.004 * sin(ph)
			a.position_track_insert_key(hip_track, tm, rest_pos + Vector3(0.008 * sin(ph) if walk else 0.0, bob, 0))
	return a
