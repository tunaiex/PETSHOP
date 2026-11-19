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
	_build_topbar()
	_build_center()
	_build_touch()
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
			_phase.text = "Hazırlık: kapıdan dükkânı aç"
		"open":
			_phase.text = "Açık"
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
	for b in [_interact_btn, _menu_btn, _speed_btn]:
		if b.visible and b.get_global_rect().has_point(p):
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
		_toasts.get_child(0).free()
	var tw := create_tween()
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
	if not _touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open(title: String, width: float = 760) -> VBoxContainer:
	if is_blocking():
		_panel.free()
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


func _clear(body: VBoxContainer) -> void:
	for c in body.get_children():
		c.free()


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
	if _panel_refresh.is_valid():
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = 1.0
			_panel_refresh.call()


# ------------------------------------------------------------------ Akvaryum paneli

func open_tank(aq: Aquarium) -> void:
	var body := _open("Tank %d" % (aq.tank_id + 1))
	var fill := func(): _fill_tank(body, aq)
	fill.call()
	_panel_refresh = fill


func _fill_tank(body: VBoxContainer, aq: Aquarium) -> void:
	_clear(body)
	var t: Dictionary = Game.tanks[aq.tank_id]
	if not t.unlocked:
		body.add_child(_lbl("Bu tank boş ve kiralık. Kiralarsan içine balık koyabilirsin.\nGünlük elektrik gideri de artar.", 21))
		_btn(body, "Kirala: %s ₺" % Aquarium._fmt(TankSim.UNLOCK_COST), func():
			if Game.spend(TankSim.UNLOCK_COST):
				t.unlocked = true
				t.dirt = 5.0
				t.temp = t.heater
				Game.tank_changed.emit(aq.tank_id)
				Game.notify.emit("Tank %d hazır!" % (aq.tank_id + 1), "good")
				_fill_tank(body, aq), Game.money >= TankSim.UNLOCK_COST)
		return
	var info := _row(body)
	info.add_child(_lbl("Su: %.1f°C  (ısıtıcı %.0f°C)" % [t.temp, t.heater], 21))
	_btn(info, " − ", func(): t.heater = max(TankSim.ROOM_TEMP, t.heater - 1.0); _fill_tank(body, aq))
	_btn(info, " + ", func(): t.heater = min(32.0, t.heater + 1.0); _fill_tank(body, aq))
	_bar(body, "Su temizliği", 100.0 - t.dirt)
	_bar(body, "Tokluk", t.food)
	if t.sick:
		body.add_child(_lbl("⚠ Beyaz benek hastalığı! (%d%%) İlaç ver ve suyu değiştir." % int(t.sick_level * 100), 21))
		body.get_child(-1).add_theme_color_override("font_color", C_BAD)
	var dead := TankSim.dead_count(t)
	if dead > 0:
		var dl := _lbl("⚠ Tankta %d ölü balık var, suyu hızla kirletiyor!" % dead, 21)
		dl.add_theme_color_override("font_color", C_BAD)
		body.add_child(dl)
	# Uyumsuzluk uyarıları
	var sps: Array = TankSim.species_in(t)
	for i in sps.size():
		for j in range(i, sps.size()):
			var r: String = FishDB.conflict_reason(sps[i], sps[j]) if i != j else (FishDB.conflict_reason(sps[i], sps[j]) if sps[i] == "beta" and TankSim._count_species(TankSim.living(t), "beta") > 1 else "")
			if r != "":
				var wl := _lbl("⚠ " + r, 20)
				wl.add_theme_color_override("font_color", C_WARN)
				body.add_child(wl)
	# Sıcaklık uyarıları
	for sp in sps:
		var s: Dictionary = FishDB.get_species(sp)
		if t.temp < s.temp_min - 0.5 or t.temp > s.temp_max + 0.5:
			var tl := _lbl("⚠ %s için su %s (ideal %d-%d°C)" % [s.name, "soğuk" if t.temp < s.temp_min else "sıcak", int(s.temp_min), int(s.temp_max)], 20)
			tl.add_theme_color_override("font_color", C_WARN)
			body.add_child(tl)

	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 8)
	acts.add_theme_constant_override("v_separation", 8)
	body.add_child(acts)
	_btn(acts, "Yem ver (%d)" % Game.stock.get("yem", 0), func():
		if Game.use_stock("yem"):
			var extra := TankSim.feed(t)
			aq.play_feed()
			if extra > 0.0:
				Game.notify.emit("Fazla yem verdin, su kirlendi!", "warn")
			Game.tank_changed.emit(aq.tank_id)
		_fill_tank(body, aq))
	_btn(acts, "Su değiştir (%d)" % Game.stock.get("su_duzenleyici", 0), func():
		if Game.use_stock("su_duzenleyici"):
			TankSim.water_change(t)
			Game.tank_changed.emit(aq.tank_id)
			Game.notify.emit("Suyun yarısı değiştirildi.", "good")
		_fill_tank(body, aq))
	_btn(acts, "İlaç ver (%d)" % Game.stock.get("ilac", 0), func():
		if Game.use_stock("ilac"):
			TankSim.medicate(t)
			Game.tank_changed.emit(aq.tank_id)
			Game.notify.emit("İlaç verildi.", "good")
		_fill_tank(body, aq), t.sick)
	_btn(acts, "Ölüleri çıkar", func():
		var n := TankSim.remove_dead(t)
		Game.tank_changed.emit(aq.tank_id)
		Game.notify.emit("%d ölü balık çıkarıldı." % n, "info")
		_fill_tank(body, aq), dead > 0)
	var salt: bool = bool(t.get("salt", false))
	var conv_txt := "Tatlı suya çevir" if salt else "Tuzlu suya çevir"
	_btn(acts, "%s (%d ₺)" % [conv_txt, TankSim.SALT_COST], func():
		if not TankSim.living(t).is_empty():
			Game.notify.emit("Önce tanktaki balıkları sat.", "bad")
			return
		if Game.spend(TankSim.SALT_COST):
			TankSim.set_salt(t, not salt)
			Game.tank_changed.emit(aq.tank_id)
			Game.notify.emit("Tank %d artık %s." % [aq.tank_id + 1, "tatlı su" if salt else "tuzlu su (deniz) tankı"], "good")
		_fill_tank(body, aq), TankSim.living(t).is_empty() and Game.money >= TankSim.SALT_COST)
	var fl: int = int(t.filter)
	if fl < 3:
		var cost: int = TankSim.FILTER_COST[fl + 1]
		_btn(acts, "Filtre Sv.%d → %d (%s ₺)" % [fl, fl + 1, Aquarium._fmt(cost)], func():
			if Game.spend(cost):
				t.filter = fl + 1
				Game.notify.emit("Filtre yükseltildi.", "good")
			_fill_tank(body, aq), Game.money >= cost)
	else:
		acts.add_child(_lbl("Filtre: en üst seviye", 20))

	body.add_child(HSeparator.new())
	var alive: Array = TankSim.living(t)
	body.add_child(_lbl("Balıklar (%d/%d)" % [t.fish.size(), TankSim.CAPACITY], 24))
	if alive.is_empty():
		body.add_child(_lbl("Tank boş. Kasadaki tabletten balık sipariş et.", 20))
	var groups := {}
	for f in alive:
		if not groups.has(f.species):
			groups[f.species] = []
		groups[f.species].append(f)
	for sp in groups:
		var arr: Array = groups[sp]
		var h := 0.0
		var v := 0
		for f in arr:
			h += f.health
			v += FishDB.market_value(sp, f.health, f.growth)
		h /= arr.size()
		var row := _row(body)
		var nm := _lbl("%s ×%d" % [FishDB.display_name(sp), arr.size()], 21)
		nm.custom_minimum_size.x = 230
		row.add_child(nm)
		var hl := _lbl("Sağlık %d%%" % int(h), 20)
		hl.add_theme_color_override("font_color", C_GOOD if h > 70 else (C_WARN if h > 40 else C_BAD))
		hl.custom_minimum_size.x = 150
		row.add_child(hl)
		row.add_child(_lbl("Değer ~%d ₺/adet" % int(v / arr.size()), 20))
	var desc := ""
	for sp in groups:
		desc += "• %s: %s\n" % [FishDB.display_name(sp), FishDB.get_species(sp).desc]
	if desc != "":
		var dl := _lbl(desc.strip_edges(), 18, Color(0.75, 0.8, 0.82))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 680
		body.add_child(dl)


# ------------------------------------------------------------------ Tedarik

func open_supplier() -> void:
	var body := _open("Tedarikçi Tableti", 860)
	_fill_supplier(body, 0, "fish")


func _fill_supplier(body: VBoxContainer, target_tank: int, tab: String) -> void:
	_clear(body)
	var tabs := _row(body)
	_btn(tabs, "Balıklar", func(): _fill_supplier(body, target_tank, "fish"), tab != "fish")
	_btn(tabs, "Ürünler", func(): _fill_supplier(body, target_tank, "products"), tab != "products")
	if tab == "products":
		for pid in ProductDB.ids():
			var p: Dictionary = ProductDB.get_product(pid)
			var row := _row(body)
			var n := _lbl(p.name, 21)
			n.custom_minimum_size.x = 250
			row.add_child(n)
			var info := _lbl("Alış %d ₺  •  Satış %d ₺  •  Stok %d" % [p.buy, p.price, Game.stock.get(pid, 0)], 19)
			info.custom_minimum_size.x = 380
			row.add_child(info)
			_btn(row, "×5 (%d ₺)" % (p.buy * 5), func():
				if Game.spend(p.buy * 5):
					Game.add_stock(pid, 5)
					Game.notify.emit("5 adet %s geldi." % p.name, "good")
				_fill_supplier(body, target_tank, tab), Game.money >= p.buy * 5)
		return
	var open_tanks: Array = []
	for t in Game.tanks:
		if t.unlocked:
			open_tanks.append(t.id)
	if open_tanks.is_empty():
		body.add_child(_lbl("Önce bir tank kirala.", 21))
		return
	if not open_tanks.has(target_tank):
		target_tank = open_tanks[0]
	var trow := _row(body)
	trow.add_child(_lbl("Hedef tank:", 21))
	for id in open_tanks:
		var tk: Dictionary = Game.tanks[id]
		_btn(trow, "T%d%s (%.0f°C, %d/%d)" % [id + 1, " 🌊" if tk.get("salt", false) else "", tk.heater, tk.fish.size(), TankSim.CAPACITY], func(): _fill_supplier(body, id, tab), id != target_tank)
	var tank: Dictionary = Game.tanks[target_tank]
	body.add_child(HSeparator.new())
	var salt: bool = bool(tank.get("salt", false))
	var hdr := _lbl("%s türleri (Tank %d %s)" % ["Tuzlu su" if salt else "Tatlı su", target_tank + 1, "tuzlu" if salt else "tatlı su"], 20, C_ACCENT.lightened(0.4))
	body.add_child(hdr)
	if not salt:
		body.add_child(_lbl("Deniz balıkları için tankı tuzlu suya çevir (tank panelinden).", 17, Color(0.75, 0.8, 0.82)))
	for sp in FishDB.salt_ids(salt):
		var s: Dictionary = FishDB.get_species(sp)
		var row := _row(body)
		var n := _lbl(s.name, 21)
		n.custom_minimum_size.x = 190
		row.add_child(n)
		var info := _lbl("Alış %d ₺ • Değer ~%d ₺ • %d-%d°C" % [s.buy, s.value, int(s.temp_min), int(s.temp_max)], 18)
		info.custom_minimum_size.x = 380
		row.add_child(info)
		var warn: String = TankSim.check_add(tank, sp)
		if tank.heater < s.temp_min - 0.5 or max(tank.heater, TankSim.ROOM_TEMP) > s.temp_max + 0.5:
			warn = "Isıtıcı ayarı (%.0f°C) bu türe uygun değil." % tank.heater if warn == "" else warn
		for qty in [1, 5]:
			var cost: int = int(s.buy) * qty
			var space: bool = tank.fish.size() + qty <= TankSim.CAPACITY
			_btn(row, "×%d (%d ₺)" % [qty, cost], func():
				if tank.fish.size() + qty > TankSim.CAPACITY:
					Game.notify.emit("Tankta yer yok.", "bad")
					return
				if Game.spend(cost):
					for i in qty:
						tank.fish.append(TankSim.new_fish(sp, Game.rng.randf_range(0.45, 0.8), Game.rng.randf_range(80.0, 95.0)))
					Game.tank_changed.emit(target_tank)
					Game.notify.emit("%d %s Tank %d'e kondu." % [qty, s.name, target_tank + 1], "good")
					if warn != "":
						Game.notify.emit("Dikkat: " + warn, "warn")
				_fill_supplier(body, target_tank, tab), Game.money >= cost and space)
		if warn != "":
			var wl := _lbl("   ⚠ " + warn, 17)
			wl.add_theme_color_override("font_color", C_WARN)
			body.add_child(wl)


# ------------------------------------------------------------------ Stok

func open_stock() -> void:
	var body := _open("Ürün Rafı")
	for pid in ProductDB.ids():
		var p: Dictionary = ProductDB.get_product(pid)
		var row := _row(body)
		var n := _lbl(p.name, 21)
		n.custom_minimum_size.x = 260
		row.add_child(n)
		row.add_child(_lbl("Stok: %d   Satış: %d ₺" % [Game.stock.get(pid, 0), p.price], 20))
	body.add_child(_lbl("Yem, su düzenleyici ve ilaç hem bakımda kullanılır hem müşteriye satılır.\nStok bitmesin, tabletten sipariş ver.", 18, Color(0.75, 0.8, 0.82)))


# ------------------------------------------------------------------ Kasa / Pazarlık

func open_register() -> void:
	var c: Customer = main.customer_at_register()
	if c == null:
		toast("Kasada bekleyen müşteri yok.", "info")
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
			nm = "🐟 %s (Tank %d)" % [FishDB.display_name(item.species), item.tank + 1]
		else:
			nm = "📦 %s" % ProductDB.get_product(item.id).name
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
	var row := _row(body)
	row.add_child(_lbl("Senin fiyatın:", 22))
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
	row.add_child(slider)
	row.add_child(ask_l)
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
	main.complete_sale(c, price)
	close_panel()
	toast("Satış: +%d ₺  “%s”" % [price, line], "good")


# ------------------------------------------------------------------ Gün sonu / menü

func show_report(r: Dictionary) -> void:
	var body := _open("Gün %d Raporu" % r.day, 640)
	var lines := [
		["Satış adedi", str(r.sales)],
		["Ciro", "+%s ₺" % Aquarium._fmt(r.revenue)],
		["Alımlar (tedarik)", "-%s ₺" % Aquarium._fmt(r.purchases)],
		["Kira", "-%s ₺" % Aquarium._fmt(r.rent)],
		["Elektrik (ısıtıcı/filtre/lamba)", "-%s ₺" % Aquarium._fmt(r.electric)],
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
	var text := """Akvaryum dükkânını ayakta tut!

• Tatlı su ve tuzlu su (deniz) tankları vardır. Palyaço balığı (Nemo), mavi cerrah (Dory) gibi deniz balıkları için tankı tuzlu suya çevir.

• Sabah hazırlık yap: tankları kontrol et, yem ver, gerekirse suyu değiştir.
• Hazır olunca ön kapıdan dükkânı aç. Gün 09:00-19:00 arası sürer.
• Müşteriler tankları gezer. Kirli su, hasta ya da ölü balık görürlerse itibarın düşer.
• Müşteri kasaya gelince kasaya bak ve pazarlık yap. Çok pahalı söylersen sabrı tükenir ve gider.
• Kasadaki tabletten balık ve ürün sipariş et. Türleri doğru tanka koy:
   - Japon balığı soğuk su ister, tropikal balıklarla olmaz.
   - Beta uzun yüzgeçlilere saldırır, melek balığı neonları yer.
   - Diskus çok kazandırır ama çok hassastır.
• Her akşam kira ve elektrik ödenir. 3 gün üst üste borçta kalırsan dükkân kapanır.

Kontroller: WASD + fare, E ile etkileşim, ESC menü.
Telefonda: sol taraf yürü, sağ taraf bak, ETKİLEŞ butonu."""
	var l := _lbl(text, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 780
	body.add_child(l)
	_btn(body, "Başla", close_panel)
