class_name Osk
extends Control
## Своя экранная клавиатура (системная на телефоне не открывалась). Кнопки работают от касаний.

signal done(text: String, ok: bool)

const EN := ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm.:-/"]
const RU := ["1234567890", "йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю.:-"]

var text := ""
var max_len := 24
var ru := false
var shift := false
var upper_only := false
var title := ""
var hint := ""
var cc: CenterContainer
var dim: ColorRect
var disp: Label
var title_l: Label
var rows_box: VBoxContainer
var lang_btn: Button
var shift_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.98)
	add_child(dim)
	cc = CenterContainer.new()
	add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	cc.add_child(box)
	title_l = Label.new()
	title_l.add_theme_font_size_override("font_size", 30)
	title_l.add_theme_color_override("font_color", Color("e8c45a"))
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_l)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.17)
	sb.border_color = Color("e8c45a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(1000, 64)
	box.add_child(pc)
	disp = Label.new()
	disp.add_theme_font_size_override("font_size", 38)
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(disp)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 6)
	rows_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(rows_box)


func open(ttl: String, start: String, maxlen: int, hnt := "", upper := false) -> void:
	title = ttl
	hint = hnt
	text = start
	max_len = maxlen
	upper_only = upper
	shift = upper
	visible = true
	_fit()
	_rebuild()


func _fit() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	dim.size = vs
	cc.size = vs
	cc.position = Vector2.ZERO


func _key(parent: HBoxContainer, label: String, w: float, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(w, 66)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	if accent:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("b98a1e")
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _rebuild() -> void:
	title_l.text = title if hint == "" else "%s\n%s" % [title, hint]
	for c in rows_box.get_children():
		c.queue_free()
	var layout: Array = RU if ru else EN
	if upper_only:
		layout = EN
	for r in layout:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 6)
		rows_box.add_child(h)
		for i in (r as String).length():
			var ch: String = (r as String)[i]
			var shown := ch.to_upper() if shift else ch
			_key(h, shown, 84, _type.bind(shown))
	var h2 := HBoxContainer.new()
	h2.alignment = BoxContainer.ALIGNMENT_CENTER
	h2.add_theme_constant_override("separation", 6)
	rows_box.add_child(h2)
	if not upper_only:
		lang_btn = _key(h2, "РУС" if ru else "ENG", 110, func(): ru = not ru; _rebuild())
		shift_btn = _key(h2, "Аа", 100, func(): shift = not shift; _rebuild())
	_key(h2, "пробел", 220, _type.bind(" "))
	_key(h2, "⌫", 110, _back)
	_key(h2, "Отмена", 150, func(): _finish(false))
	_key(h2, "ГОТОВО", 170, func(): _finish(true), true)
	_show_text()


func _type(ch: String) -> void:
	if text.length() < max_len:
		text += ch
		if shift and not upper_only:
			shift = false
			_rebuild()
			return
	_show_text()


func _back() -> void:
	if text.length() > 0:
		text = text.substr(0, text.length() - 1)
	_show_text()


func _show_text() -> void:
	disp.text = text + "▏"


func _finish(ok: bool) -> void:
	visible = false
	done.emit(text.strip_edges(), ok)


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed:
		return
	var k := e as InputEventKey
	if k.keycode == KEY_BACKSPACE:
		_back()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_finish(true)
	elif k.keycode == KEY_ESCAPE:
		_finish(false)
	elif k.unicode >= 32:
		_type(char(k.unicode).to_upper() if upper_only else char(k.unicode))
	get_viewport().set_input_as_handled()
