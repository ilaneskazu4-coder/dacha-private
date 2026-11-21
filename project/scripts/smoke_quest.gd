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
func goto(n: String) -> void:
	var npc: Node3D = m.npcs[n]
	m.player.global_position = npc.global_position + Vector3(0, 0, 2.0)
	m.player.face = 0.0
	await wait(0.3)
func talk(n: String, shots: String = "") -> void:
	await goto(n)
	m.ui.a_pressed = true
	await wait(0.3)
	if shots != "":
		await wait(0.8)
		await shot(shots)
	var guard := 0
	while m.ui.dlg_active and guard < 12:
		m.ui.dlg_chars = 999
		m.ui._advance()
		await wait(0.1)
		guard += 1
	await wait(0.2)
func run() -> void:
	await wait(0.8)
	m.ui.dlg_active = false
	m.mode = "play"
	Game.intro_done = true
	Game.stage = 4
	Game.hp = 100
	m.dn.t = 20.0
	await wait(0.3)
	m.cam.fov = 68
	# 0: визит к Коле
	await talk("makar", "q01_makar_intro")
	check(Game.q_state == 1 and Game.quest == 0, "квест 0 взят")
	await talk("kolya", "q02_kolya_done")
	check(Game.quest == 1, "квест 0 сдан")
	# 1: 15 брёвен
	await talk("kolya")
	check(Game.q_state == 1, "квест 1 взят")
	Game.wood = 3
	await talk("kolya")
	check(Game.quest == 1, "без брёвен не сдаётся")
	Game.wood = 20
	await talk("kolya", "q03_bring_wood")
	check(Game.quest == 2 and Game.wood == 5, "квест 1 сдан, wood=%d" % Game.wood)
	# 2: пила Макару
	await talk("kolya")
	await talk("makar")
	check(Game.quest == 3, "квест 2 сдан")
	# 3: волки 8
	await talk("makar")
	Game.kills += 8
	await talk("makar")
	check(Game.quest == 4, "квест 3 (волки) сдан")
	# 4: письмо в доме Макара
	await talk("makar", "q04_letter_intro")
	check(Game.q_state == 1 and Game.quest == 4, "квест письмо взят")
	m._enter_house("makar")
	await wait(1.0)
	check(m.in_house == "makar", "зашёл в дом Макара")
	var it: Interior3D = m.interiors["makar"]
	m.player.global_position = it.global_position + Vector3(-0.8, 0.05, 1.0)
	await wait(0.3)
	m.ui.a_pressed = true
	await wait(0.5)
	await shot("q04b_letter")
	check(m.q_reached, "письмо найдено")
	m.ui.dlg_chars = 999
	for k in 6:
		if m.ui.dlg_active: m.ui._advance()
		await wait(0.1)
	m.mode = "play"
	m._exit_house()
	await wait(1.0)
	check(m.in_house == "", "вышел из дома Макара")
	await talk("makar")
	check(Game.quest == 5, "квест письмо сдан")
	# 5: рыба для Вити
	await talk("vitya", "q05_vitya")
	check(Game.q_state == 1 and Game.quest == 5, "квест рыбы взят")
	await talk("vitya")
	check(Game.quest == 5, "без рыбы не сдаётся")
	Game.fish += 3
	await talk("vitya")
	check(Game.quest == 6, "квест рыбы сдан")
	# 6: Люда
	await talk("makar")
	await talk("lyuda", "q06_lyuda")
	check(Game.quest == 7, "квест Люда сдан")
	# 7: камни
	await talk("lyuda")
	Game.stone = 9
	await talk("lyuda")
	check(Game.quest == 8, "квест камни сдан")
	# 8: вышка
	await talk("lyuda")
	m.player.global_position = Vector3(70, 0, -75)
	await wait(0.5)
	await shot("q07_tower")
	check(m.q_reached, "вышка достигнута")
	await talk("lyuda")
	check(Game.quest == 9, "квест вышка сдан")
	# 9: стройка 8
	await talk("makar")
	for i in 8:
		m._spawn_struct("fence", Vector3(-10 + i * 2, 0, 30), 0)
	await wait(0.2)
	await talk("makar", "q08_build_done")
	check(Game.quest == 10, "квест стройка сдан")
	# 10: день 4
	await talk("makar")
	m.dn.day = 4
	await talk("makar")
	check(Game.quest == 11, "квест день 4 сдан")
	# 11: Борзов в клубе
	await talk("makar")
	m._enter_club()
	await wait(1.2)
	check(m.in_club, "вошёл в клуб к Борзову")
	var bz: Npc3D = m.npcs["borzov"]
	m.player.global_position = bz.global_position + Vector3(-2.0, 0.05, 0)
	await wait(0.4)
	m.ui.a_pressed = true
	await wait(0.5)
	await shot("q09_borzov")
	var guard := 0
	while m.ui.dlg_active and guard < 12:
		m.ui.dlg_chars = 999
		m.ui._advance()
		await wait(0.1)
		guard += 1
	m.mode = "play"
	check(Game.quest == 12, "квест Борзов сдан")
	m._exit_club()
	await wait(1.2)
	check(not m.in_club, "вышел из клуба")
	# 12: вожак
	await talk("makar")
	check(Game.q_state == 1 and Game.quest == 12, "квест вожак взят")
	Game.bosses += 1
	await talk("borzov", "q10_finale")
	check(Game.quest == 13, "все квесты пройдены")
	await wait(0.5)
	await shot("q08_all_done")
	# рыбалка
	Game.hp = 50.0
	m.player.global_position = Vector3(66, 0, 22.5)
	m.player.face = 1.57
	await wait(0.5)
	m.ui.a_pressed = true
	await wait(0.4)
	check(m.mode == "fish", "рыбалка началась")
	m.ui.fish_pos = (m.ui.fish_zone.x + m.ui.fish_zone.y) / 2.0
	m.fish_speed = 0.0
	await shot("q09_fishing")
	m.ui.a_pressed = true
	await wait(0.4)
	check(m.ui.fish_caught == 1 and Game.hp > 60.0, "рыба поймана, hp=%d" % int(Game.hp))
	await shot("q10_caught")
	# дискотека
	m.ui.fish_on = false
	m.mode = "play"
	m.dn.t = 30.0
	m.player.global_position = m.CLUB_DOOR + Vector3(0, 0, 1.0)
	m.yaw = 0.0
	await wait(0.4)
	await shot("q11_club_door")
	m.ui.a_pressed = true
	await wait(1.2)
	check(m.in_club, "вошёл в дискотеку")
	await wait(0.6)
	await shot("q12_club_inside")
	Game.wood = 10
	m.player.global_position = m.club.global_position + Vector3(-7.5, 0.05, -1.0)
	await wait(0.4)
	m.ui.a_pressed = true
	await wait(0.4)
	check(m.drunk >= 0.9 and Game.wood == 8, "напиток куплен: drunk=%.1f wood=%d" % [m.drunk, Game.wood])
	m.drunk = 4.0
	m.player.global_position = m.club.global_position + Vector3(0, 0.05, 1.0)
	await wait(0.5)
	m.ui.a_pressed = true
	await wait(1.0)
	check(m.player.hum.dance, "танцует")
	await shot("q13_club_drunk_dance")
	m.drunk = 0.0
	m.player.global_position = m.club.global_position + Vector3(0, 0.05, 8.4)
	m.ui.a_pressed = true
	await wait(1.6)
	check(not m.in_club, "вышел из дискотеки")
	await shot("q14_after_club_drunk")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await wait(0.5)
	print("PERF draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("FAILS: ", fails)
	get_tree().quit()
