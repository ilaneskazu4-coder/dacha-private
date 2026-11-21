extends Node
## Проверка второго героя, смены, напарника, машины и спец-приёмов.
var m: Node3D
var fails := 0

func ok(n: String, c: bool) -> void:
	print("CHARTEST ", "PASS " if c else "FAIL ", n)
	if not c:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/char_%s.png" % n)

func nearest_tree(p: Vector3) -> Dictionary:
	var best := {}
	var bd := 1e9
	for it in m.forest.items:
		if it["alive"] and it["kind"] == "tree":
			var d: float = (it["pos"] as Vector3).distance_to(p)
			if d < bd:
				bd = d
				best = it
	return best

func _ready() -> void:
	m = get_parent()
	await wait(1.5)
	Game.intro_done = true
	m.ui.dlg_active = false

	m.mode = "play"
	await wait(1.0)
	print("CHARTEST dbg mode=", m.mode, " trans=", m.transitioning, " intro=", Game.intro_done, " vis=", m.buddy.visible)
	ok("buddy exists", m.buddy != null and m.buddy.char_id == 1 and m.player.char_id == 0)
	# 1. напарник-дровосек рубит: меняем местами, чтобы напарником был Михалыч
	var t := nearest_tree(Vector3(0, 0, -2))
	var tp: Vector3 = t["pos"]
	m.player.global_position = tp + Vector3(6, 0.1, 0)
	m.buddy.set_char(0)
	m.buddy.global_position = tp + Vector3(3, 0.1, 0)
	m.buddy_ai.mode = 0
	var wood0 := int(Game.wood)
	var hp0: int = t["hp"]
	await wait(9.0)
	print("CHARTEST dbg2 wood=", Game.wood, " tree hp=", t["hp"], " alive=", t["alive"], " bpos=", m.buddy.global_position, " tp=", tp, " mode=", m.mode)
	ok("buddy chops trees", Game.wood > wood0 or (not t["alive"]) or int(t["hp"]) < hp0)
	await shot("1_buddy_chop")
	# 2. смена героя
	m.buddy.set_char(1)
	m.player.global_position = Vector3(10, 0.1, 10)
	m.buddy.global_position = Vector3(12, 0.1, 10)
	m.buddy_ai.mode = 2
	Game.hp = 77.0
	m._switch_char()
	await wait(1.0)
	ok("switched to Gena (buddy is Jason)", m.player.char_id == 1 and m.buddy.char_id == 2)
	ok("hp swapped", Game.hp > 90.0 and m.buddy2.bhp < 95.0)
	ok("all three alive on map", m.buddy.visible and m.buddy2.visible and m.player.visible and m.buddy2.char_id == 0)
	ok("positions swapped", m.player.global_position.distance_to(Vector3(12, 0.1, 10)) < 1.5)
	# 3. комбо
	m.weapons.cur = 0
	m.player.set_weapon(0)
	ok("Gena has fists", m.player.fists() and not m.player.axe_mesh.visible)
	for k in 3:
		m.player.swing()
		await wait(0.2)
		await shot("2_combo_%d" % k)
		await wait(0.55)
	ok("combo kinds", true)
	# 4. ярость
	m.player.charge = 1.0
	ok("special starts", m.player.special())
	await wait(0.6)
	await shot("3_slam")
	await wait(0.8)
	ok("rage on", m.player.rage_t > 5.0)
	await shot("4_rage")
	# 5. машина
	m.player.rage_t = 0.0
	m.buddy.global_position = Vector3(30, 0.1, 30)
	m.player.global_position = m.car.global_position + Vector3(-3.5, 0.1, 0)
	await wait(0.3)
	m._enter_car()
	await wait(0.5)
	await shot("5_car_door")
	await wait(0.4)
	await shot("6_car_sit")
	await wait(1.0)
	ok("seated in car", m.mode == "car" and m.car_seq == "" and not m.player.visible)
	m._exit_car()
	await wait(0.45)
	await shot("7_car_out")
	await wait(1.3)
	ok("exited car", m.mode == "play" and m.player.visible and m.car_seq == "")
	# 6. вихрь Михалыча
	m.buddy.down_t = 0.0
	m.switch_cd = 0.0
	m._switch_char()
	await wait(1.0)
	ok("player is Jason", m.player.char_id == 2 and m.buddy.char_id == 0 and m.buddy2.char_id == 1 and m.player.fists())
	m.switch_cd = 0.0
	m._switch_char()
	await wait(1.0)
	ok("back to Mikhalych", m.player.char_id == 0 and m.buddy.char_id == 1 and m.buddy2.char_id == 2)
	m.player.charge = 1.0
	m.player.special()
	await wait(0.4)
	await shot("8_spin")
	await wait(0.8)
	ok("spin done", m.player.spec_t < 0.0)
	# 7. ударил напарника
	m.buddy.global_position = m.player.global_position + Vector3(0, 0, -1.4)
	m.player.face = 0.0
	m.weapons.cur = 3
	m.player.set_weapon(3)
	m.buddy_ai.mode = 2
	m.player.swing()
	await wait(0.6)
	ok("buddy angry", m.buddy.anger > 0.0)
	await wait(4.0)
	ok("angry buddy hurt player", Game.hp < 100.0)
	# 8. угон
	await wait(0.5)
	Game.hp = 100.0
	m.buddy.anger = 0.0
	var tc: Car3D = null
	for c in m.city.traffic:
		if is_instance_valid(c) and (c as Car3D).ai and (c as Car3D).kind != "police":
			tc = c
			break
	ok("traffic car exists", tc != null)
	if tc != null:
		m.player.global_position = tc.global_position + Vector3(-2.0, 0.2, 0)
		ok("near jack found", m._near_jack() != null)
		m.player.set_char(1)
		m._carjack(tc)
		await wait(0.55)
		await shot("9_jack_run")
		await wait(0.45)
		await shot("9_jack_lean")
		await wait(0.4)
		await shot("9_jack_pull")
		await wait(0.35)
		await shot("9_jack_out")
		await wait(0.9)
		ok("carjacked", m.mode == "car" and not tc.ai and m.city.stars > 0)
	print("CHARTEST fails=", fails)
	get_tree().quit()
