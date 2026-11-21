class_name MenuUI
extends Control
## Самописное меню (кнопки, ползунки, выбор). Свои касания, потому что кнопки Godot на телефоне
## не получают мышь из касаний (emulate_mouse_from_touch выключен). Работает и в паузе.

signal action(id: String, value: Variant)

const W := 500.0
const GOLD := Color("e8b830")

var font: Font
var items: Array = []
var title := ""
var subtitle := ""
var left_layout := false
var panel := false
var dim := 0.0
var sel := 0
var press_item := -1
var press_idx := -1
var rects: Array = []
var t := 0.0
var loading := ""


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_items(ttl: String, its: Array, sub: String = "") -> void:
	title = ttl
	subtitle = sub
	items = its
	press_item = -1
	press_idx = -1
	sel = 0
	for i in items.size():
		if _selectable(i):
			sel = i
			break
	queue_redraw()


func vs() -> Vector2:
	return get_viewport_rect().size


func _selectable(i: int) -> bool:
	var tp: String = items[i]["t"]
	return tp == "btn" or tp == "slider" or tp == "choice"


func _item_h(it: Dictionary) -> float:
	match String(it["t"]):
		"slider": return 82.0
		"text": return 44.0
		"gap": return 16.0
	return 66.0


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	queue_redraw()


func _layout() -> void:
	rects.clear()
	var total := 0.0
	for it in items:
		total += _item_h(it) + 12.0
	total -= 12.0
	var head := 0.0
	if title != "":
		head = 150.0 if left_layout else 96.0
	var x0 := 90.0 if left_layout else (vs().x - W) / 2.0
	var y0 := (vs().y - total - head) / 2.0 + head
	if left_layout:
		y0 = minf(maxf(y0, 270.0), vs().y - total - 18.0)
	for it in items:
		var h := _item_h(it)
		rects.append(Rect2(x0, y0, W, h))
		y0 += h + 12.0


func _hit(p: Vector2) -> int:
	_layout()
	for i in rects.size():
		if _selectable(i) and (rects[i] as Rect2).grow(6.0).has_point(p):
			return i
	return -1


func _slider_set(i: int, x: float) -> void:
	var r: Rect2 = rects[i]
	var tr := Rect2(r.position.x + 20.0, r.position.y + 52.0, r.size.x - 40.0, 8.0)
	var v := clampf((x - tr.position.x) / tr.size.x, 0.0, 1.0)
	var step: float = items[i].get("step", 0.0)
	if step > 0.0:
		v = snappedf(v, step)
	items[i]["v"] = v
	action.emit(String(items[i]["id"]), v)


func _choice_step(i: int, d: int) -> void:
	var opts: Array = items[i]["opts"]
	var n := (int(items[i]["i"]) + d + opts.size()) % opts.size()
	items[i]["i"] = n
	action.emit(String(items[i]["id"]), n)


func _activate(i: int, d: int = 1) -> void:
	var tp: String = items[i]["t"]
	if tp == "btn":
		action.emit(String(items[i]["id"]), null)
	elif tp == "choice":
		_choice_step(i, d)
	elif tp == "slider":
		var step: float = items[i].get("step", 0.1)
		var v := clampf(float(items[i]["v"]) + step * d, 0.0, 1.0)
		items[i]["v"] = v
		action.emit(String(items[i]["id"]), v)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or items.is_empty() or loading != "":
		return
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position
		if ev.pressed:
			var h := _hit(p)
			if h >= 0 and press_idx == -1:
				press_item = h
				press_idx = ev.index
				sel = h
				if items[h]["t"] == "slider":
					_slider_set(h, p.x)
			get_viewport().set_input_as_handled()
		elif ev.index == press_idx:
			var h2 := _hit(p)
			if h2 == press_item and h2 >= 0:
				var tp: String = items[h2]["t"]
				if tp == "btn":
					action.emit(String(items[h2]["id"]), null)
				elif tp == "choice":
					var r: Rect2 = rects[h2]
					_choice_step(h2, -1 if p.x < r.position.x + r.size.x * 0.3 else 1)
			press_item = -1
			press_idx = -1
			get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		if ev.index == press_idx and press_item >= 0 and items[press_item]["t"] == "slider":
			_slider_set(press_item, ev.position.x)
	elif ev is InputEventMouseMotion:
		var h3 := _hit(ev.position)
		if h3 >= 0:
			sel = h3
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if k == KEY_DOWN or k == KEY_S:
			_move_sel(1)
		elif k == KEY_UP or k == KEY_W:
			_move_sel(-1)
		elif k == KEY_LEFT or k == KEY_A:
			if sel < items.size() and items[sel]["t"] != "btn":
				_activate(sel, -1)
		elif k == KEY_RIGHT or k == KEY_D:
			if sel < items.size() and items[sel]["t"] != "btn":
				_activate(sel, 1)
		elif k == KEY_ENTER or k == KEY_SPACE or k == KEY_E:
			if sel < items.size():
				_activate(sel, 1)
		elif k == KEY_ESCAPE or k == KEY_P:
			action.emit("back", null)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		action.emit("back", null)


func _move_sel(d: int) -> void:
	var n := items.size()
	for k in n:
		sel = (sel + d + n) % n
		if _selectable(sel):
			return


func _txt(pos: Vector2, s: String, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0, outline: bool = true) -> void:
	var ts := Loc.t(s)
	if outline:
		draw_string_outline(font, pos, ts, align, w, fs, 6, Color(0, 0, 0, 0.85))
	draw_string(font, pos, ts, align, w, fs, col)


func _box(r: Rect2, bg: Color, border: Color, rad: int = 16, bw: int = 3) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	draw_style_box(sb, r)


func _draw() -> void:
	if font == null:
		return
	_layout()
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs()), Color(0, 0, 0, dim))
	if left_layout:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(vs().x * 0.62, 0), Vector2(vs().x * 0.62, vs().y), Vector2(0, vs().y)])
		var cols := PackedColorArray([Color(0, 0, 0, 0.72), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.72)])
		draw_polygon(pts, cols)
		draw_rect(Rect2(0, vs().y - 90, vs().x, 90), Color(0, 0, 0, 0.35))
	if items.is_empty():
		return
	var first: Rect2 = rects[0]
	var last: Rect2 = rects[rects.size() - 1]
	if panel:
		var top := first.position.y - (92.0 if title != "" else 24.0)
		_box(Rect2(first.position.x - 28.0, top, W + 56.0, last.end.y + 28.0 - top), Color(0.07, 0.09, 0.13, 0.93), GOLD, 22, 4)
	if title != "":
		if left_layout:
			_txt(Vector2(first.position.x - 4.0, 110.0), title, 74, GOLD)
			if subtitle != "":
				_txt(Vector2(first.position.x, 160.0), subtitle, 30, Color("e8e0c8"))
		else:
			_txt(Vector2(first.position.x, first.position.y - 36.0), title, 48, GOLD, HORIZONTAL_ALIGNMENT_CENTER, W)
	for i in items.size():
		var it: Dictionary = items[i]
		var r: Rect2 = rects[i]
		var hot := (i == sel) and _selectable(i)
		var down := i == press_item
		match String(it["t"]):
			"btn":
				var accent: bool = it.get("accent", false)
				var bg := Color("e0aa2a") if accent else Color(0.14, 0.17, 0.24, 0.94)
				if hot:
					bg = bg.lightened(0.12)
				if down:
					bg = bg.darkened(0.2)
				_box(r, bg, GOLD if not accent else Color("fff0b0"))
				_txt(Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 10.0), String(it["label"]), 30,
					Color("20180a") if accent else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, accent == false)
			"slider":
				_box(r, Color(0.14, 0.17, 0.24, 0.94) if not hot else Color(0.2, 0.24, 0.33, 0.96), GOLD)
				_txt(Vector2(r.position.x + 20.0, r.position.y + 34.0), String(it["label"]), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, false)
				_txt(Vector2(r.position.x, r.position.y + 34.0), "%d%%" % int(round(float(it["v"]) * 100.0)), 26, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0, false)
				var tr := Rect2(r.position.x + 20.0, r.position.y + 52.0, r.size.x - 40.0, 8.0)
				draw_rect(tr, Color(0, 0, 0, 0.55))
				draw_rect(Rect2(tr.position, Vector2(tr.size.x * float(it["v"]), tr.size.y)), GOLD)
				draw_circle(Vector2(tr.position.x + tr.size.x * float(it["v"]), tr.position.y + 4.0), 13.0, Color("fff0b0"))
				draw_arc(Vector2(tr.position.x + tr.size.x * float(it["v"]), tr.position.y + 4.0), 13.0, 0.0, TAU, 20, GOLD, 3.0)
			"choice":
				_box(r, Color(0.14, 0.17, 0.24, 0.94) if not hot else Color(0.2, 0.24, 0.33, 0.96), GOLD)
				var opts: Array = it["opts"]
				_txt(Vector2(r.position.x + 20.0, r.position.y + r.size.y / 2.0 + 9.0), String(it["label"]), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, false)
				_txt(Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 9.0), "<  %s  >" % Loc.t(String(opts[int(it["i"])])), 26, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0, false)
			"text":
				_txt(Vector2(r.position.x, r.position.y + 28.0), String(it["label"]), 22, Color("d8d0b8"), HORIZONTAL_ALIGNMENT_CENTER if not left_layout else HORIZONTAL_ALIGNMENT_LEFT, r.size.x)
	if loading != "":
		draw_rect(Rect2(Vector2.ZERO, vs()), Color(0, 0, 0, 0.78))
		_txt(Vector2(0, vs().y / 2.0), loading, 44, GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs().x)


# ---------- общие страницы ----------

static func settings_items() -> Array:
	return [
		{"t": "choice", "id": "quality", "label": "Графика", "opts": ["Низкая", "Обычная", "Высокая"], "i": Settings.quality},
		{"t": "slider", "id": "music", "label": "Музыка", "v": Settings.music, "step": 0.05},
		{"t": "slider", "id": "sfx", "label": "Звуки", "v": Settings.sfx, "step": 0.05},
		{"t": "slider", "id": "sens", "label": "Чувствительность камеры", "v": (Settings.sens - 0.4) / 1.6, "step": 0.05},
		{"t": "choice", "id": "lang", "label": "Язык", "opts": ["Авто", "Русский", "English"], "i": maxi(0, ["auto", "ru", "en"].find(Settings.lang))},
		{"t": "gap"},
		{"t": "btn", "id": "back", "label": "Назад"}]


## true — это была настройка и она применена
static func apply_setting(id: String, v: Variant) -> bool:
	match id:
		"quality": Settings.quality = int(v)
		"music": Settings.music = float(v)
		"sfx":
			Settings.sfx = float(v)
			Sfx.play("blip")
		"sens": Settings.sens = 0.4 + float(v) * 1.6
		"lang":
			Settings.lang = ["auto", "ru", "en"][int(v)]
			Loc.set_lang(Settings.resolve_lang())
		_:
			return false
	Settings.notify()
	return true
