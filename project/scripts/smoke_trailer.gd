extends Node
## Кинотрейлер для Shorts (вертикаль). Запуск: --smoke-trailer, запись --write-movie --fixed-fps 30.
var m: Node3D
var fc: Camera3D
var ov: CanvasLayer
var fade: ColorRect
var cam_fn := Callable()
var cam_t := 0.0
var cam_dur := 1.0
var shake := 0.0
var clock := 0.0
var orbit := 0.0
var tfont: FontVariation

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	m = get_parent()
	run.call_deferred()

func _process(delta: float) -> void:
	clock += delta
	if m == null:
		return
	if m.ui != null and m.ui.dlg_active:
		m.ui.dlg_active = false
		m.ui.dlg_lines = []
	if m.mode == "dialog":
		m.mode = "play"
	if fc != null and fc.current and cam_fn.is_valid():
		cam_t += delta
		var u := clampf(cam_t / cam_dur, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65
		var r: Array = cam_fn.call(u)
		var p: Vector3 = r[0]
		p += Vector3(sin(clock * 9.0), sin(clock * 7.3), sin(clock * 8.1)) * shake
		fc.global_position = p
		fc.look_at(r[1], Vector3.UP)
	elif m.mode != "car":
		m.yaw += orbit * delta

# ---- камера ----
func cine(fn: Callable, dur: float, fov := 72.0) -> void:
	cam_fn = fn
	cam_t = 0.0
	cam_dur = dur
	fc.fov = fov
	fc.current = true
	m.ui.visible = false
	m.player.visible = false
	punch()

func game() -> void:
	m.cam.make_current()
	m.ui.visible = true
	m.player.visible = true
	punch()

func lin(p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3) -> Callable:
	return func(u: float) -> Array: return [p0.lerp(p1, u), l0.lerp(l1, u)]

func arc(c: Vector3, r0: float, r1: float, h0: float, h1: float, a0: float, a1: float, lh: float) -> Callable:
	return func(u: float) -> Array:
		var a: float = lerpf(a0, a1, u)
		var r: float = lerpf(r0, r1, u)
		return [c + Vector3(sin(a) * r, lerpf(h0, h1, u), cos(a) * r), c + Vector3(0, lh, 0)]

# ---- оверлей ----
func punch() -> void:
	var tw := create_tween()
	fade.color = Color(1, 1, 1, 0.55)
	tw.tween_property(fade, "color", Color(1, 1, 1, 0), 0.25)

func caption(text: String, dur: float, size := 96, y := 0.66, col := Color(1.0, 0.82, 0.25)) -> void:
	if tfont == null:
		var ff := FontFile.new()
		ff.load_dynamic_font("/usr/share/fonts/opentype/inter/InterDisplay-BlackItalic.otf")
		tfont = FontVariation.new()
		tfont.base_font = ff
		tfont.spacing_glyph = 3
	var l := Label.new()
	l.add_theme_font_override("font", tfont)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", int(size * 0.06))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.anchor_top = y - 0.1
	l.anchor_bottom = y + 0.1
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", int(size * 0.16))
	l.modulate.a = 0.0
	ov.add_child(l)
	var vs := get_viewport().get_visible_rect().size
	l.pivot_offset = Vector2(vs.x * 0.5, vs.y * 0.1 * 1.0)
	l.scale = Vector2(1.35, 1.35)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.18)
	tw.tween_property(l, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw2 := create_tween()
	tw2.tween_interval(maxf(dur - 0.25, 0.1))
	tw2.tween_property(l, "modulate:a", 0.0, 0.22)
	tw2.tween_callback(l.queue_free)

func black(a: float, s: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color", Color(0, 0, 0, a), s)

func run() -> void:
	Settings.quality = 2
	m._apply_quality()
	ov = CanvasLayer.new()
	ov.layer = 50
	add_child(ov)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(fade)
	fc = Camera3D.new()
	fc.keep_aspect = Camera3D.KEEP_WIDTH
	fc.near = 0.3
	fc.far = 220.0
	m.add_child(fc)
	m.cam.keep_aspect = Camera3D.KEEP_WIDTH
	await wait(0.6)
	m.ui.dlg_active = false
	m.mode = "play"
	Game.intro_done = true
	Game.stage = 4
	Game.hp = 100
	Game.wood = 6
	Game.stone = 1
	m.player.global_position = Vector3(-3.5, 0.05, 6.5)
	m.dn.t = 177.0
	m.dn._apply()
	# A. ночной облёт дачи + заголовок
	cine(arc(Vector3(0, 1.8, 0), 9.5, 6.5, 1.2, 2.3, -0.55, 0.4, 2.4), 3.0, 82.0)
	shake = 0.03
	black(0.0, 0.5)
	caption("ДАЧА\nМИХАЛЫЧА", 2.9, 150, 0.30)
	await wait(3.0)
	# B. дрон над днём
	m.dn.t = 40.0
	m.dn._apply()
	cine(lin(Vector3(80, 26, 95), Vector3(16, 6.5, 24), Vector3(0, 3, 0), Vector3(0, 4, 0)), 3.0, 80.0)
	await wait(3.0)
	# C. рубим дерево
	var best := -1
	var bd := 1e9
	for i in m.forest.items.size():
		var it: Dictionary = m.forest.items[i]
		if it["kind"] != "tree": continue
		var d: float = (it["pos"] as Vector3).distance_to(Vector3(24, 0, 28))
		if d < bd: bd = d; best = i
	var tp: Vector3 = m.forest.items[best]["pos"]
	m.player.global_position = tp + Vector3(0, 0, 1.7)
	m.player.face = 0.0
	m.yaw = 0.4
	m.pitch = 0.3
	orbit = 0.25
	game()
	caption("РУБИ ЛЕС", 2.9, 120, 0.58)
	for i in 4:
		m.ui.a_pressed = true
		await wait(0.58)
	# D. стройка
	Game.wood = 16
	Game.stone = 3
	m.player.global_position = Vector3(0, 0, 3)
	m.player.face = PI
	m.yaw = PI
	orbit = 0.0
	punch()
	caption("СТРОЙ СВОЮ ДАЧУ", 3.0, 100, 0.58)
	m.ui.c_pressed = true
	await wait(0.5)
	m.ui.slot_tapped = 2
	await wait(0.8)
	m.ui.a_pressed = true
	await wait(0.5)
	m.ui.slot_tapped = 0
	m.player.global_position = Vector3(-4, 0, 3)
	await wait(0.5)
	m.ui.a_pressed = true
	await wait(0.3)
	m.ui.c_pressed = true
	await wait(0.2)
	# E. закат облёт
	m.dn.t = 150.0
	m.dn._apply()
	m.player.global_position = Vector3(-3.5, 0.05, 6.5)
	cine(arc(Vector3(0, 1.5, 0), 17.0, 13.0, 3.0, 5.5, 0.9, -0.5, 2.5), 3.0, 78.0)
	caption("РАСКРОЙ ТАЙНУ\nДАЧИ", 2.9, 110, 0.30)
	await wait(1.6)
	m.dn.t = 176.0
	m.dn._apply()
	await wait(1.4)
	# F. волки
	m.player.global_position = Vector3(1, 0, 4.5)
	m.yaw = 2.7
	m.pitch = 0.25
	orbit = 0.12
	game()
	caption("НОЧЬЮ ПРИХОДЯТ\nВОЛКИ", 4.8, 100, 0.58)
	for k in 3:
		var wn := Wolf3D.new()
		wn.position = m.player.global_position + Vector3(-3 + k * 3.0, 0, 7 + k)
		m.wolves_root.add_child(wn)
		wn.target = m.player
		wn.died.connect(m._on_wolf_died)
	await wait(0.4)
	for i in 6:
		Game.hp = maxf(Game.hp, 60.0)
		for w in get_tree().get_nodes_in_group("wolves"):
			var wf := w as Wolf3D
			if not wf.dead and wf.global_position.distance_to(m.player.global_position) < 6.0:
				var dd: Vector3 = wf.global_position - m.player.global_position
				m.player.face = atan2(-dd.x, -dd.z)
				break
		m.ui.a_pressed = true
		if i == 4:
			m.ui.b_pressed = true
		await wait(0.5)
	var wb := Wolf3D.new()
	wb.kind = "boss"
	wb.position = m.player.global_position + Vector3(4, 0, 8)
	m.wolves_root.add_child(wb)
	wb.target = m.player
	wb.died.connect(m._on_wolf_died)
	for i in 1:
		m.ui.a_pressed = true
		await wait(0.4)
	# G. Пассат
	orbit = 0.0
	m.dn.t = 40.0
	m.dn._apply()
	m.player.global_position = m.car.global_position + Vector3(3.2, 0, 0)
	await wait(0.3)
	m.ui.a_pressed = true
	await wait(0.3)
	m.ui.move_override = Vector2(0, -1)
	var car: Car3D = m.car
	cine(func(u: float) -> Array:
		var b: Basis = car.global_transform.basis
		return [car.global_position + b * Vector3(5.0, 1.0, -4.5), car.global_position + Vector3(0, 0.8, 0)], 3.0, 70.0)
	shake = 0.05
	caption("КАТАЙСЯ НА ПАССАТЕ", 3.0, 100, 0.66)
	await wait(1.2)
	m.ui.move_override = Vector2(0.5, -1)
	await wait(1.0)
	m.ui.move_override = Vector2(-0.4, -1)
	await wait(1.0)
	# H. клуб
	m.ui.move_override = Vector2.ZERO
	m.car.speed = 0.0
	m.mode = "play"
	m.car.occupied = false
	m.player.set_active(true)
	m.dn.t = 190.0
	m.dn._apply()
	m.player.global_position = m.CLUB_DOOR + Vector3(0, 0, 1.2)
	shake = 0.02
	cine(arc(m.CLUB_DOOR + Vector3(0, 0, 0), 14.0, 8.0, 1.6, 2.6, 0.6, -0.5, 2.0), 3.0, 76.0)
	caption("ОТОРВИСЬ В КЛУБЕ", 2.9, 100, 0.66)
	await wait(1.3)
	m.ui.a_pressed = true
	await wait(1.0)
	game()
	Game.wood = 12
	m.player.global_position = m.club.global_position + Vector3(-7.5, 0.05, -1.0)
	await wait(0.3)
	for i in 2:
		m.ui.a_pressed = true
		await wait(0.45)
	m.ui.move_override = Vector2(0.7, -0.4)
	await wait(0.8)
	# I. финал
	m.ui.move_override = Vector2.ZERO
	m.dn.t = 258.0
	m.dn._apply()
	m.player.global_position = Vector3(-3.5, 0.05, 6.5)
	cine(arc(Vector3(0, 2.0, 0), 9.0, 30.0, 2.5, 14.0, 0.2, -0.3, 2.5), 3.2, 76.0)
	shake = 0.0
	caption("ДАЧА\nМИХАЛЫЧА", 3.0, 140, 0.28)
	await wait(1.0)
	caption("Играй бесплатно\nв Яндекс Играх", 2.0, 84, 0.72, Color(1, 1, 1))
	await wait(1.3)
	black(1.0, 0.5)
	await wait(0.6)
	get_tree().quit()
