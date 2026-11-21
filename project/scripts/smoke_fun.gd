extends Node
## Проверка приколов игры вместе (две копии): PvP, бочки, воскрешение, соревнование.
var m: Node3D
var role := "host"
var fails := 0

func ok(name: String, cond: bool) -> void:
	print("FUNTEST ", role, " ", "PASS " if cond else "FAIL ", name)
	if not cond:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/fun_%s_%s.png" % [role, n])

func _ready() -> void:
	m = get_parent()
	run.call_deferred()

func run() -> void:
	role = "host" if Net.is_host else "client"
	Settings.quality = 1
	m._apply_quality()
	await wait(3.0)
	m.ui.dlg_active = false
	m.mode = "play"
	var bp: Vector3 = m.fun.barrels[0]["pos"]
	# 1. PvP включает хозяин
	if role == "host":
		Net.set_pvp(true)
	await wait(1.5)
	ok("pvp on", Net.pvp)
	# 2. бочка: гость бьёт по бочке
	if role == "client":
		m.player.global_position = bp + Vector3(-1.3, 0.05, 0)
		await wait(1.0)
		m.fun.on_chop(m.player.global_position, Vector3(1, 0, 0))
		await wait(0.25)
		shot("0_boom_fire")
	else:
		m.player.global_position = Vector3(40, 0.05, 40)
		await wait(1.0)
	await wait(1.5)
	ok("barrel exploded", not m.fun.barrels[0]["alive"])
	if role == "client":
		ok("client launched/hurt by blast", Game.hp < 100.0)
		shot("1_boom")
	await wait(2.5)
	Game.hp = 100.0
	# 3. PvP-удар хозяина по гостю
	if role == "client":
		m.player.global_position = Vector3(5, 0.05, -2)
		m.player.invuln = 0.0
	else:
		m.player.global_position = Vector3(3.7, 0.05, -2)
	await wait(2.0)
	if role == "host":
		m.player.face = -PI / 2.0
		for k in 3:
			m.fun.on_chop(m.player.global_position, Vector3(1, 0, 0))
			await wait(1.0)
		await wait(2.0)
	var was_down := false
	var min_hp := 100.0
	var t0 := Time.get_ticks_msec()
	var i := 0
	while role == "client" and Time.get_ticks_msec() - t0 < 5000:
		i += 1
		await get_tree().process_frame
		min_hp = minf(min_hp, Game.hp)
		if m.player.down_t > 0.0:
			was_down = true
			if i < 10:
				shot("2_pvp")
	if role == "client":
		ok("pvp hit damage", min_hp < 90.0)
		ok("knocked down", m.player.downs >= 2)
	# 4. воскрешение
	if role == "client":
		Game.hp = 0.0
		await wait(1.0)
		ok("client dead", m.mode == "dead")
	await wait(1.0)
	if role == "host":
		m.player.global_position = Vector3(4.2, 0.05, -2)
	await wait(4.0)
	if role == "client":
		ok("revived by friend", m.mode == "play" and Game.hp > 0.0)
		shot("3_revived")
	# 5. соревнование
	if role == "host":
		Net.start_activity("wood")
	await wait(1.5)
	if role == "client":
		print("DBG client act before wood=", m.fun.act)
		m.fun.on_wood()
		m.fun.on_wood()
	await wait(6.0)
	print("DBG ", role, " act=", m.fun.act, " scores=", m.fun.scores, " players=", Net.players.keys(), " left=", m.fun.act_left)
	if role == "host":
		ok("score from client", int(m.fun.scores.get(Net.players.keys().filter(func(k: int) -> bool: return k != 1)[0], 0)) == 2)
	else:
		ok("scoreboard on client", m.ui.net_hud.contains("ГОНКА"))
		shot("4_act")
	await wait(1.0)
	# 6. гонка по городу
	if role == "host":
		Net.start_activity("race")
	await wait(2.0)
	if role == "client":
		m.player.global_position = m.fun._cp_pos(0) + Vector3(0, 0.1, 0)
	await wait(5.0)
	if role == "host":
		ok("race checkpoint scored", int(m.fun.scores.get(Net.players.keys().filter(func(k: int) -> bool: return k != 1)[0], 0)) >= 1)
	await wait(1.0 if role == "client" else 4.0)
	print("FUNTEST ", role, " DONE fails=", fails)
	get_tree().quit()
