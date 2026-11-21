extends Node
## Проходит миссию «Волчий налог» целиком и снимает кадры
var m: Node3D
var fails := 0
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func ok(n: String, c: bool) -> void:
	print("MISSIONTEST ", "PASS " if c else "FAIL ", n)
	if not c:
		fails += 1
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/ms%s_%s.png" % [OS.get_environment("LANGRU"), n])
func close_dlg() -> void:
	var cb: Callable = m.ui.dlg_cb
	m.ui.dlg_active = false
	m.ui.dlg_cb = Callable()
	if cb.is_valid():
		cb.call()
func put(c: int, p: Vector3, yaw: float = 0.0) -> void:
	m.player.set_char(c)
	m.player.global_position = m.city.C + p + Vector3(0, 0.05, 0)
	m.player.velocity = Vector3.ZERO
	m.yaw = yaw
func _ready() -> void:
	m = get_parent()
	run.call_deferred()
func run() -> void:
	await wait(2.5)
	if OS.has_environment("LANGRU"):
		Loc.en = false
	Game.intro_done = true
	Game.m1_done = false
	m.ui.dlg_active = false
	m.mode = "play"
	var M: Mission1 = m.mission
	var cash0 := Game.cash
	put(0, Mission1.P_LIS + Vector3(0, 0, 1.6))
	m.cam_rig.global_position = m.player.global_position + Vector3(0, 1.6, 0)
	await wait(0.8)
	print("MISSIONTEST dbg label=", M.label("m1_start"), " near=", m.city.near_label(m.player.global_position), " pos=", m.player.global_position, " stage=", M.stage, " pts=", m.city.points.size(), " done=", Game.m1_done)
	ok("lis label", M.label("m1_start") == "Поговорить с Лисом" and m.city.near_label(m.player.global_position) == "Поговорить с Лисом")
	await shot("1_lis")
	m.city.interact(m.player.global_position)
	await wait(0.3)
	ok("briefing dialog", m.ui.dlg_active and m.mode == "dialog")
	close_dlg()
	await wait(0.3)
	ok("stage 1 + title", M.stage == 1 and M.card_kind == "title")
	await wait(1.2)
	await shot("2_title")
	ok("buddies follow", m.buddy_ai.mode == 1 and m.buddy2_ai.mode == 1)
	put(0, Mission1.P_STAGE)
	await wait(1.0)
	ok("stage 2 plan", M.stage == 2)
	close_dlg()
	await wait(0.5)
	# все трое рядом с башней
	m.buddy.global_position = m.city.C + Mission1.P_STAGE + Vector3(2.5, 0, 1.5)
	m.buddy2.global_position = m.city.C + Mission1.P_STAGE + Vector3(-2.5, 0, 1.5)
	put(0, Mission1.P_LOBBY + Vector3(0, 0, 3.0), 0.0)
	await wait(0.8)
	await shot("3_lobby_marker")
	# неверный герой
	put(1, Mission1.P_LOBBY)
	await wait(0.2)
	m.city.interact(m.player.global_position)
	await wait(0.1)
	ok("wrong hero ignored", not M.distracted)
	put(0, Mission1.P_LOBBY)
	await wait(0.2)
	ok("lobby label", m.city.near_label(m.player.global_position) == "Отвлечь охранника")
	m.city.interact(m.player.global_position)
	await wait(0.2)
	close_dlg()
	await wait(0.2)
	ok("guard distracted", M.distracted and M.guard_t > 60.0)
	put(1, Mission1.P_DOOR + Vector3(1.0, 0, 0))
	await wait(0.5)
	await shot("4_door")
	m.city.interact(m.player.global_position)
	await wait(0.2)
	ok("door smashed", M.door_done)
	put(2, Mission1.P_SAFE + Vector3(0, 0, -0.6))
	await wait(0.4)
	ok("safe label", m.city.near_label(m.player.global_position) == "Взлом сейфа (держи)")
	m.ui.key_a = true
	await wait(3.0)
	await shot("5_safe")
	ok("cracking progress", M.crack > 0.3 and M.crack < 1.0)
	await wait(4.0)
	m.ui.key_a = false
	ok("loot dialog", m.ui.dlg_active)
	close_dlg()
	await wait(0.3)
	ok("stage 3 + stars", M.stage == 3 and m.city.stars >= 3 and M.alarm)
	await shot("6_alarm")
	m.city.clear_wanted(true)
	put(0, Vector3(-36, 0, -24))
	await wait(1.0)
	ok("mission passed", M.stage == 4 and Game.m1_done and Game.cash >= cash0 + Mission1.REWARD_CASH)
	await wait(0.8)
	await shot("7_passed")
	# общий кадр: все трое героев одновременно на карте
	m.buddy_ai.mode = 2
	m.buddy2_ai.mode = 2
	put(0, Vector3(-18, 0, -12), 0.0)
	m.buddy.global_position = m.city.C + Vector3(-19.7, 0.05, -15.0)
	m.buddy2.global_position = m.city.C + Vector3(-16.3, 0.05, -15.0)
	m.buddy.face = PI
	m.buddy2.face = PI
	m.cam_rig.global_position = m.player.global_position + Vector3(0, 1.6, 0)
	await wait(1.2)
	await shot("8_trio")
	# колесо героев: Михалыч сейчас у игрока, выбираем Джейсона через колесо
	m.mode = "play"
	m.switch_cd = 0.0
	m.player.set_char(0)
	m.ui.wheel_origin = Vector2(1100, 600)
	m.ui.sw_idx = 0
	m.ui.sw_down_ms = Time.get_ticks_msec() - 500
	await wait(0.4)
	ok("wheel opens on hold", m.ui.wheel_open and m.ui.wheel_info.size() == 3)
	ok("time slowed", Engine.time_scale < 0.5)
	m.ui.wheel_drag(Vector2(1100, 600) + Vector2(-80, 30))   # влево-вниз: Джейсон
	await wait(0.3)
	ok("wheel selects Jason", m.ui.wheel_sel == 2)
	await shot("9_wheel")
	m.ui.sw_idx = -1
	m.ui.wheel_end()
	await wait(2.0)
	ok("time restored", Engine.time_scale == 1.0)
	ok("switched via wheel to Jason", m.player.char_id == 2 and m.buddy.char_id != 2 and m.buddy2.char_id != 2)
	# короткий тап — как раньше (следующий герой)
	var before: int = m.player.char_id
	m.switch_cd = 0.0
	m.ui.sw_idx = 0
	m.ui.sw_down_ms = Time.get_ticks_msec()
	m.ui.sw_idx = -1
	m.ui.wheel_end()
	await wait(2.0)
	ok("quick tap still rotates", m.player.char_id != before)
	print("MISSIONTEST done fails=", fails)
	get_tree().quit()
