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
	await wait(1.0)
	m.ui.dlg_active = false
	m.mode = "play"
	Game.intro_done = true
	# --- рубим дерево
	var best := -1
	var bd := 1e9
	for i in m.forest.items.size():
		var it: Dictionary = m.forest.items[i]
		if it["kind"] != "tree": continue
		var d: float = (it["pos"] as Vector3).distance_to(Vector3(0, 0, 40))
		if d < bd: bd = d; best = i
	var tp: Vector3 = m.forest.items[best]["pos"]
	m.player.global_position = tp + Vector3(0, 0, 1.6)
	m.player.face = 0.0
	m.yaw = 0.0
	var w0: int = Game.wood
	for i in 4:
		m.ui.a_pressed = true
		await wait(0.7)
	check(Game.wood >= w0 + 3, "рубка дерева: бревна %d -> %d" % [w0, Game.wood])
	await shot("03_chop")
	# --- стройка
	Game.wood = 14
	Game.stone = 2
	await wait(0.3)
	check(Game.stage == 2, "стадия 2 при 10+ брёвнах")
	m.player.global_position = Vector3(0, 0, -2)
	m.player.face = PI
	m.yaw = PI
	m.ui.c_pressed = true
	await wait(0.4)
	m.ui.slot_tapped = 2
	await wait(0.4)
	print("GHOST ", m.ghost, " ", m.ghost.visible if m.ghost else "-", " ", m.ghost.position if m.ghost else "-", " ch=", m.ghost.get_child_count() if m.ghost else 0, " pl=", m.player.global_position)
	await shot("04_build_ghost")
	check(m.ghost_ok, "призрак костра валиден")
	m.ui.a_pressed = true
	await wait(0.3)
	check(get_tree().get_nodes_in_group("fires").size() == 1, "костёр построен")
	m.ui.slot_tapped = 0
	await wait(0.2)
	m.player.global_position = Vector3(0, 0, -2)
	m.player.face = 0.0
	await wait(0.4)
	m.ui.a_pressed = true
	await wait(0.3)
	m.ui.c_pressed = true
	await wait(0.3)
	check(m.structs_root.get_child_count() >= 2, "стена построена, всего %d" % m.structs_root.get_child_count())
	m.player.global_position = Vector3(2, 0, 3)
	# --- ночь
	m.dn.t = 168.0
	await wait(4.0)
	m.yaw = -2.36
	await wait(8.0)
	var wc := get_tree().get_nodes_in_group("wolves").size()
	check(wc > 0, "волки появились: %d" % wc)
	for w in get_tree().get_nodes_in_group("wolves"):
		(w as Node3D).global_position = Vector3(5, 0, 6) + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	await wait(1.5)
	m.player.face = -2.36 + PI
	await shot("05_night_wolves")
	m.ui.b_pressed = true
	await wait(0.2)
	await shot("05b_shout")
	m.ui.a_pressed = true
	await wait(0.6)
	await shot("05c_axe")
	# --- вожак и щенок
	for w in get_tree().get_nodes_in_group("wolves"):
		(w as Wolf3D).die(false)
	await wait(1.0)
	for k in ["boss", "pup", "pup"]:
		var wb := Wolf3D.new()
		wb.kind = k
		wb.position = m.player.global_position + Vector3(randf_range(3, 6), 0, randf_range(3, 6))
		m.wolves_root.add_child(wb)
		wb.target = m.player
		wb.died.connect(m._on_wolf_died)
	m.yaw = -2.36
	await wait(0.7)
	await shot("05d_boss")
	var kills0: int = Game.kills
	for w in get_tree().get_nodes_in_group("wolves"):
		if (w as Wolf3D).kind == "boss":
			check((w as Wolf3D).hp > 100.0 and (w as Wolf3D).kill_value == 5, "вожак: hp %d" % int((w as Wolf3D).hp))
			(w as Wolf3D).hurt(999.0, m.player.global_position)
	await wait(0.3)
	check(Game.kills == kills0 + 5, "убийство вожака даёт 5")
	# --- смерть и реклама
	Game.hp = 0.0
	await wait(0.4)
	check(m.mode == "dead", "модал смерти")
	await shot("06_dead")
	m.ui.modal_btn = "ad"
	await wait(1.0)
	await shot("07_ad")
	await wait(2.5)
	check(m.mode == "play" and Game.hp >= 99.0, "возрождение после рекламы: hp %d" % int(Game.hp))
	# --- рассвет
	m.dn.t = 254.0
	await wait(3.0)
	check(Game.stage == 4, "стадия 4 после первой ночи")
	await shot("08_dawn")
	# --- машина
	m.player.global_position = m.car.global_position + Vector3(3, 0, 0)
	await wait(0.2)
	m.ui.a_pressed = true
	await wait(0.3)
	check(m.mode == "car", "сел в машину")
	m.ui.move_override = Vector2(0, -1)
	await wait(2.0)
	m.ui.move_override = Vector2.ZERO
	check(m.car.global_position.distance_to(Vector3(9, 0, 10)) > 5.0, "машина поехала")
	await shot("09_car")
	print("FAILS: ", fails)
	get_tree().quit()
