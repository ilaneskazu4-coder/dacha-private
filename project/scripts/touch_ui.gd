class_name TouchUI
extends Control
## Интерфейс: плавающий стик, кнопки A/B/C, камера свайпом, панель стройки, диалоги, HUD, экран смерти.
## Работает и с пальцами (мультитач), и с мышью/клавиатурой для проверки на ПК.

var font: Font
var move_override := Vector2.ZERO

var joy_idx := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var look_idx := -1
var look_delta := Vector2.ZERO
var a_idx := -1
var b_idx := -1
var c_idx := -1
var w_idx := -1
var j_idx := -1
var j_pressed := false
var sw_idx := -1
var sp_idx := -1
var cm_idx := -1
var sw_pressed := false
# колесо смены героев (как в GTA 5): зажать «→», потянуть палец к герою, отпустить
var wheel_open := false
var wheel_sel := -1            # id выбранного героя
var wheel_pick := -1           # результат: id героя, на которого переключиться
var wheel_info: Array = []     # [{"id","name","hp","cur"}]
var wheel_t := 0.0
var wheel_origin := Vector2.ZERO
var sw_down_ms := 0
const WHEEL_HOLD_MS := 230
const WHEEL_ANG := [-90.0, 30.0, 150.0]     # где на кольце стоит герой 0, 1, 2
var portraits: Array = []
var sp_pressed := false
var cm_pressed := false
var sp_label := "Спец"
var sp_charge := 1.0      # 0..1 заряд спец-приёма
var sw_label := "Смена"
var cm_label := "Авто"
var sp_active := false
var buddy_on := true
var w_pressed := false
var w_label := "Оружие"
var a_held := false
var b_held := false
var key_a := false
var a_pressed := false
var b_pressed := false
var c_pressed := false
var a_label := ""
var b_label := "Орать"
var c_label := "Стройка"

# стройка
var build_mode := false
var hotbar: Array = []      # [{name, wood, stone, ok}]
var hot_sel := 0
var slot_tapped := -1

# часы
var clock_day := 1
var clock_frac := 0.0
var clock_text := ""
var clock_night := false
var wave_text := ""
var obj_override := ""
var drunk := 0.0
var in_club := false
var fish_on := false
var fish_pos := 0.0
var fish_zone := Vector2(0.4, 0.55)
var fish_left := 0
var fish_caught := 0

# окна
var modal := ""             # "", "dead", "ad"
var modal_title := ""
var modal_sub := ""
var modal_btn := ""
var modal_btn0 := "Возродиться за рекламу (с полным здоровьем)"
var net_hud := ""
var cash := 0
var stars := 0
var wanted_t := 0.0
var hurt_t := 0.0
var fade := 0.0
var pause_tapped := false

var dlg_active := false
var dlg_name := ""
var dlg_lines: Array = []
var dlg_i := 0
var dlg_chars := 0.0
var dlg_cb := Callable()

var toasts: Array = []
var panel_style := StyleBoxFlat.new()
var tag_style := StyleBoxFlat.new()
var btn_style := StyleBoxFlat.new()


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_style.bg_color = Color(0.06, 0.05, 0.1, 0.86)
	panel_style.set_corner_radius_all(16)
	panel_style.border_color = Color("e8c23a")
	panel_style.set_border_width_all(3)
	tag_style.bg_color = Color("e8c23a")
	tag_style.set_corner_radius_all(10)
	btn_style.set_corner_radius_all(14)
	btn_style.set_border_width_all(3)


# ---------- раскладка ----------

func a_center() -> Vector2:
	return Vector2(size.x - 130.0, size.y - 150.0)


func b_center() -> Vector2:
	return Vector2(size.x - 290.0, size.y - 90.0)


func j_center() -> Vector2:
	return Vector2(size.x - 460.0, size.y - 160.0)


func sw_center() -> Vector2:
	return Vector2(size.x - 470.0, size.y - 290.0)


func sp_center() -> Vector2:
	return Vector2(size.x - 300.0, size.y - 345.0)


func cm_center() -> Vector2:
	return Vector2(size.x - 470.0, size.y - 400.0)


func w_center() -> Vector2:
	return Vector2(size.x - 300.0, size.y - 225.0)


func c_center() -> Vector2:
	return Vector2(size.x - 130.0, size.y - 300.0)


func slot_rect(i: int) -> Rect2:
	var n := hotbar.size()
	var w := 118.0
	var gap := 8.0
	var total := n * w + (n - 1) * gap
	var x0 := size.x * 0.5 - total * 0.5 - 40.0
	return Rect2(x0 + i * (w + gap), size.y - 118.0, w, 104.0)


func modal_btn_rect(i: int) -> Rect2:
	var cx := size.x * 0.5
	return Rect2(cx - 290.0, size.y * 0.5 + 10.0 + i * 82.0, 580.0, 70.0)


# ---------- ввод ----------

func is_a_held() -> bool:
	return a_held or key_a


func get_move() -> Vector2:
	if move_override != Vector2.ZERO:
		return move_override
	var kb := Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		- int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if kb != Vector2.ZERO:
		return kb.normalized()
	if joy_idx != -1:
		return ((joy_pos - joy_origin) / 80.0).limit_length(1.0)
	return Vector2.ZERO


func pause_center() -> Vector2:
	return Vector2(size.x - 52.0, 150.0)


func _draw_pause_btn() -> void:
	var c := pause_center()
	draw_circle(c, 30.0, Color(0.07, 0.09, 0.13, 0.72))
	draw_arc(c, 30.0, 0.0, TAU, 28, Color("e8b830"), 3.0)
	draw_rect(Rect2(c.x - 10.0, c.y - 11.0, 7.0, 22.0), Color("fff0b0"))
	draw_rect(Rect2(c.x + 3.0, c.y - 11.0, 7.0, 22.0), Color("fff0b0"))


func take_look() -> Vector2:
	var d := look_delta * Settings.sens
	look_delta = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_Z):
		d.x -= 6.0
	if Input.is_physical_key_pressed(KEY_C):
		d.x += 6.0
	return d


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position
		if ev.pressed:
			if modal == "dead":
				for i in 2:
					if modal_btn_rect(i).has_point(p):
						modal_btn = "ad" if i == 0 else "respawn"
				return
			if modal != "":
				return
			if dlg_active:
				_advance()
				return
			if build_mode:
				for i in hotbar.size():
					if slot_rect(i).has_point(p):
						slot_tapped = i
						return
			if p.distance_to(pause_center()) < 46.0:
				pause_tapped = true
				return
			if p.distance_to(a_center()) < 80.0 and a_idx == -1:
				a_idx = ev.index
				a_held = true
				a_pressed = true
			elif p.distance_to(b_center()) < 60.0 and b_idx == -1:
				b_idx = ev.index
				b_held = true
				b_pressed = true
			elif p.distance_to(j_center()) < 54.0 and j_idx == -1:
				j_idx = ev.index
				j_pressed = true
			elif buddy_on and p.distance_to(sw_center()) < 50.0 and sw_idx == -1:
				sw_idx = ev.index
				wheel_origin = p
				sw_down_ms = Time.get_ticks_msec()
			elif p.distance_to(sp_center()) < 52.0 and sp_idx == -1:
				sp_idx = ev.index
				sp_pressed = true
			elif buddy_on and p.distance_to(cm_center()) < 46.0 and cm_idx == -1:
				cm_idx = ev.index
				cm_pressed = true
			elif p.distance_to(w_center()) < 50.0 and w_idx == -1:
				w_idx = ev.index
				w_pressed = true
			elif p.distance_to(c_center()) < 56.0 and c_idx == -1:
				c_idx = ev.index
				c_pressed = true
			elif p.x < size.x * 0.45 and joy_idx == -1:
				joy_idx = ev.index
				joy_origin = p
				joy_pos = p
			elif p.x >= size.x * 0.45 and look_idx == -1:
				look_idx = ev.index
		else:
			if ev.index == a_idx:
				a_idx = -1
				a_held = false
			elif ev.index == b_idx:
				b_idx = -1
				b_held = false
			elif ev.index == c_idx:
				c_idx = -1
			elif ev.index == w_idx:
				w_idx = -1
			elif ev.index == j_idx:
				j_idx = -1
			elif ev.index == sw_idx:
				sw_idx = -1
				wheel_end()
			elif ev.index == sp_idx:
				sp_idx = -1
			elif ev.index == cm_idx:
				cm_idx = -1
			elif ev.index == joy_idx:
				joy_idx = -1
			elif ev.index == look_idx:
				look_idx = -1
	elif ev is InputEventScreenDrag:
		if ev.index == sw_idx and wheel_open:
			wheel_drag(ev.position)
		elif ev.index == look_idx:
			look_delta += ev.relative
		elif ev.index == joy_idx:
			joy_pos = ev.position
			var d := joy_pos - joy_origin
			if d.length() > 80.0:
				joy_pos = joy_origin + d.normalized() * 80.0
	elif ev is InputEventKey:
		var k: int = ev.physical_keycode
		if modal == "dead" and ev.pressed and not ev.echo:
			if k == KEY_ENTER or k == KEY_E:
				modal_btn = "ad"
			elif k == KEY_ESCAPE:
				modal_btn = "respawn"
			return
		if k == KEY_E or k == KEY_SPACE or k == KEY_ENTER:
			if ev.pressed and not ev.echo:
				if dlg_active:
					_advance()
				elif modal == "":
					a_pressed = true
			key_a = ev.pressed and modal == ""
		elif k == KEY_Q or k == KEY_SHIFT:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				b_pressed = true
		elif k == KEY_R:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				w_pressed = true
		elif k == KEY_TAB:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				sw_pressed = true
		elif k == KEY_G:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				sp_pressed = true
		elif k == KEY_K:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				cm_pressed = true
		elif k == KEY_J:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				j_pressed = true
		elif k == KEY_F:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				c_pressed = true
		elif k == KEY_ESCAPE or k == KEY_P:
			if ev.pressed and not ev.echo and not dlg_active and modal == "":
				pause_tapped = true
		elif k >= KEY_1 and k <= KEY_9:
			if ev.pressed and build_mode and (k - KEY_1) < hotbar.size():
				slot_tapped = k - KEY_1


# ---------- диалоги и подсказки ----------

func open_dialog(speaker: String, lines: Array, cb: Callable = Callable()) -> void:
	dlg_active = true
	dlg_name = speaker
	dlg_lines = lines
	dlg_i = 0
	dlg_chars = 0.0
	dlg_cb = cb
	a_pressed = false
	b_pressed = false
	joy_idx = -1


func _advance() -> void:
	if dlg_i >= dlg_lines.size():
		return
	var full: int = Loc.t(String(dlg_lines[dlg_i])).length()
	if dlg_chars < full:
		dlg_chars = full
		return
	Sfx.play("blip")
	dlg_i += 1
	dlg_chars = 0.0
	if dlg_i >= dlg_lines.size():
		dlg_active = false
		var cb := dlg_cb
		dlg_cb = Callable()
		if cb.is_valid():
			cb.call()


func toast(text: String, col: Color = Color.WHITE) -> void:
	toasts.append([text, col, 0.0])
	while toasts.size() > 3:
		toasts.pop_front()


func wheel_drag(pos: Vector2) -> void:
	var d := pos - wheel_origin
	if d.length() < 28.0:
		wheel_sel = -1
		return
	var ang := rad_to_deg(d.angle())
	var best := -1
	var bd := 1e9
	for info in wheel_info:
		var k: int = int(info["id"])
		var da: float = absf(wrapf(ang - float(WHEEL_ANG[k]) + 180.0, 0.0, 360.0) - 180.0)
		if da < bd:
			bd = da
			best = k
	wheel_sel = best


func wheel_end() -> void:
	if wheel_open:
		wheel_open = false
		wheel_pick = wheel_sel
		wheel_sel = -1
	else:
		sw_pressed = true      # короткий тап — следующий герой, как раньше


func _process(delta: float) -> void:
	wanted_t += delta
	if sw_idx != -1 and not wheel_open and wheel_info.size() == 3 and Time.get_ticks_msec() - sw_down_ms > WHEEL_HOLD_MS \
			and not dlg_active and modal == "":
		wheel_open = true
		wheel_sel = -1
		wheel_t = 0.0
	if wheel_open:
		wheel_t += delta / maxf(Engine.time_scale, 0.05)
	if wheel_open and (dlg_active or modal != ""):
		wheel_open = false
	if dlg_active:
		dlg_chars += delta * 55.0
	for t in toasts:
		t[2] += delta
	toasts = toasts.filter(func(t): return t[2] < 3.4)
	queue_redraw()


# ---------- рисование ----------

func _text(pos: Vector2, s: String, fs: int, col: Color = Color.WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	s = Loc.t(s)
	draw_string_outline(font, pos, s, align, w, fs, 6, Color(0, 0, 0, 0.85))
	draw_string(font, pos, s, align, w, fs, col)


func _draw() -> void:
	_draw_hurt()
	_draw_drunk()
	_draw_hud()
	if modal != "":
		_draw_modal()
	elif dlg_active:
		_draw_dialog()
	else:
		_draw_controls()
		_draw_pause_btn()
		if build_mode:
			_draw_hotbar()
	if wheel_open:
		_draw_wheel()
	if fish_on:
		_draw_fish()
	_draw_toasts()
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade))


func _draw_drunk() -> void:
	if drunk <= 0.05:
		return
	var k := minf(drunk, 5.0) / 5.0
	var tt := Time.get_ticks_msec() / 1000.0
	var a := 0.05 + k * 0.12 + sin(tt * 2.0) * 0.03 * k
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.35, 0.95, a))
	for i in 2:
		var off := Vector2(sin(tt * 1.3 + i * 3.0), cos(tt * 1.1 + i)) * 14.0 * k
		draw_rect(Rect2(off + Vector2(size.x * 0.25, size.y * 0.2), Vector2(size.x * 0.5, size.y * 0.6)), Color(1, 1, 1, 0.025 * k), false, 3.0)
	_text(Vector2(0, size.y - 14), "Голова кругом: %d" % int(ceilf(drunk)), 18, Color("ffb0ff"), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_wheel() -> void:
	if portraits.is_empty():
		for i in 3:
			portraits.append(load("res://assets/ui/portrait_%d.png" % i))
	var a := clampf(wheel_t / 0.18, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55 * a))
	var c := size * 0.5
	var R := 150.0 * (0.8 + 0.2 * a)
	var cols := [Color("ff9a2a"), Color("e8e8f0"), Color("6acb6a")]
	# внешнее кольцо
	draw_arc(c, R + 62.0, 0.0, TAU, 96, Color(1, 1, 1, 0.18 * a), 3.0)
	draw_arc(c, R - 62.0, 0.0, TAU, 96, Color(1, 1, 1, 0.18 * a), 3.0)
	for info in wheel_info:
		var k: int = int(info["id"])
		var ang := deg_to_rad(float(WHEEL_ANG[k]))
		var sel := k == wheel_sel
		var base: Color = Color(0.1, 0.12, 0.18, 0.78 * a)
		var ring_col: Color = Color("ffd23a") if sel else (Color(1, 1, 1, 0.55) if bool(info["cur"]) else Color(1, 1, 1, 0.25))
		# сектор кольца
		draw_arc(c, R, ang - deg_to_rad(52.0), ang + deg_to_rad(52.0), 32, base, 104.0)
		draw_arc(c, R + 52.0, ang - deg_to_rad(52.0), ang + deg_to_rad(52.0), 32, ring_col, 5.0 if sel else 3.0)
		var pos := c + Vector2(cos(ang), sin(ang)) * R
		var pr := 54.0 * (1.14 if sel else 1.0)
		draw_circle(pos, pr + 5.0, ring_col)
		draw_circle(pos, pr + 1.0, Color(0.05, 0.06, 0.1))
		var tex: Texture2D = portraits[k]
		draw_texture_rect(tex, Rect2(pos - Vector2(pr, pr), Vector2(pr, pr) * 2.0), false, Color(1, 1, 1, a if not bool(info["cur"]) else a))
		# полоска здоровья
		var hp := clampf(float(info["hp"]) / 100.0, 0.0, 1.0)
		var bw := 84.0
		var bp := pos + Vector2(-bw * 0.5, pr + 12.0)
		draw_rect(Rect2(bp, Vector2(bw, 7)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bp, Vector2(bw * hp, 7)), Color("46e06a") if hp > 0.35 else Color("ff5a4a"))
		_text(pos + Vector2(-60, pr + 36.0), String(info["name"]), 17, cols[k] if sel else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	# центр
	var nm := ""
	for info in wheel_info:
		if int(info["id"]) == wheel_sel:
			nm = String(info["name"])
	draw_circle(c, 46.0, Color(0.05, 0.06, 0.1, 0.8 * a))
	draw_arc(c, 46.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5 * a), 2.0)
	_text(c + Vector2(-60, 6), nm if nm != "" else "Выбери", 16, Color("ffd23a") if nm != "" else Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	_text(Vector2(0, size.y - 60.0), "Потяни к герою и отпусти", 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_hurt() -> void:
	var low := clampf(1.0 - Game.hp / Game.max_hp, 0.0, 1.0)
	var a := maxf(hurt_t * 0.9, low * low * 0.5)
	if a <= 0.01:
		return
	var c := Color(0.8, 0.05, 0.05, a)
	var e := 90.0
	draw_rect(Rect2(0, 0, size.x, e), Color(c.r, c.g, c.b, a * 0.55))
	draw_rect(Rect2(0, size.y - e, size.x, e), Color(c.r, c.g, c.b, a * 0.55))
	draw_rect(Rect2(0, 0, e, size.y), Color(c.r, c.g, c.b, a * 0.55))
	draw_rect(Rect2(size.x - e, 0, e, size.y), Color(c.r, c.g, c.b, a * 0.55))


func _draw_hud() -> void:
	if net_hud != "":
		var ls := net_hud.split("\n")
		for i in ls.size():
			_text(Vector2(0, 118 + i * 28), ls[i], 24 if i == 0 else 20, Color("ffe08a") if i == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	draw_style_box(panel_style, Rect2(14, 14, 250, 150))
	_text(Vector2(28, 152), "Деньги: $%d" % cash, 22, Color("8aff9a"))
	if stars > 0:
		var sc := Color("ff4a4a") if int(wanted_t * 4.0) % 2 == 0 else Color("4a8aff")
		_text(Vector2(28, 198), "РОЗЫСК " + "★".repeat(stars) + "☆".repeat(5 - stars), 26, sc)
	draw_rect(Rect2(28, 28, 34, 14), Color("8a5a2b"))
	draw_circle(Vector2(28, 35), 7.0, Color("c98f4f"))
	_text(Vector2(74, 42), "Брёвна: %d" % Game.wood, 22)
	draw_circle(Vector2(45, 68), 11.0, Color("9aa0aa"))
	draw_circle(Vector2(41, 64), 5.0, Color("c0c6d0"))
	_text(Vector2(74, 76), "Камень: %d" % Game.stone, 22, Color("d8dce4"))
	# здоровье
	var hp_frac := clampf(Game.hp / Game.max_hp, 0.0, 1.0)
	draw_rect(Rect2(28, 92, 222, 22), Color(0, 0, 0, 0.6))
	var col := Color("3adf6a").lerp(Color("e03a3a"), 1.0 - hp_frac)
	draw_rect(Rect2(30, 94, 218 * hp_frac, 18), col)
	_text(Vector2(28, 109), "  %d" % int(ceilf(Game.hp)), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 222.0)

	# часы
	var cw := 250.0
	var cx := size.x - cw - 14.0
	draw_style_box(panel_style, Rect2(cx, 14, cw, 86))
	_text(Vector2(cx + 16, 44), "День %d" % clock_day, 24, Color("ffe08a") if not clock_night else Color("9ab4ff"))
	_text(Vector2(cx + 10, 44), clock_text, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, cw - 20.0)
	var bx := cx + 16.0
	var bw := cw - 32.0
	draw_rect(Rect2(bx, 60, bw, 12), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bx, 60, bw * (150.0 / 270.0), 12), Color(0.95, 0.75, 0.25, 0.85))
	draw_rect(Rect2(bx + bw * (170.0 / 270.0), 60, bw * (85.0 / 270.0), 12), Color(0.25, 0.3, 0.7, 0.9))
	var mx := bx + bw * clock_frac
	draw_circle(Vector2(mx, 66), 9.0, Color.WHITE if not clock_night else Color("cfe0ff"))
	if wave_text != "":
		_text(Vector2(cx + 10, 92), wave_text, 15, Color("ff9a9a"), HORIZONTAL_ALIGNMENT_CENTER, cw - 20.0)

	var ox := 278.0
	var ow := size.x - ox - cw - 28.0
	var r := Rect2(ox, 14, ow, 70)
	draw_style_box(panel_style, r)
	draw_multiline_string(font, Vector2(r.position.x + 18, r.position.y + 28), Loc.t(obj_override if obj_override != "" else Game.objective()),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 19, 2, Color.WHITE)


func _draw_controls() -> void:
	if joy_idx != -1:
		draw_circle(joy_origin, 80.0, Color(1, 1, 1, 0.12))
		draw_arc(joy_origin, 80.0, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(joy_pos, 34.0, Color(1, 1, 1, 0.4))
	else:
		var hint := Vector2(170, size.y - 150)
		draw_arc(hint, 80.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 3.0)
		draw_circle(hint, 30.0, Color(1, 1, 1, 0.12))
	var a := a_center()
	draw_circle(a, 70.0, Color(0.95, 0.75, 0.2, 0.85 if is_a_held() else 0.55))
	draw_arc(a, 70.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
	_text(a + Vector2(-100, 8), a_label, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
	var b := b_center()
	draw_circle(b, 50.0, Color(0.3, 0.6, 0.95, 0.85 if b_held else 0.55))
	draw_arc(b, 50.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
	_text(b + Vector2(-70, 7), b_label, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	var wc := w_center()
	draw_circle(wc, 42.0, Color(0.85, 0.3, 0.3, 0.6))
	draw_arc(wc, 42.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
	_text(wc + Vector2(-60, 6), w_label, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	var jc := j_center()
	draw_circle(jc, 48.0, Color(0.95, 0.95, 0.4, 0.75 if j_idx != -1 else 0.5))
	draw_arc(jc, 48.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
	_text(jc + Vector2(-60, 7), "Прыжок", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	if buddy_on:
		var sc := sw_center()
		draw_circle(sc, 44.0, Color(0.6, 0.4, 0.95, 0.75 if sw_idx != -1 else 0.55))
		draw_arc(sc, 44.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
		_text(sc + Vector2(-60, 7), sw_label, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		var cc := cm_center()
		draw_circle(cc, 38.0, Color(0.2, 0.55, 0.6, 0.75 if cm_idx != -1 else 0.55))
		draw_arc(cc, 38.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
		_text(cc + Vector2(-60, 6), cm_label, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	var spc := sp_center()
	var ready := sp_charge >= 1.0
	draw_circle(spc, 46.0, Color(0.95, 0.35, 0.15, 0.85) if (ready or sp_active) else Color(0.35, 0.25, 0.25, 0.6))
	draw_arc(spc, 46.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(sp_charge, 0.0, 1.0), 40, Color("ffd23a"), 6.0)
	_text(spc + Vector2(-60, 7), sp_label, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	var c := c_center()
	draw_circle(c, 46.0, Color(0.3, 0.85, 0.45, 0.8 if build_mode else 0.5))
	draw_arc(c, 46.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
	_text(c + Vector2(-60, 7), c_label, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)


func _draw_hotbar() -> void:
	for i in hotbar.size():
		var r := slot_rect(i)
		var d: Dictionary = hotbar[i]
		btn_style.bg_color = Color(0.08, 0.07, 0.12, 0.9)
		btn_style.border_color = Color("ffd23a") if i == hot_sel else Color(1, 1, 1, 0.35)
		draw_style_box(btn_style, r)
		var ok: bool = d.get("ok", true)
		_text(r.position + Vector2(0, 28), "%d. %s" % [i + 1, d["name"]], 18, Color.WHITE if ok else Color("ff8a8a"),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var wood: int = d.get("wood", 0)
		var stone: int = d.get("stone", 0)
		if wood > 0:
			draw_rect(Rect2(r.position.x + 12, r.position.y + 48, 26, 11), Color("8a5a2b"))
			_text(r.position + Vector2(44, 60), str(wood), 18)
		if stone > 0:
			draw_circle(r.position + Vector2(80, 54), 9.0, Color("9aa0aa"))
			_text(r.position + Vector2(94, 60), str(stone), 18)
		if d.get("remove", false):
			_text(r.position + Vector2(0, 66), "вернёт 50%", 15, Color("c8e6ff"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if i == hot_sel:
			_text(r.position + Vector2(0, 94), "A: поставить" if not d.get("remove", false) else "A: убрать", 15,
				Color("ffd23a"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_modal() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.62))
	var pw := 660.0
	var r := Rect2(size.x * 0.5 - pw * 0.5, size.y * 0.5 - 190.0, pw, 380.0)
	draw_style_box(panel_style, r)
	_text(Vector2(r.position.x, r.position.y + 62), modal_title, 40, Color("ff8a8a"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(r.position.x, r.position.y + 104), modal_sub, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if modal == "dead":
		btn_style.bg_color = Color("c98f1a")
		btn_style.border_color = Color("ffe08a")
		draw_style_box(btn_style, modal_btn_rect(0))
		_text(modal_btn_rect(0).position + Vector2(0, 44), modal_btn0, 22,
			Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 580.0)
		btn_style.bg_color = Color("3a3f52")
		btn_style.border_color = Color(1, 1, 1, 0.5)
		draw_style_box(btn_style, modal_btn_rect(1))
		_text(modal_btn_rect(1).position + Vector2(0, 44), "Заново на даче (потеряешь половину ресурсов)", 22,
			Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 580.0)
	else:
		_text(Vector2(r.position.x, r.position.y + 230), "Идёт реклама...", 30, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_dialog() -> void:
	var r := Rect2(40, size.y - 230, size.x - 80, 200)
	draw_style_box(panel_style, r)
	var shown_name := Loc.t(dlg_name)
	var nm_w := font.get_string_size(shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40.0
	var tag := Rect2(r.position.x + 24, r.position.y - 22, nm_w, 40)
	draw_style_box(tag_style, tag)
	draw_string(font, Vector2(tag.position.x + 20, tag.position.y + 29), shown_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("1a1020"))
	var line: String = Loc.t(String(dlg_lines[dlg_i])) if dlg_i < dlg_lines.size() else ""
	var shown := line.substr(0, int(dlg_chars))
	draw_multiline_string(font, Vector2(r.position.x + 28, r.position.y + 62), shown,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 26, 4, Color.WHITE)
	if dlg_chars >= line.length():
		_text(Vector2(r.end.x - 260, r.end.y - 16), "Нажми, чтобы дальше >>", 18, Color("e8c23a"),
			HORIZONTAL_ALIGNMENT_RIGHT, 240.0)


func _draw_toasts() -> void:
	var y := 150.0
	for t in toasts:
		var a := 1.0 - clampf((float(t[2]) - 2.6) / 0.8, 0.0, 1.0)
		var col: Color = t[1]
		_text(Vector2(0, y), t[0], 22, Color(col.r, col.g, col.b, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		y += 30.0


func _draw_fish() -> void:
	var w := 520.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - 120.0, w, 140.0)
	draw_style_box(panel_style, r)
	_text(Vector2(r.position.x, r.position.y + 38), "Рыбалка: жми A, когда поплавок в зелёной зоне", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	var bar := Rect2(r.position.x + 30, r.position.y + 60, w - 60, 30)
	draw_rect(bar, Color(0, 0, 0, 0.65))
	draw_rect(Rect2(bar.position.x + bar.size.x * fish_zone.x, bar.position.y, bar.size.x * (fish_zone.y - fish_zone.x), bar.size.y), Color("3adf6a"))
	var mx := bar.position.x + bar.size.x * fish_pos
	draw_rect(Rect2(mx - 5, bar.position.y - 6, 10, bar.size.y + 12), Color("ffe08a"))
	_text(Vector2(r.position.x, r.position.y + 124), "Попыток: %d    Поймано: %d" % [fish_left, fish_caught], 18, Color("c8e6ff"), HORIZONTAL_ALIGNMENT_CENTER, w)
