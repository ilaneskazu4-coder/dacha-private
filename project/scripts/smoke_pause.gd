extends Node
var m: Node3D
var fails := 0
func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/%s.png" % nm)
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func check(c: bool, msg: String) -> void:
	if not c: fails += 1
	print(("OK    " if c else "FAIL  ") + msg)
func _ready() -> void:
	m = get_parent()
	run.call_deferred()
func run() -> void:
	await wait(0.8)
	m.ui.dlg_active = false
	m.mode = "play"
	Game.intro_done = true
	Game.stage = 4
	m.dn.t = 190.0
	m.dn.set_process(false)
	m.dn._apply()
	m.player.global_position = Vector3(0, 0.05, 6)
	m.yaw = 0.0
	m.pitch = 0.2
	await wait(1.0)
	# --- пауза кнопкой
	m.ui.pause_tapped = true
	await wait(0.4)
	check(get_tree().paused, "игра на паузе")
	check(m.pause_ui.visible, "меню паузы видно")
	await shot("p_pause")
	var wolves_t: float = m.dn.t
	await wait(0.5)
	check(is_equal_approx(m.dn.t, wolves_t), "время стоит на паузе")
	# --- настройки из паузы
	m.pause_ui.action.emit("settings", null)
	await wait(0.3)
	await shot("p_settings")
	# --- качество: низкое / обычное / высокое, одна и та же сцена
	for q in [0, 1, 2]:
		m.pause_ui.action.emit("quality", q)
		await wait(0.5)
		check(Settings.quality == q, "качество %d применено" % q)
		check(m.env.glow_enabled == (q >= 2), "glow для качества %d" % q)
		m.pause_ui.visible = false
		await wait(0.4)
		await shot("q_%d" % q)
		m.pause_ui.visible = true
	# громкость
	m.pause_ui.action.emit("music", 0.3)
	check(absf(Settings.music - 0.3) < 0.01, "музыка 30%")
	m.pause_ui.action.emit("back", null)
	await wait(0.2)
	check(m.pause_page == "pause", "вернулись на страницу паузы")
	# --- продолжить
	m.pause_ui.action.emit("resume", null)
	await wait(0.4)
	check(not get_tree().paused, "игра продолжилась")
	check(not m.pause_ui.visible, "меню паузы скрыто")
	# клавиша Esc
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(0.5)
	check(get_tree().paused, "Esc ставит на паузу")
	m.pause_ui.action.emit("back", null)
	await wait(0.3)
	check(not get_tree().paused, "back снимает паузу")
	print("FAILS: ", fails)
	get_tree().quit()
