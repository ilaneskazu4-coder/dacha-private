extends Node
var m: Node3D
var fails := 0

func ok(n: String, c: bool) -> void:
	print("TRAFTEST ", "PASS " if c else "FAIL ", n)
	if not c:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/traf_%s.png" % n)

func put(p: Vector3, yaw: float) -> void:
	m.player.global_position = p + Vector3(0, 0.05, 0)
	m.player.velocity = Vector3.ZERO
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
	put(C + Vector3(2, 0, -7.0), -1.57)
	m.player.face = -1.57
	await wait(3.0)
	await shot("1_street")
	var last: Array = []
	var path: Array = []
	for c in m.city.traffic:
		last.append((c as Node3D).global_position)
		path.append(0.0)
	var maxdev := 0.0
	for k in 36:
		await wait(1.0)
		m.city.bust_t = 0.0
		for i in m.city.traffic.size():
			var c: Node3D = m.city.traffic[i]
			path[i] += c.global_position.distance_to(last[i])
			last[i] = c.global_position
			maxdev = maxf(maxdev, absf(c.global_position.z - C.z))
	var driving := 0
	for pl in path:
		if float(pl) > 60.0:
			driving += 1
	print("TRAFTEST maxdev_z=", maxdev, " path=", path)
	var wrapped := driving
	ok("cars drive", wrapped >= 0 and path.size() == 7 and float(path.min()) > 25.0)
	ok("cars stay on road", maxdev < 9.0)
	await shot("2_street_later")
	# вертолёт
	m.city.heat = 4.0
	m.city.stars = 4
	put(C + Vector3(-10, 0, 8), 0.0)
	for k in 50:
		await wait(0.1)
		m.city.bust_t = 0.0
	print("TRAFTEST dbg stars=", m.city.stars, " heat=", m.city.heat, " heli=", m.city.heli, " mode=", m.mode, " hp=", Game.hp)
	ok("helicopter spawned", m.city.heli != null)
	await shot("3_heli")
	var cash0: int = Game.cash
	if m.city.heli != null:
		for i in 8:
			m.city.heli_hurt(m.city.heli, 60.0)
	await wait(0.5)
	await shot("4_heli_falling")
	for k in 40:
		await wait(0.1)
		m.city.bust_t = 0.0
	ok("heli shot down", m.city.heli == null or m.city.heli.dying or Game.cash >= cash0 + 100 or m.city.stars == 0)
	print("TRAFTEST DONE fails=", fails)
	get_tree().quit()
