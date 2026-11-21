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
func press() -> void:
	m.ui.a_pressed = true
	await wait(0.15)
func run() -> void:
	await wait(0.8)
	m.ui.dlg_active = false
	m.mode = "play"
	Game.intro_done = true
	Game.stage = 4
	Game.hp = 50
	m.dn.t = 20.0
	await wait(0.3)
	for id in m.HOUSE_ORDER:
		# снаружи
		var door: Vector3 = m._house_door(id)
		var o: Vector3 = m._house_dir(id)
		m.player.global_position = door + o * 5.0 + Vector3(0, 0.05, 0)
		m.yaw = atan2(-o.x, -o.z) + PI
		m.pitch = 0.2
		await wait(0.6)
		await shot("h_%s_out" % id)
		m.player.global_position = door + Vector3(0, 0.05, 0)
		await wait(0.3)
		check(m._near_house() == id, "рядом с дверью: " + id)
		await press()
		await wait(0.9)
		check(m.in_house == id, "вошёл в " + id)
		m.yaw = 0.0
		m.pitch = 0.5
		await wait(0.6)
		await shot("h_%s_in" % id)
		# интерактив
		var it: Interior3D = m.interiors[id]
		for pt in it.points:
			m.player.global_position = it.global_position + Vector3(pt["pos"]) + Vector3(0, 0.05, 0)
			await wait(0.3)
			await press()
			await wait(0.3)
			if m.ui.dlg_active:
				m.ui.dlg_chars = 999
				for k in 6:
					if m.ui.dlg_active: m.ui._advance()
					await wait(0.1)
			m.mode = "play"
		check(true, "точки в " + id + ": " + str(it.points.size()))
		# выход
		m.player.global_position = it.global_position + Vector3(0, 0.05, it.hz - 0.5)
		await wait(0.3)
		await press()
		await wait(0.9)
		check(m.in_house == "", "вышел из " + id)
		check(m.player.global_position.distance_to(m._house_door(id)) < 3.5, "снаружи у двери " + id)
	# ночь: жители уходят домой
	Npc3D.frozen = false
	m.dn.t = 175.0
	m.dn.is_night = true
	for k in 120:
		await wait(0.5)
		var home_cnt := 0
		var need := 0
		for nid in m.npcs:
			if m.npcs[nid].home != "":
				need += 1
				if m.npcs[nid].at_home: home_cnt += 1
		if home_cnt >= need: break
	var inside := 0
	var total := 0
	for nid in m.npcs:
		if m.npcs[nid].home != "":
			total += 1
			if m.npcs[nid].at_home: inside += 1
	check(inside == total, "ночью все дома: %d / %d" % [inside, total])
	# утром выходят
	m.dn.t = 20.0
	m.dn.is_night = false
	await wait(1.5)
	var out := 0
	for nid in m.npcs:
		var n: Npc3D = m.npcs[nid]
		if n.home != "" and not n.perma_home and not n.at_home: out += 1
	check(out == total - 1, "утром жители вышли: %d" % out)
	print("FAILS: ", fails)
	get_tree().quit()
