extends Node
var m: Node3D
var fails := 0

func ok(n: String, c: bool) -> void:
	print("CITYTEST ", "PASS " if c else "FAIL ", n)
	if not c:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/city_%s.png" % n)

func _ready() -> void:
	m = get_parent()
	run.call_deferred()

func put(p: Vector3, yaw: float) -> void:
	m.player.global_position = p + Vector3(0, 0.05, 0)
	m.player.velocity = Vector3.ZERO
	m.yaw = yaw
	m.cam_rig.global_position = p + Vector3(0, 1.6, 0)

func run() -> void:
	await wait(2.5)
	m.ui.dlg_active = false
	m.mode = "play"
	var C: Vector3 = m.city.C
	Game.wood = 30
	# 1. виды города
	put(C + Vector3(-4, 0, 3), PI)
	await wait(1.5)
	await shot("1_street")
	put(C + Vector3(8, 0, -3.5), 0.0)
	m.yaw = 0.0
	await wait(1.0)
	await shot("2_exchange")
	# 2. продажа
	var lbl: String = m.city.near_label(m.player.global_position)
	ok("exchange label", lbl.contains("брёв"))
	m.city.interact(m.player.global_position)
	ok("sold logs", Game.cash > 100 and Game.wood == 10)
	# 3. пиво
	put(C + Vector3(-22, 0, -3.8), 0.0)
	await wait(0.5)
	Game.cash += 50
	var c0: int = Game.cash
	ok("bar enter label", m.city.near_label(m.player.global_position).contains("Войти"))
	m.city.interact(m.player.global_position)
	await wait(1.2)
	ok("inside bar", m.city.in_shop == "bar" and m.player.global_position.x > 500.0)
	await shot("3_bar_in")
	m.city.interact(m.player.global_position)
	ok("beer bought", Game.cash < c0 and m.drunk > 0.5)
	await shot("3_bar")
	m.player.global_position = m.city.SHOP_OFF["bar"] + Vector3(0, 0.05, 3.8)
	m.city.interact(m.player.global_position)
	await wait(1.2)
	ok("left bar", m.city.in_shop == "" and m.player.global_position.x < 200.0)
	# 4. автосалон
	put(C + Vector3(20, 0, -3.5), -1.2)
	Game.cash = 400
	m.city.interact(m.player.global_position)
	ok("sport car bought", Game.owned_sport and Game.cash == 100)
	await wait(0.8)
	await shot("4_dealer")
	# 5. убийство прохожего
	m.drunk = 0.0
	var pd: Dictionary = m.city.peds[2]
	var n: Node3D = pd["n"]
	put(n.global_position + Vector3(0, 0, 2.0), 0.0)
	n.set_process(false)
	await wait(0.3)
	var fwd := Vector3(0, 0, -1)
	for i in 3:
		m.city.hit_ped(m.player.global_position, fwd)
	ok("ped dead", float(pd["dead"]) > 0.0)
	ok("wanted after murder", m.city.stars >= 2)
	await wait(0.4)
	await shot("5_blood")
	# 6. погоня
	put(C + Vector3(-32, 0, -7), PI * 0.5)
	await wait(1.6)
	ok("police spawned", m.city.police.size() > 0)
	await wait(0.6)
	await shot("6_chase")
	var d0 := 999.0
	for p in m.city.police:
		d0 = minf(d0, (p as Node3D).global_position.distance_to(m.player.global_position))
	print("CITYTEST police dist after 2s: ", d0)
	ok("police approaching", d0 < 28.0)
	var arrested := false
	for k in 40:
		await wait(1.0)
		if k == 6 and not arrested and m.city.bust_t <= 0.0:
			put(C + Vector3(-6, 0, 3.0), PI * 0.5)
		if k % 5 == 0:
			var dm := 999.0
			for p in m.city.police:
				dm = minf(dm, (p as Node3D).global_position.distance_to(m.player.global_position))
			print("CITYDBG dmin=", dm, " stars=", m.city.stars, " mode=", m.mode, " police=", m.city.police.size(), " cops=", m.city.cops.size(), " bust=", m.city.bust_t, " hp=", Game.hp, " spd=", m.player.cur_speed)
		if m.city.stars == 0 and m.mode == "dialog":
			arrested = true
			break
	ok("arrested (wanted cleared)", arrested)
	await shot("7_busted")
	print("CITYTEST DONE fails=", fails)
	get_tree().quit()
