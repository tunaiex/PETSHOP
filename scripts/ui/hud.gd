class_name HUD
extends CanvasLayer
## Tüm arayüz kod ile kuruluyor: üst bilgi çubuğu, nişangâh, etkileşim yazısı,
## bildirimler, dokunmatik kontroller ve paneller.

const C_BG := Color(0.07, 0.1, 0.12, 0.93)
const C_ACCENT := Color(0.18, 0.62, 0.66)
const C_GOOD := Color(0.35, 0.8, 0.45)
const C_WARN := Color(1.0, 0.75, 0.25)
const C_BAD := Color(1.0, 0.38, 0.32)

var main: Node
var player: Player
var builder: Builder

var _root: Control
var _theme: Theme
var _money: Label
var _clock: Label
var _day: Label
var _rep: Label
var _phase: Label
var _prompt: Label
var _cross: Control
var _toasts: VBoxContainer
var _panel: PanelContainer
var _panel_refresh: Callable
var _refresh_timer: float = 0.0
var _touch := false
var _joy_base: Control
var _joy_knob: Control
var _joy_index: int = -1
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_index: int = -1
var _look_last := Vector2.ZERO
var _interact_btn: Button
var _menu_btn: Button
var _speed_btn: Button
var _phone_btn: Button
var _build_bar: PanelContainer
var _build_lbl: Label
var _build_btns: Array = []
var _carry_btn: Button
var _drop_btn: Button
var _haggle_customer: Customer
var _ask_value: int = 0


func _ready() -> void:
	layer = 10
	_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_theme = _make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vig.material = vm
	_root.add_child(vig)
	_build_topbar()
	_build_center()
	_build_touch()
	_build_build_bar()
	_carry_btn = Button.new()
	_carry_btn.text = "DEPOYA KOY"
	_carry_btn.add_theme_font_size_override("font_size", 22)
	_carry_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_carry_btn.offset_left = -470
	_carry_btn.offset_top = -150
	_carry_btn.offset_right = -260
	_carry_btn.offset_bottom = -50
	_carry_btn.visible = false
	_carry_btn.pressed.connect(func(): Game.carry_to_depot(); Game.notify.emit("Koli depoya kondu.", "info"))
	_root.add_child(_carry_btn)
	_drop_btn = Button.new()
	_drop_btn.text = "YERE BIRAK"
	_drop_btn.add_theme_font_size_override("font_size", 22)
	_drop_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drop_btn.offset_left = -690
	_drop_btn.offset_top = -150
	_drop_btn.offset_right = -480
	_drop_btn.offset_bottom = -50
	_drop_btn.visible = false
	_drop_btn.pressed.connect(func(): if player: player.drop_carrying())
	_root.add_child(_drop_btn)
	Game.carry_changed.connect(func():
		_carry_btn.visible = not Game.carrying.is_empty() and not Game.is_animal_box(Game.carrying)
		_carry_btn.text = "DEPOYA KOY" if _touch else "DEPOYA KOY [G]"
		_drop_btn.visible = not Game.carrying.is_empty()
		_drop_btn.text = "YERE BIRAK" if _touch else "YERE BIRAK [B]")
	Game.money_changed.connect(func(_v): _refresh_top())
	Game.time_changed.connect(func(_m): _refresh_top())
	Game.phase_changed.connect(func(_p): _refresh_top())
	Game.notify.connect(toast)
	_refresh_top()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = C_BG
	panel.set_corner_radius_all(16)
	panel.set_content_margin_all(18)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 10
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = C_ACCENT
	btn.set_corner_radius_all(10)
	btn.content_margin_left = 16
	btn.content_margin_right = 16
	btn.content_margin_top = 10
	btn.content_margin_bottom = 10
	var hov := btn.duplicate()
	hov.bg_color = C_ACCENT.lightened(0.15)
	var prs := btn.duplicate()
	prs.bg_color = C_ACCENT.darkened(0.2)
	var dis := btn.duplicate()
	dis.bg_color = Color(0.3, 0.33, 0.35)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", prs)
	t.set_stylebox("disabled", "Button", dis)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.7))
	t.set_color("font_color", "Label", Color(0.93, 0.95, 0.96))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.22, 0.25)
	bar_bg.set_corner_radius_all(6)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = C_GOOD
	bar_fg.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	return t


func _build_topbar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 10
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.1, 0.72)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	bar.add_child(hb)
	_money = _lbl("", 26, C_GOOD)
	_day = _lbl("", 22)
	_clock = _lbl("", 26)
	_rep = _lbl("", 22, C_WARN)
	_phase = _lbl("", 20)
	for l in [_money, _day, _clock, _rep, _phase]:
		hb.add_child(l)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sp)
	_phone_btn = Button.new()
	_phone_btn.text = "TELEFON"
	_phone_btn.pressed.connect(open_phone)
	hb.add_child(_phone_btn)
	_speed_btn = Button.new()
	_speed_btn.text = "Hız ×1"
	_speed_btn.pressed.connect(_cycle_speed)
	hb.add_child(_speed_btn)
	_menu_btn = Button.new()
	_menu_btn.text = "  ≡  "
	_menu_btn.pressed.connect(open_menu)
	hb.add_child(_menu_btn)


func _build_center() -> void:
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func():
		_cross.draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.85))
		_cross.draw_arc(Vector2.ZERO, 7.0, 0, TAU, 24, Color(0, 0, 0, 0.35), 1.5))
	_root.add_child(_cross)
	_prompt = _lbl("", 24)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = 22
	_prompt.offset_bottom = 60
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	_root.add_child(_prompt)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -470
	_toasts.offset_right = -14
	_toasts.offset_top = 80
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	_root.add_child(_toasts)


func _build_touch() -> void:
	_joy_base = Control.new()
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.visible = false
	_joy_base.size = Vector2(1, 1)
	_joy_base.draw.connect(func():
		_joy_base.draw_circle(Vector2.ZERO, 90.0, Color(1, 1, 1, 0.12))
		_joy_base.draw_arc(Vector2.ZERO, 90.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0))
	_root.add_child(_joy_base)
	_joy_knob = Control.new()
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.draw.connect(func(): _joy_knob.draw_circle(Vector2.ZERO, 40.0, Color(1, 1, 1, 0.45)))
	_joy_base.add_child(_joy_knob)
	_interact_btn = Button.new()
	_interact_btn.text = "ETKİLEŞ"
	_interact_btn.add_theme_font_size_override("font_size", 26)
	_interact_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_interact_btn.offset_left = -230
	_interact_btn.offset_top = -150
	_interact_btn.offset_right = -40
	_interact_btn.offset_bottom = -50
	_interact_btn.pressed.connect(func(): if player: player.try_interact())
	_interact_btn.visible = _touch
	_root.add_child(_interact_btn)
	if _touch:
		var hint := _lbl("Sol: yürü  •  Sağ: bak", 18, Color(1, 1, 1, 0.6))
		hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		hint.offset_left = 30
		hint.offset_top = -40
		hint.offset_bottom = -10
		hint.offset_right = 400
		_root.add_child(hint)


func _build_build_bar() -> void:
	_build_bar = PanelContainer.new()
	_build_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_build_bar.offset_left = -440
	_build_bar.offset_right = 440
	_build_bar.offset_top = -150
	_build_bar.offset_bottom = -20
	_build_bar.visible = false
	_root.add_child(_build_bar)
	var vb := VBoxContainer.new()
	_build_bar.add_child(vb)
	_build_lbl = _lbl("", 20)
	_build_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_build_lbl)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	for spec in [["⟲ 15°", func(): builder.rotate_by(Builder.ROT_STEP)], ["⟳ 15°", func(): builder.rotate_by(-Builder.ROT_STEP)], ["⟲ 90°", func(): builder.rotate_by(90.0)], ["YERLEŞTİR", func(): builder.confirm()], ["İptal", func(): builder.cancel()]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(120, 56)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(spec[1])
		hb.add_child(b)
		_build_btns.append(b)


## Builder durumu değişince çağrılır.
func on_build_state() -> void:
	var on: bool = builder != null and builder.active
	_build_bar.visible = on
	_interact_btn.visible = _touch and not on
	if on and not _touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _lbl(text: String, size: int = 22, color: Color = Color(0.93, 0.95, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh_top() -> void:
	_money.text = "%s ₺" % Aquarium._fmt(Game.money)
	_money.add_theme_color_override("font_color", C_GOOD if Game.money >= 0 else C_BAD)
	_day.text = "Gün %d" % Game.day
	_clock.text = Game.clock_text()
	var stars := int(round(Game.reputation / 20.0))
	_rep.text = "★".repeat(stars) + "☆".repeat(5 - stars)
	match Game.phase:
		"prep":
			_phase.text = "Hazırlık: dükkânı kur, sonra kapıdan aç"
		"open":
			_phase.text = "Açık • %s%s" % [{"gunesli": "Güneşli", "bulutlu": "Bulutlu", "yagmurlu": "Yağmurlu"}.get(Game.weather, ""), " • ELEKTRİK YOK" if Game.power_out else ""]
		"closing":
			_phase.text = "Kapanıyor"
		_:
			_phase.text = ""


func _cycle_speed() -> void:
	var speeds := [1.0, 2.0, 4.0]
	var i := speeds.find(Game.time_scale)
	Game.time_scale = speeds[(i + 1) % speeds.size()]
	_speed_btn.text = "Hız ×%d" % int(Game.time_scale)


# ------------------------------------------------------------------ Dokunmatik

func joystick_vector() -> Vector2:
	return _joy_vec


func _input(event: InputEvent) -> void:
	if not _touch:
		return
	if event is InputEventScreenTouch:
		var vp := _root.get_viewport_rect().size
		if event.pressed:
			if is_blocking() or _over_button(event.position):
				return
			if event.position.x < vp.x * 0.42 and _joy_index == -1:
				_joy_index = event.index
				_joy_center = event.position
				_joy_base.position = event.position
				_joy_knob.position = Vector2.ZERO
				_joy_base.visible = true
				_joy_base.queue_redraw()
				_joy_knob.queue_redraw()
			elif _look_index == -1:
				_look_index = event.index
				_look_last = event.position
		else:
			if event.index == _joy_index:
				_joy_index = -1
				_joy_vec = Vector2.ZERO
				_joy_base.visible = false
			elif event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _joy_index:
			var d: Vector2 = event.position - _joy_center
			if d.length() > 90.0:
				d = d.normalized() * 90.0
			_joy_knob.position = d
			_joy_vec = d / 90.0
		elif event.index == _look_index and player and not is_blocking():
			player.look(event.position - _look_last, Player.TOUCH_SENS)
			_look_last = event.position


func _over_button(p: Vector2) -> bool:
	for b in [_interact_btn, _menu_btn, _speed_btn, _phone_btn, _carry_btn, _drop_btn] + _build_btns:
		if b.visible and b.is_visible_in_tree() and b.get_global_rect().has_point(p):
			return true
	return false


# ------------------------------------------------------------------ Genel

func set_prompt(text: String) -> void:
	if is_blocking():
		_prompt.text = ""
		return
	if text == "":
		_prompt.text = ""
	else:
		_prompt.text = text if _touch else "[E] " + text
	_cross.modulate = C_ACCENT.lightened(0.3) if text != "" else Color.WHITE


func toast(text: String, kind: String = "info") -> void:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var col: Color = {"good": C_GOOD, "warn": C_WARN, "bad": C_BAD}.get(kind, C_ACCENT)
	sb.bg_color = Color(0.06, 0.08, 0.1, 0.88)
	sb.border_color = col
	sb.border_width_left = 5
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(text, 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	pc.add_child(l)
	_toasts.add_child(pc)
	while _toasts.get_child_count() > 5:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)


func is_blocking() -> bool:
	return _panel != null and is_instance_valid(_panel)


func close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_panel_refresh = Callable()
	_haggle_customer = null
	if player and player.hands and player.hands.kind() == "net":
		player.hands.clear()
		if not Game.carrying.is_empty():
			player.hands.hold_box(Game.carrying)
	if not _touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open(title: String, width: float = 760) -> VBoxContainer:
	if is_blocking():
		_root.remove_child(_panel)
		_panel.queue_free()
	_panel_refresh = Callable()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_joy_vec = Vector2.ZERO
	_joy_index = -1
	_look_index = -1
	if _joy_base:
		_joy_base.visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(width, 0)
	_root.add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := _lbl(title, 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Button.new()
	x.text = " ✕ "
	x.pressed.connect(close_panel)
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vp := _root.get_viewport_rect().size
	scroll.custom_minimum_size = Vector2(width - 36, min(520.0, vp.y - 170.0))
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	_center_panel.call_deferred()
	return body


func _center_panel() -> void:
	if not is_blocking():
		return
	var vp := _root.get_viewport_rect().size
	var s := _panel.get_combined_minimum_size()
	_panel.position = (vp - s) * 0.5
	_panel.size = s


## Paneli temizler. Tıklanan butonun kendi sinyali sürerken silinmemesi için
## önce ağaçtan çıkarılır, sonra kare sonunda silinir (queue_free).
func _clear(body: VBoxContainer) -> void:
	for c in body.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()


func _row(parent: Control) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	parent.add_child(hb)
	return hb


func _btn(parent: Control, text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _bar(parent: Control, label: String, value: float, good_high: bool = true) -> void:
	var hb := _row(parent)
	var l := _lbl(label, 20)
	l.custom_minimum_size.x = 170
	hb.add_child(l)
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(300, 22)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var q: float = value if good_high else 100.0 - value
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(6)
	fill.bg_color = C_GOOD if q > 60 else (C_WARN if q > 30 else C_BAD)
	pb.add_theme_stylebox_override("fill", fill)
	hb.add_child(pb)
	var v := _lbl("%d%%" % int(value), 20)
	v.custom_minimum_size.x = 60
	hb.add_child(v)


func _process(delta: float) -> void:
	if builder and builder.active:
		var info: Dictionary = FurnitureDB.item(builder.type)
		var price: String = "" if builder.moving_uid >= 0 else " • %s ₺" % Aquarium._fmt(int(info.price))
		var hint: String = "" if _touch else "   [R/teker: döndür • E/tık: yerleştir • ESC: iptal]"
		_build_lbl.text = "%s%s • %d°  %s%s" % [info.name, price, int(builder.rot), "✓ Uygun" if builder.valid else "✗ " + builder.reason, hint]
		_build_lbl.add_theme_color_override("font_color", C_GOOD if builder.valid else C_BAD)
	if _panel_refresh.is_valid():
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = 1.0
			_panel_refresh.call()


# ------------------------------------------------------------------ Akvaryum paneli

func open_tank(aq: Aquarium) -> void:
	var t0: Dictionary = Game.tanks[aq.tank_id]
	var title: String = "Tank %d" % (aq.tank_id + 1)
	if TankSim.is_dry(t0):
		title = "%s %d" % [FishDB.habitat_name(TankSim.habitat_of(t0)).capitalize(), aq.tank_id + 1]
	var body := _open(title, 860)
	var fill := func(): _fill_tank(body, aq)
	fill.call()
	_panel_refresh = fill


func _buy_equipment(body: VBoxContainer, aq: Aquarium, key: String) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	var info: Dictionary = FurnitureDB.EQUIPMENT[key]
	if Game.spend(int(info.price)):
		match key:
			"gravel_natural":
				t.gravel = "natural"
			"gravel_white":
				t.gravel = "white"
			"heater":
				t.heater_on = true
			"light":
				t.light = true
			"air":
				t.air = true
		Game.tank_changed.emit(aq.tank_id)
		Game.notify.emit("%s takıldı." % info.name, "good")
	_fill_tank(body, aq)


func _buy_decor(body: VBoxContainer, aq: Aquarium, key: String) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if t.decor.size() >= FurnitureDB.MAX_DECOR:
		Game.notify.emit("Tankta dekor için yer kalmadı.", "bad")
		return
	if Game.spend(int(FurnitureDB.DECOR[key].price)):
		t.decor.append(key)
		Game.tank_changed.emit(aq.tank_id)
	_fill_tank(body, aq)


func _remove_decor(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if not t.decor.is_empty():
		t.decor.pop_back()
		Game.tank_changed.emit(aq.tank_id)
	_fill_tank(body, aq)


func _upgrade_filter(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	var fl: int = int(t.filter)
	if fl < 3 and Game.spend(TankSim.FILTER_COST[fl + 1]):
		t.filter = fl + 1
		Game.tank_changed.emit(aq.tank_id)
		Game.notify.emit("Filtre seviye %d." % (fl + 1), "good")
	_fill_tank(body, aq)


func _remove_shelf_tank(aq: Aquarium) -> void:
	var err: String = Game.remove_shelf_tank(aq.furniture_uid, aq.shelf_level)
	if err != "":
		toast(err, "bad")
		return
	close_panel()


func _place_shelf_tank(body: VBoxContainer, sh: Shelf, lvl: int) -> void:
	var err: String = Game.place_shelf_tank(sh.furniture_uid, lvl)
	if err != "":
		toast(err, "bad")
	else:
		Sfx.play("kaching")
		toast("Rafa küçük akvaryum kondu. Kum, filtre ekleyip balık koyabilirsin.", "good")
	_fill_shelf(body, sh)


func _remove_rack_tank(aq: Aquarium) -> void:
	var err: String = Game.remove_rack_tank(aq.furniture_uid, aq.rack_level)
	if err != "":
		toast(err, "bad")
		return
	close_panel()


func _feed(body: VBoxContainer, aq: Aquarium, pid: String) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if Game.use_stock(pid):
		var food: String = ProductDB.get_product(pid).food
		var fit: float = TankSim.food_match(t, food)
		var extra := TankSim.feed(t, food)
		aq.play_feed()
		Sfx.play("bubble")
		if player:
			player.hands.hold_food(pid)
		if extra > 0.0:
			Game.notify.emit("Fazla yem verdin, su kirlendi!", "warn")
		elif fit < 0.99:
			Game.notify.emit("Bu yem tanktaki bazı balıklara uygun değil, az doydular.", "warn")
		Game.tank_changed.emit(aq.tank_id)
	_fill_tank(body, aq)


func _water_change(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if Game.use_stock("su_duzenleyici"):
		TankSim.water_change(t)
		Game.tank_changed.emit(aq.tank_id)
		Game.notify.emit("Suyun yarısı değiştirildi.", "good")
	_fill_tank(body, aq)


func _medicate(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if Game.use_stock("ilac"):
		TankSim.medicate(t)
		Game.tank_changed.emit(aq.tank_id)
		Game.notify.emit("İlaç verildi.", "good")
	_fill_tank(body, aq)


func _remove_dead(body: VBoxContainer, aq: Aquarium) -> void:
	var n := TankSim.remove_dead(Game.tanks[aq.tank_id])
	Game.tank_changed.emit(aq.tank_id)
	Game.notify.emit("%d ölü balık çıkarıldı." % n, "info")
	_fill_tank(body, aq)


func _toggle_salt(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	var salt: bool = bool(t.salt)
	if not TankSim.living(t).is_empty():
		Game.notify.emit("Önce tanktaki balıkları sat.", "bad")
		return
	if Game.spend(TankSim.SALT_COST):
		TankSim.set_salt(t, not salt)
		t.decor = []
		Game.tank_changed.emit(aq.tank_id)
		Game.notify.emit("Tank %d artık %s." % [aq.tank_id + 1, "tatlı su" if salt else "tuzlu su (deniz) tankı"], "good")
	_fill_tank(body, aq)


func _heater(body: VBoxContainer, aq: Aquarium, d: float) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	t.heater = clamp(t.heater + d, TankSim.ROOM_TEMP, 32.0)
	_fill_tank(body, aq)


func _section(body: VBoxContainer, text: String) -> void:
	body.add_child(HSeparator.new())
	body.add_child(_lbl(text, 23, C_ACCENT.lightened(0.45)))


func _warn(body: VBoxContainer, text: String, col: Color = C_WARN) -> void:
	var l := _lbl(text, 20, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 780
	body.add_child(l)


func _flow(body: VBoxContainer) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	body.add_child(f)
	return f


func _fill_tank(body: VBoxContainer, aq: Aquarium) -> void:
	_clear(body)
	var t: Dictionary = Game.tanks[aq.tank_id]
	var salt: bool = bool(t.salt)
	if TankSim.is_dry(t):
		_fill_dry(body, aq, t)
		return
	var info := _row(body)
	info.add_child(_lbl("%s • Su %.1f°C" % ["Tuzlu su" if salt else "Tatlı su", t.temp], 21))
	if t.heater_on:
		info.add_child(_lbl("  Isıtıcı %.0f°C" % t.heater, 21))
		_btn(info, " − ", _heater.bind(body, aq, -1.0))
		_btn(info, " + ", _heater.bind(body, aq, 1.0))
	_bar(body, "Su temizliği", 100.0 - t.dirt)
	_bar(body, "Tokluk", t.food)
	_bar(body, "Su olgunluğu", t.cycle)
	_bar(body, "Çekicilik", TankSim.appeal(t))
	if t.cycle < 60.0:
		_warn(body, "Dikkat: Yeni kurulan su henüz olgunlaşmadı (yararlı bakteri yok). Balık koyarsan zorlanırlar. Filtre olgunlaşmayı hızlandırır.")
	if t.sick:
		_warn(body, "⚠ Beyaz benek hastalığı! (%d%%) İlaç ver ve suyu değiştir." % int(t.sick_level * 100), C_BAD)
	var dead := TankSim.dead_count(t)
	if dead > 0:
		_warn(body, "⚠ Tankta %d ölü balık var, suyu hızla kirletiyor!" % dead, C_BAD)
	var sps: Array = TankSim.species_in(t)
	for i in sps.size():
		for j in range(i + 1, sps.size()):
			var r: String = FishDB.conflict_reason(sps[i], sps[j])
			if r != "":
				_warn(body, "⚠ " + r)
	for sp in sps:
		var s: Dictionary = FishDB.get_species(sp)
		if t.temp < s.temp_min - 0.5 or t.temp > s.temp_max + 0.5:
			_warn(body, "⚠ %s için su %s (ideal %d-%d°C)%s" % [s.name, "soğuk" if t.temp < s.temp_min else "sıcak", int(s.temp_min), int(s.temp_max), "" if t.heater_on else " — ısıtıcı yok!"])

	var acts := _flow(body)
	for pid in ProductDB.food_ids():
		var fp: Dictionary = ProductDB.get_product(pid)
		var ideal: bool = TankSim.food_match(t, fp.food) > 0.99 and not TankSim.living(t).is_empty()
		_btn(acts, "%s%s (%d)" % ["★ " if ideal else "", fp.name, Game.stock.get(pid, 0)], _feed.bind(body, aq, pid))
	_btn(acts, "Su değiştir (%d)" % Game.stock.get("su_duzenleyici", 0), _water_change.bind(body, aq))
	_btn(acts, "İlaç ver (%d)" % Game.stock.get("ilac", 0), _medicate.bind(body, aq), t.sick)
	_btn(acts, "Ölüleri çıkar", _remove_dead.bind(body, aq), dead > 0)

	_section(body, "Ekipman")
	var eq := _flow(body)
	var gravel_key := "gravel_white" if salt else "gravel_natural"
	var have := {"gravel_natural": str(t.gravel) != "", "gravel_white": str(t.gravel) != "", "heater": t.heater_on, "light": t.light, "air": t.air}
	for key in [gravel_key, "heater", "light", "air"]:
		var e: Dictionary = FurnitureDB.EQUIPMENT[key]
		if have[key]:
			eq.add_child(_lbl("✓ %s" % e.name, 19, C_GOOD))
		else:
			var b := _btn(eq, "%s (%d ₺)" % [e.name, e.price], _buy_equipment.bind(body, aq, key), Game.money >= int(e.price))
			b.tooltip_text = e.desc
	var fl: int = int(t.filter)
	if fl < 3:
		_btn(eq, ("Filtre al" if fl == 0 else "Filtre Sv.%d→%d" % [fl, fl + 1]) + " (%d ₺)" % TankSim.FILTER_COST[fl + 1], _upgrade_filter.bind(body, aq), Game.money >= TankSim.FILTER_COST[fl + 1])
	else:
		eq.add_child(_lbl("✓ Filtre Sv.3", 19, C_GOOD))

	_section(body, "Dekor (%d/%d)" % [t.decor.size(), FurnitureDB.MAX_DECOR])
	var dec := _flow(body)
	for key in FurnitureDB.decor_for(salt):
		var d: Dictionary = FurnitureDB.DECOR[key]
		_btn(dec, "%s (%d ₺)" % [d.name, d.price], _buy_decor.bind(body, aq, key), Game.money >= int(d.price) and t.decor.size() < FurnitureDB.MAX_DECOR)
	if not t.decor.is_empty():
		_btn(dec, "Son dekoru kaldır", _remove_decor.bind(body, aq))

	_section(body, "Balıklar (yer: %d/%d)" % [TankSim.space_used(t), TankSim.capacity(t)])
	var alive: Array = TankSim.living(t)
	if alive.is_empty():
		body.add_child(_lbl("Tank boş. Telefondan balık sipariş et.", 20))
	var groups := {}
	for f in alive:
		if not groups.has(f.species):
			groups[f.species] = []
		groups[f.species].append(f)
	for f in alive:
		if f.get("rare", false):
			var rr := _row(body)
			rr.add_child(_lbl("★ NADİR: %s %s — değer %d ₺" % [f.get("rare_name", ""), FishDB.display_name(f.species), FishDB.fish_value(f)], 20, Color(1.0, 0.85, 0.35)))
	if t.get("quarantine", false):
		var newc: int = alive.filter(func(f): return f.get("new", false)).size()
		_warn(body, "KARANTİNA TANKI: Müşteriler bu tanka bakmaz. %d balık gözlemde (her biri %d dk). Gözlemi biten balıkları satış tankına taşı." % [newc, int(TankSim.QUARANTINE_MIN)], Color(0.6, 0.85, 1.0))
	for sp in groups:
		var arr: Array = groups[sp]
		var h := 0.0
		var v := 0
		for f in arr:
			h += f.health
			v += FishDB.fish_value(f)
		h /= arr.size()
		var row := _row(body)
		var nm := _lbl("%s ×%d" % [FishDB.display_name(sp), arr.size()], 21)
		nm.custom_minimum_size.x = 260
		row.add_child(nm)
		var hl := _lbl("Sağlık %d%%" % int(h), 20)
		hl.add_theme_color_override("font_color", C_GOOD if h > 70 else (C_WARN if h > 40 else C_BAD))
		hl.custom_minimum_size.x = 150
		row.add_child(hl)
		row.add_child(_lbl("Değer ~%d ₺/adet" % int(v / arr.size()), 20))
		var obs: int = arr.filter(func(f): return f.get("new", false)).size()
		if t.get("quarantine", false) and obs > 0:
			row.add_child(_lbl(" gözlemde %d" % obs, 18, Color(0.6, 0.85, 1.0)))
		_btn(row, "Taşı →", _fill_move.bind(body, aq, sp))

	_section(body, "Tank")
	var mv := _flow(body)
	if not aq.terrarium:
		_btn(mv, "Tuzlu suya çevir" if not salt else "Tatlı suya çevir", _toggle_salt.bind(body, aq), alive.is_empty() and Game.money >= TankSim.SALT_COST).tooltip_text = "%d ₺ (tuz, test kiti). Sadece boş tankta." % TankSim.SALT_COST
		_btn(mv, "Kuru teraryuma çevir (örümcek) %d ₺" % DRY_COST, _toggle_dry.bind(body, aq), alive.is_empty() and Game.money >= DRY_COST)
	_btn(mv, "Fotoğraf çek ve paylaş", _photo.bind(body, aq), not Game.photos_today.has(aq.tank_id))
	_btn(mv, "Karantina: %s" % ("AÇIK" if t.get("quarantine", false) else "KAPALI"), _toggle_quarantine.bind(body, aq))
	if aq.shelf_level >= 0:
		_btn(mv, "Akvaryumu raftan kaldır (%d ₺)" % (Game.SHELF_TANK_PRICE / 2), _remove_shelf_tank.bind(aq), t.fish.is_empty())
	elif aq.rack_level >= 0:
		_btn(mv, "Rafı taşı", _move_furniture.bind(aq.furniture_uid))
		_btn(mv, "Akvaryumu raftan kaldır (%d ₺)" % (Game.RACK_TANK_PRICE / 2), _remove_rack_tank.bind(aq), t.fish.is_empty())
	else:
		_btn(mv, "Taşı", _move_furniture.bind(aq.furniture_uid))
		_btn(mv, "Sat (%d ₺)" % (int(FurnitureDB.item(Game.furniture_by_uid(aq.furniture_uid).get("type", "akvaryum_beyaz")).price) / 2), _sell_furniture.bind(aq.furniture_uid), t.fish.is_empty())


const DRY_COST := 150


## Boş akvaryumu kuru teraryuma (örümcek için) çevirir ya da geri akvaryum yapar.
func _toggle_dry(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if not TankSim.living(t).is_empty():
		toast("Önce içindeki hayvanları taşı ya da sat.", "bad")
		return
	if not Game.spend(DRY_COST):
		return
	if TankSim.is_dry(t):
		t.kind = ""
		t.gravel = ""
		t.cycle = 0.0
		toast("Tank %d yeniden akvaryum oldu. Kum ve filtre kur, su olgunlaşsın." % (aq.tank_id + 1), "info")
	else:
		t.kind = "kuru"
		t.salt = false
		t.gravel = "toprak"
		t.decor = t.decor.filter(func(k): return FurnitureDB.DECOR[k].salt != true)
		toast("Tank %d kuru teraryum oldu: toprak serildi. Artık örümcek konabilir." % (aq.tank_id + 1), "good")
	Game.tank_changed.emit(aq.tank_id)
	_fill_tank(body, aq)


## Suyu olmayan bölmeler (hamster/civciv kafesi, kuru teraryum) için sade panel.
func _fill_dry(body: VBoxContainer, aq: Aquarium, t: Dictionary) -> void:
	var hab: String = TankSim.habitat_of(t)
	body.add_child(_lbl("%s • Oda %.1f°C" % [FishDB.habitat_name(hab).capitalize(), t.temp], 21))
	_bar(body, "Temizlik", 100.0 - t.dirt)
	_bar(body, "Tokluk", t.food)
	_bar(body, "Çekicilik", TankSim.appeal(t))
	var dead := TankSim.dead_count(t)
	if dead > 0:
		_warn(body, "⚠ %d ölü hayvan var! Hemen çıkar." % dead, C_BAD)
	if t.dirt > 60.0:
		_warn(body, "⚠ Çok kirli: hayvanlar hastalanıyor. Temizle!", C_BAD)
	var acts := _flow(body)
	for pid in ProductDB.food_ids():
		var fp: Dictionary = ProductDB.get_product(pid)
		var ideal: bool = TankSim.food_match(t, fp.food) > 0.99 and not TankSim.living(t).is_empty()
		_btn(acts, "%s%s (%d)" % ["★ " if ideal else "", fp.name, Game.stock.get(pid, 0)], _feed.bind(body, aq, pid))
	_btn(acts, "%s (%d ₺)" % ["Talaşı değiştir" if hab != "kuru" else "Toprağı temizle", CLEAN_COST], _clean_pen.bind(body, aq), Game.money >= CLEAN_COST)
	_btn(acts, "Ölüleri çıkar", _remove_dead.bind(body, aq), dead > 0)
	if hab == "kuru":
		_section(body, "Dekor (%d/%d)" % [t.decor.size(), FurnitureDB.MAX_DECOR])
		var dec := _flow(body)
		for key in ["kaya", "kirik_kaya", "kok", "amfora"]:
			var d: Dictionary = FurnitureDB.DECOR[key]
			_btn(dec, "%s (%d ₺)" % [d.name, d.price], _buy_decor.bind(body, aq, key), Game.money >= int(d.price) and t.decor.size() < FurnitureDB.MAX_DECOR)
		if not t.decor.is_empty():
			_btn(dec, "Son dekoru kaldır", _remove_decor.bind(body, aq))
	_section(body, "Hayvanlar (yer: %d/%d)" % [TankSim.space_used(t), TankSim.capacity(t)])
	var alive: Array = TankSim.living(t)
	if alive.is_empty():
		body.add_child(_lbl("Boş. Telefondan sipariş et, kargo gelince alıp buraya bırak.", 20))
	var groups := {}
	for f in alive:
		if not groups.has(f.species):
			groups[f.species] = []
		groups[f.species].append(f)
	for sp in groups:
		var arr: Array = groups[sp]
		var h := 0.0
		for f in arr:
			h += f.health
		h /= arr.size()
		var row := _row(body)
		var nm := _lbl("%s ×%d" % [FishDB.display_name(sp), arr.size()], 21)
		nm.custom_minimum_size.x = 260
		row.add_child(nm)
		var hl := _lbl("Sağlık %d%%" % int(h), 20)
		hl.add_theme_color_override("font_color", C_GOOD if h > 70 else (C_WARN if h > 40 else C_BAD))
		row.add_child(hl)
		row.add_child(_lbl("  Değer ~%d ₺/adet" % FishDB.market_value(sp, h), 20))
		_btn(row, "Taşı →", _fill_move.bind(body, aq, sp))
	_section(body, "Kafes" if hab != "kuru" else "Teraryum")
	var mv := _flow(body)
	if hab == "kuru":
		_btn(mv, "Tekrar akvaryum yap (%d ₺)" % DRY_COST, _toggle_dry.bind(body, aq), alive.is_empty() and Game.money >= DRY_COST)
	_btn(mv, "Fotoğraf çek ve paylaş", _photo.bind(body, aq), not Game.photos_today.has(aq.tank_id))
	if aq.shelf_level >= 0:
		_btn(mv, "Akvaryumu raftan kaldır (%d ₺)" % (Game.SHELF_TANK_PRICE / 2), _remove_shelf_tank.bind(aq), t.fish.is_empty())
	elif aq.rack_level >= 0:
		_btn(mv, "Rafı taşı", _move_furniture.bind(aq.furniture_uid))
		_btn(mv, "Akvaryumu raftan kaldır (%d ₺)" % (Game.RACK_TANK_PRICE / 2), _remove_rack_tank.bind(aq), t.fish.is_empty())
	else:
		_btn(mv, "Taşı", _move_furniture.bind(aq.furniture_uid))
		_btn(mv, "Sat (%d ₺)" % (int(FurnitureDB.item(Game.furniture_by_uid(aq.furniture_uid).get("type", "akvaryum_beyaz")).price) / 2), _sell_furniture.bind(aq.furniture_uid), t.fish.is_empty())


const CLEAN_COST := 15


func _clean_pen(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if Game.spend(CLEAN_COST):
		t.dirt = max(0.0, t.dirt - 70.0)
		Sfx.play("click")
		Game.tank_changed.emit(aq.tank_id)
	_fill_tank(body, aq)


func _toggle_quarantine(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	t["quarantine"] = not t.get("quarantine", false)
	toast("Tank %d karantina %s." % [aq.tank_id + 1, "tankı oldu" if t.quarantine else "olmaktan çıktı"], "info")
	_fill_tank(body, aq)


## Bir türün balıklarını başka tanka taşıma ekranı
func _fill_move(body: VBoxContainer, aq: Aquarium, sp: String) -> void:
	_clear(body)
	var src: Dictionary = Game.tanks[aq.tank_id]
	var n: int = TankSim.living(src).filter(func(f): return f.species == sp).size()
	body.add_child(_lbl("%d %s nereye taşınsın? (kepçeyle)" % [n, FishDB.display_name(sp)], 22))
	var any := false
	for t in Game.tanks:
		if not t.unlocked or t.id == aq.tank_id or TankSim.habitat_of(t) != FishDB.habitat(sp):
			continue
		any = true
		var row := _row(body)
		var warn: String = TankSim.check_add(t, sp)
		var l := _lbl("Tank %d%s (%d/%d yer)%s" % [t.id + 1, " • karantina" if t.get("quarantine", false) else "", TankSim.space_used(t), TankSim.capacity(t), ("  ⚠ " + warn) if warn != "" else ""], 19, C_WARN if warn != "" else Color(0.93, 0.95, 0.96))
		l.custom_minimum_size.x = 560
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		_btn(row, "1 tane", _do_move.bind(body, aq, t.id, sp, 1))
		_btn(row, "Hepsi", _do_move.bind(body, aq, t.id, sp, n))
	if not any:
		body.add_child(_lbl("Bu türe uygun başka tank/kafes yok.", 20))
	_btn(body, "Geri", _fill_tank.bind(body, aq))


func _do_move(body: VBoxContainer, aq: Aquarium, dst_id: int, sp: String, n: int) -> void:
	var moved: int = TankSim.move_fish(Game.tanks[aq.tank_id], Game.tanks[dst_id], sp, n)
	Game.tank_changed.emit(aq.tank_id)
	Game.tank_changed.emit(dst_id)
	Sfx.play("splash", -10.0)
	toast("%d %s Tank %d'e taşındı." % [moved, FishDB.display_name(sp), dst_id + 1] if moved > 0 else "Hedef tankta yer yok.", "good" if moved > 0 else "bad")
	_fill_tank(body, aq)


# ------------------------------------------------------------------ Eşya genel

func _move_furniture(uid: int) -> void:
	close_panel()
	if builder:
		builder.start_move(uid)


func _sell_furniture(uid: int) -> void:
	var err: String = Game.sell_furniture(uid)
	if err != "":
		toast(err, "bad")
		return
	toast("Eşya satıldı, yarı parası iade edildi.", "info")
	close_panel()


func open_furniture(item: FurnitureItem) -> void:
	var info: Dictionary = FurnitureDB.item(item.type)
	var body := _open(info.name, 620)
	var d := _lbl(info.desc, 20)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 560
	body.add_child(d)
	var row := _row(body)
	_btn(row, "Taşı", _move_furniture.bind(item.furniture_uid))
	_btn(row, "Sat (%d ₺)" % (int(info.price) / 2), _sell_furniture.bind(item.furniture_uid))


# ------------------------------------------------------------------ Raf

func open_shelf(sh: Shelf) -> void:
	var body := _open(FurnitureDB.item(sh.kind).name, 820)
	_fill_shelf(body, sh)


func _shelf_move(body: VBoxContainer, sh: Shelf, pid: String, n: int) -> void:
	var moved: int
	if n > 0:
		moved = Game.stock_shelf(sh.furniture_uid, pid, n)
		if moved == 0:
			toast("Depoda yok ya da raf dolu.", "bad")
	else:
		Game.unstock_shelf(sh.furniture_uid, pid, -n)
	_fill_shelf(body, sh)


func _fill_shelf(body: VBoxContainer, sh: Shelf) -> void:
	_clear(body)
	var e: Dictionary = sh.entry()
	var cap: int = Game.shelf_capacity(e)
	body.add_child(_lbl("Rafta %d / %d ürün. Ürünler depodan gelir, müşteriler sadece raftakini alır." % [Game.shelf_total(e), cap], 19, Color(0.8, 0.85, 0.87)))
	for pid in ProductDB.ids():
		if not FurnitureDB.shelf_accepts(sh.kind, pid) and int(e.shelf.get(pid, 0)) == 0:
			continue
		var p: Dictionary = ProductDB.get_product(pid)
		var row := _row(body)
		var n := _lbl(p.name, 20)
		n.custom_minimum_size.x = 230
		row.add_child(n)
		var c := _lbl("Rafta %d • Depoda %d" % [int(e.shelf.get(pid, 0)), int(Game.stock.get(pid, 0))], 19)
		c.custom_minimum_size.x = 220
		row.add_child(c)
		_btn(row, "+1", _shelf_move.bind(body, sh, pid, 1), Game.stock.get(pid, 0) > 0)
		_btn(row, "+5", _shelf_move.bind(body, sh, pid, 5), Game.stock.get(pid, 0) > 0)
		_btn(row, "−1", _shelf_move.bind(body, sh, pid, -1), int(e.shelf.get(pid, 0)) > 0)
	var cfg: Dictionary = FurnitureDB.item(sh.kind).get("shelf", {})
	if cfg.get("tanks", false):
		_section(body, "Raf katlarına akvaryum")
		body.add_child(_lbl("Bir kata küçük ışıklı akvaryum (%d ₺) koyabilirsin; o kat ürün almaz." % Game.SHELF_TANK_PRICE, 17, Color(0.8, 0.85, 0.87)))
		var st: Dictionary = e.get("shelf_tanks", {})
		var levels: Array = cfg.get("levels", [])
		for li in range(levels.size() - 1, -1, -1):
			var trow := _row(body)
			var nm := _lbl("Kat %d" % (li + 1), 20)
			nm.custom_minimum_size.x = 90
			trow.add_child(nm)
			if st.has(str(li)):
				var aq: Aquarium = sh.tank_on_level(li)
				var t: Dictionary = Game.tanks[int(st[str(li)])]
				trow.add_child(_lbl("Tank %d • %d hayvan" % [int(t.id) + 1, TankSim.living(t).size()], 19))
				if aq:
					_btn(trow, "Akvaryumu aç", func(): close_panel(); open_tank(aq))
			else:
				_btn(trow, "Bu kata akvaryum koy (%d ₺)" % Game.SHELF_TANK_PRICE, _place_shelf_tank.bind(body, sh, li), Game.money >= Game.SHELF_TANK_PRICE)
	var mv := _row(body)
	_btn(mv, "Taşı", _move_furniture.bind(sh.furniture_uid))
	_btn(mv, "Sat (%d ₺, ürünler depoya döner)" % (int(FurnitureDB.item(sh.kind).price) / 2), _sell_furniture.bind(sh.furniture_uid))


# ------------------------------------------------------------------ Telefon: mobilya, balık, ürün

func open_supplier() -> void:
	open_phone("fish")


func open_phone(tab: String = "furniture") -> void:
	var body := _open("TELEFON", 900)
	_fill_phone(body, tab, -1)


func _fill_phone(body: VBoxContainer, tab: String, target_tank: int) -> void:
	_clear(body)
	var tabs := _flow(body)
	_btn(tabs, "Mobilya", _fill_phone.bind(body, "furniture", target_tank), tab != "furniture")
	_btn(tabs, "Balık", _fill_phone.bind(body, "fish", target_tank), tab != "fish")
	_btn(tabs, "Ürün / Depo", _fill_phone.bind(body, "products", target_tank), tab != "products")
	_btn(tabs, "Dükkân", _fill_phone.bind(body, "shop", target_tank), tab != "shop")
	_btn(tabs, "Personel", _fill_phone.bind(body, "staff", target_tank), tab != "staff")
	_btn(tabs, "Müşteriler", _fill_phone.bind(body, "customers", target_tank), tab != "customers")
	_btn(tabs, "Finans", _fill_phone.bind(body, "finance", target_tank), tab != "finance")
	match tab:
		"finance":
			_fill_finance(body)
		"customers":
			_fill_customers(body)
		"furniture":
			_fill_catalog(body)
		"shop":
			_fill_shop_settings(body)
		"staff":
			_fill_staff(body)
		"products":
			_fill_products(body, target_tank)
		_:
			_fill_fish(body, target_tank)


func _buy_furniture(type: String) -> void:
	var info: Dictionary = FurnitureDB.item(type)
	if info.has("max") and Game.count_furniture(type) >= int(info.max):
		toast("Bundan zaten var.", "bad")
		return
	if Game.money < int(info.price):
		toast("Yeterli paran yok.", "bad")
		return
	close_panel()
	builder.start_new(type)
	toast("Yerleştir: bak, R/⟲⟳ ile döndür, E/tık ya da YERLEŞTİR.", "info")


func _fill_catalog(body: VBoxContainer) -> void:
	body.add_child(_lbl("Ödeme yerleştirince alınır. Eşyaları sonra taşıyabilir ya da yarı fiyatına satabilirsin.", 18, Color(0.8, 0.85, 0.87)))
	for cat in FurnitureDB.CATEGORIES:
		_section(body, cat[1])
		for id in FurnitureDB.in_category(cat[0]):
			var info: Dictionary = FurnitureDB.item(id)
			var row := _row(body)
			var n := _lbl(info.name, 21)
			n.custom_minimum_size.x = 290
			row.add_child(n)
			var d := _lbl(info.desc, 17, Color(0.78, 0.82, 0.84))
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 340
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(d)
			var maxed: bool = info.has("max") and Game.count_furniture(id) >= int(info.max)
			_btn(row, "Var" if maxed else "%s ₺" % Aquarium._fmt(int(info.price)), _buy_furniture.bind(id), not maxed and Game.money >= int(info.price))


## Fiyat eğilimi işareti
func _trend(id: String) -> String:
	var m: float = float(Game.price_mult.get(id, 1.0))
	if m <= 0.9:
		return "(ucuz ▼)"
	if m >= 1.15:
		return "(pahalı ▲)"
	return ""


func _set_setting(body: VBoxContainer, key: String, value) -> void:
	Game.settings[key] = value
	Game.settings_changed.emit()
	_fill_phone(body, "shop", -1)


func _expand_shop(body: VBoxContainer) -> void:
	if Game.phase != "prep":
		toast("Dükkân sadece sabah (kapalıyken) genişletilebilir.", "bad")
		return
	var cost: int = Game.EXPAND_COST[Game.shop_level]
	if Game.spend(cost):
		Game.shop_level += 1
		Game.save_game()
		toast("Dükkân genişledi! Usta duvarı yıktı.", "good")
		close_panel()
		get_tree().reload_current_scene.call_deferred()


func _fill_shop_settings(body: VBoxContainer) -> void:
	_section(body, "Tabela")
	var row := _row(body)
	var le := LineEdit.new()
	le.text = str(Game.settings.name)
	le.max_length = 24
	le.custom_minimum_size = Vector2(420, 44)
	row.add_child(le)
	_btn(row, "Tabelayı yaz", func(): _set_setting(body, "name", le.text.strip_edges().to_upper() if le.text.strip_edges() != "" else "PETSHOP"))
	_section(body, "Ayarlar")
	_btn(body, "Kepçe mini oyunu: %s" % ("AÇIK" if Game.settings.get("catch_game", true) else "KAPALI"), _set_setting.bind(body, "catch_game", not Game.settings.get("catch_game", true)))


func _toggle_staff(body: VBoxContainer, role: String) -> void:
	Game.employees[role] = not Game.employees.get(role, false)
	if main:
		main.sync_employees()
	toast(("%s işe alındı." if Game.employees[role] else "%s işten çıkarıldı.") % ("Kasiyer" if role == "kasiyer" else "Bakımcı"), "info")
	_fill_phone(body, "staff", -1)


func _fill_staff(body: VBoxContainer) -> void:
	var roles := [
		["kasiyer", "Kasiyer", "Kasada bekleyen müşteriye sen 6 saniye içinde bakmazsan, değerinin %5 üstüne satışı kendisi yapar. Kasa tezgâhı gerekir."],
		["bakimci", "Bakımcı", "Tankları dolaşır: aç balıklara depodan yem verir, ölü balıkları çıkarır, kirli suyu değiştirir (depodan su düzenleyici kullanır)."],
	]
	for r in roles:
		_section(body, "%s — günlük maaş %d ₺" % [r[1], Game.SALARY[r[0]]])
		var d := _lbl(r[2], 18, Color(0.8, 0.85, 0.87))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 840
		body.add_child(d)
		var hired: bool = Game.employees.get(r[0], false)
		_btn(body, "İşten çıkar" if hired else "İşe al", _toggle_staff.bind(body, r[0]))


func _buy_products(body: VBoxContainer, pid: String, n: int, target_tank: int) -> void:
	var p: Dictionary = ProductDB.get_product(pid)
	if Game.spend(Game.buy_price(pid) * n):
		Game.add_delivery(pid, n)
		Game.notify.emit("%d %s koli halinde kapıya geldi." % [n, p.name], "good")
		Sfx.play("chime")
	_fill_phone(body, "products", target_tank)


func _fill_products(body: VBoxContainer, target_tank: int) -> void:
	var info0 := _lbl("Siparişler kapının yanına KOLİ olarak gelir. Koliyi alıp bir rafa bakarak diz, ya da DEPOYA KOY (bakım ürünleri depodan kullanılır). Fiyatlar her gün değişir.", 18, Color(0.8, 0.85, 0.87))
	info0.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info0.custom_minimum_size.x = 840
	body.add_child(info0)
	for pid in ProductDB.ids():
		var p: Dictionary = ProductDB.get_product(pid)
		var row := _row(body)
		var n := _lbl(p.name, 21)
		n.custom_minimum_size.x = 250
		row.add_child(n)
		var bp: int = Game.buy_price(pid)
		var info := _lbl("Alış %d ₺ %s • Satış %d ₺ • Depo %d" % [bp, _trend(pid), p.price, Game.stock.get(pid, 0)], 19)
		info.custom_minimum_size.x = 400
		row.add_child(info)
		_btn(row, "×5 (%d ₺)" % (bp * 5), _buy_products.bind(body, pid, 5, target_tank), Game.money >= bp * 5)
		_btn(row, "×20 (%d ₺)" % (bp * 20), _buy_products.bind(body, pid, 20, target_tank), Game.money >= bp * 20)


func _buy_fish(body: VBoxContainer, sp: String, qty: int, target_tank: int) -> void:
	var s: Dictionary = FishDB.get_species(sp)
	if Game.spend(Game.buy_price(sp) * qty):
		var rare_n: int = Game.order_animals(sp, qty)
		Sfx.play("chime")
		var what: String = "taşıma kutusunda" if FishDB.is_land(sp) else "poşette"
		Game.notify.emit("%d %s %s kapıya geldi. Al ve uygun %s bakıp bırak." % [qty, s.name, what, FishDB.habitat_name(FishDB.habitat(sp))], "good")
		if rare_n > 0:
			Game.notify.emit("Şanslı günün! Gelenlerden %d tanesi NADİR %s!" % [rare_n, s.name], "good")
			Sfx.play("good")
	_fill_phone(body, "fish", target_tank)


## Tanka konabilecek uygun yerlerin kısa listesi ("T2, T5" ya da "")
func _homes_for(sp: String) -> String:
	var out: Array = []
	for t in Game.tanks:
		if t.unlocked and TankSim.habitat_of(t) == FishDB.habitat(sp) and bool(t.get("salt", false)) == FishDB.is_salt(sp):
			out.append("T%d" % (int(t.id) + 1))
	return ", ".join(out)


func _fill_fish(body: VBoxContainer, target_tank: int) -> void:
	var info0 := _lbl("Siparişler kapının yanına KARGO olarak gelir: balıklar su dolu poşette, kara hayvanları taşıma kutusunda. Alıp istediğin tanka/kafese bakarak bırakırsın.", 18, Color(0.8, 0.85, 0.87))
	info0.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info0.custom_minimum_size.x = 840
	body.add_child(info0)
	var groups := [
		["Tatlı su balıkları", FishDB.salt_ids(false)],
		["Tuzlu su balıkları", FishDB.salt_ids(true)],
		["Kaplumbağa (teraryum)", FishDB.ids_in_habitat("turtle")],
		["Örümcek (kuru teraryum)", FishDB.ids_in_habitat("kuru")],
		["Hamster (hamster kafesi)", FishDB.ids_in_habitat("hamster")],
		["Civciv (civciv kafesi)", FishDB.ids_in_habitat("civciv")],
	]
	for g in groups:
		_section(body, g[0])
		for sp in g[1]:
			var s: Dictionary = FishDB.get_species(sp)
			var row := _row(body)
			var n := _lbl(s.name, 21)
			n.custom_minimum_size.x = 210
			row.add_child(n)
			var homes: String = _homes_for(sp)
			var info := _lbl("Alış %d ₺ %s • Değer ~%d ₺ • %d-%d°C • %d yer" % [Game.buy_price(sp), _trend(sp), s.value, int(s.temp_min), int(s.temp_max), TankSim.space_of(sp)], 18)
			info.custom_minimum_size.x = 420
			row.add_child(info)
			for qty in [1, 5]:
				var cost: int = Game.buy_price(sp) * qty
				_btn(row, "×%d (%d ₺)" % [qty, cost], _buy_fish.bind(body, sp, qty, target_tank), Game.money >= cost)
			if homes == "":
				body.add_child(_lbl("   ⚠ Koyacak yer yok: önce bir %s kur." % FishDB.habitat_name(FishDB.habitat(sp)), 17, C_WARN))


# ------------------------------------------------------------------ Kasa / Pazarlık

func open_register() -> void:
	var c: Customer = main.customer_at_register()
	if c == null:
		toast("Kasada bekleyen müşteri yok.", "info")
		return
	if c.kind == "complainer":
		_open_complaint(c)
		return
	var h: Haggle = c.haggle if c.haggle else c.start_haggle()
	if h == null:
		c.say("Aldıklarım kalmamış...")
		c.walk_out_angry()
		toast("Müşterinin seçtiği ürünler artık yok.", "bad")
		return
	_haggle_customer = c
	_ask_value = int(round(h.value * 1.2))
	var body := _open("Kasa: %s" % c.profile.title, 820)
	_fill_register(body, c, "")


func _fill_register(body: VBoxContainer, c: Customer, result_line: String) -> void:
	_clear(body)
	var h: Haggle = c.haggle
	if h == null:
		return
	for item in c.basket:
		var row := _row(body)
		var nm: String
		if item.type == "fish":
			nm = "Balık: %s (Tank %d)" % [FishDB.display_name(item.species), item.tank + 1]
		else:
			nm = "Ürün: %s" % ProductDB.get_product(item.id).name
		var l := _lbl(nm, 20)
		l.custom_minimum_size.x = 420
		row.add_child(l)
		row.add_child(_lbl("%d ₺" % c.item_value(item), 20))
	body.add_child(HSeparator.new())
	body.add_child(_lbl("Toplam piyasa değeri: %d ₺" % h.value, 22))
	var say_l := _lbl("“%s”" % (result_line if result_line != "" else h.last_line), 24, Color(0.95, 0.9, 0.7))
	say_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say_l.custom_minimum_size.x = 760
	body.add_child(say_l)
	_bar(body, "Sabır: " + h.mood_text(), h.patience * 100.0)
	var price_row := _row(body)
	price_row.add_child(_lbl("Senin fiyatın:", 22))
	var ask_l := _lbl("%d ₺" % _ask_value, 28, C_GOOD)
	ask_l.custom_minimum_size.x = 120
	var slider := HSlider.new()
	slider.min_value = max(1, int(h.value * 0.5))
	slider.max_value = int(h.value * 2.2)
	slider.step = 1
	slider.value = _ask_value
	slider.custom_minimum_size = Vector2(380, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v): _ask_value = int(v); ask_l.text = "%d ₺" % _ask_value)
	price_row.add_child(slider)
	price_row.add_child(ask_l)
	var fine := _row(body)
	for d in [-50, -10, -1, 1, 10, 50]:
		_btn(fine, ("%+d" % d), func(): slider.value = clamp(_ask_value + d, slider.min_value, slider.max_value))
	var acts := _row(body)
	_btn(acts, "Fiyatı söyle", _say_price.bind(body, c, h))
	_btn(acts, "Teklifini kabul et (%d ₺)" % h.offer, func(): _complete(c, h.accept_offer(), "Anlaştık!"))
	_btn(acts, "Satmaktan vazgeç", func():
		c.say("Peki, başka yere bakarım.")
		c.walk_out_angry()
		close_panel())


func _say_price(body: VBoxContainer, c: Customer, h: Haggle) -> void:
	var r: Dictionary = h.respond(_ask_value)
	match r.result:
		Haggle.Result.ACCEPT:
			_complete(c, r.price, r.line)
		Haggle.Result.LEAVE:
			c.say(r.line)
			c.walk_out_angry()
			close_panel()
			toast("Müşteri sinirlenip gitti: “%s”" % r.line, "bad")
		_:
			c.say(r.line)
			_fill_register(body, c, r.line)


func _complete(c: Customer, price: int, line: String) -> void:
	# Balık satışında önce kepçeyle yakalaman gerekir.
	var want := {}
	var tank_id := -1
	for item in c.basket:
		if item.type == "fish":
			if tank_id < 0:
				tank_id = int(item.tank)
			if int(item.tank) == tank_id:
				want[item.species] = int(want.get(item.species, 0)) + 1
	if Game.settings.get("catch_game", true) and tank_id >= 0:
		_open_catch(c, price, line, tank_id, want)
		return
	_finish_sale(c, price, line)


func _finish_sale(c: Customer, price: int, line: String) -> void:
	main.complete_sale(c, price)
	close_panel()
	toast("Satış: +%d ₺  “%s”" % [price, line], "good")


func _open_catch(c: Customer, price: int, line: String, tank_id: int, want: Dictionary) -> void:
	var body := _open("Kepçeyle yakala — Tank %d" % (tank_id + 1), 860)
	var cg := CatchGame.new()
	cg.setup(Game.tanks[tank_id], want)
	var info := _lbl("Yakala: " + cg.wanted_text() + "   (yanlış balık süreni yer!)", 21, C_WARN)
	body.add_child(info)
	body.add_child(cg)
	if player:
		player.hands.hold_net()
	cg.finished.connect(func(ok: bool):
		if player:
			player.hands.clear()
		if ok:
			_finish_sale(c, price, line)
		else:
			var reduced: int = int(price * 0.9)
			Game.change_reputation(-1.0)
			_finish_sale(c, reduced, "Ne kadar bekledim ama...")
			toast("Balıkları zor yakaladın, müşteri bekledi: %d ₺ yerine %d ₺" % [price, reduced], "warn"))


func _open_complaint(c: Customer) -> void:
	var body := _open("Şikâyet: %s" % c.profile.title, 720)
	var amt: int = int(c.complaint.get("amount", 0))
	var l := _lbl("“Dün sizden aldığım %s eve varmadan öldü! Paramı geri istiyorum: %d ₺”" % [FishDB.display_name(c.complaint.get("species", "")), amt], 22, Color(0.95, 0.9, 0.7))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 660
	body.add_child(l)
	body.add_child(_lbl("İade edersen para gider ama itibarın korunur. Reddedersen itibarın ciddi düşer.", 18, Color(0.8, 0.85, 0.87)))
	var row := _row(body)
	_btn(row, "Parasını iade et (-%d ₺)" % amt, func(): main.resolve_complaint(c, true); close_panel())
	_btn(row, "Reddet", func(): main.resolve_complaint(c, false); close_panel())


func open_question(c: Customer) -> void:
	var q: Dictionary = c.question
	var body := _open("%s soruyor" % c.profile.title, 720)
	var l := _lbl("“%s”" % q.text, 23, Color(0.95, 0.9, 0.7))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 660
	body.add_child(l)
	for i in q.options.size():
		_btn(body, q.options[i], _answer.bind(c, i, q))


func _answer(c: Customer, idx: int, q: Dictionary) -> void:
	var ok: bool = c.answer_question(idx)
	close_panel()
	toast(("Doğru! " if ok else "Yanlış. ") + str(q.get("explain", "")), "good" if ok else "bad")
	Sfx.play("good" if ok else "bad")


func _set_campaign(body: VBoxContainer, target: String, pct: int) -> void:
	Game.campaign = {"target": target, "pct": pct}
	toast("Kampanya başladı: %s %%%d indirimli! Bugün daha çok müşteri gelir." % ["Balıklar" if target == "fish" else "Ürünler", pct], "good")
	_fill_phone(body, "finance", -1)


func _take_loan(body: VBoxContainer, i: int) -> void:
	var l: Array = Game.LOANS[i]
	Game.loan = {"days_left": l[1], "daily": l[2]}
	Game.add_money(l[0])
	toast("%s ₺ kredi hesabına geçti. %d gün boyunca günde %d ₺ ödenecek." % [Aquarium._fmt(l[0]), l[1], l[2]], "good")
	_fill_phone(body, "finance", -1)


func _payoff_loan(body: VBoxContainer) -> void:
	var total: int = int(Game.loan.days_left) * int(Game.loan.daily)
	var payoff: int = int(total * 0.9)
	if Game.spend(payoff):
		Game.loan = {}
		toast("Kredi erken kapatıldı (%%10 indirimle %d ₺)." % payoff, "good")
	_fill_phone(body, "finance", -1)


func _open_branch(body: VBoxContainer) -> void:
	if Game.spend(Game.BRANCH_COST):
		Game.branches += 1
		toast("Yeni şube açıldı! Her akşam şubeden gelir gelecek.", "good")
		Sfx.play("good")
	_fill_phone(body, "finance", -1)


func _fill_finance(body: VBoxContainer) -> void:
	_section(body, "Kampanya (bugün için)")
	if Game.campaign.is_empty():
		body.add_child(_lbl("İndirim yaparsan bugün daha çok müşteri gelir ama kâr marjın düşer.", 18, Color(0.8, 0.85, 0.87)))
		var f := _flow(body)
		for target in ["fish", "products"]:
			for pct in [10, 20, 30]:
				_btn(f, "%s %%%d" % ["Balıklar" if target == "fish" else "Ürünler", pct], _set_campaign.bind(body, target, pct))
	else:
		body.add_child(_lbl("Aktif: %s %%%d indirim" % ["Balıklar" if Game.campaign.target == "fish" else "Ürünler", Game.campaign.pct], 20, C_GOOD))
	_section(body, "Sosyal medya")
	body.add_child(_lbl("Takipçi: %s. Tanklara bakıp fotoğraf paylaş; güzel tanklar çok takipçi getirir, takipçiler müşteri getirir." % Aquarium._fmt(Game.followers), 19))
	_section(body, "Banka")
	if Game.loan.is_empty():
		for i in Game.LOANS.size():
			var l: Array = Game.LOANS[i]
			_btn(body, "%s ₺ kredi çek (%d gün × %d ₺ = %s ₺ geri öde)" % [Aquarium._fmt(l[0]), l[1], l[2], Aquarium._fmt(l[1] * l[2])], _take_loan.bind(body, i))
	else:
		body.add_child(_lbl("Kredi: %d gün kaldı, günlük %d ₺ taksit." % [Game.loan.days_left, Game.loan.daily], 20, C_WARN))
		var payoff: int = int(int(Game.loan.days_left) * int(Game.loan.daily) * 0.9)
		_btn(body, "Erken kapat (%s ₺)" % Aquarium._fmt(payoff), _payoff_loan.bind(body), Game.money >= payoff)
	_section(body, "Şubeler (%d/2)" % Game.branches)
	body.add_child(_lbl("Şube her akşam itibarına göre gelir getirir (müdür maaşı düşülür). İtibar en az 60 olmalı.", 18, Color(0.8, 0.85, 0.87)))
	if Game.branches < 2:
		_btn(body, "Yeni şube aç (%s ₺)" % Aquarium._fmt(Game.BRANCH_COST), _open_branch.bind(body), Game.money >= Game.BRANCH_COST and Game.reputation >= 60.0)
	if Game.events_today.get("contest", false):
		_section(body, "Yarışma")
		body.add_child(_lbl("Bugün akvaryum yarışması var! Kapanışta en güzel tankın puanlanacak: çekicilik, tür çeşitliliği, sağlık ve nadir balıklar.", 19, C_WARN))


func _photo(body: VBoxContainer, aq: Aquarium) -> void:
	var t: Dictionary = Game.tanks[aq.tank_id]
	if Game.photos_today.has(aq.tank_id):
		toast("Bu tankın bugünkü fotoğrafını zaten paylaştın.", "bad")
		return
	Game.photos_today.append(aq.tank_id)
	var appeal: float = TankSim.appeal(t)
	var gain: int = int(appeal * Game.rng.randf_range(0.6, 1.4) * (1.0 + TankSim.species_in(t).size() * 0.15))
	for f in TankSim.living(t):
		if f.get("rare", false):
			gain += 40
	if TankSim.living(t).is_empty():
		gain = int(gain * 0.2)
	Game.followers += gain
	Game.change_reputation(appeal / 80.0)
	Sfx.play("shutter")
	if player:
		player.hands.hold_phone()
	toast("Fotoğraf paylaşıldı: +%d takipçi (toplam %s)" % [gain, Aquarium._fmt(Game.followers)], "good" if gain > 30 else "info")
	_fill_tank(body, aq)


func _fill_customers(body: VBoxContainer) -> void:
	_section(body, "Müdavimler")
	for r in Game.regulars:
		var row := _row(body)
		var n := _lbl(r.name, 21)
		n.custom_minimum_size.x = 200
		row.add_child(n)
		var lv: float = float(r.loyalty)
		var tag: String = "Sadık" if lv > 70 else ("Memnun" if lv > 40 else ("Kararsız" if lv > 15 else "Küskün"))
		row.add_child(_lbl("Sadakat %d (%s) • %d ziyaret" % [int(lv), tag, int(r.get("visits", 0))], 19, C_GOOD if lv > 40 else (C_WARN if lv > 15 else C_BAD)))
	body.add_child(_lbl("Sadık müdavimler daha çok alır ama indirim bekler. Bekletirsen ya da şikâyetini reddedersen küser.", 17, Color(0.78, 0.82, 0.84)))
	_section(body, "Özel siparişler")
	if Game.special_orders.is_empty():
		body.add_child(_lbl("Bekleyen sipariş yok. Aradığını bulamayan müşteriler bazen sipariş verir.", 19))
	for o in Game.special_orders:
		var have := 0
		for t in Game.tanks:
			if t.unlocked and not t.get("quarantine", false):
				have += TankSim.living(t).filter(func(f): return f.species == o.species).size()
		body.add_child(_lbl("%s: %d %s — Gün %d'e kadar (dükkânda %d var) • %%50 fazla öder" % [o.name, o.qty, FishDB.display_name(o.species), o.due, have], 19, C_GOOD if have >= int(o.qty) else C_WARN))


# ------------------------------------------------------------------ Gün sonu / menü

func show_report(r: Dictionary) -> void:
	var body := _open("Gün %d Raporu" % r.day, 640)
	var lines := [
		["Satış adedi", str(r.sales)],
		["Ciro", "+%s ₺" % Aquarium._fmt(r.revenue)],
		["Alımlar (tedarik)", "-%s ₺" % Aquarium._fmt(r.purchases)],
		["Kira", "-%s ₺" % Aquarium._fmt(r.rent)],
		["Elektrik (ısıtıcı/filtre/lamba)", "-%s ₺" % Aquarium._fmt(r.electric)],
		["Maaşlar", "-%s ₺" % Aquarium._fmt(r.get("salary", 0))],
		["Kredi taksiti", "-%s ₺" % Aquarium._fmt(r.get("loan", 0))],
		["Cezalar / iadeler", "-%s ₺" % Aquarium._fmt(int(r.get("fines", 0)) + int(r.get("refunds", 0)))],
		["Bahşişler", "+%s ₺" % Aquarium._fmt(r.get("tips", 0))],
		["Şubelerden", "%+d ₺" % int(r.get("branch", 0))],
		["Çalınan ürün", str(r.get("stolen", 0))],
		["Takipçi", str(r.get("followers", 0))],
		["Ölen balık", str(r.deaths)],
		["Kaçan müşteri", str(r.lost_customers)],
		["İtibar", "%d / 100" % int(r.reputation)],
		["Kasa", "%s ₺" % Aquarium._fmt(r.money)],
	]
	for l in lines:
		var row := _row(body)
		var a := _lbl(l[0], 22)
		a.custom_minimum_size.x = 360
		row.add_child(a)
		row.add_child(_lbl(l[1], 22))
	var ct: Dictionary = r.get("contest", {})
	if not ct.is_empty():
		var txt: String = "Akvaryum yarışması: %d. oldun (puan %d)" % [ct.place, ct.score]
		if int(ct.prize) > 0:
			txt += " — ödül %s ₺!" % Aquarium._fmt(ct.prize)
		body.add_child(_lbl(txt, 22, C_GOOD if int(ct.prize) > 0 else C_WARN))
	if r.over:
		var o := _lbl("Üç gün üst üste borçta kaldın. Dükkân kapandı!", 24, C_BAD)
		body.add_child(o)
		_btn(body, "Yeni oyun", func():
			Game.delete_save()
			get_tree().reload_current_scene.call_deferred()
			Game.new_game())
	else:
		if r.debt_days > 0:
			body.add_child(_lbl("⚠ Borçtasın! %d gün daha borçta kalırsan dükkân kapanır." % (3 - r.debt_days), 21, C_BAD))
		_btn(body, "Ertesi gün", func():
			close_panel()
			Game.next_day())


func open_menu() -> void:
	var body := _open("Menü", 560)
	_btn(body, "Devam et", close_panel)
	_btn(body, "Nasıl oynanır?", show_help)
	_btn(body, "Kaydet", func(): Game.save_game(); toast("Kaydedildi.", "good"))
	_btn(body, "Yeni oyun (kayıt silinir)", func():
		Game.delete_save()
		Game.new_game()
		get_tree().reload_current_scene.call_deferred())


func show_help() -> void:
	var body := _open("Nasıl Oynanır?", 820)
	var text := """Dükkânını sıfırdan kur ve ayakta tut!

KURULUM
• TELEFON > Mobilya: akvaryum, kasa tezgâhı, raf ve dekor al. Eşya baktığın yere gelir; döndürüp yerleştir.
• Akvaryuma bakıp ETKİLEŞ: kum, filtre, ısıtıcı, lamba, hava motoru ve dekor ekle. Lambasız, kumsuz tank müşteriyi kaçırır.
• Yeni kurulan su olgunlaşmalıdır. Hemen balık koyarsan zorlanırlar; filtre olgunlaşmayı hızlandırır.
• TELEFON > Balık: tanka balık sipariş et. Büyük balıklar daha çok yer kaplar.
• TELEFON > Ürün: ürünler depoya gelir. Rafa bakıp depodan rafa diz; müşteri sadece raftakini alır.
• Eşyaları istediğin zaman taşıyabilir, yarı fiyatına satabilirsin.

• Ürün siparişleri kapıya KOLİ olarak gelir: koliyi al, rafa bakıp diz ya da depoya koy (G).
• Yeni balıkları önce karantina tankına koy; bazıları hastalık taşır.

GÜN
• Hazır olunca ön kapıdan dükkânı aç (09:00-19:00). Kasa tezgâhı olmadan satış yapılamaz!
• Müşteri kasaya gelince pazarlık yap. Fazla bekletir ya da kazık atarsan çekip gider.
• Tür uyumu: japon/koi/alabalık soğuk su ister; beta, pirana, aslan balığı diğerlerine saldırır.
• Tuzlu su tankında Nemo, Dory, mandarin, deniz atı, fener balığı satılır.
• Her akşam artan kira ve elektrik ödenir. 3 gün üst üste borçta kalırsan dükkân kapanır.

Kontroller: WASD + fare, E etkileşim, ESC menü. Yerleştirirken R / fare tekeri döndürür.
Telefonda: sol taraf yürü, sağ taraf bak.

Emeği geçenler: Karakterler Adobe Mixamo. Balıklar polyy.ai, mobilyalar Innerscene ve tevy.dev, şehir Quaternius, dokular ambientCG ve Poly Haven (CC0)."""
	var l := _lbl(text, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 780
	body.add_child(l)
	_btn(body, "Başla", close_panel)
