extends Node
var m: Node3D
var fails := 0

func ok(n: String, c: bool) -> void:
	print("GUNTEST ", "PASS " if c else "FAIL ", n)
	if not c:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/guns_%s.png" % n)

func put(p: Vector3, yaw: float, face: float) -> void:
	m.player.global_position = p + Vector3(0, 0.05, 0)
	m.player.velocity = Vector3.ZERO
	m.player.face = face
	m.yaw = yaw
	m.cam_rig.global_position = p + Vector3(0, 1.6, 0)

func _ready() -> void:
	m = get_parent()
	run.call_deferred()

func run() -> void:
	await wait(2.5)
	m.ui.dlg_active = false
	m.mode = "play"
	var C: Vector3 = m.city.C
	Game.cash = 1000
	# магазин
	put(C + Vector3(-42, 0, -3.8), 0.0, 0.0)
	m.city.interact(m.player.global_position)
	await wait(1.2)
	ok("inside guns", m.city.in_shop == "guns")
	await shot("0_gunshop")
	m.city.interact(m.player.global_position)
	ok("pistol bought", Game.has_pistol and Game.ammo_p == 24 and Game.cash == 850)
	m.city.interact(m.player.global_position)
	ok("shotgun bought", Game.has_shotgun and Game.ammo_s == 8)
	m.player.global_position = m.city.SHOP_OFF["guns"] + Vector3(0, 0.05, 3.8)
	m.city.interact(m.player.global_position)
	await wait(1.2)
	ok("left guns", m.city.in_shop == "")
	m.weapons.cycle()
	ok("pistol equipped", m.weapons.cur == 1 and m.player.weapon == 1)
	# стрельба по прохожему
	var pd: Dictionary = m.city.peds[1]
	var n: Node3D = pd["n"]
	n.set_process(false)
	put(n.global_position + Vector3(0, 0, 7.0), 0.0, 0.0)
	await wait(0.4)
	m.weapons.try_fire()
	await wait(0.05)
	await shot("1_fire")
	await wait(0.5)
	m.weapons.try_fire()
	await wait(0.4)
	m.weapons.try_fire()
	await wait(0.4)
	ok("ped shot dead", float(pd["dead"]) > 0.0)
	ok("ammo spent", Game.ammo_p < 24)
	ok("wanted for shooting", m.city.stars >= 2)
	# дробовик
	m.weapons.cycle()
	ok("shotgun equipped", m.weapons.cur == 2)
	# милиция пешком
	m.city.heat = 3.0
	m.city.stars = 3
	put(C + Vector3(-32, 0, -7), -1.57, -1.57)
	for k in 15:
		await wait(1.0)
		if m.city.cops.size() > 0 and k >= 1:
			break
		print("GUNDBG stars=", m.city.stars, " heat=", m.city.heat, " mode=", m.mode, " cops=", m.city.cops.size(), " police=", m.city.police.size(), " hp=", Game.hp, " pos=", m.player.global_position - C)
	ok("foot cops spawned", m.city.cops.size() > 0)
	await shot("2_cops")
	var hp0 := Game.hp
	await wait(3.0)
	print("GUNTEST hp ", hp0, " -> ", Game.hp, " cops=", m.city.cops.size())
	# отстреливаем копов
	var killed := false
	for i in 14:
		var tgt: Cop3D = null
		var bd := 1e9
		for c in m.city.cops:
			var cc := c as Cop3D
			if is_instance_valid(cc) and not cc.dying:
				var dd := cc.global_position.distance_to(m.player.global_position)
				if dd < bd:
					bd = dd
					tgt = cc
		if tgt == null:
			killed = true
			break
		var dv: Vector3 = tgt.global_position - m.player.global_position
		m.player.face = atan2(-dv.x, -dv.z)
		if bd > 14.0:
			m.weapons.cycle()
			m.weapons.cycle()
		m.weapons.cd = 0.0
		m.weapons.try_fire()
		await wait(0.5)
		if i == 4:
			await shot("3_firefight")
	var dead_n := 0
	for c in m.city.cops:
		if is_instance_valid(c) and (c as Cop3D).dying:
			dead_n += 1
	ok("cop killed", killed or dead_n > 0)
	await shot("4_aftermath")
	print("GUNTEST DONE fails=", fails)
	get_tree().quit()
